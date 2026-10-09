-- Label: plain text (automatic multi-line), optional icon.
--   AddLabel("Text")  or  AddLabel({ Text = "...", Color = "Accent", Icon = "info", Muted = true })
--   label:Set("new text")  /  label:SetText("new text")
-- Muted (default true) uses the Muted text color; Muted = false uses the primary Text color.
-- An explicit Color token always wins.
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Create = Util.Create

local Label = Element.extend("Label")
Label.Persistent = false -- display only

function Label.new(ctx, options, parent, order)
	options = Util.Options(options, { Text = "", Muted = true }, "Text")
	local self = setmetatable({}, Label)
	Element.init(self, ctx, options)

	local color = options.Color or (options.Muted == false and "Text" or "Muted")
	self.Frame = Create("Frame", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Padding(self.Frame, 0, 0, 3, 3)
	local left = 0
	if options.Icon then
		self.IconInstance = Icons.Create(ctx, {
			Icon = options.Icon,
			Size = 16,
			Color = color,
			Position = UDim2.fromOffset(0, 0),
			Parent = self.Frame,
		})
		if self.IconInstance then
			left = 22
		end
	end
	self.Label = Kit.Text(ctx, {
		Name = "Text",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.Frame,
	}, color, "Regular")

	self:_init(options.Text)
	return self
end

function Label:_normalize(value)
	return tostring(value)
end

function Label:_render(value)
	self.Label.Text = value
end

function Label:SetText(text)
	self:Set(text, true)
end

return Label
