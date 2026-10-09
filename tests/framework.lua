-- Tiny test framework: sections, checks, metrics and a JSON report.
--   T.section("Window")                 starts a section (a spec file usually has one or more)
--   T.check("name", condition, detail)  records one verification
--   T.metric("key", value, "unit")      records a measurement for the report
-- Nothing here depends on the library under test.
local T = { sections = {}, current = nil, metrics = {}, metricUnits = {}, skipped = {} }

function T.section(name)
	local section = { name = name, passed = 0, failures = {}, names = {} }
	T.sections[#T.sections + 1] = section
	T.current = section
	print("• " .. name)
end

function T.check(name, condition, detail)
	local section = T.current
	section.names[#section.names + 1] = name
	if condition then
		section.passed = section.passed + 1
	else
		section.failures[#section.failures + 1] = name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")
	end
end

-- Check that `fn` raises an error whose message contains `needle` (plain text).
function T.raises(name, fn, needle)
	local ok, err = pcall(fn)
	local matched = not ok and (needle == nil or tostring(err):find(needle, 1, true) ~= nil)
	T.check(name, matched, ok and "no error was raised" or err)
end

function T.metric(key, value, unit)
	T.metrics[key] = value
	T.metricUnits[key] = unit
end

function T.skip(reason)
	T.skipped[#T.skipped + 1] = { section = T.current and T.current.name or "?", reason = reason }
end

function T.totals()
	local passed, failed = 0, 0
	for _, section in ipairs(T.sections) do
		passed = passed + section.passed
		failed = failed + #section.failures
	end
	return passed, failed
end

-- JSON encoding (strings, numbers, booleans, arrays, objects with sorted keys) ----------------------
local function escape(text)
	return (
		text:gsub('[%c"\\]', function(char)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[char] or string.format("\\u%04x", char:byte())
		end)
	)
end

local function encode(value)
	local kind = type(value)
	if kind == "table" then
		if #value > 0 or next(value) == nil then
			local parts = {}
			for index, item in ipairs(value) do
				parts[index] = encode(item)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = tostring(key)
		end
		table.sort(keys)
		local parts = {}
		for _, key in ipairs(keys) do
			local item = value[key]
			if item == nil then
				item = value[tonumber(key)]
			end
			parts[#parts + 1] = '"' .. escape(key) .. '":' .. encode(item)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return '"' .. escape(value) .. '"'
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		return string.format("%.6g", value)
	elseif kind == "boolean" then
		return tostring(value)
	end
	return "null"
end

function T.toJson(extra)
	local sections = {}
	for index, section in ipairs(T.sections) do
		sections[index] = {
			name = section.name,
			passed = section.passed,
			failed = #section.failures,
			failures = section.failures,
			checks = section.names,
		}
	end
	local passed, failed = T.totals()
	local report = {
		sections = sections,
		passed = passed,
		failed = failed,
		metrics = T.metrics,
		metricUnits = T.metricUnits,
		skipped = T.skipped,
	}
	for key, value in pairs(extra or {}) do
		report[key] = value
	end
	return encode(report)
end

return T
