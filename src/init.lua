-- MaUI: entry point. A Library instance owns ALL of its state
-- (theme, input, flags, windows, notifications): no shared global state.
--
--   local MaUI = loadstring(...)()
--   local ui = MaUI.new({ Theme = "Sakura", -- Sakura | Dark | Light | any registered theme ConfigFolder = "MyHub" })
--   local window = ui:CreateWindow({ Title = "My Project" })
--   local tab = window:AddTab("Main")
--   local section = tab:AddSection("Combat")
--   section:AddToggle({ Name = "Auto", Flag = "auto", Default = false, Callback = function(on) end })
local Env = require("Core/Env")
local Input = require("Core/Input")
local KeySystem = require("Components/KeySystem")
local Maid = require("Core/Maid")
local Icons = require("Core/Icons")
local Notifications = require("Components/Notifications")
local Overlay = require("Components/Overlay")
local Signal = require("Core/Signal")
local Theme = require("Core/Theme")
local Tokens = require("Core/Tokens")
local Tween = require("Core/Tween")
local Util = require("Core/Util")
local Window = require("Components/Window")

local HttpService = game:GetService("HttpService")

local MaUI = {}
MaUI.__index = MaUI
MaUI.Version = "0.2.0"
MaUI.Icons = Icons -- MaUI.Icons.Register("home", "rbxassetid://...")
MaUI.Tokens = Tokens

function MaUI.new(options)
	options = Util.Options(options, {
		Theme = "Sakura", -- Sakura | Dark | Light | any registered theme
		Animations = "Full", -- Full | Reduced | Off
		ConfigFolder = "MaUI",
		ConfigName = "default",
		AutoSave = false,
		FontFamily = "rbxasset://fonts/families/BuilderSans.json",
		Clock = os.time, -- time source (seconds): key expiry; overridable for tests
		OnKeyExpired = nil, -- function(key) called when the key expires
	})

	local self = setmetatable({}, MaUI)
	self.Options = options
	self.Maid = Maid.new()
	self.Flags = {}
	self.Windows = {}
	self.Overlays = {} -- floating overlay windows and islands, destroyed with the library
	self._destroyed = false
	self._loading = false
	self._savePending = false
	self.AutoSave = options.AutoSave
	self.ConfigFolder = options.ConfigFolder
	self.ConfigName = options.ConfigName
	self.Clock = options.Clock

	-- key state (filled in by ui:KeySystem)
	self.Key = nil -- { Value, ExpiresAt|nil, Expired, Info }
	self.KeyChanged = Signal.new()
	self.KeyExpired = Signal.new()
	self.KeyTick = Signal.new() -- once per second, only while an expiring key is displayed
	self._tickUsers = 0
	self._tickRunning = false
	self._expiryTimer = nil
	self._keySystem = nil
	self.Maid:Give(self.KeyChanged)
	self.Maid:Give(self.KeyExpired)
	self.Maid:Give(self.KeyTick)
	self.Maid:Give(function()
		if self._expiryTimer then
			pcall(task.cancel, self._expiryTimer)
			self._expiryTimer = nil
		end
		if self._keySystem then
			self._keySystem:Destroy()
			self._keySystem = nil
		end
	end)

	self.Theme = Theme.new(options.Theme)
	self.Input = Input.new()
	self.Tween = Tween.new(options.Animations)
	self.Maid:Give(self.Input)

	local touch = Env.IsTouch()
	local family = options.FontFamily
	self.Ctx = {
		Library = self,
		Theme = self.Theme,
		Input = self.Input,
		Tween = self.Tween,
		Touch = touch,
		Fonts = {
			Regular = Font.new(family, Enum.FontWeight.Regular),
			Medium = Font.new(family, Enum.FontWeight.Medium),
			Bold = Font.new(family, Enum.FontWeight.SemiBold),
		},
		-- touch-friendly sizes
		Metrics = touch
			and { Card = 50, CardTall = 64, Chip = 32, Title = 44, Tab = 40, Nav = 44, Control = 44, Compact = 34, Header = 60 }
			or { Card = 40, CardTall = 54, Chip = 26, Title = 38, Tab = 34, Nav = 36, Control = 34, Compact = 26, Header = 56 },
	}

	self.Ctx.Tokens = Tokens
	self._overlay = Overlay.new(self.Ctx)
	self.Maid:Give(self._overlay)
	self.Ctx.Popup = self._overlay.Popup
	self.Ctx.Tooltip = self._overlay.Tooltip

	-- a saved default theme wins over options.Theme
	local defaultTheme = self:GetDefaultTheme()
	if defaultTheme and not self.Theme:Has(defaultTheme) then
		self:LoadTheme(defaultTheme)
	elseif defaultTheme then
		self.Theme:Set(defaultTheme)
	end

	self._notifications = Notifications.new(self.Ctx)
	self.Maid:Give(self._notifications)
	return self
