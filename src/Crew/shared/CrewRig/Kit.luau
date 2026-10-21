--!strict
-- Read-only access to the character kits (architecture.md §18.9 rules 1-7, §18.9.1). TASK-016.
-- The kits live outside Rojo, built in edit mode by tools/assetplace/build_kits.luau:
--   ReplicatedStorage.Assets.Crew: Body, CivilArms, CapEarsUp, Hats/<Hat>, Animals/<Asset>, Accessories/<name>
--   ReplicatedStorage.CrewExpressions: one SurfaceAppearance per expression (Content.Looks.Expressions)
-- No runtime asset loading here (§18.9 rule 1): meshes only exist as kit instances and are cloned.
-- Nothing is cached but the kit folders themselves, so building and destroying rigs never leaks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CrewLooks = require(script.Parent.Parent.CrewLooks)

const Kit = {}

-- The client may start before ReplicatedStorage finished replicating the kit (it is not part of the Rojo tree).
const CLIENT_WAIT = 10
const BUILD_HINT = "run tools/assetplace/build_kits.luau in edit mode and save the place"

local versionChecked = false
local warned: { [string]: boolean } = {}

function Kit.WarnOnce(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	warn(`[CrewRig] {message}`)
end

local function find(parent: Instance, name: string): Instance?
	const found = parent:FindFirstChild(name)
	if found ~= nil then
		return found
	end
	if RunService:IsClient() then
		return parent:WaitForChild(name, CLIENT_WAIT)
	end
	return nil
end

local function need(parent: Instance, name: string): Instance
	const found = find(parent, name)
	if found == nil then
		error(`[CrewRig] kit piece missing: {parent:GetFullName()}.{name} ({BUILD_HINT})`, 3)
	end
	return found
end

-- ReplicatedStorage.Assets.Crew. Warns once (loudly) when the kit and CrewLooks disagree on KitVersion (§18.9 rule 7).
function Kit.Crew(): Instance
	const assets = need(ReplicatedStorage, "Assets")
	if not versionChecked then
		versionChecked = true
		const version = assets:GetAttribute("KitVersion")
		if version ~= CrewLooks.KitVersion then
			Kit.WarnOnce(
				"KitVersion",
				`ReplicatedStorage.Assets.KitVersion = {tostring(version)} but CrewLooks.KitVersion = {CrewLooks.KitVersion}; {BUILD_HINT}`
			)
		end
	end
	return need(assets, "Crew")
end

function Kit.Body(): Instance
	return need(Kit.Crew(), "Body")
end

function Kit.CivilArms(): Instance
	return need(Kit.Crew(), "CivilArms")
end

function Kit.CapEarsUp(): Instance
	return need(Kit.Crew(), "CapEarsUp")
end

-- Hats/<name>. Explicit request from the caller: missing = error.
function Kit.Hat(name: string): Instance
	return need(need(Kit.Crew(), "Hats"), name)
end

-- Animals/<Content.Species[k].Asset>.
function Kit.Animal(asset: string): Instance
	return need(need(Kit.Crew(), "Animals"), asset)
end

-- Accessories/<name> (AST-081 / AST-076, TASK-089). Optional: a place built before the pieces existed returns nil and
-- the rig is built without it (Content.CustomerTypes note: "CrewRig must skip a missing mesh, not fail").
function Kit.Accessory(name: string): Instance?
	const folder = Kit.Crew():FindFirstChild("Accessories")
	return if folder then folder:FindFirstChild(name) else nil
end

-- ReplicatedStorage.CrewExpressions.<name>, or nil.
function Kit.Expression(name: string): SurfaceAppearance?
	const folder = find(ReplicatedStorage, "CrewExpressions")
	const found = if folder then folder:FindFirstChild(name) else nil
	if found ~= nil and found:IsA("SurfaceAppearance") then
		return found
	end
	return nil
end

-- Fresh clones of the BaseParts under `source` (kit parts are flat children of their Model; accessories may nest).
-- Each clone keeps the imported rest pose and its own children (the Face keeps its SurfaceAppearance).
function Kit.CloneParts(source: Instance, deep: boolean?): { BasePart }
	const out: { BasePart } = {}
	if source:IsA("BasePart") then
		table.insert(out, source:Clone())
		return out
	end
	const list = if deep then source:GetDescendants() else source:GetChildren()
	for _, item in list do
		if item:IsA("BasePart") then
			const clone = item:Clone()
			-- a deep clone would carry nested parts twice
			for _, nested in clone:GetDescendants() do
				if nested:IsA("BasePart") then
					nested:Destroy()
				end
			end
			table.insert(out, clone)
		end
	end
	return out
end

return Kit
