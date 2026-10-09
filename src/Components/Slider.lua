-- Slider: numeric value over a range, on a transparent row.
--   AddSlider({ Name = "Speed", Desc = "...", Icon = "bolt", Min = 0, Max = 100, Step = 1, Default = 16,
--               Suffix = " sps", Flag = "speed", Disabled = false, Tooltip = "...",
--               Callback = function(value) end })
--   slider:Set(50)  /  slider:Set(50, true) to skip the callback  /  slider:SetDisabled(true)
-- Layout: label on the left, value pill on the right, track + fill + handle in a row beneath.
-- States: default / hover / dragging / disabled. Step = 0 (or less) gives a continuous slider.
--
-- Perf: during a drag the value is set DIRECTLY (no tween) and the callback only fires when the
-- snapped value actually changes. Only a temporary listener (Input:Capture) exists while dragging.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Slider = Element.extend("Slider")

local TRACK_HEIGHT = 4
local HANDLE = 14
local HANDLE_ACTIVE = 18

function Slider.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Slider", Min = 0, Max = 100, Step = 1, Suffix = "" })
	if type(options.Min) ~= "number" or type(options.Max) ~= "number" or options.Max <= options.Min then
		error("[MaUI] Slider '" .. tostring(options.Name) .. "': Max must be greater than Min", 3)
	end
	local self = setmetatable({}, Slider)
	Element.init(self, ctx, options)

	self.Min, self.Max = options.Min, options.Max
	local step = tonumber(options.Step) or 0
	self.Continuous = step <= 0
	self.Step = self.Continuous and (self.Max - self.Min) / 1000 or step
	self.Decimals = self.Continuous and 2 or Util.Decimals(self.Step)
	self.Dragging = false
	self.Disabled = options.Disabled == true

	local top = options.Desc and (ctx.Metrics.Control + 18) or ctx.Metrics.Control
	local trackArea = ctx.Touch and 26 or 20
	local pillWidth = 56
	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		Height = top,
		RightWidth = pillWidth,
	})
	self.Frame = self.Row.Frame
	self.Frame.Size = UDim2.new(1, 0, 0, top + trackArea)
	local holder = self.Row.Holder
	holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, top)
	if self.Row.Icon then
		self.Row.Icon.Position = UDim2.new(0, 0, 0, (top - 16) / 2)
	end

	-- value pill (top right)
	self.Pill = Kit.Frame(ctx, {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, top / 2),
		Size = UDim2.new(0, 0, 0, ctx.Metrics.Chip - 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = self.Frame,
	}, "Surface3")
	Kit.Corner(self.Pill, Tokens.Radius.Sm)
	Kit.Padding(self.Pill, 8, 8, 0, 0)
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Text",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Tokens.Type.Supporting.Size + 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = self.Pill,
	}, function(t)
		return self:_valueColor(t)
	end, "Medium")

	-- track + fill + handle
	local trackY = top + trackArea / 2 - TRACK_HEIGHT / 2 - 2
	self.Track = Kit.Frame(ctx, {
		Name = "Track",
		Position = UDim2.new(0, 0, 0, trackY),
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		Parent = self.Frame,
	}, "Surface3")
	Kit.Corner(self.Track, Tokens.Radius.Pill)
	self.Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = self.Track,
	})
	ctx.Theme:Bind(self.Fill, "BackgroundColor3", function(t)
		return self:_fillColor(t)
	end)
	Kit.Corner(self.Fill, Tokens.Radius.Pill)
	self.Handle = Create("Frame", {
		Name = "Handle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(HANDLE, HANDLE),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = self.Track,
	})
	ctx.Theme:Bind(self.Handle, "BackgroundColor3", function(t)
		return self:_handleColor(t)
	end)
	Kit.Corner(self.Handle, Tokens.Radius.Pill)
	self.HandleStroke = Create("UIStroke", { Thickness = 2, Transparency = 0, Parent = self.Handle })
	ctx.Theme:Bind(self.HandleStroke, "Color", "Surface2")
	-- alias kept for older code
	self.Knob = self.Handle

	-- enlarged hit area (easier to aim at, especially with a finger)
	local hitHeight = ctx.Touch and ctx.Metrics.Control or 22
	self.Hit = Create("TextButton", {
		Name = "Hit",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, trackY + TRACK_HEIGHT / 2),
		Size = UDim2.new(1, 0, 0, hitHeight),
		ZIndex = 3,
		Parent = self.Frame,
	})
	CK.Track(ctx, self.Maid, self.Hit, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Hit.InputBegan:Connect(function(input)
		if not self.Disabled and Input.IsPointerDown(input) then
			self:_beginDrag(input)
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)

	self:_init(options.Default ~= nil and options.Default or self.Min)
	return self
end

function Slider:_active()
	return self.Dragging and not self.Disabled
end

function Slider:_fillColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	return theme:Get("Accent")
end

function Slider:_handleColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	if self:_active() or self._hover then
		return theme:Get("Accent")
	end
	return theme:Get("Text")
end

function Slider:_valueColor(theme)
	return theme:Get(self.Disabled and "Faint" or "Accent")
end

function Slider:_beginDrag(input)
	self.Dragging = true
	self:_visual(true)
	self:_fromPointer(input.Position.X)
	self.Ctx.Input:Capture(self, input, function(moveInput)
		self:_fromPointer(moveInput.Position.X)
	end, function()
		self.Dragging = false
		if not self.Destroyed then
			self:_visual(true)
		end
	end)
end

function Slider:_fromPointer(x)
	local width = self.Track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local alpha = Util.Clamp((x - self.Track.AbsolutePosition.X) / width, 0, 1)
	self:Set(self.Min + (self.Max - self.Min) * alpha)
end

function Slider:_normalize(value)
	value = tonumber(value)
	if not value or value ~= value then
		return nil
	end
	return Util.Snap(value, self.Min, self.Max, self.Step, self.Decimals)
end

-- Repaints what depends on hover / dragging / disabled (never on the value).
function Slider:_visual(animate)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local fast = animate and Tokens.Motion.Fast or 0
	local active = self:_active()
	local size = active and HANDLE_ACTIVE or ((self._hover and not self.Disabled) and HANDLE + 2 or HANDLE)
	tween:To(self.Handle, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = self:_handleColor(theme),
	}, fast, nil, nil, true)
	tween:To(self.Fill, { BackgroundColor3 = self:_fillColor(theme) }, fast)
	tween:To(self.Track, { Size = UDim2.new(1, 0, 0, (active or self._hover) and not self.Disabled and TRACK_HEIGHT + 2 or TRACK_HEIGHT) }, fast, nil, nil, true)
	tween:To(self.ValueLabel, { TextColor3 = self:_valueColor(theme) }, fast)
	tween:To(self.Pill, { BackgroundTransparency = self.Disabled and 0.5 or 0 }, fast)
	CK.Dim(ctx, self.Row, self.Disabled, fast)
end

function Slider:_render(value, animate)
	local alpha = (value - self.Min) / (self.Max - self.Min)
	self.ValueLabel.Text = Util.FormatNumber(value, self.Decimals) .. self.Options.Suffix
	local tween = self.Ctx.Tween
	-- never tween during a drag: the value follows the pointer directly
	local duration = (animate and not self.Dragging) and 0.15 or 0
	tween:To(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
	tween:To(self.Handle, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
end

function Slider:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		if self.Ctx.Input:IsCapturing(self) then
			self.Ctx.Input:Release(self)
			self.Dragging = false
		end
	end
	if not self.Destroyed then
		self:_visual(true)
	end
end

function Slider:Destroy()
	if self.Ctx.Input:IsCapturing(self) then
		self.Ctx.Input:Release(self)
	end
	Element.Destroy(self)
end

return Slider
