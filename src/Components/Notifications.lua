-- Notifications: toasts stacked at the bottom right. Owned by the Library (not by a window):
-- ui:Notify(...) works even with no window open.
--   local toast = ui:Notify({ Title = "Loaded", Content = "5 modules", Type = "Success", Duration = 4,
--                             Dismissible = true })
--   Type: Info (default) | Success | Warning | Error | Loading   (glyph AND color per type)
--   Duration: seconds; 0 / math.huge = stays until closed. Loading never auto-closes unless a Duration is given.
--   toast:Close()   toast:Update({ Title, Content, Type, Duration })   toast.Closed:Connect(fn)
--   toast.Dismiss() is the legacy alias of Close. MaxVisible (library-wide, default 5) evicts the oldest.
-- Auto-close pauses while the pointer is over a toast (event-driven: one task.delay per toast, re-armed
-- on leave). Enter/exit are a slide + fade through ctx.Tween (instant under Animations = "Off").
-- No per-frame code, no CanvasGroup; everything is released on Destroy.
local Env = require("Core/Env")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Notifications = {}
Notifications.__index = Notifications

local WIDTH = 320
local OFFSCREEN = WIDTH + 24
local EXIT_TIME = Tokens.Motion.Slow
local MIN_REARM = 1 -- seconds a toast stays after the pointer leaves

local TYPES = {
	Info = { Token = "Info", Icon = "info" },
	Success = { Token = "Success", Icon = "success" },
	Warning = { Token = "Warning", Icon = "warning" },
	Error = { Token = "Error", Icon = "error" },
	Loading = { Token = "Accent", Icon = "loading" },
}

local function glyph(Icons, name)
	local _, value = Icons.Resolve(name)
	return value or ""
end

function Notifications.new(ctx)
	local self = setmetatable({}, Notifications)
	self.Ctx = ctx
	self.MaxVisible = 5
	self._active = {}
	self._closing = {}
	self._order = 0
	self._gui = nil
	self._holder = nil
	return self
end

-- The ScreenGui is only created on the first notification.
function Notifications:_ensureGui()
	if self._gui and self._gui.Parent then
		return
	end
	local ctx = self.Ctx
	self._gui = Create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self._gui.Parent = Env.GetParent(ctx.Library.Options.Parent)
	self._holder = Create("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, WIDTH, 1, -32),
		Parent = self._gui,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, Tokens.Space.Md),
		Parent = self._holder,
	})
end

function Notifications:_remove(handle)
	for index, entry in ipairs(self._active) do
		if entry == handle then
			table.remove(self._active, index)
			return
		end
	end
end

