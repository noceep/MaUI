-- Button: clickable control on a row.
--   AddButton({ Name = "Reset", Desc = "...", Icon = "refresh", Style = "Primary", Callback = function() end })
-- Style: Primary | Secondary (default) | Tertiary | Ghost | Destructive
-- Options: Compact (shorter, auto width), FullWidth (default true), IconOnly (square; Name becomes the tooltip),
--   Disabled, Loading, Tooltip, Confirm (two-click safety: "Click again to confirm" for 2.5 s).
-- States: default / hover / pressed / disabled / loading.
--   button:SetText / SetIcon / SetStyle / SetDisabled / SetLoading
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Button = Element.extend("Button")
Button.Persistent = false -- an action, not a value

local STYLES = {
	Primary = { Bg = "Accent", Text = "AccentText", Stroke = "Accent", Hover = 0.12, Press = 0.25 },
	Secondary = { Bg = "Surface2", Text = "Text", Stroke = "Stroke", Hover = "Surface3", Press = "Surface3" },
	Tertiary = { Bg = "AccentSoft", Text = "Accent", Stroke = "AccentSoft", Hover = 0.15, Press = 0.3 },
	Ghost = { Bg = "Surface3", Text = "Muted", Stroke = "Surface3", Ghost = true },
	Destructive = { Bg = "Surface2", Text = "Error", Stroke = "Error", Hover = "Surface3", Press = "Surface3" },
}
local SPINNER = { "◜", "◝", "◞", "◟" }
local CONFIRM_SECONDS = 2.5

function Button.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Button", Style = "Secondary", FullWidth = true })
	if not STYLES[options.Style] then
		warn("[MaUI] unknown button style '" .. tostring(options.Style) .. "', using Secondary")
		options.Style = "Secondary"
	end
	local self = setmetatable({}, Button)
	Element.init(self, ctx, options)
	self.Style = options.Style
	self.Disabled = options.Disabled == true
	self.Loading = false
	self._confirming = false
	self._text = options.Name
	self._spin = 0

	local height = options.Compact and ctx.Metrics.Compact or ctx.Metrics.Control
	if options.Desc and not options.Compact and not options.IconOnly then
		height = height + 12
	end
	local square = options.IconOnly == true
	local block = options.FullWidth and not options.Compact and not square
	self.Frame = Create("TextButton", {
		Name = options.Name,
		Size = block and UDim2.new(1, 0, 0, height) or UDim2.new(0, square and height or 0, 0, height),
		AutomaticSize = (block or square) and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Corner(self.Frame, Tokens.Radius.Md)
	self.Stroke = Kit.Stroke(ctx, self.Frame, "Stroke")
	ctx.Theme:Bind(self.Frame, "BackgroundColor3", function(t)
		return self:_bgColor(t)
	end)
	ctx.Theme:Bind(self.Stroke, "Color", function(t)
		return t:Get(STYLES[self.Style].Stroke)
	end)

	local content = Create("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(block and 1 or 0, 0, 1, 0), AutomaticSize = block and Enum.AutomaticSize.None or Enum.AutomaticSize.X, Parent = self.Frame })
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Md - 2), Parent = content,
	})
	if not square then
		Kit.Padding(content, Tokens.Space.Lg, Tokens.Space.Lg, 0, 0)
	end
	self.Content = content
	self:_buildIcon(options.Icon)
	self.Title = Kit.Text(ctx, {
		Name = "Title", Text = square and "" or options.Name, TextSize = Tokens.Type.Secondary.Size - 1,
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2, Visible = not square, Parent = content,
	}, function(t)
		return self:_textColor(t)
	end, "Medium")

	CK.Track(ctx, self.Maid, self.Frame, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		self:_click()
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip or (square and { Text = options.Name, Desc = options.Desc }) or nil)
	self.Maid:Give(function()
		self._spinning = false
		self._confirmToken = (self._confirmToken or 0) + 1
	end)

	self:_visual(false)
	if options.Loading then
		self:SetLoading(true)
	end
	return self
end

function Button:_bgColor(theme)
	local style = STYLES[self.Style]
	if self.Disabled then
		return theme:Get("Surface3")
	end
	return theme:Get(style.Bg)
end

function Button:_textColor(theme)
	local style = STYLES[self.Style]
	if self.Disabled then
		return theme:Get("Faint")
	end
	if self._confirming then
		return theme:Get(self.Style == "Destructive" and "Error" or "Warning")
	end
	if style.Ghost and self._hover then
		return theme:Get("Text")
	end
	return theme:Get(style.Text)
