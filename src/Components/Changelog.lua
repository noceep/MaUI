-- Changelog: one card per release (title, tag or date, bullet list of changes).
--   section:AddChangelog({ Entries = {
--       { Version = "1.2.0", Date = "2026-10-03", Tag = "New", Changes = { "Added X", "Fixed Y" } },
--       { Title = "Hotfix", Content = "Free text instead of a list of changes." },
--   } })
--   changelog:Set(newEntries)   -- rebuilds the cards
-- Entry fields: Title | Version, Tag, Date, Changes (array of strings) | Content (string).
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Create = Util.Create

local Changelog = Element.extend("Changelog")
Changelog.Persistent = false -- display only: never written to configs

function Changelog.new(ctx, options, parent, order)
	options = Util.Options(options, { Entries = {} })
	local self = setmetatable({}, Changelog)
	Element.init(self, ctx, options)

	self.Frame = Create("Frame", {
		Name = "Changelog",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.List(self.Frame, 8)

	self:_init(options.Entries)
	return self
end

function Changelog:_normalize(entries)
	if type(entries) ~= "table" then
		return nil
	end
	return entries
end

-- A new table is always a change: Set() rebuilds the cards.
function Changelog:_equals()
	return false
end

function Changelog:_render(entries)
	for _, child in ipairs(self.Frame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			self.Ctx.Theme:Release(child)
			child:Destroy()
		end
	end
	for index, entry in ipairs(entries) do
		self:_buildEntry(entry, index)
	end
end

function Changelog:_buildEntry(entry, index)
	local ctx = self.Ctx
	local card = Kit.Frame(ctx, {
		Name = "Entry",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = index,
		Parent = self.Frame,
	}, "Surface2")
	Kit.Corner(card, 8)
	Kit.Stroke(ctx, card, "Stroke")
	Kit.Padding(card, 14, 14, 10, 12)
	Kit.List(card, 4)

	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = card,
	})
	Kit.Text(ctx, {
		Name = "Title",
		Text = tostring(entry.Title or entry.Version or "Update"),
		TextSize = 14,
		Size = UDim2.new(1, -90, 1, 0),
		Parent = header,
	}, "Text", "Bold")

	-- the chip shows the tag, or the date when there is no tag
	local chipText = entry.Tag or entry.Date
	if chipText then
		local chip = Kit.Frame(ctx, {
			Name = "Chip",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = header,
		}, "Surface")
		Kit.Corner(chip, 5)
		Kit.Padding(chip, 8, 8, 0, 0)
		Kit.Text(ctx, {
			Name = "Text",
			Text = tostring(chipText),
			TextSize = 11,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			Parent = chip,
		}, "Accent", "Medium")
	end

	-- with a tag AND a date, the date goes on its own line under the title
	if entry.Tag and entry.Date then
		Kit.Text(ctx, {
			Name = "Date",
			Text = tostring(entry.Date),
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 2,
			Parent = card,
		}, "Muted", "Regular")
	end

	local body = entry.Content
	if type(entry.Changes) == "table" and #entry.Changes > 0 then
		body = "• " .. table.concat(entry.Changes, "\n• ")
	end
	if body then
		Kit.Text(ctx, {
			Name = "Body",
			Text = tostring(body),
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 3,
			Parent = card,
		}, "Muted", "Regular")
	end
end

return Changelog