function Notifications:Push(options)
	local givenDuration = type(options) == "table" and options.Duration ~= nil
	options = Util.Options(options, { Title = "Notification", Type = "Info", Duration = 4 }, "Title")
	if not TYPES[options.Type] then
		warn("[MaUI] Notify: unknown Type '" .. tostring(options.Type) .. "', using Info")
		options.Type = "Info"
	end
	if tonumber(options.MaxVisible) and options.MaxVisible >= 1 then
		self.MaxVisible = math.floor(options.MaxVisible)
	end
	self:_ensureGui()

	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local Icons = require("Core/Icons")
	self._order = self._order + 1

	local handle = {
		Dismissed = false,
		Closed = Signal.new(),
		Type = options.Type,
		Dismissible = options.Dismissible ~= false,
	}
	local maid = Maid.new()
	local wrapper = Create("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		Parent = self._holder,
	})
	local card = Create("TextButton", {
		Name = "Card",
		Position = UDim2.fromOffset(OFFSCREEN, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Parent = wrapper,
	})
	theme:Bind(card, "BackgroundColor3", "Surface")
	Kit.Corner(card, Tokens.Radius.Md)
	Kit.Stroke(ctx, card, "Stroke")
	Kit.Padding(card, Tokens.Space.Lg, Tokens.Space.Lg, Tokens.Space.Lg - 2, Tokens.Space.Lg - 2)

	local function typeColor(t)
		return t:Get(TYPES[handle.Type].Token)
	end
	handle.Icon = Create("TextLabel", {
		Name = "TypeIcon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = glyph(Icons, TYPES[handle.Type].Icon),
		TextSize = 17,
		FontFace = ctx.Fonts.Bold,
		Parent = card,
	})
	theme:Bind(handle.Icon, "TextColor3", typeColor)

	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = card,
	})
	Kit.Padding(body, 28, handle.Dismissible and 24 or 0, 0, 0)
	Kit.List(body, Tokens.Space.Xs)
	handle.TitleLabel = Kit.Text(ctx, {
		Name = "Title",
		Text = tostring(options.Title),
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		Parent = body,
	}, "Text", "Bold")
	handle.ContentLabel = Kit.Text(ctx, {
		Name = "Content",
		Text = options.Content ~= nil and tostring(options.Content) or "",
		TextSize = Tokens.Type.Supporting.Size + 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = options.Content ~= nil and tostring(options.Content) ~= "",
		LayoutOrder = 2,
		Parent = body,
	}, "Muted", "Regular")

	-- Closing -----------------------------------------------------------------------------------
	local timer, deadline, hovering
	local function cancelTimer()
		if timer then
			pcall(task.cancel, timer)
			timer = nil
		end
	end

	local function finish()
		maid:Clean()
		theme:Release(wrapper)
		wrapper:Destroy()
		handle._exit = nil
		self._closing[handle] = nil
	end

	local function close(instant)
		if handle.Dismissed then
			return
		end
		handle.Dismissed = true
		cancelTimer()
		self:_remove(handle)
		if instant or tween.Mode == "Off" then
			finish()
		else
			maid:Clean() -- stop reacting to the pointer while sliding out
			tween:To(card, { Position = UDim2.fromOffset(OFFSCREEN, 0), BackgroundTransparency = 1 }, EXIT_TIME)
			handle._exit = task.delay(EXIT_TIME + 0.02, finish)
			self._closing[handle] = true
		end
		handle.Closed:Fire()
		handle.Closed:Destroy()
	end
	handle.Close = function()
		close(false)
	end
	handle.Dismiss = handle.Close
	handle._closeNow = function()
		close(true)
	end
	handle._cancelExit = function()
		if handle._exit then
			pcall(task.cancel, handle._exit)
			handle._exit = nil
		end
	end

	-- Auto-close (one task.delay, re-armed after hover) -----------------------------------------
	local function arm(seconds)
		cancelTimer()
		if not seconds or seconds <= 0 or seconds == math.huge then
			deadline = nil
			return
		end
		deadline = ctx.Library.Clock() + seconds
		timer = task.delay(seconds, function()
			timer = nil
			if not hovering then
				handle.Close()
			end
		end)
	end
	-- Loading stays open until closed, unless the caller gave an explicit Duration
	if options.Type == "Loading" and not givenDuration then
		arm(0)
	else
		arm(tonumber(options.Duration))
	end

	maid:Give(card.MouseEnter:Connect(function()
		hovering = true
		if timer then
			local remaining = deadline and (deadline - ctx.Library.Clock()) or 0
			handle._remaining = math.max(remaining, MIN_REARM)
			cancelTimer()
		end
	end))
	maid:Give(card.MouseLeave:Connect(function()
		if not hovering then
			return
		end
		hovering = false
		if handle._remaining then
			local remaining = handle._remaining
			handle._remaining = nil
			arm(remaining)
		end
	end))
	if handle.Dismissible then
		maid:Give(card.MouseButton1Click:Connect(handle.Close))
		local closeButton = Kit.IconButton(ctx, maid, {
			Name = "Close",
			Icon = "close",
			Size = 22,
			IconSize = 12,
			Tooltip = "Dismiss",
			Callback = handle.Close,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, -2),
			Parent = card,
		})
		handle.CloseButton = closeButton
	end

	-- Update ------------------------------------------------------------------------------------
	function handle:Update(changes)
		if self.Dismissed or type(changes) ~= "table" then
			return
		end
		if changes.Title ~= nil then
			self.TitleLabel.Text = tostring(changes.Title)
		end
		if changes.Content ~= nil then
			local text = tostring(changes.Content)
			self.ContentLabel.Text = text
			self.ContentLabel.Visible = text ~= ""
		end
		if changes.Type ~= nil then
			if TYPES[changes.Type] then
				self.Type = changes.Type
				self.Icon.Text = glyph(Icons, TYPES[changes.Type].Icon)
				self.Icon.TextColor3 = theme:Get(TYPES[changes.Type].Token)
			else
				warn("[MaUI] Notify: unknown Type '" .. tostring(changes.Type) .. "'")
			end
		end
		if changes.Duration ~= nil then
			handle._remaining = nil
			arm(tonumber(changes.Duration))
		elseif changes.Type ~= nil and not hovering then
			-- a new type without a duration: Loading stays open, anything else gets the default
			arm(self.Type == "Loading" and 0 or 4)
		end
	end

	card.Parent = wrapper
	tween:To(card, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0 }, Tokens.Motion.Slow)

	self._active[#self._active + 1] = handle
	while #self._active > self.MaxVisible do
		self._active[1].Close()
	end
	return handle
end

function Notifications:Destroy()
	for index = #self._active, 1, -1 do
		local handle = self._active[index]
		if handle then
			handle._closeNow()
		end
	end
	self._active = {}
	for handle in pairs(self._closing) do
		handle._cancelExit()
	end
	self._closing = {}
	if self._gui then
		self.Ctx.Theme:Release(self._gui)
		self._gui:Destroy()
		self._gui = nil
		self._holder = nil
	end
end

return Notifications
