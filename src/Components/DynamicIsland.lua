-- DynamicIsland: a small always-on-top status pill that grows into a compact info panel.
--   local island = ui:CreateIsland({ Position = "TopCenter", Icon = "bolt", Text = "Farming", Metric = "1.2k/h", Count = 3 })
--   island:SetUser({ Name = "Player", Subtitle = "@player", UserId = 1 })
--   island:SetMetric(1, { Name = "FPS", Value = 60, Max = 120 }) ; island:PushMetric(1, 58)
--   island:AddChip("Ping", "34ms") ; island:AddAction({ Name = "Rejoin", Icon = "refresh", Callback = fn })
--   island:SetSettingsCallback(function() end) ; island:StartSessionClock()
--
-- Options: Position ("TopCenter" | "TopLeft" | "TopRight" | "BottomCenter" | UDim2), AnchorPoint (custom UDim2 only),
--   Margin (12), Icon, Text, Metric, Count, Status ("success" | "warning" | "error" | "info" | "accent" | "muted"),
--   Pinned, ExpandDelay (0), CollapseDelay (0.35), Width (collapsed width, 170), ExpandedSize (Vector2(300, 170);
--   the height grows if the content needs more), Visible.
-- Behavior: hover expands, leaving collapses after CollapseDelay (ONE re-armable task.delay, cancelled when the
--   pointer returns). Pinned ignores leave. Clicking the collapsed pill toggles pin. On touch devices a tap on the
--   pill expands and a tap on the user row collapses (there is no hover).
-- Methods: SetCollapsed, SetUser, SetMetric, PushMetric, AddChip, AddAction, SetSettingsCallback, Expand, Collapse
--   (also unpins), Pin, IsExpanded, IsPinned, SetVisible, SetSessionTime, StartSessionClock, StopSessionClock, Destroy.
-- Signals: ExpandedChanged(bool), PinnedChanged(bool), ActionClicked(name, action).
--
-- Perf: expanding is ONE Size tween on the root (plus one Position tween only for a custom position that needs
-- clamping). Content swaps by Visible (no CanvasGroup, no fades). The sparklines reuse a fixed pool of bar
-- frames written only while expanded. The session clock is a single task.delay(1) chain that exists only while
-- the island is expanded and visible.
local Env = require("Core/Env")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Motion = Tokens.Space, Tokens.Motion

local DynamicIsland = {}
DynamicIsland.__index = DynamicIsland

local BAR_COUNT = 20
local PAD, GAP = 8, 6
local STATUS_TOKENS = { success = "Success", warning = "Warning", error = "Error", info = "Info", accent = "Accent", muted = "Muted" }
local STATUS_ICONS = { success = "check", warning = "warning", error = "error", info = "info" }
local PRESETS = {
	TopCenter = function(m) return Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, m) end,
	TopLeft = function(m) return Vector2.new(0, 0), UDim2.fromOffset(m, m) end,
	TopRight = function(m) return Vector2.new(1, 0), UDim2.new(1, -m, 0, m) end,
	BottomCenter = function(m) return Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -m) end,
}

local function viewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function setIcon(instance, name)
	local kind, value = Icons.Resolve(name)
	if not (instance and kind) then
		return
	end
	if instance:IsA("ImageLabel") then
		if kind == "image" then
			instance.Image = value
		end
	elseif kind == "glyph" then
		instance.Text = value
	end
end

local function formatValue(format, value)
	if type(format) == "function" then
		local ok, text = pcall(format, value)
		return ok and tostring(text) or tostring(value)
	end
	if type(value) == "number" then
		if type(format) == "string" then
			local ok, text = pcall(string.format, format, value)
			if ok then
				return text
			end
		end
		if value == math.floor(value) then
			return string.format("%d", value)
		end
		return string.format("%.1f", value)
	end
	return tostring(value)
end

-- A hover/press surface used by actions and the pin button (desktop hover, pressed, disabled).
local function bindPress(ctx, maid, button, restToken, hoverToken, isDisabled)
	local theme = ctx.Theme
	local function rest()
		ctx.Tween:To(button, { BackgroundColor3 = theme:Get(restToken) }, Motion.Base)
	end
	if not ctx.Touch then
		maid:Give(button.MouseEnter:Connect(function()
			if not (isDisabled and isDisabled()) then
				ctx.Tween:To(button, { BackgroundColor3 = theme:Get(hoverToken) }, Motion.Fast)
			end
		end))
		maid:Give(button.MouseLeave:Connect(rest))
	end
	maid:Give(button.MouseButton1Down:Connect(function()
		if not (isDisabled and isDisabled()) then
			ctx.Tween:To(button, { BackgroundColor3 = theme:Get("AccentSoft") }, 0.08)
		end
	end))
	maid:Give(button.MouseButton1Up:Connect(rest))
