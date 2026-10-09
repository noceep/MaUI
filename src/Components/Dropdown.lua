-- Dropdown: pick one (or several) values from a list; the menu floats on the Popup layer.
--   AddDropdown({ Name = "Stage", Items = { "Stage 1", { Name = "Stage 2", Value = 2, Icon = "star", Desc = "Harder" } },
--                 Default = "Stage 1", Multi = false, Searchable = false, Placeholder = "Select...",
--                 MaxHeight = 220, Flag = "stage", Disabled = false, Callback = function(value) end })
--   dropdown:Set("Stage 1") / Get() / SetItems({...}) / AddItem(item) / Open() / Close() / SetDisabled(true)
-- Value: the item's Value (or its Name for plain strings). Multi = true -> array of values.
-- Items are only instantiated while the menu is open (nothing is pooled or hidden).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")
local CK = require("Components/ControlKit")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local Dropdown = Element.extend("Dropdown")

local function normalizeItems(items)
	local list = {}
	for _, item in ipairs(items or {}) do
		if type(item) == "table" then
			local name = tostring(item.Name or item.Value or "?")
			local value = item.Value
			if value == nil then
				value = name
			end
			list[#list + 1] = { Name = name, Value = value, Icon = item.Icon, Desc = item.Desc, Disabled = item.Disabled == true }
		else
			list[#list + 1] = { Name = tostring(item), Value = item }
		end
	end
	return list
end

function Dropdown.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Dropdown", Items = {}, Multi = false, Searchable = false, Placeholder = "Select...", MaxHeight = 220 })
	local self = setmetatable({}, Dropdown)
	Element.init(self, ctx, options)
	self.Items = normalizeItems(options.Items)
	self.Multi = options.Multi == true
	self.Disabled = options.Disabled == true
	self.Opened = false

	local fieldWidth = options.Width or 150
	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon, Order = order, RightWidth = fieldWidth + Space.Sm })
	self.Frame = self.Row.Frame
	self.Field = Create("TextButton", {
		Name = "Field", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(fieldWidth, ctx.Metrics.Compact + 4), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = self.Frame,
	})
	ctx.Theme:Bind(self.Field, "BackgroundColor3", "Surface2")
	Kit.Corner(self.Field, Radius.Md)
	self.FieldStroke = Kit.Stroke(ctx, self.Field, "Stroke")
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = Tokens.Type.Supporting.Size + 1, Parent = self.Field,
	}, "Text", "Medium")
	self.Chevron = Icons.Create(ctx, { Icon = "chevron", Name = "Chevron", Size = 14, Color = "Muted", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = self.Field })

	CK.Track(ctx, self.Maid, self.Field, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Field.MouseButton1Click:Connect(function()
		if not self.Disabled then
			if self.Opened then
				self:Close()
			else
				self:Open()
			end
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Field, options.Tooltip)
	self.Maid:Give(function()
		self:Close()
	end)

	self:_init(self.Multi and (options.Default or {}) or options.Default)
	self:_visual(false)
	return self
end

function Dropdown:_find(value)
	for _, item in ipairs(self.Items) do
		if item.Value == value or item.Name == value then
			return item
		end
	end
	return nil
end

function Dropdown:_normalize(value)
	if self.Multi then
		if type(value) ~= "table" then
			return nil
		end
		local out = {}
		for _, entry in ipairs(value) do
			local item = self:_find(entry)
			if item then
				out[#out + 1] = item.Value
			end
		end
		return out
	end
	if value == nil then
		return false -- nothing selected
	end
	local item = self:_find(value)
	if not item then
		return nil
	end
	return item.Value
end

function Dropdown:_equals(a, b)
	if self.Multi then
		if #a ~= #b then
			return false
		end
		for index, entry in ipairs(a) do
			if b[index] ~= entry then
				return false
			end
		end
		return true
	end
	return a == b
end

function Dropdown:_isSelected(item)
	if self.Multi then
		for _, entry in ipairs(self.Value or {}) do
			if entry == item.Value then
				return true
			end
		end
		return false
	end
	return self.Value == item.Value
end

function Dropdown:_label()
	if self.Multi then
		local names = {}
		for _, item in ipairs(self.Items) do
			if self:_isSelected(item) then
				names[#names + 1] = item.Name
			end
		end
		if #names == 0 then
			return nil
		elseif #names <= 2 then
			return table.concat(names, ", ")
		end
		return #names .. " selected"
	end
	local item = self.Value ~= false and self:_find(self.Value)
	return item and item.Name or nil
end

function Dropdown:_render()
	local text = self:_label()
	self.ValueLabel.Text = text or self.Options.Placeholder
	self.Ctx.Theme:Bind(self.ValueLabel, "TextColor3", (text and not self.Disabled) and "Text" or "Muted")
	if self.Opened then
		self:_refreshItems()
	end
end

function Dropdown:_visual(animate)
	if self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local d = animate and Motion.Fast or 0
	local stroke = self.Opened and "Accent" or ((self._hover and not self.Disabled) and "StrokeHover" or "Stroke")
	tween:To(self.FieldStroke, { Color = theme:Get(stroke) }, d)
	tween:To(self.Field, { BackgroundColor3 = theme:Get((self._pressed and not self.Disabled) and "Surface3" or "Surface2"), BackgroundTransparency = self.Disabled and 0.5 or 0 }, d)
	if self.Chevron then
		tween:To(self.Chevron, { Rotation = self.Opened and 180 or 0 }, d)
	end
	tween:To(self.ValueLabel, { TextTransparency = self.Disabled and 0.5 or 0 }, d)
	CK.Dim(ctx, self.Row, self.Disabled, d)
end

-- Menu -------------------------------------------------------------------------------------------------
function Dropdown:Open()
	if self.Opened or self.Disabled or self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local rowHeight = ctx.Metrics.Control - 2
	local searchHeight = self.Options.Searchable and 34 or 0
	local count = math.max(#self.Items, 1)
	local itemsHeight = 0
	for _, item in ipairs(self.Items) do
		itemsHeight = itemsHeight + rowHeight + (item.Desc and 14 or 0)
	end
	itemsHeight = math.max(itemsHeight, rowHeight) + Space.Sm * 2
	local height = math.min(itemsHeight + searchHeight, self.Options.MaxHeight + searchHeight)
	self.Opened = true
	self._popup = ctx.Popup:Open({
		Anchor = self.Field, Width = math.max(self.Field.AbsoluteSize.X, 160), Height = height,
		OnClose = function()
			self.Opened = false
			self._popup, self._list, self._empty, self._filter = nil, nil, nil, ""
			self:_visual(true)
		end,
		Build = function(frame)
			self:_build(frame, searchHeight)
		end,
	})
	self:_visual(true)
end

function Dropdown:_build(frame, searchHeight)
	local ctx = self.Ctx
	self._filter = ""
	if searchHeight > 0 then
		local box = Create("TextBox", {
			Name = "Search", Position = UDim2.fromOffset(Space.Md, Space.Md), Size = UDim2.new(1, -Space.Md * 2, 0, 26), BorderSizePixel = 0,
			Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, TextSize = 13, FontFace = ctx.Fonts.Regular,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
		})
		ctx.Theme:Bind(box, "BackgroundColor3", "Surface2")
		ctx.Theme:Bind(box, "TextColor3", "Text")
		ctx.Theme:Bind(box, "PlaceholderColor3", "Faint")
		Kit.Corner(box, Radius.Sm)
		Kit.Padding(box, 8, 8, 0, 0)
		self.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			self._filter = box.Text:lower()
			self:_refreshItems()
		end))
		self._searchBox = box
	end
	self._list = Create("ScrollingFrame", {
		Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 1, -searchHeight), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, Parent = frame,
	})
	ctx.Theme:Bind(self._list, "ScrollBarImageColor3", "Surface3")
	Kit.Padding(self._list, Space.Sm, Space.Sm, Space.Sm, Space.Sm)
	Kit.List(self._list, 2)
	self._empty = Kit.Text(ctx, { Name = "Empty", Text = "No results", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = frame, Position = UDim2.fromOffset(0, searchHeight + 8) }, "Muted", "Regular")
	self:_refreshItems()
end

function Dropdown:_refreshItems()
	local list = self._list
	if not list then
		return
	end
	local ctx = self.Ctx
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			ctx.Theme:Release(child)
			child:Destroy()
		end
	end
	local shown = 0
	for index, item in ipairs(self.Items) do
		if self._filter == "" or item.Name:lower():find(self._filter, 1, true) then
			shown = shown + 1
			self:_buildItem(list, item, index)
		end
	end
	if self._empty then
		self._empty.Visible = shown == 0
	end
end

function Dropdown:_buildItem(list, item, index)
	local ctx = self.Ctx
	local selected = self:_isSelected(item)
	local height = ctx.Metrics.Control - 2 + (item.Desc and 14 or 0)
	local button = Create("TextButton", {
		Name = "Item", Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = index, BackgroundTransparency = selected and 0 or 1, Parent = list,
	})
	ctx.Theme:Bind(button, "BackgroundColor3", selected and "AccentSoft" or "Surface3")
	Kit.Corner(button, Radius.Sm)
	local left = 10
	if item.Icon then
		if Icons.Create(ctx, { Icon = item.Icon, Size = 15, Color = selected and "Accent" or "Muted", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = button }) then
			left = 32
		end
	end
	local holder = Create("Frame", { Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -(left + 30), 1, 0), Parent = button })
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = holder })
	Kit.Text(ctx, { Name = "Name", Text = item.Name, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = holder }, item.Disabled and "Faint" or (selected and "Accent" or "Text"), "Medium")
	if item.Desc then
		Kit.Text(ctx, { Name = "Desc", Text = item.Desc, TextSize = 11, Size = UDim2.new(1, 0, 0, 13), LayoutOrder = 2, Parent = holder }, "Muted", "Regular")
	end
	if selected then
		Icons.Create(ctx, { Icon = "check", Name = "Check", Size = 14, Color = "Accent", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = button })
	end
	if not ctx.Touch and not item.Disabled and not selected then
		button.MouseEnter:Connect(function()
			ctx.Tween:To(button, { BackgroundTransparency = 0.5 }, Motion.Fast)
		end)
		button.MouseLeave:Connect(function()
			ctx.Tween:To(button, { BackgroundTransparency = 1 }, Motion.Base)
		end)
	end
	button.MouseButton1Click:Connect(function()
		if item.Disabled then
			return
		end
		self:_pick(item)
	end)
