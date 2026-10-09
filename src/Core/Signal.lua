-- Signal: mini event system (no BindableEvent, no Roblox overhead).
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

local function compact(signal)
	local alive = {}
	for _, connection in ipairs(signal._handlers) do
		if connection.Connected then
			alive[#alive + 1] = connection
		end
	end
	signal._handlers = alive
	signal._dirty = false
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local signal = self._signal
	self._signal = nil
	self._fn = nil
	if signal then
		signal._dirty = true
		-- only touch the list when no Fire is in progress
		if signal._depth == 0 then
			compact(signal)
		end
	end
end

function Signal.new()
	return setmetatable({ _handlers = {}, _depth = 0, _dirty = false }, Signal)
end

function Signal:Connect(fn)
	local connection = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	self._handlers[#self._handlers + 1] = connection
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	local handlers = self._handlers
	local count = #handlers
	if count == 0 then
		return
	end
	self._depth = self._depth + 1
	for i = 1, count do
		local connection = handlers[i]
		if connection and connection.Connected then
			local ok, err = pcall(connection._fn, ...)
			if not ok then
				warn("[MaUI] error in handler: " .. tostring(err))
			end
		end
	end
	self._depth = self._depth - 1
	if self._depth == 0 and self._dirty then
		compact(self)
	end
end

function Signal:Destroy()
	for _, connection in ipairs(self._handlers) do
		connection.Connected = false
		connection._signal = nil
		connection._fn = nil
	end
	self._handlers = {}
	self._dirty = false
end

return Signal