end

function DynamicIsland.new(library, options)
	options = Util.Options(options, {
		Position = "TopCenter",
		Margin = 12,
		Text = "",
		Metric = "",
		Count = 0,
		Pinned = false,
		ExpandDelay = 0,
		CollapseDelay = 0.35,
		Width = 170,
		ExpandedSize = Vector2.new(300, 170),
		Visible = true,
	}, "Text")

	local self = setmetatable({}, DynamicIsland)
	self.Library = library
	self.Options = options
	self.Maid = Maid.new()
	self.Destroyed = false
	self.Expanded = false
	self.Pinned = false
	self.Visible = true
	self.Hover = false
	self.Chips = {}
	self.Actions = {}
	self.Tiles = {}
	self._timer = nil
	self._clockThread = nil
	self._clockActive = false
	self._clockBase = 0
	self._sessionSeconds = 0
	self._avatarToken = 0
	self._avatarPending = nil
	self._settingsCallback = nil
	self.ExpandedChanged = Signal.new()
	self.PinnedChanged = Signal.new()
	self.ActionClicked = Signal.new()
	self.Maid:Give(self.ExpandedChanged)
	self.Maid:Give(self.PinnedChanged)
	self.Maid:Give(self.ActionClicked)
	self.Ctx = setmetatable({ Island = self }, { __index = library.Ctx })

	local ctx = self.Ctx
	local theme = ctx.Theme
	local touch = ctx.Touch
	self._userHeight = touch and 44 or 32
	self._tileHeight = touch and 58 or 52
	self._chipHeight = touch and 26 or 20
	self._actionHeight = touch and ctx.Metrics.Compact or 26
	self._collapsedHeight = touch and 36 or 32
	self._buttonSize = touch and 36 or 24

	options.Margin = type(options.Margin) == "number" and options.Margin or 12
	options.Width = type(options.Width) == "number" and Util.Clamp(options.Width, 90, 600) or 170

	self.Gui = Create("ScreenGui", {
		Name = "MaUIIsland",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 997,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.Gui.Parent = Env.GetParent(library.Options.Parent)

	-- anchoring ------------------------------------------------------------------------------------------------
	local anchor, position
	local preset = PRESETS[options.Position]
	if preset then
		anchor, position = preset(options.Margin)
		self._custom = false
	elseif typeof(options.Position) == "UDim2" then
		anchor = typeof(options.AnchorPoint) == "Vector2" and options.AnchorPoint or Vector2.new(0, 0)
		position = options.Position
		self._custom = true
	else
		warn("[MaUI] unknown island Position '" .. tostring(options.Position) .. "', using TopCenter")
		anchor, position = PRESETS.TopCenter(options.Margin)
		self._custom = false
	end
	self._anchor = anchor
	self._basePosition = position

	self.Root = Kit.Frame(ctx, {
		Name = "Island",
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(options.Width, self._collapsedHeight),
		ClipsDescendants = true,
		Active = true,
		Parent = self.Gui,
	}, "Background")
	Kit.Corner(self.Root, 16)
	self.Stroke = Kit.Stroke(ctx, self.Root, "Stroke")

	self:_buildPill()
	self:_buildContent()

	-- hover (desktop) ------------------------------------------------------------------------------------------------
	if not touch then
		for _, target in ipairs({ self.Root, self.Pill, self.Content }) do
			self.Maid:Give(target.MouseEnter:Connect(function()
				self:_onEnter()
			end))
			self.Maid:Give(target.MouseLeave:Connect(function()
				self:_onLeave()
			end))
		end
	end
	self.Maid:Give(function()
		self:_cancelTimer()
		self:_stopClockThread()
		self._avatarToken = self._avatarToken + 1
	end)

	-- initial state --------------------------------------------------------------------------------------------------
	self:SetCollapsed({ Icon = options.Icon, Text = options.Text, Metric = options.Metric, Count = options.Count, Status = options.Status })
	self:SetMetric(1, { Name = "Metric 1", Value = 0 })
	self:SetMetric(2, { Name = "Metric 2", Value = 0 })
	self:_defaultUser()
	self:_refreshSections()
	self.Gui.Enabled = options.Visible ~= false
	self.Visible = options.Visible ~= false
	if options.Pinned then
		self:Pin(true)
	end
	return self
end

-- Construction -------------------------------------------------------------------------------------------------------

function DynamicIsland:_buildPill()
	local ctx = self.Ctx
	-- the collapsed pill is one button: click toggles pin (tap expands on touch)
	self.Pill = Create("TextButton", {
		Name = "Pill", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		Size = UDim2.fromScale(1, 1), Parent = self.Root,
	})
	self.PillIcon = Icons.Create(ctx, {
		Icon = "dot", Size = 14, Color = "Accent", Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Parent = self.Pill,
	})
	self.PillText = Kit.Text(ctx, {
		Name = "Text", TextSize = Tokens.Type.Secondary.Size - 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -60, 1, 0),
		Parent = self.Pill,
	}, "Text", "Bold")
	self.PillMetric = Kit.Text(ctx, {
		Name = "Metric", TextSize = Tokens.Type.Supporting.Size, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 40, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = self.Pill,
	}, "Accent", "Bold")
	self.PillCount = Kit.Badge(ctx, { Name = "Count", Text = "0", Parent = self.Pill })
	self.PillCount.AnchorPoint = Vector2.new(1, 0.5)
	self.PillCount.Position = UDim2.new(1, -8, 0.5, 0)
	self.PillCount.Visible = false

	self.Maid:Give(self.Pill.MouseButton1Click:Connect(function()
		if ctx.Touch then
			self:Expand()
		else
			self:Pin(not self.Pinned)
		end
	end))
end

local function row(ctx, parent, name, height, order, horizontal)
	local frame = Create("Frame", {
		Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = parent,
	})
	if horizontal then
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Space.Sm + 1), Parent = frame,
		})
		frame.ClipsDescendants = true
	end
	return frame
