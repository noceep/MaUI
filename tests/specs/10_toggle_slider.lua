-- Toggle and Slider on transparent rows.
local MaUI = H.loadLibrary()

local function setup(options)
	local ui = H.newLibrary(MaUI, options)
	local window = ui:CreateWindow({ Title = "Hub", OpenButton = false })
	local tab = window:AddTab({ Name = "Main" })
	local card = tab:AddSection({ Name = "Card" })
	return ui, card
end

local function live()
	return #M.hui:GetDescendants()
end

local function drag(slider, fromX, toX)
	slider.Track.AbsoluteSize = Vector2.new(200, 4)
	slider.Track.AbsolutePosition = Vector2.new(0, 0)
	H.pointerDown(slider.Hit, fromX, 0)
	H.pointerMove(toX, 0, 0, 0)
end

---------------------------------------------------------------------------------------------------
T.section("Toggle: basics")
do
	local ui, card = setup()
	local calls = {}
	local toggle = card:AddToggle({ Name = "Auto", Desc = "desc", Icon = "bolt", Flag = "auto", Callback = function(v)
		calls[#calls + 1] = v
	end })
	T.check("default is off", toggle:Get() == false)
	T.check("row is transparent (no boxed card)", toggle.Frame.BackgroundTransparency == 1)
	T.check("switch is 38x20", toggle.Pill.Size.X.Offset == 38 and toggle.Pill.Size.Y.Offset == 20)
	T.check("title and desc shown", M.find(toggle.Frame, "Title").Text == "Auto" and M.find(toggle.Frame, "Desc").Text == "desc")
	T.check("icon created", toggle.Row.Icon ~= nil)
	local offX = toggle.Knob.Position.X.Offset
	H.click(toggle.Frame)
	T.check("click turns on and fires callback", toggle:Get() == true and calls[1] == true)
	T.check("knob moved right", toggle.Knob.Position.X.Offset > offX)
	T.check("on track uses Accent", M.sameColor(toggle.Pill.BackgroundColor3, ui.Theme.Tokens.Accent))
	H.click(toggle.Frame)
	T.check("second click turns off", toggle:Get() == false and calls[2] == false)
	toggle:Set(true, true)
	T.check("silent Set does not call back", toggle:Get() == true and #calls == 2)
	toggle:Set(true)
	T.check("Set to the same value is a no-op", #calls == 2)
	toggle:Toggle()
	T.check("Toggle() flips", toggle:Get() == false and #calls == 3)
	toggle:Set("yes")
	T.check("non-boolean is normalized (only true is on)", toggle:Get() == false)
	local changed = 0
	toggle:OnChanged(function() changed = changed + 1 end)
	toggle:Set(true)
	T.check("OnChanged fires", changed == 1)
	toggle:Reset()
	T.check("Reset restores default", toggle:Get() == false)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Toggle: states")
do
	local ui, card = setup()
	local toggle = card:AddToggle({ Name = "T" })
	local off = toggle.Pill.BackgroundColor3
	toggle.Frame.MouseEnter:Fire()
	T.check("hover recolors the track and fades in the row", not M.sameColor(toggle.Pill.BackgroundColor3, off) and toggle.Frame.BackgroundTransparency < 1)
	local hover = toggle.Pill.BackgroundColor3
	toggle.Frame.MouseButton1Down:Fire()
	T.check("pressed recolors again and enlarges the knob", not M.sameColor(toggle.Pill.BackgroundColor3, hover) and toggle.Knob.Size.X.Offset > 14)
	toggle.Frame.MouseButton1Up:Fire()
	T.check("release restores the knob size", toggle.Knob.Size.X.Offset == 14)
	toggle.Frame.MouseLeave:Fire()
	T.check("leave restores the row", toggle.Frame.BackgroundTransparency == 1 and M.sameColor(toggle.Pill.BackgroundColor3, off))
	ui.Theme:Set("Light")
	T.check("theme change recolors the track", M.sameColor(toggle.Pill.BackgroundColor3, ui.Theme.Tokens.Surface3))
	toggle:Set(true)
	ui:SetTheme("Dark")
	T.check("on state follows theme Accent", M.sameColor(toggle.Pill.BackgroundColor3, ui.Theme.Tokens.Accent))
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Toggle: disabled, tooltip, config, cleanup")
do
	local ui, card = setup()
	local calls = 0
	local base = live()
	local toggle = card:AddToggle({ Name = "D", Flag = "d", Disabled = true, Tooltip = "Tip", Callback = function() calls = calls + 1 end })
	H.click(toggle.Frame)
	T.check("disabled ignores user clicks", toggle:Get() == false and calls == 0)
	T.check("disabled dims the title", toggle.Row.Title.TextTransparency > 0)
	toggle.Frame.MouseEnter:Fire()
	T.check("disabled has no hover feedback", toggle.Frame.BackgroundTransparency == 1)
	toggle:Set(true)
	T.check("programmatic Set still works while disabled", toggle:Get() == true and calls == 1)
	toggle:SetDisabled(false)
	T.check("title restored when enabled", toggle.Row.Title.TextTransparency == 0)
	H.click(toggle.Frame)
	T.check("enabled again reacts", toggle:Get() == false)
	toggle:SetDisabled(true)
	T.check("SetDisabled(true) after enabled", toggle.Disabled == true)

	T.check("tooltip attached (hover schedules, no crash)", pcall(function()
		toggle.Frame.MouseEnter:Fire()
		M.advance(1)
		toggle.Frame.MouseLeave:Fire()
	end))

	local cfg = card:AddToggle({ Name = "Cfg", Flag = "cfg", Default = false })
	cfg:Set(true)
	ui:SaveConfig("t")
	cfg:Set(false)
	ui:LoadConfig("t")
	T.check("config round trip", cfg:Get() == true)
	T.check("flag registered", ui.Flags.cfg == cfg)
	toggle:Destroy()
	cfg:Destroy()
	T.check("flag released on destroy", ui.Flags.cfg == nil and ui.Flags.d == nil)
	toggle:SetDisabled(false)
	toggle:Set(true)
	T.check("calls after Destroy are harmless", true)
	H.destroyAll()
	T.check("no leaked instances after destroy", live() == 0, live())
	local _ = base
end

---------------------------------------------------------------------------------------------------
T.section("Toggle: animation modes and touch")
do
	local ui, card = setup({ Animations = "Off" })
	local toggle = card:AddToggle({ Name = "Off" })
	local before = M.tweenCount
	H.click(toggle.Frame)
	T.check("Animations=Off creates no tween", M.tweenCount == before and toggle:Get() == true)
	H.destroyAll()

	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = true, false
	local _, tcard = setup()
	local tt = tcard:AddToggle({ Name = "Touch" })
	T.check("touch uses a bigger switch and hit area", tt.Pill.Size.X.Offset >= 44 and tt.Frame.Size.Y.Offset >= 44)
	local enters = 0
	tt.Frame.MouseEnter:Fire()
	T.check("no hover feedback on touch", tt.Frame.BackgroundTransparency == 1 and enters == 0)
	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = false, true
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Slider: value handling")
do
	local ui, card = setup()
	local calls = {}
	local slider = card:AddSlider({ Name = "Speed", Min = 0, Max = 100, Step = 5, Default = 20, Suffix = " sps", Flag = "spd", Callback = function(v)
		calls[#calls + 1] = v
	end })
	T.check("default applied silently", slider:Get() == 20 and #calls == 0)
	T.check("value pill shows suffix", slider.ValueLabel.Text == "20 sps")
	T.check("fill reflects the value", slider.Fill.Size.X.Scale == 0.2)
	T.check("handle follows", slider.Handle.Position.X.Scale == 0.2)
	slider:Set(47)
	T.check("snapped to step", slider:Get() == 45 and calls[1] == 45)
	slider:Set(1000)
	T.check("clamped to max", slider:Get() == 100)
	slider:Set(-5)
	T.check("clamped to min", slider:Get() == 0)
	slider:Set(10, true)
	T.check("silent Set", slider:Get() == 10 and #calls == 3)
	slider:Set("abc")
	slider:Set(0 / 0)
	T.check("invalid input ignored", slider:Get() == 10)
	slider:Set("30")
	T.check("numeric string accepted", slider:Get() == 30)
	T.raises("Max <= Min raises", function()
		card:AddSlider({ Name = "bad", Min = 5, Max = 5 })
	end, "Max must be greater")
	local dec = card:AddSlider({ Name = "dec", Min = 0, Max = 1, Step = 0.25, Default = 0.5 })
	T.check("decimals follow the step", dec.ValueLabel.Text == "0.50")
	local cont = card:AddSlider({ Name = "cont", Min = 0, Max = 1, Step = 0, Default = 0.333 })
	T.check("continuous slider (Step = 0) keeps fine values", cont:Get() == 0.33 and cont.Continuous == true)
	local none = card:AddSlider({ Name = "none" })
	T.check("defaults: Min as value", none:Get() == 0)
	slider:Reset()
	T.check("Reset to default", slider:Get() == 20)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Slider: dragging")
do
	local ui, card = setup()
	local calls = 0
	local slider = card:AddSlider({ Name = "S", Min = 0, Max = 100, Step = 1, Default = 0, Callback = function() calls = calls + 1 end })
	local ib, ic, ie = H.inputCounts()
	drag(slider, 100, 100)
	T.check("pointer down sets the value from position", slider:Get() == 50)
	T.check("dragging flag set", slider.Dragging == true)
	local tweens = M.tweenCount
	H.pointerMove(150, 0, 0, 0)
	T.check("drag moves the value", slider:Get() == 75)
	H.pointerMove(150, 0, 0, 0)
	T.check("callback only fires when the snapped value changes", calls == 2, calls)
	T.check("no value tween while dragging", M.tweenCount == tweens or slider.Fill.Size.X.Scale == 0.75)
	H.pointerMove(-500, 0, 0, 0)
	T.check("drag clamps below min", slider:Get() == 0)
	H.pointerMove(9999, 0, 0, 0)
	T.check("drag clamps above max", slider:Get() == 100)
	H.pointerUp()
	T.check("release ends the drag", slider.Dragging == false)
	local a, b, c = H.inputCounts()
	T.check("capture listeners are removed after release", a == ib and b == ic and c == ie)
	H.pointerMove(100, 0, 0, 0)
	T.check("moves after release are ignored", slider:Get() == 100)

	-- stepped
	local stepped = card:AddSlider({ Name = "St", Min = 0, Max = 10, Step = 5, Default = 0 })
	drag(stepped, 60, 60)
	T.check("stepped drag snaps (60/200*10=3 -> 5)", stepped:Get() == 5)
	H.pointerUp()

	-- disabled
	local dis = card:AddSlider({ Name = "Dis", Default = 10, Disabled = true })
	drag(dis, 150, 150)
	T.check("disabled slider ignores drag", dis:Get() == 10 and dis.Dragging == false)
	H.pointerUp()
	dis:SetDisabled(false)
	drag(dis, 150, 150)
	T.check("enabled slider drags", dis:Get() == 75)
	dis:SetDisabled(true)
	T.check("disabling mid-drag releases the capture", dis.Dragging == false)
	H.pointerMove(0, 0, 0, 0)
	T.check("disabled mid-drag no longer follows", dis:Get() == 75)
	H.pointerUp()

	-- destroy mid-drag
	local mid = card:AddSlider({ Name = "Mid" })
	drag(mid, 50, 50)
	mid:Destroy()
	local x, y, z = H.inputCounts()
	T.check("destroy mid-drag releases the capture", x == ib and y == ic and z == ie)
	T.check("pointer events after destroy are harmless", pcall(H.pointerMove, 10, 0, 0, 0))
	H.pointerUp()
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Slider: states, theme, config, cleanup")
do
	local ui, card = setup()
	local slider = card:AddSlider({ Name = "S", Desc = "d", Icon = "bolt", Flag = "sl", Min = 0, Max = 10, Default = 3, Tooltip = "tip" })
	T.check("row is transparent", slider.Frame.BackgroundTransparency == 1)
	T.check("row has room for the track beneath the label", slider.Frame.Size.Y.Offset > 34)
	local rest = slider.Handle.Size.X.Offset
	slider.Hit.MouseEnter:Fire()
	T.check("hover enlarges the handle", slider.Handle.Size.X.Offset > rest)
	slider.Hit.MouseLeave:Fire()
	T.check("leave restores the handle", slider.Handle.Size.X.Offset == rest)
	drag(slider, 20, 20)
	T.check("dragging enlarges the handle most", slider.Handle.Size.X.Offset > rest + 2)
	H.pointerUp()
	local fill = slider.Fill.BackgroundColor3
	slider:SetDisabled(true)
	T.check("disabled recolors fill and dims title", not M.sameColor(fill, slider.Fill.BackgroundColor3) and slider.Row.Title.TextTransparency > 0)
	slider:SetDisabled(false)
	ui:SetTheme("Light")
	T.check("theme change recolors the fill", M.sameColor(slider.Fill.BackgroundColor3, ui.Theme.Tokens.Accent))
	slider:Set(8)
	ui:SaveConfig("s")
	slider:Set(1)
	ui:LoadConfig("s")
	T.check("config round trip", slider:Get() == 8)
	slider:Destroy()
	H.destroyAll()
	T.check("no leaked instances", live() == 0, live())

	local ui2, card2 = setup({ Animations = "Off" })
	local s2 = card2:AddSlider({ Name = "Off" })
	local before = M.tweenCount
	s2:Set(50)
	T.check("Animations=Off: no tweens", M.tweenCount == before and s2.Fill.Size.X.Scale == 0.5)
	H.destroyAll()

	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = true, false
	local _, card3 = setup()
	local s3 = card3:AddSlider({ Name = "Touch" })
	T.check("touch: hit area >= Control metric", s3.Hit.Size.Y.Offset >= 44)
	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = false, true
	H.destroyAll()
end
