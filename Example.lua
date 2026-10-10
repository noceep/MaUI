
local MaUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/noceep/MaUI/main/dist/MaUI.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

local ui = MaUI.new({ Name = "MaUIHub", ConfigFolder = "MaUIHub" })

-- Key gate. This runs on the client, so it only deters casual use; for real protection, validate the key
-- on your own server inside `Validate` and keep the protected logic server-side.
local gate = ui:KeySystem({
	Title = "MaUI Hub",
	Note = "Enter your key to continue.",
	Keys = { "MAUI-DEMO" },
	Link = "https://example.com/getkey",
})
if not gate:Wait() then
	return
end

-- Everything we connect is collected here and released when the UI is destroyed.
local connections = {}
local function connect(signal, fn)
	local connection = signal:Connect(fn)
	connections[#connections + 1] = connection
	return connection
end
ui.Maid:Give(function()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end)

local function character()
	return player.Character
end
local function humanoid()
	local char = character()
	return char and char:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------
local window = ui:CreateWindow({
	Title = "MaUI Hub",
	Version = "v0.2.0",
	ToggleKey = Enum.KeyCode.RightControl,
	CollapseKey = Enum.KeyCode.RightShift,
})

window:AddHome({
	Changelog = {
		{ Title = "Movement and visuals", Version = "0.2.0", Tag = "New", Changes = {
			"Walk speed, jump power and infinite jump",
			"Player ESP with a custom color",
			"Fullbright and field of view",
		} },
		{ Title = "Interface", Version = "0.1.0", Changes = { "Config manager, theme editor and keybinds in Settings" } },
	},
})

---------------------------------------------------------------------------------------------------
-- Player
---------------------------------------------------------------------------------------------------
window:AddTabSeparator("Features")
local playerTab = window:AddTab({ Name = "Player", Icon = "user" })

local movement = playerTab:AddCard({ Name = "Movement", Icon = "bolt", Desc = "Character speed and jumping" })

local walkSpeedOn, walkSpeed = false, 32
movement:AddToggle({ Name = "Walk speed", Desc = "Overrides the humanoid walk speed", Flag = "walkspeed_on", Callback = function(on)
	walkSpeedOn = on
	local hum = humanoid()
	if hum and not on then
		hum.WalkSpeed = 16
	end
end })
movement:AddSlider({ Name = "Speed", Min = 16, Max = 200, Step = 1, Default = 32, Suffix = " sps", Flag = "walkspeed", Callback = function(value)
	walkSpeed = value
end })

local jumpOn, jumpPower = false, 80
movement:AddToggle({ Name = "Jump power", Flag = "jump_on", Callback = function(on)
	jumpOn = on
	local hum = humanoid()
	if hum and not on then
		hum.UseJumpPower = true
		hum.JumpPower = 50
	end
end })
movement:AddSlider({ Name = "Power", Min = 50, Max = 300, Step = 5, Default = 80, Flag = "jump", Callback = function(value)
	jumpPower = value
end })

local infiniteJump = false
movement:AddToggle({ Name = "Infinite jump", Desc = "Jump again while in the air", Flag = "infjump", Callback = function(on)
	infiniteJump = on
end })

connect(RunService.Heartbeat, function()
	local hum = humanoid()
	if not hum then
		return
	end
	if walkSpeedOn then
		hum.WalkSpeed = walkSpeed
	end
	if jumpOn then
		hum.UseJumpPower = true
		hum.JumpPower = jumpPower
	end
end)
connect(UserInputService.JumpRequest, function()
	local hum = humanoid()
	if infiniteJump and hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local utility = playerTab:AddCard({ Name = "Utility", Icon = "settings" })
local antiAfk
utility:AddToggle({ Name = "Anti AFK", Desc = "Prevents the idle kick", Flag = "antiafk", Default = true, Callback = function(on)
	if antiAfk then
		antiAfk:Disconnect()
		antiAfk = nil
	end
	if on then
		antiAfk = player.Idled:Connect(function()
			local VirtualUser = game:GetService("VirtualUser")
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
		connections[#connections + 1] = antiAfk
	end
end })
utility:AddButton({ Name = "Reset character", Style = "Destructive", Confirm = true, Callback = function()
	local hum = humanoid()
	if hum then
		hum.Health = 0
	end
end })

---------------------------------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------------------------------
local visualsTab = window:AddTab({ Name = "Visuals", Icon = "eye" })
local columns = visualsTab:AddColumns(2)

-- ESP: one Highlight per player, created only while enabled and removed with the toggle
local espColor, espMode = Color3.fromRGB(255, 158, 200), "Fill"
local highlights = {}
local espOn = false

local function applyEspStyle(highlight)
	highlight.FillColor = espColor
	highlight.OutlineColor = espColor
	highlight.FillTransparency = espMode == "Outline" and 1 or 0.6
end
local function addEsp(target)
	if target == player or highlights[target] then
		return
	end
	local char = target.Character
	if not char then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = char
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	applyEspStyle(highlight)
	highlight.Parent = char
	highlights[target] = highlight
end
local function clearEsp()
	for target, highlight in pairs(highlights) do
		highlight:Destroy()
		highlights[target] = nil
	end
end
local function refreshEsp()
	for _, target in ipairs(Players:GetPlayers()) do
		addEsp(target)
	end
end

local esp = columns[1]:AddSection({ Name = "Player ESP", Icon = "eye", Desc = "Highlights other players" })
esp:AddToggle({ Name = "Enabled", Flag = "esp", Callback = function(on)
	espOn = on
	if on then
		refreshEsp()
	else
		clearEsp()
	end
end })
esp:AddDropdown({ Name = "Style", Items = { "Fill", "Outline" }, Default = "Fill", Flag = "esp_style", Callback = function(value)
	espMode = value
	for _, highlight in pairs(highlights) do
		applyEspStyle(highlight)
	end
end })
esp:AddColorPicker({ Name = "Color", Default = espColor, Flag = "esp_color", Live = true, Callback = function(color)
	espColor = color
	for _, highlight in pairs(highlights) do
		applyEspStyle(highlight)
	end
end })
connect(Players.PlayerAdded, function(target)
	connect(target.CharacterAdded, function()
		task.wait(0.5)
		if espOn then
			highlights[target] = nil
			addEsp(target)
		end
	end)
end)
for _, target in ipairs(Players:GetPlayers()) do
	connect(target.CharacterAdded, function()
		task.wait(0.5)
		if espOn then
			highlights[target] = nil
			addEsp(target)
		end
	end)
end
connect(Players.PlayerRemoving, function(target)
	if highlights[target] then
		highlights[target]:Destroy()
		highlights[target] = nil
	end
end)
ui.Maid:Give(clearEsp)

local world = columns[2]:AddSection({ Name = "World", Icon = "bolt", Desc = "Lighting and camera" })
local savedLighting = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows }
world:AddToggle({ Name = "Fullbright", Flag = "fullbright", Callback = function(on)
	if on then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
	else
		for key, value in pairs(savedLighting) do
			Lighting[key] = value
		end
	end
end })
ui.Maid:Give(function()
	for key, value in pairs(savedLighting) do
		Lighting[key] = value
	end
end)
local camera = workspace.CurrentCamera
local defaultFov = camera and camera.FieldOfView or 70
world:AddSlider({ Name = "Field of view", Min = 40, Max = 120, Step = 1, Default = defaultFov, Flag = "fov", Callback = function(value)
	if workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = value
	end
end })

---------------------------------------------------------------------------------------------------
-- Stats: live FPS and ping
---------------------------------------------------------------------------------------------------
local statsTab = window:AddTab({ Name = "Stats", Icon = "refresh" })
local row = statsTab:AddColumns(2)
local fpsMetric = row[1]:AddSection({ Name = "Performance", Variant = "Statistic" }):AddMetric({
	Name = "FPS", Icon = "bolt", Value = 0, Viz = "Bars", Status = "success",
	Format = function(value) return string.format("%d", value) end,
})
local pingMetric = row[2]:AddSection({ Name = "Network", Variant = "Statistic" }):AddMetric({
	Name = "Ping", Icon = "refresh", Value = 0, Viz = "Bars", Status = "success",
	Format = function(value) return string.format("%d ms", value) end,
})

local details = statsTab:AddCard({ Name = "Session", Icon = "info" })
local playersRow = details:AddDataRow({ Name = "Players", Value = tostring(#Players:GetPlayers()) })
details:AddDataRow({ Name = "Place ID", Value = tostring(game.PlaceId) })
details:AddDataRow({ Name = "Job ID", Value = string.sub(game.JobId, 1, 8) ~= "" and string.sub(game.JobId, 1, 8) or "Studio" })

-- FPS is the average over a short window (no per-frame UI work); it is not capped at 60.
local island -- created at the bottom; the FPS loop feeds it once it exists
local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
	frames = frames + 1
	elapsed = elapsed + dt
	if elapsed < 0.25 then
		return
	end
	local fps = frames / elapsed
	frames, elapsed = 0, 0
	fpsMetric:Push(fps)
	fpsMetric:SetStatus(fps >= 60 and "success" or fps >= 30 and "warning" or "error")
	if island and not island.Destroyed then
		island:PushMetric(1, fps)
		island:SetCollapsed({ Metric = string.format("%d fps", fps) })
	end
end)

local function readPing()
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and value or 0
end
task.spawn(function()
	while not window.Destroyed do
		local ping = readPing()
		pingMetric:Push(ping)
		pingMetric:SetStatus(ping < 100 and "success" or ping < 200 and "warning" or "error")
		playersRow:SetValue(tostring(#Players:GetPlayers()))
		task.wait(1)
	end
end)

---------------------------------------------------------------------------------------------------
-- Misc
---------------------------------------------------------------------------------------------------
local miscTab = window:AddTab({ Name = "Misc", Icon = "folder" })
local sub = miscTab:AddSubTabs()

local server = sub:AddTab("Server")
local serverCard = server:AddSection({ Name = "Server tools", Icon = "refresh" })
serverCard:AddButton({ Name = "Rejoin", Desc = "Reconnects to this server", Icon = "refresh", Confirm = true, Callback = function()
	TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
end })
serverCard:AddButton({ Name = "Copy Job ID", Style = "Secondary", Callback = function()
	if setclipboard then
		setclipboard(game.JobId)
		ui:Notify({ Title = "Copied", Content = "Job ID copied to the clipboard.", Type = "Success" })
	else
		ui:Notify({ Title = "Unavailable", Content = "Your executor has no setclipboard.", Type = "Warning" })
	end
end })

local chat = sub:AddTab("Notes")
local notes = chat:AddSection({ Name = "Notes", Icon = "info" })
notes:AddTextBox({ Name = "Reminder", Placeholder = "Type something", MaxLength = 80, Flag = "reminder" })
notes:AddKeybind({ Name = "Panic key", Desc = "Destroys the UI", Default = Enum.KeyCode.End, Flag = "panic", Callback = function()
	ui:Destroy()
end })
notes:AddButton({ Name = "Show a notification", Style = "Primary", Callback = function()
	ui:Notify({ Title = "MaUI Hub", Content = "Everything works.", Type = "Info", Duration = 4 })
end })

---------------------------------------------------------------------------------------------------
-- Dynamic Island: shown only while the window is hidden. Click it to reopen the window, drag it to move it.
---------------------------------------------------------------------------------------------------
island = ui:CreateIsland({ Window = window, Icon = "bolt", Text = "MaUI Hub" })
island:SetMetric(1, { Name = "FPS", Value = 0 })
island:SetMetric(2, { Name = "Ping", Value = 0 })
island:StartSessionClock()
task.spawn(function()
	while not window.Destroyed do
		island:PushMetric(2, readPing())
		task.wait(1)
	end
end)

-- Settings (interface, keybinds, theme editor, configs) is added automatically; load the autoloaded config:
ui:LoadAutoload()
ui:Notify({ Title = "MaUI Hub", Content = "Loaded. Press RightControl to hide the window.", Type = "Success" })
