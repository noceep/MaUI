-- Modular sources live in src/.
local __defs, __cache = {}, {}

local function __require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local definition = __defs[name]
	if not definition then
		error("[MaUI] module not found : " .. tostring(name), 2)
	end
	local result = definition(__require)
	if result == nil then
		result = true
	end
	__cache[name] = result
	return result
end

__defs["Components/Branding"] = function(require)
-- Branding: logo + name + version/status. Expanded (logo, name, version line) or compact (logo only).
--   Branding.new(ctx, parent, { Title = "MaUI", Version = "v0.2", Status = "success", Logo = "rbxassetid://..." | "bolt" })
--   branding:SetCompact(true) / :SetVersion("v0.3") / :SetStatus("warning")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local STATUS = { success = "Success", warning = "Warning", error = "Error", info = "Info", accent = "Accent", muted = "Muted" }

local Branding = {}
Branding.__index = Branding

function Branding.new(ctx, parent, options)
	options = Util.Options(options, { Title = "MaUI", Logo = "bolt" }, "Title")
	local self = setmetatable({}, Branding)
	self.Ctx = ctx
	self.Options = options
	local theme = ctx.Theme

	self.Frame = Create("Frame", { Name = "Branding", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Parent = parent })
	self.LogoBox = Create("Frame", {
		Name = "Logo", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, Tokens.Space.Lg, 0.5, 0),
		Size = UDim2.fromOffset(32, 32), BorderSizePixel = 0, Parent = self.Frame,
	})
	theme:Bind(self.LogoBox, "BackgroundColor3", "AccentSoft")
	Kit.Corner(self.LogoBox, Tokens.Radius.Md)
	self.LogoIcon = Icons.Create(ctx, {
		Icon = options.Logo, Size = 20, Color = "Accent",
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = self.LogoBox,
	})
	if self.LogoIcon and self.LogoIcon:IsA("ImageLabel") and options.LogoColor == false then
		self.LogoIcon.ImageColor3 = Color3.new(1, 1, 1)
		theme:Unbind(self.LogoIcon, "ImageColor3")
	end

	self.Texts = Create("Frame", {
		Name = "Texts", BackgroundTransparency = 1, Position = UDim2.fromOffset(Tokens.Space.Lg + 32 + Tokens.Space.Md, 0),
		Size = UDim2.new(1, -(Tokens.Space.Lg + 32 + Tokens.Space.Md + Tokens.Space.Md), 1, 0), Parent = self.Frame,
	})
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = self.Texts })
	self.Name = Kit.Text(ctx, { Name = "Name", Text = tostring(options.Title), TextSize = 14, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = self.Texts }, "Text", "Bold")
	local meta = Create("Frame", { Name = "Meta", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = self.Texts })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), Parent = meta })
	self.StatusDot = Create("Frame", { Name = "Status", Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, LayoutOrder = 1, Visible = options.Status ~= nil, Parent = meta })
	Kit.Corner(self.StatusDot, 6)
	self.Version = Kit.Text(ctx, { Name = "Version", Text = tostring(options.Version or ""), TextSize = Tokens.Type.Caption.Size, Size = UDim2.new(1, -12, 1, 0), LayoutOrder = 2, Parent = meta }, "Muted", "Regular")
	self:SetStatus(options.Status)
	return self
end

function Branding:SetStatus(status)
	self.StatusDot.Visible = status ~= nil
	if status then
		self.Ctx.Theme:Bind(self.StatusDot, "BackgroundColor3", STATUS[status] or "Muted")
	end
end

function Branding:SetVersion(text)
	self.Version.Text = tostring(text)
end

function Branding:SetTitle(text)
	self.Name.Text = tostring(text)
end

function Branding:SetCompact(compact)
	self.Compact = compact == true
	self.Texts.Visible = not self.Compact
	self.LogoBox.Position = self.Compact and UDim2.new(0.5, -16, 0.5, 0) or UDim2.new(0, Tokens.Space.Lg, 0.5, 0)
	self.LogoBox.AnchorPoint = Vector2.new(0, 0.5)
end

return Branding
end

__defs["Components/Button"] = function(require)
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
end

__defs["Components/Changelog"] = function(require)
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
end

__defs["Components/ColorPicker"] = function(require)
-- ColorPicker: Color3 value edited in a popup (saturation/value square, hue bar, hex field, presets).
--   AddColorPicker({ Name = "Accent", Default = Color3.fromRGB(255, 158, 200), Flag = "accent", Live = true,
--                    Presets = { Color3.fromRGB(...), ... }, Disabled = false, Callback = function(color) end })
--   picker:Set(Color3 | "FF9EC8") / Get() -> Color3 / SetDisabled(true) / Open() / Close()
-- Config value: "RRGGBB" hex string. Live = true fires the callback while dragging (once per input event).
-- Perf: dragging only moves two handles and recolors one frame; no tweens, no per-frame loop.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local ColorPicker = Element.extend("ColorPicker")

local DEFAULT_PRESETS = {
	Color3.fromRGB(255, 158, 200), Color3.fromRGB(255, 120, 130), Color3.fromRGB(246, 190, 120), Color3.fromRGB(140, 224, 170),
	Color3.fromRGB(150, 190, 255), Color3.fromRGB(190, 150, 255), Color3.fromRGB(248, 232, 240), Color3.fromRGB(40, 24, 34),
}

local function toHex(color)
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function parseHex(text)
	text = tostring(text):gsub("^#", "")
	if not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

function ColorPicker.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Color", Default = Color3.fromRGB(255, 158, 200), Live = true, Presets = DEFAULT_PRESETS })
	local self = setmetatable({}, ColorPicker)
	Element.init(self, ctx, options)
	self.Disabled = options.Disabled == true
	self.Opened = false
	self.H, self.S, self.V = 0, 1, 1

	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon, Order = order, Clickable = true, RightWidth = 96 })
	self.Frame = self.Row.Frame
	self.Swatch = Create("Frame", {
		Name = "Swatch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(ctx.Touch and 30 or 24, ctx.Touch and 30 or 24), BorderSizePixel = 0, Parent = self.Frame,
	})
	Kit.Corner(self.Swatch, Radius.Sm)
	self.SwatchStroke = Kit.Stroke(ctx, self.Swatch, "StrokeHover")
	self.HexLabel = Kit.Text(ctx, {
		Name = "Hex", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0), Size = UDim2.fromOffset(60, 16),
		TextSize = Tokens.Type.Supporting.Size, TextXAlignment = Enum.TextXAlignment.Right, Parent = self.Frame,
	}, "Muted", "Medium")

	CK.Track(ctx, self.Maid, self.Frame, self, function()
		CK.RowBackground(ctx, self.Frame, self, self.Disabled, Motion.Fast)
	end)
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		if self.Disabled then
			return
		end
		if self.Opened then
			self:Close()
		else
			self:Open()
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)
	self.Maid:Give(function()
		self:Close()
	end)
	self:_init(options.Default)
	CK.Dim(ctx, self.Row, self.Disabled, 0)
	return self
end

function ColorPicker:_normalize(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		return parseHex(value)
	end
	return nil
end

function ColorPicker:_equals(a, b)
	return toHex(a) == toHex(b)
end

function ColorPicker:_render(color)
	self.H, self.S, self.V = color:ToHSV()
	self.Swatch.BackgroundColor3 = color
	self.HexLabel.Text = "#" .. toHex(color)
	if self.Opened then
		self:_syncPopup()
	end
end

function ColorPicker:Serialize()
	return toHex(self.Value)
end

function ColorPicker:Deserialize(data, silent)
	self:Set(data, silent)
end

function ColorPicker:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self:Close()
	end
	CK.Dim(self.Ctx, self.Row, self.Disabled, Motion.Fast)
	self.Ctx.Tween:To(self.Swatch, { BackgroundTransparency = self.Disabled and 0.5 or 0 }, Motion.Fast)
end

-- Applies a color coming from the popup (drag, hex, preset): updates the value and fires the callback if Live
-- (or when `final`).
function ColorPicker:_fromHSV(h, s, v, final)
	local color = Color3.fromHSV(h, s, v)
	self.H, self.S, self.V = h, s, v
	if self:_equals(self.Value, color) then
		self:_syncPopup()
		return
	end
	self.Value = color
	self.Swatch.BackgroundColor3 = color
	self.HexLabel.Text = "#" .. toHex(color)
	self:_syncPopup()
	if self.Options.Live or final then
		self:_emit(color)
	else
		self._pending = true
	end
end

function ColorPicker:Open()
	if self.Opened or self.Disabled or self.Destroyed then
		return
	end
	local ctx = self.Ctx
	self.Opened = true
	self._popup = ctx.Popup:Open({
		Anchor = self.Swatch, Align = "Right", Width = 232, Height = 252,
		OnClose = function()
			self.Opened = false
			self._popup, self._ui = nil, nil
			if self._pending then
				self._pending = false
				self:_emit(self.Value)
			end
		end,
		Build = function(frame)
			self:_build(frame)
		end,
	})
end

function ColorPicker:_build(frame)
	local ctx = self.Ctx
	local ui = {}
	self._ui = ui
	Kit.Padding(frame, Space.Md, Space.Md, Space.Md, Space.Md)

	-- saturation / value square: base hue + white gradient (left->right) + black gradient (top->bottom)
	ui.Square = Create("TextButton", { Name = "SV", Size = UDim2.new(1, 0, 0, 130), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = frame })
	Kit.Corner(ui.Square, Radius.Sm)
	local white = Create("Frame", { Name = "White", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ui.Square })
	Kit.Corner(white, Radius.Sm)
	Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = Create("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = ui.Square })
	Kit.Corner(black, Radius.Sm)
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	ui.Cursor = Create("Frame", { Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = ui.Square })
	Kit.Corner(ui.Cursor, 12)
	Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = ui.Cursor })

	-- hue bar
	ui.Hue = Create("TextButton", { Name = "Hue", Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 14), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = frame })
	Kit.Corner(ui.Hue, 7)
	local stops = {}
	for i = 0, 6 do
		stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0.999 or i / 6, 1, 1))
	end
	Create("UIGradient", { Color = ColorSequence.new(stops), Parent = ui.Hue })
	ui.HueCursor = Create("Frame", { Name = "Cursor", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 18), BorderSizePixel = 0, ZIndex = 3, Parent = ui.Hue })
	Kit.Corner(ui.HueCursor, 3)
	Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = ui.HueCursor })

	-- hex field + RGB readout
	ui.Hex = Create("TextBox", {
		Name = "HexInput", Position = UDim2.fromOffset(0, 160), Size = UDim2.fromOffset(86, 26), BorderSizePixel = 0, Text = "", PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false, TextSize = 13, FontFace = ctx.Fonts.Medium, Parent = frame,
	})
	ctx.Theme:Bind(ui.Hex, "BackgroundColor3", "Surface2")
	ctx.Theme:Bind(ui.Hex, "TextColor3", "Text")
	ctx.Theme:Bind(ui.Hex, "PlaceholderColor3", "Faint")
	Kit.Corner(ui.Hex, Radius.Sm)
	ui.HexStroke = Kit.Stroke(ctx, ui.Hex, "Stroke")
	ui.RGB = Kit.Text(ctx, { Name = "RGB", Position = UDim2.fromOffset(94, 160), Size = UDim2.new(1, -94, 0, 26), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Parent = frame }, "Muted", "Regular")
	self.Maid:Give(ui.Hex.FocusLost:Connect(function()
		local color = parseHex(ui.Hex.Text)
		if color then
			ctx.Theme:Bind(ui.HexStroke, "Color", "Stroke")
			self:Set(color)
		else
			ctx.Theme:Bind(ui.HexStroke, "Color", "Error")
			ui.Hex.Text = "#" .. toHex(self.Value)
		end
	end))

	-- presets
	local presets = Create("Frame", { Name = "Presets", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 44), Parent = frame })
	Create("UIGridLayout", { CellSize = UDim2.fromOffset(22, 22), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = presets })
	for index, color in ipairs(self.Options.Presets or {}) do
		local swatch = Create("TextButton", { Name = "Preset", BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = index, Parent = presets })
		Kit.Corner(swatch, Radius.Sm)
		Kit.Stroke(ctx, swatch, "Stroke")
		swatch.MouseButton1Click:Connect(function()
			self:Set(color)
		end)
	end

	-- drags: both areas share one handler that maps the pointer into their local space
	local function bindDrag(area, onMove)
		self.Maid:Give(area.InputBegan:Connect(function(input)
			if Input.IsPointerDown(input) then
				onMove(input.Position)
				ctx.Input:Capture(self, input, function(moveInput)
					onMove(moveInput.Position)
				end, function()
					if self._pending then
						self._pending = false
						self:_emit(self.Value)
					end
				end)
			end
		end))
	end
	bindDrag(ui.Square, function(position)
		local size, origin = ui.Square.AbsoluteSize, ui.Square.AbsolutePosition
		local s = Util.Clamp((position.X - origin.X) / math.max(size.X, 1), 0, 1)
		local v = 1 - Util.Clamp((position.Y - origin.Y) / math.max(size.Y, 1), 0, 1)
		self:_fromHSV(self.H, s, v)
	end)
	bindDrag(ui.Hue, function(position)
		local size, origin = ui.Hue.AbsoluteSize, ui.Hue.AbsolutePosition
		local h = Util.Clamp((position.X - origin.X) / math.max(size.X, 1), 0, 0.999)
		self:_fromHSV(h, self.S, self.V)
	end)
	self:_syncPopup()
end

-- Repositions the cursors and recolors the square for the current value.
function ColorPicker:_syncPopup()
	local ui = self._ui
	if not ui then
		return
	end
	ui.Square.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	ui.Cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
	ui.HueCursor.Position = UDim2.fromScale(self.H, 0.5)
	ui.HueCursor.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	ui.Hex.Text = "#" .. toHex(self.Value)
	ui.RGB.Text = string.format("%d, %d, %d", math.floor(self.Value.R * 255 + 0.5), math.floor(self.Value.G * 255 + 0.5), math.floor(self.Value.B * 255 + 0.5))
end

function ColorPicker:Close()
	local popup = self._popup
	if popup then
		popup:Close()
	end
end

function ColorPicker:IsOpen()
	return self.Opened
end

return ColorPicker
end

__defs["Components/Columns"] = function(require)
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
end

__defs["Components/ConfigManager"] = function(require)
-- ConfigManager: ready-made card to manage saved configurations.
--   section:AddConfigManager({ Title = "Configs" })
-- Create / Save / Load / Rename / Delete / Reset, autoload, and import / export through a shareable code.
-- Destructive actions (Delete, Reset) ask for a second click. Every result is reported with a notification.
local Section = require("Components/Section")
local Util = require("Core/Util")
local Env = require("Core/Env")

local ConfigManager = {}
ConfigManager.__index = ConfigManager
ConfigManager.Persistent = false

function ConfigManager.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "Configs", Icon = "folder" }, "Title")
	local self = setmetatable({}, ConfigManager)
	local library = ctx.Library
	self.Options = options
	self.Section = Section.new(ctx, { Name = options.Title, Icon = options.Icon, Variant = "Settings" }, parent, order)
	self.Frame = self.Section.Frame
	local card = self.Section

	local function notify(title, content, kind)
		library:Notify({ Title = title, Content = content, Type = kind })
	end
	local function report(ok, err, okTitle, name, failTitle)
		if ok then
			notify(okTitle, name, "Success")
		else
			notify(failTitle, tostring(err), "Error")
		end
		return ok
	end

	self.NameBox = card:AddTextBox({ Name = "Name", Placeholder = "config name", Width = 160 })
	self.List = card:AddDropdown({ Name = "Saved", Items = library:ListConfigs(), Placeholder = "none", Width = 160 })
	self.Status = card:AddLabel({ Text = "" })

	local function refresh(select)
		self.List:SetItems(library:ListConfigs())
		if select then
			self.List:Set(select, true)
		end
		local loaded = library.ConfigName
		local autoload = library:GetAutoload()
		self.Status:SetText("loaded: " .. tostring(loaded or "none") .. "  |  autoload: " .. tostring(autoload or "none"))
	end
	self.Refresh = refresh
	local function typedOrSelected()
		local typed = Util.Trim(self.NameBox:Get() or "")
		if typed ~= "" then
			return typed
		end
		return self.List:Get()
	end
	local function selected()
		return self.List:Get() or typedOrSelected()
	end

	local a = card:AddColumns(2)
	a[1]:AddButton({ Name = "Create", Icon = "plus", Callback = function()
		local name = Util.Trim(self.NameBox:Get() or "")
		if name == "" then
			return notify("Name required", "Type a name for the new config", "Warning")
		end
		if report(library:SaveConfig(name)) then
			notify("Config created", name, "Success")
		end
		refresh(name)
	end })
	a[2]:AddButton({ Name = "Save", Icon = "check", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config or type a name", "Warning")
		end
		local ok, err = library:SaveConfig(name)
		report(ok, err, "Config saved", name, "Could not save")
		refresh(name)
	end })
	local b = card:AddColumns(2)
	b[1]:AddButton({ Name = "Load", Icon = "folder", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config first", "Warning")
		end
		local ok, err = library:LoadConfig(name)
		report(ok, err, "Config loaded", name, "Could not load")
		refresh()
	end })
	b[2]:AddButton({ Name = "Rename", Icon = "settings", Callback = function()
		local new = Util.Trim(self.NameBox:Get() or "")
		local old = self.List:Get()
		if not old or new == "" then
			return notify("Rename", "Pick a config and type the new name", "Warning")
		end
		local ok, err = library:RenameConfig(old, new)
		report(ok, err, "Config renamed", new, "Could not rename")
		refresh(ok and new or nil)
	end })
	local c = card:AddColumns(2)
	c[1]:AddButton({ Name = "Delete", Style = "Destructive", Confirm = true, Icon = "close", Callback = function()
		local name = self.List:Get()
		if not name then
			return notify("Nothing selected", "Pick a config to delete", "Warning")
		end
		local ok, err = library:DeleteConfig(name)
		report(ok, err, "Config deleted", name, "Could not delete")
		if ok and library:GetAutoload() == name then
			library:SetAutoload(nil)
		end
		refresh()
		self.List:Set(nil, true)
	end })
	c[2]:AddButton({ Name = "Reset", Style = "Destructive", Confirm = true, Icon = "refresh", Callback = function()
		local count = library:ResetConfig()
		notify("Defaults restored", count .. " settings reset", "Info")
	end })
	local d = card:AddColumns(2)
	d[1]:AddButton({ Name = "Set autoload", Icon = "star", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config first", "Warning")
		end
		local ok, err = library:SetAutoload(name)
		report(ok, err, "Autoload set", name, "Could not set autoload")
		refresh()
	end })
	d[2]:AddButton({ Name = "Clear autoload", Callback = function()
		library:SetAutoload(nil)
		notify("Autoload cleared", "No config loads automatically", "Info")
		refresh()
	end })

	self.Code = card:AddTextBox({ Name = "Config code", Placeholder = "paste a code here", Width = 160 })
	local e = card:AddColumns(2)
	e[1]:AddButton({ Name = "Export", Icon = "copy", Callback = function()
		local code, err = library:ExportConfig()
		if not code then
			return notify("Could not export", tostring(err), "Error")
		end
		self.Code:Set(code, true)
		if Env.SetClipboard and Env.SetClipboard(code) then
			notify("Config copied", "The code is in your clipboard", "Success")
		else
			notify("Config code ready", "Copy it from the field above", "Info")
		end
	end })
	e[2]:AddButton({ Name = "Import", Icon = "play", Callback = function()
		local ok, err = library:ImportConfig(self.Code:Get() or "")
		report(ok, err, "Config imported", "values applied", "Could not import")
	end })
	refresh()
	return self
end

function ConfigManager:Destroy()
	self.Section:Destroy()
end

function ConfigManager:SetVisible(visible)
	self.Section:SetVisible(visible)
end

return ConfigManager
end

__defs["Components/Container"] = function(require)
-- Container: adds the AddXxx methods to a class (Tab, Section).
-- Contract: the class provides self.Ctx, self.Content (parent Instance), self.Maid,
--           self.Elements (list) and self._order (LayoutOrder counter).
local Button = require("Components/Button")
local Changelog = require("Components/Changelog")
local KeyStatus = require("Components/KeyStatus")
local Keybind = require("Components/Keybind")
local Label = require("Components/Label")
local Paragraph = require("Components/Paragraph")
local Profile = require("Components/Profile")
local Slider = require("Components/Slider")
local Toggle = require("Components/Toggle")

local Container = {}

function Container.apply(class)
	function class:_AddElement(componentClass, options)
		self._order = self._order + 1
		local element = componentClass.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = element
		self.Maid:Give(element)
		return element
	end

	-- Cards, column layouts and sub-tabs (required lazily: Section/Columns/SubTabs themselves use Container).
	function class:AddSection(options)
		local Section = require("Components/Section")
		self._order = self._order + 1
		local section = Section.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = section
		self.Maid:Give(section)
		self._plain = nil
		return section
	end
	class.AddCard = class.AddSection

	function class:AddColumns(options)
		local Columns = require("Components/Columns")
		self._order = self._order + 1
		local columns = Columns.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = columns
		self.Maid:Give(columns)
		self._plain = nil
		return Columns.array(columns)
	end

	function class:AddSubTabs(options)
		local SubTabs = require("Components/SubTabs")
		self._order = self._order + 1
		local group = SubTabs.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = group
		self.Maid:Give(group)
		self._plain = nil
		return group
	end

	-- Components below are required lazily so each can use Container itself and so a missing optional
	-- component never breaks loading of the others.
	local function lazy(methodName, moduleName)
		class[methodName] = function(self, options)
			return self:_AddElement(require(moduleName), options)
		end
	end
	lazy("AddDropdown", "Components/Dropdown")
	lazy("AddTextBox", "Components/TextBox")
	lazy("AddColorPicker", "Components/ColorPicker")
	lazy("AddMetric", "Components/Metric")
	lazy("AddDataRow", "Components/DataRow")
	lazy("AddKeycap", "Components/Keycap")
	lazy("AddThemeEditor", "Components/ThemeEditor")
	lazy("AddConfigManager", "Components/ConfigManager")

	function class:AddToggle(options)
		return self:_AddElement(Toggle, options)
	end

	function class:AddSlider(options)
		return self:_AddElement(Slider, options)
	end

	function class:AddLabel(options)
		return self:_AddElement(Label, options)
	end

	function class:AddButton(options)
		return self:_AddElement(Button, options)
	end

	function class:AddKeybind(options)
		return self:_AddElement(Keybind, options)
	end

	function class:AddParagraph(options)
		return self:_AddElement(Paragraph, options)
	end

	function class:AddProfile(options)
		return self:_AddElement(Profile, options)
	end

	function class:AddKeyStatus(options)
		return self:_AddElement(KeyStatus, options)
	end

	function class:AddChangelog(options)
		return self:_AddElement(Changelog, options)
	end
end

return Container
end

__defs["Components/ControlKit"] = function(require)
-- ControlKit: tiny helpers shared by the control components (Toggle, Slider, Button, Keybind,
-- DataRow, Metric...). Pointer-state tracking, disabled dimming and tooltip attachment live here
-- so every control reacts to hover / pressed / disabled in exactly the same way.
local Icons = require("Core/Icons")
local Tokens = require("Core/Tokens")

local CK = {}

local DISABLED_ALPHA = 0.5

-- Tracks hover/pressed on `target` into `state._hover` / `state._pressed` and calls onChange()
-- after every real change. Hover is ignored on touch devices (no pointer to hover with).
function CK.Track(ctx, maid, target, state, onChange)
	local function apply(hover, pressed)
		if state._hover ~= hover or state._pressed ~= pressed then
			state._hover, state._pressed = hover, pressed
			onChange()
		end
	end
	state._hover, state._pressed = false, false
	if not ctx.Touch then
		maid:Give(target.MouseEnter:Connect(function()
			apply(true, state._pressed)
		end))
	end
	maid:Give(target.MouseLeave:Connect(function()
		apply(false, false)
	end))
	-- only buttons have MouseButton1Down/Up (a Frame errors on access in real Roblox)
	if target:IsA("GuiButton") then
		maid:Give(target.MouseButton1Down:Connect(function()
			apply(state._hover, true)
		end))
		maid:Give(target.MouseButton1Up:Connect(function()
			apply(state._hover, false)
		end))
	end
end

