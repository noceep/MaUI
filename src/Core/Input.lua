-- Input: SINGLE entry point for keyboard/mouse/touch input across the whole lib.
--  * 1 permanent listener (InputBegan) for keybinds -> KeyCode table -> handlers (O(1)).
--  * InputChanged / InputEnded listeners only exist DURING a capture (slider drag,
--    window move/resize). At rest, no cost per mouse movement.
--  * Only one active capture at a time: only the active element receives movements.
local Util = require("Core/Util")

local UserInputService = game:GetService("UserInputService")

local Input = {}
Input.__index = Input

local function isMouseButton(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
end

function Input.new()
	local self = setmetatable({}, Input)
	self._binds = {} -- [KeyCode] = { handle, ... }
	self._capture = nil
	self._keyCapture = nil
	self._began = UserInputService.InputBegan:Connect(function(input, processed)
		self:_onBegan(input, processed)
	end)
	return self
end

-- Keybinds ----------------------------------------------------------------------

function Input:_onBegan(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- During a "rebind", the key is swallowed: no other bind fires.
	local keyCapture = self._keyCapture
	if keyCapture then
		self._keyCapture = nil
		Util.Call(keyCapture, input.KeyCode)
		return
	end
	if processed then
		return
	end
	local list = self._binds[input.KeyCode]
	if not list then
		return
	end
	-- copy: a callback can add/remove binds
	local snapshot = {}
	for i = 1, #list do
		snapshot[i] = list[i]
	end
	for i = 1, #snapshot do
		local handle = snapshot[i]
		if handle.Connected then
			Util.Call(handle.Callback, input.KeyCode)
		end
	end
end

local function removeFrom(list, handle)
	for i = 1, #list do
		if list[i] == handle then
			table.remove(list, i)
			return
		end
	end
end

-- Registers a keybind. Returns a handle { SetKey(keyCode|nil), Disconnect() }.
function Input:BindKey(keyCode, callback)
	local owner = self
	local handle = { Callback = callback, KeyCode = nil, Connected = true }

	function handle:SetKey(newKey)
		if self.KeyCode then
			local list = owner._binds[self.KeyCode]
			if list then
				removeFrom(list, self)
				if #list == 0 then
					owner._binds[self.KeyCode] = nil
				end
			end
		end
		self.KeyCode = newKey
		if newKey then
			local list = owner._binds[newKey]
			if not list then
				list = {}
				owner._binds[newKey] = list
			end
			list[#list + 1] = self
		end
	end

	function handle:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		self:SetKey(nil)
	end

	handle:SetKey(keyCode)
	return handle
end

-- Waits for the next key pressed. callback(keyCode); callback(nil) if the capture is cancelled.
function Input:CaptureKey(callback)
	self:CancelKeyCapture()
	self._keyCapture = callback
end

function Input:CancelKeyCapture()
	local previous = self._keyCapture
	if previous then
		self._keyCapture = nil
		Util.Call(previous, nil)
	end
end

-- Pointer captures (drag) ---------------------------------------------------

-- Starts a capture from the InputObject `startInput` (click / touch).
--   onMove(inputObject) : on every movement of the same pointer
--   onEnd()             : on release (or if another capture takes over)
function Input:Capture(owner, startInput, onMove, onEnd)
	self:Release()
	local capture = { Owner = owner, Start = startInput, OnEnd = onEnd }
	self._capture = capture

	capture.Changed = UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or (kind == Enum.UserInputType.Touch and input == startInput) then
			Util.Call(onMove, input)
		end
	end)

	capture.Ended = UserInputService.InputEnded:Connect(function(input)
		local same = input == startInput
			or (isMouseButton(startInput) and input.UserInputType == startInput.UserInputType)
		if same then
			self:Release(owner)
		end
	end)
end

-- Ends the current capture. If `owner` is given, only that owner can end it.
function Input:Release(owner)
	local capture = self._capture
	if not capture then
		return
	end
	if owner ~= nil and capture.Owner ~= owner then
		return
	end
	self._capture = nil
	capture.Changed:Disconnect()
	capture.Ended:Disconnect()
	Util.Call(capture.OnEnd)
end

function Input:IsCapturing(owner)
	local capture = self._capture
	return capture ~= nil and (owner == nil or capture.Owner == owner)
end

-- Left click or touch: the only "presses" that start a drag.
function Input.IsPointerDown(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

function Input:Destroy()
	self:Release()
	self._keyCapture = nil
	self._binds = {}
	if self._began then
		self._began:Disconnect()
		self._began = nil
	end
end

return Input
