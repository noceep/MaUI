-- Window: the application shell.
--   +-----------+--------------------------------------------+
--   | Branding  | Header: page icon, title, search, controls |
--   | Nav items +--------------------------------------------+
--   |           | Pages (cards, columns, sub-tabs...)        |
--   | Session   |                                            |
--   +-----------+--------------------------------------------+
--
--   local window = ui:CreateWindow({ Title = "My Hub", Version = "v1.0", Logo = "bolt", Size = Vector2.new(760, 500) })
--   local tab = window:AddTab({ Name = "Main", Icon = "home" })
--   window:Toggle() ; window:SelectTab(tab) ; window:SetFullscreen(true) ; window:Destroy()
--
-- Options: Title, Version, Logo, Status, Size, MinSize, MaxSize, ToggleKey (false disables), CollapseKey,
--   Resizable, Shadow, Collapsible, CloseButton, Expandable (fullscreen button), Search (true), SearchPlaceholder,
--   Sidebar ("Auto" | "Expanded" | "Compact"), Session (true | false | { Name, Subtitle, UserId, Status, Callback }),
--   OpenButton, Collapsed.
--
-- Perf: moving and resizing go through Input:Capture (temporary listeners, mouse deltas); the window has NO
-- per-frame loop and no CanvasGroup. Layout reflow (compact sidebar, search visibility) runs only when a
-- resize ends or a mode changes.
local Branding = require("Components/Branding")
local Env = require("Core/Env")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local SearchBox = require("Components/SearchBox")
local SessionCard = require("Components/SessionCard")
local Signal = require("Core/Signal")
local Tab = require("Components/Tab")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Motion = Tokens.Space, Tokens.Motion

local Window = {}
Window.__index = Window

local SHADOW_IMAGE = "rbxassetid://6014261993"
local SIDEBAR_WIDE, SIDEBAR_COMPACT = 176, 60
local COMPACT_BELOW, HIDE_SEARCH_BELOW = 560, 520

