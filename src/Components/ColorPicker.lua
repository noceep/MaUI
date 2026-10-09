-- ColorPicker: Color3 value edited in a popup (saturation/value square, hue bar, hex field, presets).
--   AddColorPicker({ Name = "Accent", Default = Color3.fromRGB(255, 158, 200), Flag = "accent", Live = true,
--                    Presets = { Color3.fromRGB(...), ... }, Disabled = false, Callback = function(color) end })
--   picker:Set(Color3 | "FF9EC8") / Get() -> Color3 / SetDisabled(true) / Open() / Close()
-- Config value: "RRGGBB" hex string. Live = true fires the callback while dragging (once per input event).
-- Perf: dragging only moves two handles and recolors one frame; no tweens, no per-frame loop.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local ColorPicker = Element.extend("ColorPicker")

local DEFAULT_PRESETS = {
	Color3.fromRGB(255, 158, 200), Color3.fromRGB(255, 120, 130), Color3.fromRGB(246, 190, 120), Color3.fromRGB(140, 224, 170),
	Color3.fromRGB(150, 190, 255), Color3.fromRGB(190, 150, 255), Color3.fromRGB(248, 232, 240), Color3.fromRGB(40, 24, 34),
}

local function toHex(color)
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function parseHex(text)
	text = tostring(text):gsub("^#", "")
	if not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

function ColorPicker.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Color", Default = Color3.fromRGB(255, 158, 200), Live = true, Presets = DEFAULT_PRESETS })
	local self = setmetatable({}, ColorPicker)
	Element.init(self, ctx, options)
	self.Disabled = options.Disabled == true
	self.Opened = false
	self.H, self.S, self.V = 0, 1, 1

	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon, Order = order, Clickable = true, RightWidth = 96 })
	self.Frame = self.Row.Frame
	self.Swatch = Create("Frame", {
		Name = "Swatch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(ctx.Touch and 30 or 24, ctx.Touch and 30 or 24), BorderSizePixel = 0, Parent = self.Frame,
	})
	Kit.Corner(self.Swatch, Radius.Sm)
	self.SwatchStroke = Kit.Stroke(ctx, self.Swatch, "StrokeHover")
	self.HexLabel = Kit.Text(ctx, {
		Name = "Hex", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(60, 16),
		TextSize = Tokens.Type.Supporting.Size, TextXAlignment = Enum.TextXAlignment.Right, Parent = self.Frame,
	}, "Muted", "Medium")

	CK.Track(ctx, self.Maid, self.Frame, self, function()
		CK.RowBackground(ctx, self.Frame, self, self.Disabled, Motion.Fast)
	end)
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		if self.Disabled then
			return
		end
		if self.Opened then
			self:Close()
		else
			self:Open()
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)
	self.Maid:Give(function()
		self:Close()
	end)
	self:_init(options.Default)
	CK.Dim(ctx, self.Row, self.Disabled, 0)
	return self
end

