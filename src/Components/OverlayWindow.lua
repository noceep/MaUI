-- OverlayWindow: a small floating in-game panel (HUD style) that hosts regular MaUI elements.
--   local overlay = ui:CreateOverlayWindow({ Title = "Stats", Icon = "bolt", Size = Vector2.new(260, 180) })
--   overlay:AddMetric({...}) ; overlay:AddSection("Farm"):AddToggle({...}) ; overlay:AddLabel("Hi")
--   overlay:SetTransparency(0.3) ; overlay:SetScale(0.9) ; overlay:SetCompact(true) ; overlay:Minimize(true)
--
-- Options: Title, Icon, Size (Vector2, default 260x180), Position (UDim2, default top-right with a margin),
--   Transparency (0..1, background only: text stays opaque), Scale (UIScale), Resizable, Draggable,
--   DragRegion ("Header" | "All"), Minimizable, Closable, Compact, Blur (true | blur size), ToggleKey,
--   MinSize, MaxSize, Visible.
-- Methods: Show, Hide, Toggle, SetVisible, IsVisible, SetTransparency, SetScale, SetCompact, Minimize,
--   IsMinimized, SetPosition, GetPosition, SetSize, SetTitle, Destroy; every Container method (AddSection,
--   AddColumns, AddMetric, AddDataRow, AddToggle, AddLabel, AddButton...).
-- Signals: Moved(UDim2), VisibilityChanged(bool), CompactChanged(bool), MinimizedChanged(bool).
--
-- Perf: no per-frame loop. Moving/resizing use Input:Capture (temporary listeners, mouse deltas) and the
-- position is clamped to the screen once, on release. The ScreenGui holds only the panel frame, so nothing
-- outside it can swallow input.
local Container = require("Components/Container")
local Env = require("Core/Env")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Motion = Tokens.Space, Tokens.Motion

local OverlayWindow = {}
OverlayWindow.__index = OverlayWindow
Container.apply(OverlayWindow)

local MARGIN = 16
local SCALE_MIN, SCALE_MAX = 0.5, 2

local function viewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function setIcon(button, name)
	local kind, value = Icons.Resolve(name)
	local icon = button.Icon
	if not (kind and icon) then
		return
	end
	if icon:IsA("ImageLabel") then
		if kind == "image" then
			icon.Image = value
		end
	elseif kind == "glyph" then
		icon.Text = value
	end
end

local function toVector(value, fallback)
	if typeof(value) == "UDim2" then
		return Vector2.new(value.X.Offset, value.Y.Offset)
	end
	if typeof(value) == "Vector2" then
		return value
	end
	return fallback
end

