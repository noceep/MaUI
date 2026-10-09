-- DynamicIsland: collapsed pill that expands into a compact info panel.
local MaUI = H.loadLibrary()

local function live()
	return #M.hui:GetDescendants()
end

local function setup(options, libOptions)
	local ui = H.newLibrary(MaUI, libOptions)
	local island = ui:CreateIsland(options)
	return ui, island, M.find(island.Gui, "Island")
end

local function queued()
	local n = 0
	for _, entry in ipairs(M.queue) do
		if not entry.cancelled then
			n = n + 1
		end
	end
	return n
end

---------------------------------------------------------------------------------------------------
T.section("Island: creation and collapsed pill")
do
	local ui, island, root = setup({ Icon = "bolt", Text = "Farming", Metric = "1.2k/h", Count = 3, Status = "success" })
	local gui = island.Gui
	T.check("registered in library.Overlays", ui.Overlays[1] == island)
	T.check("single ScreenGui, DisplayOrder 997", gui.ClassName == "ScreenGui" and gui.DisplayOrder == 997 and #gui:GetChildren() == 1)
	T.check("collapsed size is a small pill", root.Size.X.Offset == 170 and root.Size.Y.Offset == 32)
	T.check("TopCenter anchoring", root.AnchorPoint.X == 0.5 and root.AnchorPoint.Y == 0 and root.Position.X.Scale == 0.5 and root.Position.Y.Offset == 12)
	T.check("pill shows text and metric", M.find(gui, "Text").Text == "Farming" and M.find(gui, "Metric").Text == "1.2k/h")
	T.check("count badge shown", M.find(gui, "Count").Visible and M.find(gui, "Count").Text == "3")
	T.check("content hidden while collapsed", M.find(gui, "Content").Visible == false and M.find(gui, "Pill").Visible ~= false)
	T.check("not expanded, not pinned", not island:IsExpanded() and not island:IsPinned())
	T.check("root clips its content", root.ClipsDescendants == true)
	T.check("no CanvasGroup anywhere", (function()
		for _, d in ipairs(gui:GetDescendants()) do
			if d.ClassName == "CanvasGroup" then
				return false
			end
		end
		return true
	end)())

	local _, plain, _ = setup({})
	T.check("count badge hidden at zero", M.find(plain.Gui, "Count").Visible == false)
	T.check("metric hidden when empty", M.find(plain.Gui, "Metric").Visible == false)
	local _, short = setup("Hello")
	T.check("string shorthand is the text", M.find(short.Gui, "Text").Text == "Hello")
	local _, hidden = setup({ Visible = false })
	T.check("Visible=false starts disabled", hidden.Gui.Enabled == false)
	local _, wide, wroot = setup({ Width = 240 })
	T.check("Width option", wroot.Size.X.Offset == 240)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: positions")
do
	local cases = {
		{ "TopLeft", 0, 0, 12, 12, 0 },
		{ "TopRight", 1, 0, -12, 12, 1 },
		{ "BottomCenter", 0.5, 1, 0, -12, 0.5 },
	}
	for _, c in ipairs(cases) do
		local _, _, root = setup({ Position = c[1] })
		T.check("preset " .. c[1], root.AnchorPoint.X == c[2] and root.AnchorPoint.Y == c[3] and root.Position.Y.Offset == c[5]
			and (c[1] == "BottomCenter" and root.Position.X.Scale == 0.5 or root.Position.X.Offset == c[4]))
	end
	local _, _, margin = setup({ Position = "TopLeft", Margin = 30 })
	T.check("Margin option", margin.Position.X.Offset == 30 and margin.Position.Y.Offset == 30)
	local _, _, custom = setup({ Position = UDim2.fromOffset(500, 300), AnchorPoint = Vector2.new(0, 0) })
	T.check("custom UDim2 position", custom.Position.X.Offset == 500 and custom.Position.Y.Offset == 300)
	local warnings = H.collectWarnings(function()
		local _, _, bad = setup({ Position = "Nowhere" })
		T.check("unknown position falls back to TopCenter", bad.AnchorPoint.X == 0.5)
	end)
	T.check("unknown position warns", H.contains(warnings, "Position"))

	-- the expanded panel stays on screen near edges
	local _, isl, edge = setup({ Position = UDim2.fromOffset(1000, 600), AnchorPoint = Vector2.new(0, 0) })
	isl:Expand()
	local size = edge.Size
	T.check("custom position is shifted so the panel fits", edge.Position.X.Offset + size.X.Offset <= 1280 and edge.Position.Y.Offset + size.Y.Offset <= 720,
		edge.Position.X.Offset .. "," .. edge.Position.Y.Offset)
	isl:Collapse()
	T.check("collapsing returns the custom position", edge.Position.X.Offset == 1000 and edge.Position.Y.Offset == 600)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: hover expand and delayed collapse")
do
	local _, island, root = setup({ Text = "S" })
	local events = {}
	island.ExpandedChanged:Connect(function(v)
		events[#events + 1] = v
	end)
	root.MouseEnter:Fire()
	T.check("hover expands instantly (ExpandDelay 0)", island:IsExpanded() and events[1] == true)
	T.check("content swapped by Visible", M.find(island.Gui, "Content").Visible and not M.find(island.Gui, "Pill").Visible)
	T.check("expanded size is ExpandedSize", root.Size.X.Offset == 300 and root.Size.Y.Offset >= 170)
	T.check("expanded panel stays much smaller than a window", root.Size.X.Offset <= 360 and root.Size.Y.Offset <= 260)
	root.MouseLeave:Fire()
	T.check("leave does not collapse immediately", island:IsExpanded())
	M.advance(0.3)
	T.check("still expanded before CollapseDelay", island:IsExpanded())
	M.advance(0.1)
	T.check("collapses after CollapseDelay", not island:IsExpanded() and events[2] == false)
	T.check("collapsed size restored", root.Size.X.Offset == 170 and root.Size.Y.Offset == 32)

	-- pointer returns: the pending collapse is cancelled
	root.MouseEnter:Fire()
	root.MouseLeave:Fire()
	M.advance(0.2)
	root.MouseEnter:Fire()
	M.advance(1)
	T.check("returning pointer cancels the collapse", island:IsExpanded())
	T.check("no timer left running", queued() == 0)

	-- moving between the root and its children does not flicker
	local content = M.find(island.Gui, "Content")
	root.MouseLeave:Fire()
	content.MouseEnter:Fire()
	M.advance(1)
	T.check("child MouseEnter keeps it open", island:IsExpanded())
	content.MouseLeave:Fire()
	M.advance(0.5)
	T.check("child MouseLeave collapses", not island:IsExpanded())

	-- re-arming: many leave events keep ONE timer
	root.MouseEnter:Fire()
	for _ = 1, 20 do
		root.MouseLeave:Fire()
		root.MouseEnter:Fire()
		root.MouseLeave:Fire()
	end
	T.check("re-arming keeps a single pending timer", queued() == 1, queued())
	M.advance(1)
	T.check("final leave collapses once", not island:IsExpanded() and queued() == 0)
	H.destroyAll()
end

do
	local _, island, root = setup({ ExpandDelay = 0.2, CollapseDelay = 1 })
	root.MouseEnter:Fire()
	T.check("ExpandDelay postpones the expansion", not island:IsExpanded())
	M.advance(0.25)
	T.check("expands after ExpandDelay", island:IsExpanded())
	root.MouseLeave:Fire()
	M.advance(0.9)
	T.check("CollapseDelay option", island:IsExpanded())
	M.advance(0.2)
	T.check("collapsed after custom delay", not island:IsExpanded())
	root.MouseEnter:Fire()
	root.MouseLeave:Fire()
	M.advance(1)
	T.check("leaving before ExpandDelay fires cancels the expansion", not island:IsExpanded())
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: pin")
do
	local _, island, root = setup({})
	local pins = {}
	island.PinnedChanged:Connect(function(v)
		pins[#pins + 1] = v
	end)
	island:Pin(true)
	T.check("Pin expands", island:IsExpanded() and island:IsPinned() and pins[1] == true)
	root.MouseLeave:Fire()
	M.advance(5)
	T.check("pinned ignores leave", island:IsExpanded())
	T.check("pinned has no pending timer", queued() == 0)
	H.click(M.find(island.Gui, "Pin"))
	T.check("pin button unpins", not island:IsPinned() and pins[2] == false)
	M.advance(1)
	T.check("unpinned (pointer away) collapses after the delay", not island:IsExpanded())
	island:Pin(false)
	T.check("repeated Pin(false) is a no-op", #pins == 2)

	-- clicking the collapsed pill toggles pin
	H.click(M.find(island.Gui, "Pill"))
	T.check("clicking the collapsed pill pins", island:IsPinned() and island:IsExpanded())
	island:Collapse()
	T.check("Collapse unpins and collapses", not island:IsPinned() and not island:IsExpanded())

	local _, pinned = setup({ Pinned = true })
	T.check("Pinned option starts expanded", pinned:IsExpanded() and pinned:IsPinned())

	-- pointer inside while unpinning: stays open
	local _, i2, r2 = setup({})
	r2.MouseEnter:Fire()
	i2:Pin(true)
	i2:Pin(false)
	M.advance(2)
	T.check("unpin while hovering keeps it open", i2:IsExpanded())
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: touch")
do
	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = true, false
	local _, island, root = setup({})
	root.MouseEnter:Fire()
	T.check("no hover expansion on touch", not island:IsExpanded())
	H.click(M.find(island.Gui, "Pill"))
	T.check("tap expands", island:IsExpanded() and not island:IsPinned())
	H.click(M.find(island.Gui, "Header"))
	T.check("tap on the user row collapses", not island:IsExpanded())
	T.check("touch metrics: taller pill", root.Size.Y.Offset >= 36)
	island:Pin(true)
	H.click(M.find(island.Gui, "Header"))
	T.check("pinned panel ignores the collapse tap", island:IsExpanded())
	T.check("touch buttons meet the control size", M.find(island.Gui, "Pin").Size.X.Offset >= 36)
	H.destroyAll()
	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = false, true
end

---------------------------------------------------------------------------------------------------
T.section("Island: collapsed content API")
do
	local _, island = setup({ Text = "A", Metric = "1", Count = 0 })
	local gui = island.Gui
	island:SetCollapsed({ Text = "B" })
	T.check("partial update keeps other fields", M.find(gui, "Text").Text == "B" and M.find(gui, "Metric").Text == "1")
	island:SetCollapsed({ Metric = "9.9k", Count = 150 })
	T.check("metric and count update", M.find(gui, "Metric").Text == "9.9k" and M.find(gui, "Count").Text == "99+" and M.find(gui, "Count").Visible)
	island:SetCollapsed({ Count = 0 })
	T.check("count 0 hides the badge", M.find(gui, "Count").Visible == false)
	island:SetCollapsed({ Metric = "" })
	T.check("empty metric hides it", M.find(gui, "Metric").Visible == false)
	local icon = M.find(gui, "Pill"):FindFirstChild("Icon", true)
	island:SetCollapsed({ Status = "error" })
	T.check("status changes the icon", icon ~= nil and (icon.Image ~= "" or icon.Text ~= nil))
	local before = icon.ImageColor3 or icon.TextColor3
	island:SetCollapsed({ Status = "success" })
	T.check("status changes the icon color", not M.sameColor(before, icon.ImageColor3 or icon.TextColor3))
	local warnings = H.collectWarnings(function()
		island:SetCollapsed({ Status = "bogus" })
		island:SetCollapsed("x")
		island:SetUser("x")
		island:SetMetric(3, {})
		island:SetMetric(1, "x")
		island:PushMetric(3, 1)
		island:PushMetric(1, "x")
		island:PushMetric(1, 0 / 0)
		island:PushMetric(1, math.huge)
		island:SetSettingsCallback("x")
		island:SetSessionTime("x")
	end)
	T.check("invalid input warns without crashing", #warnings == 11, #warnings)
	island:SetCollapsed({ Status = false })
	T.check("Status=false clears it", island.Options.Status == nil)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: user row and avatar")
do
	local requests = M.thumbnailRequests
	local _, island, root = setup({})
	T.check("default user comes from the local player", M.find(island.Gui, "Name").Text == "Test Display" and M.find(island.Gui, "Subtitle").Text == "@TestUser")
	T.check("avatar is not fetched while collapsed", M.thumbnailRequests == requests)
	island:Expand()
	T.check("avatar fetched on first expand", M.thumbnailRequests == requests + 1)
	T.check("avatar image set", tostring(M.find(island.Gui, "Avatar").Image):find("12345", 1, true) ~= nil)
	island:Collapse()
	island:Expand()
	T.check("avatar is not refetched", M.thumbnailRequests == requests + 1)
	island:SetUser({ Name = "Neo", Subtitle = "The One", UserId = 777 })
	T.check("SetUser texts", M.find(island.Gui, "Name").Text == "Neo" and M.find(island.Gui, "Subtitle").Text == "The One")
	T.check("SetUser with UserId refetches while expanded", M.thumbnailRequests == requests + 2 and tostring(M.find(island.Gui, "Avatar").Image):find("777", 1, true) ~= nil)
	island:SetUser({ Avatar = "rbxassetid://1" })
	T.check("explicit Avatar wins", M.find(island.Gui, "Avatar").Image == "rbxassetid://1")
	island:SetUser({ Name = "Only" })
	T.check("partial SetUser keeps the avatar", M.find(island.Gui, "Subtitle").Text == "The One" and M.find(island.Gui, "Avatar").Image == "rbxassetid://1")

	-- token guard: a stale thumbnail answer must not overwrite a newer avatar
	local players = game:GetService("Players")
	local original = players.GetUserThumbnailAsync
	local release
	players.GetUserThumbnailAsync = function(_, id)
		release = id
		return "late://" .. id
	end
	local _, i2 = setup({})
	i2:SetUser({ UserId = 1 })
	i2:Expand()
	i2:SetUser({ Avatar = "explicit" })
	T.check("avatar token guard keeps the newest image", M.find(i2.Gui, "Avatar").Image == "explicit")
	players.GetUserThumbnailAsync = original
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: metrics and sparklines")
do
	local _, island = setup({})
	local gui = island.Gui
	island:SetMetric(1, { Name = "FPS", Value = 60, Max = 120 })
	island:SetMetric(2, { Name = "Ping", Value = 34.5, Format = "%.0fms" })
	T.check("tile names", M.find(gui, "Tile1"):FindFirstChild("Name").Text == "FPS" and M.find(gui, "Tile2"):FindFirstChild("Name").Text == "Ping")
	T.check("tile values formatted", M.find(gui, "Tile1"):FindFirstChild("Value").Text == "60" and M.find(gui, "Tile2"):FindFirstChild("Value").Text == "34ms" or M.find(gui, "Tile2"):FindFirstChild("Value").Text == "35ms")
	island:SetMetric(2, { Format = function(v) return v .. " ms!" end })
	T.check("function format", M.find(gui, "Tile2"):FindFirstChild("Value").Text:find("ms!", 1, true) ~= nil)
	island:SetMetric(2, { Format = function() error("boom") end })
	T.check("a failing format function falls back", M.find(gui, "Tile2"):FindFirstChild("Value") ~= nil)

	local tile1 = M.find(gui, "Tile1")
	local bars = {}
	for _, d in ipairs(tile1:GetDescendants()) do
		if d.Name == "Bar" then
			bars[#bars + 1] = d
		end
	end
	T.check("pool of 20 bars per tile", #bars == 20, #bars)
	T.check("newest bar uses the accent color", M.sameColor(bars[20].BackgroundColor3, island.Ctx.Theme:Get("Accent")))

	island:Expand()
	for i = 1, 5 do
		island:PushMetric(1, i * 10)
	end
	T.check("PushMetric updates the tile value", M.find(gui, "Tile1"):FindFirstChild("Value").Text == "50")
	T.check("newest bar is the tallest sample (Max 120)", math.abs(bars[20].Size.Y.Scale - (50 / 120) * 0.9) < 1e-6, bars[20].Size.Y.Scale)
	T.check("older samples shift left", math.abs(bars[19].Size.Y.Scale - (40 / 120) * 0.9) < 1e-6)
	T.check("empty slots are minimal", bars[1].Size.Y.Scale == 0 and bars[1].Size.Y.Offset == 2)

	-- auto scaling without Max
	island:SetMetric(2, { Name = "Auto" })
	island:PushMetric(2, 5)
	island:PushMetric(2, 10)
	local bars2 = {}
	for _, d in ipairs(M.find(gui, "Tile2"):GetDescendants()) do
		if d.Name == "Bar" then
			bars2[#bars2 + 1] = d
		end
	end
	T.check("auto max scales to the largest sample", math.abs(bars2[20].Size.Y.Scale - 0.9) < 1e-6 and math.abs(bars2[19].Size.Y.Scale - 0.45) < 1e-6)

	-- stability: 200 pushes create nothing, tween nothing
	local count, tweens = live(), M.tweenCount
	for i = 1, 200 do
		island:PushMetric(1, i % 100)
		island:PushMetric(2, i)
	end
	T.check("200 PushMetric calls create no instances", live() == count, live() - count)
	T.check("PushMetric never tweens", M.tweenCount == tweens)
	T.check("ring never grows past the pool", #island.Tiles[1].Ring <= 20)
	T.check("newest bar shows the last sample", math.abs(bars[20].Size.Y.Scale - 0) < 1e-6)

	-- collapsed pushes do not touch bars; they render on expand
	island:Collapse()
	local mark = bars[20].Size
	island:PushMetric(1, 100)
	T.check("collapsed pushes do not redraw the bars", bars[20].Size == mark)
	island:Expand()
	T.check("bars catch up on expand", math.abs(bars[20].Size.Y.Scale - (100 / 120) * 0.9) < 1e-6)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: chips, actions, settings")
do
	local _, island, root = setup({})
	local gui = island.Gui
	T.check("rows hidden when empty", M.find(gui, "Chips").Visible == false and M.find(gui, "Actions").Visible == false)
	island:Expand()
	local base = root.Size.Y.Offset
	local chip = island:AddChip("Ping", "34ms")
	T.check("chip row appears", M.find(gui, "Chips").Visible)
	T.check("expanded height grows for the chip row", root.Size.Y.Offset >= base)
	chip:Set(55)
	T.check("chip :Set updates the value", chip.ValueLabel.Text == "55")
	T.check("chip label", chip.NameLabel.Text == "Ping")
	local chip2 = island:AddChip("Region", nil)
	T.check("nil chip value is empty text", chip2.ValueLabel.Text == "")

	local clicked, signalName = 0, nil
	island.ActionClicked:Connect(function(name)
		signalName = name
	end)
	local action = island:AddAction({ Name = "Rejoin", Icon = "refresh", Callback = function(a)
		clicked = clicked + 1
	end })
	T.check("action row appears", M.find(gui, "Actions").Visible)
	T.check("expanded height covers every row", root.Size.Y.Offset >= 8 * 2 + 32 + 52 + 20 + 26 + 18, root.Size.Y.Offset)
	H.click(action.Frame)
	T.check("action callback and signal", clicked == 1 and signalName == "Rejoin")
	action:SetDisabled(true)
	H.click(action.Frame)
	T.check("disabled action does nothing", clicked == 1)
	action:SetDisabled(false)
	H.click(action.Frame)
	T.check("re-enabled action works", clicked == 2)
	local thrown = H.collectWarnings(function()
		island:AddAction({ Name = "Bad", Callback = function() error("x") end })
		H.click(island.Actions[2].Frame)
	end)
	T.check("a failing callback warns without crashing", #thrown >= 1)
	local plainAction = island:AddAction("Nameless")
	T.check("action without callback is safe", (function() H.click(plainAction.Frame) return true end)())

	T.check("settings button hidden without a callback", M.find(gui, "Settings").Visible == false)
	local opened = 0
	island:SetSettingsCallback(function()
		opened = opened + 1
	end)
	T.check("settings button appears", M.find(gui, "Settings").Visible)
	H.click(M.find(gui, "Settings"))
	T.check("settings callback runs", opened == 1)
	island:SetSettingsCallback(nil)
	T.check("clearing hides the settings button", M.find(gui, "Settings").Visible == false)

	local chipFrame = chip.Frame
	chip:Destroy()
	T.check("chip destroy removes it", #island.Chips == 1 and M.isDestroyed(chipFrame))
	action:Destroy()
	T.check("action destroy removes it", #island.Actions == 2)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: session clock")
do
	M.now = M.now or 0
	local _, island, root = setup({})
	local label = M.find(island.Gui, "Session")
	island:SetSessionTime(65)
	T.check("SetSessionTime formats with FormatDuration", label.Text == "1m 5s", label.Text)
	T.check("no timer without the clock", queued() == 0)
	island:StartSessionClock()
	T.check("clock does not run while collapsed", queued() == 0)
	island:Expand()
	T.check("clock runs while expanded: ONE pending task", queued() == 1, queued())
	M.advance(3)
	T.check("clock advances with the library clock", label.Text == "1m 8s", label.Text)
	T.check("still a single chain", queued() == 1)
	island:Collapse()
	T.check("collapse stops the clock", queued() == 0)
	M.advance(10)
	island:Expand()
	T.check("clock resumes with the elapsed time", label.Text == "1m 18s", label.Text)
	island:SetVisible(false)
	T.check("hiding stops the clock", queued() == 0)
	island:SetVisible(true)
	T.check("showing resumes it", queued() == 1)
	island:StopSessionClock()
	T.check("StopSessionClock stops it", queued() == 0)
	island:SetSessionTime(5)
	M.advance(5)
	T.check("without the clock the text only changes on demand", label.Text == "5s")
	island:StartSessionClock(100)
	T.check("StartSessionClock(start) begins there", label.Text == "1m 40s", label.Text)
	island:Destroy()
	T.check("destroy stops the clock", queued() == 0)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: animation budget, theme, modes")
do
	local _, island, root = setup({})
	local tweens = M.tweenCount
	island:Expand()
	T.check("expanding is a single Size tween", M.tweenCount - tweens == 1, M.tweenCount - tweens)
	tweens = M.tweenCount
	island:Collapse()
	T.check("collapsing is a single Size tween", M.tweenCount - tweens == 1, M.tweenCount - tweens)
	tweens = M.tweenCount
	for _ = 1, 50 do
		island:SetCollapsed({ Text = "x", Metric = "y" })
		island:PushMetric(1, 3)
	end
	M.advance(5)
	T.check("idle updates cause no tweens", M.tweenCount == tweens)
	island:Expand()
	island:Expand()
	T.check("redundant Expand does nothing", M.tweenCount - tweens == 1)

	local ui, i2 = setup({})
	local r2 = M.find(i2.Gui, "Island")
	local old = r2.BackgroundColor3
	ui:SetTheme("Light")
	T.check("theme change re-colors the island", not M.sameColor(old, r2.BackgroundColor3))

	local _, off, offRoot = setup({}, { Animations = "Off" })
	local t0 = M.tweenCount
	off:Expand()
	T.check("Animations=Off expands instantly", offRoot.Size.X.Offset == 300 and M.tweenCount == t0)
	off:Collapse()
	T.check("Animations=Off collapses instantly", offRoot.Size.X.Offset == 170)

	local _, vis = setup({})
	vis:Expand()
	vis:SetVisible(false)
	T.check("SetVisible(false) disables the gui", vis.Gui.Enabled == false)
	vis:SetVisible(true)
	T.check("SetVisible(true) re-enables it", vis.Gui.Enabled == true)

	-- ExpandedSize / small viewports
	local _, small, sroot = setup({ ExpandedSize = Vector2.new(5000, 5000) })
	small:Expand()
	T.check("ExpandedSize is clamped inside the viewport", sroot.Size.X.Offset <= 1280 - 24 and sroot.Size.Y.Offset <= 720 - 24)
	local _, tiny, troot = setup({ ExpandedSize = Vector2.new(10, 10) })
	tiny:Expand()
	T.check("ExpandedSize has a usable minimum", troot.Size.X.Offset >= 220 and troot.Size.Y.Offset >= 120)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Island: cleanup")
do
	local baseline = live()
	local ui = H.newLibrary(MaUI)
	local lib0 = live()
	local island = ui:CreateIsland({ Text = "x" })
	island:AddChip("a", "b")
	island:AddAction({ Name = "go" })
	island:StartSessionClock()
	island:Expand()
	island:SetUser({ UserId = 5 })
	root = M.find(island.Gui, "Island")
	root.MouseLeave:Fire()
	island:Destroy()
	M.advance(5)
	T.check("destroy cancels every timer", queued() == 0)
	T.check("removed from library.Overlays", #ui.Overlays == 0)
	T.check("instances return to the library baseline", live() == lib0, live() .. " vs " .. lib0)
	island:Expand()
	island:PushMetric(1, 3)
	island:SetCollapsed({ Text = "late" })
	T.check("calls after destroy do not crash", true)
	island:Destroy()
	T.check("double destroy is safe", true)
	ui:Destroy()
	T.check("no leaked guis", live() == baseline, live() .. " vs " .. baseline)
	H.destroyAll()
end
