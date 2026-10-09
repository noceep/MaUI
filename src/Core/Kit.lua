-- Kit: small shared UI builders (cards, texts, hover...).
-- Everything is bound to the theme via ctx.Theme:Bind, nothing is hardcoded.
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Kit = {}

function Kit.Corner(parent, radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function Kit.Stroke(ctx, parent, token, thickness)
	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Parent = parent,
	})
	ctx.Theme:Bind(stroke, "Color", token or "Stroke")
	return stroke
end

function Kit.Padding(parent, left, right, top, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		Parent = parent,
	})
end

function Kit.List(parent, padding)
	return Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
		Parent = parent,
	})
end

-- Solid Frame, color bound to a background token.
function Kit.Frame(ctx, props, token)
	props.BorderSizePixel = 0
	local frame = Create("Frame", props)
	ctx.Theme:Bind(frame, "BackgroundColor3", token or "Surface")
	return frame
end

-- Transparent TextLabel. colorToken: text token ("Text", "Muted", ...), fontKey: Regular|Medium|Bold.
function Kit.Text(ctx, props, colorToken, fontKey)
	props.BackgroundTransparency = 1
	if props.TextSize == nil then
		props.TextSize = 14
	end
	props.FontFace = props.FontFace or ctx.Fonts[fontKey or "Medium"]
	if props.TextXAlignment == nil then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	if props.TextTruncate == nil then
		props.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local label = Create("TextLabel", props)
	ctx.Theme:Bind(label, "TextColor3", colorToken or "Text")
	return label
end

-- Standard element card: Surface2 background, border, title + optional description.
-- options: Name, Desc, Clickable, Order, RightWidth (space reserved on the right),
--          Height (forces the height), TopAligned (text at the top instead of centered)
function Kit.Card(ctx, parent, options)
	local metrics = ctx.Metrics
	local height = options.Height or (options.Desc and metrics.CardTall or metrics.Card)
	local frame = Create(options.Clickable and "TextButton" or "Frame", {
		Name = options.Name or "Card",
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = options.Order or 0,
		Parent = parent,
	})
	if options.Clickable then
		frame.AutoButtonColor = false
		frame.Text = ""
	end
	ctx.Theme:Bind(frame, "BackgroundColor3", "Surface2")
	Kit.Corner(frame, 8)
	local stroke = Kit.Stroke(ctx, frame, "Stroke")

	local reserved = 28 + (options.RightWidth or 0)
	local holder = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = options.TopAligned and UDim2.fromOffset(14, 10) or UDim2.fromOffset(14, 0),
		Size = options.TopAligned and UDim2.new(1, -reserved, 0, options.Desc and 38 or 20)
			or UDim2.new(1, -reserved, 1, 0),
		Parent = frame,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = options.TopAligned and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		Parent = holder,
	})
	local title = Kit.Text(ctx, {
		Name = "Title",
		Text = options.Name or "",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = holder,
	}, "Text", "Medium")
	local desc
	if options.Desc then
		desc = Kit.Text(ctx, {
			Name = "Desc",
			Text = options.Desc,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
			Parent = holder,
		}, "Muted", "Regular")
	end

	return { Frame = frame, Stroke = stroke, Title = title, Desc = desc, Holder = holder, Height = height }
end

-- Hover: the card border switches to StrokeHover. Ignored on touch.
function Kit.Hover(ctx, maid, button, stroke)
	if ctx.Touch then
		return
	end
	maid:Give(button.MouseEnter:Connect(function()
		ctx.Tween:To(stroke, { Color = ctx.Theme:Get("StrokeHover") }, 0.12)
	end))
	maid:Give(button.MouseLeave:Connect(function()
		ctx.Tween:To(stroke, { Color = ctx.Theme:Get("Stroke") }, 0.2)
	end))
end

local Icons = require("Core/Icons")

-- Row: the building block of every control line inside a card. Transparent (the card is the
-- surface), title on the left, a reserved area on the right for the control.
-- options: Name, Desc, Icon, Order, Clickable, RightWidth, Height
-- Returns { Frame, Title, Desc, Icon, Holder, Height }.
function Kit.Row(ctx, parent, options)
	local height = options.Height or (options.Desc and (ctx.Metrics.Control + 18) or ctx.Metrics.Control)
	local frame = Create(options.Clickable and "TextButton" or "Frame", {
		Name = options.Name or "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = options.Order or 0,
		Parent = parent,
	})
	if options.Clickable then
		frame.AutoButtonColor = false
		frame.Text = ""
	end
	ctx.Theme:Bind(frame, "BackgroundColor3", "Surface2")
	Kit.Corner(frame, Tokens.Radius.Sm)

	local left = 0
	local icon
	if options.Icon then
		icon = Icons.Create(ctx, {
			Icon = options.Icon,
			Size = 16,
			Color = "Muted",
			Position = UDim2.new(0, 0, 0.5, -8),
			Parent = frame,
		})
		if icon then
			left = 24
		end
	end
	local holder = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + (options.RightWidth or 0) + Tokens.Space.Md), 1, 0),
		Parent = frame,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Tokens.Space.Xs),
		Parent = holder,
	})
	local title = Kit.Text(ctx, {
		Name = "Title",
		Text = options.Name or "",
		TextSize = Tokens.Type.Secondary.Size - 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = holder,
	}, "Text", "Medium")
	local desc
	if options.Desc then
		desc = Kit.Text(ctx, {
			Name = "Desc",
			Text = options.Desc,
			TextSize = Tokens.Type.Supporting.Size,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
			Parent = holder,
		}, "Muted", "Regular")
	end
	return { Frame = frame, Title = title, Desc = desc, Icon = icon, Holder = holder, Height = height }
