-- Toggle: boolean switch (38x20 track with a knob) on a transparent row.
--   AddToggle({ Name = "Auto", Desc = "...", Icon = "bolt", Default = false, Flag = "auto",
--               Disabled = false, Tooltip = "Runs automatically", Callback = function(on) end })
--   toggle:Set(true)  /  toggle:Set(true, true) to skip the callback
--   toggle:SetDisabled(true)   -- user input is ignored, programmatic Set still works
-- States: OFF / ON / hover / pressed / disabled.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Toggle = Element.extend("Toggle")

local INSET = 3

function Toggle.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Toggle", Default = false })
	local self = setmetatable({}, Toggle)
	Element.init(self, ctx, options)

	local touch = ctx.Touch
	local width, height = 38, 20
	if touch then
		width, height = 46, 24
	end
	local knob = height - INSET * 2
	self._pillWidth, self._knobSize, self._knobPressed = width, knob, knob + 4
	self.Disabled = options.Disabled == true

	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		Clickable = true,
		RightWidth = width + Tokens.Space.Sm,
	})
	self.Frame = self.Row.Frame
	local theme = ctx.Theme

	self.Pill = Create("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		BorderSizePixel = 0,
		Parent = self.Frame,
	})
	Kit.Corner(self.Pill, Tokens.Radius.Pill)
	-- the bindings read the current state: a theme change stays consistent
	theme:Bind(self.Pill, "BackgroundColor3", function(t)
		return self:_trackColor(t)
	end)
	self.Knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(knob, knob),
		BorderSizePixel = 0,
		Parent = self.Pill,
	})
	Kit.Corner(self.Knob, Tokens.Radius.Pill)
	theme:Bind(self.Knob, "BackgroundColor3", function(t)
		return self:_knobColor(t)
	end)

	CK.Track(ctx, self.Maid, self.Frame, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		if not self.Disabled then
			self:Set(not self.Value)
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)

	self:_init(options.Default)
	return self
end

function Toggle:_trackColor(theme)
	if self.Value then
		return theme:Get("Accent")
	end
	if not self.Disabled then
		if self._pressed then
			return theme:Get("Faint")
		elseif self._hover then
			return theme:Get("StrokeHover")
		end
	end
	return theme:Get("Surface3")
end

function Toggle:_knobColor(theme)
	return self.Value and theme:Get("AccentText") or theme:Get(self._hover and not self.Disabled and "Text" or "Muted")
end

function Toggle:_normalize(value)
	return value == true
end

-- Repaints everything that depends on (value, hover, pressed, disabled).
function Toggle:_visual(animate)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local duration = animate and Tokens.Motion.Base or 0
	local fast = animate and Tokens.Motion.Fast or 0
	local disabled = self.Disabled
	local pressed = self._pressed and not disabled
	local knobWidth = pressed and self._knobPressed or self._knobSize
	local x = self.Value and (self._pillWidth - INSET - knobWidth) or INSET

	tween:To(self.Pill, {
		BackgroundColor3 = self:_trackColor(theme),
		BackgroundTransparency = disabled and 0.55 or ((pressed and self.Value) and 0.2 or 0),
	}, duration)
	tween:To(self.Knob, {
		Position = UDim2.new(0, x, 0.5, 0),
		Size = UDim2.fromOffset(knobWidth, self._knobSize),
		BackgroundColor3 = self:_knobColor(theme),
		BackgroundTransparency = disabled and 0.35 or 0,
	}, duration)
	CK.RowBackground(ctx, self.Frame, self, disabled, fast)
	CK.Dim(ctx, self.Row, disabled, fast)
end

function Toggle:_render(_, animate)
	self:_visual(animate)
end

function Toggle:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
	end
	if not self.Destroyed then
		self:_visual(true)
	end
end

function Toggle:Toggle()
	self:Set(not self.Value)
end

return Toggle
