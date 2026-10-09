-- ConfigManager: ready-made card to manage saved configurations.
--   section:AddConfigManager({ Title = "Configs" })
-- Create / Save / Load / Rename / Delete / Reset, autoload, and import / export through a shareable code.
-- Destructive actions (Delete, Reset) ask for a second click. Every result is reported with a notification.
local Section = require("Components/Section")
local Util = require("Core/Util")
local Env = require("Core/Env")

local ConfigManager = {}
ConfigManager.__index = ConfigManager
ConfigManager.Persistent = false

function ConfigManager.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "Configs", Icon = "folder" }, "Title")
	local self = setmetatable({}, ConfigManager)
	local library = ctx.Library
	self.Options = options
	self.Section = Section.new(ctx, { Name = options.Title, Icon = options.Icon, Variant = "Settings" }, parent, order)
	self.Frame = self.Section.Frame
	local card = self.Section

	local function notify(title, content, kind)
		library:Notify({ Title = title, Content = content, Type = kind })
	end
	local function report(ok, err, okTitle, name, failTitle)
		if ok then
			notify(okTitle, name, "Success")
		else
			notify(failTitle, tostring(err), "Error")
		end
		return ok
	end

	self.NameBox = card:AddTextBox({ Name = "Name", Placeholder = "config name", Width = 160 })
	self.List = card:AddDropdown({ Name = "Saved", Items = library:ListConfigs(), Placeholder = "none", Width = 160 })
	self.Status = card:AddLabel({ Text = "" })

	local function refresh(select)
		self.List:SetItems(library:ListConfigs())
		if select then
			self.List:Set(select, true)
		end
		local loaded = library.ConfigName
		local autoload = library:GetAutoload()
		self.Status:SetText("loaded: " .. tostring(loaded or "none") .. "  |  autoload: " .. tostring(autoload or "none"))
	end
	self.Refresh = refresh
	local function typedOrSelected()
		local typed = Util.Trim(self.NameBox:Get() or "")
		if typed ~= "" then
			return typed
		end
		return self.List:Get()
	end
	local function selected()
		return self.List:Get() or typedOrSelected()
	end

	local a = card:AddColumns(2)
	a[1]:AddButton({ Name = "Create", Icon = "plus", Callback = function()
		local name = Util.Trim(self.NameBox:Get() or "")
		if name == "" then
			return notify("Name required", "Type a name for the new config", "Warning")
		end
		if report(library:SaveConfig(name)) then
			notify("Config created", name, "Success")
		end
		refresh(name)
	end })
	a[2]:AddButton({ Name = "Save", Icon = "check", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config or type a name", "Warning")
		end
		local ok, err = library:SaveConfig(name)
		report(ok, err, "Config saved", name, "Could not save")
		refresh(name)
	end })
	local b = card:AddColumns(2)
	b[1]:AddButton({ Name = "Load", Icon = "folder", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config first", "Warning")
		end
		local ok, err = library:LoadConfig(name)
		report(ok, err, "Config loaded", name, "Could not load")
		refresh()
	end })
	b[2]:AddButton({ Name = "Rename", Icon = "settings", Callback = function()
		local new = Util.Trim(self.NameBox:Get() or "")
		local old = self.List:Get()
		if not old or new == "" then
			return notify("Rename", "Pick a config and type the new name", "Warning")
		end
		local ok, err = library:RenameConfig(old, new)
		report(ok, err, "Config renamed", new, "Could not rename")
		refresh(ok and new or nil)
	end })
	local c = card:AddColumns(2)
	c[1]:AddButton({ Name = "Delete", Style = "Destructive", Confirm = true, Icon = "close", Callback = function()
		local name = self.List:Get()
		if not name then
			return notify("Nothing selected", "Pick a config to delete", "Warning")
		end
		local ok, err = library:DeleteConfig(name)
		report(ok, err, "Config deleted", name, "Could not delete")
		if ok and library:GetAutoload() == name then
			library:SetAutoload(nil)
		end
		refresh()
		self.List:Set(nil, true)
	end })
	c[2]:AddButton({ Name = "Reset", Style = "Destructive", Confirm = true, Icon = "refresh", Callback = function()
		local count = library:ResetConfig()
		notify("Defaults restored", count .. " settings reset", "Info")
	end })
	local d = card:AddColumns(2)
	d[1]:AddButton({ Name = "Set autoload", Icon = "star", Callback = function()
		local name = selected()
		if not name then
			return notify("Nothing selected", "Pick a config first", "Warning")
		end
		local ok, err = library:SetAutoload(name)
		report(ok, err, "Autoload set", name, "Could not set autoload")
		refresh()
	end })
	d[2]:AddButton({ Name = "Clear autoload", Callback = function()
		library:SetAutoload(nil)
		notify("Autoload cleared", "No config loads automatically", "Info")
		refresh()
	end })

	self.Code = card:AddTextBox({ Name = "Config code", Placeholder = "paste a code here", Width = 160 })
	local e = card:AddColumns(2)
	e[1]:AddButton({ Name = "Export", Icon = "copy", Callback = function()
		local code, err = library:ExportConfig()
		if not code then
			return notify("Could not export", tostring(err), "Error")
		end
		self.Code:Set(code, true)
		if Env.SetClipboard and Env.SetClipboard(code) then
			notify("Config copied", "The code is in your clipboard", "Success")
		else
			notify("Config code ready", "Copy it from the field above", "Info")
		end
	end })
	e[2]:AddButton({ Name = "Import", Icon = "play", Callback = function()
		local ok, err = library:ImportConfig(self.Code:Get() or "")
		report(ok, err, "Config imported", "values applied", "Could not import")
	end })
	refresh()
	return self
end

function ConfigManager:Destroy()
	self.Section:Destroy()
end

function ConfigManager:SetVisible(visible)
	self.Section:SetVisible(visible)
end

return ConfigManager
