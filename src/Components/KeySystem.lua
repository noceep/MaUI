-- KeySystem: key entry window, to be shown BEFORE creating the main window.
--
--   local gate = ui:KeySystem({
--       Title = "My Project",
--       Note = "Get your key on our Discord.",
--       Link = "https://discord.gg/xxxx",            -- "Get key" button (copies the link)
--       Keys = { "ABC-123" },                        -- fixed list (optional)
--       Validate = function(key)                     -- optional, may yield (HttpGet...)
--           return true, { ExpiresIn = 86400 }       -- ok, info (ExpiresIn in seconds or ExpiresAt as a timestamp)
--           -- return false, "Key revoked"           -- rejection + message shown
--       end,
--       SaveKey = true,                              -- remembers the key (<ConfigFolder>/key.txt)
--       OnSuccess = function(key, info) end,
--   })
--   local ok = gate:Wait()                           -- blocks until validated (true) or closed (false)
--   if not ok then return end
--
-- IMPORTANT: this check runs on the player's machine, so it protects nothing on its own.
-- For real protection, `Validate` must query YOUR server (which decides and sets the expiry).
-- The saved key is revalidated on every launch: local expiry is never taken at face value.
local Env = require("Core/Env")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Util = require("Core/Util")

local Create = Util.Create

local KeySystem = {}
KeySystem.__index = KeySystem

local MAX_WIDTH = 360

function KeySystem.new(library, options)
	options = Util.Options(options, {
		Title = "Key system",
		Note = "Enter your key to continue.",
		Placeholder = "Enter your key...",
		CheckText = "Check key",
		LinkText = "Get key",
		SaveKey = true,
		Cooldown = 1.5, -- seconds of lockout after a rejected key
	}, "Title")
	if type(options.Keys) ~= "table" and type(options.Validate) ~= "function" then
		error("[MaUI] KeySystem: provide `Keys` (list) and/or `Validate` (function)", 3)
	end

	local self = setmetatable({}, KeySystem)
	self.Library = library
	self.Options = options
	self.Maid = Maid.new()
	self.Passed = Signal.new() -- (key, info)
	self.Closed = Signal.new()
	self.Maid:Give(self.Passed)
	self.Maid:Give(self.Closed)
	self.Done = false
	self.Success = false
	self.Info = nil
	self.Destroyed = false
	self.Busy = false
	self.Locked = false
	self.KeyFile = options.KeyFile or (library.ConfigFolder .. "/key.txt")
	self._waiters = {}
	self._statusToken = "Muted"

	local saved = options.SaveKey and self:_readSaved() or nil
	if saved then
		-- saved key: revalidate it without showing the window (it only appears on failure)
		self.Busy = true
		task.spawn(function()
			local ok, info = self:_validate(saved)
			self.Busy = false
			if self.Done or self.Destroyed then
				return
			end
			if ok then
				self:_finish(true, saved, info)
			else
				Env.DeleteFile(self.KeyFile)
				self:_buildUI()
			end
		end)
	else
		self:_buildUI()
	end
	return self
end

-- Saved key ---------------------------------------------------------------------

function KeySystem:_readSaved()
	if not Env.HasFS() or not Env.IsFile(self.KeyFile) then
		return nil
	end
	local ok, content = Env.ReadFile(self.KeyFile)
	if not ok then
		return nil
	end
	local key = Util.Trim(content)
	if key == "" then
		return nil
	end
	return key
end

-- Validation -------------------------------------------------------------------------

-- Returns ok, info|message
function KeySystem:_validate(key)
	local options = self.Options
	if type(options.Keys) == "table" then
		for _, valid in ipairs(options.Keys) do
			if valid == key then
				return true, nil
			end
		end
	end
	if type(options.Validate) == "function" then
		local called, ok, info = pcall(options.Validate, key)
		if not called then
			warn("[MaUI] error in Validate: " .. tostring(ok))
			return false, "Could not check the key. Try again."
		end
		if ok then
			return true, info
		end
		return false, type(info) == "string" and info or "Invalid key."
	end
	return false, "Invalid key."
end

function KeySystem:_finish(success, key, info)
	if self.Done then
		return
	end
	self.Done = true
	self.Success = success
	self.Info = info
	if success then
		local expiresAt = nil
		if type(info) == "table" then
			if type(info.ExpiresAt) == "number" then
				expiresAt = info.ExpiresAt
			elseif type(info.ExpiresIn) == "number" then
				expiresAt = self.Library.Clock() + info.ExpiresIn
			end
		end
		self.Library:_SetKey(key, expiresAt, info)
		if self.Options.SaveKey and Env.HasFS() then
			Env.EnsureFolder(self.Library.ConfigFolder)
			Env.WriteFile(self.KeyFile, key)
		end
	end
	self:_closeUI()
	if success then
		self.Passed:Fire(key, info)
		Util.Call(self.Options.OnSuccess, key, info)
	else
		self.Closed:Fire()
		Util.Call(self.Options.OnClose)
	end
	local waiters = self._waiters
	self._waiters = {}
	for _, thread in ipairs(waiters) do
		task.spawn(thread, success, info)
	end
end

