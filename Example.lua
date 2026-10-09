-- MaUI example. Run in an executor that provides gethui/writefile.
-- local MaUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/MaUI/main/dist/MaUI.lua"))()
local MaUI = loadstring(readfile("MaUI.lua"))()

local ui = MaUI.new({ Name = "MaUIExample", ConfigFolder = "MaUIExample" })

-- Key system (client-side only: use `Validate` to ask your own server for real protection)
local gate = ui:KeySystem({
	Title = "MaUI Hub",
	Note = "Enter your key to continue.",
	Keys = { "DEMO-KEY" },
	Link = "https://example.com/getkey",
})
if not gate:Wait() then return end

local window = ui:CreateWindow({ Title = "MaUI Hub", Version = "v0.2.0", ToggleKey = "RightControl", CollapseKey = "RightShift" })
window:AddHome({ Changelog = {
	{ Title = "Welcome", Version = "0.2.0", Tag = "New", Changes = { "Sakura theme", "Cards, columns, sub-tabs", "Config manager" } },
} })

local main = window:AddTab({ Name = "Main", Icon = "home" })
local card = main:AddCard({ Name = "Player", Icon = "bolt", Desc = "Basic controls" })
card:AddToggle({ Name = "Enabled", Flag = "enabled", Callback = function(v) print("enabled", v) end })
card:AddSlider({ Name = "Speed", Min = 0, Max = 100, Default = 16, Flag = "speed" })
card:AddDropdown({ Name = "Mode", Items = { "Legit", "Rage" }, Default = "Legit", Searchable = true, Flag = "mode" })
card:AddTextBox({ Name = "Target", Placeholder = "Username", Flag = "target" })
card:AddColorPicker({ Name = "ESP color", Default = Color3.fromRGB(255, 158, 200), Flag = "esp" })
card:AddKeybind({ Name = "Panic", Default = "End", Flag = "panic" })
card:AddButton({ Name = "Notify", Callback = function() ui:Notify({ Title = "Hello", Content = "From MaUI", Type = "Success" }) end })

local columns = main:AddColumns(2)
columns[1]:AddSection("Stats"):AddMetric({ Name = "FPS", Value = 60, Suffix = " fps" })
columns[2]:AddSection("Info"):AddDataRow({ Name = "Ping", Value = "20 ms" })

local sub = main:AddSubTabs()
sub:AddTab("One"):AddSection("First")
sub:AddTab("Two"):AddSection("Second")

local settings = window:AddTab({ Name = "Settings", Icon = "gear" })
settings:AddThemeEditor()
settings:AddConfigManager()

-- Floating overlay and Dynamic Island
local overlay = ui:CreateOverlayWindow({ Title = "Overlay" })
local island = ui:CreateIsland({ Title = "MaUI" })

ui:LoadAutoload()
