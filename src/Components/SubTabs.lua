-- SubTabs: horizontal tab strip inside a page, for switching between related modules.
--   local group = tab:AddSubTabs()
--   local dungeon = group:AddTab({ Name = "Dungeon", Icon = "bolt", Badge = 3 })
--   dungeon:AddSection("Farm") ...
-- Tab states: default, hover, active (tinted container), pressed, disabled; optional badge.
local Container = require("Components/Container")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Motion = Tokens.Motion

local SubTab = {}
SubTab.__index = SubTab
Container.apply(SubTab)

local SubTabs = {}
SubTabs.__index = SubTabs

function SubTabs.new(ctx, options, parent, order)
	options = Util.Options(options, {})
	local self = setmetatable({}, SubTabs)
	self.Ctx = ctx
	self.Maid = Maid.new()
	self.Tabs = {}
	self.Current = nil
	self.Changed = Signal.new()
	self.Maid:Give(self.Changed)
	self.Elements = {}

	self.Frame = Create("Frame", {
		Name = "SubTabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = parent,
	})
	Kit.List(self.Frame, Tokens.Space.Md)
	self.Strip = Create("ScrollingFrame", {
		Name = "Strip", BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, ctx.Metrics.Chip + 8), CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X, Parent = self.Frame,
	})
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Tokens.Space.Sm), Parent = self.Strip })
	self.Pages = Create("Frame", { Name = "Pages", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = self.Frame })
	return self
end

function SubTabs:AddTab(options)
	options = Util.Options(options, { Name = "Tab" })
	local ctx, theme = self.Ctx, self.Ctx.Theme
	local tab = setmetatable({ Ctx = ctx, Group = self, Options = options, Name = options.Name, Maid = Maid.new(), Elements = {}, _order = 0, Active = false, Disabled = false }, SubTab)

	tab.Button = Create("TextButton", {
		Name = options.Name, Size = UDim2.new(0, 0, 0, ctx.Metrics.Chip + 6), AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = #self.Tabs + 1, Parent = self.Strip,
	})
	theme:Bind(tab.Button, "BackgroundColor3", "AccentSoft")
	tab.Button.BackgroundTransparency = 1
	Kit.Corner(tab.Button, Tokens.Radius.Md)
	local row = Create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = tab.Button })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = row })
	Kit.Padding(row, 12, 12, 0, 0)
	tab.IconInstance = Icons.Create(ctx, { Icon = options.Icon, Size = 14, Color = "Muted", LayoutOrder = 1, Parent = row })
	tab.Label = Kit.Text(ctx, {
		Name = "Label", Text = options.Name, TextSize = 13, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Parent = row,
	}, "Muted", "Medium")
	tab.BadgeLabel = Kit.Badge(ctx, { Text = options.Badge or "", LayoutOrder = 3, Parent = row })
	tab.BadgeLabel.Visible = options.Badge ~= nil

	tab.Page = Create("Frame", { Name = options.Name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = self.Pages })
	Kit.List(tab.Page, Tokens.Space.Md)
	tab.Content = tab.Page

	tab.Maid:Give(tab.Button.MouseButton1Click:Connect(function()
		if not tab.Disabled then
			self:Select(tab)
		end
	end))
	tab.Maid:Give(tab.Button.MouseButton1Down:Connect(function()
		if not tab.Disabled and not tab.Active then
			ctx.Tween:To(tab.Button, { BackgroundTransparency = 0.5 }, 0.08)
		end
	end))
	if not ctx.Touch then
		tab.Maid:Give(tab.Button.MouseEnter:Connect(function()
			if not tab.Active and not tab.Disabled then
				ctx.Tween:To(tab.Button, { BackgroundTransparency = 0.7 }, Motion.Fast)
				ctx.Tween:To(tab.Label, { TextColor3 = theme:Get("Text") }, Motion.Fast)
			end
		end))
		tab.Maid:Give(tab.Button.MouseLeave:Connect(function()
			if not tab.Active then
				ctx.Tween:To(tab.Button, { BackgroundTransparency = 1 }, Motion.Base)
				ctx.Tween:To(tab.Label, { TextColor3 = theme:Get("Muted") }, Motion.Base)
			end
		end))
	end
	self.Tabs[#self.Tabs + 1] = tab
	self.Maid:Give(tab.Maid)
	if not self.Current then
		self:Select(tab, true)
	end
	if options.Disabled then
		tab:SetDisabled(true)
	end
	return tab
end

function SubTabs:Select(tab, instant)
	if self.Current == tab then
		return
	end
	local previous = self.Current
	self.Current = tab
	if previous then
		previous:_setActive(false, true)
	end
	tab:_setActive(true, instant)
	self.Changed:Fire(tab)
end

function SubTab:_setActive(active, instant)
	self.Active = active
	local ctx, theme = self.Ctx, self.Ctx.Theme
	local d = instant and 0 or Motion.Base
	ctx.Tween:To(self.Button, { BackgroundTransparency = active and 0 or 1 }, d)
	ctx.Tween:To(self.Label, { TextColor3 = theme:Get(active and "Accent" or "Muted") }, d)
	if self.IconInstance then
		ctx.Tween:To(self.IconInstance, { [Icons.ColorProperty(self.IconInstance)] = theme:Get(active and "Accent" or "Muted") }, d)
	end
	self.Page.Visible = active
end

function SubTab:SetBadge(value)
	self.BadgeLabel.Visible = value ~= nil and value ~= false
	if value ~= nil and value ~= false then
		self.BadgeLabel.Text = tostring(value)
	end
end

function SubTab:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Button.BackgroundTransparency = self.Active and 0 or 1
	self.Label.TextTransparency = self.Disabled and 0.6 or 0
end

function SubTab:Select()
	self.Group:Select(self)
end

function SubTabs:Destroy()
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
end

return SubTabs