end

function DynamicIsland:_buildContent()
	local ctx = self.Ctx
	local theme = ctx.Theme
	self.Content = Create("Frame", {
		Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = self.Root,
	})
	Kit.Padding(self.Content, PAD, PAD, PAD, PAD)
	Kit.List(self.Content, GAP)

	-- user / session row ---------------------------------------------------------------------------------------
	self.UserRow = row(ctx, self.Content, "User", self._userHeight, 1)
	local header = Create("TextButton", {
		Name = "Header", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		Size = UDim2.new(1, -(self._buttonSize * 2 + Space.Sm + 2), 1, 0), Parent = self.UserRow,
	})
	local avatarSize = self._userHeight - (ctx.Touch and 8 or 0)
	self.Avatar = Create("ImageLabel", {
		Name = "Avatar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(avatarSize, avatarSize),
		BorderSizePixel = 0, Image = "", Parent = header,
	})
	theme:Bind(self.Avatar, "BackgroundColor3", "Surface3")
	Kit.Corner(self.Avatar, 32)
	local textX = avatarSize + Space.Md
	self.NameLabel = Kit.Text(ctx, {
		Name = "Name", TextSize = 13, Position = UDim2.new(0, textX, 0.5, -15), Size = UDim2.new(1, -(textX + 56), 0, 16), Parent = header,
	}, "Text", "Bold")
	self.SubLabel = Kit.Text(ctx, {
		Name = "Subtitle", TextSize = Tokens.Type.Caption.Size, Position = UDim2.new(0, textX, 0.5, 1), Size = UDim2.new(1, -textX, 0, 14),
		Parent = header,
	}, "Muted", "Regular")
	self.TimeLabel = Kit.Text(ctx, {
		Name = "Session", Text = "0s", TextSize = Tokens.Type.Caption.Size, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0.5, -15), Size = UDim2.fromOffset(52, 16), TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
	}, "Accent", "Bold")
	self.Header = header
	self.Maid:Give(header.MouseButton1Click:Connect(function()
		if ctx.Touch and not self.Pinned then
			self:Collapse()
		end
	end))

	local buttons = Create("Frame", {
		Name = "Buttons", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(self._buttonSize * 2 + Space.Sm, self._buttonSize), Parent = self.UserRow,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Space.Sm),
		Parent = buttons,
	})
	self.SettingsButton = Kit.IconButton(ctx, self.Maid, {
		Name = "Settings", Icon = "settings", Tooltip = "Settings", LayoutOrder = 1, Size = self._buttonSize, IconSize = 14,
		Parent = buttons, Callback = function()
			Util.Call(self._settingsCallback, self)
		end,
	})
	self.SettingsButton.Visible = false

	-- pin toggle: filled disc + accent tint when pinned, hollow circle when not (never color alone)
	self.PinButton = Create("TextButton", {
		Name = "Pin", Size = UDim2.fromOffset(self._buttonSize, self._buttonSize), BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = 2, Parent = buttons,
	})
	theme:Bind(self.PinButton, "BackgroundColor3", "Surface3")
	self.PinButton.BackgroundTransparency = 1
	Kit.Corner(self.PinButton, Tokens.Radius.Sm)
	self.PinIcon = Icons.Create(ctx, {
		Icon = "eyeOff", Size = 14, Color = "Muted", Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Parent = self.PinButton,
	})
	if not ctx.Touch then
		self.Maid:Give(self.PinButton.MouseEnter:Connect(function()
			ctx.Tween:To(self.PinButton, { BackgroundTransparency = self.Pinned and 0 or 0.4 }, Motion.Fast)
		end))
		self.Maid:Give(self.PinButton.MouseLeave:Connect(function()
			ctx.Tween:To(self.PinButton, { BackgroundTransparency = self.Pinned and 0 or 1 }, Motion.Fast)
		end))
	end
	self.Maid:Give(self.PinButton.MouseButton1Click:Connect(function()
		self:Pin(not self.Pinned)
	end))
	if ctx.Tooltip then
		self._pinTip = ctx.Tooltip:Attach(self.PinButton, { Text = "Pin open" })
		self.Maid:Give(self._pinTip)
	end

	-- metrics row: 2 tiles, each with a pooled sparkline -----------------------------------------------------------
	self.MetricsRow = Create("Frame", {
		Name = "Metrics", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, self._tileHeight), LayoutOrder = 2, Parent = self.Content,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, GAP), Parent = self.MetricsRow,
	})
	for index = 1, 2 do
		self.Tiles[index] = self:_buildTile(index)
	end

	-- chips and actions -------------------------------------------------------------------------------------------------
	self.ChipRow = row(ctx, self.Content, "Chips", self._chipHeight, 3, true)
	self.ChipRow.Visible = false
	self.ActionRow = row(ctx, self.Content, "Actions", self._actionHeight, 4, true)
	self.ActionRow.Visible = false
