-- Container: adds the AddXxx methods to a class (Tab, Section).
-- Contract: the class provides self.Ctx, self.Content (parent Instance), self.Maid,
--           self.Elements (list) and self._order (LayoutOrder counter).
local Button = require("Components/Button")
local Changelog = require("Components/Changelog")
local KeyStatus = require("Components/KeyStatus")
local Keybind = require("Components/Keybind")
local Label = require("Components/Label")
local Paragraph = require("Components/Paragraph")
local Profile = require("Components/Profile")
local Slider = require("Components/Slider")
local Toggle = require("Components/Toggle")

local Container = {}

function Container.apply(class)
	function class:_AddElement(componentClass, options)
		self._order = self._order + 1
		local element = componentClass.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = element
		self.Maid:Give(element)
		return element
	end

	-- Cards, column layouts and sub-tabs (required lazily: Section/Columns/SubTabs themselves use Container).
	function class:AddSection(options)
		local Section = require("Components/Section")
		self._order = self._order + 1
		local section = Section.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = section
		self.Maid:Give(section)
		self._plain = nil
		return section
	end
	class.AddCard = class.AddSection

	function class:AddColumns(options)
		local Columns = require("Components/Columns")
		self._order = self._order + 1
		local columns = Columns.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = columns
		self.Maid:Give(columns)
		self._plain = nil
		return Columns.array(columns)
	end

	function class:AddSubTabs(options)
		local SubTabs = require("Components/SubTabs")
		self._order = self._order + 1
		local group = SubTabs.new(self.Ctx, options, self.Content, self._order)
		self.Elements[#self.Elements + 1] = group
		self.Maid:Give(group)
		self._plain = nil
		return group
	end

	-- Components below are required lazily so each can use Container itself and so a missing optional
	-- component never breaks loading of the others.
	local function lazy(methodName, moduleName)
		class[methodName] = function(self, options)
			return self:_AddElement(require(moduleName), options)
		end
	end
	lazy("AddDropdown", "Components/Dropdown")
	lazy("AddTextBox", "Components/TextBox")
	lazy("AddColorPicker", "Components/ColorPicker")
	lazy("AddMetric", "Components/Metric")
	lazy("AddDataRow", "Components/DataRow")
	lazy("AddKeycap", "Components/Keycap")
	lazy("AddThemeEditor", "Components/ThemeEditor")
	lazy("AddConfigManager", "Components/ConfigManager")

	function class:AddToggle(options)
		return self:_AddElement(Toggle, options)
	end

	function class:AddSlider(options)
		return self:_AddElement(Slider, options)
	end

	function class:AddLabel(options)
		return self:_AddElement(Label, options)
	end

	function class:AddButton(options)
		return self:_AddElement(Button, options)
	end

	function class:AddKeybind(options)
		return self:_AddElement(Keybind, options)
	end

	function class:AddParagraph(options)
		return self:_AddElement(Paragraph, options)
	end

	function class:AddProfile(options)
		return self:_AddElement(Profile, options)
	end

	function class:AddKeyStatus(options)
		return self:_AddElement(KeyStatus, options)
	end

	function class:AddChangelog(options)
		return self:_AddElement(Changelog, options)
	end
end

return Container