end

-- Windows / notifications ------------------------------------------------------

function MaUI:CreateWindow(options)
	local window = Window.new(self, options)
	self.Windows[#self.Windows + 1] = window
	return window
end

-- Floating overlay window / Dynamic Island (see Components/OverlayWindow.lua, Components/DynamicIsland.lua).
function MaUI:CreateOverlayWindow(options)
	local OverlayWindow = require("Components/OverlayWindow")
	local overlay = OverlayWindow.new(self, options)
	self.Overlays[#self.Overlays + 1] = overlay
	return overlay
end

function MaUI:CreateIsland(options)
	local DynamicIsland = require("Components/DynamicIsland")
	local island = DynamicIsland.new(self, options)
	self.Overlays[#self.Overlays + 1] = island
	return island
end

function MaUI:Notify(options)
	return self._notifications:Push(options)
end

-- Key system -----------------------------------------------------------------------------

-- Shows the key entry window. See Components/KeySystem.lua.
function MaUI:KeySystem(options)
	if self._keySystem then
		self._keySystem:Destroy()
	end
	local gate = KeySystem.new(self, options)
	self._keySystem = gate
	return gate
end

-- Seconds remaining: nil = no key, math.huge = key without expiry.
function MaUI:GetKeyTimeLeft()
	local key = self.Key
	if not key then
		return nil
	end
	if key.Expired then
		return 0
	end
	if not key.ExpiresAt then
		return math.huge
	end
	return math.max(key.ExpiresAt - self.Clock(), 0)
end

-- A single scheduled task for expiry (re-checked on wake-up: os.time is only accurate to the second).
function MaUI:_ArmExpiry()
	if self._expiryTimer then
		pcall(task.cancel, self._expiryTimer)
		self._expiryTimer = nil
	end
	local key = self.Key
	if self._destroyed or not key or not key.ExpiresAt or key.Expired then
		return
	end
	local remaining = key.ExpiresAt - self.Clock()
	-- wake up within 24 h at most: avoids very long delays
	self._expiryTimer = task.delay(math.max(math.min(remaining, 86400), 0), function()
		self._expiryTimer = nil
		if self._destroyed or self.Key ~= key then
			return
		end
		if self.Clock() >= key.ExpiresAt then
			self:_OnKeyExpired()
		else
			self:_ArmExpiry()
		end
	end)
end

function MaUI:_SetKey(value, expiresAt, info)
	self.Key = { Value = value, ExpiresAt = expiresAt, Expired = false, Info = info }
	self:_ArmExpiry()
	self.KeyChanged:Fire(self.Key)
	self:_EnsureTick()
end

function MaUI:_OnKeyExpired()
	local key = self.Key
	if self._destroyed or not key or key.Expired then
		return
	end
	key.Expired = true
	self.KeyChanged:Fire(key)
	self.KeyExpired:Fire(key)
	self:Notify({ Title = "Key expired", Content = "Your key is no longer valid.", Type = "Warning", Duration = 6 })
	Util.Call(self.Options.OnKeyExpired, key)
end

-- Refresh rate for the remaining-time display: runs only if something is displaying it (AddKeyStatus)
-- AND a key is expiring. Otherwise: no task.
function MaUI:_AcquireKeyTick()
	self._tickUsers = self._tickUsers + 1
	self:_EnsureTick()
end

function MaUI:_ReleaseKeyTick()
	self._tickUsers = math.max(self._tickUsers - 1, 0)
end

function MaUI:_EnsureTick()
	if self._tickRunning or self._destroyed or self._tickUsers <= 0 then
		return
	end
	local key = self.Key
	if not key or not key.ExpiresAt or key.Expired then
		return
	end
	self._tickRunning = true
	local function step()
		local current = self.Key
		if self._destroyed or self._tickUsers <= 0 or not current or not current.ExpiresAt or current.Expired then
			self._tickRunning = false
			return
		end
		self.KeyTick:Fire(current)
		task.delay(1, step)
	end
	task.delay(1, step)
end

function MaUI:_RemoveWindow(window)
	for index, entry in ipairs(self.Windows) do
		if entry == window then
			table.remove(self.Windows, index)
			return
		end
	end
end

-- Theme / animations -------------------------------------------------------------

function MaUI:SetTheme(name)
	return self.Theme:Set(name)
end

function MaUI:RegisterTheme(name, tokens, base)
	self.Theme:Register(name, tokens, base)
end

function MaUI:SetAnimations(mode)
	return self.Tween:SetMode(mode)
end

-- Flags ----------------------------------------------------------------------------

function MaUI:_RegisterFlag(flag, element)
	if self.Flags[flag] ~= nil then
		error(string.format("[MaUI] the flag '%s' is already used by another element", tostring(flag)), 3)
	end
	self.Flags[flag] = element
end

function MaUI:_UnregisterFlag(flag, element)
	if self.Flags[flag] == element then
		self.Flags[flag] = nil
	end
end

-- Auto-save with debounce (0.5 s): a single timer, no matter how many changes.
function MaUI:_NotifyFlagChanged()
	if not self.AutoSave or self._loading or self._savePending or self._destroyed then
		return
	end
	self._savePending = true
	task.delay(0.5, function()
		self._savePending = false
		if not self._destroyed then
			self:SaveConfig(self.ConfigName)
		end
	end)
end

-- Configs ----------------------------------------------------------------------------

local function cleanName(name)
	name = tostring(name or ""):gsub("[^%w%-_ ]", "")
	if name == "" then
		return nil
	end
	return name
end

function MaUI:_ConfigPath(name)
	return self.ConfigFolder .. "/" .. name .. ".json"
end

-- Returns ok, error
function MaUI:SaveConfig(name)
	name = cleanName(name or self.ConfigName)
	if not name then
		return false, "invalid config name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local data = self:_CollectFlags()
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not okEncode then
		return false, tostring(encoded)
	end
	Env.EnsureFolder(self.ConfigFolder)
	local ok, err = Env.WriteFile(self:_ConfigPath(name), encoded)
	if ok then
		self.ConfigName = name
		return true
	end
	return false, tostring(err)
end

-- silent = true: applies the values without firing callbacks. Returns ok, error
function MaUI:LoadConfig(name, silent)
	name = cleanName(name or self.ConfigName)
	if not name then
		return false, "invalid config name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ConfigPath(name)
	if not Env.IsFile(path) then
		return false, "no config named " .. name
	end
	local okRead, content = Env.ReadFile(path)
	if not okRead then
		return false, tostring(content)
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not okDecode or type(data) ~= "table" then
		return false, "config unreadable (invalid JSON)"
	end
	self:_ApplyFlags(data, silent == true)
	self.ConfigName = name
	return true
end

-- Flag data of every persistent element: { [flag] = { Type, Value } }. Display-only elements are skipped.
function MaUI:_CollectFlags()
	local data = {}
	for flag, element in pairs(self.Flags) do
		if element.Persistent ~= false then
			data[flag] = { Type = element.Kind, Value = element:Serialize() }
		end
	end
	return data
end

function MaUI:_ApplyFlags(data, silent)
	self._loading = true -- avoids an auto-save while loading
	for flag, entry in pairs(data) do
		local element = self.Flags[flag]
		if element and type(entry) == "table" and entry.Type == element.Kind then
			local ok, err = pcall(element.Deserialize, element, entry.Value, silent)
			if not ok then
				warn("[MaUI] flag '" .. tostring(flag) .. "' not loaded: " .. tostring(err))
			end
		end
	end
	self._loading = false
end

function MaUI:DeleteConfig(name)
	name = cleanName(name)
	if not name then
		return false, "invalid config name"
	end
	local path = self:_ConfigPath(name)
	if not Env.IsFile(path) then
		return false, "no config named " .. name
	end
	local ok, err = Env.DeleteFile(path)
	if ok then
		return true
	end
	return false, tostring(err)
end

function MaUI:ListConfigs()
	local names = {}
	for _, path in ipairs(Env.ListFiles(self.ConfigFolder)) do
		path = tostring(path):gsub("\\", "/")
		local name = path:match("([^/]+)%.json$")
		-- direct children only: sub folders such as themes/ hold other kinds of files
		local parent = path:match("^(.*)/[^/]+$")
		if name and parent == self.ConfigFolder then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- Config management extras ----------------------------------------------------------------------

-- Renames a saved config. Returns ok, error
function MaUI:RenameConfig(old, new)
	old, new = cleanName(old), cleanName(new)
	if not old or not new then
		return false, "invalid config name"
	end
	if old == new then
		return true
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	if not Env.IsFile(self:_ConfigPath(old)) then
		return false, "no config named " .. old
	end
	if Env.IsFile(self:_ConfigPath(new)) then
		return false, "a config named " .. new .. " already exists"
	end
	local okRead, content = Env.ReadFile(self:_ConfigPath(old))
	if not okRead then
		return false, tostring(content)
	end
	local okWrite, err = Env.WriteFile(self:_ConfigPath(new), content)
	if not okWrite then
		return false, tostring(err)
	end
	Env.DeleteFile(self:_ConfigPath(old))
	if self.ConfigName == old then
		self.ConfigName = new
	end
	if self:GetAutoload() == old then
		self:SetAutoload(new)
	end
	return true
end

-- Restores every persistent element to its default value (silently). Returns how many were reset.
function MaUI:ResetConfig()
	local count = 0
	self._loading = true
	for _, element in pairs(self.Flags) do
		if element.Persistent ~= false and element.Reset then
			element:Reset(true)
			count = count + 1
		end
	end
	self._loading = false
	return count
end

function MaUI:_AutoloadPath()
	return self.ConfigFolder .. "/autoload.txt"
end

-- Marks a saved config to be applied by LoadAutoload(). nil clears it. Returns ok, error
function MaUI:SetAutoload(name)
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	if name == nil then
		if Env.IsFile(self:_AutoloadPath()) then
			Env.DeleteFile(self:_AutoloadPath())
		end
		return true
	end
	name = cleanName(name)
	if not name then
		return false, "invalid config name"
	end
	Env.EnsureFolder(self.ConfigFolder)
	return Env.WriteFile(self:_AutoloadPath(), name)
end

function MaUI:GetAutoload()
	if not Env.HasFS() or not Env.IsFile(self:_AutoloadPath()) then
		return nil
	end
	local ok, content = Env.ReadFile(self:_AutoloadPath())
	return ok and cleanName(content) or nil
end

-- Applies the autoload config if one is set (call it after your UI is built). Returns ok, error
function MaUI:LoadAutoload(silent)
	local name = self:GetAutoload()
	if not name then
		return false, "no autoload configured"
	end
	return self:LoadConfig(name, silent)
end

local EXPORT_PREFIX = "MAUI1:"

-- A shareable text code of the current flag values.
function MaUI:ExportConfig()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(self:_CollectFlags())
	end)
	if not ok then
		return nil, tostring(encoded)
	end
	return EXPORT_PREFIX .. encoded
end

-- Applies a code produced by ExportConfig. Invalid codes are rejected without changing anything.
function MaUI:ImportConfig(code, silent)
	if type(code) ~= "string" or code:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return false, "not a MaUI config code"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(code:sub(#EXPORT_PREFIX + 1))
	end)
	if not ok or type(data) ~= "table" then
		return false, "config code is corrupted"
	end
	self:_ApplyFlags(data, silent == true)
	return true
end

-- Custom themes -----------------------------------------------------------------------------------

function MaUI:_ThemeFolder()
	return self.ConfigFolder .. "/themes"
end

local function toHex(color)
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function fromHex(text)
	if type(text) ~= "string" or not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

-- Saves the CURRENT theme tokens (including live edits) under `name`. Returns ok, error
function MaUI:SaveTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local tokens = {}
	for token, color in pairs(self.Theme:Snapshot()) do
		tokens[token] = toHex(color)
	end
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(tokens)
	end)
	if not okEncode then
		return false, tostring(encoded)
	end
	Env.EnsureFolder(self.ConfigFolder)
	Env.EnsureFolder(self:_ThemeFolder())
	local ok, err = Env.WriteFile(self:_ThemeFolder() .. "/" .. name .. ".json", encoded)
	if not ok then
		return false, tostring(err)
	end
	-- register + select, so the saved theme is immediately a normal theme
	local colors = {}
	for token, hex in pairs(tokens) do
		colors[token] = fromHex(hex)
	end
	self.Theme:Register(name, colors, "Sakura")
	self.Theme:Set(name)
	return true
end

-- Loads a saved theme and applies it. Returns ok, error
function MaUI:LoadTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ThemeFolder() .. "/" .. name .. ".json"
	if not Env.IsFile(path) then
		return false, "no theme named " .. name
	end
	local okRead, content = Env.ReadFile(path)
	if not okRead then
		return false, tostring(content)
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not okDecode or type(data) ~= "table" then
		return false, "theme unreadable (invalid JSON)"
	end
	local colors = {}
	for token, hex in pairs(data) do
		local color = fromHex(hex)
		if color then
			colors[token] = color
		end
	end
	self.Theme:Register(name, colors, "Sakura")
	self.Theme:Set(name)
	return true
end

function MaUI:DeleteTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	local path = self:_ThemeFolder() .. "/" .. name .. ".json"
	if not Env.HasFS() or not Env.IsFile(path) then
		return false, "no theme named " .. tostring(name)
	end
	Env.DeleteFile(path)
	self.Theme:Remove(name)
	if self:GetDefaultTheme() == name then
		self:SetDefaultTheme(nil)
	end
	return true
end

-- Names of the saved custom themes.
function MaUI:ListThemes()
	local names = {}
	if Env.HasFS() then
		for _, path in ipairs(Env.ListFiles(self:_ThemeFolder())) do
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- The default theme is applied when the library is created. nil clears it (also accepts built-in theme names).
function MaUI:SetDefaultTheme(name)
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ThemeFolder() .. "/_default.txt"
	if name == nil then
		if Env.IsFile(path) then
			Env.DeleteFile(path)
		end
		return true
	end
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	Env.EnsureFolder(self.ConfigFolder)
	Env.EnsureFolder(self:_ThemeFolder())
	return Env.WriteFile(path, name)
end

function MaUI:GetDefaultTheme()
	local path = self:_ThemeFolder() .. "/_default.txt"
	if not Env.HasFS() or not Env.IsFile(path) then
		return nil
	end
	local ok, content = Env.ReadFile(path)
	return ok and cleanName(content) or nil
end

-- Cleanup ---------------------------------------------------------------------------

function MaUI:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self.Windows, 1, -1 do
		self.Windows[index]:Destroy()
	end
	for index = #self.Overlays, 1, -1 do
		self.Overlays[index]:Destroy()
	end
	self.Maid:Clean()
	self.Flags = {}
end

return MaUI
