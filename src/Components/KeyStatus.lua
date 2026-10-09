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