end

function Button:_buildIcon(icon)
	if self.IconInstance then
		self.Ctx.Theme:Release(self.IconInstance)
		self.IconInstance:Destroy()
		self.IconInstance = nil
	end
	self.IconInstance = Icons.Create(self.Ctx, { Icon = icon, Size = 15, Color = function(t)
		return self:_textColor(t)
	end, LayoutOrder = 1, Parent = self.Content })
end

-- Repaints hover / pressed / disabled / loading (never touches the text).
function Button:_visual(animate)
	if self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local style = STYLES[self.Style]
	local fast = animate and Tokens.Motion.Fast or 0
	local props = { BackgroundColor3 = self:_bgColor(theme) }
	local transparency = 0
	if style.Ghost then
		transparency = self.Disabled and 1 or (self._pressed and 0.3 or (self._hover and 0.6 or 1))
	elseif not self.Disabled then
		if self._pressed then
			if type(style.Press) == "string" then
				props.BackgroundColor3 = theme:Get(style.Press)
			else
				transparency = style.Press
			end
		elseif self._hover then
			if type(style.Hover) == "string" then
				props.BackgroundColor3 = theme:Get(style.Hover)
			else
				transparency = style.Hover
			end
		end
	else
		transparency = 0.4
	end
	props.BackgroundTransparency = transparency
	tween:To(self.Frame, props, fast)
	tween:To(self.Title, { TextColor3 = self:_textColor(theme) }, fast)
	if self.IconInstance then
		tween:To(self.IconInstance, { [Icons.ColorProperty(self.IconInstance)] = self:_textColor(theme) }, fast)
	end
	tween:To(self.Stroke, { Color = theme:Get(self.Disabled and "Stroke" or (self._hover and not style.Ghost and "StrokeHover" or style.Stroke)) }, fast)
end

function Button:_click()
	if self.Disabled or self.Loading then
		return
	end
	if self.Options.Confirm then
		if not self._confirming then
			self._confirming = true
			self._confirmToken = (self._confirmToken or 0) + 1
			local token = self._confirmToken
			self.Title.Text = "Click again to confirm"
			self.Title.Visible = true
			self:_visual(true)
			task.delay(CONFIRM_SECONDS, function()
				if token == self._confirmToken and self._confirming and not self.Destroyed then
					self:_cancelConfirm()
				end
			end)
			return
		end
		self:_cancelConfirm()
	end
	Util.Call(self.Options.Callback)
end

function Button:_cancelConfirm()
	self._confirming = false
	self._confirmToken = (self._confirmToken or 0) + 1
	self.Title.Text = self.Options.IconOnly and "" or self._text
	self.Title.Visible = not self.Options.IconOnly
	self:_visual(true)
end

function Button:SetText(text)
	self._text = tostring(text)
	self.Options.Name = self._text
	if not self.Loading and not self._confirming and not self.Options.IconOnly then
		self.Title.Text = self._text
	end
end

function Button:SetIcon(icon)
	self.Options.Icon = icon
	self:_buildIcon(icon)
end

function Button:SetStyle(style)
	if not STYLES[style] then
		warn("[MaUI] unknown button style: " .. tostring(style))
		return false
	end
	self.Style = style
	self:_visual(true)
	return true
end

function Button:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		if self._confirming then
			self:_cancelConfirm()
		end
	end
	self:_visual(true)
end

-- Loading: clicks are ignored and the label is replaced by a spinner glyph that advances only while loading.
function Button:SetLoading(loading)
	loading = loading == true
	if loading == self.Loading or self.Destroyed then
		return
	end
	self.Loading = loading
	if loading then
		if self._confirming then
			self:_cancelConfirm()
		end
		self._spinning = true
		self._spinToken = (self._spinToken or 0) + 1
		local token = self._spinToken
		self.Title.Visible = true
		local function step()
			if not self._spinning or token ~= self._spinToken or self.Destroyed then
				return
			end
			self._spin = self._spin % #SPINNER + 1
			self.Title.Text = SPINNER[self._spin] .. (self.Options.IconOnly and "" or "  " .. self._text)
			task.delay(0.12, step)
		end
		step()
	else
		self._spinning = false
		self._spinToken = (self._spinToken or 0) + 1
		self.Title.Text = self.Options.IconOnly and "" or self._text
		self.Title.Visible = not self.Options.IconOnly
	end
	self:_visual(true)
end

return Button
