local MaUI = H.loadLibrary()
local function gate(ui, options)
	return ui:KeySystem(options)
end
local function submit(g, text)
	local gui = M.find(M.hui, "KeySystem")
	M.find(gui, "Input").Text = text
	H.click(M.find(gui, "Check"))
end

T.section("Key system: validation")
do
	local ui = H.newLibrary(MaUI)
	local passed
	local g = gate(ui, { Title = "Hub", Keys = { "ABC" }, OnSuccess = function(k) passed = k end })
	T.check("the gate window appears", M.find(M.hui, "KeySystem") ~= nil)
	submit(g, "")
	T.check("empty input asks for a key", M.find(M.find(M.hui, "KeySystem"), "Status").Text == "Enter a key first.")
	submit(g, "nope")
	T.check("a wrong key is rejected", not g.Done and M.find(M.find(M.hui, "KeySystem"), "Status").Text == "Invalid key.")
	submit(g, "ABC")
	T.check("a locked gate ignores attempts during the cooldown", not g.Done)
	M.advance(2)
	submit(g, " ABC ")
	T.check("a valid key (trimmed) passes", g.Done and g.Success and passed == "ABC")
	T.check("the window is removed", M.find(M.hui, "KeySystem") == nil)
	T.check("library state: key set, no expiry", ui.Key.Value == "ABC" and ui:GetKeyTimeLeft() == math.huge)
	T.check("the key is saved", M.files[ui.ConfigFolder .. "/key.txt"] == "ABC")
	T.raises("no Keys and no Validate is an error", function() ui:KeySystem({ Title = "x" }) end, "provide `Keys`")
end

T.section("Key system: Validate, expiry, Wait")
do
	local ui = H.newLibrary(MaUI)
	local seen = {}
	local g = gate(ui, { Validate = function(key)
		seen[#seen + 1] = key
		if key == "good" then return true, { ExpiresIn = 100, Message = "Welcome" } end
		if key == "boom" then error("server down") end
		return false, "Revoked"
	end, SaveKey = false })
	submit(g, "bad")
	T.check("Validate message is shown", M.find(M.find(M.hui, "KeySystem"), "Status").Text == "Revoked")
	M.advance(2)
	local w = H.collectWarnings(function() submit(g, "boom") end)
	T.check("a throwing Validate is reported and rejected", H.contains(w, "error in Validate") and not g.Done)
	M.advance(2)
	local result
	task.spawn(function() result = { g:Wait() } end)
	T.check("Wait blocks until done", result == nil)
	submit(g, "good")
	T.check("Wait resumes with success and info", result and result[1] == true and result[2].ExpiresIn == 100)
	T.check("time left counts down", ui:GetKeyTimeLeft() == 100)
	M.now = M.now + 40
	T.check("clock advances", ui:GetKeyTimeLeft() == 60)
	local expired = 0
	ui.KeyExpired:Connect(function() expired = expired + 1 end)
	M.advance(61)
	T.check("expiry fires once and time left is 0", expired == 1 and ui:GetKeyTimeLeft() == 0 and ui.Key.Expired)
	T.check("nothing is saved when SaveKey = false", M.files[ui.ConfigFolder .. "/key.txt"] == nil)
end

T.section("Key system: saved key and closing")
do
	local ui = H.newLibrary(MaUI)
	M.files[ui.ConfigFolder .. "/key.txt"] = "SAVED"
	local calls = 0
	local g = gate(ui, { Keys = { "SAVED" }, Validate = nil })
	T.check("a valid saved key passes without showing the window", g.Done and g.Success and M.find(M.hui, "KeySystem") == nil)
	local ui2 = H.newLibrary(MaUI)
	M.files[ui2.ConfigFolder .. "/key.txt"] = "OLD"
	local g2 = gate(ui2, { Keys = { "NEW" } })
	T.check("an invalid saved key is deleted and the window appears", not g2.Done and M.files[ui2.ConfigFolder .. "/key.txt"] == nil and M.find(M.hui, "KeySystem") ~= nil)
	local closed = false
	g2.Closed:Connect(function() closed = true end)
	H.click(M.find(M.find(M.hui, "KeySystem"), "Close"))
	T.check("closing the window fails the gate", g2.Done and not g2.Success and closed)
	T.check("Wait after close returns false", select(1, g2:Wait()) == false)
	local ui3 = H.newLibrary(MaUI)
	local g3 = gate(ui3, { Keys = { "K" }, Link = "https://example.com" })
	H.click(M.find(M.find(M.hui, "KeySystem"), "GetKey"))
	T.check("Get key reports the link", M.find(M.find(M.hui, "KeySystem"), "Status").Text ~= "")
	ui3:Destroy()
	T.check("destroying the library removes the gate", M.find(M.hui, "KeySystem") == nil)
end

T.section("Home tab, Profile, KeyStatus, Changelog")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub" })
	local main = window:AddTab("Main")
	local home = window:AddHome({ Greeting = "Hi", Changelog = {
		{ Title = "Added keys", Version = "1.1", Tag = "New", Changes = { "one", "two" } },
		{ Title = "Fixes", Content = "text" },
	} })
	T.check("Home is the first tab and selected", window.Tabs[1] == home and window.CurrentTab == home and window.Home == home)
	T.check("profile shows display name and username", M.find(home.Page, "DisplayName").Text == "Test Display" and M.find(home.Page, "Subtitle").Text:find("@TestUser", 1, true) ~= nil)
	T.check("profile shows the user id", M.find(home.Page, "Subtitle").Text:find("12345", 1, true) ~= nil)
	T.check("the avatar was requested", M.thumbnailRequests >= 1 and M.find(home.Page, "Avatar").Image:find("12345", 1, true) ~= nil)
	T.check("changelog entries are built", #(function() local n = {} for _, d in ipairs(home.Page:GetDescendants()) do if d.Name == "Entry" then n[#n + 1] = d end end return n end)() == 2)
	T.check("no KeyStatus without a key", M.find(home.Page, "TimeLeft") == nil)
	T.raises("a second Home is refused", function() window:AddHome({}) end, "already has a Home")
	T.check("Home and profile are not saved in configs", (function() ui:SaveConfig("h") return not M.files[ui.ConfigFolder .. "/h.json"]:find("Profile", 1, true) end)())

	local ui2 = H.newLibrary(MaUI)
	ui2:_SetKey("K", ui2.Clock() + 7200, nil)
	local w2 = ui2:CreateWindow({ Title = "Hub2" })
	local home2 = w2:AddHome({})
	local label = M.find(home2.Page, "TimeLeft")
	T.check("KeyStatus appears with a key and shows time left", label ~= nil and label.Text:find("2h", 1, true) ~= nil)
	M.now = M.now + 3601
	M.advance(1.1)
	T.check("the display refreshes once per second", label.Text:find("1h", 1, true) ~= nil or label.Text:find("0h", 1, true) ~= nil or label.Text:find("59m", 1, true) ~= nil)
	ui2.KeyTick:Fire(ui2.Key)
	ui2:_OnKeyExpired()
	T.check("an expired key shows Expired", label.Text == "Expired")
	local ui3 = H.newLibrary(MaUI)
	ui3:_SetKey("L", nil, nil)
	local home3 = ui3:CreateWindow({ Title = "H3" }):AddHome({})
	T.check("lifetime key", M.find(home3.Page, "TimeLeft").Text == "Lifetime")
	T.check("no 1s tick without an expiring key", ui3._tickRunning == false)
end
