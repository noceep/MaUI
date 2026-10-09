local MaUI = H.loadLibrary()

local function count(root)
	return root and #root:GetDescendants() or 0
end

T.section("Performance: instance budget (headless mock)")
do
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "Perf" })
	local tab = window:AddTab({ Name = "Main" })
	local card = tab:AddCard({ Name = "C" })
	local base = count(window.Root)
	local t0 = os.clock()
	for i = 1, 50 do card:AddToggle({ Name = "T" .. i }) end
	local per = (count(window.Root) - base) / 50
	T.metric("instances_per_toggle", per, "instances")
	T.check("a toggle stays under 14 instances", per <= 14)
	base = count(window.Root)
	for i = 1, 50 do card:AddSlider({ Name = "S" .. i, Min = 0, Max = 10, Default = 1 }) end
	per = (count(window.Root) - base) / 50
	T.metric("instances_per_slider", per, "instances")
	T.check("a slider stays under 20 instances", per <= 20)
	T.metric("build_100_elements_ms", math.floor((os.clock() - t0) * 10000) / 10, "ms")

	local dd = card:AddDropdown({ Name = "D", Items = (function() local t = {} for i = 1, 200 do t[i] = "Item" .. i end return t end)() })
	local idle = count(ui._overlay.Gui)
	dd:Open()
	local open = count(ui._overlay.Gui)
	dd:Close()
	T.check("popups build items on open and free them on close", open > idle and count(ui._overlay.Gui) <= idle + 2)
	T.metric("dropdown_200_items_open_instances", open - idle, "instances")
	local t1 = os.clock()
	for i = 1, 40 do window:AddTab({ Name = "Tab" .. i }) end
	T.metric("add_40_tabs_ms", math.floor((os.clock() - t1) * 10000) / 10, "ms")
	ui:Destroy()
	T.check("destroy frees everything", M.find(M.hui, "MaUI") == nil)
end
