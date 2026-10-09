-- Tab: sidebar navigation item + scrolling page.
--   local tab = window:AddTab({ Name = "Main", Icon = "home", Badge = 3, Subtitle = "Everything farm related" })
--   tab:AddSection("Combat") -> card ; tab:AddColumns(2) ; tab:AddSubTabs() ; tab:AddToggle(...)
-- Nav item states: default, hover, pressed, active (tinted container + accent bar), disabled; optional badge.
-- An inactive page is Visible = false: it costs no rendering and no layout.
-- Elements added straight to a tab land in an implicit card, so loose controls still look right.
local Container = require("Components/Container")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Motion = Tokens.Motion

local Tab = {}
Tab.__index = Tab
Container.apply(Tab)

function Tab.new(window, options, order)
	options = Util.Options(options, { Name = "Tab" })
	local ctx = window.Ctx
	local theme = ctx.Theme
	local self = setmetatable({}, Tab)
	self.Window = window
	self.Ctx = ctx
	self.Options = options
	self.Name = options.Name
	self.Subtitle = options.Subtitle
	self.IconName = options.Icon
	self.Maid = Maid.new()
	self.Elements = {}
	self._order = 0
	self.Active = false
	self.Disabled = false
	self.Destroyed = false
	self.Compact = false

	-- navigation item ----------------------------------------------------------------------
	self.Button = Create("TextButton", {
		Name = options.Name, Size = UDim2.new(1, 0, 0, ctx.Metrics.Nav), BackgroundTransparency = 1,
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order, Parent = window.TabList,
	})
	theme:Bind(self.Button, "BackgroundColor3", "AccentSoft")
	Kit.Corner(self.Button, Tokens.Radius.Md)
	self.Bar = Create("Frame", {
		Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 0),
		BorderSizePixel = 0, Parent = self.Button,
	})
	theme:Bind(self.Bar, "BackgroundColor3", "Accent")
	Kit.Corner(self.Bar, 3)

	self.Icon = Icons.Create(ctx, {
		Icon = options.Icon, Size = 17, Color = "Muted",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Parent = self.Button,
	})
	self._textX = self.Icon and 42 or 14
	self.Label = Kit.Text(ctx, {
		Name = "Label", Text = options.Name, TextSize = 14,
		Position = UDim2.fromOffset(self._textX, 0), Size = UDim2.new(1, -(self._textX + 30), 1, 0), Parent = self.Button,
	}, "Muted", "Medium")
	self.BadgeLabel = Kit.Badge(ctx, { Text = options.Badge or "", Parent = self.Button })
	self.BadgeLabel.AnchorPoint = Vector2.new(1, 0.5)
	self.BadgeLabel.Position = UDim2.new(1, -8, 0.5, 0)
	self.BadgeLabel.Visible = options.Badge ~= nil

	-- page ------------------------------------------------------------------------------------
	self.Page = Create("ScrollingFrame", {
		Name = options.Name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = window.Pages,
	})
	theme:Bind(self.Page, "ScrollBarImageColor3", "Surface3")
	Kit.Padding(self.Page, Tokens.Space.Xl, Tokens.Space.Xl, Tokens.Space.Sm, Tokens.Space.Xl)
	Kit.List(self.Page, Tokens.Space.Md)
	self.Content = self.Page

	self.Maid:Give(self.Button.MouseButton1Click:Connect(function()
		if not self.Disabled then
			window:SelectTab(self)
		end
	end))
	self.Maid:Give(self.Button.MouseButton1Down:Connect(function()
		if not self.Disabled and not self.Active then
			ctx.Tween:To(self.Button, { BackgroundTransparency = 0.35 }, 0.08)
		end
	end))
	if not ctx.Touch then
		self.Maid:Give(self.Button.MouseEnter:Connect(function()
			if not self.Active and not self.Disabled then
				ctx.Tween:To(self.Button, { BackgroundTransparency = 0.65 }, Motion.Fast)
				ctx.Tween:To(self.Label, { TextColor3 = theme:Get("Text") }, Motion.Fast)
			end
		end))
		self.Maid:Give(self.Button.MouseLeave:Connect(function()
			if not self.Active then
				ctx.Tween:To(self.Button, { BackgroundTransparency = 1 }, Motion.Base)
				ctx.Tween:To(self.Label, { TextColor3 = theme:Get("Muted") }, Motion.Base)
			end
		end))
	end
	if ctx.Tooltip then
		-- shows the name only while the sidebar is compact (labels hidden)
		self._tip = ctx.Tooltip:Attach(self.Button, { Text = options.Name, Delay = 0.3 })
		self.Maid:Give(self._tip)
		self._tip.Options = nil
	end
	if options.Disabled then
		self:SetDisabled(true)
	end
	return self
