-- Columns: a responsive multi-column layout inside a page. Each column is a container
-- (AddSection / AddToggle / ...). When the available width is below Count * MinWidth the
-- columns stack vertically.
--   local cols = tab:AddColumns(2)         -- or tab:AddColumns({ Count = 3, MinWidth = 240 })
--   cols[1]:AddSection("Left") ; cols[2]:AddSection("Right")
local Container = require("Components/Container")
local Maid = require("Core/Maid")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")
local Kit = require("Core/Kit")

local Create = Util.Create

local Column = {}
Column.__index = Column
Container.apply(Column)

local Columns = {}
Columns.__index = Columns

function Columns.new(ctx, options, parent, order)
	options = Util.Options(options, { Count = 2, MinWidth = 220 }, "Count")
	if type(options.Count) ~= "number" then
		options.Count = 2
	end
	options.Count = math.max(1, math.floor(options.Count))
	local self = setmetatable({}, Columns)
	self.Ctx = ctx
	self.Options = options
	self.Maid = Maid.new()
	self.Columns = {}
	self.Stacked = false
	self.Elements = {}

	self.Frame = Create("Frame", {
		Name = "Columns", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent,
	})
	self.Layout = Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Md), Parent = self.Frame,
	})
	for index = 1, options.Count do
		local frame = Create("Frame", {
			Name = "Column" .. index, BackgroundTransparency = 1, LayoutOrder = index,
			Size = UDim2.new(1 / options.Count, -math.ceil(Tokens.Space.Md * (options.Count - 1) / options.Count), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Frame,
		})
		Kit.List(frame, Tokens.Space.Md)
		local column = setmetatable({ Ctx = ctx, Content = frame, Frame = frame, Maid = Maid.new(), Elements = {}, _order = 0 }, Column)
		self.Maid:Give(column.Maid)
		self.Columns[index] = column
		self.Maid:Give(function()
			ctx.Theme:Release(frame)
		end)
	end
	self.Maid:Give(self.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:Reflow()
	end))
	self:Reflow()
	return self
end

-- Switches between side-by-side and stacked depending on the current width.
function Columns:Reflow()
	local count, width = self.Options.Count, self.Frame.AbsoluteSize.X
	local stacked = count > 1 and width > 0 and width < count * self.Options.MinWidth
	if stacked == self.Stacked and self._applied then
		return
	end
	self._applied = true
	self.Stacked = stacked
	self.Layout.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	for _, column in ipairs(self.Columns) do
		column.Frame.Size = stacked and UDim2.new(1, 0, 0, 0)
			or UDim2.new(1 / count, -math.ceil(Tokens.Space.Md * (count - 1) / count), 0, 0)
	end
end

function Columns:Destroy()
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
end

-- tab:AddColumns() returns the columns array directly, so cols[1] works; the object is cols.Object
function Columns.array(object)
	local array = setmetatable({ Object = object }, { __index = function(_, key)
		return object[key]
	end })
	for index, column in ipairs(object.Columns) do
		array[index] = column
	end
	return array
end

return Columns
