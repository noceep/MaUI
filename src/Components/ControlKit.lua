-- ControlKit: tiny helpers shared by the control components (Toggle, Slider, Button, Keybind,
-- DataRow, Metric...). Pointer-state tracking, disabled dimming and tooltip attachment live here
-- so every control reacts to hover / pressed / disabled in exactly the same way.
local Icons = require("Core/Icons")
local Tokens = require("Core/Tokens")

local CK = {}

local DISABLED_ALPHA = 0.5

-- Tracks hover/pressed on `target` into `state._hover` / `state._pressed` and calls onChange()
-- after every real change. Hover is ignored on touch devices (no pointer to hover with).
function CK.Track(ctx, maid, target, state, onChange)
	local function apply(hover, pressed)
		if state._hover ~= hover or state._pressed ~= pressed then
			state._hover, state._pressed = hover, pressed
			onChange()
		end
	end
	state._hover, state._pressed = false, false
	if not ctx.Touch then
		maid:Give(target.MouseEnter:Connect(function()
			apply(true, state._pressed)
		end))
	end
	maid:Give(target.MouseLeave:Connect(function()
		apply(false, false)
	end))
	maid:Give(target.MouseButton1Down:Connect(function()
		apply(state._hover, true)
	end))
	maid:Give(target.MouseButton1Up:Connect(function()
		apply(state._hover, false)
	end))
end

-- Attaches a tooltip (string | { Text, Desc, Key, Delay }) and gives the handle to the maid.
function CK.Tooltip(ctx, maid, instance, tip)
	if tip == nil or tip == false or not ctx.Tooltip then
		return nil
	end
	local handle = ctx.Tooltip:Attach(instance, tip)
	maid:Give(handle)
	return handle
end

function CK.TransparencyProperty(instance)
	if instance:IsA("ImageLabel") then
		return "ImageTransparency"
	end
	return "TextTransparency"
end

-- Dims (or restores) the texts and the icon of a Kit.Row.
function CK.Dim(ctx, row, disabled, duration)
	local alpha = disabled and DISABLED_ALPHA or 0
	ctx.Tween:To(row.Title, { TextTransparency = alpha }, duration)
	if row.Desc then
		ctx.Tween:To(row.Desc, { TextTransparency = alpha }, duration)
	end
	if row.Icon then
		ctx.Tween:To(row.Icon, { [CK.TransparencyProperty(row.Icon)] = alpha }, duration)
	end
end

-- Row background feedback: transparent at rest, fades in on hover and a bit more while pressed.
function CK.RowBackground(ctx, frame, state, disabled, duration)
	local alpha = 1
	if not disabled then
		if state._pressed then
			alpha = 0.35
		elseif state._hover then
			alpha = 0.55
		end
	end
	ctx.Tween:To(frame, { BackgroundTransparency = alpha }, duration)
end

CK.Motion = Tokens.Motion
CK.Icons = Icons

return CK