function Window.new(library, options)
	options = Util.Options(options, {
		Title = "MaUI",
		Version = nil,
		Logo = "bolt",
		Size = Vector2.new(760, 500),
		MinSize = Vector2.new(400, 300),
		MaxSize = Vector2.new(1200, 800),
		ToggleKey = Enum.KeyCode.RightControl,
		Resizable = true,
		Shadow = true,
		Collapsible = true,
		CloseButton = true,
		Expandable = true,
		Search = true,
		SearchPlaceholder = "Search",
		Sidebar = "Auto",
		Session = true,
	}, "Title")

	local self = setmetatable({}, Window)
	self.Library = library
	self.Options = options
	self.Maid = Maid.new()
	self.Tabs = {}
	self.CurrentTab = nil
	self.Home = nil
	self.Open = true
	self.Collapsed = false
	self.Fullscreen = false
	self.CompactSidebar = false
	self.Destroyed = false
	self._tabOrder = 0
	self._headerActions = 0
	self.OpenChanged = Signal.new()
	self.CollapsedChanged = Signal.new()
	self.FullscreenChanged = Signal.new()
	self.Maid:Give(self.FullscreenChanged)
	self.Maid:Give(self.OpenChanged)
	self.Maid:Give(self.CollapsedChanged)
	self.Ctx = setmetatable({ Window = self }, { __index = library.Ctx })

	local ctx = self.Ctx
	local theme = ctx.Theme
	local headerHeight = ctx.Metrics.Header

	local gui = Create("ScreenGui", {
		Name = tostring(options.Title),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = Env.GetParent(library.Options.Parent)
	self.Gui = gui

	if typeof(options.Size) == "UDim2" then
		options.Size = Vector2.new(options.Size.X.Offset, options.Size.Y.Offset)
	end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.floor(Util.Clamp(options.Size.X, 200, math.max(200, viewport.X - 24)))
	local height = math.floor(Util.Clamp(options.Size.Y, 160, math.max(160, viewport.Y - 24)))

	self.Root = Create("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		Position = UDim2.new(0.5, -math.floor(width / 2), 0.5, -math.floor(height / 2)),
		Parent = gui,
	})
	if options.Shadow then
		Create("ImageLabel", {
			Name = "Shadow", BackgroundTransparency = 1, Position = UDim2.fromOffset(-24, -24), Size = UDim2.new(1, 48, 1, 48),
			Image = SHADOW_IMAGE, ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.5, ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(49, 49, 450, 450), ZIndex = 0, Parent = self.Root,
		})
	end
	self.Body = Kit.Frame(ctx, { Name = "Body", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = self.Root }, "Background")
	Kit.Corner(self.Body, Tokens.Radius.Lg)
	Kit.Stroke(ctx, self.Body, "Stroke")

	-- Sidebar ---------------------------------------------------------------------------------
	self.Sidebar = Create("Frame", { Name = "Sidebar", BackgroundTransparency = 1, Size = UDim2.new(0, SIDEBAR_WIDE, 1, 0), Parent = self.Body })
	self.SideLine = Kit.Frame(ctx, { Name = "SideLine", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), Parent = self.Sidebar }, "Stroke")
	self.Branding = Branding.new(ctx, self.Sidebar, {
		Title = options.Title, Version = options.Version, Logo = options.Logo, Status = options.Status,
	})
	self.Maid:Give(function()
		theme:Release(self.Branding.Frame)
	end)

	local footerHeight = options.Session == false and 0 or 64
	self.TabList = Create("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -(56 + footerHeight)),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = self.Sidebar,
	})
	Kit.Padding(self.TabList, Space.Md, Space.Md, Space.Sm, Space.Sm)
	Kit.List(self.TabList, Space.Xs)

	if options.Session ~= false then
		self.SessionHolder = Create("Frame", {
			Name = "SessionHolder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, footerHeight), Parent = self.Sidebar,
		})
		Kit.Padding(self.SessionHolder, Space.Md, Space.Md, Space.Md, Space.Md)
		self:SetSession(options.Session)
	end

	-- Main area: header + pages ----------------------------------------------------------------
	self.Main = Create("Frame", {
		Name = "Main", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDEBAR_WIDE + 1, 0),
		Size = UDim2.new(1, -(SIDEBAR_WIDE + 1), 1, 0), Parent = self.Body,
	})
	self.Header = Create("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerHeight), Parent = self.Main })
	self.TitleLine = Kit.Frame(ctx, { Name = "HeaderLine", Position = UDim2.fromOffset(0, headerHeight), Size = UDim2.new(1, 0, 0, 1), Parent = self.Main }, "Stroke")

	self.TitleHolder = Create("Frame", {
		Name = "Titles", BackgroundTransparency = 1, Position = UDim2.fromOffset(Space.Xl, 0),
		Size = UDim2.new(1, -(Space.Xl * 2), 1, 0), Parent = self.Header,
	})
	self.PageIconHolder = Create("Frame", { Name = "PageIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = self.TitleHolder })
	self.TitleTexts = Create("Frame", { Name = "Texts", BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0), Parent = self.TitleHolder })
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = self.TitleTexts })
	self.TitleLabel = Kit.Text(ctx, { Name = "Title", Text = "", TextSize = Tokens.Type.Primary.Size, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = self.TitleTexts }, "Text", "Bold")
	self.SubtitleLabel = Kit.Text(ctx, { Name = "Subtitle", Text = "", TextSize = Tokens.Type.Supporting.Size, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Visible = false, Parent = self.TitleTexts }, "Muted", "Regular")

	-- right cluster: [actions] [search] [expand] [collapse] [close]
	self.Controls = Create("Frame", {
		Name = "Controls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -Space.Lg, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = self.Header,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Space.Sm), Parent = self.Controls,
	})
	if options.Search then
		self.Search = SearchBox.new(ctx, self.Controls, { Placeholder = options.SearchPlaceholder, Width = 190, LayoutOrder = 20, OnChanged = function(text)
			if self.CurrentTab then
				self.CurrentTab:Filter(text)
			end
		end })
		self.Maid:Give(self.Search)
	end
	if options.Expandable then
		self.ExpandButton = Kit.IconButton(ctx, self.Maid, {
			Name = "Expand", Icon = "expand", Tooltip = { Text = "Fullscreen", Desc = "Fill the screen" }, LayoutOrder = 30, Parent = self.Controls,
			Callback = function()
				self:SetFullscreen(not self.Fullscreen)
			end,
		})
	end
	if options.Collapsible then
		self.CollapseButton = Kit.IconButton(ctx, self.Maid, {
			Name = "Collapse", Icon = "minus", Tooltip = { Text = "Collapse", Key = options.CollapseKey and Util.KeyName(Util.ParseKey(options.CollapseKey)) or nil }, LayoutOrder = 40, Parent = self.Controls,
			Callback = function()
				self:Collapse()
			end,
		})
	end
	if options.CloseButton then
		self.CloseButton = Kit.IconButton(ctx, self.Maid, {
			Name = "Close", Icon = "close", Tooltip = { Text = "Hide", Key = options.ToggleKey and options.ToggleKey ~= false and Util.KeyName(Util.ParseKey(options.ToggleKey)) or nil }, LayoutOrder = 50, Parent = self.Controls,
			Callback = function()
				self:Toggle(false)
			end,
		})
	end

	self.Pages = Create("Frame", {
		Name = "Pages", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, headerHeight + 1),
		Size = UDim2.new(1, 0, 1, -(headerHeight + 1)), Parent = self.Main,
	})
	self.Content = self.Pages -- compatibility alias

	-- drag: sidebar branding and header (mouse deltas, no absolute coordinate math) ------
	local function bindDrag(handle)
		self.Maid:Give(handle.InputBegan:Connect(function(input)
			if Input.IsPointerDown(input) and not self.Fullscreen then
				ctx.Popup:Close()
				ctx.Input:Capture(self, input, function(moveInput)
					local delta = moveInput.Delta
					local position = self.Root.Position
					self.Root.Position = UDim2.new(position.X.Scale, position.X.Offset + delta.X, position.Y.Scale, position.Y.Offset + delta.Y)
				end, function()
					if not self.Destroyed then
						self:_clampToScreen()
					end
				end)
			end
		end))
	end
	bindDrag(self.Header)
	bindDrag(self.Branding.Frame)

	-- resizing -------------------------------------------------------------------------------------
	if options.Resizable then
		local grip = Create("Frame", {
			Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(ctx.Touch and 22 or 14, ctx.Touch and 22 or 14), BackgroundTransparency = 0.5, BorderSizePixel = 0,
			Active = true, ZIndex = 5, Parent = self.Body,
		})
		theme:Bind(grip, "BackgroundColor3", "Surface3")
		Kit.Corner(grip, 4)
		self.Grip = grip
		self.Maid:Give(grip.InputBegan:Connect(function(input)
			if Input.IsPointerDown(input) and not self.Fullscreen then
				ctx.Popup:Close()
				ctx.Input:Capture(self, input, function(moveInput)
					local delta = moveInput.Delta
					local size = self.Root.Size
					self.Root.Size = UDim2.fromOffset(
						Util.Clamp(size.X.Offset + delta.X, options.MinSize.X, options.MaxSize.X),
						Util.Clamp(size.Y.Offset + delta.Y, options.MinSize.Y, options.MaxSize.Y)
					)
				end, function()
					if not self.Destroyed then
						self:_applyLayout(false)
						self:_clampToScreen()
					end
				end)
			end
		end))
	end

	-- keys ---------------------------------------------------------------------------------------------
	local toggleKey = Util.ParseKey(options.ToggleKey)
	self.ToggleBind = ctx.Input:BindKey(toggleKey, function()
		self:Toggle()
	end)
	self.Maid:Give(self.ToggleBind)
	self.CollapseBind = ctx.Input:BindKey(Util.ParseKey(options.CollapseKey), function()
		if self.Open then
			self:Collapse()
		end
	end)
	self.Maid:Give(self.CollapseBind)

	if options.OpenButton == true or (options.OpenButton == nil and (ctx.Touch or toggleKey == nil)) then
		self:_createOpenButton()
	end

	self:_setPageHeader(nil)
	self:_applyLayout(true)
	if options.Collapsed then
		self:Collapse(true)
	end
	return self
