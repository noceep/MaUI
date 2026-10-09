-- SearchBox: lightweight search field (icon, placeholder, text, focus/filled/disabled states, clear button).
--   local box = SearchBox.new(ctx, parent, { Placeholder = "Search", Width = 180, OnChanged = function(text) end })
--   box:Get() / box:Set("abc") / box:Clear() / box:SetDisabled(true) / box.Changed:Connect(fn)
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Maid = require("Core/Maid")
local Signal = require("Core/Signal")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create
local SearchBox = {}
SearchBox.__index = SearchBox

function SearchBox.new(ctx, parent, options)
	options = Util.Options(options, { Placeholder = "Search", Width = 180 }, "Placeholder")
	local self = setmetatable({}, SearchBox)
	self.Ctx = ctx
	self.Maid = Maid.new()
	self.Changed = Signal.new()
	self.Maid:Give(self.Changed)
	self.Disabled = false
	self.Focused = false
	local theme = ctx.Theme

	self.Frame = Create("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(options.Width, ctx.Metrics.Compact + 4),
		BorderSizePixel = 0,
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
	})
	theme:Bind(self.Frame, "BackgroundColor3", "Surface")
	Kit.Corner(self.Frame, Tokens.Radius.Md)
	self.Stroke = Kit.Stroke(ctx, self.Frame, "Stroke")

	self.Icon = Icons.Create(ctx, {
		Icon = "search", Size = 14, Color = "Muted",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = self.Frame,
	})
	self.Box = Create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = "",
		PlaceholderText = options.Placeholder,
		ClearTextOnFocus = false,
		TextSize = Tokens.Type.Supporting.Size + 1,
		FontFace = ctx.Fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.Frame,
	})
	theme:Bind(self.Box, "TextColor3", "Text")
	theme:Bind(self.Box, "PlaceholderColor3", "Faint")

	self.ClearButton = Kit.IconButton(ctx, self.Maid, {
		Name = "Clear", Icon = "close", IconSize = 11, Size = 20, Tooltip = "Clear",
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Parent = self.Frame,
		Callback = function()
			self:Clear()
		end,
	})
	self.ClearButton.Visible = false

	self.Maid:Give(self.Box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = self.Box.Text
		self.ClearButton.Visible = text ~= ""
		self.Changed:Fire(text)
		Util.Call(options.OnChanged, text)
	end))
	self.Maid:Give(self.Box.Focused:Connect(function()
		self.Focused = true
		ctx.Tween:To(self.Stroke, { Color = theme:Get("Accent") }, Tokens.Motion.Fast)
		if self.Icon then
			ctx.Tween:To(self.Icon, { [Icons.ColorProperty(self.Icon)] = theme:Get("Accent") }, Tokens.Motion.Fast)
		end
	end))
	self.Maid:Give(self.Box.FocusLost:Connect(function()
		self.Focused = false
		ctx.Tween:To(self.Stroke, { Color = theme:Get("Stroke") }, Tokens.Motion.Base)
		if self.Icon then
			ctx.Tween:To(self.Icon, { [Icons.ColorProperty(self.Icon)] = theme:Get("Muted") }, Tokens.Motion.Base)
		end
	end))
	return self
end

function SearchBox:Get()
	return self.Box.Text
end

function SearchBox:Set(text)
	self.Box.Text = tostring(text or "")
end

function SearchBox:Clear()
	self.Box.Text = ""
end

function SearchBox:SetDisabled(disabled)
	self.Disabled = disabled == true
	self.Box.TextEditable = not self.Disabled
	self.Frame.BackgroundTransparency = self.Disabled and 0.5 or 0
	self.Box.TextTransparency = self.Disabled and 0.5 or 0
end

function SearchBox:SetVisible(visible)
	self.Frame.Visible = visible
end

function SearchBox:Destroy()
	self.Maid:Clean()
	self.Ctx.Theme:Release(self.Frame)
	self.Frame:Destroy()
end

return SearchBox