-- Attaches a tooltip (string | { Text, Desc, Key, Delay }) and gives the handle to the maid.
function CK.Tooltip(ctx, maid, instance, tip)
	if tip == nil or tip == false or not ctx.Tooltip then
		return nil
	end
	local handle = ctx.Tooltip:Attach(instance, tip)
	maid:Give(handle)
	return handle
end

function CK.TransparencyProperty(instance)
	if instance:IsA("ImageLabel") then
		return "ImageTransparency"
	end
	return "TextTransparency"
end

-- Dims (or restores) the texts and the icon of a Kit.Row.
function CK.Dim(ctx, row, disabled, duration)
	local alpha = disabled and DISABLED_ALPHA or 0
	ctx.Tween:To(row.Title, { TextTransparency = alpha }, duration)
	if row.Desc then
		ctx.Tween:To(row.Desc, { TextTransparency = alpha }, duration)
	end
	if row.Icon then
		ctx.Tween:To(row.Icon, { [CK.TransparencyProperty(row.Icon)] = alpha }, duration)
	end
end

-- Row background feedback: transparent at rest, fades in on hover and a bit more while pressed.
function CK.RowBackground(ctx, frame, state, disabled, duration)
	local alpha = 1
	if not disabled then
		if state._pressed then
			alpha = 0.35
		elseif state._hover then
			alpha = 0.55
		end
	end
	ctx.Tween:To(frame, { BackgroundTransparency = alpha }, duration)
end

CK.Motion = Tokens.Motion
CK.Icons = Icons

return CK
end

__defs["Components/DataRow"] = function(require)
-- DataRow: read-only "label ... value" line with an optional status and row actions.
--   AddDataRow({ Name = "Ping", Value = "42 ms", Icon = "bolt", Status = "success",
--                Desc = "Round trip to the server",
--                Actions = { { Icon = "copy", Tooltip = "Copy", Callback = function() end } } })
--   row:SetValue("55 ms")  row:SetStatus("warning")  row:SetName("Latency")
-- Status: success | warning | error | info | muted. The status is shown as a colored value AND a
-- glyph, never by color alone. Never saved in configs (Persistent = false).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local DataRow = Element.extend("DataRow")
DataRow.Persistent = false

local STATUS = {
	success = { Token = "Success", Glyph = "success" },
	warning = { Token = "Warning", Glyph = "warning" },
	error = { Token = "Error", Glyph = "error" },
	info = { Token = "Info", Glyph = "info" },
	muted = { Token = "Muted", Glyph = nil },
}

function DataRow.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Data", Value = "" })
	local self = setmetatable({}, DataRow)
	Element.init(self, ctx, options)

	local actions = type(options.Actions) == "table" and options.Actions or {}
	local buttonSize = ctx.Touch and 36 or 28
	local actionsWidth = #actions * (buttonSize + Tokens.Space.Sm)
	self._valueWidth = 120
	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		RightWidth = self._valueWidth + actionsWidth,
	})
	self.Frame = self.Row.Frame
	self.Status = nil

	-- right side: [status glyph] [value] [actions...]
	self.Right = Create("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = self.Frame,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Sm),
		Parent = self.Right,
	})
	self.StatusIcon = Create("TextLabel", {
		Name = "StatusIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(14, 14),
		Text = "",
		TextSize = 13,
		FontFace = ctx.Fonts.Bold,
		Visible = false,
		LayoutOrder = 1,
		Parent = self.Right,
	})
	ctx.Theme:Bind(self.StatusIcon, "TextColor3", function(t)
		return self:_statusColor(t)
	end)
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Tokens.Type.Secondary.Size - 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.None,
		LayoutOrder = 2,
		Parent = self.Right,
	}, function(t)
		return self:_statusColor(t)
	end, "Medium")

	self.ActionButtons = {}
	for index, action in ipairs(actions) do
		if type(action) == "table" then
			local button = Kit.IconButton(ctx, self.Maid, {
				Name = "Action" .. index,
				Icon = action.Icon or "dot",
				Tooltip = action.Tooltip,
				Callback = action.Callback,
				LayoutOrder = 2 + index,
				Parent = self.Right,
			})
			self.ActionButtons[#self.ActionButtons + 1] = button
		end
	end

	self:SetStatus(options.Status)
	self:_init(options.Value)
	return self
end

function DataRow:_statusColor(theme)
	local status = STATUS[self.Status]
	if status and self.Status ~= "muted" then
		return theme:Get(status.Token)
	end
	return theme:Get(self.Status == "muted" and "Muted" or "Text")
end

function DataRow:_normalize(value)
	if value == nil then
		return nil
	end
	return tostring(value)
end

function DataRow:_render(value)
	self.ValueLabel.Text = value
end

function DataRow:SetValue(value)
	self:Set(value, true)
end

function DataRow:SetStatus(status)
	if self.Destroyed then
		return
	end
	if status ~= nil and not STATUS[status] then
		warn("[MaUI] DataRow: unknown Status '" .. tostring(status) .. "'")
		status = nil
	end
	self.Status = status
	local info = status and STATUS[status]
	local glyph = info and info.Glyph and Icons.Resolve(info.Glyph)
	self.StatusIcon.Visible = glyph ~= nil
	if info and info.Glyph then
		local _, text = Icons.Resolve(info.Glyph)
		self.StatusIcon.Text = text or ""
	end
	local theme = self.Ctx.Theme
	self.ValueLabel.TextColor3 = self:_statusColor(theme)
	self.StatusIcon.TextColor3 = self:_statusColor(theme)
end

function DataRow:SetName(name)
	if not self.Destroyed then
		self.Row.Title.Text = tostring(name)
	end
end

function DataRow:Serialize()
	return nil
end

function DataRow:Deserialize() end

return DataRow
end

__defs["Components/Dropdown"] = function(require)
-- Dropdown: pick one (or several) values from a list; the menu floats on the Popup layer.
--   AddDropdown({ Name = "Stage", Items = { "Stage 1", { Name = "Stage 2", Value = 2, Icon = "star", Desc = "Harder" } },
--                 Default = "Stage 1", Multi = false, Searchable = false, Placeholder = "Select...",
--                 MaxHeight = 220, Flag = "stage", Disabled = false, Callback = function(value) end })
--   dropdown:Set("Stage 1") / Get() / SetItems({...}) / AddItem(item) / Open() / Close() / SetDisabled(true)
-- Value: the item's Value (or its Name for plain strings). Multi = true -> array of values.
-- Items are only instantiated while the menu is open (nothing is pooled or hidden).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")
local CK = require("Components/ControlKit")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local Dropdown = Element.extend("Dropdown")

local function normalizeItems(items)
	local list = {}
	for _, item in ipairs(items or {}) do
		if type(item) == "table" then
			local name = tostring(item.Name or item.Value or "?")
			local value = item.Value
			if value == nil then
				value = name
			end
			list[#list + 1] = { Name = name, Value = value, Icon = item.Icon, Desc = item.Desc, Disabled = item.Disabled == true }
		else
			list[#list + 1] = { Name = tostring(item), Value = item }
		end
	end
	return list
end

function Dropdown.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Dropdown", Items = {}, Multi = false, Searchable = false, Placeholder = "Select...", MaxHeight = 220 })
	local self = setmetatable({}, Dropdown)
	Element.init(self, ctx, options)
	self.Items = normalizeItems(options.Items)
	self.Multi = options.Multi == true
	self.Disabled = options.Disabled == true
	self.Opened = false

	local fieldWidth = options.Width or 150
	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon, Order = order, RightWidth = fieldWidth + Space.Sm })
	self.Frame = self.Row.Frame
	self.Field = Create("TextButton", {
		Name = "Field", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(fieldWidth, ctx.Metrics.Compact + 4), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = self.Frame,
	})
	ctx.Theme:Bind(self.Field, "BackgroundColor3", "Surface2")
	Kit.Corner(self.Field, Radius.Md)
	self.FieldStroke = Kit.Stroke(ctx, self.Field, "Stroke")
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = Tokens.Type.Supporting.Size + 1, Parent = self.Field,
	}, "Text", "Medium")
	self.Chevron = Icons.Create(ctx, { Icon = "chevron", Name = "Chevron", Size = 14, Color = "Muted", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = self.Field })

	CK.Track(ctx, self.Maid, self.Field, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Field.MouseButton1Click:Connect(function()
		if not self.Disabled then
			if self.Opened then
				self:Close()
			else
				self:Open()
			end
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Field, options.Tooltip)
	self.Maid:Give(function()
		self:Close()
	end)

	self:_init(self.Multi and (options.Default or {}) or options.Default)
	self:_visual(false)
	return self
end

function Dropdown:_find(value)
	for _, item in ipairs(self.Items) do
		if item.Value == value or item.Name == value then
			return item
		end
	end
	return nil
end

function Dropdown:_normalize(value)
	if self.Multi then
		if type(value) ~= "table" then
			return nil
		end
		local out = {}
		for _, entry in ipairs(value) do
			local item = self:_find(entry)
			if item then
				out[#out + 1] = item.Value
			end
		end
		return out
	end
	if value == nil then
		return false -- nothing selected
	end
	local item = self:_find(value)
	if not item then
		return nil
	end
	return item.Value
end

function Dropdown:_equals(a, b)
	if self.Multi then
		if #a ~= #b then
			return false
		end
		for index, entry in ipairs(a) do
			if b[index] ~= entry then
				return false
			end
		end
		return true
	end
	return a == b
end

function Dropdown:_isSelected(item)
	if self.Multi then
		for _, entry in ipairs(self.Value or {}) do
			if entry == item.Value then
				return true
			end
		end
		return false
	end
	return self.Value == item.Value
end

function Dropdown:_label()
	if self.Multi then
		local names = {}
		for _, item in ipairs(self.Items) do
			if self:_isSelected(item) then
				names[#names + 1] = item.Name
			end
		end
		if #names == 0 then
			return nil
		elseif #names <= 2 then
			return table.concat(names, ", ")
		end
		return #names .. " selected"
	end
	local item = self.Value ~= false and self:_find(self.Value)
	return item and item.Name or nil
end

function Dropdown:_render()
	local text = self:_label()
	self.ValueLabel.Text = text or self.Options.Placeholder
	self.Ctx.Theme:Bind(self.ValueLabel, "TextColor3", (text and not self.Disabled) and "Text" or "Muted")
	if self.Opened then
		self:_refreshItems()
	end
end

function Dropdown:_visual(animate)
	if self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local d = animate and Motion.Fast or 0
	local stroke = self.Opened and "Accent" or ((self._hover and not self.Disabled) and "StrokeHover" or "Stroke")
	tween:To(self.FieldStroke, { Color = theme:Get(stroke) }, d)
	tween:To(self.Field, { BackgroundColor3 = theme:Get((self._pressed and not self.Disabled) and "Surface3" or "Surface2"), BackgroundTransparency = self.Disabled and 0.5 or 0 }, d)
	if self.Chevron then
		tween:To(self.Chevron, { Rotation = self.Opened and 180 or 0 }, d)
	end
	tween:To(self.ValueLabel, { TextTransparency = self.Disabled and 0.5 or 0 }, d)
	CK.Dim(ctx, self.Row, self.Disabled, d)
end

-- Menu -------------------------------------------------------------------------------------------------
function Dropdown:Open()
	if self.Opened or self.Disabled or self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local rowHeight = ctx.Metrics.Control - 2
	local searchHeight = self.Options.Searchable and 34 or 0
	local count = math.max(#self.Items, 1)
	local itemsHeight = 0
	for _, item in ipairs(self.Items) do
		itemsHeight = itemsHeight + rowHeight + (item.Desc and 14 or 0)
	end
	itemsHeight = math.max(itemsHeight, rowHeight) + Space.Sm * 2
	local height = math.min(itemsHeight + searchHeight, self.Options.MaxHeight + searchHeight)
	self.Opened = true
	self._popup = ctx.Popup:Open({
		Anchor = self.Field, Width = math.max(self.Field.AbsoluteSize.X, 160), Height = height,
		OnClose = function()
			self.Opened = false
			self._popup, self._list, self._empty, self._filter = nil, nil, nil, ""
			self:_visual(true)
		end,
		Build = function(frame)
			self:_build(frame, searchHeight)
		end,
	})
	self:_visual(true)
end

function Dropdown:_build(frame, searchHeight)
	local ctx = self.Ctx
	self._filter = ""
	if searchHeight > 0 then
		local box = Create("TextBox", {
			Name = "Search", Position = UDim2.fromOffset(Space.Md, Space.Md), Size = UDim2.new(1, -Space.Md * 2, 0, 26), BorderSizePixel = 0,
			Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false, TextSize = 13, FontFace = ctx.Fonts.Regular,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
		})
		ctx.Theme:Bind(box, "BackgroundColor3", "Surface2")
		ctx.Theme:Bind(box, "TextColor3", "Text")
		ctx.Theme:Bind(box, "PlaceholderColor3", "Faint")
		Kit.Corner(box, Radius.Sm)
		Kit.Padding(box, 8, 8, 0, 0)
		self.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			self._filter = box.Text:lower()
			self:_refreshItems()
		end))
		self._searchBox = box
	end
	self._list = Create("ScrollingFrame", {
		Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 1, -searchHeight), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, Parent = frame,
	})
	ctx.Theme:Bind(self._list, "ScrollBarImageColor3", "Surface3")
	Kit.Padding(self._list, Space.Sm, Space.Sm, Space.Sm, Space.Sm)
	Kit.List(self._list, 2)
	self._empty = Kit.Text(ctx, { Name = "Empty", Text = "No results", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = frame, Position = UDim2.fromOffset(0, searchHeight + 8) }, "Muted", "Regular")
	self:_refreshItems()
end

function Dropdown:_refreshItems()
	local list = self._list
	if not list then
		return
	end
	local ctx = self.Ctx
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			ctx.Theme:Release(child)
			child:Destroy()
		end
	end
	local shown = 0
	for index, item in ipairs(self.Items) do
		if self._filter == "" or item.Name:lower():find(self._filter, 1, true) then
			shown = shown + 1
			self:_buildItem(list, item, index)
		end
	end
	if self._empty then
		self._empty.Visible = shown == 0
	end
end

function Dropdown:_buildItem(list, item, index)
	local ctx = self.Ctx
	local selected = self:_isSelected(item)
	local height = ctx.Metrics.Control - 2 + (item.Desc and 14 or 0)
	local button = Create("TextButton", {
		Name = "Item", Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, AutoButtonColor = false, Text = "",
		LayoutOrder = index, BackgroundTransparency = selected and 0 or 1, Parent = list,
	})
	ctx.Theme:Bind(button, "BackgroundColor3", selected and "AccentSoft" or "Surface3")
	Kit.Corner(button, Radius.Sm)
	local left = 10
	if item.Icon then
		if Icons.Create(ctx, { Icon = item.Icon, Size = 15, Color = selected and "Accent" or "Muted", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = button }) then
			left = 32
		end
	end
	local holder = Create("Frame", { Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -(left + 30), 1, 0), Parent = button })
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = holder })
	Kit.Text(ctx, { Name = "Name", Text = item.Name, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = holder }, item.Disabled and "Faint" or (selected and "Accent" or "Text"), "Medium")
	if item.Desc then
		Kit.Text(ctx, { Name = "Desc", Text = item.Desc, TextSize = 11, Size = UDim2.new(1, 0, 0, 13), LayoutOrder = 2, Parent = holder }, "Muted", "Regular")
	end
	if selected then
		Icons.Create(ctx, { Icon = "check", Name = "Check", Size = 14, Color = "Accent", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = button })
	end
	if not ctx.Touch and not item.Disabled and not selected then
		button.MouseEnter:Connect(function()
			ctx.Tween:To(button, { BackgroundTransparency = 0.5 }, Motion.Fast)
		end)
		button.MouseLeave:Connect(function()
			ctx.Tween:To(button, { BackgroundTransparency = 1 }, Motion.Base)
		end)
	end
	button.MouseButton1Click:Connect(function()
		if item.Disabled then
			return
		end
		self:_pick(item)
	end)
end

function Dropdown:_pick(item)
	if self.Multi then
		local value, found = {}, false
		for _, entry in ipairs(self.Value or {}) do
			if entry == item.Value then
				found = true
			else
				value[#value + 1] = entry
			end
		end
		if not found then
			value[#value + 1] = item.Value
		end
		self:Set(value)
	else
		self:Set(item.Value)
		self:Close()
	end
end

function Dropdown:Close()
	local popup = self._popup
	if popup then
		popup:Close()
	end
end

function Dropdown:IsOpen()
	return self.Opened
end

function Dropdown:SetItems(items)
	self.Items = normalizeItems(items)
	-- drop values that no longer exist
	local kept = self:_normalize(self.Value == false and nil or self.Value)
	self.Value = kept == nil and (self.Multi and {} or false) or kept
	self:_render()
end

function Dropdown:AddItem(item)
	local list = normalizeItems({ item })
	self.Items[#self.Items + 1] = list[1]
	self:_render()
end

function Dropdown:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		self:Close()
	end
	self:_render()
	self:_visual(true)
end

function Dropdown:Get()
	if self.Value == false then
		return nil
	end
	return self.Value
end

function Dropdown:Serialize()
	return self.Value
end

function Dropdown:Deserialize(data, silent)
	if data == nil or (not self.Multi and type(data) == "table") then
		return
	end
	self:Set(data, silent)
end

return Dropdown
end

__defs["Components/DynamicIsland"] = function(require)
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
local Input = require("Core/Input")
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
	self:_bindDrag(self.Pill)
	self:_bindDrag(self.Header)

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
	if options.Window then
		self:LinkWindow(options.Window)
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
		if self:_wasDragged() then
			return
		end
		if self.Window then
			self:_openWindow()
		elseif ctx.Touch then
			self:Expand()
		else
			self:Pin(not self.Pinned)
		end
	end))
end

-- Dragging -----------------------------------------------------------------------------------------------------------
-- The pill and the expanded header move the island. A press that moved less than DRAG_THRESHOLD pixels is a click.
local DRAG_THRESHOLD = 4

function DynamicIsland:_wasDragged()
	local moved = self._moved or 0
	self._moved = 0
	return moved >= DRAG_THRESHOLD
end

function DynamicIsland:_bindDrag(handle)
	local ctx = self.Ctx
	self.Maid:Give(handle.InputBegan:Connect(function(input)
		if not Input.IsPointerDown(input) or self.Destroyed then
			return
		end
		self._moved = 0
		ctx.Input:Capture(self, input, function(moveInput)
			local delta = moveInput.Delta
			self._moved = self._moved + math.abs(delta.X) + math.abs(delta.Y)
			if self._moved < DRAG_THRESHOLD then
				return
			end
			local base = self._basePosition
			self._basePosition = UDim2.new(base.X.Scale, base.X.Offset + delta.X, base.Y.Scale, base.Y.Offset + delta.Y)
			self._custom = true
			local size = self.Root.Size
			self._basePosition = self:_positionFor(Vector2.new(size.X.Offset, size.Y.Offset))
			self.Root.Position = self._basePosition
		end, nil)
	end))
end

-- Companion window: the island only shows while the window is hidden, and clicking it opens the window.
function DynamicIsland:LinkWindow(window)
	if self.Destroyed or not window then
		return
	end
	self.Window = window
	self.Maid:Give(window.OpenChanged:Connect(function(open)
		if open then
			self:Collapse()
		end
		self:SetVisible(not open)
	end))
	self:SetVisible(not window.Open)
end

function DynamicIsland:_openWindow()
	local window = self.Window
	if window and not window.Destroyed then
		window:Toggle(true)
	end
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
		if self:_wasDragged() then
			return
		end
		if self.Window then
			self:_openWindow()
		elseif ctx.Touch and not self.Pinned then
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
end

__defs["Components/KeyStatus"] = function(require)
-- KeyStatus: shows how much time is left on the key validated by ui:KeySystem().
--   section:AddKeyStatus({ Name = "Key", Desc = "Time left on your key" })
-- States: "No key" (muted), "Lifetime" (no expiry), "2d 3h" (accent), under one hour (warning), "Expired" (error).
-- Perf: the library runs ONE 1-second tick, and only while a KeyStatus exists AND the key can expire.
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local KeyStatus = Element.extend("KeyStatus")
KeyStatus.Persistent = false -- display only: never written to configs

function KeyStatus.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Key", Desc = "Time left on your key" })
	local self = setmetatable({}, KeyStatus)
	Element.init(self, ctx, options)

	local card = Kit.Card(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Order = order,
		RightWidth = 130,
	})
	self.Frame = card.Frame

	local chip = Kit.Frame(ctx, {
		Name = "Chip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 0, 0, ctx.Metrics.Chip),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = card.Frame,
	}, "Surface")
	Kit.Corner(chip, 6)
	Kit.Padding(chip, 10, 10, 0, 0)
	self.Label = Kit.Text(ctx, {
		Name = "TimeLeft",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = chip,
	}, "Muted", "Medium")
	-- the binding reads the current state, so a theme change keeps the right color
	ctx.Theme:Bind(self.Label, "TextColor3", function(theme)
		return theme:Get(self.Token or "Muted")
	end)

	local library = ctx.Library
	self.Maid:Give(library.KeyChanged:Connect(function()
		self:_refresh()
	end))
	self.Maid:Give(library.KeyTick:Connect(function()
		self:_refresh()
	end))
	library:_AcquireKeyTick()
	self.Maid:Give(function()
		library:_ReleaseKeyTick()
	end)

	self:_init(self:_compute())
	return self
end

-- Returns the text to display and updates self.Token (the theme color token).
function KeyStatus:_compute()
	local library = self.Ctx.Library
	local key = library.Key
	if not key then
		self.Token = "Muted"
		return "No key"
	end
	if key.Expired then
		self.Token = "Error"
		return "Expired"
	end
	if not key.ExpiresAt then
		self.Token = "Success"
		return "Lifetime"
	end
	local left = library:GetKeyTimeLeft()
	self.Token = left < 3600 and "Warning" or "Accent"
	return Util.FormatDuration(left)
end

function KeyStatus:_refresh()
	if self.Destroyed then
		return
	end
	self:Set(self:_compute(), true)
end

function KeyStatus:_normalize(value)
	return tostring(value)
end

function KeyStatus:_render(value)
	self.Label.Text = value
	self.Label.TextColor3 = self.Ctx.Theme:Get(self.Token or "Muted")
end

return KeyStatus
end

__defs["Components/KeySystem"] = function(require)
-- KeySystem: key entry window, to be shown BEFORE creating the main window.
--
--   local gate = ui:KeySystem({
--       Title = "My Project",
--       Note = "Get your key on our Discord.",
--       Link = "https://discord.gg/xxxx",            -- "Get key" button (copies the link)
--       Keys = { "ABC-123" },                        -- fixed list (optional)
--       Validate = function(key)                     -- optional, may yield (HttpGet...)
--           return true, { ExpiresIn = 86400 }       -- ok, info (ExpiresIn in seconds or ExpiresAt as a timestamp)
--           -- return false, "Key revoked"           -- rejection + message shown
--       end,
--       SaveKey = true,                              -- remembers the key (<ConfigFolder>/key.txt)
--       OnSuccess = function(key, info) end,
--   })
--   local ok = gate:Wait()                           -- blocks until validated (true) or closed (false)
--   if not ok then return end
--
-- IMPORTANT: this check runs on the player's machine, so it protects nothing on its own.
-- For real protection, `Validate` must query YOUR server (which decides and sets the expiry).
-- The saved key is revalidated on every launch: local expiry is never taken at face value.
local Env = require("Core/Env")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Util = require("Core/Util")

local Create = Util.Create

local KeySystem = {}
KeySystem.__index = KeySystem

local MAX_WIDTH = 360

function KeySystem.new(library, options)
	options = Util.Options(options, {
		Title = "Key system",
		Note = "Enter your key to continue.",
		Placeholder = "Enter your key...",
		CheckText = "Check key",
		LinkText = "Get key",
		SaveKey = true,
		Cooldown = 1.5, -- seconds of lockout after a rejected key
	}, "Title")
	if type(options.Keys) ~= "table" and type(options.Validate) ~= "function" then
		error("[MaUI] KeySystem: provide `Keys` (list) and/or `Validate` (function)", 3)
	end

	local self = setmetatable({}, KeySystem)
	self.Library = library
	self.Options = options
	self.Maid = Maid.new()
	self.Passed = Signal.new() -- (key, info)
	self.Closed = Signal.new()
	self.Maid:Give(self.Passed)
	self.Maid:Give(self.Closed)
	self.Done = false
	self.Success = false
	self.Info = nil
	self.Destroyed = false
	self.Busy = false
	self.Locked = false
	self.KeyFile = options.KeyFile or (library.ConfigFolder .. "/key.txt")
	self._waiters = {}
	self._statusToken = "Muted"

	local saved = options.SaveKey and self:_readSaved() or nil
	if saved then
		-- saved key: revalidate it without showing the window (it only appears on failure)
		self.Busy = true
		task.spawn(function()
			local ok, info = self:_validate(saved)
			self.Busy = false
			if self.Done or self.Destroyed then
				return
			end
			if ok then
				self:_finish(true, saved, info)
			else
				Env.DeleteFile(self.KeyFile)
				self:_buildUI()
			end
		end)
	else
		self:_buildUI()
	end
	return self
