local MaUI = H.loadLibrary()
local function setup(options)
	local ui = H.newLibrary(MaUI)
	local card = ui:CreateWindow({ Title = "W" }):AddTab("Main"):AddSection("Card")
	local calls = {}
	options.Callback = function(v) calls[#calls + 1] = v end
	return ui, card:AddColorPicker(options), calls
end
local function hex(c) return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end

T.section("ColorPicker: value")
do
	local ui, cp, calls = setup({ Name = "C", Default = Color3.fromRGB(255, 0, 0), Flag = "c" })
	T.check("default shown, no callback", hex(cp:Get()) == "FF0000" and #calls == 0 and M.find(cp.Frame, "Hex").Text == "#FF0000")
	cp:Set("00FF00")
	T.check("Set accepts hex", hex(cp:Get()) == "00FF00" and #calls == 1)
	cp:Set("#0000ff", true)
	T.check("hex with # and silent Set", hex(cp:Get()) == "0000FF" and #calls == 1)
	cp:Set("zzzzzz")
	cp:Set(12)
	T.check("invalid input ignored", hex(cp:Get()) == "0000FF")
	cp:Set(Color3.fromRGB(0, 0, 255))
	T.check("same color does not call back", #calls == 1)
	T.check("serialize is a hex string", cp:Serialize() == "0000FF")
	T.check("config round trip", ui:SaveConfig("cp") and (cp:Set("FF00FF", true) or true) and ui:LoadConfig("cp") and hex(cp:Get()) == "0000FF")
	cp:Reset()
	T.check("Reset restores the default", hex(cp:Get()) == "FF0000")
end

T.section("ColorPicker: popup and dragging")
do
	local ui, cp, calls = setup({ Name = "C", Default = Color3.fromRGB(255, 0, 0) })
	H.click(cp.Frame)
	T.check("clicking opens the popup", cp:IsOpen() and M.find(ui._overlay.Gui, "SV") ~= nil)
	local square = M.find(ui._overlay.Gui, "SV")
	square.AbsoluteSize = Vector2.new(100, 100)
	square.AbsolutePosition = Vector2.new(0, 0)
	H.pointerDown(square, 50, 50)
	T.check("pressing the square picks that saturation/value", math.abs(cp.S - 0.5) < 1e-6 and math.abs(cp.V - 0.5) < 1e-6)
	T.check("Live fires the callback while dragging", #calls == 1)
	H.pointerMove(100, 0)
	T.check("dragging follows the pointer", math.abs(cp.S - 1) < 1e-6 and math.abs(cp.V - 1) < 1e-6 and #calls == 2)
	H.pointerMove(900, -300)
	T.check("the pointer is clamped to the square", cp.S == 1 and cp.V == 1)
	H.pointerUp()
	local tweens = M.tweenCount
	H.pointerDown(square, 10, 10)
	H.pointerMove(20, 20); H.pointerMove(30, 30)
	T.check("dragging creates no tweens", M.tweenCount == tweens)
	H.pointerUp()
	local hue = M.find(ui._overlay.Gui, "Hue")
	hue.AbsoluteSize = Vector2.new(200, 14)
	hue.AbsolutePosition = Vector2.new(0, 0)
	H.pointerDown(hue, 100, 7)
	T.check("the hue bar sets the hue", math.abs(cp.H - 0.5) < 1e-6)
	H.pointerUp()
	local hexBox = M.find(ui._overlay.Gui, "HexInput")
	hexBox.Text = "#112233"
	hexBox.FocusLost:Fire(true)
	T.check("hex field applies a valid color", hex(cp:Get()) == "112233")
	hexBox.Text = "nonsense"
	hexBox.FocusLost:Fire(true)
	T.check("invalid hex is rejected and restored", hex(cp:Get()) == "112233" and hexBox.Text == "#112233")
	local presets = 0
	for _, c in ipairs(M.find(ui._overlay.Gui, "Presets"):GetChildren()) do if c.Name == "Preset" then presets = presets + 1 end end
	T.check("presets are listed", presets == 8)
	H.click(M.find(ui._overlay.Gui, "Preset"))
	T.check("a preset applies its color", hex(cp:Get()) == "FF9EC8")
	ui._overlay.Popup:Close()
	T.check("closing the popup resets state", not cp:IsOpen() and M.find(ui._overlay.Gui, "SV") == nil)
	cp:Set("FF0000", true)
	T.check("Set while closed works", hex(cp:Get()) == "FF0000")
end

T.section("ColorPicker: non-live, disabled, lifecycle")
do
	local ui, cp, calls = setup({ Name = "N", Live = false, Default = Color3.fromRGB(255, 0, 0) })
	cp:Open()
	local square = M.find(ui._overlay.Gui, "SV")
	square.AbsoluteSize = Vector2.new(100, 100)
	H.pointerDown(square, 20, 20)
	H.pointerMove(40, 40)
	T.check("non-live holds the callback during the drag", #calls == 0)
	H.pointerUp()
	T.check("non-live fires once at the end of the drag", #calls == 1)
	local ui2, d = setup({ Name = "D", Disabled = true })
	H.click(d.Frame)
	T.check("disabled does not open", not d:IsOpen())
	d:SetDisabled(false)
	H.click(d.Frame)
	d:SetDisabled(true)
	T.check("disabling closes the popup", not d:IsOpen())
	d:Open()
	d:SetDisabled(false); d:Open()
	d:Destroy()
	T.check("destroy closes the popup and frees the flag", not ui2._overlay.Popup:IsOpen())
end