function ColorPicker:_normalize(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		return parseHex(value)
	end
	return nil
end

function ColorPicker:_equals(a, b)
	return toHex(a) == toHex(b)
end

function ColorPicker:_render(color)
	self.H, self.S, self.V = color:ToHSV()
	self.Swatch.BackgroundColor3 = color
	self.HexLabel.Text = "#" .. toHex(color)
	if self.Opened then
		self:_syncPopup()
	end
end

function ColorPicker:Serialize()
	return toHex(self.Value)
end

function ColorPicker:Deserialize(data, silent)
	self:Set(data, silent)
end

function ColorPicker:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self:Close()
	end
	CK.Dim(self.Ctx, self.Row, self.Disabled, Motion.Fast)
	self.Ctx.Tween:To(self.Swatch, { BackgroundTransparency = self.Disabled and 0.5 or 0 }, Motion.Fast)
end

-- Applies a color coming from the popup (drag, hex, preset): updates the value and fires the callback if Live
-- (or when `final`).
function ColorPicker:_fromHSV(h, s, v, final)
	local color = Color3.fromHSV(h, s, v)
	self.H, self.S, self.V = h, s, v
	if self:_equals(self.Value, color) then
		self:_syncPopup()
		return
	end
	self.Value = color
	self.Swatch.BackgroundColor3 = color
	self.HexLabel.Text = "#" .. toHex(color)
	self:_syncPopup()
	if self.Options.Live or final then
		self:_emit(color)
	else
		self._pending = true
	end
end

function ColorPicker:Open()
	if self.Opened or self.Disabled or self.Destroyed then
		return
	end
	local ctx = self.Ctx
	self.Opened = true
	self._popup = ctx.Popup:Open({
		Anchor = self.Swatch, Align = "Right", Width = 232, Height = 252,
		OnClose = function()
			self.Opened = false
			self._popup, self._ui = nil, nil
			if self._pending then
				self._pending = false
				self:_emit(self.Value)
			end
		end,
		Build = function(frame)
			self:_build(frame)
		end,
	})
end

function ColorPicker:_build(frame)
	local ctx = self.Ctx
	local ui = {}
	self._ui = ui
	Kit.Padding(frame, Space.Md, Space.Md, Space.Md, Space.Md)

	-- saturation / value square: base hue + white gradient (left->right) + black gradient (top->bottom)
	ui.Square = Create("TextButton", { Name = "SV", Size = UDim2.new(1, 0, 0, 130), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = frame })
	Kit.Corner(ui.Square, Radius.Sm)
	local white = Create("Frame", { Name = "White", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ui.Square })
	Kit.Corner(white, Radius.Sm)
	Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = Create("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ui.Square })
	Kit.Corner(black, Radius.Sm)
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	ui.Cursor = Create("Frame", { Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = ui.Square })
	Kit.Corner(ui.Cursor, 12)
	Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = ui.Cursor })

	-- hue bar
	ui.Hue = Create("TextButton", { Name = "Hue", Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 14), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = frame })
	Kit.Corner(ui.Hue, 7)
	local stops = {}
	for i = 0, 6 do
		stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0.999 or i / 6, 1, 1))
	end
	Create("UIGradient", { Color = ColorSequence.new(stops), Parent = ui.Hue })
	ui.HueCursor = Create("Frame", { Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 18), BorderSizePixel = 0, ZIndex = 3, Parent = ui.Hue })
	Kit.Corner(ui.HueCursor, 3)
	Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = ui.HueCursor })

	-- hex field + RGB readout
	ui.Hex = Create("TextBox", {
		Name = "HexInput", Position = UDim2.fromOffset(0, 160), Size = UDim2.fromOffset(86, 26), BorderSizePixel = 0, Text = "", PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false, TextSize = 13, FontFace = ctx.Fonts.Medium, Parent = frame,
	})
	ctx.Theme:Bind(ui.Hex, "BackgroundColor3", "Surface2")
	ctx.Theme:Bind(ui.Hex, "TextColor3", "Text")
	ctx.Theme:Bind(ui.Hex, "PlaceholderColor3", "Faint")
	Kit.Corner(ui.Hex, Radius.Sm)
	ui.HexStroke = Kit.Stroke(ctx, ui.Hex, "Stroke")
	ui.RGB = Kit.Text(ctx, { Name = "RGB", Position = UDim2.fromOffset(94, 160), Size = UDim2.new(1, -94, 0, 26), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = frame }, "Muted", "Regular")
	self.Maid:Give(ui.Hex.FocusLost:Connect(function()
		local color = parseHex(ui.Hex.Text)
		if color then
			ctx.Theme:Bind(ui.HexStroke, "Color", "Stroke")
			self:Set(color)
		else
			ctx.Theme:Bind(ui.HexStroke, "Color", "Error")
			ui.Hex.Text = "#" .. toHex(self.Value)
		end
	end))

	-- presets
	local presets = Create("Frame", { Name = "Presets", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 44), Parent = frame })
	Create("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = presets })
	for index, color in ipairs(self.Options.Presets or {}) do
		local swatch = Create("TextButton", { Name = "Preset", BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = index, Parent = presets })
		Kit.Corner(swatch, Radius.Sm)
		Kit.Stroke(ctx, swatch, "Stroke")
		swatch.MouseButton1Click:Connect(function()
			self:Set(color)
		end)
	end

	-- drags: both areas share one handler that maps the pointer into their local space
	local function bindDrag(area, onMove)
		self.Maid:Give(area.InputBegan:Connect(function(input)
			if Input.IsPointerDown(input) then
				onMove(input.Position)
				ctx.Input:Capture(self, input, function(moveInput)
					onMove(moveInput.Position)
				end, function()
					if self._pending then
						self._pending = false
						self:_emit(self.Value)
					end
				end)
			end
		end))
	end
	bindDrag(ui.Square, function(position)
		local size, origin = ui.Square.AbsoluteSize, ui.Square.AbsolutePosition
		local s = Util.Clamp((position.X - origin.X) / math.max(size.X, 1), 0, 1)
		local v = 1 - Util.Clamp((position.Y - origin.Y) / math.max(size.Y, 1), 0, 1)
		self:_fromHSV(self.H, s, v)
	end)
	bindDrag(ui.Hue, function(position)
		local size, origin = ui.Hue.AbsoluteSize, ui.Hue.AbsolutePosition
		local h = Util.Clamp((position.X - origin.X) / math.max(size.X, 1), 0, 0.999)
		self:_fromHSV(h, self.S, self.V)
	end)
	self:_syncPopup()
end

-- Repositions the cursors and recolors the square for the current value.
function ColorPicker:_syncPopup()
	local ui = self._ui
	if not ui then
		return
	end
	ui.Square.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	ui.Cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
	ui.HueCursor.Position = UDim2.fromScale(self.H, 0.5)
	ui.HueCursor.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	ui.Hex.Text = "#" .. toHex(self.Value)
	ui.RGB.Text = string.format("%d, %d, %d", math.floor(self.Value.R * 255 + 0.5), math.floor(self.Value.G * 255 + 0.5), math.floor(self.Value.B * 255 + 0.5))
end

function ColorPicker:Close()
	local popup = self._popup
	if popup then
		popup:Close()
	end
end

function ColorPicker:IsOpen()
	return self.Opened
end

return ColorPicker
