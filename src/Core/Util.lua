-- Util: pure helpers, no global state.
local Util = {}

-- Declarative instance creation. "Parent" is applied last
-- (avoids layout recalculations during construction).
function Util.Create(className, props, children)
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Normalizes an options table: shallow copy + default values.
-- A lone string is accepted and assigned to `stringKey` (default: "Name").
function Util.Options(input, defaults, stringKey)
	local options = {}
	if type(input) == "string" then
		options[stringKey or "Name"] = input
	elseif type(input) == "table" then
		for key, value in pairs(input) do
			options[key] = value
		end
	end
	if defaults then
		for key, value in pairs(defaults) do
			if options[key] == nil then
				options[key] = value
			end
		end
	end
	return options
end

-- Calls a user callback without ever breaking the lib.
function Util.Call(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[MaUI] error in callback: " .. tostring(err))
	end
end

function Util.Clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

-- Number of decimals in a step (0.5 -> 1, 0.25 -> 2, 1 -> 0).
function Util.Decimals(step)
	local decimals = 0
	local scaled = step
	while decimals < 8 and math.abs(scaled - math.floor(scaled + 0.5)) > 1e-7 do
		scaled = scaled * 10
		decimals = decimals + 1
	end
	return decimals
end

-- Snaps `value` to the `step` grid (relative to `low`), clamps and removes float noise.
function Util.Snap(value, low, high, step, decimals)
	if step and step > 0 then
		value = math.floor((value - low) / step + 0.5) * step + low
	end
	value = Util.Clamp(value, low, high)
	local factor = 10 ^ (decimals or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Util.FormatNumber(value, decimals)
	return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

-- Strips whitespace around a text.
function Util.Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 93784 -> "1d 2h", 3700 -> "1h 1m", 125 -> "2m 5s", 42 -> "42s"
function Util.FormatDuration(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local rest = seconds % 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	if minutes > 0 then
		return string.format("%dm %ds", minutes, rest)
	end
	return string.format("%ds", rest)
end

function Util.Copy(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

local KEY_NAMES = {
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	Return = "Enter",
	Escape = "Esc",
	Backspace = "Bksp",
	Delete = "Del",
	Insert = "Ins",
	PageUp = "PgUp",
	PageDown = "PgDn",
}

function Util.KeyName(keyCode)
	if not keyCode then
		return "None"
	end
	return KEY_NAMES[keyCode.Name] or keyCode.Name
end

-- Accepts an Enum.KeyCode or its name ("RightShift"). Returns nil if invalid.
function Util.ParseKey(value)
	if type(value) == "string" then
		local ok, key = pcall(function()
			return Enum.KeyCode[value]
		end)
		if ok then
			return key
		end
		return nil
	end
	if typeof(value) == "EnumItem" then
		return value
	end
	return nil
end

return Util