end

-- Keeps the header reachable: at least 80px of the window stays horizontally on screen and the header
-- never leaves the top/bottom edges.
function Window:_clampToScreen()
	local root = self.Root
	local bounds = self.Gui.AbsoluteSize
	local position, size = root.Position, root.Size
	local keep = 80
	local x = position.X.Scale * bounds.X + position.X.Offset
	local y = position.Y.Scale * bounds.Y + position.Y.Offset
	local cx = Util.Clamp(x, keep - size.X.Offset, math.max(keep - size.X.Offset, bounds.X - keep))
	local cy = Util.Clamp(y, 0, math.max(0, bounds.Y - self.Ctx.Metrics.Header))
	if cx ~= x or cy ~= y then
		root.Position = UDim2.new(position.X.Scale, position.X.Offset + (cx - x), position.Y.Scale, position.Y.Offset + (cy - y))
	end
end

-- Responsive layout --------------------------------------------------------------------------------
-- Computes the sidebar mode from the window width and applies it. Cheap and event-driven: called after a
-- resize, a fullscreen switch, a collapse and when the mode changes.
function Window:_applyLayout(instant)
	local ctx = self.Ctx
	local width = self.Root.Size.X.Offset
	local mode = self.Options.Sidebar
	local compact = mode == "Compact" or (mode == "Auto" and width < COMPACT_BELOW)
	local sidebarWidth = self.Collapsed and 0 or (compact and SIDEBAR_COMPACT or SIDEBAR_WIDE)
	local changed = compact ~= self.CompactSidebar
	self.CompactSidebar = compact

	local duration = instant and 0 or Motion.Base
	ctx.Tween:To(self.Sidebar, { Size = UDim2.new(0, sidebarWidth, 1, 0) }, duration)
	ctx.Tween:To(self.Main, {
		Position = UDim2.fromOffset(sidebarWidth + (sidebarWidth > 0 and 1 or 0), 0),
		Size = UDim2.new(1, -(sidebarWidth + (sidebarWidth > 0 and 1 or 0)), 1, 0),
	}, duration)
	self.Sidebar.Visible = sidebarWidth > 0
	if changed or instant then
		self.Branding:SetCompact(compact)
		if self.Session then
			self.Session:SetCompact(compact)
		end
		for _, tab in ipairs(self.Tabs) do
			tab:SetCompact(compact)
		end
		for _, separator in ipairs(self._separators or {}) do
			separator.Label.Visible = not compact
			separator.Line.Visible = compact
		end
	end
	if self.Search then
		self.Search:SetVisible(width >= HIDE_SEARCH_BELOW and not self.Collapsed)
	end
