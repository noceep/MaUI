-- Metric: compact stat block: icon + overline label, large value, secondary text, mini visualization.
--   AddMetric({ Name = "FPS", Icon = "bolt", Value = 60, Secondary = "avg 58", Trend = "up",
--               Status = "success", Viz = "Bars", Samples = { 55, 58, 60 }, Max = 120,
--               Format = function(value) return string.format("%d fps", value) end })
--   metric:Set(61)  :Push(62)  :SetSecondary("avg 59")  :SetTrend(-3)  :SetStatus("warning")  :Clear()
-- Trend: "up" | "down" | a number delta (arrow glyph + text, never color alone).
-- Status: success | warning | error | info | muted (or a raw theme token name), colors the value.
-- Viz: "Bars" | "Segments" | "Progress" | "Graph" | nil.
--   Bars / Graph : a FIXED pool of 24 bar frames used as a ring. Push(value) shifts the heights, it never
--                  creates or destroys an instance. The newest bar uses the status/Accent color.
--   Progress     : track + fill (value / Max).
--   Segments     : 10 discrete segments lit proportionally to value / Max.
-- Max defaults to 100 for Progress/Segments; Bars/Graph auto-scale when Max is omitted.
-- Never saved in configs (Persistent = false).
local Element = require("Core/Element")
local Icons = require("Core/Icons")
local Kit = require("Core/Kit")
local Tokens = require("Core/Tokens")
local Util = require("Core/Util")

local Create = Util.Create

local Metric = Element.extend("Metric")
Metric.Persistent = false

local POOL = 24
local SEGMENTS = 10
local VIZ_HEIGHT = 30
local VIZS = { Bars = true, Segments = true, Progress = true, Graph = true }
local STATUS_TOKENS = { success = "Success", warning = "Warning", error = "Error", info = "Info", muted = "Muted" }

function Metric.new(ctx, options, parent, order)
	options = Util.Options(options, { Name = "Metric" })
	local self = setmetatable({}, Metric)
	Element.init(self, ctx, options)

	if options.Viz ~= nil and not VIZS[options.Viz] then
		warn("[MaUI] Metric '" .. tostring(options.Name) .. "': unknown Viz '" .. tostring(options.Viz) .. "'")
		options.Viz = nil
	end
	self.Viz = options.Viz
	self.MaxValue = tonumber(options.Max)
	self.Samples = {}
	self.SampleCount = 0
	self._head = 0
	self.Status = nil
	self.Trend = nil

	self.Frame = Create("Frame", {
		Name = options.Name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.Padding(self.Frame, 0, 0, Tokens.Space.Sm, Tokens.Space.Sm)
	Kit.List(self.Frame, Tokens.Space.Xs)

	-- header: icon + overline label on the left, trend on the right
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = self.Frame,
	})
	local left = 0
	self.Icon = options.Icon and Icons.Create(ctx, {
		Icon = options.Icon,
		Size = 14,
		Color = "Muted",
		Position = UDim2.fromOffset(0, 1),
		Parent = header,
	})
	if self.Icon then
		left = 20
	end
	self.Title = Kit.Text(ctx, {
		Name = "Title",
		Text = string.upper(tostring(options.Name)),
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + 70), 1, 0),
		TextSize = Tokens.Type.Caption.Size,
	}, "Muted", "Bold")
	self.Title.Parent = header
	self.TrendLabel = Kit.Text(ctx, {
		Name = "Trend",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(66, 16),
		TextSize = Tokens.Type.Supporting.Size,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = header,
	}, function(t)
		return self:_trendColor(t)
	end, "Bold")

	self.ValueLabel = Kit.Text(ctx, {
		Name = "Value",
		Size = UDim2.new(1, 0, 0, Tokens.Type.Display.Size + 6),
		TextSize = Tokens.Type.Display.Size,
		LayoutOrder = 2,
		Parent = self.Frame,
	}, function(t)
		return self:_valueColor(t)
	end, "Bold")

	self.SecondaryLabel = Kit.Text(ctx, {
		Name = "Secondary",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = Tokens.Type.Supporting.Size,
		Visible = false,
		LayoutOrder = 3,
		Parent = self.Frame,
	}, "Muted", "Regular")

	if self.Viz then
		self:_buildViz()
	end
	self:SetStatus(options.Status)
	self:SetSecondary(options.Secondary)
	self:SetTrend(options.Trend)

	self:_init(options.Value)
	if type(options.Samples) == "table" and (self.Viz == "Bars" or self.Viz == "Graph") then
		for _, sample in ipairs(options.Samples) do
			self:_pushSample(sample)
		end
		self:_paintBars()
	end
	return self
