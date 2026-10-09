-- OverlayWindow: floating in-game panel.
local MaUI = H.loadLibrary()

local function live()
	return #M.hui:GetDescendants()
end

local function setup(options, libOptions)
	local ui = H.newLibrary(MaUI, libOptions)
	local overlay = ui:CreateOverlayWindow(options)
	return ui, overlay
end

local function drag(handle, dx, dy)
	H.pointerDown(handle, 10, 10)
	H.pointerMove(10, 10, dx, dy)
	H.pointerUp()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: creation and defaults")
do
	local ui, overlay = setup({ Title = "Stats", Icon = "bolt" })
	local gui = overlay.Gui
	T.check("registered in library.Overlays", ui.Overlays[1] == overlay)
	T.check("own ScreenGui with DisplayOrder 998", gui.ClassName == "ScreenGui" and gui.DisplayOrder == 998)
	T.check("gui is enabled by default", gui.Enabled == true and overlay:IsVisible())
	T.check("title shown", M.find(gui, "Title").Text == "Stats")
	T.check("icon present", M.find(gui, "Icon") ~= nil)
	local root = M.find(gui, "Overlay")
	T.check("default size 260x180", root.Size.X.Offset == 260 and root.Size.Y.Offset == 180)
	T.check("default position is top-right with margin", root.Position.X.Offset == 1280 - 260 - 16 and root.Position.Y.Offset == 16, root.Position.X.Offset)
	T.check("header buttons exist", M.find(gui, "Minimize") and M.find(gui, "Compact") and M.find(gui, "Close"))
	T.check("only the panel lives in the gui (no input sink)", #gui:GetChildren() == 1)
	T.check("default is not minimized nor compact", not overlay:IsMinimized() and not overlay.Compact)
	T.check("UIScale default 1", overlay.Scale.Scale == 1)

	local _, bare = setup({})
	T.check("empty options use defaults", M.find(bare.Gui, "Title").Text == "Overlay")
	local _, short = setup("Hello")
	T.check("string shorthand is the title", M.find(short.Gui, "Title").Text == "Hello")
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: options")
do
	local _, o = setup({ Size = Vector2.new(300, 200), Position = UDim2.fromOffset(40, 50), Transparency = 0.4, Scale = 1.2 })
	local root = M.find(o.Gui, "Overlay")
	T.check("Size option", root.Size.X.Offset == 300 and root.Size.Y.Offset == 200)
	T.check("Position option", root.Position.X.Offset == 40 and root.Position.Y.Offset == 50)
	T.check("Transparency option applies to the background", M.find(o.Gui, "Body").BackgroundTransparency == 0.4)
	T.check("text stays opaque", (M.find(o.Gui, "Title").TextTransparency or 0) == 0)
	T.check("Scale option", o.Scale.Scale == 1.2)

	local _, small = setup({ Size = Vector2.new(10, 10), MinSize = Vector2.new(150, 80), MaxSize = Vector2.new(400, 300) })
	local r2 = M.find(small.Gui, "Overlay")
	T.check("Size is clamped to MinSize", r2.Size.X.Offset == 150 and r2.Size.Y.Offset == 80)
	local _, big = setup({ Size = Vector2.new(9000, 9000), MaxSize = Vector2.new(400, 300) })
	local r3 = M.find(big.Gui, "Overlay")
	T.check("Size is clamped to MaxSize", r3.Size.X.Offset == 400 and r3.Size.Y.Offset == 300)

	local _, hidden = setup({ Visible = false })
	T.check("Visible=false starts hidden", hidden.Gui.Enabled == false and not hidden:IsVisible())
	local _, nc = setup({ Closable = false, Minimizable = false })
	T.check("Closable=false removes the close button", M.find(nc.Gui, "Close") == nil)
	T.check("Minimizable=false removes the minimize button", M.find(nc.Gui, "Minimize") == nil)
	nc:Minimize(true)
	T.check("Minimize is ignored when not Minimizable", not nc:IsMinimized())
	local _, nr = setup({ Resizable = false })
	T.check("Resizable=false has no grip", M.find(nr.Gui, "ResizeGrip") == nil)
	local _, r = setup({ Resizable = true })
	T.check("Resizable=true has a grip", M.find(r.Gui, "ResizeGrip") ~= nil)
	local _, c = setup({ Compact = true })
	T.check("Compact option starts compact", c.Compact and not M.find(c.Gui, "Title").Visible)

	local warnings = H.collectWarnings(function()
		local _, bad = setup({ DragRegion = "Nowhere" })
		T.check("bad DragRegion falls back and still builds", bad.Options.DragRegion == "Header")
	end)
	T.check("bad DragRegion warns", H.contains(warnings, "DragRegion"))
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: content container")
do
	local ui, overlay = setup({ Title = "C" })
	local toggled
	local toggle = overlay:AddToggle({ Name = "Loose toggle", Callback = function(v)
		toggled = v
	end })
	overlay:AddLabel("Direct label")
	T.check("direct elements work", toggle ~= nil and overlay._plain ~= nil)
	toggle:Set(true)
	T.check("callback runs for directly added element", toggled == true)
	local plain = overlay._plain
	overlay:AddButton({ Name = "Another" })
	T.check("direct elements share one implicit card", overlay._plain == plain)
	local section = overlay:AddSection({ Name = "Farm", Icon = "bolt" })
	local inner = section:AddToggle({ Name = "Auto" })
	T.check("AddSection works", section ~= nil and inner ~= nil)
	local cols = overlay:AddColumns(2)
	cols[1]:AddSection("Left")
	T.check("AddColumns works", #cols == 2)
	local content = M.find(overlay.Gui, "Content")
	T.check("content is a scrolling frame", content ~= nil and content.ClassName == "ScrollingFrame")
	local before = live()
	overlay:Destroy()
	T.check("destroy removes everything", live() < before)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: drag, resize and clamp")
do
	local _, o = setup({ Position = UDim2.fromOffset(100, 100) })
	local root = M.find(o.Gui, "Overlay")
	local header = M.find(o.Gui, "Header")
	local moved = {}
	o.Moved:Connect(function(p)
		moved[#moved + 1] = p
	end)
	local began, changed, ended = H.inputCounts()
		H.pointerDown(header, 5, 5)
	local _, changed2 = H.inputCounts()
	T.check("a drag adds a temporary move listener", changed2 == changed + 1)
	H.pointerMove(5, 5, 30, 20)
	T.check("mouse delta moves the panel", root.Position.X.Offset == 130 and root.Position.Y.Offset == 120)
	H.pointerUp()
	local _, changed3 = H.inputCounts()
	T.check("listener removed on release", changed3 == changed)
	T.check("Moved fired once on release", #moved == 1)
	T.check("unrelated pointer movement after release does nothing", (function()
		H.pointerMove(0, 0, 50, 50)
		return root.Position.X.Offset == 130
	end)())

	drag(header, 5000, 5000)
	T.check("clamped to the right/bottom edge", root.Position.X.Offset == 1280 - 260 and root.Position.Y.Offset == 720 - 180,
		root.Position.X.Offset .. "," .. root.Position.Y.Offset)
	drag(header, -9000, -9000)
	T.check("clamped to the left/top edge", root.Position.X.Offset == 0 and root.Position.Y.Offset == 0)

	-- right click does not drag
	header.InputBegan:Fire(M.input("MouseButton2", { Position = Vector2.new(0, 0) }))
	H.pointerMove(0, 0, 40, 40)
	H.pointerUp()
	T.check("only the primary pointer drags", root.Position.X.Offset == 0)

	-- touch drag
	local touchInput = M.input("Touch", { Position = Vector2.new(0, 0) })
	header.InputBegan:Fire(touchInput)
	M.UIS.InputChanged:Fire(M.input("Touch", { Delta = Vector3.new(10, 10, 0) }))
	T.check("a different touch finger is ignored", root.Position.X.Offset == 0)
	touchInput.Delta = Vector3.new(15, 25, 0)
	M.UIS.InputChanged:Fire(touchInput)
	T.check("the starting touch drags", root.Position.X.Offset == 15 and root.Position.Y.Offset == 25)
	M.UIS.InputEnded:Fire(touchInput)

	-- resize
	local grip = M.find(o.Gui, "ResizeGrip")
	H.pointerDown(grip, 0, 0)
	H.pointerMove(0, 0, 60, 40)
	T.check("grip resizes", root.Size.X.Offset == 320 and root.Size.Y.Offset == 220)
	H.pointerMove(0, 0, 9999, 9999)
	T.check("resize respects MaxSize", root.Size.X.Offset == 520 and root.Size.Y.Offset == 640)
	H.pointerMove(0, 0, -9999, -9999)
	T.check("resize respects MinSize", root.Size.X.Offset == 180 and root.Size.Y.Offset == 90)
	H.pointerUp()

	-- scale-aware resize
	o:SetSize(Vector2.new(260, 180))
	o:SetScale(2)
	H.pointerDown(grip, 0, 0)
	H.pointerMove(0, 0, 40, 40)
	T.check("resize deltas are divided by the UI scale", root.Size.X.Offset == 280)
	H.pointerUp()
	drag(header, 9000, 9000)
	T.check("scaled panel is clamped using its scaled size", root.Position.X.Offset == 1280 - 280 * 2, root.Position.X.Offset)
	H.destroyAll()
end

do
	local _, fixed = setup({ Draggable = false, Position = UDim2.fromOffset(100, 100) })
	local root = M.find(fixed.Gui, "Overlay")
	H.pointerDown(M.find(fixed.Gui, "Header"), 0, 0)
	H.pointerMove(0, 0, 50, 50)
	H.pointerUp()
	T.check("Draggable=false does not move", root.Position.X.Offset == 100)

	local _, hdr = setup({ DragRegion = "Header", Position = UDim2.fromOffset(100, 100) })
	local rootH = M.find(hdr.Gui, "Overlay")
	H.pointerDown(M.find(hdr.Gui, "Body"), 0, 0)
	H.pointerMove(0, 0, 50, 50)
	H.pointerUp()
	T.check("DragRegion=Header ignores body presses", rootH.Position.X.Offset == 100)

	local _, all = setup({ DragRegion = "All", Position = UDim2.fromOffset(100, 100) })
	local rootA = M.find(all.Gui, "Overlay")
	H.pointerDown(M.find(all.Gui, "Body"), 0, 0)
	H.pointerMove(0, 0, 50, 50)
	H.pointerUp()
	T.check("DragRegion=All drags from the body", rootA.Position.X.Offset == 150)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: visibility, toggle key, signals")
do
	local _, o = setup({ ToggleKey = "RightShift" })
	local events = {}
	o.VisibilityChanged:Connect(function(v)
		events[#events + 1] = v
	end)
	o:Hide()
	T.check("Hide disables the gui", o.Gui.Enabled == false and not o:IsVisible())
	o:Hide()
	T.check("repeated Hide does not re-fire", #events == 1)
	o:Show()
	T.check("Show enables the gui", o.Gui.Enabled == true)
	o:Toggle()
	T.check("Toggle flips", o.Gui.Enabled == false)
	M.press("RightShift")
	T.check("ToggleKey shows it again", o.Gui.Enabled == true)
	M.press("RightShift", true)
	T.check("ToggleKey is ignored when the game processed the key", o.Gui.Enabled == true)
	o:Toggle(false)
	T.check("Toggle(false) hides", o.Gui.Enabled == false)
	T.check("VisibilityChanged values", events[1] == false and events[2] == true and events[3] == false and events[4] == true)
	H.click(M.find(o.Gui, "Close"))
	T.check("close button hides", o.Gui.Enabled == false)
	o:Show()

	-- hiding mid-drag releases the capture
	H.pointerDown(M.find(o.Gui, "Header"), 0, 0)
	o:Hide()
	T.check("hiding releases an active drag", not o.Ctx.Input:IsCapturing())
	o:Destroy()
	M.press("RightShift")
	T.check("destroyed overlay ignores its key", o.Destroyed)
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: compact, minimize, transparency, scale, title")
do
	local _, o = setup({ Title = "T" })
	local compactEvents = {}
	o.CompactChanged:Connect(function(v)
		compactEvents[#compactEvents + 1] = v
	end)
	local root = M.find(o.Gui, "Overlay")
	local header = M.find(o.Gui, "Header")
	local fullHeader = header.Size.Y.Offset
	local pad = o.Padding.PaddingLeft.Offset
	o:SetCompact(true)
	T.check("compact hides the title", M.find(o.Gui, "Title").Visible == false)
	T.check("compact shrinks the header", header.Size.Y.Offset < fullHeader)
	T.check("compact shrinks the padding", o.Padding.PaddingLeft.Offset < pad)
	T.check("CompactChanged(true)", compactEvents[1] == true)
	o:SetCompact(true)
	T.check("idempotent compact", #compactEvents == 1)
	H.click(M.find(o.Gui, "Compact"))
	T.check("compact button toggles back", not o.Compact and M.find(o.Gui, "Title").Visible and compactEvents[2] == false)

	local events = {}
	o.MinimizedChanged:Connect(function(v)
		events[#events + 1] = v
	end)
	o:Minimize(true)
	T.check("minimized shows only the header", root.Size.Y.Offset == header.Size.Y.Offset and M.find(o.Gui, "Content").Visible == false)
	T.check("grip hidden while minimized", M.find(o.Gui, "ResizeGrip").Visible == false)
	H.pointerDown(M.find(o.Gui, "ResizeGrip"), 0, 0)
	H.pointerMove(0, 0, 40, 40)
	H.pointerUp()
	T.check("minimized panel cannot be resized", root.Size.Y.Offset == header.Size.Y.Offset)
	H.click(M.find(o.Gui, "Minimize"))
	T.check("minimize button restores", not o:IsMinimized() and root.Size.Y.Offset == 180 and M.find(o.Gui, "Content").Visible)
	T.check("MinimizedChanged fired", events[1] == true and events[2] == false)

	o:SetTransparency(2)
	T.check("transparency is clamped to 1", M.find(o.Gui, "Body").BackgroundTransparency == 1)
	o:SetTransparency(-3)
	T.check("transparency is clamped to 0", M.find(o.Gui, "Body").BackgroundTransparency == 0)
	local warnings = H.collectWarnings(function()
		o:SetTransparency("x")
		o:SetScale("big")
		o:SetScale(0 / 0)
		o:SetPosition("nope")
		o:SetSize("nope")
	end)
	T.check("invalid input warns and does not crash", #warnings == 5, #warnings)
	T.check("invalid input leaves state intact", o.Scale.Scale == 1)
	o:SetScale(10)
	T.check("scale is clamped high", o.Scale.Scale == 2)
	o:SetScale(0.01)
	T.check("scale is clamped low", o.Scale.Scale == 0.5)

	o:SetPosition(UDim2.fromOffset(77, 88))
	T.check("SetPosition", o:GetPosition().X.Offset == 77 and o:GetPosition().Y.Offset == 88)
	o:SetPosition(Vector2.new(5000, 5000))
	T.check("SetPosition clamps to the screen", o:GetPosition().X.Offset == 1280 - 130 and o:GetPosition().Y.Offset == 720 - 90, o:GetPosition().X.Offset)
	o:SetTitle("Renamed")
	T.check("SetTitle", M.find(o.Gui, "Title").Text == "Renamed")
	H.destroyAll()
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: blur, theme, animations, touch")
do
	local lighting = M.lighting
	local before = #lighting:GetChildren()
	local _, plain = setup({})
	T.check("no blur unless requested", #lighting:GetChildren() == before)
	local _, o = setup({ Blur = true })
	T.check("Blur creates a BlurEffect in Lighting", #lighting:GetChildren() == before + 1)
	o:Hide()
	T.check("hiding removes the blur", #lighting:GetChildren() == before)
	o:Show()
	T.check("showing restores the blur", #lighting:GetChildren() == before + 1)
	o:Destroy()
	T.check("destroy removes the blur", #lighting:GetChildren() == before)
	local ui2, o2 = setup({ Blur = 20 })
	T.check("numeric Blur sets the size", lighting:GetChildren()[#lighting:GetChildren()].Size == 20)
	ui2:Destroy()
	T.check("library destroy removes the blur", #lighting:GetChildren() == before)
	H.destroyAll()

	local ui, th = setup({})
	local body = M.find(th.Gui, "Body")
	local old = body.BackgroundColor3
	ui:SetTheme("Light")
	T.check("theme change re-colors the panel", not M.sameColor(old, body.BackgroundColor3))
	H.destroyAll()

	local ui3, off = setup({}, { Animations = "Off" })
	local tweens = M.tweenCount
	off:SetCompact(true)
	off:Minimize(true)
	T.check("Animations=Off applies instantly", M.tweenCount == tweens and M.find(off.Gui, "Overlay").Size.Y.Offset == M.find(off.Gui, "Header").Size.Y.Offset)
	H.destroyAll()

	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = true, false
	local _, t = setup({})
	T.check("touch header and buttons are larger", M.find(t.Gui, "Header").Size.Y.Offset >= 40 and M.find(t.Gui, "Minimize").Size.X.Offset >= 36)
	T.check("touch grip is larger", M.find(t.Gui, "ResizeGrip").Size.X.Offset >= 20)
	H.destroyAll()
	M.UIS.TouchEnabled, M.UIS.KeyboardEnabled = false, true
end

---------------------------------------------------------------------------------------------------
T.section("Overlay: cleanup")
do
	local baseline = live()
	local conns = { H.inputCounts() }
	local ui = H.newLibrary(MaUI)
	local lib0 = live()
	local o = ui:CreateOverlayWindow({ Title = "Leak", ToggleKey = "F6", Blur = true })
	o:AddToggle({ Name = "x" })
	o:AddSection("S"):AddToggle({ Name = "y" })
	H.pointerDown(M.find(o.Gui, "Header"), 0, 0)
	o:Destroy()
	T.check("destroy while dragging releases the capture", not ui.Ctx.Input:IsCapturing())
	T.check("removed from library.Overlays", #ui.Overlays == 0)
	T.check("instances return to the library baseline", live() == lib0, live() .. " vs " .. lib0)
	o:Destroy()
	T.check("double destroy is safe", true)
	local o2 = ui:CreateOverlayWindow({})
	local o3 = ui:CreateIsland({})
	ui:Destroy()
	T.check("library destroy destroys overlays", o2.Destroyed and o3.Destroyed and #ui.Overlays == 0)
	T.check("no leaked guis", live() == baseline, live() .. " vs " .. baseline)
	local began, changed, ended = H.inputCounts()
	T.check("no leaked input listeners", changed == conns[2] and ended == conns[3])
	H.destroyAll()
end