end

function Dropdown:_pick(item)
	if self.Multi then
		local value, found = {}, false
		for _, entry in ipairs(self.Value or {}) do
			if entry == item.Value then
				found = true
			else
				value[#value + 1] = entry
			end
		end
		if not found then
			value[#value + 1] = item.Value
		end
		self:Set(value)
	else
		self:Set(item.Value)
		self:Close()
	end
end

function Dropdown:Close()
	local popup = self._popup
	if popup then
		popup:Close()
	end
end

function Dropdown:IsOpen()
	return self.Opened
end

function Dropdown:SetItems(items)
	self.Items = normalizeItems(items)
	-- drop values that no longer exist
	local kept = self:_normalize(self.Value == false and nil or self.Value)
	self.Value = kept == nil and (self.Multi and {} or false) or kept
	self:_render()
end

function Dropdown:AddItem(item)
	local list = normalizeItems({ item })
	self.Items[#self.Items + 1] = list[1]
	self:_render()
end

function Dropdown:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		self:Close()
	end
	self:_render()
	self:_visual(true)
end

function Dropdown:Get()
	if self.Value == false then
		return nil
	end
	return self.Value
end

function Dropdown:Serialize()
	return self.Value
end

function Dropdown:Deserialize(data, silent)
	if data == nil or (not self.Multi and type(data) == "table") then
		return
	end
	self:Set(data, silent)
end

return Dropdown