end

-- Saved key ---------------------------------------------------------------------

function KeySystem:_readSaved()
	if not Env.HasFS() or not Env.IsFile(self.KeyFile) then
		return nil
	end
	local ok, content = Env.ReadFile(self.KeyFile)
	if not ok then
		return nil
	end
	local key = Util.Trim(content)
	if key == "" then
		return nil
	end
	return key
end

-- Validation -------------------------------------------------------------------------

-- Returns ok, info|message
function KeySystem:_validate(key)
	local options = self.Options
	if type(options.Keys) == "table" then
		for _, valid in ipairs(options.Keys) do
			if valid == key then
				return true, nil
			end
		end
	end
	if type(options.Validate) == "function" then
		local called, ok, info = pcall(options.Validate, key)
		if not called then
			warn("[MaUI] error in Validate: " .. tostring(ok))
			return false, "Could not check the key. Try again."
		end
		if ok then
			return true, info
		end
		return false, type(info) == "string" and info or "Invalid key."
	end
	return false, "Invalid key."
end

function KeySystem:_finish(success, key, info)
	if self.Done then
		return
	end
	self.Done = true
	self.Success = success
	self.Info = info
	if success then
		local expiresAt = nil
		if type(info) == "table" then
			if type(info.ExpiresAt) == "number" then
				expiresAt = info.ExpiresAt
			elseif type(info.ExpiresIn) == "number" then
				expiresAt = self.Library.Clock() + info.ExpiresIn
			end
		end
		self.Library:_SetKey(key, expiresAt, info)
		if self.Options.SaveKey and Env.HasFS() then
			Env.EnsureFolder(self.Library.ConfigFolder)
			Env.WriteFile(self.KeyFile, key)
		end
	end
	self:_closeUI()
	if success then
		self.Passed:Fire(key, info)
		Util.Call(self.Options.OnSuccess, key, info)
	else
		self.Closed:Fire()
		Util.Call(self.Options.OnClose)
	end
	local waiters = self._waiters
	self._waiters = {}
	for _, thread in ipairs(waiters) do
		task.spawn(thread, success, info)
	end
end

-- Blocks the current thread until done. Returns success, info.
function KeySystem:Wait()
	if self.Done then
		return self.Success, self.Info
	end
	local thread, isMain = coroutine.running()
	if thread == nil or isMain == true then
		-- main thread (cannot yield): wait by polling
		while not self.Done do
			task.wait(0.1)
		end
		return self.Success, self.Info
	end
	self._waiters[#self._waiters + 1] = thread
	return coroutine.yield()
end

-- Interface ---------------------------------------------------------------------------

function KeySystem:_setStatus(text, token)
	self._statusToken = token
	if self.Status then
		self.Status.Text = text
		self.Status.TextColor3 = self.Library.Theme:Get(token)
	end
end

function KeySystem:_copyLink()
	local link = tostring(self.Options.Link)
	if Env.SetClipboard(link) then
		self:_setStatus("Link copied to clipboard.", "Success")
	else
		-- clipboard unavailable: show the link instead
		self:_setStatus(link, "Accent")
	end
end

function KeySystem:_submit()
	if self.Done or self.Destroyed or self.Busy or self.Locked or not self.Input then
		return
	end
	local key = Util.Trim(self.Input.Text)
	if key == "" then
		self:_setStatus("Enter a key first.", "Warning")
		return
	end
	self.Busy = true
	self:_setStatus("Checking key...", "Muted")
	task.spawn(function()
		local ok, info = self:_validate(key)
		self.Busy = false
		if self.Done or self.Destroyed then
			return
		end
		if ok then
			local message = type(info) == "table" and type(info.Message) == "string" and info.Message or "Key accepted."
			self:_setStatus(message, "Success")
			self:_finish(true, key, info)
		else
			self:_setStatus(tostring(info), "Error")
			self.Locked = true
			task.delay(self.Options.Cooldown, function()
				self.Locked = false
			end)
		end
	end)
end

function KeySystem:_buildUI()
	if self.Destroyed or self.Done or self.Gui then
		return
	end
	local library = self.Library
	local ctx = library.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local options = self.Options

	local gui = Create("ScreenGui", {
		Name = "KeySystem",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1001,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = Env.GetParent(library.Options.Parent)
	self.Gui = gui

	-- dimmed backdrop: also blocks clicks from reaching the game
	Create("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		Parent = gui,
	})

	local card = Kit.Frame(ctx, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = gui,
	}, "Background")
	Create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, math.huge), Parent = card })
	Kit.Corner(card, 10)
	Kit.Stroke(ctx, card, "Stroke")
	Kit.Padding(card, 18, 18, 16, 18)
	Kit.List(card, 10)

	-- title + close
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
		Parent = card,
	})
	Kit.Text(ctx, {
		Name = "Title",
		Text = tostring(options.Title),
		TextSize = 17,
		Size = UDim2.new(1, -34, 1, 0),
		Parent = header,
	}, "Text", "Bold")
	local close = Create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "×",
		TextSize = 22,
		FontFace = ctx.Fonts.Medium,
		Parent = header,
	})
	theme:Bind(close, "TextColor3", "Muted")
	self.Maid:Give(close.MouseButton1Click:Connect(function()
		self:_finish(false)
	end))

	if options.Note and options.Note ~= "" then
		Kit.Text(ctx, {
			Name = "Note",
			Text = tostring(options.Note),
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = card,
		}, "Muted", "Regular")
	end

	-- input field
	local inputFrame = Kit.Frame(ctx, {
		Name = "InputFrame",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		Parent = card,
	}, "Surface")
	Kit.Corner(inputFrame, 8)
	local inputStroke = Kit.Stroke(ctx, inputFrame, "Stroke")
	local input = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = tostring(options.Placeholder),
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		TextSize = 14,
		FontFace = ctx.Fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = inputFrame,
	})
	theme:Bind(input, "TextColor3", "Text")
	theme:Bind(input, "PlaceholderColor3", "Muted")
	self.Input = input
	self.Maid:Give(input.Focused:Connect(function()
		tween:To(inputStroke, { Color = theme:Get("Accent") }, 0.12)
	end))
	self.Maid:Give(input.FocusLost:Connect(function(enterPressed)
		tween:To(inputStroke, { Color = theme:Get("Stroke") }, 0.15)
		if enterPressed then
			self:_submit()
		end
	end))

	-- status message
	self.Status = Kit.Text(ctx, {
		Name = "Status",
		Text = "",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 4,
		Parent = card,
	}, "Muted", "Regular")
	theme:Bind(self.Status, "TextColor3", function(t)
		return t:Get(self._statusToken)
	end)

	-- buttons
	local row = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 5,
		Parent = card,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = row,
	})
	local function makeButton(name, text, primary, order, onClick)
		local button = Create("TextButton", {
			Name = name,
			Size = UDim2.new(0, 0, 0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = text,
			TextSize = 14,
			FontFace = ctx.Fonts.Medium,
			LayoutOrder = order,
			Parent = row,
		})
		theme:Bind(button, "BackgroundColor3", primary and "Accent" or "Surface2")
		theme:Bind(button, "TextColor3", primary and "AccentText" or "Text")
		Kit.Corner(button, 8)
		Kit.Padding(button, 18, 18, 0, 0)
		if not primary then
			Kit.Stroke(ctx, button, "Stroke")
		end
		self.Maid:Give(button.MouseButton1Click:Connect(onClick))
		return button
	end
	if options.Link then
		makeButton("GetKey", tostring(options.LinkText), false, 1, function()
			self:_copyLink()
		end)
	end
	self.CheckButton = makeButton("Check", tostring(options.CheckText), true, 2, function()
		self:_submit()
	end)
end

function KeySystem:_closeUI()
	local gui = self.Gui
	if gui then
		self.Gui = nil
		self.Input = nil
		self.Status = nil
		self.Library.Theme:Release(gui)
		gui:Destroy()
	end
end

function KeySystem:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	if not self.Done then
		self:_finish(false)
	end
	self:_closeUI()
	self.Maid:Clean()
end

return KeySystem
end

__defs["Components/Keybind"] = function(require)
-- Keybind: key assignable by the user.
--   AddKeybind({ Name = "Fly", Default = Enum.KeyCode.F, Flag = "fly_key",
--                Callback = function(key) end,     -- when the key is PRESSED
--                OnChanged = function(key) end })  -- when the key is reassigned
--   keybind:Set(Enum.KeyCode.G)  /  keybind:Set(false) to clear the key
-- Click the keycap, then press a key to reassign. Escape cancels, Backspace/Delete clears.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Keybind = Element.extend("Keybind")

local CAPTURE_TEXT = "Press a key..."
local CAP_WIDTH = 104

function Keybind.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Keybind" })
	local self = setmetatable({}, Keybind)
	Element.init(self, ctx, options)

	self.Listening = false
	self.Disabled = options.Disabled == true
	self.Pressed = Signal.new()
	self.Maid:Give(self.Pressed)

	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		RightWidth = CAP_WIDTH + Tokens.Space.Sm,
	})
	self.Frame = self.Row.Frame

	-- keycap-style button on the right (same look as Kit.Keycaps)
	local capHeight = ctx.Touch and ctx.Metrics.Compact or 24
	self.Chip = Create("TextButton", {
		Name = "Chip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(CAP_WIDTH, capHeight),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Parent = self.Frame,
	})
	ctx.Theme:Bind(self.Chip, "BackgroundColor3", function(t)
		return t:Get(self.Listening and "AccentSoft" or "Surface3")
	end)
	Kit.Corner(self.Chip, Tokens.Radius.Sm - 2)
	self.ChipStroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = self.Chip,
	})
	ctx.Theme:Bind(self.ChipStroke, "Color", function(t)
		return self:_strokeColor(t)
	end)
	self.ChipLabel = Kit.Text(ctx, {
		Name = "Key",
		Size = UDim2.fromScale(1, 1),
		TextSize = Tokens.Type.Supporting.Size,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = self.Chip,
	}, function(t)
		return self:_textColor(t)
	end, "Bold")

	CK.Track(ctx, self.Maid, self.Chip, self, function()
		self:_renderChip()
	end)
	self.Maid:Give(self.Chip.MouseButton1Click:Connect(function()
		if not self.Disabled then
			self:_toggleListening()
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Chip, options.Tooltip)

	-- a single bind in the central registry; SetKey moves it on reassignment
	self.Bind = ctx.Input:BindKey(nil, function()
		self.Pressed:Fire(self.Value or nil)
		Util.Call(options.Callback, self.Value or nil)
	end)
	self.Maid:Give(self.Bind)
	self.Maid:Give(function()
		if self.Listening then
			ctx.Input:CancelKeyCapture()
		end
	end)

	self:_init(options.Default)
	return self
end

-- false = no key
function Keybind:_normalize(value)
	if value == nil or value == false then
		return false
	end
	local key = Util.ParseKey(value)
	if key == nil then
		return nil
	end
	return key
end

function Keybind:_render(value)
	self.Bind:SetKey(value or nil)
	self:_renderChip()
end

function Keybind:_strokeColor(theme)
	if self.Listening then
		return theme:Get("Accent")
	end
	return theme:Get((self._hover and not self.Disabled) and "StrokeHover" or "Stroke")
end

function Keybind:_textColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	if self.Listening then
		return theme:Get("Accent")
	end
	return theme:Get(self.Value and "Text" or "Muted")
end

function Keybind:_renderChip()
	if self.Destroyed then
		return
	end
	self.ChipLabel.Text = self.Listening and CAPTURE_TEXT or Util.KeyName(self.Value or nil)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local pressed = self._pressed and not self.Disabled
	tween:To(self.ChipStroke, { Color = self:_strokeColor(theme) }, Tokens.Motion.Fast)
	tween:To(self.ChipLabel, { TextColor3 = self:_textColor(theme) }, Tokens.Motion.Fast)
	tween:To(self.Chip, {
		BackgroundColor3 = theme:Get(self.Listening and "AccentSoft" or "Surface3"),
		BackgroundTransparency = self.Disabled and 0.5 or (pressed and 0.3 or 0),
	}, Tokens.Motion.Fast)
	CK.Dim(ctx, self.Row, self.Disabled, Tokens.Motion.Fast)
end

function Keybind:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		if self.Listening then
			self.Ctx.Input:CancelKeyCapture()
		end
	end
	self:_renderChip()
end

function Keybind:_toggleListening()
	local input = self.Ctx.Input
	if self.Listening then
		input:CancelKeyCapture()
		return
	end
	self.Listening = true
	self:_renderChip()
	input:CaptureKey(function(keyCode)
		self.Listening = false
		if self.Destroyed then
			return
		end
		if keyCode == nil or keyCode == Enum.KeyCode.Escape then
			self:_renderChip()
		elseif keyCode == Enum.KeyCode.Backspace or keyCode == Enum.KeyCode.Delete then
			self:Set(false)
			self:_renderChip()
		else
			self:Set(keyCode)
			self:_renderChip()
		end
	end)
end

-- Callback = key pressed; OnChanged = key reassigned
function Keybind:_callback(value)
	Util.Call(self.Options.OnChanged, value or nil)
end

function Keybind:Get()
	return self.Value or nil
end

function Keybind:Serialize()
	return self.Value and self.Value.Name or false
end

return Keybind
end

__defs["Components/Keycap"] = function(require)
-- Keycap: display-only row showing a shortcut as keyboard keys.
--   AddKeycap({ Name = "Toggle UI", Keys = { "Ctrl", "R" } })  /  keycap:SetKeys({ "Shift", "F" })
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Keycap = Element.extend("Keycap")
Keycap.Persistent = false

function Keycap.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Shortcut", Keys = {} })
	local self = setmetatable({}, Keycap)
	Element.init(self, ctx, options)
	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon, Order = order, RightWidth = 120 })
	self.Frame = self.Row.Frame
	self.Holder = Util.Create("Frame", {
		Name = "Keys", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X, Parent = self.Frame,
	})
	self:_init(options.Keys)
	return self
end

function Keycap:_normalize(keys)
	if type(keys) == "string" then
		local list = {}
		for part in keys:gmatch("[^+]+") do
			list[#list + 1] = Util.Trim(part)
		end
		return list
	end
	return type(keys) == "table" and keys or nil
end

function Keycap:_equals()
	return false
end

function Keycap:_render(keys)
	for _, child in ipairs(self.Holder:GetChildren()) do
		self.Ctx.Theme:Release(child)
		child:Destroy()
	end
	Kit.Keycaps(self.Ctx, self.Holder, keys, {}).Name = "Caps"
end

function Keycap:SetKeys(keys)
	self:Set(keys, true)
end

return Keycap
end

__defs["Components/Label"] = function(require)
-- Label: plain text (automatic multi-line), optional icon.
--   AddLabel("Text")  or  AddLabel({ Text = "...", Color = "Accent", Icon = "info", Muted = true })
--   label:Set("new text")  /  label:SetText("new text")
-- Muted (default true) uses the Muted text color; Muted = false uses the primary Text color.
-- An explicit Color token always wins.
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Create = Util.Create

local Label = Element.extend("Label")
Label.Persistent = false -- display only

function Label.new(ctx, options, parent, order)
	options = Util.Options(options, { Text = "", Muted = true }, "Text")
	local self = setmetatable({}, Label)
	Element.init(self, ctx, options)

	local color = options.Color or (options.Muted == false and "Text" or "Muted")
	self.Frame = Create("Frame", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Padding(self.Frame, 0, 0, 3, 3)
	local left = 0
	if options.Icon then
		self.IconInstance = Icons.Create(ctx, {
			Icon = options.Icon,
			Size = 16,
			Color = color,
			Position = UDim2.fromOffset(0, 0),
			Parent = self.Frame,
		})
		if self.IconInstance then
			left = 22
		end
	end
	self.Label = Kit.Text(ctx, {
		Name = "Text",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.Frame,
	}, color, "Regular")

	self:_init(options.Text)
	return self
end

function Label:_normalize(value)
	return tostring(value)
end

function Label:_render(value)
	self.Label.Text = value
end

function Label:SetText(text)
	self:Set(text, true)
end

return Label
end

__defs["Components/Metric"] = function(require)
-- Metric: compact stat block: icon + overline label, large value, secondary text, mini visualization.
--   AddMetric({ Name = "FPS", Icon = "bolt", Value = 60, Secondary = "avg 58", Trend = "up",
--               Status = "success", Viz = "Bars", Samples = { 55, 58, 60 }, Max = 120,
--               Format = function(value) return string.format("%d fps", value) end })
--   metric:Set(61)  :Push(62)  :SetSecondary("avg 59")  :SetTrend(-3)  :SetStatus("warning")  :Clear()
-- Trend: "up" | "down" | a number delta (arrow glyph + text, never color alone).
-- Status: success | warning | error | info | muted (or a raw theme token name), colors the value.
-- Viz: "Bars" | "Segments" | "Progress" | "Graph" | nil.
--   Bars / Graph : a FIXED pool of 24 bar frames used as a ring. Push(value) shifts the heights, it never
--                  creates or destroys an instance. The newest bar uses the status/Accent color.
--   Progress     : track + fill (value / Max).
--   Segments     : 10 discrete segments lit proportionally to value / Max.
-- Max defaults to 100 for Progress/Segments; Bars/Graph auto-scale when Max is omitted.
-- Never saved in configs (Persistent = false).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Metric = Element.extend("Metric")
Metric.Persistent = false

local POOL = 24
local SEGMENTS = 10
local VIZ_HEIGHT = 30
local VIZS = { Bars = true, Segments = true, Progress = true, Graph = true }
local STATUS_TOKENS = { success = "Success", warning = "Warning", error = "Error", info = "Info", muted = "Muted" }

function Metric.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Metric" })
	local self = setmetatable({}, Metric)
	Element.init(self, ctx, options)

	if options.Viz ~= nil and not VIZS[options.Viz] then
		warn("[MaUI] Metric '" .. tostring(options.Name) .. "': unknown Viz '" .. tostring(options.Viz) .. "'")
		options.Viz = nil
	end
	self.Viz = options.Viz
	self.MaxValue = tonumber(options.Max)
	self.Samples = {}
	self.SampleCount = 0
	self._head = 0
	self.Status = nil
	self.Trend = nil

	self.Frame = Create("Frame", {
		Name = options.Name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.Padding(self.Frame, 0, 0, Tokens.Space.Sm, Tokens.Space.Sm)
	Kit.List(self.Frame, Tokens.Space.Xs)

	-- header: icon + overline label on the left, trend on the right
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = self.Frame,
	})
	local left = 0
	self.Icon = options.Icon and Icons.Create(ctx, {
		Icon = options.Icon,
		Size = 14,
		Color = "Muted",
		Position = UDim2.fromOffset(0, 1),
		Parent = header,
	})
	if self.Icon then
		left = 20
	end
	self.Title = Kit.Text(ctx, {
		Name = "Title",
		Text = string.upper(tostring(options.Name)),
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + 70), 1, 0),
		TextSize = Tokens.Type.Caption.Size,
	}, "Muted", "Bold")
	self.Title.Parent = header
	self.TrendLabel = Kit.Text(ctx, {
		Name = "Trend",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(66, 16),
		TextSize = Tokens.Type.Supporting.Size,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = header,
	}, function(t)
		return self:_trendColor(t)
	end, "Bold")

	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value",
		Size = UDim2.new(1, 0, 0, Tokens.Type.Display.Size + 6),
		TextSize = Tokens.Type.Display.Size,
		LayoutOrder = 2,
		Parent = self.Frame,
	}, function(t)
		return self:_valueColor(t)
	end, "Bold")

	self.SecondaryLabel = Kit.Text(ctx, {
		Name = "Secondary",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = Tokens.Type.Supporting.Size,
		Visible = false,
		LayoutOrder = 3,
		Parent = self.Frame,
	}, "Muted", "Regular")

	if self.Viz then
		self:_buildViz()
	end
	self:SetStatus(options.Status)
	self:SetSecondary(options.Secondary)
	self:SetTrend(options.Trend)

	self:_init(options.Value)
	if type(options.Samples) == "table" and (self.Viz == "Bars" or self.Viz == "Graph") then
		for _, sample in ipairs(options.Samples) do
			self:_pushSample(sample)
		end
		self:_paintBars()
	end
	return self
end

-- Colors ---------------------------------------------------------------------------------------

function Metric:_statusToken()
	local status = self.Status
	if not status then
		return nil
	end
	return STATUS_TOKENS[status] or status
end

function Metric:_valueColor(theme)
	local token = self:_statusToken()
	if token and theme:Get(token) then
		return theme:Get(token)
	end
	return theme:Get("Text")
end

function Metric:_vizColor(theme)
	local token = self:_statusToken()
	if token and token ~= "Muted" and theme:Get(token) then
		return theme:Get(token)
	end
	return theme:Get("Accent")
end

function Metric:_trendColor(theme)
	local trend = self.Trend
	if trend == "up" or (type(trend) == "number" and trend > 0) then
		return theme:Get("Success")
	elseif trend == "down" or (type(trend) == "number" and trend < 0) then
		return theme:Get("Error")
	end
	return theme:Get("Muted")
end

-- Visualization --------------------------------------------------------------------------------

function Metric:_buildViz()
	local ctx = self.Ctx
	self.VizFrame = Create("Frame", {
		Name = "Viz",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, self.Viz == "Progress" and 6 or VIZ_HEIGHT),
		LayoutOrder = 4,
		Parent = self.Frame,
	})
	if self.Viz == "Progress" then
		local track = Kit.Frame(ctx, {
			Name = "Track",
			Size = UDim2.new(1, 0, 0, 6),
			Parent = self.VizFrame,
		}, "Surface3")
		Kit.Corner(track, Tokens.Radius.Pill)
		self.Fill = Create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			Parent = track,
		})
		ctx.Theme:Bind(self.Fill, "BackgroundColor3", function(t)
			return self:_vizColor(t)
		end)
		Kit.Corner(self.Fill, Tokens.Radius.Pill)
	elseif self.Viz == "Segments" then
		self.Segs = {}
		local width = 1 / SEGMENTS
		for i = 1, SEGMENTS do
			local seg = Create("Frame", {
				Name = "Segment",
				Position = UDim2.new((i - 1) * width, 1, 0, 0),
				Size = UDim2.new(width, -2, 0, 8),
				BorderSizePixel = 0,
				Parent = self.VizFrame,
			})
			ctx.Theme:Bind(seg, "BackgroundColor3", function(t)
				return (self._lit or 0) >= i and self:_vizColor(t) or t:Get("Surface3")
			end)
			Kit.Corner(seg, 2)
			self.Segs[i] = seg
		end
	else
		-- Bars / Graph: fixed pool of POOL frames, never created or destroyed again
		self.Bars = {}
		local ratio = self.Viz == "Graph" and 0.45 or 0.8
		local slot = 1 / POOL
		for i = 1, POOL do
			local bar = Create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new((i - 1) * slot + slot * (1 - ratio) / 2, 0, 1, 0),
				Size = UDim2.new(slot * ratio, 0, 0.06, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0.6,
				Parent = self.VizFrame,
			})
			ctx.Theme:Bind(bar, "BackgroundColor3", function(t)
				if i == POOL and self.SampleCount > 0 then
					return self:_vizColor(t)
				end
				return t:Get(self.Viz == "Graph" and "Faint" or "Surface3")
			end)
			Kit.Corner(bar, 2)
			self.Bars[i] = bar
		end
	end
end

-- Writes a sample in the ring (no instance work).
function Metric:_pushSample(value)
	value = tonumber(value)
	if not value or value ~= value then
		return false
	end
	self._head = self._head % POOL + 1
	self.Samples[self._head] = value
	self.SampleCount = math.min(self.SampleCount + 1, POOL)
	return true
