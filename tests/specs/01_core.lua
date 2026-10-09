-- Core modules: Signal, Maid, Util, Theme, Tween, Input (unit tests, source target only).
local Signal = H.module("Core/Signal")
if not Signal then
	T.section("Core (unit tests)")
	T.skip("unit tests run against the individual source files, not the bundle")
	return
end
local Maid = H.module("Core/Maid")
local Util = H.module("Core/Util")
local Theme = H.module("Core/Theme")
local Tween = H.module("Core/Tween")
local Input = H.module("Core/Input")

---------------------------------------------------------------------------------------------------
T.section("Core: Signal")
do
	local signal = Signal.new()
	local received
	signal:Connect(function(a, b)
		received = { a, b }
	end)
	signal:Fire(1, "x")
	T.check("passes arguments to handlers", received and received[1] == 1 and received[2] == "x")

	local order, b = {}, nil
	local s2 = Signal.new()
	s2:Connect(function()
		order[#order + 1] = "a"
		b:Disconnect()
	end)
	b = s2:Connect(function()
		order[#order + 1] = "b"
	end)
	s2:Connect(function()
		order[#order + 1] = "c"
	end)
	s2:Fire()
	T.check("a handler disconnected during Fire does not run", table.concat(order) == "ac", table.concat(order))
	order = {}
	s2:Fire()
	T.check("list is compacted after Fire", table.concat(order) == "ac" and #s2._handlers == 2)

	local once, count = Signal.new(), 0
	once:Once(function()
		count = count + 1
	end)
	once:Fire()
	once:Fire()
	T.check("Once fires a single time", count == 1)

	local failing, ran = Signal.new(), false
	failing:Connect(function()
		error("boom")
	end)
	failing:Connect(function()
		ran = true
	end)
	local warnings = H.collectWarnings(function()
		failing:Fire()
	end)
	T.check("an erroring handler does not stop the others", ran)
	T.check("handler errors are reported with a warning", H.contains(warnings, "error in handler"))

	local destroyed, hit = Signal.new(), false
	destroyed:Connect(function()
		hit = true
	end)
	destroyed:Destroy()
	destroyed:Fire()
	T.check("Destroy disconnects everything", not hit)

	local conn = Signal.new():Connect(function() end)
	conn:Disconnect()
	conn:Disconnect()
	T.check("Disconnect is idempotent", conn.Connected == false)
end

---------------------------------------------------------------------------------------------------
T.section("Core: Maid")
do
	local maid, log = Maid.new(), {}
	maid:Give(function()
		log[#log + 1] = "fn"
	end)
	maid:Give({ Destroy = function()
		log[#log + 1] = "destroy"
	end })
	maid:Give({ Disconnect = function()
		log[#log + 1] = "disconnect"
	end })
	local connection = M.UIS.InputBegan:Connect(function() end)
	maid:Give(connection)
	local instance = Instance.new("Frame")
	maid:Give(instance)
	T.check("Give returns the item", maid:Give(instance) == instance)
	maid:Clean()
	T.check("cleans functions, objects and connections in reverse order", table.concat(log, ",") == "disconnect,destroy,fn", table.concat(log, ","))
	T.check("disconnects Roblox connections", connection.Connected == false)
	T.check("destroys Instances", M.isDestroyed(instance))
	maid:Clean()
	T.check("a second Clean does nothing", #log == 3)

	local resilient, ok = Maid.new(), false
	resilient:Give(function()
		ok = true
	end)
	resilient:Give(function()
		error("cleanup failed")
	end)
	local warnings = H.collectWarnings(function()
		resilient:Clean()
	end)
	T.check("an erroring task does not stop the cleanup", ok)
	T.check("cleanup errors are reported", H.contains(warnings, "cleanup error"))
	T.check("Maid.Destroy is an alias of Clean", Maid.Destroy == Maid.Clean)
end

---------------------------------------------------------------------------------------------------
T.section("Core: Util")
do
	T.check("Options: string goes to the string key", Util.Options("x", { Name = "d" }).Name == "x")
	T.check("Options: custom string key", Util.Options("x", {}, "Text").Text == "x")
	local merged = Util.Options({ A = 1 }, { A = 2, B = 3 })
	T.check("Options: defaults fill the gaps only", merged.A == 1 and merged.B == 3)
	T.check("Options: an explicit false is kept", Util.Options({ X = false }, { X = true }).X == false)
	local input = { A = 1 }
	Util.Options(input, { B = 2 })
	T.check("Options: the input table is not mutated", input.B == nil)

	T.check("Clamp", Util.Clamp(5, 0, 3) == 3 and Util.Clamp(-1, 0, 3) == 0 and Util.Clamp(2, 0, 3) == 2)
	T.check("Decimals", Util.Decimals(1) == 0 and Util.Decimals(0.5) == 1 and Util.Decimals(0.25) == 2 and Util.Decimals(0.1) == 1)
	T.check("Snap: step grid", Util.Snap(43, 0, 100, 5, 0) == 45)
	T.check("Snap: grid is relative to min", Util.Snap(7, 2, 10, 3, 0) == 8)
	T.check("Snap: no floating point noise", Util.Snap(0.74, 0, 1, 0.1, 1) == 0.7)
	T.check("Snap: clamps to the range", Util.Snap(1000, 0, 100, 5, 0) == 100 and Util.Snap(-9, 0, 100, 5, 0) == 0)
	T.check("FormatNumber", Util.FormatNumber(3.14159, 2) == "3.14" and Util.FormatNumber(5, 0) == "5")

	T.check("FormatDuration: seconds", Util.FormatDuration(42) == "42s" and Util.FormatDuration(0) == "0s")
	T.check("FormatDuration: minutes", Util.FormatDuration(125) == "2m 5s")
	T.check("FormatDuration: hours", Util.FormatDuration(3700) == "1h 1m")
	T.check("FormatDuration: days", Util.FormatDuration(93784) == "1d 2h")
	T.check("FormatDuration: negative values clamp to 0", Util.FormatDuration(-50) == "0s")
	T.check("Trim", Util.Trim("  a b \n") == "a b" and Util.Trim(nil) == "" and Util.Trim("") == "")

	T.check("ParseKey: by name", Util.ParseKey("RightShift") == Enum.KeyCode.RightShift)
	T.check("ParseKey: EnumItem passes through", Util.ParseKey(Enum.KeyCode.F) == Enum.KeyCode.F)
	T.check("ParseKey: other types give nil", Util.ParseKey(nil) == nil and Util.ParseKey(12) == nil and Util.ParseKey(false) == nil)
	T.check("KeyName: abbreviations", Util.KeyName(Enum.KeyCode.RightControl) == "RCtrl" and Util.KeyName(Enum.KeyCode.F) == "F")
	T.check("KeyName: nil is None", Util.KeyName(nil) == "None")

	local copy = Util.Copy({ a = 1 })
	T.check("Copy", copy.a == 1)

	local warnings = H.collectWarnings(function()
		Util.Call(function()
			error("oops")
		end)
		Util.Call(nil)
	end)
	T.check("Call: errors are caught and reported", H.contains(warnings, "error in callback"))
	T.check("Call: a non-function is ignored", #warnings == 1)

	local parent = Instance.new("Frame")
	local child = Instance.new("Frame")
	local created = Util.Create("TextLabel", { Name = "n", Text = "t", Parent = parent }, { child })
	T.check("Create: applies properties, children and parent", created.Name == "n" and created.Text == "t" and created.Parent == parent and child.Parent == created)
end

---------------------------------------------------------------------------------------------------
T.section("Core: Theme")
do
	local theme = Theme.new("Dark")
	local frame = Instance.new("Frame")
	theme:Bind(frame, "BackgroundColor3", "Accent")
	T.check("Bind applies the token immediately", M.sameColor(frame.BackgroundColor3, Theme.Presets.Dark.Accent))
	local fired
	theme.Changed:Connect(function(name)
		fired = name
	end)
	T.check("Set returns true for a known theme", theme:Set("Light") == true)
	T.check("Set updates every bound instance", M.sameColor(frame.BackgroundColor3, Theme.Presets.Light.Accent))
	T.check("Changed fires with the theme name", fired == "Light")

	local dynamic = Instance.new("Frame")
	theme:Bind(dynamic, "BackgroundColor3", function(t)
		return t:Get("Surface3")
	end)
	theme:Set("Dark")
	T.check("function bindings are re-evaluated", M.sameColor(dynamic.BackgroundColor3, Theme.Presets.Dark.Surface3))

	theme:Release(frame)
	theme:Set("Light")
	T.check("Release stops updating an instance", M.sameColor(frame.BackgroundColor3, Theme.Presets.Dark.Accent))
	T.check("other instances keep updating", M.sameColor(dynamic.BackgroundColor3, Theme.Presets.Light.Surface3))

	local parent, descendant = Instance.new("Frame"), Instance.new("Frame")
	descendant.Parent = parent
	theme:Bind(descendant, "BackgroundColor3", "Accent")
	theme:Release(parent)
	theme:Set("Dark")
	theme:Set("Light")
	T.check("Release also frees descendants", M.sameColor(descendant.BackgroundColor3, Theme.Presets.Light.Accent) and theme._bindings[descendant] == nil)

	theme:Register("Mint", { Accent = Color3.fromRGB(10, 200, 120) }, "Dark")
	theme:Set("Mint")
	T.check("Register: partial theme overrides a token", M.sameColor(theme:Get("Accent"), Color3.fromRGB(10, 200, 120)))
	T.check("Register: other tokens come from the base", M.sameColor(theme:Get("Text"), Theme.Presets.Dark.Text))
	T.check("Set rejects an unknown theme and keeps the current one", theme:Set("Nope") == false and theme.Name == "Mint")

	local warnings = H.collectWarnings(function()
		Theme.new("Nope")
	end)
	T.check("an unknown initial theme warns and falls back to Dark", H.contains(warnings, "unknown theme"))
	T.check("bindings use weak keys", getmetatable(theme._bindings).__mode == "k")
end

---------------------------------------------------------------------------------------------------
T.section("Core: Tween")
do
	local label = Instance.new("TextLabel")
	local off = Tween.new("Off")
	local before = M.tweenCount
	off:To(label, { TextTransparency = 0.5 }, 0.3)
	T.check("Off: properties are set instantly, no tween created", label.TextTransparency == 0.5 and M.tweenCount == before)

	local full = Tween.new("Full")
	full:To(label, { TextTransparency = 0 }, 0.2)
	full:To(Instance.new("TextLabel"), { TextTransparency = 0 }, 0.2)
	T.check("Full: creates tweens", M.tweenCount == before + 2)
	local infos = 0
	for _ in pairs(full._infos) do
		infos = infos + 1
	end
	T.check("TweenInfo objects are cached per (duration, style, direction)", infos == 1)
	before = M.tweenCount
	full:To(label, { TextTransparency = 1 }, 0)
	T.check("a zero duration applies instantly", label.TextTransparency == 1 and M.tweenCount == before)

	local reduced = Tween.new("Reduced")
	reduced:To(label, { TextTransparency = 0.2 }, 0.2, nil, nil, true)
	T.check("Reduced: decorative effects are instant", label.TextTransparency == 0.2 and M.tweenCount == before)
	reduced:To(label, { TextTransparency = 0.4 }, 0.2)
	local key = next(reduced._infos)
	T.check("Reduced: durations are halved", tostring(key):sub(1, 4) == "0.1|", key)

	local warnings = H.collectWarnings(function()
		T.check("SetMode rejects an unknown mode", full:SetMode("Turbo") == false)
	end)
	T.check("an unknown mode is reported", H.contains(warnings, "unknown animation mode"))
	T.check("a nil instance is ignored", full:To(nil, {}, 1) == nil)
end

---------------------------------------------------------------------------------------------------
T.section("Core: Input")
do
	local input = Input.new()
	local began, changed, ended = H.inputCounts()
	T.check("a single permanent listener (InputBegan)", began >= 1 and changed == 0 and ended == 0)

	local hits = {}
	local bindF = input:BindKey(Enum.KeyCode.F, function()
		hits[#hits + 1] = "F"
	end)
	local bindF2 = input:BindKey(Enum.KeyCode.F, function()
		hits[#hits + 1] = "F2"
	end)
	M.press("F")
	T.check("a key triggers every bind on it", table.concat(hits, ",") == "F,F2")
	hits = {}
	M.press("F", true)
	T.check("keys already handled by the game (processed) are ignored", #hits == 0)
	bindF2:Disconnect()
	M.press("F")
	T.check("Disconnect removes a bind", table.concat(hits, ",") == "F")
	bindF:SetKey(Enum.KeyCode.G)
	hits = {}
	M.press("F")
	M.press("G")
	T.check("SetKey moves a bind to another key", table.concat(hits, ",") == "F")
	bindF:SetKey(nil)
	hits = {}
	M.press("G")
	T.check("SetKey(nil) unbinds", #hits == 0)

	local reentrant, calls = nil, 0
	reentrant = input:BindKey(Enum.KeyCode.H, function()
		calls = calls + 1
		input:BindKey(Enum.KeyCode.H, function()
			calls = calls + 100
		end)
	end)
	M.press("H")
	T.check("binds added during dispatch wait for the next press", calls == 1, calls)

	-- key capture (rebinding)
	local captured
	input:CaptureKey(function(key)
		captured = key
	end)
	hits = {}
	input:BindKey(Enum.KeyCode.J, function()
		hits[#hits + 1] = "J"
	end)
	M.press("J")
	T.check("CaptureKey swallows the next key", captured == Enum.KeyCode.J and #hits == 0)
	local cancelled = "unset"
	input:CaptureKey(function(key)
		cancelled = key
	end)
	input:CancelKeyCapture()
	T.check("CancelKeyCapture calls back with nil", cancelled == nil)

	-- pointer captures (drag)
	local startInput = M.input("MouseButton1", { Position = Vector2.new(0, 0) })
	local moves, ends = 0, 0
	input:Capture("owner", startInput, function()
		moves = moves + 1
	end, function()
		ends = ends + 1
	end)
	local _, changedNow, endedNow = H.inputCounts()
	T.check("a capture connects InputChanged/InputEnded", changedNow == 1 and endedNow == 1)
	T.check("IsCapturing", input:IsCapturing() and input:IsCapturing("owner") and not input:IsCapturing("other"))
	H.pointerMove(5, 5)
	T.check("mouse moves reach the capture", moves == 1)
	M.UIS.InputChanged:Fire(M.input("Touch"))
	T.check("a foreign touch is ignored", moves == 1)
	input:Release("other")
	T.check("Release(owner) from the wrong owner does nothing", input:IsCapturing())
	local second = 0
	input:Capture("owner2", startInput, function() end, function()
		second = second + 1
	end)
	T.check("a new capture ends the previous one", ends == 1 and input:IsCapturing("owner2"))
	H.pointerUp()
	T.check("releasing the pointer ends the capture", second == 1 and not input:IsCapturing())
	local _, changedAfter, endedAfter = H.inputCounts()
	T.check("capture listeners are removed", changedAfter == 0 and endedAfter == 0)
	T.check("IsPointerDown", Input.IsPointerDown(M.input("MouseButton1")) and Input.IsPointerDown(M.input("Touch")) and not Input.IsPointerDown(M.input("MouseMovement")))

	input:Destroy()
	local beganAfter = H.inputCounts()
	T.check("Destroy removes the permanent listener", beganAfter == began - 1)
end
