-- ThemeEditor: ready-made card to customize and manage themes with a live preview.
--   section:AddThemeEditor({ Title = "Theme", Tokens = { "Accent", "Background", "Surface", "Text", "Muted" } })
-- Contents: theme selector, one color picker per token (changes recolor the whole UI immediately),
-- a name field and Save / Load / Delete / Set default buttons (custom themes live in <ConfigFolder>/themes).
local Section = require("Components/Section")
local Util = require("Core/Util")

local ThemeEditor = {}
ThemeEditor.__index = ThemeEditor
ThemeEditor.Persistent = false

local DEFAULT_TOKENS = { "Accent", "Background", "Surface", "Text", "Muted" }

function ThemeEditor.new(ctx, options, parent, order)
	options = Util.Options(options, { Title = "Theme", Icon = "palette", Tokens = DEFAULT_TOKENS }, "Title")
	local self = setmetatable({}, ThemeEditor)
	local library, theme = ctx.Library, ctx.Theme
	self.Options = options
	self.Ctx = ctx
	self.Section = Section.new(ctx, { Name = options.Title, Icon = options.Icon, Variant = "Settings", Desc = "Colors update live" }, parent, order)
	self.Frame = self.Section.Frame
	self.Pickers = {}
	local card = self.Section

	local function notify(title, content, kind)
		library:Notify({ Title = title, Content = content, Type = kind })
	end
	local function names()
		return theme:List()
	end

	self.Selector = card:AddDropdown({
		Name = "Theme", Items = names(), Default = theme.Name, Callback = function(name)
			if theme.Name ~= name then
				library:SetTheme(name)
			end
		end,
	})
	for _, token in ipairs(options.Tokens) do
		if theme:Get(token) then
			self.Pickers[token] = card:AddColorPicker({
				Name = token, Default = theme:Get(token), Callback = function(color)
					if not self._refreshing then
						theme:SetToken(token, color)
					end
				end,
			})
		end
	end
	self.NameBox = card:AddTextBox({ Name = "Save as", Placeholder = "theme name", Width = 150 })

	local function refreshSelector()
		self.Selector:SetItems(names())
		self.Selector:Set(theme.Name, true)
	end
	local function currentName()
		local typed = Util.Trim(self.NameBox:Get() or "")
		return typed ~= "" and typed or theme.Name
	end
	local columns = card:AddColumns(2)
	columns[1]:AddButton({ Name = "Save", Icon = "check", Callback = function()
		local name = currentName()
		local ok, err = library:SaveTheme(name)
		if ok then
			refreshSelector()
			notify("Theme saved", name, "Success")
		else
			notify("Could not save theme", tostring(err), "Error")
		end
	end })
	columns[2]:AddButton({ Name = "Load", Icon = "folder", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:LoadTheme(name)
		if ok then
			notify("Theme loaded", name, "Info")
		elseif theme:Has(name) then
			library:SetTheme(name)
		else
			notify("Could not load theme", tostring(err), "Error")
		end
	end })
	local second = card:AddColumns(2)
	second[1]:AddButton({ Name = "Delete", Style = "Destructive", Confirm = true, Icon = "close", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:DeleteTheme(name)
		if ok then
			library:SetTheme("Sakura")
			refreshSelector()
			notify("Theme deleted", name, "Warning")
		else
			notify("Could not delete theme", tostring(err), "Error")
		end
	end })
	second[2]:AddButton({ Name = "Set default", Icon = "star", Callback = function()
		local name = self.Selector:Get() or theme.Name
		local ok, err = library:SetDefaultTheme(name)
		if ok then
			notify("Default theme", name .. " will load at startup", "Success")
		else
			notify("Could not set default", tostring(err), "Error")
		end
	end })

	-- keep pickers in sync when the theme changes from anywhere else (SetTheme, load...)
	self._connection = theme.Changed:Connect(function(name)
		self._refreshing = true
		for token, picker in pairs(self.Pickers) do
			picker:Set(theme:Get(token), true)
		end
		if self.Selector.Frame and self.Selector:Get() ~= name then
			self.Selector:Set(name, true)
		end
		self._refreshing = false
	end)
	return self
end

function ThemeEditor:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self.Section:Destroy()
end

function ThemeEditor:SetVisible(visible)
	self.Section:SetVisible(visible)
end

return ThemeEditor
