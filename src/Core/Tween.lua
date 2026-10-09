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
