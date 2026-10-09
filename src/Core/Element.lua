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