end

function DynamicIsland:_buildTile(index)
	local ctx = self.Ctx
	local theme = ctx.Theme
	local frame = Kit.Frame(ctx, {
		Name = "Tile" .. index, Size = UDim2.new(0.5, -(GAP / 2), 1, 0), LayoutOrder = index, Parent = self.MetricsRow,
	}, "Surface2")
	Kit.Corner(frame, Tokens.Radius.Md)
	local sparkWidth = BAR_COUNT * 3 - 1
	local name = Kit.Text(ctx, {
		Name = "Name", TextSize = Tokens.Type.Caption.Size, Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 12), Parent = frame,
	}, "Muted", "Regular")
	local value = Kit.Text(ctx, {
		Name = "Value", TextSize = Tokens.Type.Primary.Size, Position = UDim2.new(0, 8, 1, -(self._tileHeight - 20)),
		Size = UDim2.new(1, -(8 + sparkWidth + 14), 0, 24), Parent = frame,
	}, "Text", "Bold")
	local spark = Create("Frame", {
		Name = "Spark", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -7),
		Size = UDim2.fromOffset(sparkWidth, self._tileHeight - 26), Parent = frame,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = spark,
	})
	local bars = {}
	for i = 1, BAR_COUNT do
		local newest = i == BAR_COUNT
		local bar = Kit.Frame(ctx, {
			Name = "Bar", Size = UDim2.new(0, 2, 0, 2), LayoutOrder = i, BackgroundTransparency = 0.5, Parent = spark,
		}, newest and "Accent" or "Faint")
		if newest then
			bar.BackgroundTransparency = 0
		end
		bars[i] = bar
	end
	return {
		Index = index, Frame = frame, NameLabel = name, ValueLabel = value, Bars = bars,
		Ring = {}, Head = 0, Count = 0, Value = 0, Max = nil, Format = nil, Dirty = true,
	}
end

-- Sections visibility / size ---------------------------------------------------------------------------------------------

function DynamicIsland:_collapsedSize()
	return Vector2.new(self.Options.Width, self._collapsedHeight)
end

-- The expanded size: ExpandedSize, grown if the visible rows need more height, clamped to the viewport.
function DynamicIsland:_expandedSize()
	local requested = self.Options.ExpandedSize
	if typeof(requested) ~= "Vector2" then
		requested = Vector2.new(300, 170)
	end
	local needed = PAD * 2 + self._userHeight + GAP + self._tileHeight
	if #self.Chips > 0 then
		needed = needed + GAP + self._chipHeight
	end
	if #self.Actions > 0 then
		needed = needed + GAP + self._actionHeight
	end
	local viewport = viewportSize()
	local margin = self.Options.Margin
	local width = Util.Clamp(requested.X, 220, math.max(220, viewport.X - margin * 2))
	local height = Util.Clamp(math.max(requested.Y, needed), 120, math.max(120, viewport.Y - margin * 2))
	return Vector2.new(width, height)
end

function DynamicIsland:_refreshSections()
	self.ChipRow.Visible = #self.Chips > 0
	self.ActionRow.Visible = #self.Actions > 0
end