end

function Window:SetSidebarMode(mode)
	if mode ~= "Auto" and mode ~= "Expanded" and mode ~= "Compact" then
		warn("[MaUI] unknown sidebar mode: " .. tostring(mode))
		return false
	end
	self.Options.Sidebar = mode
	self:_applyLayout(false)
	return true
end

-- Header ------------------------------------------------------------------------------------------------
function Window:_setPageHeader(tab)
	local ctx = self.Ctx
	if self.PageIconInstance then
		ctx.Theme:Release(self.PageIconInstance)
		self.PageIconInstance:Destroy()
		self.PageIconInstance = nil
	end
	local title = tab and tab.Name or tostring(self.Options.Title)
	self.TitleLabel.Text = title
	local subtitle = tab and tab.Subtitle
	self.SubtitleLabel.Visible = subtitle ~= nil and subtitle ~= ""
	self.SubtitleLabel.Text = tostring(subtitle or "")
	local icon = tab and tab.IconName
	self.PageIconInstance = Icons.Create(ctx, { Icon = icon, Size = 20, Color = "Accent", Name = "Glyph", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = self.PageIconHolder })
	self.PageIconHolder.Visible = self.PageIconInstance ~= nil
	self.TitleTexts.Position = UDim2.fromOffset(self.PageIconInstance and 32 or 0, 0)
	self.TitleTexts.Size = UDim2.new(1, self.PageIconInstance and -32 or 0, 1, 0)
end

-- Adds an icon button to the header (left of the search field). Returns the button.
function Window:AddHeaderAction(options)
	self._headerActions = self._headerActions + 1
	options = Util.Options(options, { Icon = "settings" }, "Tooltip")
	return Kit.IconButton(self.Ctx, self.Maid, {
		Name = options.Name or "Action", Icon = options.Icon, Tooltip = options.Tooltip, Callback = options.Callback,
		LayoutOrder = self._headerActions, Parent = self.Controls,
	})
end

