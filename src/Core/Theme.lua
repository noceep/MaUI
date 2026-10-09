-- Theme: color tokens + binding registry.
-- Instances register on a token (or a function): a theme change
-- updates the registry without recreating anything.
local Signal = require("Core/Signal")
local Util = require("Core/Util")

local Theme = {}
Theme.__index = Theme

-- Token reference (every color used by the library comes from here):
--   Background  window / sidebar base          Surface   cards, header strips
--   Surface2    controls on a card             Surface3  hover / pressed / tracks
--   Stroke / StrokeHover   borders             Accent / AccentText   primary color and text on it
--   AccentSoft  tinted container (active nav item, badges)
--   Text / Muted / Faint   primary, secondary, supporting text
--   Success / Warning / Error / Info   status colors      Backdrop   dim layer behind modal UI
Theme.Presets = {
	Sakura = {
		Background = Color3.fromRGB(24, 14, 20),
		Surface = Color3.fromRGB(35, 20, 29),
		Surface2 = Color3.fromRGB(45, 27, 37),
		Surface3 = Color3.fromRGB(64, 40, 53),
		Stroke = Color3.fromRGB(58, 36, 48),
		StrokeHover = Color3.fromRGB(120, 78, 100),
		Accent = Color3.fromRGB(255, 158, 200),
		AccentText = Color3.fromRGB(40, 12, 26),
		AccentSoft = Color3.fromRGB(72, 36, 55),
		Text = Color3.fromRGB(248, 232, 240),
		Muted = Color3.fromRGB(150, 112, 132),
		Faint = Color3.fromRGB(104, 76, 92),
		Success = Color3.fromRGB(140, 224, 170),
		Warning = Color3.fromRGB(246, 190, 120),
		Error = Color3.fromRGB(242, 120, 130),
		Info = Color3.fromRGB(150, 190, 255),
		Backdrop = Color3.fromRGB(8, 4, 6),
	},
	Dark = {
		Background = Color3.fromRGB(18, 18, 22),
		Surface = Color3.fromRGB(26, 26, 32),
		Surface2 = Color3.fromRGB(33, 33, 41),
		Surface3 = Color3.fromRGB(48, 48, 58),
		Stroke = Color3.fromRGB(44, 44, 54),
		StrokeHover = Color3.fromRGB(86, 86, 108),
		Accent = Color3.fromRGB(110, 140, 255),
		AccentText = Color3.fromRGB(14, 16, 28),
		AccentSoft = Color3.fromRGB(36, 42, 76),
		Text = Color3.fromRGB(232, 232, 238),
		Muted = Color3.fromRGB(140, 140, 156),
		Faint = Color3.fromRGB(94, 94, 108),
		Success = Color3.fromRGB(120, 214, 150),
		Warning = Color3.fromRGB(240, 182, 110),
		Error = Color3.fromRGB(240, 110, 110),
		Info = Color3.fromRGB(130, 180, 255),
		Backdrop = Color3.fromRGB(4, 4, 8),
	},
	Light = {
		Background = Color3.fromRGB(244, 244, 248),
		Surface = Color3.fromRGB(255, 255, 255),
		Surface2 = Color3.fromRGB(238, 238, 244),
		Surface3 = Color3.fromRGB(214, 216, 226),
		Stroke = Color3.fromRGB(220, 222, 232),
		StrokeHover = Color3.fromRGB(160, 164, 190),
		Accent = Color3.fromRGB(70, 100, 235),
		AccentText = Color3.fromRGB(255, 255, 255),
		AccentSoft = Color3.fromRGB(222, 228, 252),
		Text = Color3.fromRGB(24, 24, 32),
		Muted = Color3.fromRGB(110, 112, 128),
		Faint = Color3.fromRGB(160, 162, 176),
		Success = Color3.fromRGB(40, 160, 90),
		Warning = Color3.fromRGB(200, 130, 30),
		Error = Color3.fromRGB(210, 60, 60),
		Info = Color3.fromRGB(50, 120, 220),
		Backdrop = Color3.fromRGB(60, 60, 70),
	},
}