end

-- Repaints the pooled bars from the ring: position i shows the sample (POOL - i) steps old.
function Metric:_paintBars()
	local bars = self.Bars
	if not bars then
		return
	end
	local ceiling = self.MaxValue
	if not ceiling then
		ceiling = 0
		for _, sample in pairs(self.Samples) do
			ceiling = math.max(ceiling, sample)
		end
	end
	if ceiling <= 0 then
		ceiling = 1
	end
	local theme = self.Ctx.Theme
	for i = 1, POOL do
		local age = POOL - i
		local bar = bars[i]
		if age < self.SampleCount then
			local index = (self._head - 1 - age) % POOL + 1
			local fraction = Util.Clamp(self.Samples[index] / ceiling, 0.06, 1)
			bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, fraction, 0)
			bar.BackgroundTransparency = 0
		else
			bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, 0.06, 0)
			bar.BackgroundTransparency = 0.6
		end
		bar.BackgroundColor3 = (i == POOL and self.SampleCount > 0) and self:_vizColor(theme)
			or theme:Get(self.Viz == "Graph" and "Faint" or "Surface3")
	end
end

function Metric:_repaintViz(animate)
	local numeric = tonumber(self.Value)
	if self.Viz == "Progress" and self.Fill then
		local alpha = numeric and Util.Clamp(numeric / (self.MaxValue or 100), 0, 1) or 0
		self.Ctx.Tween:To(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, animate and Tokens.Motion.Base or 0)
	elseif self.Viz == "Segments" and self.Segs then
		local alpha = numeric and Util.Clamp(numeric / (self.MaxValue or 100), 0, 1) or 0
		self._lit = math.floor(alpha * SEGMENTS + 0.5)
		local theme = self.Ctx.Theme
		for i, seg in ipairs(self.Segs) do
			seg.BackgroundColor3 = self._lit >= i and self:_vizColor(theme) or theme:Get("Surface3")
		end
	elseif self.Bars then
		self:_paintBars()
	end
end

-- Element hooks --------------------------------------------------------------------------------

function Metric:_normalize(value)
	if value == nil then
		return nil
	end
	if type(value) == "number" and value ~= value then
		return nil
	end
	return value
end

function Metric:_format(value)
	local format = self.Options.Format
	if type(format) == "function" then
		local ok, text = pcall(format, value)
		if ok then
			return tostring(text)
		end
		warn("[MaUI] Metric Format error: " .. tostring(text))
	end
	local number = type(value) == "number" and tonumber(value) or nil
	if number then
		if number == math.floor(number) then
			return tostring(number)
		end
		return string.format("%.2f", number)
	end
	return tostring(value)
end

function Metric:_render(value, animate)
	self.ValueLabel.Text = self:_format(value)
	if self.Viz == "Progress" or self.Viz == "Segments" then
		self:_repaintViz(animate)
	end
end

-- Public API -----------------------------------------------------------------------------------

function Metric:Push(value)
	if self.Destroyed then
		return
	end
	local number = tonumber(value)
	if not number or number ~= number then
		warn("[MaUI] Metric:Push expects a number")
		return
	end
	if self.Bars then
		self:_pushSample(number)
	end
	self.Value = number
	self:_render(number, true)
	if self.Bars then
		self:_paintBars()
	end
end

function Metric:SetSecondary(text)
	if self.Destroyed then
		return
	end
	local has = text ~= nil and text ~= ""
	self.SecondaryLabel.Visible = has
	self.SecondaryLabel.Text = has and tostring(text) or ""
end

function Metric:SetTrend(trend)
	if self.Destroyed then
		return
	end
	local glyph, text
	if trend == "up" then
		glyph, text = "▲", "Up"
	elseif trend == "down" then
		glyph, text = "▼", "Down"
	elseif type(trend) == "number" and trend == trend then
		if trend > 0 then
			glyph, text = "▲", "+" .. self:_formatDelta(trend)
		elseif trend < 0 then
			glyph, text = "▼", "-" .. self:_formatDelta(-trend)
		else
			glyph, text = "▬", "0"
		end
	else
		trend = nil
	end
	self.Trend = trend
	self.TrendLabel.Visible = trend ~= nil
	self.TrendLabel.Text = trend ~= nil and (glyph .. " " .. text) or ""
	self.TrendLabel.TextColor3 = self:_trendColor(self.Ctx.Theme)
end

function Metric:_formatDelta(delta)
	if delta == math.floor(delta) then
		return tostring(delta)
	end
	return string.format("%.1f", delta)
end

function Metric:SetStatus(status)
	if self.Destroyed then
		return
	end
	if status ~= nil and not STATUS_TOKENS[status] and self.Ctx.Theme:Get(status) == nil then
		warn("[MaUI] Metric: unknown Status '" .. tostring(status) .. "'")
		status = nil
	end
	self.Status = status
	self.ValueLabel.TextColor3 = self:_valueColor(self.Ctx.Theme)
	if self.Viz then
		self:_repaintViz(false)
	end
end

function Metric:Clear()
	if self.Destroyed then
		return
	end
	self.Samples = {}
	self.SampleCount = 0
	self._head = 0
	self.Value = nil
	self.ValueLabel.Text = "–"
	if self.Viz == "Progress" or self.Viz == "Segments" then
		self:_repaintViz(false)
	else
		self:_paintBars()
	end
end

function Metric:Serialize()
	return nil
end

function Metric:Deserialize() end

return Metric
end

__defs["Components/Notifications"] = function(require)
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
end

__defs["Components/Overlay"] = function(require)
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
	if instance:IsA("GuiButton") then
		handle.Maid:Give(instance.MouseButton1Down:Connect(function()
			self:_hide()
		end))
	end
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
end

__defs["Components/OverlayWindow"] = function(require)
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
	local icon = Kit.IconOf(button)
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
			self._tips = self._tips or {}
			self._tips[button] = ctx.Tooltip:Attach(button, { Text = tip })
			self.Maid:Give(self._tips[button])
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
	local compactTip = self._tips and self._tips[self.CompactButton]
	if compactTip and compactTip.SetOptions then
		compactTip:SetOptions({ Text = compact and "Normal mode" or "Compact mode" })
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
	local minimizeTip = self._tips and self._tips[self.MinimizeButton]
	if minimizeTip and minimizeTip.SetOptions then
		minimizeTip:SetOptions({ Text = minimized and "Restore" or "Minimize" })
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
end

__defs["Components/Paragraph"] = function(require)
-- Paragraph: a card with an optional title and wrapped body text (announcements, notes, descriptions).
--   section:AddParagraph({ Title = "About", Content = "Longer text that wraps across several lines." })
--   section:AddParagraph("Just a body")
--   paragraph:Set("New body") ; paragraph:SetTitle("New title")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Paragraph = Element.extend("Paragraph")
Paragraph.Persistent = false -- display only: never written to configs

function Paragraph.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "", Content = "" }, "Content")
	local self = setmetatable({}, Paragraph)
	Element.init(self, ctx, options)

	self.Frame = Kit.Frame(ctx, {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, "Surface2")
	Kit.Corner(self.Frame, 8)
	Kit.Stroke(ctx, self.Frame, "Stroke")
	Kit.Padding(self.Frame, 14, 14, 10, 12)
	Kit.List(self.Frame, 4)

	if options.Title ~= "" then
		self.TitleLabel = Kit.Text(ctx, {
			Name = "Title",
			Text = tostring(options.Title),
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = self.Frame,
		}, "Text", "Medium")
	end
	self.Body = Kit.Text(ctx, {
		Name = "Content",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = self.Frame,
	}, "Muted", "Regular")

	self:_init(options.Content)
	return self
end

function Paragraph:_normalize(value)
	return tostring(value)
end

function Paragraph:_render(value)
	self.Body.Text = value
end

function Paragraph:SetTitle(title)
	if self.TitleLabel then
		self.TitleLabel.Text = tostring(title)
	end
end

return Paragraph
end

__defs["Components/Profile"] = function(require)
-- Profile: the player's card for a Home tab (avatar, display name, @username, user ID).
--   section:AddProfile({ Greeting = "Welcome back", Badge = "Premium", ShowId = true })
--   profile:Set(player)   -- show another Player instead of the local one
-- Options: Player (default: LocalPlayer), Greeting (false/"" hides it), Badge (chip on the right),
--          ShowId (default true), ShowAvatar (default true).
-- The avatar is the same head shot the Roblox website shows; it loads in the background.
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Util = require("Core/Util")

local Create = Util.Create
local Players = game:GetService("Players")

local Profile = Element.extend("Profile")
Profile.Persistent = false -- display only: never written to configs

function Profile.new(ctx, options, parent, order)
	options = Util.Options(options, { Greeting = "Welcome back", ShowId = true, ShowAvatar = true })
	local self = setmetatable({}, Profile)
	Element.init(self, ctx, options)

	local theme = ctx.Theme
	local avatarSize = ctx.Touch and 56 or 52

	self.Frame = Kit.Frame(ctx, {
		Name = "Profile",
		Size = UDim2.new(1, 0, 0, avatarSize + 24),
		LayoutOrder = order,
		Parent = parent,
	}, "Surface2")
	Kit.Corner(self.Frame, 8)
	Kit.Stroke(ctx, self.Frame, "Stroke")

	self.Avatar = Create("ImageLabel", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(avatarSize, avatarSize),
		BorderSizePixel = 0,
		Image = "",
		Parent = self.Frame,
	})
	theme:Bind(self.Avatar, "BackgroundColor3", "Surface3")
	Kit.Corner(self.Avatar, avatarSize) -- radius >= half the size: a circle
	Kit.Stroke(ctx, self.Avatar, "Stroke")

	local textX = 14 + avatarSize + 12
	local holder = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -(textX + (options.Badge and 110 or 14)), 1, 0),
		Parent = self.Frame,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 1),
		Parent = holder,
	})
	if options.Greeting and options.Greeting ~= "" then
		Kit.Text(ctx, {
			Name = "Greeting",
			Text = tostring(options.Greeting),
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = 1,
			Parent = holder,
		}, "Muted", "Regular")
	end
	self.NameLabel = Kit.Text(ctx, {
		Name = "DisplayName",
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 2,
		Parent = holder,
	}, "Text", "Bold")
	self.Subtitle = Kit.Text(ctx, {
		Name = "Subtitle",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 3,
		Parent = holder,
	}, "Muted", "Regular")

	if options.Badge then
		local badge = Kit.Frame(ctx, {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0, 0, 0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = self.Frame,
		}, "Surface")
		Kit.Corner(badge, 6)
		Kit.Padding(badge, 10, 10, 0, 0)
		Kit.Text(ctx, {
			Name = "Text",
			Text = tostring(options.Badge),
			TextSize = 12,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.None,
			Parent = badge,
		}, "Accent", "Medium")
	end

	self:_init(options.Player or Players.LocalPlayer)
	return self
end

function Profile:_normalize(player)
	return player
end

function Profile:_render(player)
	local displayName = player and player.DisplayName or "Guest"
	local userName = player and player.Name or "guest"
	local userId = player and player.UserId or 0
	self.NameLabel.Text = displayName
	local subtitle = "@" .. userName
	if self.Options.ShowId then
		subtitle = subtitle .. "  ·  UID " .. string.format("%.0f", userId)
	end
	self.Subtitle.Text = subtitle
	self:_loadAvatar(player)
end

-- The head shot is fetched in the background; a newer request cancels an older one.
function Profile:_loadAvatar(player)
	self._loadToken = (self._loadToken or 0) + 1
	local token = self._loadToken
	self.Avatar.Image = ""
	if not player or not self.Options.ShowAvatar then
		return
	end
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and image and not self.Destroyed and token == self._loadToken then
			self.Avatar.Image = image
		end
	end)
end

return Profile
end

__defs["Components/SearchBox"] = function(require)
-- SearchBox: lightweight search field (icon, placeholder, text, focus/filled/disabled states, clear button).
--   local box = SearchBox.new(ctx, parent, { Placeholder = "Search", Width = 180, OnChanged = function(text) end })
--   box:Get() / box:Set("abc") / box:Clear() / box:SetDisabled(true) / box.Changed:Connect(fn)
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local SearchBox = {}
SearchBox.__index = SearchBox

function SearchBox.new(ctx, parent, options)
	options = Util.Options(options, { Placeholder = "Search", Width = 180 }, "Placeholder")
	local self = setmetatable({}, SearchBox)
	self.Ctx = ctx
	self.Maid = Maid.new()
	self.Changed = Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self.Focused = false
	local theme = ctx.Theme

	self.Frame = Create("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(options.Width, ctx.Metrics.Compact + 4),
		BorderSizePixel = 0,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
	})
	theme:Bind(self.Frame, "BackgroundColor3", "Surface")
	Kit.Corner(self.Frame, Tokens.Radius.Md)
	self.Stroke = Kit.Stroke(ctx, self.Frame, "Stroke")

	self.Icon = Icons.Create(ctx, {
		Icon = "search", Size = 14, Color = "Muted",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = self.Frame,
	})
	self.Box = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = "",
		PlaceholderText = options.Placeholder,
		ClearTextOnFocus = false,
		TextSize = Tokens.Type.Supporting.Size + 1,
		FontFace = ctx.Fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.Frame,
	})
	theme:Bind(self.Box, "TextColor3", "Text")
	theme:Bind(self.Box, "PlaceholderColor3", "Faint")

	self.ClearButton = Kit.IconButton(ctx, self.Maid, {
		Name = "Clear", Icon = "close", IconSize = 11, Size = 20, Tooltip = "Clear",
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Parent = self.Frame,
		Callback = function()
			self:Clear()
		end,
	})
	self.ClearButton.Visible = false

	self.Maid:Give(self.Box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = self.Box.Text
		self.ClearButton.Visible = text ~= ""
		self.Changed:Fire(text)
		Util.Call(options.OnChanged, text)
	end))
	self.Maid:Give(self.Box.Focused:Connect(function()
		self.Focused = true
		ctx.Tween:To(self.Stroke, { Color = theme:Get("Accent") }, Tokens.Motion.Fast)
		if self.Icon then
			ctx.Tween:To(self.Icon, { [Icons.ColorProperty(self.Icon)] = theme:Get("Accent") }, Tokens.Motion.Fast)
		end
	end))
	self.Maid:Give(self.Box.FocusLost:Connect(function()
		self.Focused = false
		ctx.Tween:To(self.Stroke, { Color = theme:Get("Stroke") }, Tokens.Motion.Base)
		if self.Icon then
			ctx.Tween:To(self.Icon, { [Icons.ColorProperty(self.Icon)] = theme:Get("Muted") }, Tokens.Motion.Base)
		end
	end))
	return self
end

function SearchBox:Get()
	return self.Box.Text
end

function SearchBox:Set(text)
	self.Box.Text = tostring(text or "")
end

function SearchBox:Clear()
	self.Box.Text = ""
end

function SearchBox:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Box.TextEditable = not self.Disabled
	self.Frame.BackgroundTransparency = self.Disabled and 0.5 or 0
	self.Box.TextTransparency = self.Disabled and 0.5 or 0
end

function SearchBox:SetVisible(visible)
	self.Frame.Visible = visible
end

function SearchBox:Destroy()
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
end

return SearchBox
end

__defs["Components/Section"] = function(require)
-- Section (card): the primary building block of a page. Created via tab:AddSection / tab:AddCard.
--   local card = tab:AddSection({ Name = "Dungeon", Icon = "bolt", Desc = "Auto farm", Variant = "Standard" })
--   card:AddToggle({...}) ; card:SetName("Dungeon (beta)") ; card:SetCollapsed(true)
-- Options:
--   Name, Desc, Icon           header content
--   Variant                    Standard | Compact | Large | Settings | Action | Info | Statistic | Plain
--   Collapsible (true)         header toggles the body with a chevron and a height animation
--   Collapsed (false)          initial state
--   Status                     "success" | "warning" | "error" | "info" | "accent" | "muted" -> status dot in the header
--   Actions                    { { Icon = "settings", Tooltip = "Options", Callback = fn }, ... } icon buttons in the header
--   Footer                     string shown in a muted footer line (or card:GetFooter() for a custom Frame)
--   Group                      Accordion group (string): expanding one card collapses the others of the same group
local Container = require("Components/Container")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local Section = {}
Section.__index = Section
Container.apply(Section)

-- header height, body padding, title size, radius per variant
local VARIANTS = {
	Standard = { Header = 38, Pad = Space.Lg, Title = 14, Radius = Radius.Md },
	Compact = { Header = 30, Pad = Space.Md, Title = 13, Radius = Radius.Md },
	Large = { Header = 52, Pad = Space.Xl, Title = 16, Radius = Radius.Lg },
	Settings = { Header = 46, Pad = Space.Lg, Title = 14, Radius = Radius.Md },
	Action = { Header = 38, Pad = Space.Lg, Title = 14, Radius = Radius.Md, Tinted = true },
	Info = { Header = 38, Pad = Space.Lg, Title = 14, Radius = Radius.Md, Bar = true },
	Statistic = { Header = 28, Pad = Space.Lg, Title = 11, Radius = Radius.Md, Overline = true },
	Plain = { Header = 0, Pad = Space.Sm, Title = 14, Radius = Radius.Md },
}

local STATUS_TOKENS = {
	success = "Success", warning = "Warning", error = "Error", info = "Info", accent = "Accent", muted = "Muted",
}

local groups = setmetatable({}, { __mode = "k" }) -- library -> { [group] = { cards } }

function Section.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Section", Variant = "Standard", Collapsible = true, Collapsed = false })
	local variant = VARIANTS[options.Variant]
	if not variant then
		warn("[MaUI] unknown card variant '" .. tostring(options.Variant) .. "', using Standard")
		options.Variant = "Standard"
		variant = VARIANTS.Standard
	end
	local plain = options.Variant == "Plain"
	if plain or options.Variant == "Statistic" then
		options.Collapsible = false
	end
	local theme = ctx.Theme
	local self = setmetatable({}, Section)
	self.Ctx = ctx
	self.Options = options
	self.Maid = Maid.new()
	self.Elements = {}
	self._order = 0
	self.Collapsed = false
	self.CollapsedChanged = Signal.new()
	self.Maid:Give(self.CollapsedChanged)

	self.Frame = Kit.Frame(ctx, {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, plain and "Background" or "Surface")
	if plain then
		self.Frame.BackgroundTransparency = 1
	else
		Kit.Corner(self.Frame, variant.Radius)
		Kit.Stroke(ctx, self.Frame, "Stroke")
	end
	Kit.List(self.Frame, 0)

	-- header ---------------------------------------------------------------------------------
	if not plain then
		local header = Create(options.Collapsible and "TextButton" or "Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, variant.Header),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
			Parent = self.Frame,
		})
		if options.Collapsible then
			header.AutoButtonColor = false
			header.Text = ""
		end
		theme:Bind(header, "BackgroundColor3", variant.Tinted and "AccentSoft" or "Surface2")
		header.BackgroundTransparency = variant.Tinted and 0 or 0.35
		Kit.Corner(header, variant.Radius)
		self.Header = header
		-- squares the lower corners so the header sits flush on the body
		local flush = Create("Frame", {
			Name = "Flush", BackgroundTransparency = header.BackgroundTransparency, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, variant.Radius),
			Parent = header,
		})
		theme:Bind(flush, "BackgroundColor3", variant.Tinted and "AccentSoft" or "Surface2")

		local left, right = variant.Pad, variant.Pad
		if options.Variant == "Info" then
			local bar = Kit.Frame(ctx, { Name = "Bar", Size = UDim2.new(0, 3, 1, 0), ZIndex = 2, Parent = self.Frame }, "Info")
			bar.Position = UDim2.fromOffset(0, 0)
			bar.Size = UDim2.new(0, 3, 0, variant.Header)
		end
		local icon = Icons.Create(ctx, {
			Icon = options.Icon, Size = options.Variant == "Large" and 20 or 16,
			Color = options.Variant == "Info" and "Info" or "Accent",
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, left, 0.5, 0), Parent = header,
		})
		self.IconInstance = icon
		if icon then
			left = left + (options.Variant == "Large" and 30 or 26)
		end

		-- right side: chevron, actions, status (built right-to-left)
		if options.Collapsible then
			self.Chevron = Icons.Create(ctx, {
				Icon = "chevron", Name = "Chevron", Size = 14, Color = "Muted",
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right, 0.5, 0), Parent = header,
			})
			right = right + 22
		end
		for index = #(options.Actions or {}), 1, -1 do
			local action = options.Actions[index]
			local button = Kit.IconButton(ctx, self.Maid, {
				Name = "Action", Icon = action.Icon or "settings", Tooltip = action.Tooltip, Callback = action.Callback,
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right, 0.5, 0), Size = 26, Parent = header,
			})
			button.ZIndex = 3
			right = right + 30
		end
		if options.Status then
			self.StatusDot = Create("Frame", {
				Name = "Status", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right, 0.5, 0),
				Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Parent = header,
			})
			Kit.Corner(self.StatusDot, 8)
			self:SetStatus(options.Status)
			right = right + 16
		end

		local textHolder = Create("Frame", {
			Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(left, 0),
			Size = UDim2.new(1, -(left + right + Space.Sm), 1, 0), Parent = header,
		})
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = textHolder })
		local overline = variant.Overline
		self.Title = Kit.Text(ctx, {
			Name = "Title",
			Text = overline and string.upper(options.Name) or options.Name,
			TextSize = variant.Title,
			Size = UDim2.new(1, 0, 0, variant.Title + 4),
			LayoutOrder = 1,
			Parent = textHolder,
		}, overline and "Muted" or "Text", overline and "Bold" or (options.Variant == "Large" and "Bold" or "Medium"))
		if options.Desc then
			self.DescLabel = Kit.Text(ctx, {
				Name = "Desc", Text = options.Desc, TextSize = Tokens.Type.Supporting.Size,
				Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = textHolder,
			}, "Muted", "Regular")
		end

		if options.Collapsible then
			self.Maid:Give(header.MouseButton1Click:Connect(function()
				self:SetCollapsed(not self.Collapsed)
			end))
			if not ctx.Touch then
				self.Maid:Give(header.MouseEnter:Connect(function()
					ctx.Tween:To(header, { BackgroundTransparency = variant.Tinted and 0.15 or 0 }, Motion.Fast)
				end))
				self.Maid:Give(header.MouseLeave:Connect(function()
					ctx.Tween:To(header, { BackgroundTransparency = variant.Tinted and 0 or 0.35 }, Motion.Base)
				end))
			end
		end
	end

	-- body: clipped wrapper (animated height) around the content list ----------------------
	self.Body = Create("Frame", {
		Name = "Body", BackgroundTransparency = 1, ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = self.Frame,
	})
	self.Content = Create("Frame", {
		Name = "Content", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Body,
	})
	Kit.Padding(self.Content, variant.Pad, variant.Pad, plain and 0 or Space.Md, variant.Pad)
	Kit.List(self.Content, Space.Sm)

	if options.Footer then
		self:GetFooter()
		Kit.Text(ctx, { Name = "FooterText", Text = tostring(options.Footer), TextSize = Tokens.Type.Supporting.Size, Size = UDim2.new(1, 0, 1, 0), Parent = self.FooterFrame }, "Muted", "Regular")
	end

	if options.Group then
		local library = groups[ctx.Library] or {}
		groups[ctx.Library] = library
		library[options.Group] = library[options.Group] or {}
		table.insert(library[options.Group], self)
		self.Maid:Give(function()
			local list = library[options.Group]
			for index, card in ipairs(list or {}) do
				if card == self then
					table.remove(list, index)
					break
				end
			end
		end)
	end

	if options.Collapsed and options.Collapsible then
		self:SetCollapsed(true, true)
	end
	return self
end

function Section:SetName(name)
	if self.Title then
		self.Title.Text = self.Options.Variant == "Statistic" and string.upper(tostring(name)) or tostring(name)
	end
end

function Section:SetDesc(text)
	if self.DescLabel then
		self.DescLabel.Text = tostring(text)
	end
end

function Section:SetStatus(status)
	if not self.StatusDot then
		return
	end
	local token = STATUS_TOKENS[status] or "Muted"
	self.StatusDot.BackgroundColor3 = self.Ctx.Theme:Get(token)
	self.Ctx.Theme:Bind(self.StatusDot, "BackgroundColor3", token)
end

