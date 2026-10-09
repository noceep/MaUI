-- Minimal mock of the Roblox API: enough to run MaUI headless (LuaJIT / Lua 5.1).
-- This is NOT a renderer: it computes no layout and draws nothing. It validates logic,
-- event wiring, lifecycle and cleanup, not appearance.
local unpack = table.unpack or unpack
local realType = type

M = {
	warnings = {},
	threadErrors = {},
	tweenCount = 0,
	instanceCount = 0,
	thumbnailRequests = 0,
	now = 0,
	queue = {},
	files = {},
	folders = {},
	writes = 0,
	hook = nil, -- line hook installed on every new coroutine (coverage)
}

function typeof(value)
	if realType(value) == "table" then
		local tag = rawget(value, "__rbx")
		if tag then
			return tag
		end
	elseif realType(value) == "thread" then
		return "thread"
	end
	return realType(value)
end

function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	M.warnings[#M.warnings + 1] = table.concat(parts, " ")
end

-- task -------------------------------------------------------------------------------
task = {}
-- Like Roblox: task.spawn accepts a function (new thread) or a suspended thread (resume it).
-- An error inside a thread is recorded in M.threadErrors instead of being lost.
function task.spawn(fn, ...)
	local co = fn
	if realType(fn) ~= "thread" then
		co = coroutine.create(fn)
		if M.hook then
			debug.sethook(co, M.hook, "l")
		end
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		M.threadErrors[#M.threadErrors + 1] = tostring(err)
	end
	return co
end
function task.defer(fn, ...)
	return task.spawn(fn, ...)
end
function task.delay(seconds, fn, ...)
	local entry = { __rbx = "thread", at = M.now + seconds, fn = fn, args = { ... }, cancelled = false }
	M.queue[#M.queue + 1] = entry
	return entry
end
function task.cancel(entry)
	if realType(entry) == "table" then
		entry.cancelled = true
	end
end
function task.wait(seconds)
	M.now = M.now + (seconds or 0)
	return seconds or 0
end
-- advances the clock and runs the delayed callbacks that are due
function M.advance(seconds)
	local target = M.now + seconds
	while true do
		local nextEntry, nextIndex
		for i, entry in ipairs(M.queue) do
			if not entry.cancelled and entry.at <= target and (not nextEntry or entry.at < nextEntry.at) then
				nextEntry, nextIndex = entry, i
			end
		end
		if not nextEntry then
			break
		end
		table.remove(M.queue, nextIndex)
		M.now = nextEntry.at
		nextEntry.fn(unpack(nextEntry.args))
	end
	M.now = target
end

-- Signaux ----------------------------------------------------------------------------
local function newSignal()
	local signal = { __rbx = "RBXScriptSignal", _list = {} }
	function signal:Connect(fn)
		local connection = { __rbx = "RBXScriptConnection", Connected = true, fn = fn }
		function connection:Disconnect()
			self.Connected = false
		end
		self._list[#self._list + 1] = connection
		return connection
	end
	function signal:Fire(...)
		local snapshot = {}
		for i, c in ipairs(self._list) do
			snapshot[i] = c
		end
		for _, c in ipairs(snapshot) do
			if c.Connected then
				c.fn(...)
			end
		end
	end
	function signal:ActiveCount()
		local n = 0
		for _, c in ipairs(self._list) do
			if c.Connected then
				n = n + 1
			end
		end
		return n
	end
	return signal
end

-- Types valeur -------------------------------------------------------------------------
local vec2 = {}
vec2.__index = vec2
vec2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
vec2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
vec2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2 = { new = function(x, y) return setmetatable({ __rbx = "Vector2", X = x or 0, Y = y or 0 }, vec2) end }
Vector3 = { new = function(x, y, z) return { __rbx = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 } end }
UDim = { new = function(s, o) return { __rbx = "UDim", Scale = s or 0, Offset = o or 0 } end }
UDim2 = {
	new = function(xs, xo, ys, yo)
		return { __rbx = "UDim2", X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
	end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
}
local color3 = {}
color3.__index = color3
local function mkColor(r, g, b)
	return setmetatable({ __rbx = "Color3", R = r, G = g, B = b }, color3)
end
function color3:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local d = max - min
	local h = 0
	if d > 0 then
		if max == r then h = ((g - b) / d) % 6 elseif max == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, max == 0 and 0 or d / max, max
end
function color3:Lerp(other, t)
	return mkColor(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
end
function color3:ToHex()
	return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
end
color3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = mkColor,
	fromRGB = function(r, g, b) return mkColor(r / 255, g / 255, b / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		i = i % 6
		local r, g, b
		if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
		elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
		return mkColor(r, g, b)
	end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return mkColor(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}
function M.sameColor(a, b)
	return a ~= nil and b ~= nil and a.R == b.R and a.G == b.G and a.B == b.B
end
Rect = { new = function(a, b, c, d) return { __rbx = "Rect", a, b, c, d } end }
Font = { new = function(family, weight) return { __rbx = "Font", Family = family, Weight = weight } end }
TweenInfo = { new = function(d, s, dir) return { __rbx = "TweenInfo", Time = d, Style = s, Dir = dir } end }

Enum = setmetatable({}, {
	__index = function(root, enumName)
		local enumType = setmetatable({}, {
			__index = function(self, itemName)
				local item = { __rbx = "EnumItem", Name = itemName, EnumType = enumName }
				rawset(self, itemName, item)
				return item
			end,
		})
		rawset(root, enumName, enumType)
		return enumType
	end,
})

-- Instances ----------------------------------------------------------------------------
local EVENTS = {
	MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true,
	InputChanged = true, Destroying = true, ChildAdded = true, ChildRemoved = true,
	FocusLost = true, Focused = true,
}

local methods = {}
local function detach(instance)
	local data = rawget(instance, "_data")
	if data.parent then
		local siblings = rawget(data.parent, "_data").children
		for i, child in ipairs(siblings) do
			if child == instance then
				table.remove(siblings, i)
				break
			end
		end
	end
	data.parent = nil
end

function methods.Destroy(self)
	local data = rawget(self, "_data")
	if data.destroyed then
		return
	end
	data.destroyed = true
	local snapshot = {}
	for i, child in ipairs(data.children) do
		snapshot[i] = child
	end
	for _, child in ipairs(snapshot) do
		child:Destroy()
	end
	detach(self)
end
function methods.GetChildren(self)
	local out = {}
	for i, child in ipairs(rawget(self, "_data").children) do
		out[i] = child
	end
	return out
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in ipairs(rawget(node, "_data").children) do
			out[#out + 1] = child
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(recursive and methods.GetDescendants(self) or rawget(self, "_data").children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
methods.WaitForChild = methods.FindFirstChild
function methods.IsDescendantOf(self, ancestor)
	local node = rawget(self, "_data").parent
	while node do
		if node == ancestor then
			return true
		end
		node = rawget(node, "_data").parent
	end
	return false
end
local GUI_OBJECTS = { Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true }
function methods.IsA(self, className)
	if className == "GuiObject" then
		return GUI_OBJECTS[self.ClassName] == true
	end
	return self.ClassName == className
end
function methods.GetPropertyChangedSignal(self, name)
	local data = rawget(self, "_data")
	local key = "prop:" .. name
	data.signals[key] = data.signals[key] or newSignal()
	return data.signals[key]
end

local instanceMeta = {
	__index = function(self, key)
		if methods[key] then
			return methods[key]
		end
		local data = rawget(self, "_data")
		if key == "Parent" then
			return data.parent
		elseif EVENTS[key] then
			data.signals[key] = data.signals[key] or newSignal()
			return data.signals[key]
		elseif data.props[key] ~= nil then
			return data.props[key]
		elseif key == "AbsoluteSize" then
			return Vector2.new(100, 30)
		elseif key == "AbsolutePosition" then
			return Vector2.new(0, 0)
		end
		return nil
	end,
	__newindex = function(self, key, value)
		if key == "Parent" then
			local data = rawget(self, "_data")
			detach(self)
			if value then
				data.parent = value
				local siblings = rawget(value, "_data").children
				siblings[#siblings + 1] = self
			end
		else
			-- properties live in data.props (not as raw keys) so EVERY assignment reaches this handler
			local data = rawget(self, "_data")
			local old = data.props[key]
			data.props[key] = value
			local signals = data.signals
			local signal = signals["prop:" .. key]
			if signal and old ~= value then
				signal:Fire()
			end
		end
	end,
}

Instance = {}
function Instance.new(className)
	M.instanceCount = M.instanceCount + 1
	local instance = setmetatable({
		__rbx = "Instance",
		ClassName = className,
		_data = { children = {}, signals = {}, props = { Name = className }, parent = nil, destroyed = false },
	}, instanceMeta)
	if className == "ScreenGui" then
		instance.AbsoluteSize = Vector2.new(1280, 720)
	end
	return instance
end
function M.isDestroyed(instance)
	return rawget(instance, "_data").destroyed
end
-- Finds a descendant by name (first match)
function M.find(root, name)
	return root:FindFirstChild(name, true)
end

-- JSON minimal --------------------------------------------------------------------------
local function encode(value)
	local kind = realType(value)
	if kind == "table" then
		if #value > 0 then
			local parts = {}
			for i, v in ipairs(value) do
				parts[i] = encode(v)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for k in pairs(value) do
			keys[#keys + 1] = k
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			parts[#parts + 1] = string.format("%q", k) .. ":" .. encode(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return string.format("%q", value):gsub("\\\n", "\\n")
	end
	return tostring(value)
end

local function decode(text)
	local pos = 1
	local function skip()
		pos = text:find("%S", pos) or #text + 1
	end
	local parseValue
	local function parseString()
		if text:sub(pos, pos) ~= '"' then
			error("invalid JSON: string expected at position " .. pos)
		end
		local close = pos + 1
		while text:sub(close, close) ~= '"' do
			if close > #text then
				error("invalid JSON: unterminated string")
			end
			if text:sub(close, close) == "\\" then
				close = close + 1
			end
			close = close + 1
		end
		local raw = text:sub(pos + 1, close - 1)
		pos = close + 1
		return (raw:gsub("\\n", "\n"):gsub('\\"', '"'):gsub("\\\\", "\\"))
	end
	function parseValue()
		skip()
		local c = text:sub(pos, pos)
		if c == "{" then
			local out = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "}" then
				pos = pos + 1
				return out
			end
			while true do
				skip()
				local key = parseString()
				skip()
				pos = pos + 1 -- ':'
				out[key] = parseValue()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "}" then
					return out
				end
			end
		elseif c == "[" then
			local out = {}
			pos = pos + 1
			skip()
			if text:sub(pos, pos) == "]" then
				pos = pos + 1
				return out
			end
			while true do
				out[#out + 1] = parseValue()
				skip()
				local sep = text:sub(pos, pos)
				pos = pos + 1
				if sep == "]" then
					return out
				end
			end
		elseif c == '"' then
			return parseString()
		elseif text:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif text:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		elseif text:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		end
		local number = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
		if not number then
			error("invalid JSON at position " .. pos)
		end
		pos = pos + #number
		return tonumber(number)
	end
	return parseValue()
end

-- Services -------------------------------------------------------------------------------
local services = {}

services.TweenService = {
	Create = function(_, instance, info, props)
		M.tweenCount = M.tweenCount + 1
		return {
			Play = function()
				for k, v in pairs(props) do
					instance[k] = v
				end
			end,
			Cancel = function() end,
		}
	end,
}

services.UserInputService = {
	InputBegan = newSignal(),
	InputChanged = newSignal(),
	InputEnded = newSignal(),
	TouchEnabled = false,
	KeyboardEnabled = true,
	GetMouseLocation = function() return Vector2.new(0, 0) end,
	GetFocusedTextBox = function() return nil end,
}
services.HttpService = {
	JSONEncode = function(_, value) return (encode(value)) end,
	JSONDecode = function(_, text) return decode(text) end,
}
services.GuiService = { GetGuiInset = function() return Vector2.new(0, 36) end }
services.CoreGui = Instance.new("CoreGui")
M.hui = Instance.new("HiddenUI")
services.Players = {
	LocalPlayer = {
		Name = "TestUser",
		DisplayName = "Test Display",
		UserId = 12345,
		WaitForChild = function() return Instance.new("PlayerGui") end,
	},
	GetPlayers = function() return { 1, 2, 3 } end,
	GetUserThumbnailAsync = function(_, userId)
		M.thumbnailRequests = M.thumbnailRequests + 1
		return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId), true
	end,
}

game = {
	GetService = function(_, name)
		return services[name] or error("service not mocked: " .. tostring(name))
	end,
}
workspace = { CurrentCamera = { ViewportSize = Vector2.new(1280, 720) } }
M.UIS = services.UserInputService

-- API "executor" (gethui + fichiers) --------------------------------------------------------
function gethui()
	return M.hui
end
function writefile(path, data)
	M.files[path] = data
	M.writes = M.writes + 1
end
function readfile(path)
	if M.files[path] == nil then
		error("fichier introuvable : " .. path)
	end
	return M.files[path]
end
function isfile(path)
	return M.files[path] ~= nil
end
function isfolder(path)
	return M.folders[path] == true
end
function makefolder(path)
	M.folders[path] = true
end
function delfile(path)
	M.files[path] = nil
end
function listfiles(folder)
	local out = {}
	for path in pairs(M.files) do
		if path:sub(1, #folder + 1) == folder .. "/" then
			out[#out + 1] = path
		end
	end
	table.sort(out)
	return out
end

-- Simulated input objects --------------------------------------------------------------------
function M.input(kind, fields)
	local input = { UserInputType = Enum.UserInputType[kind], KeyCode = Enum.KeyCode.Unknown }
	for k, v in pairs(fields or {}) do
		input[k] = v
	end
	return input
end
function M.press(keyName, processed)
	M.UIS.InputBegan:Fire(M.input("Keyboard", { KeyCode = Enum.KeyCode[keyName] }), processed or false)
end
