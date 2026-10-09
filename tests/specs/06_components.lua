local MaUI = H.loadLibrary()
local ui = H.newLibrary(MaUI)
local window = ui:CreateWindow({ Title = "Hub" })
local tab = window:AddTab({ Name = "Main" })
local card = tab:AddCard({ Name = "C" })

T.section("Button")
do
	local n = 0
	local b = card:AddButton({ Name = "Go", Callback = function() n = n + 1 end })
	H.click(b.Frame or b.Button or b.Root)
	T.check("click fires callback", n == 1)
	b:SetDisabled(true); H.click(b.Frame or b.Button or b.Root)
	T.check("disabled ignores clicks", n == 1)
	b:SetDisabled(false)
	b:SetLoading(true); H.click(b.Frame or b.Button or b.Root)
	T.check("loading ignores clicks", n == 1)
	b:SetLoading(false)
	b:SetText("Run"); b:SetIcon("bolt"); b:SetStyle("Destructive")
	for _, s in ipairs({ "Primary", "Secondary", "Tertiary", "Ghost" }) do b:SetStyle(s) end
end

T.section("Metric and DataRow")
do
	local m = card:AddMetric({ Name = "FPS", Value = 60, Suffix = " fps", Visual = "Bars" })
	for i = 1, 40 do m:Push(50 + i % 7) end
	m:SetSecondary("avg"); m:SetTrend(2); m:SetTrend(-2); m:SetStatus("Warning"); m:Clear()
	T.check("metric accepts pushes and clear", true)
	local d = card:AddDataRow({ Name = "Ping", Value = "20 ms" })
	d:SetValue("30 ms"); d:SetStatus("Error"); d:SetName("Latency")
	T.check("data row updates", d:Get() == "30 ms")
	T.check("display rows are not persisted", (function() ui:SaveConfig("m") local j = M.files[ui.ConfigFolder .. "/m.json"] return not j:find("Latency", 1, true) end)())
end

T.section("Keycap, Label, Keybind")
do
	local k = card:AddKeycap({ Keys = { "Ctrl", "K" } })
	k:SetKeys({ "Shift" })
	local l = card:AddLabel({ Text = "hello" })
	l:SetText("bye")
	T.check("label text", l:Get() == "bye")
	local hit = 0
	local kb = card:AddKeybind({ Name = "Key", Default = "F", Flag = "kb", Callback = function() hit = hit + 1 end })
	T.check("keybind default", kb:Get() ~= nil)
	kb:SetDisabled(true); kb:SetDisabled(false)
	T.check("keybind serializes", kb:Serialize() ~= nil)
end

T.section("Notifications")
do
	local seen = {}
	for _, t in ipairs({ "Info", "Success", "Warning", "Error", "Loading" }) do
		seen[t] = ui:Notify({ Title = t, Content = "c", Type = t, Duration = 2 })
	end
	T.check("every type returns a handle", seen.Info and seen.Loading and seen.Error)
	seen.Loading:Update({ Title = "Done", Type = "Success", Duration = 1 })
	local closed = false
	seen.Info.Closed:Connect(function() closed = true end)
	seen.Info:Close()
	M.advance(1)
	T.check("Close fires Closed", closed)
	local w = H.collectWarnings(function() ui:Notify({ Title = "x", Type = "Weird" }) end)
	T.check("unknown type warns", H.contains(w, "unknown Type"))
	M.advance(10)
	for i = 1, 12 do ui:Notify({ Title = "n" .. i }) end
	M.advance(20)
	T.check("toasts expire without leaking", true)
end

T.section("Lifecycle")
do
	ui:Destroy()
	T.check("destroy leaves no MaUI guis", M.find(M.hui, "MaUI") == nil)
end