-- Custom positions: shift the expanded panel so it stays on screen. Returns the position for `size`.
function DynamicIsland:_positionFor(size)
	local base = self._basePosition
	if not self._custom then
		return base
	end
	local viewport = viewportSize()
	local anchor = self._anchor
	local px = base.X.Scale * viewport.X + base.X.Offset
	local py = base.Y.Scale * viewport.Y + base.Y.Offset
	local x0 = px - anchor.X * size.X
	local y0 = py - anchor.Y * size.Y
	local dx = Util.Clamp(x0, 0, math.max(viewport.X - size.X, 0)) - x0
	local dy = Util.Clamp(y0, 0, math.max(viewport.Y - size.Y, 0)) - y0
	if dx == 0 and dy == 0 then
		return base
	end
	return UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset + dy)
end

function DynamicIsland:_applySize(animate)
	local size = self.Expanded and self:_expandedSize() or self:_collapsedSize()
	local goal = UDim2.fromOffset(size.X, size.Y)
	local position = self:_positionFor(size)
	if animate then
		self.Ctx.Tween:To(self.Root, { Size = goal }, Motion.Slow, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		if self._custom then
			self.Ctx.Tween:To(self.Root, { Position = position }, Motion.Slow)
		end
	else
		self.Root.Size = goal
		self.Root.Position = position
	end
end

-- Collapsed pill content --------------------------------------------------------------------------------------------------------

function DynamicIsland:_layoutPill()
	local o = self.Options
	local hasCount = type(o.Count) == "number" and o.Count > 0
	self.PillCount.Visible = hasCount
	if hasCount then
		self.PillCount.Text = o.Count > 99 and "99+" or tostring(math.floor(o.Count))
	end
	local metric = tostring(o.Metric or "")
	local countReserve = hasCount and 32 or 0
	local metricWidth = metric ~= "" and (#metric * 7 + 4) or 0
	self.PillMetric.Visible = metric ~= ""
	self.PillMetric.Text = metric
	self.PillMetric.Size = UDim2.new(0, metricWidth, 1, 0)
	self.PillMetric.Position = UDim2.new(1, -(10 + countReserve), 0.5, 0)
	local left = self.PillIcon and 32 or 12
	self.PillText.Position = UDim2.fromOffset(left, 0)
	self.PillText.Size = UDim2.new(1, -(left + 10 + countReserve + metricWidth + (metricWidth > 0 and 6 or 0)), 1, 0)
end

-- Partial update of the collapsed pill: only the keys that are present change.
-- { Icon, Text, Metric, Count, Status }
function DynamicIsland:SetCollapsed(info)
	if type(info) ~= "table" then
		warn("[MaUI] island SetCollapsed expects a table")
		return
	end
	local o = self.Options
	if info.Text ~= nil then
		o.Text = tostring(info.Text)
	end
	if info.Metric ~= nil then
		o.Metric = tostring(info.Metric)
	end
	if info.Count ~= nil then
		o.Count = type(info.Count) == "number" and info.Count or 0
	end
	if info.Icon ~= nil then
		o.Icon = info.Icon
	end
	if info.Status ~= nil then
		if info.Status ~= false and not STATUS_TOKENS[info.Status] then
			warn("[MaUI] unknown island status '" .. tostring(info.Status) .. "'")
		else
			o.Status = info.Status or nil
		end
	end
	self.PillText.Text = o.Text
	if info.Icon ~= nil or info.Status ~= nil or self._iconReady == nil then
		self._iconReady = true
		local icon = o.Icon or STATUS_ICONS[o.Status] or "dot"
		if not Icons.Resolve(icon) then
			icon = "dot"
		end
		setIcon(self.PillIcon, icon)
		self.Ctx.Theme:Bind(self.PillIcon, Icons.ColorProperty(self.PillIcon), STATUS_TOKENS[o.Status] or "Accent")
	end
	self:_layoutPill()
end

-- Expanded panel API --------------------------------------------------------------------------------------------------------------------

function DynamicIsland:_defaultUser()
	local ok, player = pcall(function()
		return game:GetService("Players").LocalPlayer
	end)
	if ok and player then
		self:SetUser({
			Name = player.DisplayName or player.Name or "Player",
			Subtitle = player.Name and ("@" .. player.Name) or "",
			UserId = player.UserId,
		})
	else
		self:SetUser({ Name = "Player", Subtitle = "" })
	end
end

function DynamicIsland:SetUser(info)
	if type(info) ~= "table" then
		warn("[MaUI] island SetUser expects a table")
		return
	end
	if info.Name ~= nil then
		self.NameLabel.Text = tostring(info.Name)
	end
	if info.Subtitle ~= nil then
		self.SubLabel.Text = tostring(info.Subtitle)
	end
	if info.Avatar ~= nil then
		self._avatarToken = self._avatarToken + 1
		self._avatarPending = nil
		self.Avatar.Image = tostring(info.Avatar)
	elseif info.UserId ~= nil then
		self._avatarToken = self._avatarToken + 1
		self._avatarPending = info.UserId
		if self.Expanded then
			self:_loadAvatar()
		end
	end
end

-- Loads the pending avatar (only once the panel is shown). A token guards against stale answers.
function DynamicIsland:_loadAvatar()
	local userId = self._avatarPending
	if not userId then
		return
	end
	self._avatarPending = nil
	local token = self._avatarToken
	task.spawn(function()
		local ok, image = pcall(function()
			return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and image and token == self._avatarToken and not self.Destroyed then
			self.Avatar.Image = image
		end
	end)
end

local function renderTileValue(tile)
	tile.ValueLabel.Text = formatValue(tile.Format, tile.Value)
end

-- Redraws the pooled bars: oldest on the left, newest (accent) on the right.
local function renderBars(tile)
	local ring, bars = tile.Ring, tile.Bars
	local maximum = tile.Max
	if not maximum then
		maximum = 0
		for i = 1, tile.Count do
			if ring[i] > maximum then
				maximum = ring[i]
			end
		end
	end
	if maximum <= 0 then
		maximum = 1
	end
	local empty = BAR_COUNT - tile.Count
	for i = 1, BAR_COUNT do
		local bar = bars[i]
		local k = i - empty -- 1..Count for filled bars
		if k >= 1 then
			local slot = (tile.Head - tile.Count + k - 1) % BAR_COUNT + 1
			local ratio = Util.Clamp(ring[slot] / maximum, 0, 1)
			bar.Size = UDim2.new(0, 2, ratio * 0.9, 2)
		else
			bar.Size = UDim2.new(0, 2, 0, 2)
		end
	end
	tile.Dirty = false
end

-- { Name, Value, Max, Format }: Format is a function(value) -> string or a string.format pattern ("%d%%").
function DynamicIsland:SetMetric(index, info)
	local tile = self.Tiles[index]
	if not tile then
		warn("[MaUI] island metric index must be 1 or 2")
		return
	end
	if type(info) ~= "table" then
		warn("[MaUI] island SetMetric expects a table")
		return
	end
	if info.Name ~= nil then
		tile.NameLabel.Text = tostring(info.Name)
	end
	if info.Format ~= nil then
		tile.Format = info.Format
	end
	if info.Max ~= nil then
		tile.Max = type(info.Max) == "number" and info.Max > 0 and info.Max or nil
		tile.Dirty = true
		if self.Expanded then
			renderBars(tile)
		end
	end
	if info.Value ~= nil then
		tile.Value = info.Value
	end
	renderTileValue(tile)
end

-- Pushes a sample into the sparkline ring (no instance is created) and shows it as the tile value.
function DynamicIsland:PushMetric(index, value)
	local tile = self.Tiles[index]
	if not tile then
		warn("[MaUI] island metric index must be 1 or 2")
		return
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		warn("[MaUI] island PushMetric expects a finite number")
		return
	end
	tile.Head = tile.Head % BAR_COUNT + 1
	tile.Ring[tile.Head] = value
	if tile.Count < BAR_COUNT then
		tile.Count = tile.Count + 1
	end
	tile.Value = value
	tile.Dirty = true
	renderTileValue(tile)
	if self.Expanded then
		renderBars(tile)
	end
end

local Chip = {}
Chip.__index = Chip

function Chip:Set(value)
	self.Value = tostring(value)
	self.ValueLabel.Text = self.Value
end

function Chip:SetName(name)
	self.Name = tostring(name)
	self.NameLabel.Text = self.Name
end

function Chip:Destroy()
	local island = self.Island
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for i = #island.Chips, 1, -1 do
		if island.Chips[i] == self then
			table.remove(island.Chips, i)
		end
	end
	island.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
	if not island.Destroyed then
		island:_refreshSections()
		if island.Expanded then
			island:_applySize(true)
		end
	end
end

function DynamicIsland:AddChip(name, value)
	local ctx = self.Ctx
	local chip = setmetatable({ Island = self, Name = tostring(name), Value = tostring(value == nil and "" or value) }, Chip)
	chip.Frame = Kit.Frame(ctx, {
		Name = "Chip", Size = UDim2.new(0, 0, 0, self._chipHeight), AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = #self.Chips + 1, Parent = self.ChipRow,
	}, "Surface2")
	Kit.Corner(chip.Frame, Tokens.Radius.Pill)
	Kit.Padding(chip.Frame, 8, 8, 0, 0)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Space.Sm), Parent = chip.Frame,
	})
	chip.NameLabel = Kit.Text(ctx, {
		Name = "Name", Text = chip.Name, TextSize = Tokens.Type.Caption.Size, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 1, Parent = chip.Frame,
	}, "Muted", "Regular")
	chip.ValueLabel = Kit.Text(ctx, {
		Name = "Value", Text = chip.Value, TextSize = Tokens.Type.Caption.Size, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Parent = chip.Frame,
	}, "Text", "Bold")
	self.Chips[#self.Chips + 1] = chip
	self:_refreshSections()
	if self.Expanded then
		self:_applySize(true)
	end
	return chip
end

local Action = {}
Action.__index = Action

function Action:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Label.TextTransparency = self.Disabled and 0.6 or 0
	if self.IconLabel then
		self.IconLabel[self.IconLabel:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"] = self.Disabled and 0.6 or 0
	end
end

function Action:Destroy()
	local island = self.Island
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	for i = #island.Actions, 1, -1 do
		if island.Actions[i] == self then
			table.remove(island.Actions, i)
		end
	end
	island.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
	if not island.Destroyed then
		island:_refreshSections()
		if island.Expanded then
			island:_applySize(true)
		end
	end
end

-- { Name, Icon, Callback } -> action button (callback receives the action; ActionClicked fires too).
function DynamicIsland:AddAction(options)
	options = Util.Options(options, { Name = "Action" })
	local ctx = self.Ctx
	local action = setmetatable({ Island = self, Name = tostring(options.Name), Options = options, Disabled = false }, Action)
	local button = Create("TextButton", {
		Name = "Action", Size = UDim2.new(0, 0, 0, self._actionHeight), AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", LayoutOrder = #self.Actions + 1, Parent = self.ActionRow,
	})
	ctx.Theme:Bind(button, "BackgroundColor3", "Surface2")
	Kit.Corner(button, Tokens.Radius.Sm)
	Kit.Padding(button, 8, 8, 0, 0)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), Parent = button,
	})
	action.Frame = button
	action.IconLabel = Icons.Create(ctx, { Icon = options.Icon, Size = 14, Color = "Accent", Name = "Icon", LayoutOrder = 1, Parent = button })
	action.Label = Kit.Text(ctx, {
		Name = "Label", Text = action.Name, TextSize = Tokens.Type.Supporting.Size, Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Parent = button,
	}, "Text", "Medium")
	bindPress(ctx, self.Maid, button, "Surface2", "Surface3", function()
		return action.Disabled
	end)
	self.Maid:Give(button.MouseButton1Click:Connect(function()
		if action.Disabled or action.Destroyed then
			return
		end
		Util.Call(options.Callback, action)
		self.ActionClicked:Fire(action.Name, action)
	end))
	if options.Tooltip and ctx.Tooltip then
		self.Maid:Give(ctx.Tooltip:Attach(button, options.Tooltip))
	end
	self.Actions[#self.Actions + 1] = action
	self:_refreshSections()
	if self.Expanded then
		self:_applySize(true)
	end
	return action
end

-- The settings shortcut button is visible only while a callback is set.
function DynamicIsland:SetSettingsCallback(callback)
	if callback ~= nil and type(callback) ~= "function" then
		warn("[MaUI] island SetSettingsCallback expects a function")
		return
	end
	self._settingsCallback = callback
	self.SettingsButton.Visible = callback ~= nil
end

-- Session clock -------------------------------------------------------------------------------------------------------------------------

function DynamicIsland:_renderSession(seconds)
	self._sessionSeconds = seconds
	self.TimeLabel.Text = Util.FormatDuration(seconds)
end

function DynamicIsland:SetSessionTime(seconds)
	if type(seconds) ~= "number" or seconds ~= seconds then
		warn("[MaUI] island SetSessionTime expects a number of seconds")
		return
	end
	seconds = math.max(seconds, 0)
	self._clockBase = self.Library.Clock() - seconds
	self:_renderSession(seconds)
end

function DynamicIsland:_stopClockThread()
	if self._clockThread then
		pcall(task.cancel, self._clockThread)
		self._clockThread = nil
	end
end

function DynamicIsland:_tickClock()
	self._clockThread = nil
	if self.Destroyed or not self._clockActive or not self.Expanded or not self.Visible then
		return
	end
	self:_renderSession(math.max(self.Library.Clock() - self._clockBase, 0))
	self._clockThread = task.delay(1, function()
		self:_tickClock()
	end)
end

-- Runs the clock chain only while it is wanted AND visible on screen.
function DynamicIsland:_syncClock()
	local wanted = self._clockActive and self.Expanded and self.Visible and not self.Destroyed
	if wanted and not self._clockThread then
		self:_renderSession(math.max(self.Library.Clock() - self._clockBase, 0))
		self._clockThread = task.delay(1, function()
			self:_tickClock()
		end)
	elseif not wanted then
		self:_stopClockThread()
	end
end

-- Starts counting from the current SetSessionTime value (or `startSeconds`).
function DynamicIsland:StartSessionClock(startSeconds)
	self._clockActive = true
	self._clockBase = self.Library.Clock() - (type(startSeconds) == "number" and startSeconds or self._sessionSeconds)
	self:_stopClockThread()
	self:_syncClock()
end

function DynamicIsland:StopSessionClock()
	self._clockActive = false
	self:_stopClockThread()
end

-- Expand / collapse / pin ------------------------------------------------------------------------------------------------------------------

function DynamicIsland:_cancelTimer()
	if self._timer then
		pcall(task.cancel, self._timer)
		self._timer = nil
	end
end

-- The ONE re-armable timer: expand and collapse intents replace each other.
function DynamicIsland:_schedule(delay, fn)
	self:_cancelTimer()
	if delay <= 0 then
		fn()
		return
	end
	self._timer = task.delay(delay, function()
		self._timer = nil
		if not self.Destroyed then
			fn()
		end
	end)
end

function DynamicIsland:_onEnter()
	if self.Destroyed then
		return
	end
	self.Hover = true
	self:_cancelTimer()
	if not self.Expanded then
		self:_schedule(self.Options.ExpandDelay or 0, function()
			if self.Hover then
				self:_setExpanded(true)
			end
		end)
	end
end

function DynamicIsland:_onLeave()
	if self.Destroyed then
		return
	end
	self.Hover = false
	if self.Pinned then
		return
	end
	if self.Expanded then
		self:_schedule(self.Options.CollapseDelay or 0, function()
			if not self.Hover and not self.Pinned then
				self:_setExpanded(false)
			end
		end)
	else
		self:_cancelTimer() -- the pointer left before a delayed expand fired
	end
end

function DynamicIsland:_setExpanded(expanded)
	if self.Destroyed or expanded == self.Expanded then
		return
	end
	self.Expanded = expanded
	self.Pill.Visible = not expanded
	self.Content.Visible = expanded
	if expanded then
		self:_loadAvatar()
		for _, tile in ipairs(self.Tiles) do
			if tile.Dirty then
				renderBars(tile)
			end
		end
	end
	self:_applySize(true)
	self:_syncClock()
	self.ExpandedChanged:Fire(expanded)
end

function DynamicIsland:Expand()
	self:_cancelTimer()
	self:_setExpanded(true)
end

-- Explicit collapse: also unpins.
function DynamicIsland:Collapse()
	self:_cancelTimer()
	if self.Pinned then
		self:Pin(false, true)
	end
	self:_setExpanded(false)
end

function DynamicIsland:Pin(pinned, silentCollapse)
	pinned = pinned ~= false
	if pinned == self.Pinned or self.Destroyed then
		return
	end
	self.Pinned = pinned
	setIcon(self.PinIcon, pinned and "dot" or "eyeOff")
	self.Ctx.Theme:Bind(self.PinIcon, Icons.ColorProperty(self.PinIcon), pinned and "Accent" or "Muted")
	self.Ctx.Theme:Bind(self.PinButton, "BackgroundColor3", pinned and "AccentSoft" or "Surface3")
	self.PinButton.BackgroundTransparency = pinned and 0 or 1
	if self._pinTip and self._pinTip.SetOptions then
		self._pinTip:SetOptions({ Text = pinned and "Unpin" or "Pin open" })
	end
	self:_cancelTimer()
	if pinned then
		self:_setExpanded(true)
	elseif not self.Hover and not silentCollapse and self.Expanded then
		self:_schedule(self.Options.CollapseDelay or 0, function()
			if not self.Hover and not self.Pinned then
				self:_setExpanded(false)
			end
		end)
	end
	self.PinnedChanged:Fire(pinned)
end

function DynamicIsland:IsExpanded()
	return self.Expanded
end

function DynamicIsland:IsPinned()
	return self.Pinned
end

function DynamicIsland:SetVisible(visible)
	visible = visible ~= false
	if visible == self.Visible or self.Destroyed then
		return
	end
	self.Visible = visible
	self.Gui.Enabled = visible
	if not visible then
		self:_cancelTimer()
		self.Hover = false
	end
	self:_syncClock()
end

function DynamicIsland:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Gui)
	self.Gui:Destroy()
	local overlays = self.Library.Overlays
	for index = #overlays, 1, -1 do
		if overlays[index] == self then
			table.remove(overlays, index)
		end
	end
end

return DynamicIsland