-- Session card ----------------------------------------------------------------------------------------
-- window:SetSession(true | false | { Name, Subtitle, UserId, Avatar, Status, Callback })
function Window:SetSession(config)
	if not self.SessionHolder then
		return nil
	end
	if self.Session then
		self.Session:Destroy()
		self.Session = nil
	end
	if config == false then
		return nil
	end
	local options = type(config) == "table" and Util.Copy(config) or {}
	if options.Name == nil then
		local ok, player = pcall(function()
			return game:GetService("Players").LocalPlayer
		end)
		if ok and player then
			options.Name = player.DisplayName
			options.Subtitle = options.Subtitle or ("@" .. player.Name)
			options.UserId = options.UserId or player.UserId
		end
	end
	self.Session = SessionCard.new(self.Ctx, self.SessionHolder, options)
	self.Session:SetCompact(self.CompactSidebar)
	return self.Session
end

function Window:AddTab(options)
	self._tabOrder = self._tabOrder + 1
	local tab = Tab.new(self, options, self._tabOrder)
	self.Tabs[#self.Tabs + 1] = tab
	self.Maid:Give(tab)
	if not self.CurrentTab then
		self:SelectTab(tab, true)
	end
	return tab
end

-- A small heading (or a thin line when `text` is nil) between navigation items. In the compact sidebar
-- headings collapse into a thin line.
function Window:AddTabSeparator(text)
	self._tabOrder = self._tabOrder + 1
	local ctx = self.Ctx
	local hasText = text ~= nil and text ~= ""
	local frame = Create("Frame", {
		Name = "Separator", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, hasText and 26 or 12),
		LayoutOrder = self._tabOrder, Parent = self.TabList,
	})
	local label
	if hasText then
		label = Kit.Text(ctx, {
			Name = "Label", Text = string.upper(tostring(text)), TextSize = Tokens.Type.Caption.Size,
			Position = UDim2.fromOffset(Space.Md, 8), Size = UDim2.new(1, -(Space.Md * 2), 0, 14), Parent = frame,
		}, "Faint", "Bold")
	end
	local line = Kit.Frame(ctx, {
		Name = "Line", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, Space.Md, 0.5, 0),
		Size = UDim2.new(1, -(Space.Md * 2), 0, 1), Visible = not hasText, Parent = frame,
	}, "Stroke")
	if hasText then
		self._separators = self._separators or {}
		self._separators[#self._separators + 1] = { Label = label, Line = line }
		label.Visible = not self.CompactSidebar
		line.Visible = self.CompactSidebar
	end
	return frame
end

-- The Home tab: always the first tab, selected on creation. It is a normal Tab, so you can keep adding
-- sections and elements to it. Options:
--   Name, Icon        sidebar label / icon
--   Profile           show the player card (default true); Greeting, Badge, ShowId, Player are forwarded
--   KeyStatus         true | false | "auto" (default: shown only if a key was validated)
--   Changelog         array of entries (see Components/Changelog.lua); ChangelogTitle = section title
--   Select            false to keep the current tab selected
function Window:AddHome(options)
	if self.Home then
		error("[MaUI] this window already has a Home tab", 2)
	end
	options = Util.Options(options, {
		Name = "Home",
		Profile = true,
		KeyStatus = "auto",
		ChangelogTitle = "Changelog",
	}, "Name")

	local tab = Tab.new(self, { Name = options.Name, Icon = options.Icon }, -1)
	table.insert(self.Tabs, 1, tab)
	self.Maid:Give(tab)
	self.Home = tab

	if options.Profile ~= false then
		tab:AddProfile({
			Greeting = options.Greeting,
			Badge = options.Badge,
			ShowId = options.ShowId,
			ShowAvatar = options.ShowAvatar,
			Player = options.Player,
		})
	end
	local showKey = options.KeyStatus
	if showKey == "auto" then
		showKey = self.Library.Key ~= nil
	end
	if showKey then
		tab:AddKeyStatus()
	end
	if options.Changelog then
		local section = tab:AddSection(options.ChangelogTitle)
		section:AddChangelog({ Entries = options.Changelog })
	end

	if options.Select ~= false then
		self:SelectTab(tab, true)
	end
	return tab
end

function Window:SelectTab(tab, instant)
	if self.CurrentTab == tab or self.Destroyed or tab.Disabled then
		return
	end
	local previous = self.CurrentTab
	self.CurrentTab = tab
	self.Ctx.Popup:Close()
	if previous then
		previous:SetActive(false, false)
	end
	tab:SetActive(true, not instant)
	self:_setPageHeader(tab)
	if self.Search and self.Search:Get() ~= "" then
		tab:Filter(self.Search:Get())
	end
end

function Window:Toggle(open)
	if self.Destroyed then
		return
	end
	if open == nil then
		open = not self.Open
	end
	if open == self.Open then
		return
	end
	self.Open = open
	if not open then
		self.Ctx.Popup:Close()
	end
	self.Root.Visible = open
	if self.OpenButton then
		self.OpenButton.Visible = not open
	end
	self.OpenChanged:Fire(open)
end

-- Collapses the window to its header bar (or expands it back). Collapse() with no argument flips the state.
function Window:Collapse(collapsed)
	if self.Destroyed or self.Options.Collapsible == false then
		return
	end
	if collapsed == nil then
		collapsed = not self.Collapsed
	end
	if collapsed == self.Collapsed then
		return
	end
	self.Collapsed = collapsed
	local ctx = self.Ctx
	local root = self.Root
	ctx.Popup:Close()
	if collapsed then
		self._expandedSize = root.Size
		ctx.Input:Release(self) -- a resize in progress would fight the new size
	end
	-- hidden subtrees cost no rendering and no layout
	self.Pages.Visible = not collapsed
	self.TitleLine.Visible = not collapsed
	if self.Grip then
		self.Grip.Visible = not collapsed
	end
	if self.CollapseButton and self.CollapseButton.Icon then
		local kind, glyph = Icons.Resolve(collapsed and "plus" or "minus")
		if kind == "glyph" then
			self.CollapseButton.Icon.Text = glyph
		end
	end
	local target = collapsed and UDim2.fromOffset(root.Size.X.Offset, ctx.Metrics.Header + 1) or self._expandedSize
	ctx.Tween:To(root, { Size = target }, Motion.Slow)
	self:_applyLayout(false)
	if not collapsed then
		task.delay(Motion.Slow + 0.05, function()
			if not self.Destroyed then
				self:_clampToScreen()
			end
		end)
	end
	self.CollapsedChanged:Fire(collapsed)
end

-- Fills the screen (minus a small margin) or restores the previous size and position.
function Window:SetFullscreen(fullscreen)
	if self.Destroyed then
		return
	end
	fullscreen = fullscreen == true
	if fullscreen == self.Fullscreen then
		return
	end
	local ctx = self.Ctx
	ctx.Popup:Close()
	ctx.Input:Release(self)
	if self.Collapsed then
		self:Collapse(false)
	end
	self.Fullscreen = fullscreen
	local root = self.Root
	if fullscreen then
		self._restore = { Size = root.Size, Position = root.Position }
		local bounds = self.Gui.AbsoluteSize
		local margin = 12
		ctx.Tween:To(root, {
			Size = UDim2.fromOffset(math.max(bounds.X - margin * 2, 200), math.max(bounds.Y - margin * 2, 160)),
			Position = UDim2.fromOffset(margin, margin),
		}, Motion.Slow)
	elseif self._restore then
		ctx.Tween:To(root, self._restore, Motion.Slow)
	end
	if self.ExpandButton and self.ExpandButton.Icon then
		local kind, glyph = Icons.Resolve(fullscreen and "shrink" or "expand")
		if kind == "glyph" then
			self.ExpandButton.Icon.Text = glyph
		end
	end
	if fullscreen then
		self.Root.Size = self.Root.Size -- ensure the layout below sees the target size
	end
	task.defer(function()
		if not self.Destroyed then
			self:_applyLayout(false)
		end
	end)
	self.FullscreenChanged:Fire(fullscreen)
end

function Window:SetTitle(title)
	self.Options.Title = title
	self.Branding:SetTitle(title)
	if not self.CurrentTab then
		self.TitleLabel.Text = tostring(title)
	end
end

function Window:SetCollapseKey(key)
	self.CollapseBind:SetKey(Util.ParseKey(key))
end

function Window:SetToggleKey(key)
	local parsed = Util.ParseKey(key)
	if parsed then
		self.ToggleBind:SetKey(parsed)
	end
end

function Window:Notify(options)
	return self.Library:Notify(options)
end

function Window:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Ctx.Input:Release(self)
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Gui)
	self.Gui:Destroy()
	self.Library:_RemoveWindow(self)
end

return Window