-- Footer: a thin strip below the body; returns the Frame so you can parent your own content.
function Section:GetFooter()
	if self.FooterFrame then
		return self.FooterFrame
	end
	local ctx = self.Ctx
	local holder = Create("Frame", { Name = "Footer", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, Parent = self.Frame })
	Kit.Frame(ctx, { Name = "Line", Size = UDim2.new(1, 0, 0, 1), Parent = holder }, "Stroke")
	local inner = Create("Frame", { Name = "Inner", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 1), Size = UDim2.new(1, 0, 1, -1), Parent = holder })
	Kit.Padding(inner, Space.Lg, Space.Lg, 0, 0)
	self.FooterFrame = inner
	return inner
end

-- Collapses/expands the body. `instant` skips the animation. Accordion groups collapse siblings.
function Section:SetCollapsed(collapsed, instant)
	if self.Destroyed or not self.Options.Collapsible then
		return
	end
	collapsed = collapsed == true
	if collapsed == self.Collapsed then
		return
	end
	self.Collapsed = collapsed
	local ctx = self.Ctx
	local body = self.Body
	self._animation = (self._animation or 0) + 1
	local ticket = self._animation

	if self.Chevron then
		ctx.Tween:To(self.Chevron, { Rotation = collapsed and -90 or 0 }, instant and 0 or Motion.Base)
	end
	if collapsed then
		self._height = self.Content.AbsoluteSize.Y
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, self._height or 0)
		if instant then
			body.Size = UDim2.new(1, 0, 0, 0)
			self.Content.Visible = false
		else
			ctx.Tween:To(body, { Size = UDim2.new(1, 0, 0, 0) }, Motion.Slow)
			task.delay(Motion.Slow, function()
				if ticket == self._animation and not self.Destroyed then
					self.Content.Visible = false -- a collapsed subtree costs no rendering
				end
			end)
		end
	else
		self.Content.Visible = true
		local height = self._height or self.Content.AbsoluteSize.Y
		if instant then
			body.Size = UDim2.new(1, 0, 0, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
		else
			ctx.Tween:To(body, { Size = UDim2.new(1, 0, 0, height) }, Motion.Slow)
			task.delay(Motion.Slow, function()
				if ticket == self._animation and not self.Destroyed then
					body.Size = UDim2.new(1, 0, 0, 0)
					body.AutomaticSize = Enum.AutomaticSize.Y -- back to content-driven height
				end
			end)
		end
		local group = self.Options.Group
		if group and not instant then
			for _, other in ipairs((groups[ctx.Library] or {})[group] or {}) do
				if other ~= self then
					other:SetCollapsed(true)
				end
			end
		end
	end
	self.CollapsedChanged:Fire(collapsed)
end

function Section:Toggle()
	self:SetCollapsed(not self.Collapsed)
end

function Section:SetVisible(visible)
	self.Frame.Visible = visible
end

function Section:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
end

return Section
end

__defs["Components/SessionCard"] = function(require)
-- SessionCard: clickable user/session summary pinned at the bottom of the sidebar.
--   SessionCard.new(ctx, parent, { Name = "Player", Subtitle = "Game", UserId = 123, Avatar = "rbxassetid://..",
--                                  Status = "success", Callback = function(card) end })
-- States: default, hover, pressed, active (card:SetActive(true) while a menu is open), compact (avatar only).
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")
local Maid = require("Core/Maid")

local Create = Util.Create
local STATUS = { success = "Success", warning = "Warning", error = "Error", info = "Info", accent = "Accent", muted = "Muted" }

local SessionCard = {}
SessionCard.__index = SessionCard

function SessionCard.new(ctx, parent, options)
	options = Util.Options(options, { Name = "Player", Subtitle = "", Status = "success" })
	local self = setmetatable({}, SessionCard)
	self.Ctx = ctx
	self.Options = options
	self.Maid = Maid.new()
	self.Active = false
	self._token = 0
	local theme = ctx.Theme

	self.Frame = Create("TextButton", {
		Name = "Session", Size = UDim2.new(1, 0, 0, 48), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = parent,
	})
	theme:Bind(self.Frame, "BackgroundColor3", "Surface")
	Kit.Corner(self.Frame, Tokens.Radius.Md)
	self.Stroke = Kit.Stroke(ctx, self.Frame, "Stroke")

	self.Avatar = Create("ImageLabel", {
		Name = "Avatar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 0, BorderSizePixel = 0, Image = options.Avatar or "", Parent = self.Frame,
	})
	theme:Bind(self.Avatar, "BackgroundColor3", "Surface3")
	Kit.Corner(self.Avatar, 32)
	self.Dot = Create("Frame", {
		Name = "Status", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 1, 1, 1),
		Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, ZIndex = 2, Parent = self.Avatar,
	})
	Kit.Corner(self.Dot, 10)
	Kit.Stroke(ctx, self.Dot, "Surface", 2)

	self.Texts = Create("Frame", { Name = "Texts", BackgroundTransparency = 1, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -74, 1, 0), Parent = self.Frame })
	Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 1), Parent = self.Texts })
	self.NameLabel = Kit.Text(ctx, { Name = "Name", Text = tostring(options.Name), TextSize = 13, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1, Parent = self.Texts }, "Text", "Bold")
	self.SubLabel = Kit.Text(ctx, { Name = "Subtitle", Text = tostring(options.Subtitle), TextSize = Tokens.Type.Caption.Size, Size = UDim2.new(1, 0, 0, 13), LayoutOrder = 2, Parent = self.Texts }, "Muted", "Regular")
	self.Chevron = Icons.Create(ctx, {
		Icon = "chevronRight", Name = "Chevron", Size = 14, Color = "Muted",
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = self.Frame,
	})

	self:SetStatus(options.Status)
	if not ctx.Touch then
		self.Maid:Give(self.Frame.MouseEnter:Connect(function()
			ctx.Tween:To(self.Stroke, { Color = theme:Get("StrokeHover") }, Tokens.Motion.Fast)
			ctx.Tween:To(self.Frame, { BackgroundColor3 = theme:Get("Surface2") }, Tokens.Motion.Fast)
		end))
		self.Maid:Give(self.Frame.MouseLeave:Connect(function()
			self:_rest()
		end))
	end
	self.Maid:Give(self.Frame.MouseButton1Down:Connect(function()
		ctx.Tween:To(self.Frame, { BackgroundColor3 = theme:Get("Surface3") }, 0.08)
	end))
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		self:_rest()
		Util.Call(options.Callback, self)
	end))
	if options.Tooltip ~= false and ctx.Tooltip then
		self.Tooltip = ctx.Tooltip:Attach(self.Frame, { Text = tostring(options.Name), Desc = options.Subtitle ~= "" and options.Subtitle or nil })
		self.Maid:Give(self.Tooltip)
	end
	if options.UserId then
		self:LoadAvatar(options.UserId)
	end
	return self
end

function SessionCard:_rest()
	local theme = self.Ctx.Theme
	self.Ctx.Tween:To(self.Stroke, { Color = theme:Get(self.Active and "Accent" or "Stroke") }, Tokens.Motion.Base)
	self.Ctx.Tween:To(self.Frame, { BackgroundColor3 = theme:Get(self.Active and "AccentSoft" or "Surface") }, Tokens.Motion.Base)
end

function SessionCard:SetActive(active)
	self.Active = active == true
	self:_rest()
end

function SessionCard:SetStatus(status)
	self.Dot.Visible = status ~= nil
	if status then
		self.Ctx.Theme:Bind(self.Dot, "BackgroundColor3", STATUS[status] or "Muted")
	end
end

function SessionCard:SetInfo(name, subtitle)
	if name then
		self.NameLabel.Text = tostring(name)
	end
	if subtitle then
		self.SubLabel.Text = tostring(subtitle)
	end
end

function SessionCard:LoadAvatar(userId)
	self._token = self._token + 1
	local token = self._token
	task.spawn(function()
		local ok, image = pcall(function()
			return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and image and token == self._token and self.Frame then
			self.Avatar.Image = image
		end
	end)
end

function SessionCard:SetCompact(compact)
	self.Compact = compact == true
	self.Texts.Visible = not self.Compact
	self.Chevron.Visible = not self.Compact
	self.Avatar.Position = self.Compact and UDim2.new(0.5, -16, 0.5, 0) or UDim2.new(0, 8, 0.5, 0)
end

function SessionCard:Destroy()
	self._token = self._token + 1
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
	self.Frame = nil
end

return SessionCard
end

__defs["Components/Slider"] = function(require)
-- Slider: numeric value over a range, on a transparent row.
--   AddSlider({ Name = "Speed", Desc = "...", Icon = "bolt", Min = 0, Max = 100, Step = 1, Default = 16,
--               Suffix = " sps", Flag = "speed", Disabled = false, Tooltip = "...",
--               Callback = function(value) end })
--   slider:Set(50)  /  slider:Set(50, true) to skip the callback  /  slider:SetDisabled(true)
-- Layout: label on the left, value pill on the right, track + fill + handle in a row beneath.
-- States: default / hover / dragging / disabled. Step = 0 (or less) gives a continuous slider.
--
-- Perf: during a drag the value is set DIRECTLY (no tween) and the callback only fires when the
-- snapped value actually changes. Only a temporary listener (Input:Capture) exists while dragging.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Input = require("Core/Input")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Slider = Element.extend("Slider")

local TRACK_HEIGHT = 4
local HANDLE = 14
local HANDLE_ACTIVE = 18

function Slider.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Slider", Min = 0, Max = 100, Step = 1, Suffix = "" })
	if type(options.Min) ~= "number" or type(options.Max) ~= "number" or options.Max <= options.Min then
		error("[MaUI] Slider '" .. tostring(options.Name) .. "': Max must be greater than Min", 3)
	end
	local self = setmetatable({}, Slider)
	Element.init(self, ctx, options)

	self.Min, self.Max = options.Min, options.Max
	local step = tonumber(options.Step) or 0
	self.Continuous = step <= 0
	self.Step = self.Continuous and (self.Max - self.Min) / 1000 or step
	self.Decimals = self.Continuous and 2 or Util.Decimals(self.Step)
	self.Dragging = false
	self.Disabled = options.Disabled == true

	local top = options.Desc and (ctx.Metrics.Control + 18) or ctx.Metrics.Control
	local trackArea = ctx.Touch and 26 or 20
	local pillWidth = 56
	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		Height = top,
		RightWidth = pillWidth,
	})
	self.Frame = self.Row.Frame
	self.Frame.Size = UDim2.new(1, 0, 0, top + trackArea)
	local holder = self.Row.Holder
	holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, top)
	if self.Row.Icon then
		self.Row.Icon.Position = UDim2.new(0, 0, 0, (top - 16) / 2)
	end

	-- value pill (top right)
	self.Pill = Kit.Frame(ctx, {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, top / 2),
		Size = UDim2.new(0, 0, 0, ctx.Metrics.Chip - 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = self.Frame,
	}, "Surface3")
	Kit.Corner(self.Pill, Tokens.Radius.Sm)
	Kit.Padding(self.Pill, 8, 8, 0, 0)
	self.ValueLabel = Kit.Text(ctx, {
		Name = "Text",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Tokens.Type.Supporting.Size + 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = self.Pill,
	}, function(t)
		return self:_valueColor(t)
	end, "Medium")

	-- track + fill + handle
	local trackY = top + trackArea / 2 - TRACK_HEIGHT / 2 - 2
	self.Track = Kit.Frame(ctx, {
		Name = "Track",
		Position = UDim2.new(0, 0, 0, trackY),
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		Parent = self.Frame,
	}, "Surface3")
	Kit.Corner(self.Track, Tokens.Radius.Pill)
	self.Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = self.Track,
	})
	ctx.Theme:Bind(self.Fill, "BackgroundColor3", function(t)
		return self:_fillColor(t)
	end)
	Kit.Corner(self.Fill, Tokens.Radius.Pill)
	self.Handle = Create("Frame", {
		Name = "Handle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(HANDLE, HANDLE),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = self.Track,
	})
	ctx.Theme:Bind(self.Handle, "BackgroundColor3", function(t)
		return self:_handleColor(t)
	end)
	Kit.Corner(self.Handle, Tokens.Radius.Pill)
	self.HandleStroke = Create("UIStroke", { Thickness = 2, Transparency = 0, Parent = self.Handle })
	ctx.Theme:Bind(self.HandleStroke, "Color", "Surface2")
	-- alias kept for older code
	self.Knob = self.Handle

	-- enlarged hit area (easier to aim at, especially with a finger)
	local hitHeight = ctx.Touch and ctx.Metrics.Control or 22
	self.Hit = Create("TextButton", {
		Name = "Hit",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, trackY + TRACK_HEIGHT / 2),
		Size = UDim2.new(1, 0, 0, hitHeight),
		ZIndex = 3,
		Parent = self.Frame,
	})
	CK.Track(ctx, self.Maid, self.Hit, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Hit.InputBegan:Connect(function(input)
		if not self.Disabled and Input.IsPointerDown(input) then
			self:_beginDrag(input)
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)

	self:_init(options.Default ~= nil and options.Default or self.Min)
	return self
end

function Slider:_active()
	return self.Dragging and not self.Disabled
end

function Slider:_fillColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	return theme:Get("Accent")
end

function Slider:_handleColor(theme)
	if self.Disabled then
		return theme:Get("Faint")
	end
	if self:_active() or self._hover then
		return theme:Get("Accent")
	end
	return theme:Get("Text")
end

function Slider:_valueColor(theme)
	return theme:Get(self.Disabled and "Faint" or "Accent")
end

function Slider:_beginDrag(input)
	self.Dragging = true
	self:_visual(true)
	self:_fromPointer(input.Position.X)
	self.Ctx.Input:Capture(self, input, function(moveInput)
		self:_fromPointer(moveInput.Position.X)
	end, function()
		self.Dragging = false
		if not self.Destroyed then
			self:_visual(true)
		end
	end)
end

function Slider:_fromPointer(x)
	local width = self.Track.AbsoluteSize.X
	if width <= 0 then
		return
	end
	local alpha = Util.Clamp((x - self.Track.AbsolutePosition.X) / width, 0, 1)
	self:Set(self.Min + (self.Max - self.Min) * alpha)
end

function Slider:_normalize(value)
	value = tonumber(value)
	if not value or value ~= value then
		return nil
	end
	return Util.Snap(value, self.Min, self.Max, self.Step, self.Decimals)
end

-- Repaints what depends on hover / dragging / disabled (never on the value).
function Slider:_visual(animate)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local fast = animate and Tokens.Motion.Fast or 0
	local active = self:_active()
	local size = active and HANDLE_ACTIVE or ((self._hover and not self.Disabled) and HANDLE + 2 or HANDLE)
	tween:To(self.Handle, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = self:_handleColor(theme),
	}, fast, nil, nil, true)
	tween:To(self.Fill, { BackgroundColor3 = self:_fillColor(theme) }, fast)
	tween:To(self.Track, { Size = UDim2.new(1, 0, 0, (active or self._hover) and not self.Disabled and TRACK_HEIGHT + 2 or TRACK_HEIGHT) }, fast, nil, nil, true)
	tween:To(self.ValueLabel, { TextColor3 = self:_valueColor(theme) }, fast)
	tween:To(self.Pill, { BackgroundTransparency = self.Disabled and 0.5 or 0 }, fast)
	CK.Dim(ctx, self.Row, self.Disabled, fast)
end

function Slider:_render(value, animate)
	local alpha = (value - self.Min) / (self.Max - self.Min)
	self.ValueLabel.Text = Util.FormatNumber(value, self.Decimals) .. self.Options.Suffix
	local tween = self.Ctx.Tween
	-- never tween during a drag: the value follows the pointer directly
	local duration = (animate and not self.Dragging) and 0.15 or 0
	tween:To(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
	tween:To(self.Handle, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
end

function Slider:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
		if self.Ctx.Input:IsCapturing(self) then
			self.Ctx.Input:Release(self)
			self.Dragging = false
		end
	end
	if not self.Destroyed then
		self:_visual(true)
	end
end

function Slider:Destroy()
	if self.Ctx.Input:IsCapturing(self) then
		self.Ctx.Input:Release(self)
	end
	Element.Destroy(self)
end

return Slider
end

__defs["Components/SubTabs"] = function(require)
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
end

__defs["Components/Tab"] = function(require)
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
end

__defs["Components/TextBox"] = function(require)
-- TextBox: single-line text/number input with validation feedback.
--   AddTextBox({ Name = "Webhook", Default = "", Placeholder = "https://...", Callback = function(text) end,
--                Live = false, Numeric = false, Min = 0, Max = 100, MaxLength = 64, ReadOnly = false, Disabled = false,
--                Validate = function(text) return ok, message end, Icon = "search", Flag = "hook",
--                Action = { Icon = "copy", Tooltip = "Copy", Callback = function(text) end } })
--   box:Set("x") / Get() / SetState("error"|"success"|nil, "message") / SetDisabled / SetReadOnly / Focus()
-- Commits on FocusLost (or on every change when Live = true). Invalid input is NOT committed: the field shows the
-- error state with the validation message below it and the previous value stays active.
-- States: default / hover / focus / filled / error / success / disabled / read-only.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local Space, Radius, Motion = Tokens.Space, Tokens.Radius, Tokens.Motion

local TextBox = Element.extend("TextBox")

function TextBox.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Text", Default = "", Placeholder = "", Live = false, Numeric = false })
	local self = setmetatable({}, TextBox)
	Element.init(self, ctx, options)
	self.Disabled = options.Disabled == true
	self.ReadOnly = options.ReadOnly == true
	self.Focused = false
	self.State = nil
	self.Message = nil

	local fieldWidth = options.Width or 170
	local fieldHeight = ctx.Metrics.Compact + 4
	-- the row grows by one helper line when a message is shown
	self.Row = Kit.Row(ctx, parent, { Name = options.Name, Desc = options.Desc, Icon = options.Icon and nil, Order = order, RightWidth = fieldWidth + Space.Sm })
	self.Frame = self.Row.Frame
	self._baseHeight = self.Row.Height
	self.Field = Create("Frame", {
		Name = "Field", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, (self._baseHeight - fieldHeight) / 2),
		Size = UDim2.fromOffset(fieldWidth, fieldHeight), BorderSizePixel = 0, Parent = self.Frame,
	})
	ctx.Theme:Bind(self.Field, "BackgroundColor3", "Surface2")
	Kit.Corner(self.Field, Radius.Md)
	self.FieldStroke = Kit.Stroke(ctx, self.Field, "Stroke")

	local left, right = 10, 10
	if options.Icon then
		self.LeadIcon = Icons.Create(ctx, { Icon = options.Icon, Size = 14, Color = "Muted", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Parent = self.Field })
		if self.LeadIcon then
			left = 30
		end
	end
	if options.Action then
		self.ActionButton = Kit.IconButton(ctx, self.Maid, {
			Name = "Action", Icon = options.Action.Icon or "copy", Tooltip = options.Action.Tooltip, Size = fieldHeight - 6, IconSize = 13,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -3, 0.5, 0), Parent = self.Field,
			Callback = function()
				Util.Call(options.Action.Callback, self.Value)
			end,
		})
		right = fieldHeight + 2
	end
	self.StatusIcon = Icons.Create(ctx, { Icon = "info", Name = "StatusIcon", Size = 14, Color = "Error", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right, 0.5, 0), Parent = self.Field })
	self.StatusIcon.Visible = false
	self.Box = Create("TextBox", {
		Name = "Input", BackgroundTransparency = 1, Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -(left + right + 18), 1, 0),
		Text = "", PlaceholderText = options.Placeholder, ClearTextOnFocus = options.ClearOnFocus == true, TextSize = Tokens.Type.Supporting.Size + 1,
		FontFace = ctx.Fonts.Medium, TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, Parent = self.Field,
	})
	ctx.Theme:Bind(self.Box, "TextColor3", "Text")
	ctx.Theme:Bind(self.Box, "PlaceholderColor3", "Faint")

	self.Helper = Kit.Text(ctx, { Name = "Helper", Text = "", TextSize = Tokens.Type.Supporting.Size, Position = UDim2.new(0, 0, 0, self._baseHeight - 2), Size = UDim2.new(1, 0, 0, 16), Visible = false, Parent = self.Frame }, "Muted", "Regular")

	self.Maid:Give(self.Box.Focused:Connect(function()
		self.Focused = true
		self:_visual(true)
	end))
	self.Maid:Give(self.Box.FocusLost:Connect(function()
		self.Focused = false
		self:_commit()
		self:_visual(true)
	end))
	self.Maid:Give(self.Box:GetPropertyChangedSignal("Text"):Connect(function()
		if self._syncing then
			return
		end
		local max = options.MaxLength
		if max and #self.Box.Text > max then
			self._syncing = true
			self.Box.Text = self.Box.Text:sub(1, max)
			self._syncing = false
		end
		if self.ReadOnly or self.Disabled then
			self._syncing = true
			self.Box.Text = self.Value
			self._syncing = false
			return
		end
		if options.Live then
			self:_commit()
		end
		self:_visual(true)
	end))
	CK.Track(ctx, self.Maid, self.Field, self, function()
		self:_visual(true)
	end)
	CK.Tooltip(ctx, self.Maid, self.Field, options.Tooltip)

	self:_init(options.Default)
	self:_visual(false)
	return self
end

function TextBox:_normalize(value)
	if value == nil then
		return nil
	end
	if self.Options.Numeric then
		local number = tonumber(value)
		if not number or number ~= number then
			return nil
		end
		local o = self.Options
		if o.Min then
			number = math.max(number, o.Min)
		end
		if o.Max then
			number = math.min(number, o.Max)
		end
		return number
	end
	local text = tostring(value)
	if self.Options.MaxLength then
		text = text:sub(1, self.Options.MaxLength)
	end
	return text
end

function TextBox:_render(value)
	self._syncing = true
	self.Box.Text = tostring(value)
	self._syncing = false
	self:_visual(false)
end

-- Runs validation on the typed text; commits it when valid, otherwise shows the error and keeps the old value.
function TextBox:_commit()
	local text = self.Box.Text
	if text == tostring(self.Value) then
		if self.State == "error" and not self._forced then
			self:_setState(nil, nil)
		end
		return
	end
	local validate = self.Options.Validate
	if validate then
		local ok, result, message = pcall(validate, text)
		if not ok then
			warn("[MaUI] error in Validate: " .. tostring(result))
		elseif not result then
			self:_setState("error", message or "Invalid value")
			return
		end
	end
	local normalized = self:_normalize(text)
	if normalized == nil then
		self:_setState("error", self.Options.Numeric and "Enter a number" or "Invalid value")
		return
	end
	self:_setState(nil, nil)
	if self:_equals(self.Value, normalized) then
		self:_render(self.Value)
		return
	end
	self.Value = normalized
	self:_render(normalized)
	self:_emit(normalized)
end

function TextBox:_setState(state, message)
	self.State, self.Message = state, message
	self._forced = false
	local hasMessage = message ~= nil and message ~= ""
	self.Helper.Visible = hasMessage
	self.Helper.Text = hasMessage and tostring(message) or ""
	self.Ctx.Theme:Bind(self.Helper, "TextColor3", state == "error" and "Error" or (state == "success" and "Success" or "Muted"))
	self.Frame.Size = UDim2.new(1, 0, 0, self._baseHeight + (hasMessage and 16 or 0))
	if self.StatusIcon then
		local kind = state == "error" and "error" or (state == "success" and "success" or nil)
		self.StatusIcon.Visible = kind ~= nil
		if kind then
			local k, glyph = Icons.Resolve(kind)
			if k == "glyph" then
				self.StatusIcon.Text = glyph
			end
			self.Ctx.Theme:Bind(self.StatusIcon, Icons.ColorProperty(self.StatusIcon), state == "error" and "Error" or "Success")
		end
	end
	self:_visual(true)
end

-- Manually sets the feedback state ("error" | "success" | nil) with an optional message.
function TextBox:SetState(state, message)
	if state ~= nil and state ~= "error" and state ~= "success" then
		warn("[MaUI] unknown TextBox state: " .. tostring(state))
		return
	end
	self:_setState(state, message)
	self._forced = true
end

