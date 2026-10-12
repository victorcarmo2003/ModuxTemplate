--!nocheck
-- Studio-only stand-in for "Rojo connected": copies the Source of every script of sourcemap.json (repo root) whose text
-- differs from the file, creating the missing scripts / folders. For a Studio where the Rojo plugin is not connected (the
-- agents cannot press Connect). Edit mode, execute_luau. Deletions are NOT inferred: pass the dotted paths to destroy.
-- Call: run("studio/sync_src", { "StarterPlayer.StarterPlayerScripts.client.Vehicle.PadHideController" }, "/client/")
-- Needs the repo HTTP server (tools/studio/README.md) and a fresh sourcemap.json (tools/analyze.ps1 or `rojo sourcemap`).
-- Returns a report. Only scripts are touched, never the map.
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8772/"
local destroy, only = ... -- only = Lua pattern a repo path must match (the HTTP limit is 500 requests / minute)
local report = { changed = {}, created = {}, same = 0, failed = {} }

local map = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "sourcemap.json", true))

local SCRIPT = { Script = true, LocalScript = true, ModuleScript = true }

local function child(parent: Instance, name: string): Instance?
	for _, c in parent:GetChildren() do
		if c.Name == name then
			return c
		end
	end
	return nil
end

local function walk(node, parent: Instance)
	local inst = child(parent, node.name)
	if inst == nil and node.className ~= "DataModel" then
		local ok, made = pcall(Instance.new, node.className)
		if not ok then
			table.insert(report.failed, "cannot create " .. node.className .. " " .. node.name)
			return
		end
		inst = made
		inst.Name = node.name
		inst.Parent = parent
		table.insert(report.created, inst:GetFullName())
	end
	local files = node.filePaths
	if inst ~= nil and SCRIPT[node.className] and files ~= nil then
		for _, path in files do
			if (string.sub(path, -5) == ".luau" or string.sub(path, -4) == ".lua") and (only == nil or string.find(path, only)) then
				local ok, text = pcall(function()
					return HttpService:GetAsync(BASE .. string.gsub(path, " ", "%%20"), true)
				end)
				if not ok then
					table.insert(report.failed, path .. ": " .. tostring(text))
				else
					text = string.gsub(text, "\r\n", "\n")
					if inst.Source ~= text then
						local set, err = pcall(function()
							inst.Source = text
						end)
						if set then
							table.insert(report.changed, path)
						else
							table.insert(report.failed, path .. ": " .. tostring(err))
						end
					else
						report.same += 1
					end
				end
				break
			end
		end
	end
	if inst ~= nil and node.children then
		for _, c in node.children do
			walk(c, inst)
		end
	end
end

for _, top in map.children do
	local service = game:FindFirstChild(top.name) or (pcall(game.GetService, game, top.name) and game:GetService(top.name))
	if service then
		for _, c in top.children or {} do
			walk(c, service)
		end
	end
end

if destroy then
	for _, dotted in destroy do
		local cur = game
		for part in string.gmatch(dotted, "[^%.]+") do
			cur = cur and cur:FindFirstChild(part)
		end
		if cur and cur ~= game then
			cur:Destroy()
			table.insert(report.changed, "destroyed " .. dotted)
		end
	end
end

return string.format(
	"same %d, changed %d, created %d, failed %d\nCHANGED:\n%s\nCREATED:\n%s\nFAILED:\n%s",
	report.same,
	#report.changed,
	#report.created,
	#report.failed,
	table.concat(report.changed, "\n"),
	table.concat(report.created, "\n"),
	table.concat(report.failed, "\n")
)
