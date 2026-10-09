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
