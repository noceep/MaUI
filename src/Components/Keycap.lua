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