end

-- Subtle row hover: the row background fades in. Ignored on touch. Returns nothing.
function Kit.RowHover(ctx, maid, button, frame)
	if ctx.Touch then
		return
	end
	frame = frame or button
	maid:Give(button.MouseEnter:Connect(function()
		ctx.Tween:To(frame, { BackgroundTransparency = 0.55 }, Tokens.Motion.Fast)
	end))
	maid:Give(button.MouseLeave:Connect(function()
		ctx.Tween:To(frame, { BackgroundTransparency = 1 }, Tokens.Motion.Base)
	end))
end

-- Icon-only button (28 px; 36 on touch). options: Icon, Tooltip (string|table), Callback, Name, Parent,
-- Position/AnchorPoint, LayoutOrder, Size. Returns the TextButton; button.Icon is the glyph/image.
function Kit.IconButton(ctx, maid, options)
	local size = options.Size or (ctx.Touch and 36 or 28)
	local button = Create("TextButton", {
		Name = options.Name or "IconButton",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = options.AnchorPoint,
		Position = options.Position,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})
	ctx.Theme:Bind(button, "BackgroundColor3", "Surface3")
	Kit.Corner(button, Tokens.Radius.Sm)
	local icon = Icons.Create(ctx, {
		Icon = options.Icon,
		Size = options.IconSize or 16,
		Color = "Muted",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = button,
	})
	button.Icon = icon
	local function tint(token, bg)
		if icon then
			ctx.Tween:To(icon, { [Icons.ColorProperty(icon)] = ctx.Theme:Get(token) }, Tokens.Motion.Fast)
		end
		ctx.Tween:To(button, { BackgroundTransparency = bg }, Tokens.Motion.Fast)
	end
	if not ctx.Touch then
		maid:Give(button.MouseEnter:Connect(function()
			tint("Text", 0.4)
		end))
		maid:Give(button.MouseLeave:Connect(function()
			tint("Muted", 1)
		end))
	end
	maid:Give(button.MouseButton1Down:Connect(function()
		tint("Accent", 0)
	end))
	maid:Give(button.MouseButton1Up:Connect(function()
		tint("Text", ctx.Touch and 1 or 0.4)
	end))
	maid:Give(button.MouseButton1Click:Connect(function()
		Util.Call(options.Callback)
	end))
	if options.Tooltip and ctx.Tooltip then
		maid:Give(ctx.Tooltip:Attach(button, options.Tooltip))
	end
	return button
end

-- Small pill with text (badges, tags, notification counts). options: Text, Color token ("Accent"...), Parent, LayoutOrder.
function Kit.Badge(ctx, options)
	local label = Create("TextLabel", {
		Name = options.Name or "Badge",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Text = tostring(options.Text or ""),
		TextSize = Tokens.Type.Caption.Size,
		FontFace = ctx.Fonts.Bold,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})
	ctx.Theme:Bind(label, "BackgroundColor3", options.Soft == false and (options.Color or "Accent") or "AccentSoft")
	ctx.Theme:Bind(label, "TextColor3", options.Soft == false and "AccentText" or (options.Color or "Accent"))
	Kit.Corner(label, Tokens.Radius.Pill)
	Kit.Padding(label, 7, 7, 0, 0)
	return label
end

-- A row of keycaps ("Ctrl", "R"...): compact keyboard-key look. keys: array of strings.
-- options: Size "Small"|"Normal", LayoutOrder, Parent is the first argument. Returns the holder Frame.
function Kit.Keycaps(ctx, parent, keys, options)
	options = options or {}
	local small = options.Size == "Small"
	local height = small and 16 or 22
	local holder = Create("Frame", {
		Name = "Keycaps",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Xs + 1),
		Parent = holder,
	})
	for index, key in ipairs(keys) do
		local cap = Create("TextLabel", {
			Name = "Key",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			Text = tostring(key),
			TextSize = small and 10 or 12,
			FontFace = ctx.Fonts.Bold,
			LayoutOrder = index,
			Parent = holder,
		})
		ctx.Theme:Bind(cap, "BackgroundColor3", "Surface3")
		ctx.Theme:Bind(cap, "TextColor3", "Text")
		Kit.Corner(cap, 4)
		Kit.Padding(cap, 6, 6, 0, 0)
		Kit.Stroke(ctx, cap, "StrokeHover")
	end
	return holder
end

Kit.Tokens = Tokens

return Kit