end

-- Colors ---------------------------------------------------------------------------------------

function Metric:_statusToken()
	local status = self.Status
	if not status then
		return nil
	end
	return STATUS_TOKENS[status] or status
end

function Metric:_valueColor(theme)
	local token = self:_statusToken()
	if token and theme:Get(token) then
		return theme:Get(token)
	end
	return theme:Get("Text")
end

function Metric:_vizColor(theme)
	local token = self:_statusToken()
	if token and token ~= "Muted" and theme:Get(token) then
		return theme:Get(token)
	end
	return theme:Get("Accent")
end

function Metric:_trendColor(theme)
	local trend = self.Trend
	if trend == "up" or (type(trend) == "number" and trend > 0) then
		return theme:Get("Success")
	elseif trend == "down" or (type(trend) == "number" and trend < 0) then
		return theme:Get("Error")
	end
	return theme:Get("Muted")
end

-- Visualization --------------------------------------------------------------------------------

function Metric:_buildViz()
	local ctx = self.Ctx
	self.VizFrame = Create("Frame", {
		Name = "Viz",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, self.Viz == "Progress" and 6 or VIZ_HEIGHT),
		LayoutOrder = 4,
		Parent = self.Frame,
	})
	if self.Viz == "Progress" then
		local track = Kit.Frame(ctx, {
			Name = "Track",
			Size = UDim2.new(1, 0, 0, 6),
			Parent = self.VizFrame,
		}, "Surface3")
		Kit.Corner(track, Tokens.Radius.Pill)
		self.Fill = Create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BorderSizePixel = 0,
			Parent = track,
		})
		ctx.Theme:Bind(self.Fill, "BackgroundColor3", function(t)
			return self:_vizColor(t)
		end)
		Kit.Corner(self.Fill, Tokens.Radius.Pill)
	elseif self.Viz == "Segments" then
		self.Segs = {}
		local width = 1 / SEGMENTS
		for i = 1, SEGMENTS do
			local seg = Create("Frame", {
				Name = "Segment",
				Position = UDim2.new((i - 1) * width, 1, 0, 0),
				Size = UDim2.new(width, -2, 0, 8),
				BorderSizePixel = 0,
				Parent = self.VizFrame,
			})
			ctx.Theme:Bind(seg, "BackgroundColor3", function(t)
				return (self._lit or 0) >= i and self:_vizColor(t) or t:Get("Surface3")
			end)
			Kit.Corner(seg, 2)
			self.Segs[i] = seg
		end
	else
		-- Bars / Graph: fixed pool of POOL frames, never created or destroyed again
		self.Bars = {}
		local ratio = self.Viz == "Graph" and 0.45 or 0.8
		local slot = 1 / POOL
		for i = 1, POOL do
			local bar = Create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new((i - 1) * slot + slot * (1 - ratio) / 2, 0, 1, 0),
				Size = UDim2.new(slot * ratio, 0, 0.06, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0.6,
				Parent = self.VizFrame,
			})
			ctx.Theme:Bind(bar, "BackgroundColor3", function(t)
				if i == POOL and self.SampleCount > 0 then
					return self:_vizColor(t)
				end
				return t:Get(self.Viz == "Graph" and "Faint" or "Surface3")
			end)
			Kit.Corner(bar, 2)
			self.Bars[i] = bar
		end
	end
end

-- Writes a sample in the ring (no instance work).
function Metric:_pushSample(value)
	value = tonumber(value)
	if not value or value ~= value then
		return false
	end
	self._head = self._head % POOL + 1
	self.Samples[self._head] = value
	self.SampleCount = math.min(self.SampleCount + 1, POOL)
	return true
end

-- Repaints the pooled bars from the ring: position i shows the sample (POOL - i) steps old.
function Metric:_paintBars()
	local bars = self.Bars
	if not bars then
		return
	end
	local ceiling = self.MaxValue
	if not ceiling then
		ceiling = 0
		for _, sample in pairs(self.Samples) do
			ceiling = math.max(ceiling, sample)
		end
	end
	if ceiling <= 0 then
		ceiling = 1
	end
	local theme = self.Ctx.Theme
	for i = 1, POOL do
		local age = POOL - i
		local bar = bars[i]
		if age < self.SampleCount then
			local index = (self._head - 1 - age) % POOL + 1
			local fraction = Util.Clamp(self.Samples[index] / ceiling, 0.06, 1)
			bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, fraction, 0)
			bar.BackgroundTransparency = 0
		else
			bar.Size = UDim2.new(bar.Size.X.Scale, bar.Size.X.Offset, 0.06, 0)
			bar.BackgroundTransparency = 0.6
		end
		bar.BackgroundColor3 = (i == POOL and self.SampleCount > 0) and self:_vizColor(theme)
			or theme:Get(self.Viz == "Graph" and "Faint" or "Surface3")
	end
