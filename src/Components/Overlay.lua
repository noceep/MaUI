-- Overlay: the library-wide top layer. One ScreenGui per library instance, created lazily,
-- hosting everything that must float above windows without disturbing their layout:
--   ctx.Popup    dropdown menus, color pickers, context menus (one open at a time)
--   ctx.Tooltip  hover hints with delay, shortcut keycaps and screen-edge clamping
--
--   local popup = ctx.Popup:Open({ Anchor = button, Width = 200, Height = 180, Build = function(frame) end })
--   popup:Close()
--   ctx.Tooltip:Attach(button, { Text = "Copy", Desc = "Copies the job id", Key = "Ctrl+C" })
local Env = require("Core/Env")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Overlay = {}
Overlay.__index = Overlay

local SHADOW_IMAGE = "rbxassetid://6014261993"

function Overlay.new(ctx)
	local self = setmetatable({}, Overlay)
	self.Ctx = ctx
	self.Maid = Maid.new()
	self.Gui = nil
	self.Popup = setmetatable({ Overlay = self, Current = nil, Closed = Signal.new() }, { __index = Overlay.PopupApi })
	self.Tooltip = setmetatable({ Overlay = self, _tip = nil, _timer = nil, _token = 0 }, { __index = Overlay.TooltipApi })
	self.Maid:Give(self.Popup.Closed)
	return self
end

