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