end

-- Elements added directly to the tab go into one shared implicit card until an explicit card is added.
function Tab:_AddElement(componentClass, options)
	if not self._plain or self._plain.Destroyed then
		local Section = require("Components/Section")
		self._order = self._order + 1
		self._plain = Section.new(self.Ctx, { Variant = "Plain" }, self.Content, self._order)
		self.Elements[#self.Elements + 1] = self._plain
		self.Maid:Give(self._plain)
	end
	return self._plain:_AddElement(componentClass, options)
end

function Tab:SetCompact(compact)
	self.Compact = compact == true
	local ctx = self.Ctx
	self.Label.Visible = not self.Compact
	self.BadgeLabel.Visible = (not self.Compact) and self.Options.Badge ~= nil
	if self.Icon then
		self.Icon.Position = self.Compact and UDim2.new(0.5, -8, 0.5, 0) or UDim2.new(0, 14, 0.5, 0)
	end
	if self._tip then
		self._tip.Options = self.Compact and { Text = self.Name, Delay = 0.3 } or nil
	end
end

function Tab:SetBadge(value)
	self.Options.Badge = (value ~= false) and value or nil
	self.BadgeLabel.Visible = self.Options.Badge ~= nil and not self.Compact
	if self.Options.Badge ~= nil then
		self.BadgeLabel.Text = tostring(self.Options.Badge)
	end
end

function Tab:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Label.TextTransparency = self.Disabled and 0.6 or 0
	if self.Icon then
		local property = self.Icon:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
		self.Icon[property] = self.Disabled and 0.6 or 0
	end
end

-- Filters the page by a search text: rows/cards whose name does not contain it are hidden.
-- Returns the number of matches. An empty text restores everything.
local function matches(name, needle)
	return needle == "" or tostring(name or ""):lower():find(needle, 1, true) ~= nil
end

local function filterList(elements, needle, parentMatches)
	local any = false
	for _, element in ipairs(elements) do
		local name = element.Options and element.Options.Name
		local visible
		if element.Elements and element.Columns == nil and element.Tabs == nil then
			-- a card: visible if its title matches or any child matches
			local own = matches(name, needle) or parentMatches
			local children = filterList(element.Elements, needle, own)
			visible = own or children
		elseif element.Columns then
			visible = false
			for _, column in ipairs(element.Columns) do
				if filterList(column.Elements, needle, false) then
					visible = true
				end
			end
		else
			visible = parentMatches or matches(name, needle)
			if element.Options and element.Options.Persistent == false and element.Options.Name == nil then
				visible = needle == ""
			end
		end
		if element.SetVisible then
			element:SetVisible(visible)
		end
		any = any or visible
	end
	return any
end

function Tab:Filter(text)
	local needle = Util.Trim(text or ""):lower()
	self._filter = needle
	return filterList(self.Elements, needle, false)
end

function Tab:SetActive(active, animate)
	self.Active = active
	local theme, tween = self.Ctx.Theme, self.Ctx.Tween
	local d = animate and Motion.Base or 0
	tween:To(self.Button, { BackgroundTransparency = active and 0 or 1 }, d)
	tween:To(self.Bar, { Size = UDim2.fromOffset(3, active and 18 or 0) }, d)
	tween:To(self.Label, { TextColor3 = theme:Get(active and "Text" or "Muted") }, d)
	if self.Icon then
		tween:To(self.Icon, { [Icons.ColorProperty(self.Icon)] = theme:Get(active and "Accent" or "Muted") }, d)
	end
	self.Page.Visible = active
	if active and animate then
		-- a single position tween on the page (no fade: it would need a CanvasGroup)
		self.Page.Position = UDim2.fromOffset(0, 10)
		tween:To(self.Page, { Position = UDim2.fromOffset(0, 0) }, Motion.Base, nil, nil, true)
	end
end

function Tab:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Button)
	self.Ctx.Theme:Release(self.Page)
	self.Button:Destroy()
	self.Page:Destroy()
end

return Tab
