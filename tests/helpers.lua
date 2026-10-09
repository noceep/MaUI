-- Helpers shared by the spec files.
-- Globals provided by tests/run.py: TARGET ("dist" | "src"), DIST_SOURCE, SRC_READ(name), COVERAGE (bool).
local H = { _libraries = {}, _counter = 0 }

-- Loading the library under test -----------------------------------------------------------------

-- Loads a source module through the same lazy `require` the bundler uses, so every spec can run against
-- either the shipped bundle (dist) or the individual source files (src, which enables coverage).
local sourceCache = {}
local function sourceRequire(name)
	local cached = sourceCache[name]
	if cached ~= nil then
		return cached
	end
	local source = SRC_READ(name)
	assert(source, "module not found: " .. name)
	local chunk, err = loadstring(source, "@" .. name .. ".lua")
	assert(chunk, err)
	setfenv(chunk, setmetatable({ require = sourceRequire }, { __index = _G }))
	local result = chunk()
	if result == nil then
		result = true
	end
	sourceCache[name] = result
	return result
end

-- A fresh copy of the library (new module state) from the selected target.
function H.loadLibrary()
	if TARGET == "dist" then
		return assert(loadstring(DIST_SOURCE, "=MaUI.lua"))()
	end
	sourceCache = {}
	return sourceRequire("init")
end

-- Internal modules (Signal, Maid, Util, Theme...) for unit tests. Source target only.
function H.module(name)
	if TARGET ~= "src" then
		return nil
	end
	return sourceRequire(name)
end

-- Library instances ---------------------------------------------------------------------------------

-- Creates a library with a deterministic clock (driven by M.advance) and a unique config folder.
-- Instances are tracked so a spec can destroy everything it created.
function H.newLibrary(MaUI, options)
	H._counter = H._counter + 1
	options = options or {}
	if options.ConfigFolder == nil then
		options.ConfigFolder = "Test" .. H._counter
	end
	if options.Clock == nil then
		options.Clock = function()
			return M.now
		end
	end
	local library = MaUI.new(options)
	H._libraries[#H._libraries + 1] = library
	return library
end

function H.destroyAll()
	for index = #H._libraries, 1, -1 do
		H._libraries[index]:Destroy()
		H._libraries[index] = nil
	end
end

-- Instances and input -------------------------------------------------------------------------------------

function H.find(root, name)
	return M.find(root, name)
end

function H.click(instance)
	instance.MouseButton1Click:Fire()
end

-- Number of live connections on the three global input signals: (began, changed, ended).
function H.inputCounts()
	return M.UIS.InputBegan:ActiveCount(), M.UIS.InputChanged:ActiveCount(), M.UIS.InputEnded:ActiveCount()
end

function H.pointerDown(instance, x, y)
	instance.InputBegan:Fire(M.input("MouseButton1", { Position = Vector2.new(x or 0, y or 0) }))
end

function H.pointerMove(x, y, deltaX, deltaY)
	M.UIS.InputChanged:Fire(M.input("MouseMovement", {
		Position = Vector2.new(x or 0, y or 0),
		Delta = Vector3.new(deltaX or 0, deltaY or 0, 0),
	}))
end

function H.pointerUp()
	M.UIS.InputEnded:Fire(M.input("MouseButton1"))
end

-- Clears the recorded warnings and returns them after running fn.
function H.collectWarnings(fn)
	M.warnings = {}
	fn()
	local collected = M.warnings
	M.warnings = {}
	return collected
end

function H.contains(list, needle)
	for _, item in ipairs(list) do
		if tostring(item):find(needle, 1, true) then
			return true
		end
	end
	return false
end

-- Enables line coverage: every executed line of every "@Module.lua" chunk is recorded in M.coverage.
function H.enableCoverage()
	local hits = {}
	M.coverage = hits
	local getinfo = debug.getinfo
	M.hook = function(_, line)
		local source = getinfo(2, "S").source
		if source:sub(1, 1) == "@" then
			local file = hits[source]
			if not file then
				file = {}
				hits[source] = file
			end
			file[line] = true
		end
	end
	debug.sethook(M.hook, "l")
	if jit then
		jit.off() -- line hooks need the interpreter
	end
end

return H
