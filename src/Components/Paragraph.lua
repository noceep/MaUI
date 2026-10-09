-- Paragraph: a card with an optional title and wrapped body text (announcements, notes, descriptions).
--   section:AddParagraph({ Title = "About", Content = "Longer text that wraps across several lines." })
--   section:AddParagraph("Just a body")
--   paragraph:Set("New body") ; paragraph:SetTitle("New title")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Paragraph = Element.extend("Paragraph")
Paragraph.Persistent = false -- display only: never written to configs

function Paragraph.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "", Content = "" }, "Content")
	local self = setmetatable({}, Paragraph)
	Element.init(self, ctx, options)

	self.Frame = Kit.Frame(ctx, {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, "Surface2")
	Kit.Corner(self.Frame, 8)
	Kit.Stroke(ctx, self.Frame, "Stroke")
	Kit.Padding(self.Frame, 14, 14, 10, 12)
	Kit.List(self.Frame, 4)

	if options.Title ~= "" then
		self.TitleLabel = Kit.Text(ctx, {
			Name = "Title",
			Text = tostring(options.Title),
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = self.Frame,
		}, "Text", "Medium")
	end
	self.Body = Kit.Text(ctx, {
		Name = "Content",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = self.Frame,
	}, "Muted", "Regular")

	self:_init(options.Content)
	return self
end

function Paragraph:_normalize(value)
	return tostring(value)
end

function Paragraph:_render(value)
	self.Body.Text = value
end

function Paragraph:SetTitle(title)
	if self.TitleLabel then
		self.TitleLabel.Text = tostring(title)
	end
end

return Paragraph