function TextBox:_visual(animate)
	if self.Destroyed then
		return
	end
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local d = animate and Motion.Fast or 0
	local stroke = "Stroke"
	if self.Disabled then
		stroke = "Stroke"
	elseif self.State == "error" then
		stroke = "Error"
	elseif self.State == "success" then
		stroke = "Success"
	elseif self.Focused and not self.ReadOnly then
		stroke = "Accent"
	elseif self._hover then
		stroke = "StrokeHover"
	end
	tween:To(self.FieldStroke, { Color = theme:Get(stroke) }, d)
	tween:To(self.Field, { BackgroundTransparency = self.Disabled and 0.5 or (self.ReadOnly and 0.3 or 0) }, d)
	tween:To(self.Box, { TextTransparency = self.Disabled and 0.5 or 0 }, d)
	if self.LeadIcon then
		tween:To(self.LeadIcon, { [Icons.ColorProperty(self.LeadIcon)] = theme:Get(self.Focused and "Accent" or "Muted") }, d)
	end
	CK.Dim(ctx, self.Row, self.Disabled, d)
end

function TextBox:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Box.TextEditable = not (self.Disabled or self.ReadOnly)
	if self.Disabled then
		self._hover = false
	end
	self:_visual(true)
end

function TextBox:SetReadOnly(readOnly)
	self.ReadOnly = readOnly == true
	self.Box.TextEditable = not (self.Disabled or self.ReadOnly)
	self:_visual(true)
end

function TextBox:Focus()
	if not (self.Disabled or self.ReadOnly) then
		self.Box:CaptureFocus()
	end
end

return TextBox
end

__defs["Components/ThemeEditor"] = function(require)
-- ThemeEditor: ready-made card to customize and manage themes with a live preview.
--   section:AddThemeEditor({ Title = "Theme", Tokens = { "Accent", "Background", "Surface", "Text", "Muted" } })
-- Contents: theme selector, one color picker per token (changes recolor the whole UI immediately),
-- a name field and Save / Load / Delete / Set default buttons (custom themes live in <ConfigFolder>/themes).
local Section = require("Components/Section")
local Util = require("Core/Util")

local ThemeEditor = {}
ThemeEditor.__index = ThemeEditor
ThemeEditor.Persistent = false

local DEFAULT_TOKENS = { "Accent", "Background", "Surface", "Text", "Muted" }

function ThemeEditor.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "Theme", Icon = "palette", Tokens = DEFAULT_TOKENS }, "Title")
	local self = setmetatable({}, ThemeEditor)
	local library, theme = ctx.Library, ctx.Theme
	self.Options = options
	self.Ctx = ctx
	self.Section = Section.new(ctx, { Name = options.Title, Icon = options.Icon, Variant = "Settings", Desc = "Colors update live" }, parent, order)
	self.Frame = self.Section.Frame
	self.Pickers = {}
	local card = self.Section

	local function notify(title, content, kind)
		library:Notify({ Title = title, Content = content, Type = kind })
	end
	local function names()
		return theme:List()
	end

	self.Selector = card:AddDropdown({
		Name = "Theme", Items = names(), Default = theme.Name, Callback = function(name)
			if theme.Name ~= name then
				library:SetTheme(name)
			end
		end,
	})
	for _, token in ipairs(options.Tokens) do
		if theme:Get(token) then
			self.Pickers[token] = card:AddColorPicker({
				Name = token, Default = theme:Get(token), Callback = function(color)
					if not self._refreshing then
						theme:SetToken(token, color)
					end
				end,
			})
		end
	end
	self.NameBox = card:AddTextBox({ Name = "Save as", Placeholder = "theme name", Width = 150 })

	local function refreshSelector()
		self.Selector:SetItems(names())
		self.Selector:Set(theme.Name, true)
	end
	local function currentName()
		local typed = Util.Trim(self.NameBox:Get() or "")
		return typed ~= "" and typed or theme.Name
	end
	local columns = card:AddColumns(2)
	columns[1]:AddButton({ Name = "Save", Icon = "check", Callback = function()
		local name = currentName()
		local ok, err = library:SaveTheme(name)
		if ok then
			refreshSelector()
			notify("Theme saved", name, "Success")
		else
			notify("Could not save theme", tostring(err), "Error")
		end
	end })
	columns[2]:AddButton({ Name = "Load", Icon = "folder", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:LoadTheme(name)
		if ok then
			notify("Theme loaded", name, "Info")
		elseif theme:Has(name) then
			library:SetTheme(name)
		else
			notify("Could not load theme", tostring(err), "Error")
		end
	end })
	local second = card:AddColumns(2)
	second[1]:AddButton({ Name = "Delete", Style = "Destructive", Confirm = true, Icon = "close", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:DeleteTheme(name)
		if ok then
			library:SetTheme("Sakura")
			refreshSelector()
			notify("Theme deleted", name, "Warning")
		else
			notify("Could not delete theme", tostring(err), "Error")
		end
	end })
	second[2]:AddButton({ Name = "Set default", Icon = "star", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:SetDefaultTheme(name)
		if ok then
			notify("Default theme", name .. " will load at startup", "Success")
		else
			notify("Could not set default", tostring(err), "Error")
		end
	end })

	-- keep pickers in sync when the theme changes from anywhere else (SetTheme, load...)
	self._connection = theme.Changed:Connect(function(name)
		self._refreshing = true
		for token, picker in pairs(self.Pickers) do
			picker:Set(theme:Get(token), true)
		end
		if self.Selector.Frame and self.Selector:Get() ~= name then
			self.Selector:Set(name, true)
		end
		self._refreshing = false
	end)
	return self
end

function ThemeEditor:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self.Section:Destroy()
end

function ThemeEditor:SetVisible(visible)
	self.Section:SetVisible(visible)
end

return ThemeEditor
end

__defs["Components/Toggle"] = function(require)
-- Toggle: boolean switch (38x20 track with a knob) on a transparent row.
--   AddToggle({ Name = "Auto", Desc = "...", Icon = "bolt", Default = false, Flag = "auto",
--               Disabled = false, Tooltip = "Runs automatically", Callback = function(on) end })
--   toggle:Set(true)  /  toggle:Set(true, true) to skip the callback
--   toggle:SetDisabled(true)   -- user input is ignored, programmatic Set still works
-- States: OFF / ON / hover / pressed / disabled.
local CK = require("Components/ControlKit")
local Element = require("Core/Element")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Toggle = Element.extend("Toggle")

local INSET = 3

function Toggle.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Toggle", Default = false })
	local self = setmetatable({}, Toggle)
	Element.init(self, ctx, options)

	local touch = ctx.Touch
	local width, height = 38, 20
	if touch then
		width, height = 46, 24
	end
	local knob = height - INSET * 2
	self._pillWidth, self._knobSize, self._knobPressed = width, knob, knob + 4
	self.Disabled = options.Disabled == true

	self.Row = Kit.Row(ctx, parent, {
		Name = options.Name,
		Desc = options.Desc,
		Icon = options.Icon,
		Order = order,
		Clickable = true,
		RightWidth = width + Tokens.Space.Sm,
	})
	self.Frame = self.Row.Frame
	local theme = ctx.Theme

	self.Pill = Create("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		BorderSizePixel = 0,
		Parent = self.Frame,
	})
	Kit.Corner(self.Pill, Tokens.Radius.Pill)
	-- the bindings read the current state: a theme change stays consistent
	theme:Bind(self.Pill, "BackgroundColor3", function(t)
		return self:_trackColor(t)
	end)
	self.Knob = Create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(knob, knob),
		BorderSizePixel = 0,
		Parent = self.Pill,
	})
	Kit.Corner(self.Knob, Tokens.Radius.Pill)
	theme:Bind(self.Knob, "BackgroundColor3", function(t)
		return self:_knobColor(t)
	end)

	CK.Track(ctx, self.Maid, self.Frame, self, function()
		self:_visual(true)
	end)
	self.Maid:Give(self.Frame.MouseButton1Click:Connect(function()
		if not self.Disabled then
			self:Set(not self.Value)
		end
	end))
	CK.Tooltip(ctx, self.Maid, self.Frame, options.Tooltip)

	self:_init(options.Default)
	return self
end

function Toggle:_trackColor(theme)
	if self.Value then
		return theme:Get("Accent")
	end
	if not self.Disabled then
		if self._pressed then
			return theme:Get("Faint")
		elseif self._hover then
			return theme:Get("StrokeHover")
		end
	end
	return theme:Get("Surface3")
end

function Toggle:_knobColor(theme)
	return self.Value and theme:Get("AccentText") or theme:Get(self._hover and not self.Disabled and "Text" or "Muted")
end

function Toggle:_normalize(value)
	return value == true
end

-- Repaints everything that depends on (value, hover, pressed, disabled).
function Toggle:_visual(animate)
	local ctx = self.Ctx
	local theme, tween = ctx.Theme, ctx.Tween
	local duration = animate and Tokens.Motion.Base or 0
	local fast = animate and Tokens.Motion.Fast or 0
	local disabled = self.Disabled
	local pressed = self._pressed and not disabled
	local knobWidth = pressed and self._knobPressed or self._knobSize
	local x = self.Value and (self._pillWidth - INSET - knobWidth) or INSET

	tween:To(self.Pill, {
		BackgroundColor3 = self:_trackColor(theme),
		BackgroundTransparency = disabled and 0.55 or ((pressed and self.Value) and 0.2 or 0),
	}, duration)
	tween:To(self.Knob, {
		Position = UDim2.new(0, x, 0.5, 0),
		Size = UDim2.fromOffset(knobWidth, self._knobSize),
		BackgroundColor3 = self:_knobColor(theme),
		BackgroundTransparency = disabled and 0.35 or 0,
	}, duration)
	CK.RowBackground(ctx, self.Frame, self, disabled, fast)
	CK.Dim(ctx, self.Row, disabled, fast)
end

function Toggle:_render(_, animate)
	self:_visual(animate)
end

function Toggle:SetDisabled(disabled)
	self.Disabled = disabled == true
	if self.Disabled then
		self._hover, self._pressed = false, false
	end
	if not self.Destroyed then
		self:_visual(true)
	end
end

function Toggle:Toggle()
	self:Set(not self.Value)
end

return Toggle
end

__defs["Components/Window"] = function(require)
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
	if options.Callback == nil then
		-- default: the card leads to the Home tab
		options.Callback = function()
			if self.Home and not self.Destroyed then
				if not self.Open then
					self:Toggle(true)
				end
				self:SelectTab(self.Home)
			end
		end
	end
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

-- Built-in settings page: interface (sidebar, animations, size, scale), keybinds, theme editor, configs.
-- Created automatically (last in the sidebar); pass `Settings = false` to CreateWindow to skip it.
function Window:AddSettings(options)
	if self.SettingsTab then
		return self.SettingsTab
	end
	options = Util.Options(options, { Name = "Settings", Icon = "settings" }, "Name")
	local library = self.Library
	local tab = Tab.new(self, { Name = options.Name, Icon = options.Icon }, 1000000)
	self.Tabs[#self.Tabs + 1] = tab
	self.Maid:Give(tab)
	self.SettingsTab = tab

	local columns = tab:AddColumns({ Count = 2, MinWidth = 260 })
	local ui = columns[1]:AddSection({ Name = "Interface", Icon = "settings", Variant = "Settings" })
	ui:AddDropdown({ Name = "Sidebar", Items = { "Auto", "Expanded", "Compact" }, Default = self.Options.Sidebar or "Auto",
		Callback = function(value) self:SetSidebarMode(value) end })
	ui:AddDropdown({ Name = "Animations", Items = { "Full", "Reduced", "Off" }, Default = library.Options.Animations or "Full",
		Callback = function(value) library:SetAnimations(value) end })
	ui:AddSlider({ Name = "Width", Min = self.Options.MinSize.X, Max = self.Options.MaxSize.X, Default = self.Root.Size.X.Offset,
		Callback = function(value) self:SetSize(value, nil) end })
	ui:AddSlider({ Name = "Height", Min = self.Options.MinSize.Y, Max = self.Options.MaxSize.Y, Default = self.Root.Size.Y.Offset,
		Callback = function(value) self:SetSize(nil, value) end })
	ui:AddSlider({ Name = "UI scale", Min = 0.7, Max = 1.5, Step = 0.05, Default = 1,
		Callback = function(value) self:SetScale(value) end })
	ui:AddButton({ Name = "Reset window", Style = "Secondary", Callback = function()
		self:SetFullscreen(false)
		self:Collapse(false)
		self:SetScale(1)
		self:SetSize(self.Options.Size.X, self.Options.Size.Y)
		self.Root.Position = UDim2.new(0.5, -math.floor(self.Root.Size.X.Offset / 2), 0.5, -math.floor(self.Root.Size.Y.Offset / 2))
	end })

	local keys = columns[2]:AddSection({ Name = "Keybinds", Icon = "keyboard", Variant = "Settings" })
	keys:AddKeybind({ Name = "Show / hide UI", Default = self.ToggleBind.KeyCode,
		OnChanged = function(key) self:SetToggleKey(key or false) end })
	keys:AddKeybind({ Name = "Collapse window", Default = self.CollapseBind.KeyCode,
		OnChanged = function(key) self:SetCollapseKey(key) end })

	tab:AddThemeEditor()
	tab:AddConfigManager()
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
	local collapseIcon = self.CollapseButton and Kit.IconOf(self.CollapseButton)
	if collapseIcon then
		local kind, glyph = Icons.Resolve(collapsed and "plus" or "minus")
		if kind == "glyph" then
			collapseIcon.Text = glyph
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
	local expandIcon = self.ExpandButton and Kit.IconOf(self.ExpandButton)
	if expandIcon then
		local kind, glyph = Icons.Resolve(fullscreen and "shrink" or "expand")
		if kind == "glyph" then
			expandIcon.Text = glyph
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
	if key == false or key == nil then
		self.ToggleBind:SetKey(nil)
		return
	end
	local parsed = Util.ParseKey(key)
	if parsed then
		self.ToggleBind:SetKey(parsed)
	end
end

-- Resizes the window (pixels), clamped to MinSize/MaxSize. Ignored while collapsed or fullscreen.
function Window:SetSize(width, height)
	if self.Destroyed or self.Collapsed or self.Fullscreen then
		return
	end
	local o = self.Options
	self.Root.Size = UDim2.fromOffset(
		Util.Clamp(width or self.Root.Size.X.Offset, o.MinSize.X, o.MaxSize.X),
		Util.Clamp(height or self.Root.Size.Y.Offset, o.MinSize.Y, o.MaxSize.Y)
	)
	self:_applyLayout(false)
	self:_clampToScreen()
end

-- Scales the whole window (0.7 - 1.5).
function Window:SetScale(scale)
	scale = Util.Clamp(tonumber(scale) or 1, 0.7, 1.5)
	if not self._scale then
		self._scale = Create("UIScale", { Parent = self.Root })
	end
	self._scale.Scale = scale
	self.Scale = scale
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
end

__defs["Core/Element"] = function(require)
-- Element: base class of all interactive components.
-- Provides: Maid, Changed, Flag (store + config), Set/Get, safe callbacks, Destroy.
--
-- A subclass defines:
--   _normalize(value) -> valid value, or nil if invalid
--   _render(value, animate)  -> updates the UI
-- and calls self:_init(default) at the end of its constructor.
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Util = require("Core/Util")

local Element = {}
Element.__index = Element

function Element.extend(kind)
	local class = {}
	class.__index = class
	class.Kind = kind
	return setmetatable(class, { __index = Element })
end

function Element.init(self, ctx, options)
	self.Ctx = ctx
	self.Options = options
	self.Maid = Maid.new()
	self.Changed = Signal.new()
	self.Destroyed = false
	self.Flag = options.Flag
	self.Maid:Give(self.Changed)
	if self.Flag then
		ctx.Library:_RegisterFlag(self.Flag, self)
		self.Maid:Give(function()
			ctx.Library:_UnregisterFlag(self.Flag, self)
		end)
	end
end

-- To override -------------------------------------------------------------------

function Element:_normalize(value)
	return value
end

function Element:_equals(a, b)
	return a == b
end

function Element:_render(value, animate) end

-- Notifies the user (Callback). Overridden by Keybind.
function Element:_callback(value)
	Util.Call(self.Options.Callback, value)
end

-- Initial value: set without animation and without callback (unless FireOnInit = true).
function Element:_init(default)
	local value = self:_normalize(default)
	self.Default = value -- remembered so Reset() can restore it
	self.Value = value
	self.Default = value -- remembered for Element:Reset()
	self:_render(value, false)
	if self.Options.FireOnInit and value ~= nil then
		self:_emit(value)
	end
end

function Element:_emit(value)
	self.Changed:Fire(value)
	self:_callback(value)
	if self.Flag then
		self.Ctx.Library:_NotifyFlagChanged(self)
	end
end

-- Public API -------------------------------------------------------------------

function Element:Get()
	return self.Value
end

-- Set(value, silent): `silent = true` fires neither Changed nor Callback.
function Element:Set(value, silent)
	if self.Destroyed then
		return
	end
	local normalized = self:_normalize(value)
	if normalized == nil then
		return
	end
	if self:_equals(self.Value, normalized) then
		return
	end
	self.Value = normalized
	self:_render(normalized, true)
	if not silent then
		self:_emit(normalized)
	end
end

-- Restores the (normalized) default value given at construction. No-op without a default.
-- Callbacks fire unless `silent` is true.
function Element:Reset(silent)
	if self.Default ~= nil then
		self:Set(self.Default, silent)
	end
end

-- Restores the default value (silent by default: pass false to fire callbacks).
function Element:Reset(silent)
	if self.Default ~= nil then
		self:Set(self.Default, silent ~= false)
	end
end

function Element:OnChanged(callback)
	return self.Changed:Connect(callback)
end

function Element:SetVisible(visible)
	if self.Frame then
		self.Frame.Visible = visible
	end
end

-- Config: value <-> JSON. Overridable (e.g. Keybind).
function Element:Serialize()
	return self.Value
end

function Element:Deserialize(data, silent)
	self:Set(data, silent)
end

function Element:Destroy()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	self.Maid:Clean()
	if self.Frame then
		self.Ctx.Theme:Release(self.Frame)
		self.Frame:Destroy()
		self.Frame = nil
	end
end

return Element
end

__defs["Core/Env"] = function(require)
-- Env: platform adapter. The rest of the lib never calls
-- gethui / writefile / etc. directly: everything goes through here (and stays optional).
local Env = {}

local function lookup(name)
	local ok, value = pcall(function()
		return getfenv(0)[name]
	end)
	if ok and value ~= nil then
		return value
	end
	local okGenv, genv = pcall(function()
		return getgenv()
	end)
	if okGenv and type(genv) == "table" and genv[name] ~= nil then
		return genv[name]
	end
	return _G[name]
end

-- gethui() -> CoreGui -> PlayerGui. `preferred` forces a specific parent.
function Env.GetParent(preferred)
	if preferred then
		return preferred
	end
	local gethui = lookup("gethui")
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		local writable = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = coreGui
			probe:Destroy()
		end)
		if writable then
			return coreGui
		end
	end
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

function Env.IsTouch()
	local service = game:GetService("UserInputService")
	return service.TouchEnabled and not service.KeyboardEnabled
end

-- Clipboard (optional). Returns true if the text was copied.
function Env.SetClipboard(text)
	for _, name in ipairs({ "setclipboard", "toclipboard" }) do
		local fn = lookup(name)
		if type(fn) == "function" then
			local ok = pcall(fn, text)
			if ok then
				return true
			end
		end
	end
	return false
end

-- Files (optional) ------------------------------------------------------

function Env.HasFS()
	return type(lookup("writefile")) == "function"
		and type(lookup("readfile")) == "function"
		and type(lookup("isfile")) == "function"
end

local function call(name, ...)
	local fn = lookup(name)
	if type(fn) ~= "function" then
		return false, name .. " unavailable"
	end
	return pcall(fn, ...)
end

function Env.EnsureFolder(path)
	local isfolder, makefolder = lookup("isfolder"), lookup("makefolder")
	if type(isfolder) == "function" and type(makefolder) == "function" then
		local ok, exists = pcall(isfolder, path)
		if ok and not exists then
			pcall(makefolder, path)
		end
	end
end

function Env.WriteFile(path, data)
	return call("writefile", path, data)
end

-- Returns ok, content|error
function Env.ReadFile(path)
	return call("readfile", path)
end

function Env.IsFile(path)
	local ok, result = call("isfile", path)
	return ok and result == true
end

function Env.DeleteFile(path)
	return call("delfile", path)
end

function Env.ListFiles(folder)
	local ok, result = call("listfiles", folder)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

return Env
end

__defs["Core/Icons"] = function(require)
-- Icons: one registry for every icon in the library.
-- An icon is referenced by name ("home"), by asset ("rbxassetid://123") or not at all.
-- Built-in names resolve to a compact text glyph so the library is usable with ZERO asset
-- dependencies; call Icons.Register("home", "rbxassetid://<id>") (or MaUI.Icons.Register) to swap
-- in a real icon set, and every component that uses "home" picks it up.
local Icons = {}

local glyphs = {
	home = "⌂", settings = "≡", search = "⌕", close = "✕", check = "✓", plus = "+", minus = "–",
	chevron = "▾", chevronRight = "▸", info = "i", warning = "!", error = "✕", success = "✓",
	star = "★", dot = "●", user = "☺", copy = "⧉", refresh = "⟳", folder = "▤", palette = "◐",
	bolt = "ϟ", keyboard = "▦", gear = "≡", eye = "◉", eyeOff = "○", expand = "⤢", shrink = "⤡", play = "▶", loading = "◜",
}
local assets = {}

function Icons.Register(name, asset)
	assets[name] = asset
end

function Icons.Has(name)
	return assets[name] ~= nil or glyphs[name] ~= nil
end

-- Returns kind ("image" | "glyph"), value; nil when `icon` is nil/empty/unknown.
function Icons.Resolve(icon)
	if type(icon) ~= "string" or icon == "" then
		return nil
	end
	if icon:find("rbxasset", 1, true) or icon:match("^%d+$") then
		return "image", icon:match("^%d+$") and ("rbxassetid://" .. icon) or icon
	end
	if assets[icon] then
		return "image", assets[icon]
	end
	if glyphs[icon] then
		return "glyph", glyphs[icon]
	end
	return nil
end

-- Builds the icon instance. props: Icon, Size (default 16), Color (token or function), Parent,
-- Position, AnchorPoint, Name, LayoutOrder. Returns nil when the icon cannot be resolved.
function Icons.Create(ctx, props)
	local kind, value = Icons.Resolve(props.Icon)
	if not kind then
		return nil
	end
	local size = props.Size or 16
	local instance
	if kind == "image" then
		instance = Instance.new("ImageLabel")
		instance.Image = value
		instance.ScaleType = Enum.ScaleType.Fit
	else
		instance = Instance.new("TextLabel")
		instance.Text = value
		instance.TextSize = math.floor(size * 1.05)
		instance.FontFace = ctx.Fonts.Bold
	end
	instance.Name = props.Name or "Icon"
	instance.BackgroundTransparency = 1
	instance.Size = UDim2.fromOffset(size, size)
	if props.Position then
		instance.Position = props.Position
	end
	if props.AnchorPoint then
		instance.AnchorPoint = props.AnchorPoint
	end
	if props.LayoutOrder then
		instance.LayoutOrder = props.LayoutOrder
	end
	ctx.Theme:Bind(instance, kind == "image" and "ImageColor3" or "TextColor3", props.Color or "Muted")
	instance.Parent = props.Parent
	return instance, kind
end

-- Recolors an icon created by Create (handles both kinds).
function Icons.Tint(instance, color)
	if instance:IsA("ImageLabel") then
		instance.ImageColor3 = color
	else
		instance.TextColor3 = color
	end
end

function Icons.ColorProperty(instance)
	return instance:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
end

return Icons
end

__defs["Core/Input"] = function(require)
-- Input: SINGLE entry point for keyboard/mouse/touch input across the whole lib.
--  * 1 permanent listener (InputBegan) for keybinds -> KeyCode table -> handlers (O(1)).
--  * InputChanged / InputEnded listeners only exist DURING a capture (slider drag,
--    window move/resize). At rest, no cost per mouse movement.
--  * Only one active capture at a time: only the active element receives movements.
local Util = require("Core/Util")

local UserInputService = game:GetService("UserInputService")

local Input = {}
Input.__index = Input

