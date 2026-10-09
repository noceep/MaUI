-- Env: platform adapter. The rest of the lib never calls
-- gethui / writefile / etc. directly: everything goes through here (and stays optional).
local Env = {}

local function lookup(name)
	local ok, value = pcall(function()
		return getfenv(0)[name]
	end)
	if ok and value ~= nil then
		return value
	end
	local okGenv, genv = pcall(function()
		return getgenv()
	end)
	if okGenv and type(genv) == "table" and genv[name] ~= nil then
		return genv[name]
	end
	return _G[name]
end

-- gethui() -> CoreGui -> PlayerGui. `preferred` forces a specific parent.
function Env.GetParent(preferred)
	if preferred then
		return preferred
	end
	local gethui = lookup("gethui")
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and coreGui then
		local writable = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = coreGui
			probe:Destroy()
		end)
		if writable then
			return coreGui
		end
	end
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

function Env.IsTouch()
	local service = game:GetService("UserInputService")
	return service.TouchEnabled and not service.KeyboardEnabled
end

-- Clipboard (optional). Returns true if the text was copied.
function Env.SetClipboard(text)
	for _, name in ipairs({ "setclipboard", "toclipboard" }) do
		local fn = lookup(name)
		if type(fn) == "function" then
			local ok = pcall(fn, text)
			if ok then
				return true
			end
		end
	end
	return false
end

-- Files (optional) ------------------------------------------------------

function Env.HasFS()
	return type(lookup("writefile")) == "function"
		and type(lookup("readfile")) == "function"
		and type(lookup("isfile")) == "function"
end

local function call(name, ...)
	local fn = lookup(name)
	if type(fn) ~= "function" then
		return false, name .. " unavailable"
	end
	return pcall(fn, ...)
end

function Env.EnsureFolder(path)
	local isfolder, makefolder = lookup("isfolder"), lookup("makefolder")
	if type(isfolder) == "function" and type(makefolder) == "function" then
		local ok, exists = pcall(isfolder, path)
		if ok and not exists then
			pcall(makefolder, path)
		end
	end
end

function Env.WriteFile(path, data)
	return call("writefile", path, data)
end

-- Returns ok, content|error
function Env.ReadFile(path)
	return call("readfile", path)
end

function Env.IsFile(path)
	local ok, result = call("isfile", path)
	return ok and result == true
end

function Env.DeleteFile(path)
	return call("delfile", path)
end

function Env.ListFiles(folder)
	local ok, result = call("listfiles", folder)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

return Env
