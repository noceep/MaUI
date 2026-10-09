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