local function isMouseButton(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
end

function Input.new()
	local self = setmetatable({}, Input)
	self._binds = {} -- [KeyCode] = { handle, ... }
	self._capture = nil
	self._keyCapture = nil
	self._began = UserInputService.InputBegan:Connect(function(input, processed)
		self:_onBegan(input, processed)
	end)
	return self
end

-- Keybinds ----------------------------------------------------------------------

function Input:_onBegan(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- During a "rebind", the key is swallowed: no other bind fires.
	local keyCapture = self._keyCapture
	if keyCapture then
		self._keyCapture = nil
		Util.Call(keyCapture, input.KeyCode)
		return
	end
	if processed then
		return
	end
	local list = self._binds[input.KeyCode]
	if not list then
		return
	end
	-- copy: a callback can add/remove binds
	local snapshot = {}
	for i = 1, #list do
		snapshot[i] = list[i]
	end
	for i = 1, #snapshot do
		local handle = snapshot[i]
		if handle.Connected then
			Util.Call(handle.Callback, input.KeyCode)
		end
	end
end

local function removeFrom(list, handle)
	for i = 1, #list do
		if list[i] == handle then
			table.remove(list, i)
			return
		end
	end
end

-- Registers a keybind. Returns a handle { SetKey(keyCode|nil), Disconnect() }.
function Input:BindKey(keyCode, callback)
	local owner = self
	local handle = { Callback = callback, KeyCode = nil, Connected = true }

	function handle:SetKey(newKey)
		if self.KeyCode then
			local list = owner._binds[self.KeyCode]
			if list then
				removeFrom(list, self)
				if #list == 0 then
					owner._binds[self.KeyCode] = nil
				end
			end
		end
		self.KeyCode = newKey
		if newKey then
			local list = owner._binds[newKey]
			if not list then
				list = {}
				owner._binds[newKey] = list
			end
			list[#list + 1] = self
		end
	end

	function handle:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		self:SetKey(nil)
	end

	handle:SetKey(keyCode)
	return handle
end

-- Waits for the next key pressed. callback(keyCode); callback(nil) if the capture is cancelled.
function Input:CaptureKey(callback)
	self:CancelKeyCapture()
	self._keyCapture = callback
end

function Input:CancelKeyCapture()
	local previous = self._keyCapture
	if previous then
		self._keyCapture = nil
		Util.Call(previous, nil)
	end
end

-- Pointer captures (drag) ---------------------------------------------------

-- Starts a capture from the InputObject `startInput` (click / touch).
--   onMove(inputObject) : on every movement of the same pointer
--   onEnd()             : on release (or if another capture takes over)
function Input:Capture(owner, startInput, onMove, onEnd)
	self:Release()
	local capture = { Owner = owner, Start = startInput, OnEnd = onEnd }
	self._capture = capture

	capture.Changed = UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or (kind == Enum.UserInputType.Touch and input == startInput) then
			Util.Call(onMove, input)
		end
	end)

	capture.Ended = UserInputService.InputEnded:Connect(function(input)
		local same = input == startInput
			or (isMouseButton(startInput) and input.UserInputType == startInput.UserInputType)
		if same then
			self:Release(owner)
		end
	end)
end

-- Ends the current capture. If `owner` is given, only that owner can end it.
function Input:Release(owner)
	local capture = self._capture
	if not capture then
		return
	end
	if owner ~= nil and capture.Owner ~= owner then
		return
	end
	self._capture = nil
	capture.Changed:Disconnect()
	capture.Ended:Disconnect()
	Util.Call(capture.OnEnd)
end

function Input:IsCapturing(owner)
	local capture = self._capture
	return capture ~= nil and (owner == nil or capture.Owner == owner)
end

-- Left click or touch: the only "presses" that start a drag.
function Input.IsPointerDown(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

function Input:Destroy()
	self:Release()
	self._keyCapture = nil
	self._binds = {}
	if self._began then
		self._began:Disconnect()
		self._began = nil
	end
end

return Input
end

__defs["Core/Kit"] = function(require)
-- Kit: small shared UI builders (cards, texts, hover...).
-- Everything is bound to the theme via ctx.Theme:Bind, nothing is hardcoded.
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Kit = {}

function Kit.Corner(parent, radius)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function Kit.Stroke(ctx, parent, token, thickness)
	local stroke = Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Parent = parent,
	})
	ctx.Theme:Bind(stroke, "Color", token or "Stroke")
	return stroke
end

function Kit.Padding(parent, left, right, top, bottom)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
		Parent = parent,
	})
end

function Kit.List(parent, padding)
	return Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding or 0),
		Parent = parent,
	})
end

-- Solid Frame, color bound to a background token.
function Kit.Frame(ctx, props, token)
	props.BorderSizePixel = 0
	local frame = Create("Frame", props)
	ctx.Theme:Bind(frame, "BackgroundColor3", token or "Surface")
	return frame
end

-- Transparent TextLabel. colorToken: text token ("Text", "Muted", ...), fontKey: Regular|Medium|Bold.
function Kit.Text(ctx, props, colorToken, fontKey)
	props.BackgroundTransparency = 1
	if props.TextSize == nil then
		props.TextSize = 14
	end
	props.FontFace = props.FontFace or ctx.Fonts[fontKey or "Medium"]
	if props.TextXAlignment == nil then
		props.TextXAlignment = Enum.TextXAlignment.Left
	end
	if props.TextTruncate == nil then
		props.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local label = Create("TextLabel", props)
	ctx.Theme:Bind(label, "TextColor3", colorToken or "Text")
	return label
end

-- Standard element card: Surface2 background, border, title + optional description.
-- options: Name, Desc, Clickable, Order, RightWidth (space reserved on the right),
--          Height (forces the height), TopAligned (text at the top instead of centered)
function Kit.Card(ctx, parent, options)
	local metrics = ctx.Metrics
	local height = options.Height or (options.Desc and metrics.CardTall or metrics.Card)
	local frame = Create(options.Clickable and "TextButton" or "Frame", {
		Name = options.Name or "Card",
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = options.Order or 0,
		Parent = parent,
	})
	if options.Clickable then
		frame.AutoButtonColor = false
		frame.Text = ""
	end
	ctx.Theme:Bind(frame, "BackgroundColor3", "Surface2")
	Kit.Corner(frame, 8)
	local stroke = Kit.Stroke(ctx, frame, "Stroke")

	local reserved = 28 + (options.RightWidth or 0)
	local holder = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = options.TopAligned and UDim2.fromOffset(14, 10) or UDim2.fromOffset(14, 0),
		Size = options.TopAligned and UDim2.new(1, -reserved, 0, options.Desc and 38 or 20)
			or UDim2.new(1, -reserved, 1, 0),
		Parent = frame,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = options.TopAligned and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		Parent = holder,
	})
	local title = Kit.Text(ctx, {
		Name = "Title",
		Text = options.Name or "",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = holder,
	}, "Text", "Medium")
	local desc
	if options.Desc then
		desc = Kit.Text(ctx, {
			Name = "Desc",
			Text = options.Desc,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
			Parent = holder,
		}, "Muted", "Regular")
	end

	return { Frame = frame, Stroke = stroke, Title = title, Desc = desc, Holder = holder, Height = height }
end

-- Hover: the card border switches to StrokeHover. Ignored on touch.
function Kit.Hover(ctx, maid, button, stroke)
	if ctx.Touch then
		return
	end
	maid:Give(button.MouseEnter:Connect(function()
		ctx.Tween:To(stroke, { Color = ctx.Theme:Get("StrokeHover") }, 0.12)
	end))
	maid:Give(button.MouseLeave:Connect(function()
		ctx.Tween:To(stroke, { Color = ctx.Theme:Get("Stroke") }, 0.2)
	end))
end

local Icons = require("Core/Icons")

-- Row: the building block of every control line inside a card. Transparent (the card is the
-- surface), title on the left, a reserved area on the right for the control.
-- options: Name, Desc, Icon, Order, Clickable, RightWidth, Height
-- Returns { Frame, Title, Desc, Icon, Holder, Height }.
function Kit.Row(ctx, parent, options)
	local height = options.Height or (options.Desc and (ctx.Metrics.Control + 18) or ctx.Metrics.Control)
	local frame = Create(options.Clickable and "TextButton" or "Frame", {
		Name = options.Name or "Row",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = options.Order or 0,
		Parent = parent,
	})
	if options.Clickable then
		frame.AutoButtonColor = false
		frame.Text = ""
	end
	ctx.Theme:Bind(frame, "BackgroundColor3", "Surface2")
	Kit.Corner(frame, Tokens.Radius.Sm)

	local left = 0
	local icon
	if options.Icon then
		icon = Icons.Create(ctx, {
			Icon = options.Icon,
			Size = 16,
			Color = "Muted",
			Position = UDim2.new(0, 0, 0.5, -8),
			Parent = frame,
		})
		if icon then
			left = 24
		end
	end
	local holder = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + (options.RightWidth or 0) + Tokens.Space.Md), 1, 0),
		Parent = frame,
	})
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Tokens.Space.Xs),
		Parent = holder,
	})
	local title = Kit.Text(ctx, {
		Name = "Title",
		Text = options.Name or "",
		TextSize = Tokens.Type.Secondary.Size - 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = holder,
	}, "Text", "Medium")
	local desc
	if options.Desc then
		desc = Kit.Text(ctx, {
			Name = "Desc",
			Text = options.Desc,
			TextSize = Tokens.Type.Supporting.Size,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = 2,
			Parent = holder,
		}, "Muted", "Regular")
	end
	return { Frame = frame, Title = title, Desc = desc, Icon = icon, Holder = holder, Height = height }
end

-- Subtle row hover: the row background fades in. Ignored on touch. Returns nothing.
function Kit.RowHover(ctx, maid, button, frame)
	if ctx.Touch then
		return
	end
	frame = frame or button
	maid:Give(button.MouseEnter:Connect(function()
		ctx.Tween:To(frame, { BackgroundTransparency = 0.55 }, Tokens.Motion.Fast)
	end))
	maid:Give(button.MouseLeave:Connect(function()
		ctx.Tween:To(frame, { BackgroundTransparency = 1 }, Tokens.Motion.Base)
	end))
end

-- Icon-only button (28 px; 36 on touch). options: Icon, Tooltip (string|table), Callback, Name, Parent,
-- Position/AnchorPoint, LayoutOrder, Size. Returns the TextButton; Kit.IconOf(button) is the glyph/image.
-- The icon child of a Kit.IconButton (instances cannot carry custom fields in real Roblox).
function Kit.IconOf(button)
	return button and button:FindFirstChild("Icon") or nil
end

function Kit.IconButton(ctx, maid, options)
	local size = options.Size or (ctx.Touch and 36 or 28)
	local button = Create("TextButton", {
		Name = options.Name or "IconButton",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = options.AnchorPoint,
		Position = options.Position,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})
	ctx.Theme:Bind(button, "BackgroundColor3", "Surface3")
	Kit.Corner(button, Tokens.Radius.Sm)
	local icon = Icons.Create(ctx, {
		Icon = options.Icon,
		Size = options.IconSize or 16,
		Color = "Muted",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = button,
	})
	local function tint(token, bg)
		if icon then
			ctx.Tween:To(icon, { [Icons.ColorProperty(icon)] = ctx.Theme:Get(token) }, Tokens.Motion.Fast)
		end
		ctx.Tween:To(button, { BackgroundTransparency = bg }, Tokens.Motion.Fast)
	end
	if not ctx.Touch then
		maid:Give(button.MouseEnter:Connect(function()
			tint("Text", 0.4)
		end))
		maid:Give(button.MouseLeave:Connect(function()
			tint("Muted", 1)
		end))
	end
	maid:Give(button.MouseButton1Down:Connect(function()
		tint("Accent", 0)
	end))
	maid:Give(button.MouseButton1Up:Connect(function()
		tint("Text", ctx.Touch and 1 or 0.4)
	end))
	maid:Give(button.MouseButton1Click:Connect(function()
		Util.Call(options.Callback)
	end))
	if options.Tooltip and ctx.Tooltip then
		maid:Give(ctx.Tooltip:Attach(button, options.Tooltip))
	end
	return button
end

-- Small pill with text (badges, tags, notification counts). options: Text, Color token ("Accent"...), Parent, LayoutOrder.
function Kit.Badge(ctx, options)
	local label = Create("TextLabel", {
		Name = options.Name or "Badge",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Text = tostring(options.Text or ""),
		TextSize = Tokens.Type.Caption.Size,
		FontFace = ctx.Fonts.Bold,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = options.Parent,
	})
	ctx.Theme:Bind(label, "BackgroundColor3", options.Soft == false and (options.Color or "Accent") or "AccentSoft")
	ctx.Theme:Bind(label, "TextColor3", options.Soft == false and "AccentText" or (options.Color or "Accent"))
	Kit.Corner(label, Tokens.Radius.Pill)
	Kit.Padding(label, 7, 7, 0, 0)
	return label
end

-- A row of keycaps ("Ctrl", "R"...): compact keyboard-key look. keys: array of strings.
-- options: Size "Small"|"Normal", LayoutOrder, Parent is the first argument. Returns the holder Frame.
function Kit.Keycaps(ctx, parent, keys, options)
	options = options or {}
	local small = options.Size == "Small"
	local height = small and 16 or 22
	local holder = Create("Frame", {
		Name = "Keycaps",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Tokens.Space.Xs + 1),
		Parent = holder,
	})
	for index, key in ipairs(keys) do
		local cap = Create("TextLabel", {
			Name = "Key",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			Text = tostring(key),
			TextSize = small and 10 or 12,
			FontFace = ctx.Fonts.Bold,
			LayoutOrder = index,
			Parent = holder,
		})
		ctx.Theme:Bind(cap, "BackgroundColor3", "Surface3")
		ctx.Theme:Bind(cap, "TextColor3", "Text")
		Kit.Corner(cap, 4)
		Kit.Padding(cap, 6, 6, 0, 0)
		Kit.Stroke(ctx, cap, "StrokeHover")
	end
	return holder
end

Kit.Tokens = Tokens

return Kit
end