function OverlayWindow.new(library, options)
	options = Util.Options(options, {
		Title = "Overlay",
		Size = Vector2.new(260, 180),
		MinSize = Vector2.new(180, 90),
		MaxSize = Vector2.new(520, 640),
		Transparency = 0,
		Scale = 1,
		Resizable = true,
		Draggable = true,
		DragRegion = "Header",
		Minimizable = true,
		Closable = true,
		Compact = false,
		Blur = false,
		Visible = true,
	}, "Title")

	local self = setmetatable({}, OverlayWindow)
	self.Library = library
	self.Options = options
	self.Maid = Maid.new()
	self.Elements = {}
	self._order = 0
	self.Destroyed = false
	self.Visible = true
	self.Minimized = false
	self.Compact = false
	self.Moved = Signal.new()
	self.VisibilityChanged = Signal.new()
	self.CompactChanged = Signal.new()
	self.MinimizedChanged = Signal.new()
	self.Maid:Give(self.Moved)
	self.Maid:Give(self.VisibilityChanged)
	self.Maid:Give(self.CompactChanged)
	self.Maid:Give(self.MinimizedChanged)
	self.Ctx = setmetatable({ Overlay = self }, { __index = library.Ctx })

	local ctx = self.Ctx
	local theme = ctx.Theme
	local touch = ctx.Touch

	if options.DragRegion ~= "Header" and options.DragRegion ~= "All" then
		warn("[MaUI] unknown overlay DragRegion '" .. tostring(options.DragRegion) .. "', using Header")
		options.DragRegion = "Header"
	end
	local viewport = viewportSize()
	local minSize = toVector(options.MinSize, Vector2.new(180, 90))
	local maxSize = toVector(options.MaxSize, Vector2.new(520, 640))
	self._minSize, self._maxSize = minSize, maxSize
	local size = toVector(options.Size, Vector2.new(260, 180))
	self._size = Vector2.new(Util.Clamp(size.X, minSize.X, maxSize.X), Util.Clamp(size.Y, minSize.Y, maxSize.Y))
	self._headerFull = touch and 44 or 32
	self._headerCompact = touch and 36 or 24
	self._buttonSize = touch and 36 or 24

	self.Gui = Create("ScreenGui", {
		Name = tostring(options.Title) .. "Overlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 998,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.Gui.Parent = Env.GetParent(library.Options.Parent)

	local position = options.Position
	if typeof(position) ~= "UDim2" then
		position = UDim2.fromOffset(math.max(viewport.X - self._size.X - MARGIN, 0), MARGIN)
	end
	self.Root = Create("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(self._size.X, self._size.Y),
		Position = position,
		Parent = self.Gui,
	})
	self.Scale = Create("UIScale", { Scale = 1, Parent = self.Root })

	self.Body = Kit.Frame(ctx, { Name = "Body", Size = UDim2.fromScale(1, 1), Active = true, Parent = self.Root }, "Background")
	Kit.Corner(self.Body, Tokens.Radius.Lg)
	self.Stroke = Kit.Stroke(ctx, self.Body, "Stroke")

	-- header ---------------------------------------------------------------------------------
	self.Header = Create("Frame", {
		Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, self._headerFull), Parent = self.Body,
	})
	self.HeaderLine = Kit.Frame(ctx, {
		Name = "Line", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = self.Header,
	}, "Stroke")
	self.Icon = Icons.Create(ctx, {
		Icon = options.Icon, Size = 16, Color = "Accent", Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, Space.Md + 2, 0.5, 0), Parent = self.Header,
	})
	self.TitleLabel = Kit.Text(ctx, {
		Name = "Title", Text = tostring(options.Title), TextSize = Tokens.Type.Secondary.Size - 1, Parent = self.Header,
	}, "Text", "Bold")

	self.Controls = Create("Frame", {
		Name = "Controls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -Space.Sm, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = self.Header,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Space.Xs),
		Parent = self.Controls,
	})
	local controlCount = 0
	local function addControl(name, icon, tip, order, callback)
		controlCount = controlCount + 1
		local button = Kit.IconButton(ctx, self.Maid, {
			Name = name, Icon = icon, LayoutOrder = order, Size = self._buttonSize, IconSize = 14,
			Parent = self.Controls, Callback = callback,
		})
		if ctx.Tooltip then
			button.Tip = ctx.Tooltip:Attach(button, { Text = tip })
			self.Maid:Give(button.Tip)
		end
		return button
	end
	if options.Minimizable then
		self.MinimizeButton = addControl("Minimize", "minus", "Minimize", 10, function()
			self:Minimize(not self.Minimized)
		end)
	end
	self.CompactButton = addControl("Compact", "shrink", "Compact mode", 20, function()
		self:SetCompact(not self.Compact)
	end)
	if options.Closable then
		local key = options.ToggleKey and Util.KeyName(Util.ParseKey(options.ToggleKey)) or nil
		self.CloseButton = addControl("Close", "close", key and ("Hide (" .. key .. ")") or "Hide", 30, function()
			self:Hide()
		end)
	end
	self._controlsWidth = controlCount * (self._buttonSize + Space.Xs) + Space.Sm

	-- content (a Container: AddSection / AddMetric / ... land here) ------------------------------------
	self.Page = Create("ScrollingFrame", {
		Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = self.Body,
	})
	theme:Bind(self.Page, "ScrollBarImageColor3", "Surface3")
	self.Padding = Kit.Padding(self.Page, Space.Md, Space.Md, Space.Md, Space.Md)
	Kit.List(self.Page, Space.Md)
	self.Content = self.Page

	-- resize grip ---------------------------------------------------------------------------------------
	if options.Resizable then
		local gripSize = touch and 22 or 12
		self.Grip = Create("Frame", {
			Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(gripSize, gripSize), BackgroundTransparency = 0.5, BorderSizePixel = 0, Active = true,
			ZIndex = 5, Parent = self.Body,
		})
		theme:Bind(self.Grip, "BackgroundColor3", "Surface3")
		Kit.Corner(self.Grip, 4)
		self.Maid:Give(self.Grip.InputBegan:Connect(function(input)
			if Input.IsPointerDown(input) and not self.Minimized then
				ctx.Input:Capture(self, input, function(moveInput)
					local delta = moveInput.Delta
					local scale = self.Scale.Scale
					self:_setSize(self._size.X + delta.X / scale, self._size.Y + delta.Y / scale)
				end, function()
					if not self.Destroyed then
						self:_clampToScreen()
					end
				end)
			end
		end))
	end

	-- dragging -------------------------------------------------------------------------------------------
	if options.Draggable then
		local handle = options.DragRegion == "All" and self.Body or self.Header
		self.Maid:Give(handle.InputBegan:Connect(function(input)
			if not Input.IsPointerDown(input) then
				return
			end
			-- a control inside the body (slider...) that already started its own capture wins
			if handle == self.Body and ctx.Input:IsCapturing() then
				return
			end
			ctx.Input:Capture(self, input, function(moveInput)
				local delta = moveInput.Delta
				local current = self.Root.Position
				self.Root.Position = UDim2.new(current.X.Scale, current.X.Offset + delta.X, current.Y.Scale, current.Y.Offset + delta.Y)
			end, function()
				if not self.Destroyed then
					self:_clampToScreen()
				end
			end)
		end))
	end

	-- keys -----------------------------------------------------------------------------------------------------
	self.ToggleBind = ctx.Input:BindKey(Util.ParseKey(options.ToggleKey), function()
		self:Toggle()
	end)
	self.Maid:Give(self.ToggleBind)

	self.Maid:Give(function()
		self:_removeBlur()
	end)

	self:SetScale(options.Scale)
	self:SetTransparency(options.Transparency)
	self:_layout()
	if options.Compact then
		self:SetCompact(true)
	end
	self:_clampToScreen(true)
	self.Gui.Enabled = options.Visible ~= false
	self.Visible = options.Visible ~= false
	self:_updateBlur()
	return self