-- Blocks the current thread until done. Returns success, info.
function KeySystem:Wait()
	if self.Done then
		return self.Success, self.Info
	end
	local thread, isMain = coroutine.running()
	if thread == nil or isMain == true then
		-- main thread (cannot yield): wait by polling
		while not self.Done do
			task.wait(0.1)
		end
		return self.Success, self.Info
	end
	self._waiters[#self._waiters + 1] = thread
	return coroutine.yield()
end

-- Interface ---------------------------------------------------------------------------

function KeySystem:_setStatus(text, token)
	self._statusToken = token
	if self.Status then
		self.Status.Text = text
		self.Status.TextColor3 = self.Library.Theme:Get(token)
	end
end

function KeySystem:_copyLink()
	local link = tostring(self.Options.Link)
	if Env.SetClipboard(link) then
		self:_setStatus("Link copied to clipboard.", "Success")
	else
		-- clipboard unavailable: show the link instead
		self:_setStatus(link, "Accent")
	end
end

function KeySystem:_submit()
	if self.Done or self.Destroyed or self.Busy or self.Locked or not self.Input then
		return
	end
	local key = Util.Trim(self.Input.Text)
	if key == "" then
		self:_setStatus("Enter a key first.", "Warning")
		return
	end
	self.Busy = true
	self:_setStatus("Checking key...", "Muted")
	task.spawn(function()
		local ok, info = self:_validate(key)
		self.Busy = false
		if self.Done or self.Destroyed then
			return
		end
		if ok then
			local message = type(info) == "table" and type(info.Message) == "string" and info.Message or "Key accepted."
			self:_setStatus(message, "Success")
			self:_finish(true, key, info)
		else
			self:_setStatus(tostring(info), "Error")
			self.Locked = true
			task.delay(self.Options.Cooldown, function()
				self.Locked = false
			end)
		end
	end)
end

function KeySystem:_buildUI()
	if self.Destroyed or self.Done or self.Gui then
		return
	end
	local library = self.Library
	local ctx = library.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local options = self.Options

	local gui = Create("ScreenGui", {
		Name = "KeySystem",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1001,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = Env.GetParent(library.Options.Parent)
	self.Gui = gui

	-- dimmed backdrop: also blocks clicks from reaching the game
	Create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		Parent = gui,
	})

	local card = Kit.Frame(ctx, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = gui,
	}, "Background")
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, math.huge), Parent = card })
	Kit.Corner(card, 10)
	Kit.Stroke(ctx, card, "Stroke")
	Kit.Padding(card, 18, 18, 16, 18)
	Kit.List(card, 10)

	-- title + close
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
		Parent = card,
	})
	Kit.Text(ctx, {
		Name = "Title",
		Text = tostring(options.Title),
		TextSize = 17,
		Size = UDim2.new(1, -34, 1, 0),
		Parent = header,
	}, "Text", "Bold")
	local close = Create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "×",
		TextSize = 22,
		FontFace = ctx.Fonts.Medium,
		Parent = header,
	})
	theme:Bind(close, "TextColor3", "Muted")
	self.Maid:Give(close.MouseButton1Click:Connect(function()
		self:_finish(false)
	end))

	if options.Note and options.Note ~= "" then
		Kit.Text(ctx, {
			Name = "Note",
			Text = tostring(options.Note),
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = card,
		}, "Muted", "Regular")
	end

	-- input field
	local inputFrame = Kit.Frame(ctx, {
		Name = "InputFrame",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		Parent = card,
	}, "Surface")
	Kit.Corner(inputFrame, 8)
	local inputStroke = Kit.Stroke(ctx, inputFrame, "Stroke")
	local input = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = tostring(options.Placeholder),
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		TextSize = 14,
		FontFace = ctx.Fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = inputFrame,
	})
	theme:Bind(input, "TextColor3", "Text")
	theme:Bind(input, "PlaceholderColor3", "Muted")
	self.Input = input
	self.Maid:Give(input.Focused:Connect(function()
		tween:To(inputStroke, { Color = theme:Get("Accent") }, 0.12)
	end))
	self.Maid:Give(input.FocusLost:Connect(function(enterPressed)
		tween:To(inputStroke, { Color = theme:Get("Stroke") }, 0.15)
		if enterPressed then
			self:_submit()
		end
	end))

	-- status message
	self.Status = Kit.Text(ctx, {
		Name = "Status",
		Text = "",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 4,
		Parent = card,
	}, "Muted", "Regular")
	theme:Bind(self.Status, "TextColor3", function(t)
		return t:Get(self._statusToken)
	end)

	-- buttons
	local row = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 5,
		Parent = card,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = row,
	})
	local function makeButton(name, text, primary, order, onClick)
		local button = Create("TextButton", {
			Name = name,
			Size = UDim2.new(0, 0, 0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			TextSize = 14,
			FontFace = ctx.Fonts.Medium,
			LayoutOrder = order,
			Parent = row,
		})
		theme:Bind(button, "BackgroundColor3", primary and "Accent" or "Surface2")
		theme:Bind(button, "TextColor3", primary and "AccentText" or "Text")
		Kit.Corner(button, 8)
		Kit.Padding(button, 18, 18, 0, 0)
		if not primary then
			Kit.Stroke(ctx, button, "Stroke")
		end
		self.Maid:Give(button.MouseButton1Click:Connect(onClick))
		return button
	end
	if options.Link then
		makeButton("GetKey", tostring(options.LinkText), false, 1, function()
			self:_copyLink()
		end)
	end
	self.CheckButton = makeButton("Check", tostring(options.CheckText), true, 2, function()
		self:_submit()
	end)
end

function KeySystem:_closeUI()
	local gui = self.Gui
	if gui then
		self.Gui = nil
		self.Input = nil
		self.Status = nil
		self.Library.Theme:Release(gui)
		gui:Destroy()
	end
end

function KeySystem:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	if not self.Done then
		self:_finish(false)
	end
	self:_closeUI()
	self.Maid:Clean()
end

return KeySystem
