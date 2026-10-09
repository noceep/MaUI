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
