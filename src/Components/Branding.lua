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
