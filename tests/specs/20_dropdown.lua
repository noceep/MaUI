local MaUI = H.loadLibrary()
local function setup(options)
	local ui = H.newLibrary(MaUI)
	local window = ui:CreateWindow({ Title = "W" })
	local card = window:AddTab("Main"):AddSection("Card")
	local calls = {}
	options.Callback = function(v) calls[#calls + 1] = v end
	return ui, card:AddDropdown(options), calls
end
local function popup(ui) return ui._overlay.Gui and M.find(ui._overlay.Gui, "Popup") end
local function items(ui)
	local list = M.find(ui._overlay.Gui, "List")
	local out = {}
	for _, c in ipairs(list:GetChildren()) do if c.Name == "Item" then out[#out + 1] = c end end
	return out
end

T.section("Dropdown: single select")
do
	local ui, dd, calls = setup({ Name = "Stage", Items = { "A", "B", { Name = "C", Value = 3, Desc = "third", Icon = "star" } }, Default = "A", Flag = "stage" })
	T.check("default applied without callback", dd:Get() == "A" and #calls == 0)
	T.check("popup closed initially", not dd:IsOpen() and popup(ui) == nil)
	dd:Open()
	T.check("Open creates the popup on the overlay layer", dd:IsOpen() and popup(ui) ~= nil)
	T.check("one button per item", #items(ui) == 3)
	H.click(items(ui)[3])
	T.check("picking uses the item Value", dd:Get() == 3 and calls[1] == 3)
	T.check("single select closes the menu", not dd:IsOpen() and popup(ui) == nil)
	T.check("items destroyed with the popup", M.find(ui._overlay.Gui, "Item") == nil)
	dd:Set("B", true)
	T.check("silent Set does not call back", dd:Get() == "B" and #calls == 1)
	dd:Set("nope")
	T.check("unknown value ignored", dd:Get() == "B")
	dd:Set(3)
	T.check("Set accepts a Value and the label shows the Name", M.find(dd.Frame, "Value").Text == "C")
	T.check("serialize / deserialize", dd:Serialize() == 3 and (dd:Deserialize("zzz", true) or dd:Get() == 3))
	dd:Deserialize("A", true)
	T.check("deserialize known value", dd:Get() == "A")
	dd:Open(); ui._overlay.Popup:Close()
	T.check("popup close resets the open state", not dd:IsOpen())
	dd:Open(); dd:Open()
	T.check("opening twice keeps one popup", #M.find(ui._overlay.Gui, "PopupLayer"):GetChildren() == 2)
	local before = M.instanceCount
	for _ = 1, 30 do dd:Open(); dd:Close() end
	local grown = M.instanceCount - before
	T.check("open/close cycles are bounded", grown < 30 * 40)
	dd:Close()
	dd:SetItems({ "X", "Y" })
	T.check("SetItems drops a value that disappeared", dd:Get() == nil)
	dd:AddItem("Z")
	dd:Set("Z")
	T.check("AddItem", dd:Get() == "Z")
end

T.section("Dropdown: disabled, multi, search")
do
	local ui, dd, calls = setup({ Name = "D", Items = { "A", "B" }, Disabled = true })
	dd:Open()
	T.check("a disabled dropdown does not open", not dd:IsOpen())
	dd:SetDisabled(false)
	dd:Open()
	T.check("enabling restores it", dd:IsOpen())
	dd:SetDisabled(true)
	T.check("disabling closes an open menu", not dd:IsOpen())

	local ui2, multi, c2 = setup({ Name = "M", Items = { "A", "B", "C", "D" }, Multi = true, Default = { "A" } })
	T.check("multi default is an array", #multi:Get() == 1 and multi:Get()[1] == "A")
	multi:Open()
	H.click(items(ui2)[2]); H.click(items(ui2)[3])
	T.check("multi toggles and stays open", multi:IsOpen() and #multi:Get() == 3)
	H.click(items(ui2)[2])
	T.check("clicking again deselects", #multi:Get() == 2 and multi:Get()[2] == "C")
	multi:Set({ "A", "B", "C" }, true)
	T.check("label summarizes many", M.find(multi.Frame, "Value").Text == "3 selected")
	multi:Set({ "A", "B" }, true)
	T.check("label lists two names", M.find(multi.Frame, "Value").Text == "A, B")
	multi:Set({}, true)
	T.check("empty multi shows the placeholder", M.find(multi.Frame, "Value").Text == "Select...")

	local ui3, s = setup({ Name = "S", Items = { "Apple", "Banana", "Cherry" }, Searchable = true })
	s:Open()
	local box = M.find(ui3._overlay.Gui, "Search")
	T.check("searchable shows a search box", box ~= nil)
	box.Text = "an"
	T.check("filter narrows the list", #items(ui3) == 1)
	box.Text = "zzz"
	T.check("no results shows the empty state", #items(ui3) == 0 and M.find(ui3._overlay.Gui, "Empty").Visible == true)
	box.Text = ""
	T.check("clearing the filter restores items", #items(ui3) == 3)
end

T.section("Dropdown: config + lifecycle")
do
	local ui = H.newLibrary(MaUI)
	local card = ui:CreateWindow({ Title = "W" }):AddTab("T"):AddSection("S")
	local dd = card:AddDropdown({ Name = "D", Items = { "A", "B" }, Default = "A", Flag = "d" })
	dd:Set("B")
	T.check("config save", ui:SaveConfig("dd") == true)
	dd:Set("A")
	T.check("config load restores", ui:LoadConfig("dd") == true and dd:Get() == "B")
	dd:Reset()
	T.check("Reset restores the default", dd:Get() == "A")
	dd:Open()
	dd:Destroy()
	T.check("destroy closes the popup", ui._overlay.Popup:IsOpen() == false)
	T.check("destroy frees the flag", ui.Flags.d == nil)
end
