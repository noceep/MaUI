local MaUI = H.loadLibrary()

T.section("Window: tabs and navigation")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub", Version = "v1", CollapseKey = "RightShift" })
	local a = window:AddTab({ Name = "Alpha", Icon = "home" })
	window:AddTabSeparator("Group")
	window:AddTabSeparator()
	local b = window:AddTab({ Name = "Beta", Badge = 3 })
	T.check("the first tab is selected", window.CurrentTab == a and a.Page.Visible and not b.Page.Visible)
	window:SelectTab(b)
	T.check("SelectTab switches pages", window.CurrentTab == b and b.Page.Visible and not a.Page.Visible)
	b:SetDisabled(true)
	window:SelectTab(a)
	window:SelectTab(b)
	T.check("a disabled tab cannot be selected", window.CurrentTab == a)
	b:SetDisabled(false)
	b:SetBadge(nil)
	b:SetCompact(true)
	b:SetCompact(false)
	for i = 1, 40 do window:AddTab({ Name = "T" .. i }) end
	T.check("40+ tabs work", #window.Tabs == 42)
	window:SetTitle("Renamed")
	T.check("title updates", window.Options.Title == "Renamed")
	window:Toggle(false)
	T.check("Toggle hides", window.Root.Visible == false and window.Open == false)
	window:Toggle()
	T.check("Toggle shows", window.Root.Visible == true)
	ui:Destroy()
	T.check("Destroy removes the gui", window.Destroyed)
end

T.section("Window: collapse, fullscreen, layout")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub" })
	local tab = window:AddTab({ Name = "Main" })
	local dd = tab:AddDropdown({ Name = "D", Items = { "a", "b" }, Flag = "d" })
	dd:Open()
	local changes = {}
	window.CollapsedChanged:Connect(function(v) changes[#changes + 1] = v end)
	window:Collapse(true)
	T.check("collapse hides pages and closes popups", window.Collapsed and not window.Pages.Visible and not ui._overlay.Popup:IsOpen())
	window:Collapse()
	T.check("collapse toggles back", not window.Collapsed and window.Pages.Visible)
	T.check("CollapsedChanged fires", #changes == 2 and changes[1] == true and changes[2] == false)
	window:SetFullscreen(true)
	T.check("fullscreen flag", window.Fullscreen == true)
	window:Collapse(true)
	window:SetFullscreen(false)
	T.check("leaving fullscreen works", window.Fullscreen == false)
	window:SetSidebarMode("Compact")
	T.check("compact sidebar", window.CompactSidebar == true)
	window:SetSidebarMode("Expanded")
	T.check("expanded sidebar", window.CompactSidebar == false)
	window:SetSidebarMode("Auto")
	local act = window:AddHeaderAction({ Icon = "bell", Tooltip = "Alerts", Callback = function() end })
	T.check("header action is created", act ~= nil)
	window:SetSession({ Name = "Me", Status = "Online" })
	T.check("session card exists", window.Session ~= nil)
	window:SetSession({ Name = "Other" })
	local nc = H.newLibrary(MaUI):CreateWindow({ Title = "x", Collapsible = false })
	nc:Collapse(true)
	T.check("Collapsible = false is respected", not nc.Collapsed)
end

T.section("Cards, columns, sub-tabs, search")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub" })
	local tab = window:AddTab({ Name = "Main" })
	local variants = { "Standard", "Compact", "Large", "Statistic", "Settings", "Action", "Info" }
	local cards = {}
	for _, v in ipairs(variants) do cards[v] = tab:AddCard({ Name = v .. " card", Variant = v }) end
	T.check("all card variants build", #tab.Elements >= #variants)
	local w = H.collectWarnings(function() tab:AddSection({ Name = "Odd", Variant = "Nope" }) end)
	T.check("unknown variant warns and falls back", H.contains(w, "unknown card variant"))
	local c = cards.Standard
	c:SetName("Renamed"); c:SetDesc("desc"); c:SetStatus("Success"); c:SetStatus(nil)
	c:SetCollapsed(true, true)
	T.check("collapse hides content", c.Collapsed == true)
	c:Toggle()
	T.check("toggle expands", c.Collapsed == false)
	c:SetCollapsed(true)
	M.advance(1)
	T.check("animated collapse completes", c.Collapsed == true)
	c:SetVisible(false)
	T.check("SetVisible hides", c.Frame.Visible == false)
	T.check("footer is available", c:GetFooter() ~= nil)

	local cols = tab:AddColumns({ Count = 3, MinWidth = 200 })
	cols[1]:AddSection("A"):AddToggle({ Name = "Alpha toggle" })
	cols[2]:AddSection("B"):AddToggle({ Name = "Beta toggle" })
	T.check("columns build", #cols == 3)
	local sub = tab:AddSubTabs()
	local s1 = sub:AddTab("One")
	local s2 = sub:AddTab("Two")
	s1:AddSection("S1")
	sub:Select(s2)
	sub:Select(s1, true)

	T.check("filter matches by name", tab:Filter("alpha") == true)
	T.check("filter with no match returns false", tab:Filter("zzzzzz") == false)
	tab:Filter("")
	T.check("clearing the filter shows other cards", cards.Compact.Frame.Visible == true)

end

T.section("Theme and animation switching")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub" })
	local tab = window:AddTab({ Name = "Main" })
	local card = tab:AddCard({ Name = "C" })
	local t = card:AddToggle({ Name = "T" })
	local before = window.Body.BackgroundColor3
	ui.Theme:Set("Light")
	T.check("switching theme recolors the window", window.Body.BackgroundColor3 ~= before)
	ui.Theme:Set("Sakura")
	T.check("switching back restores it", window.Body.BackgroundColor3 == before)
	ui:SetAnimations("Off")
	t:Set(true)
	T.check("Animations Off still applies state", t:Get() == true)
	ui:SetAnimations("Reduced")
	ui:SetAnimations("Full")
end

T.section("Window: drag, resize, clamp")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Hub" })
	window:AddTab({ Name = "Main" })
	local start = window.Root.Position
	H.pointerDown(window.Header)
	H.pointerMove(50, 20)
	T.check("dragging moves the window", window.Root.Position ~= start)
	H.pointerMove(5000, 5000)
	H.pointerUp()
	local p = window.Root.Position
	local abs = p.X.Scale * 1280 + p.X.Offset
	T.check("released outside the screen clamps back", abs <= 1280 - 80 and p.Y.Scale * 720 + p.Y.Offset <= 720)
	local size = window.Root.Size
	H.pointerDown(window.Grip)
	H.pointerMove(40, 40)
	H.pointerUp()
	T.check("resizing changes the size", window.Root.Size ~= size)
	window:_clampToScreen()
end
