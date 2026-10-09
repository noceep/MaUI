local MaUI = H.loadLibrary()
local function setup(options)
	local ui = H.newLibrary(MaUI)
	local card = ui:CreateWindow({ Title = "W" }):AddTab("Main"):AddSection("Card")
	local calls = {}
	options.Callback = function(v) calls[#calls + 1] = v end
	return ui, card:AddTextBox(options), calls
end
local function type_(box, text, commit)
	box.Box.Text = text
	if commit ~= false then box.Box.FocusLost:Fire(true) end
end

T.section("TextBox: commit and values")
do
	local ui, box, calls = setup({ Name = "N", Default = "hello", Flag = "n" })
	T.check("default shown, no callback", box:Get() == "hello" and M.find(box.Frame, "Input").Text == "hello" and #calls == 0)
	type_(box, "world", false)
	T.check("typing alone does not commit", box:Get() == "hello" and #calls == 0)
	box.Box.FocusLost:Fire(true)
	T.check("FocusLost commits", box:Get() == "world" and calls[1] == "world")
	type_(box, "world")
	T.check("an unchanged text does not call back", #calls == 1)
	box:Set("x", true)
	T.check("silent Set", box:Get() == "x" and #calls == 1 and box.Box.Text == "x")
	T.check("serialization round trip", box:Serialize() == "x" and ui:SaveConfig("tb") and (box:Set("y", true) or true) and ui:LoadConfig("tb") and box:Get() == "x")
	box:Reset()
	T.check("Reset", box:Get() == "hello")
end

T.section("TextBox: live, limits, numeric")
do
	local ui, live, calls = setup({ Name = "L", Live = true, MaxLength = 5 })
	type_(live, "ab", false)
	type_(live, "abc", false)
	T.check("Live fires on every change", #calls == 2 and calls[2] == "abc")
	type_(live, "abcdefgh", false)
	T.check("MaxLength truncates", live.Box.Text == "abcde")
	local ui2, num, c2 = setup({ Name = "Num", Numeric = true, Min = 0, Max = 10, Default = 5 })
	type_(num, "7")
	T.check("numeric value is a number", num:Get() == 7)
	type_(num, "99")
	T.check("numeric clamps to Max", num:Get() == 10)
	type_(num, "-4")
	T.check("numeric clamps to Min", num:Get() == 0)
	type_(num, "abc")
	T.check("non-numeric rejected, value kept, error shown", num:Get() == 0 and num.State == "error" and M.find(num.Frame, "Helper").Text == "Enter a number")
	type_(num, "3")
	T.check("a valid entry clears the error", num.State == nil and M.find(num.Frame, "Helper").Visible == false)
end

T.section("TextBox: validation and states")
do
	local ui, box, calls = setup({ Name = "V", Default = "ok", Validate = function(t) return t:find("^%a+$") ~= nil, "Letters only" end })
	type_(box, "a1")
	T.check("invalid input is not committed", box:Get() == "ok" and #calls == 0)
	T.check("error state + message", box.State == "error" and M.find(box.Frame, "Helper").Text == "Letters only")
	T.check("the row grows for the message", box.Frame.Size.Y.Offset > box._baseHeight)
	type_(box, "fine")
	T.check("valid input commits and clears the error", box:Get() == "fine" and box.State == nil and box.Frame.Size.Y.Offset == box._baseHeight)
	box:SetState("success", "Looks good")
	T.check("manual success state", box.State == "success" and M.find(box.Frame, "Helper").Text == "Looks good")
	box:SetState(nil)
	T.check("manual clear", box.State == nil)
	local warnings = H.collectWarnings(function() box:SetState("bogus") end)
	T.check("unknown state warns", H.contains(warnings, "unknown TextBox state"))
	local thrower = select(2, setup({ Name = "T", Validate = function() error("boom") end }))
	local w = H.collectWarnings(function() type_(thrower, "x") end)
	T.check("a throwing Validate is reported, not fatal", H.contains(w, "error in Validate"))

	local ui2, dis, c2 = setup({ Name = "D", Default = "keep", Disabled = true })
	type_(dis, "changed")
	T.check("disabled ignores typing", dis:Get() == "keep" and dis.Box.Text == "keep")
	dis:SetDisabled(false)
	type_(dis, "changed")
	T.check("enabling allows typing", dis:Get() == "changed")
	local ui3, ro = setup({ Name = "R", Default = "fixed", ReadOnly = true })
	type_(ro, "nope")
	T.check("read-only keeps the value", ro:Get() == "fixed")
	ro:SetReadOnly(false)
	type_(ro, "now")
	T.check("read-only can be lifted", ro:Get() == "now")
	local acted
	local ui4, act = setup({ Name = "A", Default = "val", Icon = "search", Action = { Icon = "copy", Tooltip = "Copy", Callback = function(v) acted = v end } })
	H.click(M.find(act.Frame, "Action"))
	T.check("trailing action receives the value", acted == "val")
	act:Destroy()
	T.check("destroy removes the row", act.Frame == nil)
end