end

-- Elements added directly land in one implicit plain card (same pattern as Tab).
function OverlayWindow:_AddElement(componentClass, options)
	if not self._plain or self._plain.Destroyed then
		local Section = require("Components/Section")
		self._order = self._order + 1
		self._plain = Section.new(self.Ctx, { Variant = "Plain" }, self.Content, self._order)
		self.Elements[#self.Elements + 1] = self._plain
		self.Maid:Give(self._plain)
	end
	return self._plain:_AddElement(componentClass, options)
end

-- Layout ---------------------------------------------------------------------------------------------------------

function OverlayWindow:_headerHeight()
	return self.Compact and self._headerCompact or self._headerFull
end

-- Applies sizes and compact/minimized visibility. Called on state changes only, never per frame.
function OverlayWindow:_layout(animate)
	local ctx = self.Ctx
	local header = self:_headerHeight()
	self.Header.Size = UDim2.new(1, 0, 0, header)
	local left = (self.Icon and (Space.Md + 2 + 16 + Space.Md)) or (Space.Md + 2)
	self.TitleLabel.Visible = not self.Compact
	self.TitleLabel.Position = UDim2.fromOffset(left, 0)
	self.TitleLabel.Size = UDim2.new(1, -(left + self._controlsWidth), 1, 0)
	if self.Icon then
		self.Icon.Position = UDim2.new(0, Space.Md + 2, 0.5, 0)
	end
	self.Page.Position = UDim2.fromOffset(0, header + 1)
	self.Page.Size = UDim2.new(1, 0, 1, -(header + 1))
	self.Page.Visible = not self.Minimized
	self.HeaderLine.Visible = not self.Minimized
	if self.Grip then
		self.Grip.Visible = not self.Minimized
	end
	local pad = self.Compact and Space.Sm or Space.Md
	self.Padding.PaddingLeft = UDim.new(0, pad)
	self.Padding.PaddingRight = UDim.new(0, pad)
	self.Padding.PaddingTop = UDim.new(0, pad)
	self.Padding.PaddingBottom = UDim.new(0, pad)
	local goal = UDim2.fromOffset(self._size.X, self.Minimized and header or self._size.Y)
	if animate then
		ctx.Tween:To(self.Root, { Size = goal }, Motion.Base)
	else
		self.Root.Size = goal
	end
end

function OverlayWindow:_setSize(width, height)
	self._size = Vector2.new(
		Util.Clamp(width, self._minSize.X, self._maxSize.X),
		Util.Clamp(height, self._minSize.Y, self._maxSize.Y)
	)
	self.Root.Size = UDim2.fromOffset(self._size.X, self._size.Y)
end

-- Keeps the whole panel inside the screen. Converts the position to pixels (offset only).
function OverlayWindow:_clampToScreen(silent)
	local viewport = viewportSize()
	local scale = self.Scale.Scale
	local position = self.Root.Position
	local root = self.Root.Size
	local width, height = root.X.Offset * scale, root.Y.Offset * scale
	local x = position.X.Scale * viewport.X + position.X.Offset
	local y = position.Y.Scale * viewport.Y + position.Y.Offset
	x = Util.Clamp(x, 0, math.max(viewport.X - width, 0))
	y = Util.Clamp(y, 0, math.max(viewport.Y - height, 0))
	self.Root.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	if not silent then
		self.Moved:Fire(self.Root.Position)
	end
end

-- Public API ---------------------------------------------------------------------------------------------------

function OverlayWindow:SetPosition(position)
	if typeof(position) == "Vector2" then
		position = UDim2.fromOffset(position.X, position.Y)
	end
	if typeof(position) ~= "UDim2" then
		warn("[MaUI] overlay SetPosition expects a UDim2 or Vector2")
		return
	end
	self.Root.Position = position
	self:_clampToScreen()
end

function OverlayWindow:GetPosition()
	return self.Root.Position
end

function OverlayWindow:SetSize(size)
	size = toVector(size, nil)
	if not size then
		warn("[MaUI] overlay SetSize expects a Vector2")
		return
	end
	self:_setSize(size.X, size.Y)
	self:_layout()
	self:_clampToScreen()
end

function OverlayWindow:SetTitle(title)
	self.Options.Title = tostring(title)
	self.TitleLabel.Text = self.Options.Title
end

-- 0 = opaque panel, 1 = fully transparent panel. Text and controls are never affected.
function OverlayWindow:SetTransparency(value)
	if type(value) ~= "number" then
		warn("[MaUI] overlay transparency must be a number")
		return
	end
	value = Util.Clamp(value, 0, 1)
	self.Options.Transparency = value
	self.Body.BackgroundTransparency = value
	self.Stroke.Transparency = value * 0.5
end

function OverlayWindow:SetScale(value)
	if type(value) ~= "number" or value ~= value then
		warn("[MaUI] overlay scale must be a number")
		return
	end
	self.Options.Scale = Util.Clamp(value, SCALE_MIN, SCALE_MAX)
	self.Scale.Scale = self.Options.Scale
	if self.Root.Parent then
		self:_clampToScreen(true)
	end
end

function OverlayWindow:SetCompact(compact)
	compact = compact == true
	if compact == self.Compact then
		return
	end
	self.Compact = compact
	setIcon(self.CompactButton, compact and "expand" or "shrink")
	if self.CompactButton.Tip and self.CompactButton.Tip.SetOptions then
		self.CompactButton.Tip:SetOptions({ Text = compact and "Normal mode" or "Compact mode" })
	end
	self:_layout(true)
	self.CompactChanged:Fire(compact)
end

function OverlayWindow:Minimize(minimized)
	if not self.Options.Minimizable then
		return
	end
	minimized = minimized == true
	if minimized == self.Minimized then
		return
	end
	self.Minimized = minimized
	setIcon(self.MinimizeButton, minimized and "plus" or "minus")
	if self.MinimizeButton.Tip and self.MinimizeButton.Tip.SetOptions then
		self.MinimizeButton.Tip:SetOptions({ Text = minimized and "Restore" or "Minimize" })
	end
	self:_layout(true)
	self.MinimizedChanged:Fire(minimized)
end

function OverlayWindow:IsMinimized()
	return self.Minimized
end

function OverlayWindow:IsVisible()
	return self.Visible
end

-- Blur lives in Lighting only while the overlay is visible (and only if Blur was requested).
function OverlayWindow:_removeBlur()
	if self._blur then
		self._blur:Destroy()
		self._blur = nil
	end
end

function OverlayWindow:_updateBlur()
	if self.Options.Blur and self.Visible and not self.Destroyed then
		if not self._blur then
			local ok, lighting = pcall(function()
				return game:GetService("Lighting")
			end)
			if ok and lighting then
				self._blur = Create("BlurEffect", {
					Name = "MaUIOverlayBlur",
					Size = type(self.Options.Blur) == "number" and self.Options.Blur or 12,
					Parent = lighting,
				})
			end
		end
	else
		self:_removeBlur()
	end
end

function OverlayWindow:SetVisible(visible)
	visible = visible ~= false
	if visible == self.Visible or self.Destroyed then
		return
	end
	self.Visible = visible
	if not visible then
		self.Ctx.Input:Release(self)
	end
	self.Gui.Enabled = visible
	self:_updateBlur()
	self.VisibilityChanged:Fire(visible)
end

function OverlayWindow:Show()
	self:SetVisible(true)
end

function OverlayWindow:Hide()
	self:SetVisible(false)
end

function OverlayWindow:Toggle(visible)
	if visible == nil then
		visible = not self.Visible
	end
	self:SetVisible(visible)
end

function OverlayWindow:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Ctx.Input:Release(self)
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

return OverlayWindow