function Theme.new(name)
	local self = setmetatable({}, Theme)
	self._themes = {}
	self._base = {} -- pristine copy of a theme edited through SetToken (restored by Set)
	for themeName, tokens in pairs(Theme.Presets) do
		self._themes[themeName] = Util.Copy(tokens)
	end
	-- weak keys: a destroyed instance is not kept referenced by the registry
	self._bindings = setmetatable({}, { __mode = "k" })
	self.Changed = Signal.new()
	self.Tokens = self._themes.Sakura
	self.Name = "Sakura"
	if name and not self:Set(name) then
		warn("[MaUI] unknown theme, falling back to Sakura: " .. tostring(name))
	end
	return self
end

-- Registers (or replaces) a theme. `tokens` may be partial: the rest comes from `base`.
function Theme:Register(name, tokens, base)
	local merged = Util.Copy(self._themes[base or "Sakura"] or Theme.Presets.Sakura)
	for token, value in pairs(tokens) do
		merged[token] = value
	end
	self._themes[name] = merged
	self._base[name] = nil
end

-- Names of every registered theme, sorted.
function Theme:List()
	local names = {}
	for name in pairs(self._themes) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Copy of the current theme's tokens.
function Theme:Has(name)
	return self._themes[name] ~= nil
end

function Theme:Snapshot()
	return Util.Copy(self.Tokens)
end

-- Unregisters a theme. Built-in presets and the active theme cannot be removed.
function Theme:Remove(name)
	if Theme.Presets[name] or name == self.Name or not self._themes[name] then
		return false
	end
	self._themes[name] = nil
	self._base[name] = nil
	return true
end

function Theme:Get(token)
	return self.Tokens[token]
end

local function resolve(self, source)
	if type(source) == "function" then
		return source(self)
	end
	return self.Tokens[source]
end

-- Binds `instance[property]` to a token ("Accent") or to a function(theme) -> value.
function Theme:Bind(instance, property, source)
	local properties = self._bindings[instance]
	if not properties then
		properties = {}
		self._bindings[instance] = properties
	end
	properties[property] = source
	local value = resolve(self, source)
	if value ~= nil then
		instance[property] = value
	end
	return instance
end

function Theme:Unbind(instance, property)
	local properties = self._bindings[instance]
	if properties then
		properties[property] = nil
	end
end

-- Releases the bindings of an instance and all its descendants (call before Destroy).
function Theme:Release(root)
	self._bindings[root] = nil
	for _, descendant in ipairs(root:GetDescendants()) do
		self._bindings[descendant] = nil
	end
end

-- Changes ONE token of the current theme and recolors only the bindings that can depend on it
-- (direct token bindings + function bindings). Nothing is recreated. Fires Changed.
-- Edits are live previews: Theme:Set(name) later restores the theme's pristine tokens.
function Theme:SetToken(token, color)
	if type(token) ~= "string" or self.Tokens[token] == nil or typeof(color) ~= "Color3" then
		return false
	end
	if self.Tokens[token] == color then
		return true
	end
	if not self._base[self.Name] then
		self._base[self.Name] = Util.Copy(self.Tokens)
	end
	self.Tokens[token] = color
	for instance, properties in pairs(self._bindings) do
		for property, source in pairs(properties) do
			if source == token or type(source) == "function" then
				local value = resolve(self, source)
				if value ~= nil then
					instance[property] = value
				end
			end
		end
	end
	self.Changed:Fire(self.Name)
	return true
end

function Theme:Set(name)
	local tokens = self._themes[name]
	if not tokens then
		return false
	end
	local base = self._base[name]
	if base then -- discard unsaved live edits
		for token, value in pairs(base) do
			tokens[token] = value
		end
		self._base[name] = nil
	end
	self.Name = name
	self.Tokens = tokens
	for instance, properties in pairs(self._bindings) do
		for property, source in pairs(properties) do
			local value = resolve(self, source)
			if value ~= nil then
				instance[property] = value
			end
		end
	end
	self.Changed:Fire(name)
	return true
end

return Theme
