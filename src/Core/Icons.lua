-- Icons: one registry for every icon in the library.
-- An icon is referenced by name ("home"), by asset ("rbxassetid://123") or not at all.
-- Built-in names resolve to a compact text glyph so the library is usable with ZERO asset
-- dependencies; call Icons.Register("home", "rbxassetid://<id>") (or MaUI.Icons.Register) to swap
-- in a real icon set, and every component that uses "home" picks it up.
local Icons = {}

local glyphs = {
	home = "⌂", settings = "⚙", search = "⌕", close = "✕", check = "✓", plus = "+", minus = "–",
	chevron = "▾", chevronRight = "▸", info = "i", warning = "!", error = "✕", success = "✓",
	star = "★", dot = "●", user = "☺", copy = "⧉", refresh = "⟳", folder = "▤", palette = "◐",
	bolt = "ϟ", eye = "◉", eyeOff = "○", expand = "⤢", shrink = "⤡", play = "▶", loading = "◜",
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
