-- DataRow: read-only "label ... value" line with an optional status and row actions.
--   AddDataRow({ Name = "Ping", Value = "42 ms", Icon = "bolt", Status = "success",
--                Desc = "Round trip to the server",
--                Actions = { { Icon = "copy", Tooltip = "Copy", Callback = function() end } } })
--   row:SetValue("55 ms")  row:SetStatus("warning")  row:SetName("Latency")
-- Status: success | warning | error | info | muted. The status is shown as a colored value AND a
-- glyph, never by color alone. Never saved in configs (Persistent = false).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local DataRow = Element.extend("DataRow")
DataRow.Persistent = false

local STATUS = {
	success = { Token = "Success", Glyph = "success" },
	warning = { Token = "Warning", Glyph = "warning" },
	error = { Token = "Error", Glyph = "error" },
	info = { Token = "Info", Glyph = "info" },
	muted = { Token = "Muted", Glyph = nil },
}

function DataRow.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Data", Value = "" })
	local self = setmetatable({}, DataRow)
	Element.init(self, ctx, options)

	local actions = type(options.Actions) == "table" and options.Actions or {}
	local buttonSize = ctx.Touch and 36 or 28
	local actionsWidth = #actions * (buttonSize + Tokens.Space.Sm)
	self._valueWidth = 120
	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		RightWidth = self._valueWidth + actionsWidth,
	})
	self.Frame = self.Row.Frame
	self.Status = nil

	-- right side: [status glyph] [value] [actions...]
	self.Right = Create("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = self.Frame,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Sm),
		Parent = self.Right,
	})
	self.StatusIcon = Create("TextLabel", {
		Name = "StatusIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(14, 14),
		Text = "",
		TextSize = 13,
		FontFace = ctx.Fonts.Bold,
		Visible = false,
		LayoutOrder = 1,
		Parent = self.Right,
	})
	ctx.Theme:Bind(self.StatusIcon, "TextColor3", function(t)
		return self:_statusColor(t)
	end)
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Tokens.Type.Secondary.Size - 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 2,
		Parent = self.Right,
	}, function(t)
		return self:_statusColor(t)
	end, "Medium")

	self.ActionButtons = {}
	for index, action in ipairs(actions) do
		if type(action) == "table" then
			local button = Kit.IconButton(ctx, self.Maid, {
				Name = "Action" .. index,
				Icon = action.Icon or "dot",
				Tooltip = action.Tooltip,
				Callback = action.Callback,
				LayoutOrder = 2 + index,
				Parent = self.Right,
			})
			self.ActionButtons[#self.ActionButtons + 1] = button
		end
	end

	self:SetStatus(options.Status)
	self:_init(options.Value)
	return self
end

function DataRow:_statusColor(theme)
	local status = STATUS[self.Status]
	if status and self.Status ~= "muted" then
		return theme:Get(status.Token)
	end
	return theme:Get(self.Status == "muted" and "Muted" or "Text")
end

function DataRow:_normalize(value)
	if value == nil then
		return nil
	end
	return tostring(value)
end

function DataRow:_render(value)
	self.ValueLabel.Text = value
end

function DataRow:SetValue(value)
	self:Set(value, true)
end

function DataRow:SetStatus(status)
	if self.Destroyed then
		return
	end
	if status ~= nil and not STATUS[status] then
		warn("[MaUI] DataRow: unknown Status '" .. tostring(status) .. "'")
		status = nil
	end
	self.Status = status
	local info = status and STATUS[status]
	local glyph = info and info.Glyph and Icons.Resolve(info.Glyph)
	self.StatusIcon.Visible = glyph ~= nil
	if info and info.Glyph then
		local _, text = Icons.Resolve(info.Glyph)
		self.StatusIcon.Text = text or ""
	end
	local theme = self.Ctx.Theme
	self.ValueLabel.TextColor3 = self:_statusColor(theme)
	self.StatusIcon.TextColor3 = self:_statusColor(theme)
end

function DataRow:SetName(name)
	if not self.Destroyed then
		self.Row.Title.Text = tostring(name)
	end
end

function DataRow:Serialize()
	return nil
end

function DataRow:Deserialize() end

return DataRow