end

function Metric:_repaintViz(animate)
	local numeric = tonumber(self.Value)
	if self.Viz == "Progress" and self.Fill then
		local alpha = numeric and Util.Clamp(numeric / (self.MaxValue or 100), 0, 1) or 0
		self.Ctx.Tween:To(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, animate and Tokens.Motion.Base or 0)
	elseif self.Viz == "Segments" and self.Segs then
		local alpha = numeric and Util.Clamp(numeric / (self.MaxValue or 100), 0, 1) or 0
		self._lit = math.floor(alpha * SEGMENTS + 0.5)
		local theme = self.Ctx.Theme
		for i, seg in ipairs(self.Segs) do
			seg.BackgroundColor3 = self._lit >= i and self:_vizColor(theme) or theme:Get("Surface3")
		end
	elseif self.Bars then
		self:_paintBars()
	end
end

-- Element hooks --------------------------------------------------------------------------------

function Metric:_normalize(value)
	if value == nil then
		return nil
	end
	if type(value) == "number" and value ~= value then
		return nil
	end
	return value
end

function Metric:_format(value)
	local format = self.Options.Format
	if type(format) == "function" then
		local ok, text = pcall(format, value)
		if ok then
			return tostring(text)
		end
		warn("[MaUI] Metric Format error: " .. tostring(text))
	end
	local number = type(value) == "number" and tonumber(value) or nil
	if number then
		if number == math.floor(number) then
			return tostring(number)
		end
		return string.format("%.2f", number)
	end
	return tostring(value)
end

function Metric:_render(value, animate)
	self.ValueLabel.Text = self:_format(value)
	if self.Viz == "Progress" or self.Viz == "Segments" then
		self:_repaintViz(animate)
	end
end

-- Public API -----------------------------------------------------------------------------------

function Metric:Push(value)
	if self.Destroyed then
		return
	end
	local number = tonumber(value)
	if not number or number ~= number then
		warn("[MaUI] Metric:Push expects a number")
		return
	end
	if self.Bars then
		self:_pushSample(number)
	end
	self.Value = number
	self:_render(number, true)
	if self.Bars then
		self:_paintBars()
	end
end

function Metric:SetSecondary(text)
	if self.Destroyed then
		return
	end
	local has = text ~= nil and text ~= ""
	self.SecondaryLabel.Visible = has
	self.SecondaryLabel.Text = has and tostring(text) or ""
end

function Metric:SetTrend(trend)
	if self.Destroyed then
		return
	end
	local glyph, text
	if trend == "up" then
		glyph, text = "▲", "Up"
	elseif trend == "down" then
		glyph, text = "▼", "Down"
	elseif type(trend) == "number" and trend == trend then
		if trend > 0 then
			glyph, text = "▲", "+" .. self:_formatDelta(trend)
		elseif trend < 0 then
			glyph, text = "▼", "-" .. self:_formatDelta(-trend)
		else
			glyph, text = "▬", "0"
		end
	else
		trend = nil
	end
	self.Trend = trend
	self.TrendLabel.Visible = trend ~= nil
	self.TrendLabel.Text = trend ~= nil and (glyph .. " " .. text) or ""
	self.TrendLabel.TextColor3 = self:_trendColor(self.Ctx.Theme)
end

function Metric:_formatDelta(delta)
	if delta == math.floor(delta) then
		return tostring(delta)
	end
	return string.format("%.1f", delta)
end

function Metric:SetStatus(status)
	if self.Destroyed then
		return
	end
	if status ~= nil and not STATUS_TOKENS[status] and self.Ctx.Theme:Get(status) == nil then
		warn("[MaUI] Metric: unknown Status '" .. tostring(status) .. "'")
		status = nil
	end
	self.Status = status
	self.ValueLabel.TextColor3 = self:_valueColor(self.Ctx.Theme)
	if self.Viz then
		self:_repaintViz(false)
	end
end

function Metric:Clear()
	if self.Destroyed then
		return
	end
	self.Samples = {}
	self.SampleCount = 0
	self._head = 0
	self.Value = nil
	self.ValueLabel.Text = "–"
	if self.Viz == "Progress" or self.Viz == "Segments" then
		self:_repaintViz(false)
	else
		self:_paintBars()
	end
end

function Metric:Serialize()
	return nil
end

function Metric:Deserialize() end

return Metric