-- The gui is created on first use: a library that never opens a popup pays nothing.
function Overlay:_gui()
	if self.Gui then
		return self.Gui
	end
	local gui = Create("ScreenGui", {
		Name = "MaUI_Overlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = Env.GetParent(self.Ctx.Library.Options.Parent)
	self.Gui = gui
	return gui
end

function Overlay:Destroy()
	self.Popup:Close()
	self.Tooltip:_hide()
	self.Maid:Clean()
	if self.Gui then
		self.Ctx.Theme:Release(self.Gui)
		self.Gui:Destroy()
		self.Gui = nil
	end
end

-- Positions a floating frame next to an anchor, flipping/clamping inside the screen.
-- Returns the final top-left in screen pixels.
function Overlay.Place(anchor, width, height, bounds, align, gap)
	gap = gap or Tokens.Space.Sm
	local position, size = anchor.AbsolutePosition, anchor.AbsoluteSize
	local x = position.X
	if align == "Right" then
		x = position.X + size.X - width
	end
	local y = position.Y + size.Y + gap
	if bounds.X > 0 and bounds.Y > 0 then
		if y + height > bounds.Y and position.Y - gap - height >= 0 then
			y = position.Y - gap - height -- flip above the anchor
		end
		x = Util.Clamp(x, 4, math.max(bounds.X - width - 4, 4))
		y = Util.Clamp(y, 4, math.max(bounds.Y - height - 4, 4))
	end
	return x, y
end

---------------------------------------------------------------------------------------------------
-- Popup
---------------------------------------------------------------------------------------------------
local PopupApi = {}
Overlay.PopupApi = PopupApi

-- options: Anchor (Instance), Width (default: anchor width), Height, Align "Left"|"Right",
--          Build(frame, handle), OnClose(), Modal (dim the background)
-- Returns a handle { Frame, Close(), Open }.
function PopupApi:Open(options)
	local overlay, ctx = self.Overlay, self.Overlay.Ctx
	self:Close()
	local gui = overlay:_gui()
	local theme = ctx.Theme
	local anchor = options.Anchor
	local width = options.Width or (anchor and anchor.AbsoluteSize.X) or 200
	local height = options.Height or 160

	local layer = Create("Frame", { Name = "PopupLayer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui })
	-- full-screen blocker: swallows the click that dismisses the popup instead of letting it hit the page
	local blocker = Create("TextButton", {
		Name = "Blocker",
		BackgroundTransparency = options.Modal and 0.55 or 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = layer,
	})
	theme:Bind(blocker, "BackgroundColor3", "Backdrop")

	local x, y = 0, 0
	if anchor then
		x, y = Overlay.Place(anchor, width, height, gui.AbsoluteSize, options.Align, options.Gap)
	end
	local frame = Create("Frame", {
		Name = "Popup",
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 2,
		Parent = layer,
	})
	theme:Bind(frame, "BackgroundColor3", "Surface")
	Kit.Corner(frame, Tokens.Radius.Md)
	Kit.Stroke(ctx, frame, "Stroke")

	local handle = { Frame = frame, Layer = layer, Open = true, Maid = Maid.new() }
	function handle:Close()
		self.Overlay_close()
	end
	handle.Overlay_close = function()
		if not handle.Open then
			return
		end
		handle.Open = false
		if self.Current == handle then
			self.Current = nil
		end
		handle.Maid:Clean()
		theme:Release(layer)
		layer:Destroy()
		Util.Call(options.OnClose)
		self.Closed:Fire(handle)
	end
	handle.Maid:Give(blocker.MouseButton1Click:Connect(handle.Overlay_close))
	handle.Maid:Give(ctx.Input:BindKey(Enum.KeyCode.Escape, handle.Overlay_close))

	self.Current = handle
	-- entrance: a small slide + the frame is already at its final size (no layout cost)
	frame.Position = UDim2.fromOffset(x, y - 6)
	ctx.Tween:To(frame, { Position = UDim2.fromOffset(x, y) }, Tokens.Motion.Base, nil, nil, true)
	if options.Build then
		Util.Call(options.Build, frame, handle)
	end
	return handle
end

function PopupApi:Close()
	local current = self.Current
	if current then
		current:Close()
	end
end

function PopupApi:IsOpen()
	return self.Current ~= nil
end

---------------------------------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------------------------------
local TooltipApi = {}
Overlay.TooltipApi = TooltipApi

-- options: Text (required), Desc, Key ("Ctrl+R" or table of key names), Delay (default 0.45 s)
-- Returns a handle with :Disconnect(). Ignored on touch devices (no hover).
function TooltipApi:Attach(instance, options)
	local ctx = self.Overlay.Ctx
	if type(options) == "string" then
		options = { Text = options }
	end
	local handle = { Maid = Maid.new(), Options = options }
	if ctx.Touch or not options or not options.Text then
		function handle:Disconnect() end
		function handle:SetOptions() end
		return handle
	end
	handle.Maid:Give(instance.MouseEnter:Connect(function()
		self:_schedule(instance, handle.Options)
	end))
	handle.Maid:Give(instance.MouseLeave:Connect(function()
		self:_hide()
	end))
	handle.Maid:Give(instance.MouseButton1Down and instance.MouseButton1Down:Connect(function()
		self:_hide()
	end) or function() end)
	function handle:SetOptions(newOptions)
		self.Options = type(newOptions) == "string" and { Text = newOptions } or newOptions
	end
	function handle:Disconnect()
		self.Maid:Clean()
	end
	handle.Maid:Give(function()
		self:_hide()
	end)
	return handle
end

function TooltipApi:_schedule(instance, options)
	self:_hide()
	if not options then
		return -- tooltip currently disabled for this target
	end
	local token = self._token
	self._timer = task.delay(options.Delay or 0.45, function()
		if token == self._token then
			self._timer = nil
			self:Show(instance, options)
		end
	end)
end

-- Shows a tooltip immediately next to `instance` (used by Attach after the delay).
function TooltipApi:Show(instance, options)
	local overlay, ctx = self.Overlay, self.Overlay.Ctx
	self:_hide()
	local gui = overlay:_gui()
	local theme = ctx.Theme
	local keys = options.Key
	if type(keys) == "string" then
		local list = {}
		for part in keys:gmatch("[^+]+") do
			list[#list + 1] = Util.Trim(part)
		end
		keys = list
	end

	local frame = Create("Frame", {
		Name = "Tooltip",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 50,
		Parent = gui,
	})
	theme:Bind(frame, "BackgroundColor3", "Surface3")
	Kit.Corner(frame, Tokens.Radius.Sm)
	Kit.Stroke(ctx, frame, "StrokeHover")
	Kit.Padding(frame, 8, 8, 6, 6)
	Create("UISizeConstraint", { MaxSize = Vector2.new(260, 400), Parent = frame })
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = frame })
	local head = Create("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 16), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = frame })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = head })
	Kit.Text(ctx, { Name = "Text", Text = tostring(options.Text), TextSize = 13, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 1, Parent = head }, "Text", "Medium")
	if keys and #keys > 0 then
		Kit.Keycaps(ctx, head, keys, { LayoutOrder = 2, Size = "Small" })
	end
	if options.Desc then
		Kit.Text(ctx, { Name = "Desc", Text = tostring(options.Desc), TextSize = 12, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Parent = frame }, "Muted", "Regular")
	end
	self._tip = frame

	-- placement: below the anchor, flipped above near the bottom edge; needs the measured size
	local size = frame.AbsoluteSize
	local x, y = Overlay.Place(instance, math.max(size.X, 1), math.max(size.Y, 1), gui.AbsoluteSize, "Left", 6)
	frame.Position = UDim2.fromOffset(x, y)
	return frame
end

function TooltipApi:_hide()
	self._token = self._token + 1
	if self._timer then
		pcall(task.cancel, self._timer)
		self._timer = nil
	end
	if self._tip then
		self.Overlay.Ctx.Theme:Release(self._tip)
		self._tip:Destroy()
		self._tip = nil
	end
end

Overlay.Icons = Icons
return Overlay