__defs["Core/Maid"] = function(require)
-- Maid: groups everything that must be cleaned up (connections, instances, functions, objects).
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
	if item ~= nil then
		self._tasks[#self._tasks + 1] = item
	end
	return item
end

local function cleanup(item)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		task.cancel(item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

-- Cleans up in reverse order (the last created is destroyed first).
function Maid:Clean()
	local items = self._tasks
	self._tasks = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanup, items[i])
		if not ok then
			warn("[MaUI] cleanup error: " .. tostring(err))
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
end

__defs["Core/Signal"] = function(require)
-- Signal: mini event system (no BindableEvent, no Roblox overhead).
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

local function compact(signal)
	local alive = {}
	for _, connection in ipairs(signal._handlers) do
		if connection.Connected then
			alive[#alive + 1] = connection
		end
	end
	signal._handlers = alive
	signal._dirty = false
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	self._signal = nil
	self._fn = nil
	if signal then
		signal._dirty = true
		-- only touch the list when no Fire is in progress
		if signal._depth == 0 then
			compact(signal)
		end
	end
end

function Signal.new()
	return setmetatable({ _handlers = {}, _depth = 0, _dirty = false }, Signal)
end

function Signal:Connect(fn)
	local connection = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	self._handlers[#self._handlers + 1] = connection
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	local handlers = self._handlers
	local count = #handlers
	if count == 0 then
		return
	end
	self._depth = self._depth + 1
	for i = 1, count do
		local connection = handlers[i]
		if connection and connection.Connected then
			local ok, err = pcall(connection._fn, ...)
			if not ok then
				warn("[MaUI] error in handler: " .. tostring(err))
			end
		end
	end
	self._depth = self._depth - 1
	if self._depth == 0 and self._dirty then
		compact(self)
	end
end

function Signal:Destroy()
	for _, connection in ipairs(self._handlers) do
		connection.Connected = false
		connection._signal = nil
		connection._fn = nil
	end
	self._handlers = {}
	self._dirty = false
end

return Signal
end

__defs["Core/Theme"] = function(require)
-- Theme: color tokens + binding registry.
-- Instances register on a token (or a function): a theme change
-- updates the registry without recreating anything.
local Signal = require("Core/Signal")
local Util = require("Core/Util")

local Theme = {}
Theme.__index = Theme

-- Token reference (every color used by the library comes from here):
--   Background  window / sidebar base          Surface   cards, header strips
--   Surface2    controls on a card             Surface3  hover / pressed / tracks
--   Stroke / StrokeHover   borders             Accent / AccentText   primary color and text on it
--   AccentSoft  tinted container (active nav item, badges)
--   Text / Muted / Faint   primary, secondary, supporting text
--   Success / Warning / Error / Info   status colors      Backdrop   dim layer behind modal UI
Theme.Presets = {
	Sakura = {
		Background = Color3.fromRGB(24, 14, 20),
		Surface = Color3.fromRGB(35, 20, 29),
		Surface2 = Color3.fromRGB(45, 27, 37),
		Surface3 = Color3.fromRGB(64, 40, 53),
		Stroke = Color3.fromRGB(58, 36, 48),
		StrokeHover = Color3.fromRGB(120, 78, 100),
		Accent = Color3.fromRGB(255, 158, 200),
		AccentText = Color3.fromRGB(40, 12, 26),
		AccentSoft = Color3.fromRGB(72, 36, 55),
		Text = Color3.fromRGB(248, 232, 240),
		Muted = Color3.fromRGB(150, 112, 132),
		Faint = Color3.fromRGB(104, 76, 92),
		Success = Color3.fromRGB(140, 224, 170),
		Warning = Color3.fromRGB(246, 190, 120),
		Error = Color3.fromRGB(242, 120, 130),
		Info = Color3.fromRGB(150, 190, 255),
		Backdrop = Color3.fromRGB(8, 4, 6),
	},
	Dark = {
		Background = Color3.fromRGB(18, 18, 22),
		Surface = Color3.fromRGB(26, 26, 32),
		Surface2 = Color3.fromRGB(33, 33, 41),
		Surface3 = Color3.fromRGB(48, 48, 58),
		Stroke = Color3.fromRGB(44, 44, 54),
		StrokeHover = Color3.fromRGB(86, 86, 108),
		Accent = Color3.fromRGB(110, 140, 255),
		AccentText = Color3.fromRGB(14, 16, 28),
		AccentSoft = Color3.fromRGB(36, 42, 76),
		Text = Color3.fromRGB(232, 232, 238),
		Muted = Color3.fromRGB(140, 140, 156),
		Faint = Color3.fromRGB(94, 94, 108),
		Success = Color3.fromRGB(120, 214, 150),
		Warning = Color3.fromRGB(240, 182, 110),
		Error = Color3.fromRGB(240, 110, 110),
		Info = Color3.fromRGB(130, 180, 255),
		Backdrop = Color3.fromRGB(4, 4, 8),
	},
	Light = {
		Background = Color3.fromRGB(244, 244, 248),
		Surface = Color3.fromRGB(255, 255, 255),
		Surface2 = Color3.fromRGB(238, 238, 244),
		Surface3 = Color3.fromRGB(214, 216, 226),
		Stroke = Color3.fromRGB(220, 222, 232),
		StrokeHover = Color3.fromRGB(160, 164, 190),
		Accent = Color3.fromRGB(70, 100, 235),
		AccentText = Color3.fromRGB(255, 255, 255),
		AccentSoft = Color3.fromRGB(222, 228, 252),
		Text = Color3.fromRGB(24, 24, 32),
		Muted = Color3.fromRGB(110, 112, 128),
		Faint = Color3.fromRGB(160, 162, 176),
		Success = Color3.fromRGB(40, 160, 90),
		Warning = Color3.fromRGB(200, 130, 30),
		Error = Color3.fromRGB(210, 60, 60),
		Info = Color3.fromRGB(50, 120, 220),
		Backdrop = Color3.fromRGB(60, 60, 70),
	},
}

function Theme.new(name)
	local self = setmetatable({}, Theme)
	self._themes = {}
	self._base = {} -- pristine copy of a theme edited through SetToken (restored by Set)
	for themeName, tokens in pairs(Theme.Presets) do
		self._themes[themeName] = Util.Copy(tokens)
	end
	-- weak keys: a destroyed instance is not kept referenced by the registry
	self._bindings = setmetatable({}, { __mode = "k" })
	self.Changed = Signal.new()
	self.Tokens = self._themes.Sakura
	self.Name = "Sakura"
	if name and not self:Set(name) then
		warn("[MaUI] unknown theme, falling back to Sakura: " .. tostring(name))
	end
	return self
end

-- Registers (or replaces) a theme. `tokens` may be partial: the rest comes from `base`.
function Theme:Register(name, tokens, base)
	local merged = Util.Copy(self._themes[base or "Sakura"] or Theme.Presets.Sakura)
	for token, value in pairs(tokens) do
		merged[token] = value
	end
	self._themes[name] = merged
	self._base[name] = nil
end

-- Names of every registered theme, sorted.
function Theme:List()
	local names = {}
	for name in pairs(self._themes) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Copy of the current theme's tokens.
function Theme:Has(name)
	return self._themes[name] ~= nil
end

function Theme:Snapshot()
	return Util.Copy(self.Tokens)
end

-- Unregisters a theme. Built-in presets and the active theme cannot be removed.
function Theme:Remove(name)
	if Theme.Presets[name] or name == self.Name or not self._themes[name] then
		return false
	end
	self._themes[name] = nil
	self._base[name] = nil
	return true
end

function Theme:Get(token)
	return self.Tokens[token]
end

local function resolve(self, source)
	if type(source) == "function" then
		return source(self)
	end
	return self.Tokens[source]
end

-- Binds `instance[property]` to a token ("Accent") or to a function(theme) -> value.
function Theme:Bind(instance, property, source)
	local properties = self._bindings[instance]
	if not properties then
		properties = {}
		self._bindings[instance] = properties
	end
	properties[property] = source
	local value = resolve(self, source)
	if value ~= nil then
		instance[property] = value
	end
	return instance
end

function Theme:Unbind(instance, property)
	local properties = self._bindings[instance]
	if properties then
		properties[property] = nil
	end
end

-- Releases the bindings of an instance and all its descendants (call before Destroy).
function Theme:Release(root)
	self._bindings[root] = nil
	for _, descendant in ipairs(root:GetDescendants()) do
		self._bindings[descendant] = nil
	end
end

-- Changes ONE token of the current theme and recolors only the bindings that can depend on it
-- (direct token bindings + function bindings). Nothing is recreated. Fires Changed.
-- Edits are live previews: Theme:Set(name) later restores the theme's pristine tokens.
function Theme:SetToken(token, color)
	if type(token) ~= "string" or self.Tokens[token] == nil or typeof(color) ~= "Color3" then
		return false
	end
	if self.Tokens[token] == color then
		return true
	end
	if not self._base[self.Name] then
		self._base[self.Name] = Util.Copy(self.Tokens)
	end
	self.Tokens[token] = color
	for instance, properties in pairs(self._bindings) do
		for property, source in pairs(properties) do
			if source == token or type(source) == "function" then
				local value = resolve(self, source)
				if value ~= nil then
					instance[property] = value
				end
			end
		end
	end
	self.Changed:Fire(self.Name)
	return true
end

function Theme:Set(name)
	local tokens = self._themes[name]
	if not tokens then
		return false
	end
	local base = self._base[name]
	if base then -- discard unsaved live edits
		for token, value in pairs(base) do
			tokens[token] = value
		end
		self._base[name] = nil
	end
	self.Name = name
	self.Tokens = tokens
	for instance, properties in pairs(self._bindings) do
		for property, source in pairs(properties) do
			local value = resolve(self, source)
			if value ~= nil then
				instance[property] = value
			end
		end
	end
	self.Changed:Fire(name)
	return true
end

return Theme
end

__defs["Core/Tokens"] = function(require)
-- Tokens: the design scales every component draws from. No component hardcodes a spacing,
-- radius, text size or duration: it picks a step from here, which is what keeps the whole
-- library visually consistent (and lets a single edit re-skin everything).
local Tokens = {}

-- Spacing scale (pixels). Pick by relationship, not by eye:
--   Xs  icon <-> text          Sm  items inside one control      Md  sibling controls
--   Lg  card padding           Xl  between cards                 Xxl between page areas
Tokens.Space = { Xs = 2, Sm = 4, Md = 8, Lg = 12, Xl = 16, Xxl = 24 }

Tokens.Radius = { Sm = 6, Md = 8, Lg = 12, Pill = 999 }

-- Typography hierarchy. Primary: page titles, key values. Secondary: section titles, labels,
-- control names. Supporting: descriptions, status, metadata. Caption: overlines, badges.
Tokens.Type = {
	Display = { Size = 24, Font = "Bold" },
	Primary = { Size = 17, Font = "Bold" },
	Secondary = { Size = 14, Font = "Medium" },
	Supporting = { Size = 12, Font = "Regular" },
	Caption = { Size = 11, Font = "Bold" },
}

-- Motion (seconds). Fast: hover/press feedback. Base: state changes. Slow: layout (expand, collapse).
Tokens.Motion = { Fast = 0.12, Base = 0.18, Slow = 0.28 }

-- Control heights: [touch] doubles as the minimum hit area.
Tokens.Height = {
	Compact = { Desktop = 26, Touch = 34 },
	Control = { Desktop = 34, Touch = 44 },
	Nav = { Desktop = 36, Touch = 44 },
}

return Tokens
end

__defs["Core/Tween"] = function(require)
-- Tween: TweenService wrapper with a TweenInfo cache and animation modes.
--   Full    : everything is animated
--   Reduced : durations halved, "decorative" effects are applied instantly
--   Off     : no tweens at all, properties are set directly
local TweenService = game:GetService("TweenService")

local Tween = {}
Tween.__index = Tween

Tween.Fast = 0.12
Tween.Normal = 0.2
Tween.Slow = 0.35

local MODES = { Full = true, Reduced = true, Off = true }

function Tween.new(mode)
	local self = setmetatable({ Mode = "Full", _infos = {} }, Tween)
	self:SetMode(mode or "Full")
	return self
end

function Tween:SetMode(mode)
	if not MODES[mode] then
		warn("[MaUI] unknown animation mode: " .. tostring(mode))
		return false
	end
	self.Mode = mode
	return true
end

-- Animates `props` on `instance`. Returns the Tween (or nil if applied instantly).
function Tween:To(instance, props, duration, style, direction, decorative)
	if not instance then
		return nil
	end
	duration = duration or Tween.Normal
	local mode = self.Mode
	if mode == "Off" or duration <= 0 or (decorative and mode == "Reduced") then
		for key, value in pairs(props) do
			instance[key] = value
		end
		return nil
	end
	if mode == "Reduced" then
		duration = duration * 0.5
	end
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local key = tostring(duration) .. "|" .. style.Name .. "|" .. direction.Name
	local info = self._infos[key]
	if not info then
		info = TweenInfo.new(duration, style, direction)
		self._infos[key] = info
	end
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

return Tween
end

__defs["Core/Util"] = function(require)
-- Util: pure helpers, no global state.
local Util = {}

-- Declarative instance creation. "Parent" is applied last
-- (avoids layout recalculations during construction).
function Util.Create(className, props, children)
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Normalizes an options table: shallow copy + default values.
-- A lone string is accepted and assigned to `stringKey` (default: "Name").
function Util.Options(input, defaults, stringKey)
	local options = {}
	if type(input) == "string" then
		options[stringKey or "Name"] = input
	elseif type(input) == "table" then
		for key, value in pairs(input) do
			options[key] = value
		end
	end
	if defaults then
		for key, value in pairs(defaults) do
			if options[key] == nil then
				options[key] = value
			end
		end
	end
	return options
end

-- Calls a user callback without ever breaking the lib.
function Util.Call(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[MaUI] error in callback: " .. tostring(err))
	end
end

function Util.Clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

-- Number of decimals in a step (0.5 -> 1, 0.25 -> 2, 1 -> 0).
function Util.Decimals(step)
	local decimals = 0
	local scaled = step
	while decimals < 8 and math.abs(scaled - math.floor(scaled + 0.5)) > 1e-7 do
		scaled = scaled * 10
		decimals = decimals + 1
	end
	return decimals
end

-- Snaps `value` to the `step` grid (relative to `low`), clamps and removes float noise.
function Util.Snap(value, low, high, step, decimals)
	if step and step > 0 then
		value = math.floor((value - low) / step + 0.5) * step + low
	end
	value = Util.Clamp(value, low, high)
	local factor = 10 ^ (decimals or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Util.FormatNumber(value, decimals)
	return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

-- Strips whitespace around a text.
function Util.Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 93784 -> "1d 2h", 3700 -> "1h 1m", 125 -> "2m 5s", 42 -> "42s"
function Util.FormatDuration(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	if minutes > 0 then
		return string.format("%dm %ds", minutes, rest)
	end
	return string.format("%ds", rest)
end

function Util.Copy(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local KEY_NAMES = {
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	Return = "Enter",
	Escape = "Esc",
	Backspace = "Bksp",
	Delete = "Del",
	Insert = "Ins",
	PageUp = "PgUp",
	PageDown = "PgDn",
}

function Util.KeyName(keyCode)
	if not keyCode then
		return "None"
	end
	return KEY_NAMES[keyCode.Name] or keyCode.Name
end

-- Accepts an Enum.KeyCode or its name ("RightShift"). Returns nil if invalid.
function Util.ParseKey(value)
	if type(value) == "string" then
		local ok, key = pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok then
			return key
		end
		return nil
	end
	if typeof(value) == "EnumItem" then
		return value
	end
	return nil
end

return Util
end

__defs["init"] = function(require)
-- MaUI: entry point. A Library instance owns ALL of its state
-- (theme, input, flags, windows, notifications): no shared global state.
--
--   local MaUI = loadstring(...)()
--   local ui = MaUI.new({ Theme = "Sakura", -- Sakura | Dark | Light | any registered theme ConfigFolder = "MyHub" })
--   local window = ui:CreateWindow({ Title = "My Project" })
--   local tab = window:AddTab("Main")
--   local section = tab:AddSection("Combat")
--   section:AddToggle({ Name = "Auto", Flag = "auto", Default = false, Callback = function(on) end })
local Env = require("Core/Env")
local Input = require("Core/Input")
local KeySystem = require("Components/KeySystem")
local Maid = require("Core/Maid")
local Icons = require("Core/Icons")
local Notifications = require("Components/Notifications")
local Overlay = require("Components/Overlay")
local Signal = require("Core/Signal")
local Theme = require("Core/Theme")
local Tokens = require("Core/Tokens")
local Tween = require("Core/Tween")
local Util = require("Core/Util")
local Window = require("Components/Window")

local HttpService = game:GetService("HttpService")

local MaUI = {}
MaUI.__index = MaUI
MaUI.Version = "0.2.0"
MaUI.Icons = Icons -- MaUI.Icons.Register("home", "rbxassetid://...")
MaUI.Tokens = Tokens

function MaUI.new(options)
	options = Util.Options(options, {
		Theme = "Sakura", -- Sakura | Dark | Light | any registered theme
		Animations = "Full", -- Full | Reduced | Off
		ConfigFolder = "MaUI",
		ConfigName = "default",
		AutoSave = false,
		FontFamily = "rbxasset://fonts/families/BuilderSans.json",
		Clock = os.time, -- time source (seconds): key expiry; overridable for tests
		OnKeyExpired = nil, -- function(key) called when the key expires
	})

	local self = setmetatable({}, MaUI)
	self.Options = options
	self.Maid = Maid.new()
	self.Flags = {}
	self.Windows = {}
	self.Overlays = {} -- floating overlay windows and islands, destroyed with the library
	self._destroyed = false
	self._loading = false
	self._savePending = false
	self.AutoSave = options.AutoSave
	self.ConfigFolder = options.ConfigFolder
	self.ConfigName = options.ConfigName
	self.Clock = options.Clock

	-- key state (filled in by ui:KeySystem)
	self.Key = nil -- { Value, ExpiresAt|nil, Expired, Info }
	self.KeyChanged = Signal.new()
	self.KeyExpired = Signal.new()
	self.KeyTick = Signal.new() -- once per second, only while an expiring key is displayed
	self._tickUsers = 0
	self._tickRunning = false
	self._expiryTimer = nil
	self._keySystem = nil
	self.Maid:Give(self.KeyChanged)
	self.Maid:Give(self.KeyExpired)
	self.Maid:Give(self.KeyTick)
	self.Maid:Give(function()
		if self._expiryTimer then
			pcall(task.cancel, self._expiryTimer)
			self._expiryTimer = nil
		end
		if self._keySystem then
			self._keySystem:Destroy()
			self._keySystem = nil
		end
	end)

	self.Theme = Theme.new(options.Theme)
	self.Input = Input.new()
	self.Tween = Tween.new(options.Animations)
	self.Maid:Give(self.Input)

	local touch = Env.IsTouch()
	local family = options.FontFamily
	self.Ctx = {
		Library = self,
		Theme = self.Theme,
		Input = self.Input,
		Tween = self.Tween,
		Touch = touch,
		Fonts = {
			Regular = Font.new(family, Enum.FontWeight.Regular),
			Medium = Font.new(family, Enum.FontWeight.Medium),
			Bold = Font.new(family, Enum.FontWeight.SemiBold),
		},
		-- touch-friendly sizes
		Metrics = touch
			and { Card = 50, CardTall = 64, Chip = 32, Title = 44, Tab = 40, Nav = 44, Control = 44, Compact = 34, Header = 60 }
			or { Card = 40, CardTall = 54, Chip = 26, Title = 38, Tab = 34, Nav = 36, Control = 34, Compact = 26, Header = 56 },
	}

	self.Ctx.Tokens = Tokens
	self._overlay = Overlay.new(self.Ctx)
	self.Maid:Give(self._overlay)
	self.Ctx.Popup = self._overlay.Popup
	self.Ctx.Tooltip = self._overlay.Tooltip

	-- a saved default theme wins over options.Theme
	local defaultTheme = self:GetDefaultTheme()
	if defaultTheme and not self.Theme:Has(defaultTheme) then
		self:LoadTheme(defaultTheme)
	elseif defaultTheme then
		self.Theme:Set(defaultTheme)
	end

	self._notifications = Notifications.new(self.Ctx)
	self.Maid:Give(self._notifications)
	return self
end

-- Windows / notifications ------------------------------------------------------

function MaUI:CreateWindow(options)
	local window = Window.new(self, options)
	self.Windows[#self.Windows + 1] = window
	if not (options and options.Settings == false) then
		window:AddSettings()
	end
	return window
end

-- Floating overlay window / Dynamic Island (see Components/OverlayWindow.lua, Components/DynamicIsland.lua).
function MaUI:CreateOverlayWindow(options)
	local OverlayWindow = require("Components/OverlayWindow")
	local overlay = OverlayWindow.new(self, options)
	self.Overlays[#self.Overlays + 1] = overlay
	return overlay
end

function MaUI:CreateIsland(options)
	local DynamicIsland = require("Components/DynamicIsland")
	local island = DynamicIsland.new(self, options)
	self.Overlays[#self.Overlays + 1] = island
	return island
end

function MaUI:Notify(options)
	return self._notifications:Push(options)
end

-- Key system -----------------------------------------------------------------------------

-- Shows the key entry window. See Components/KeySystem.lua.
function MaUI:KeySystem(options)
	if self._keySystem then
		self._keySystem:Destroy()
	end
	local gate = KeySystem.new(self, options)
	self._keySystem = gate
	return gate
end

-- Seconds remaining: nil = no key, math.huge = key without expiry.
function MaUI:GetKeyTimeLeft()
	local key = self.Key
	if not key then
		return nil
	end
	if key.Expired then
		return 0
	end
	if not key.ExpiresAt then
		return math.huge
	end
	return math.max(key.ExpiresAt - self.Clock(), 0)
end

-- A single scheduled task for expiry (re-checked on wake-up: os.time is only accurate to the second).
function MaUI:_ArmExpiry()
	if self._expiryTimer then
		pcall(task.cancel, self._expiryTimer)
		self._expiryTimer = nil
	end
	local key = self.Key
	if self._destroyed or not key or not key.ExpiresAt or key.Expired then
		return
	end
	local remaining = key.ExpiresAt - self.Clock()
	-- wake up within 24 h at most: avoids very long delays
	self._expiryTimer = task.delay(math.max(math.min(remaining, 86400), 0), function()
		self._expiryTimer = nil
		if self._destroyed or self.Key ~= key then
			return
		end
		if self.Clock() >= key.ExpiresAt then
			self:_OnKeyExpired()
		else
			self:_ArmExpiry()
		end
	end)
end

function MaUI:_SetKey(value, expiresAt, info)
	self.Key = { Value = value, ExpiresAt = expiresAt, Expired = false, Info = info }
	self:_ArmExpiry()
	self.KeyChanged:Fire(self.Key)
	self:_EnsureTick()
end

function MaUI:_OnKeyExpired()
	local key = self.Key
	if self._destroyed or not key or key.Expired then
		return
	end
	key.Expired = true
	self.KeyChanged:Fire(key)
	self.KeyExpired:Fire(key)
	self:Notify({ Title = "Key expired", Content = "Your key is no longer valid.", Type = "Warning", Duration = 6 })
	Util.Call(self.Options.OnKeyExpired, key)
end

-- Refresh rate for the remaining-time display: runs only if something is displaying it (AddKeyStatus)
-- AND a key is expiring. Otherwise: no task.
function MaUI:_AcquireKeyTick()
	self._tickUsers = self._tickUsers + 1
	self:_EnsureTick()
end

function MaUI:_ReleaseKeyTick()
	self._tickUsers = math.max(self._tickUsers - 1, 0)
end

function MaUI:_EnsureTick()
	if self._tickRunning or self._destroyed or self._tickUsers <= 0 then
		return
	end
	local key = self.Key
	if not key or not key.ExpiresAt or key.Expired then
		return
	end
	self._tickRunning = true
	local function step()
		local current = self.Key
		if self._destroyed or self._tickUsers <= 0 or not current or not current.ExpiresAt or current.Expired then
			self._tickRunning = false
			return
		end
		self.KeyTick:Fire(current)
		task.delay(1, step)
	end
	task.delay(1, step)
end

function MaUI:_RemoveWindow(window)
	for index, entry in ipairs(self.Windows) do
		if entry == window then
			table.remove(self.Windows, index)
			return
		end
	end
end

-- Theme / animations -------------------------------------------------------------

function MaUI:SetTheme(name)
	return self.Theme:Set(name)
end

function MaUI:RegisterTheme(name, tokens, base)
	self.Theme:Register(name, tokens, base)
end

function MaUI:SetAnimations(mode)
	return self.Tween:SetMode(mode)
end

-- Flags ----------------------------------------------------------------------------

function MaUI:_RegisterFlag(flag, element)
	if self.Flags[flag] ~= nil then
		error(string.format("[MaUI] the flag '%s' is already used by another element", tostring(flag)), 3)
	end
	self.Flags[flag] = element
end

function MaUI:_UnregisterFlag(flag, element)
	if self.Flags[flag] == element then
		self.Flags[flag] = nil
	end
end

-- Auto-save with debounce (0.5 s): a single timer, no matter how many changes.
function MaUI:_NotifyFlagChanged()
	if not self.AutoSave or self._loading or self._savePending or self._destroyed then
		return
	end
	self._savePending = true
	task.delay(0.5, function()
		self._savePending = false
		if not self._destroyed then
			self:SaveConfig(self.ConfigName)
		end
	end)
end

-- Configs ----------------------------------------------------------------------------

local function cleanName(name)
	name = tostring(name or ""):gsub("[^%w%-_ ]", "")
	if name == "" then
		return nil
	end
	return name
end

function MaUI:_ConfigPath(name)
	return self.ConfigFolder .. "/" .. name .. ".json"
end

-- Returns ok, error
function MaUI:SaveConfig(name)
	name = cleanName(name or self.ConfigName)
	if not name then
		return false, "invalid config name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local data = self:_CollectFlags()
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not okEncode then
		return false, tostring(encoded)
	end
	Env.EnsureFolder(self.ConfigFolder)
	local ok, err = Env.WriteFile(self:_ConfigPath(name), encoded)
	if ok then
		self.ConfigName = name
		return true
	end
	return false, tostring(err)
end

-- silent = true: applies the values without firing callbacks. Returns ok, error
function MaUI:LoadConfig(name, silent)
	name = cleanName(name or self.ConfigName)
	if not name then
		return false, "invalid config name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ConfigPath(name)
	if not Env.IsFile(path) then
		return false, "no config named " .. name
	end
	local okRead, content = Env.ReadFile(path)
	if not okRead then
		return false, tostring(content)
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not okDecode or type(data) ~= "table" then
		return false, "config unreadable (invalid JSON)"
	end
	self:_ApplyFlags(data, silent == true)
	self.ConfigName = name
	return true
end

-- Flag data of every persistent element: { [flag] = { Type, Value } }. Display-only elements are skipped.
function MaUI:_CollectFlags()
	local data = {}
	for flag, element in pairs(self.Flags) do
		if element.Persistent ~= false then
			data[flag] = { Type = element.Kind, Value = element:Serialize() }
		end
	end
	return data
end

function MaUI:_ApplyFlags(data, silent)
	self._loading = true -- avoids an auto-save while loading
	for flag, entry in pairs(data) do
		local element = self.Flags[flag]
		if element and type(entry) == "table" and entry.Type == element.Kind then
			local ok, err = pcall(element.Deserialize, element, entry.Value, silent)
			if not ok then
				warn("[MaUI] flag '" .. tostring(flag) .. "' not loaded: " .. tostring(err))
			end
		end
	end
	self._loading = false
end

function MaUI:DeleteConfig(name)
	name = cleanName(name)
	if not name then
		return false, "invalid config name"
	end
	local path = self:_ConfigPath(name)
	if not Env.IsFile(path) then
		return false, "no config named " .. name
	end
	local ok, err = Env.DeleteFile(path)
	if ok then
		return true
	end
	return false, tostring(err)
end

function MaUI:ListConfigs()
	local names = {}
	for _, path in ipairs(Env.ListFiles(self.ConfigFolder)) do
		path = tostring(path):gsub("\\", "/")
		local name = path:match("([^/]+)%.json$")
		-- direct children only: sub folders such as themes/ hold other kinds of files
		local parent = path:match("^(.*)/[^/]+$")
		if name and parent == self.ConfigFolder then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- Config management extras ----------------------------------------------------------------------

-- Renames a saved config. Returns ok, error
function MaUI:RenameConfig(old, new)
	old, new = cleanName(old), cleanName(new)
	if not old or not new then
		return false, "invalid config name"
	end
	if old == new then
		return true
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	if not Env.IsFile(self:_ConfigPath(old)) then
		return false, "no config named " .. old
	end
	if Env.IsFile(self:_ConfigPath(new)) then
		return false, "a config named " .. new .. " already exists"
	end
	local okRead, content = Env.ReadFile(self:_ConfigPath(old))
	if not okRead then
		return false, tostring(content)
	end
	local okWrite, err = Env.WriteFile(self:_ConfigPath(new), content)
	if not okWrite then
		return false, tostring(err)
	end
	Env.DeleteFile(self:_ConfigPath(old))
	if self.ConfigName == old then
		self.ConfigName = new
	end
	if self:GetAutoload() == old then
		self:SetAutoload(new)
	end
	return true
end

-- Restores every persistent element to its default value (silently). Returns how many were reset.
function MaUI:ResetConfig()
	local count = 0
	self._loading = true
	for _, element in pairs(self.Flags) do
		if element.Persistent ~= false and element.Reset then
			element:Reset(true)
			count = count + 1
		end
	end
	self._loading = false
	return count
end

function MaUI:_AutoloadPath()
	return self.ConfigFolder .. "/autoload.txt"
end

-- Marks a saved config to be applied by LoadAutoload(). nil clears it. Returns ok, error
function MaUI:SetAutoload(name)
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	if name == nil then
		if Env.IsFile(self:_AutoloadPath()) then
			Env.DeleteFile(self:_AutoloadPath())
		end
		return true
	end
	name = cleanName(name)
	if not name then
		return false, "invalid config name"
	end
	Env.EnsureFolder(self.ConfigFolder)
	return Env.WriteFile(self:_AutoloadPath(), name)
end

function MaUI:GetAutoload()
	if not Env.HasFS() or not Env.IsFile(self:_AutoloadPath()) then
		return nil
	end
	local ok, content = Env.ReadFile(self:_AutoloadPath())
	return ok and cleanName(content) or nil
end

-- Applies the autoload config if one is set (call it after your UI is built). Returns ok, error
function MaUI:LoadAutoload(silent)
	local name = self:GetAutoload()
	if not name then
		return false, "no autoload configured"
	end
	return self:LoadConfig(name, silent)
end

local EXPORT_PREFIX = "MAUI1:"

-- A shareable text code of the current flag values.
function MaUI:ExportConfig()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(self:_CollectFlags())
	end)
	if not ok then
		return nil, tostring(encoded)
	end
	return EXPORT_PREFIX .. encoded
end

-- Applies a code produced by ExportConfig. Invalid codes are rejected without changing anything.
function MaUI:ImportConfig(code, silent)
	if type(code) ~= "string" or code:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
		return false, "not a MaUI config code"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(code:sub(#EXPORT_PREFIX + 1))
	end)
	if not ok or type(data) ~= "table" then
		return false, "config code is corrupted"
	end
	self:_ApplyFlags(data, silent == true)
	return true
end

-- Custom themes -----------------------------------------------------------------------------------

function MaUI:_ThemeFolder()
	return self.ConfigFolder .. "/themes"
end

local function toHex(color)
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function fromHex(text)
	if type(text) ~= "string" or not text:match("^%x%x%x%x%x%x$") then
		return nil
	end
	return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

-- Saves the CURRENT theme tokens (including live edits) under `name`. Returns ok, error
function MaUI:SaveTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local tokens = {}
	for token, color in pairs(self.Theme:Snapshot()) do
		tokens[token] = toHex(color)
	end
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(tokens)
	end)
	if not okEncode then
		return false, tostring(encoded)
	end
	Env.EnsureFolder(self.ConfigFolder)
	Env.EnsureFolder(self:_ThemeFolder())
	local ok, err = Env.WriteFile(self:_ThemeFolder() .. "/" .. name .. ".json", encoded)
	if not ok then
		return false, tostring(err)
	end
	-- register + select, so the saved theme is immediately a normal theme
	local colors = {}
	for token, hex in pairs(tokens) do
		colors[token] = fromHex(hex)
	end
	self.Theme:Register(name, colors, "Sakura")
	self.Theme:Set(name)
	return true
end

-- Loads a saved theme and applies it. Returns ok, error
function MaUI:LoadTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ThemeFolder() .. "/" .. name .. ".json"
	if not Env.IsFile(path) then
		return false, "no theme named " .. name
	end
	local okRead, content = Env.ReadFile(path)
	if not okRead then
		return false, tostring(content)
	end
	local okDecode, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not okDecode or type(data) ~= "table" then
		return false, "theme unreadable (invalid JSON)"
	end
	local colors = {}
	for token, hex in pairs(data) do
		local color = fromHex(hex)
		if color then
			colors[token] = color
		end
	end
	self.Theme:Register(name, colors, "Sakura")
	self.Theme:Set(name)
	return true
end

function MaUI:DeleteTheme(name)
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	local path = self:_ThemeFolder() .. "/" .. name .. ".json"
	if not Env.HasFS() or not Env.IsFile(path) then
		return false, "no theme named " .. tostring(name)
	end
	Env.DeleteFile(path)
	self.Theme:Remove(name)
	if self:GetDefaultTheme() == name then
		self:SetDefaultTheme(nil)
	end
	return true
end

-- Names of the saved custom themes.
function MaUI:ListThemes()
	local names = {}
	if Env.HasFS() then
		for _, path in ipairs(Env.ListFiles(self:_ThemeFolder())) do
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- The default theme is applied when the library is created. nil clears it (also accepts built-in theme names).
function MaUI:SetDefaultTheme(name)
	if not Env.HasFS() then
		return false, "file API unavailable"
	end
	local path = self:_ThemeFolder() .. "/_default.txt"
	if name == nil then
		if Env.IsFile(path) then
			Env.DeleteFile(path)
		end
		return true
	end
	name = cleanName(name)
	if not name then
		return false, "invalid theme name"
	end
	Env.EnsureFolder(self.ConfigFolder)
	Env.EnsureFolder(self:_ThemeFolder())
	return Env.WriteFile(path, name)
end

function MaUI:GetDefaultTheme()
	local path = self:_ThemeFolder() .. "/_default.txt"
	if not Env.HasFS() or not Env.IsFile(path) then
		return nil
	end
	local ok, content = Env.ReadFile(path)
	return ok and cleanName(content) or nil
end

-- Cleanup ---------------------------------------------------------------------------

function MaUI:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self.Windows, 1, -1 do
		self.Windows[index]:Destroy()
	end
	for index = #self.Overlays, 1, -1 do
		self.Overlays[index]:Destroy()
	end
	self.Maid:Clean()
	self.Flags = {}
end

return MaUI
end

return __require("init")
