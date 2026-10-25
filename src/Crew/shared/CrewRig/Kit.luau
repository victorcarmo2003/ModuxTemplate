--!strict
-- Read-only access to the character kits (architecture.md §18.9 rules 1-7, §18.9.1). TASK-016.
-- The kits live outside Rojo, built in edit mode by tools/assetplace/build_kits.luau:
--   ReplicatedStorage.Assets.Crew: Body, CivilArms, CapEarsUp, Hats/<Hat>, Animals/<Asset>, Accessories/<name>
--   ReplicatedStorage.CrewExpressions: one SurfaceAppearance per expression (Content.Looks.Expressions)
--   ReplicatedStorage.CrewOutfitSheets: one SurfaceAppearance per outfit sheet id (tools/assetplace/build_outfit_sheets.luau)
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

-- Outfit sheet on an outfit piece (OutfitPart: torso, arms, legs, apron, cap). Roblox draws a MeshPart TextureID ignoring
-- its alpha, so the fur texels of the sheet (hands, forearms, shins) showed the neutral grey stored under them on every
-- species, never MeshPart.Color (owner report 2026-10-25: "the frog has the cat's hands"). A SurfaceAppearance with
-- AlphaMode Overlay shows MeshPart.Color under the alpha, but ColorMap is not script-writable: templates are built in
-- edit mode (ReplicatedStorage.CrewOutfitSheets.<numeric id>, build_outfit_sheets.luau) and cloned here. TextureID is
-- still set (the fallback when a template is missing, and the key other code reads). The caller sets MeshPart.Color.
const SHEET_FOLDER = "CrewOutfitSheets"
const SHEET_HINT = "run tools/assetplace/build_outfit_sheets.luau in edit mode and save the place"
local sheetFolder: Instance? = nil
local sheetWaited = false

local function sheetTemplates(): Instance?
	if sheetFolder ~= nil and sheetFolder.Parent == ReplicatedStorage then
		return sheetFolder
	end
	local found = ReplicatedStorage:FindFirstChild(SHEET_FOLDER)
	if found == nil and RunService:IsClient() and not sheetWaited then
		sheetWaited = true -- wait once: a place without the folder must not stall every Dress
		found = ReplicatedStorage:WaitForChild(SHEET_FOLDER, CLIENT_WAIT)
	end
	sheetFolder = found
	return found
end

function Kit.ApplySheet(part: MeshPart, sheet: string)
	if part.TextureID ~= sheet then
		part.TextureID = sheet
	end
	const id = string.match(sheet, "%d+$")
	const folder = sheetTemplates()
	const found = if folder ~= nil and id ~= nil then folder:FindFirstChild(id) else nil
	const template = if found ~= nil and found:IsA("SurfaceAppearance") then found else nil
	local current: SurfaceAppearance? = nil
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			if current == nil and template ~= nil and child.Name == template.Name then
				current = child
			else
				child:Destroy()
			end
		end
	end
	if template == nil then
		Kit.WarnOnce(`Sheet:{sheet}`, `no ReplicatedStorage.{SHEET_FOLDER}.{id or sheet}: grey hands ({SHEET_HINT})`)
		return
	end
	if current == nil then
		template:Clone().Parent = part
	end
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
