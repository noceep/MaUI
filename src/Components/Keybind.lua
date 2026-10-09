-- Keybind: key assignable by the user.
--   AddKeybind({ Name = "Fly", Default = Enum.KeyCode.F, Flag = "fly_key",
--                Callback = function(key) end,     -- when the key is PRESSED
--                OnChanged = function(key) end })  -- when the key is reassigned
--   keybind:Set(Enum.KeyCode.G)  /  keybind:Set(false) to clear the key
-- Click the keycap, then press a key to reassign. Escape cancels, Backspace/Delete clears.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Keybind = Element.extend("Keybind")

local CAPTURE_TEXT = "Press a key..."
local CAP_WIDTH = 104

function Keybind.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Keybind" })
	local self = setmetatable({}, Keybind)
	Element.init(self, ctx, options)

	self.Listening = false
	self.Disabled = options.Disabled == true
	self.Pressed = Signal.new()
	self.Maid:Give(self.Pressed)

	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		RightWidth = CAP_WIDTH + Tokens.Space.Sm,
	})
	self.Frame = self.Row.Frame

	-- keycap-style button on the right (same look as Kit.Keycaps)
	local capHeight = ctx.Touch and ctx.Metrics.Compact or 24
	self.Chip = Create("TextButton", {
		Name = "Chip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(CAP_WIDTH, capHeight),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = self.Frame,
	})
	ctx.Theme:Bind(self.Chip, "BackgroundColor3", function(t)
		return t:Get(self.Listening and "AccentSoft" or "Surface3")
	end)
	Kit.Corner(self.Chip, Tokens.Radius.Sm - 2)
	self.ChipStroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = self.Chip,
	})
	ctx.Theme:Bind(self.ChipStroke, "Color", function(t)
		return self:_strokeColor(t)
	end)
	self.ChipLabel = Kit.Text(ctx, {
		Name = "Key",
		Size = UDim2.fromScale(1, 1),
		TextSize = Tokens.Type.Supporting.Size,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.Chip,
	}, function(t)
		return self:_textColor(t)
	end, "Bold")

	CK.Track(ctx, self.Maid, self.Chip, self, function()
		self:_renderChip()
	end)
	self.Maid:Give(self.Chip.MouseButton1Click:Connect(function()
		if not self.Disabled then
			self:_toggleListening()
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Chip, options.Tooltip)

	-- a single bind in the central registry; SetKey moves it on reassignment
	self.Bind = ctx.Input:BindKey(nil, function()
		self.Pressed:Fire(self.Value or nil)
		Util.Call(options.Callback, self.Value or nil)
	end)
	self.Maid:Give(self.Bind)
	self.Maid:Give(function()
		if self.Listening then
			ctx.Input:CancelKeyCapture()
		end
	end)

	self:_init(options.Default)
	return self
end

-- false = no key
function Keybind:_normalize(value)
	if value == nil or value == false then
		return false
	end
	local key = Util.ParseKey(value)
	if key == nil then
		return nil
	end
	return key
end

function Keybind:_render(value)
	self.Bind:SetKey(value or nil)
	self:_renderChip()
end

function Keybind:_strokeColor(theme)
	if self.Listening then
		return theme:Get("Accent")
	end
	return theme:Get((self._hover and not self.Disabled) and "StrokeHover" or "Stroke")
end

function Keybind:_textColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	if self.Listening then
		return theme:Get("Accent")
	end
	return theme:Get(self.Value and "Text" or "Muted")
end

function Keybind:_renderChip()
	if self.Destroyed then
		return
	end
	self.ChipLabel.Text = self.Listening and CAPTURE_TEXT or Util.KeyName(self.Value or nil)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local pressed = self._pressed and not self.Disabled
	tween:To(self.ChipStroke, { Color = self:_strokeColor(theme) }, Tokens.Motion.Fast)
	tween:To(self.ChipLabel, { TextColor3 = self:_textColor(theme) }, Tokens.Motion.Fast)
	tween:To(self.Chip, {
		BackgroundColor3 = theme:Get(self.Listening and "AccentSoft" or "Surface3"),
		BackgroundTransparency = self.Disabled and 0.5 or (pressed and 0.3 or 0),
	}, Tokens.Motion.Fast)
	CK.Dim(ctx, self.Row, self.Disabled, Tokens.Motion.Fast)
end

function Keybind:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		if self.Listening then
			self.Ctx.Input:CancelKeyCapture()
		end
	end
	self:_renderChip()
end

function Keybind:_toggleListening()
	local input = self.Ctx.Input
	if self.Listening then
		input:CancelKeyCapture()
		return
	end
	self.Listening = true
	self:_renderChip()
	input:CaptureKey(function(keyCode)
		self.Listening = false
		if self.Destroyed then
			return
		end
		if keyCode == nil or keyCode == Enum.KeyCode.Escape then
			self:_renderChip()
		elseif keyCode == Enum.KeyCode.Backspace or keyCode == Enum.KeyCode.Delete then
			self:Set(false)
			self:_renderChip()
		else
			self:Set(keyCode)
			self:_renderChip()
		end
	end)
end

-- Callback = key pressed; OnChanged = key reassigned
function Keybind:_callback(value)
	Util.Call(self.Options.OnChanged, value or nil)
end

function Keybind:Get()
	return self.Value or nil
end

function Keybind:Serialize()
	return self.Value and self.Value.Name or false
end

return Keybind
