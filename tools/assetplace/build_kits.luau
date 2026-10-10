--!strict
--[[
	Character kit builder (TASK-006; architecture.md §18.9). EDIT MODE ONLY: Command Bar or Studio MCP.
	InsertService is allowed here because this is a tool (§18.9 rule 1: never in src/).

	Builds, outside Rojo (§18.9 rule 5):
	  ReplicatedStorage.Assets            (Folder, attribute KitVersion = CrewLooks.KitVersion; shared with TASK-007)
	    Crew/Body                         AST-053_CrewTex without Head: Torso, Left/Right Arm, Left/Right Leg, Apron, Cap
	    Crew/CivilArms                    AST-053_CivilArms: Left Arm, Right Arm (straight civil arms, DEC-161)
	    Crew/CapEarsUp                    AST-053_CrewCap_EarsUp: one MeshPart named "Cap"
	    Crew/Hats/ThiefHat                AST-053_ThiefHat: one MeshPart named "Hat"
	    Crew/Animals/<Asset>              AST-053_Animal_<Asset> (18): Head_<A>, Face_<A>, Ears_<A>, Tail_<A>, extras
	    Crew/Accessories/<kit name>       AST-081_Acc_* / AST-076_Acc_* (TASK-089): one MeshPart named after the kit
	                                      name ("Acc_Badge"), attribute Anchor (R6 part) + DayTextureID; list, assets and
	                                      anchors from AccessoryFit (src/Crew/shared, generated from AST-081_offsets.json)
	  ReplicatedStorage.CrewExpressions   one SurfaceAppearance per expression (T_Expr_<Name>, AlphaMode Transparency)

	Kit conventions (consumed by CrewRig, TASK-016):
	  - every piece keeps the imported rest pose (common origin at the feet, front -Z): never PivotTo a kit model;
	  - parts are flat children of their Model; Anchored, no collision/query/touch (CrewRig unanchors);
	  - attribute Asset = "AST-053_<name>" on every kit Model and BasePart (§18.9 rule 7);
	  - OutfitPart = true on outfit-sheet parts (body, civil arms); their TextureID = Day sheet (crew / civil_a);
	  - DayTextureID = imported atlas texture on atlas pieces (ears, tails, extras, CapEarsUp, ThiefHat);
	  - Head_<A>: TextureID = CrewLooks Head.Day, Color = Fur; Face_<A>: TextureID "" + clone of the Normal face.
	Only Assets.Crew and CrewExpressions are rebuilt: Assets.Items / Assets.Equipment (TASK-007) are left alone.
	AST-053_CrewBase is not part of the runtime kit (§18.9.1: joints come from the rest pose).

	Usage (repo served at http://127.0.0.1:8772/, e.g. `python -m http.server 8772` at the repo root):
		local Http = game:GetService("HttpService")
		local was = Http.HttpEnabled
		Http.HttpEnabled = true
		local ms = Instance.new("ModuleScript")
		ms.Source = Http:GetAsync("http://127.0.0.1:8772/tools/assetplace/build_kits.luau")
		Http.HttpEnabled = was
		local Kits = require(ms)
		print(Kits.run({ baseUrl = "http://127.0.0.1:8772/" }))          -- build + check
		print(Kits.run({ baseUrl = "http://127.0.0.1:8772/", demo = true })) -- + workspace.KitDemo (18 x Day/Mid/Night)
		Kits.clearDemo()
	Without the server: Kits.run({ ids = <_asset_ids table>, tex = <_texture_ids table>, looks = <CrewLooks table>,
		fit = <AccessoryFit table> }).
	CrewLooks / AccessoryFit are taken from opts.looks / opts.fit, else ReplicatedStorage.shared.Crew.<module> (rojo
	serve), else the server.
	Save the place afterwards (Ctrl+S): the place is not in git, this script is the recipe.
]]

local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

type Ids = { [string]: any }
type Tex = { [string]: string }
type SpeciesLook = { Fur: Color3, EarsUp: boolean, CapRaise: number, Head: { [string]: string } }
type Looks = {
	KitVersion: number,
	Species: { [string]: SpeciesLook },
	Outfits: { [string]: { [string]: string } },
	Atlas: { [string]: string },
}
type FitPiece = { Asset: string, Anchor: string, Attachment: string, Only: string? }
type Fit = { Pieces: { [string]: FitPiece }, Species: { [string]: { [string]: { Use: string? } } } }
export type Options = {
	baseUrl: string?,
	ids: Ids?,
	tex: Tex?,
	looks: Looks?,
	fit: Fit?, -- AccessoryFit (src/Crew/shared/AccessoryFit.luau)
	reload: boolean?, -- drop cached character assets and load them again
	demo: boolean?, -- also build workspace.KitDemo for a visual check
}

local Kits = {}

const CACHE_NAME = "__AssetCache" -- shared with place_assets.luau
const DEMO_NAME = "KitDemo"
const PACKS = { "Day", "Mid", "Night" }
-- Content.Looks.PackFace (content-data.md §3.10b)
const PACK_FACE: { [string]: string } = { Day = "Normal", Mid = "Exhausted", Night = "Normal_Night" }
-- Content.Looks.Expressions (closed list) + Thief (NPC-007 only)
const EXPRESSIONS = {
	"Normal",
	"Happy",
	"Smile",
	"Sad",
	"Fainted",
	"Skeptical",
	"Exhausted",
	"Stressed",
	"Normal_Night",
	"Thief",
}
const BODY = { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Apron", "Cap" }
const ARMS = { "Left Arm", "Right Arm" }

-- Content (ReplicatedStorage.shared.Content) when rojo serve is running; nil otherwise.
local contentCache: any = nil
local function content(): any
	if contentCache == nil then
		contentCache = false
		local shared = ReplicatedStorage:FindFirstChild("shared")
		local mod = shared and shared:FindFirstChild("Content")
		if mod and mod:IsA("ModuleScript") then
			local ok, res = pcall(require, mod)
			if ok then
				contentCache = res
			end
		end
	end
	return if contentCache then contentCache else nil
end

-- Content.Species key -> kit name (Content.Species[k].Asset). Without Content: PascalCase of the key (all 18 keys
-- are one word, content-data.md §3.10a).
local function assetOf(key: string): string
	local c = content()
	local row = c and c.Species.ByKey[key]
	if row and type(row.Asset) == "string" then
		return row.Asset
	end
	return string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

-- HTTP ------------------------------------------------------------------------------------------------------------

local function httpGet(url: string): string
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, res = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	HttpService.HttpEnabled = was
	if not ok then
		error("GET " .. url .. " failed: " .. tostring(res))
	end
	return res :: string
end

local function join(base: string, path: string): string
	if string.sub(base, -1) ~= "/" then
		base ..= "/"
	end
	return base .. path
end

local function requireSource(name: string, source: string): any
	local ms = Instance.new("ModuleScript")
	ms.Name = name
	ms.Source = source
	return (require :: any)(ms)
end

-- Data module of src/Crew/shared: ReplicatedStorage.shared.Crew.<name> (rojo serve), else the repo server.
local function crewModule(name: string, opts: Options): any
	local shared = ReplicatedStorage:FindFirstChild("shared")
	local crew = shared and shared:FindFirstChild("Crew")
	local mod = crew and crew:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		return (require :: any)(mod)
	end
	if opts.baseUrl then
		return requireSource(name, httpGet(join(opts.baseUrl, "src/Crew/shared/" .. name .. ".luau")))
	end
	error(name .. " not found: pass it in opts, run rojo serve, or pass opts.baseUrl")
end

local function resolveLooks(opts: Options): Looks
	if opts.looks then
		return opts.looks
	end
	return crewModule("CrewLooks", opts)
end

local function resolveFit(opts: Options): Fit
	if opts.fit then
		return opts.fit
	end
	return crewModule("AccessoryFit", opts)
end

-- Asset loading (InsertService, cached like place_assets.luau) ------------------------------------------------------

local function cacheFolder(): Folder
	local f = ServerStorage:FindFirstChild(CACHE_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = CACHE_NAME
		f.Parent = ServerStorage
	end
	return f :: Folder
end

local function template(name: string, ids: Ids, reload: boolean?): Instance
	local id = ids[name]
	if id == nil then
		error("no asset id for " .. name .. " in _asset_ids.json")
	end
	local cache = cacheFolder()
	local hit = cache:FindFirstChild(name)
	if hit and (reload or hit:GetAttribute("AssetId") ~= tostring(id)) then
		hit:Destroy()
		hit = nil
	end
	if hit then
		return hit
	end
	local num = tonumber(id)
	if not num then
		error("bad asset id for " .. name .. ": " .. tostring(id))
	end
	local ok, res = pcall(function()
		return InsertService:LoadAsset(num)
	end)
	if not ok then
		error("LoadAsset failed for " .. name .. ": " .. tostring(res))
	end
	local container = res :: Model
	local model = container:GetChildren()[1]
	if not model then
		container:Destroy()
		error("empty asset " .. name)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Name = name
	model:SetAttribute("AssetId", tostring(id))
	model.Parent = cache
	container:Destroy()
	return model
end

-- Every BasePart of a fresh clone of the asset, by name (Accessory/Model nesting from the import is flattened).
local function partsOf(name: string, ids: Ids, reload: boolean?): ({ [string]: BasePart }, { BasePart })
	local clone = template(name, ids, reload):Clone()
	local byName: { [string]: BasePart } = {}
	local list: { BasePart } = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			byName[d.Name] = d
			table.insert(list, d)
		end
	end
	for _, p in list do
		p.Parent = nil
	end
	clone:Destroy()
	return byName, list
end

local function kitPart(p: BasePart, asset: string, parent: Instance)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Asset", asset)
	for _, d in p:GetDescendants() do
		if d:IsA("PackageLink") then
			d:Destroy()
		end
	end
	p.Parent = parent
end

local function newModel(name: string, asset: string?, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	if asset then
		m:SetAttribute("Asset", asset)
	end
	m.Parent = parent
	return m
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f and not f:IsA("Folder") then
		f:Destroy()
		f = nil
	end
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

-- Expressions -------------------------------------------------------------------------------------------------------

function Kits.buildExpressions(tex: Tex, problems: { string }): Folder
	local root = folder(ReplicatedStorage, "CrewExpressions")
	root:ClearAllChildren()
	local known: { [string]: boolean } = {}
	for _, name in EXPRESSIONS do
		known[name] = true
		local id = tex["T_Expr_" .. name]
		if not id then
			table.insert(problems, "missing texture T_Expr_" .. name)
			continue
		end
		local sa = Instance.new("SurfaceAppearance")
		sa.Name = name
		sa.ColorMap = id
		sa.AlphaMode = Enum.AlphaMode.Transparency
		sa:SetAttribute("Texture", "T_Expr_" .. name)
		sa.Parent = root
	end
	for key in tex do
		local name = string.match(key, "^T_Expr_(.+)$")
		if name and not known[name] then
			table.insert(problems, "note: " .. key .. " is not in the expression list (not built)")
		end
	end
	return root
end

-- Crew kit ----------------------------------------------------------------------------------------------------------

local function markAtlas(p: BasePart)
	if p:IsA("MeshPart") and p.TextureID ~= "" then
		p:SetAttribute("DayTextureID", p.TextureID)
	end
end

local function single(
	name: string,
	modelName: string,
	partName: string,
	ids: Ids,
	reload: boolean?,
	parent: Instance,
	problems: { string }
)
	local _, list = partsOf(name, ids, reload)
	if #list ~= 1 then
		table.insert(problems, string.format("%s: expected 1 part, got %d", name, #list))
	end
	local p = list[1]
	if not p then
		return
	end
	for i = 2, #list do
		list[i]:Destroy()
	end
	local m = newModel(modelName, name, parent)
	p.Name = partName
	markAtlas(p)
	kitPart(p, name, m)
	m.PrimaryPart = p
end

-- Accessories (TASK-089): one Model per AccessoryFit.Pieces entry, named by kit name, holding one MeshPart of the
-- same name (rest pose kept). Anchor on Model and part: CrewRig welds there (briefcase/cane = arm, not the nearest leg).
local function buildAccessories(ids: Ids, fit: Fit, reload: boolean?, crew: Instance, problems: { string })
	local root = folder(crew, "Accessories")
	local names = {}
	for name in fit.Pieces do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		const row = fit.Pieces[name]
		local ok, err = pcall(function()
			single(row.Asset, name, name, ids, reload, root, problems)
		end)
		if not ok then
			table.insert(problems, tostring(err))
			continue
		end
		local m = root:FindFirstChild(name)
		local p = m and m:FindFirstChild(name)
		if m and p and p:IsA("BasePart") then
			m:SetAttribute("Anchor", row.Anchor)
			p:SetAttribute("Anchor", row.Anchor)
			p:SetAttribute("Attachment", row.Attachment)
		end
	end
end

function Kits.buildCrew(
	ids: Ids,
	looks: Looks,
	expressions: Folder,
	reload: boolean?,
	problems: { string },
	fit: Fit?
): Folder
	local assets = folder(ReplicatedStorage, "Assets")
	assets:SetAttribute("KitVersion", looks.KitVersion)
	local old = assets:FindFirstChild("Crew")
	if old then
		old:Destroy()
	end
	local crew = Instance.new("Folder")
	crew.Name = "Crew"

	-- Body (uniform, Day sheet)
	do
		const asset = "AST-053_CrewTex"
		local byName, list = partsOf(asset, ids, reload)
		local m = newModel("Body", asset, crew)
		local keep: { [string]: boolean } = {}
		for _, n in BODY do
			keep[n] = true
			local p = byName[n]
			if not p then
				table.insert(problems, asset .. ": missing " .. n)
				continue
			end
			if p:IsA("MeshPart") then
				p.TextureID = looks.Outfits.crew.Day
			end
			p:SetAttribute("OutfitPart", true)
			kitPart(p, asset, m)
		end
		for _, p in list do
			if not keep[p.Name] then
				if p.Name ~= "Head" then
					table.insert(problems, "note: " .. asset .. ": dropped extra part " .. p.Name)
				end
				p:Destroy()
			end
		end
		m.PrimaryPart = byName.Torso
	end

	-- Civil arms (Day sheet of civil_a; CrewRig.Dress sets the real outfit)
	do
		const asset = "AST-053_CivilArms"
		local byName, list = partsOf(asset, ids, reload)
		local m = newModel("CivilArms", asset, crew)
		for _, n in ARMS do
			local p = byName[n]
			if not p then
				table.insert(problems, asset .. ": missing " .. n)
				continue
			end
			if p:IsA("MeshPart") then
				p.TextureID = looks.Outfits.civil_a.Day
			end
			p:SetAttribute("OutfitPart", true)
			kitPart(p, asset, m)
		end
		for _, p in list do
			if p.Parent == nil then
				p:Destroy()
			end
		end
	end

	single("AST-053_CrewCap_EarsUp", "CapEarsUp", "Cap", ids, reload, crew, problems)
	local hats = folder(crew, "Hats")
	single("AST-053_ThiefHat", "ThiefHat", "Hat", ids, reload, hats, problems)

	-- Animals
	local animals = folder(crew, "Animals")
	local normal = expressions:FindFirstChild("Normal")
	local keys = {}
	for key in looks.Species do
		table.insert(keys, key)
	end
	table.sort(keys)
	for i, key in keys do
		const look = looks.Species[key]
		const a = assetOf(key)
		const asset = "AST-053_Animal_" .. a
		local ok, err = pcall(function()
			local byName, list = partsOf(asset, ids, reload)
			local m = newModel(a, asset, animals)
			m:SetAttribute("Species", key)
			local head = byName["Head_" .. a]
			local face = byName["Face_" .. a]
			if not head then
				table.insert(problems, asset .. ": missing Head_" .. a)
			end
			if not face then
				table.insert(problems, asset .. ": missing Face_" .. a)
			end
			for _, p in list do
				if p == head then
					if p:IsA("MeshPart") then
						p.TextureID = look.Head.Day
					end
					p.Color = look.Fur
				elseif p == face then
					if p:IsA("MeshPart") then
						p.TextureID = ""
					end
					local oldSa = p:FindFirstChildOfClass("SurfaceAppearance")
					if oldSa then
						oldSa:Destroy()
					end
					local tpl = normal
					if tpl then
						tpl:Clone().Parent = p
					end
				else
					markAtlas(p)
				end
				kitPart(p, asset, m)
			end
			m.PrimaryPart = head
		end)
		if not ok then
			table.insert(problems, tostring(err))
		end
		if i % 4 == 0 then
			task.wait()
		end
	end

	if fit then
		buildAccessories(ids, fit, reload, crew, problems)
	else
		folder(crew, "Accessories")
		table.insert(problems, "AccessoryFit not given: Crew.Accessories left empty")
	end
	crew.Parent = assets
	return crew
end

-- Check (TASK-006 acceptance) -------------------------------------------------------------------------------------

function Kits.check(looks: Looks, tex: Tex?, fit: Fit?): { string }
	local problems: { string } = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = assets and assets:FindFirstChild("Crew")
	local expr = ReplicatedStorage:FindFirstChild("CrewExpressions")
	if not assets or not crew then
		return { "ReplicatedStorage.Assets.Crew missing" }
	end
	if assets:GetAttribute("KitVersion") ~= looks.KitVersion then
		table.insert(problems, "Assets.KitVersion ~= CrewLooks.KitVersion")
	end
	-- every id in CrewLooks exists in the JSON
	if tex then
		local valid: { [string]: boolean } = {}
		for _, v in tex do
			valid[v] = true
		end
		local function id(where: string, v: string)
			if not valid[v] then
				table.insert(problems, "id not in _texture_ids.json: " .. where .. " = " .. v)
			end
		end
		for k, s in looks.Species do
			for pack, v in s.Head do
				id(k .. ".Head." .. pack, v)
			end
		end
		for k, o in looks.Outfits do
			for pack, v in o do
				id(k .. "." .. pack, v)
			end
		end
		for pack, v in looks.Atlas do
			id("Atlas." .. pack, v)
		end
	end
	-- every Content.Species / Content.Outfits key has an entry, and the outfit packs exist (§18.9.3 Validate)
	local c = content()
	if c then
		for _, row in c.Species.List do
			if not looks.Species[row.Key] then
				table.insert(problems, "CrewLooks.Species has no entry for Content.Species." .. row.Key)
			end
		end
		for k in looks.Species do
			if not c.Species.ByKey[k] then
				table.insert(problems, "CrewLooks.Species." .. k .. " is not a Content.Species key")
			end
		end
		for _, row in c.Outfits.List do
			local o = looks.Outfits[row.Key]
			if not o then
				table.insert(problems, "CrewLooks.Outfits has no entry for Content.Outfits." .. row.Key)
				continue
			end
			for _, pack in row.Packs do
				if not o[pack] then
					table.insert(problems, "CrewLooks.Outfits." .. row.Key .. " has no " .. pack)
				end
			end
		end
		for k in looks.Outfits do
			if not c.Outfits.ByKey[k] then
				table.insert(problems, "CrewLooks.Outfits." .. k .. " is not a Content.Outfits key")
			end
		end
		for _, name in c.Looks.Expressions do
			if not table.find(EXPRESSIONS, name) then
				table.insert(problems, "Content.Looks.Expressions." .. name .. " is not built by build_kits")
			end
		end
		-- every CustomerTypes accessory is a kit piece (TASK-089)
		local accessories = crew:FindFirstChild("Accessories")
		for _, row in c.CustomerTypes.List do
			for _, name in row.Accessories do
				if not (accessories and accessories:FindFirstChild(name)) then
					table.insert(problems, "Content.CustomerTypes." .. row.Key .. ": Crew.Accessories." .. name .. " missing")
				end
			end
		end
		if fit then
			for k in fit.Species do
				if not c.Species.ByKey[k] then
					table.insert(problems, "AccessoryFit.Species." .. k .. " is not a Content.Species key")
				end
			end
		end
	else
		table.insert(problems, "note: Content not found (rojo serve off): Content key cross-check skipped")
	end
	for k, o in looks.Outfits do
		if not o.Day then
			table.insert(problems, "Outfits." .. k .. " has no Day")
		end
	end
	-- kit pieces
	local body = crew:FindFirstChild("Body")
	for _, n in BODY do
		if not (body and body:FindFirstChild(n)) then
			table.insert(problems, "Crew.Body." .. n .. " missing")
		end
	end
	local arms = crew:FindFirstChild("CivilArms")
	for _, n in ARMS do
		if not (arms and arms:FindFirstChild(n)) then
			table.insert(problems, "Crew.CivilArms." .. n .. " missing")
		end
	end
	local capUp = crew:FindFirstChild("CapEarsUp")
	if not (capUp and capUp:FindFirstChild("Cap")) then
		table.insert(problems, "Crew.CapEarsUp.Cap missing")
	end
	local hats = crew:FindFirstChild("Hats")
	local thief = hats and hats:FindFirstChild("ThiefHat")
	if not (thief and thief:FindFirstChild("Hat")) then
		table.insert(problems, "Crew.Hats.ThiefHat.Hat missing")
	end
	local animals = crew:FindFirstChild("Animals")
	for k in looks.Species do
		local a = assetOf(k)
		local m = animals and animals:FindFirstChild(a)
		if not m then
			table.insert(problems, "Crew.Animals." .. a .. " missing (species " .. k .. ")")
			continue
		end
		for _, n in { "Head_" .. a, "Face_" .. a } do
			if not m:FindFirstChild(n) then
				table.insert(problems, "Crew.Animals." .. a .. "." .. n .. " missing")
			end
		end
	end
	-- accessories (TASK-089): every AccessoryFit piece built, one MeshPart, Anchor + DayTextureID
	local accessories = crew:FindFirstChild("Accessories")
	if not accessories then
		table.insert(problems, "Crew.Accessories missing")
	elseif fit then
		for name, row in fit.Pieces do
			local m = accessories:FindFirstChild(name)
			local p = m and m:FindFirstChild(name)
			if not (m and p and p:IsA("MeshPart")) then
				table.insert(problems, "Crew.Accessories." .. name .. " missing (" .. row.Asset .. ")")
				continue
			end
			if m:GetAttribute("Anchor") ~= row.Anchor then
				table.insert(problems, "Crew.Accessories." .. name .. ": Anchor ~= " .. row.Anchor)
			end
			if p:GetAttribute("DayTextureID") == nil then
				table.insert(problems, "Crew.Accessories." .. name .. ": no DayTextureID (atlas texture missing)")
			end
		end
		for _, bySpecies in fit.Species do
			for _, f in bySpecies do
				if f.Use and not accessories:FindFirstChild(f.Use) then
					table.insert(problems, "Crew.Accessories." .. f.Use .. " missing (AccessoryFit Use)")
				end
			end
		end
		for _, m in accessories:GetChildren() do
			if not fit.Pieces[m.Name] then
				table.insert(problems, "note: Crew.Accessories." .. m.Name .. " is not in AccessoryFit")
			end
		end
	else
		table.insert(problems, "note: AccessoryFit not given: accessory check skipped")
	end
	for _, name in EXPRESSIONS do
		local sa = expr and expr:FindFirstChild(name)
		if not (sa and sa:IsA("SurfaceAppearance") and sa.ColorMap ~= "") then
			table.insert(problems, "CrewExpressions." .. name .. " missing")
		end
	end
	for _, d in crew:GetDescendants() do
		if d:IsA("PackageLink") then
			table.insert(problems, "PackageLink left in " .. d:GetFullName())
		elseif d:IsA("BasePart") and d:GetAttribute("Asset") == nil then
			table.insert(problems, "no Asset attribute: " .. d:GetFullName())
		end
	end
	return problems
end

-- Demo: one rig per species x pack, welded and anchored (visual check only; production = CrewRig, TASK-016) ---------

local function demoRig(looks: Looks, key: string, outfit: string, pack: string, at: CFrame, parent: Instance): { string }
	local missing: { string } = {}
	local crew = (ReplicatedStorage :: any).Assets.Crew
	local a = assetOf(key)
	local look = looks.Species[key]
	local model = Instance.new("Model")
	model.Name = string.format("%s_%s_%s", a, outfit, pack)
	local parts: { [string]: BasePart } = {}
	local function take(src: Instance?, label: string)
		if not src then
			table.insert(missing, label)
			return
		end
		for _, p in src:GetChildren() do
			if p:IsA("BasePart") then
				parts[p.Name] = p:Clone()
			end
		end
	end
	take(crew.Body, "Body")
	take(crew.Animals:FindFirstChild(a), "Animals." .. a)
	if outfit ~= "crew" then
		take(crew.CivilArms, "CivilArms")
		if parts.Apron then
			parts.Apron:Destroy()
			parts.Apron = nil
		end
	end
	if parts.Cap and (outfit ~= "crew" or look.EarsUp) then
		parts.Cap:Destroy()
		parts.Cap = nil
	end
	if outfit == "thief" then
		take(crew.Hats:FindFirstChild("ThiefHat"), "Hats.ThiefHat")
	elseif outfit == "crew" and look.EarsUp then
		take(crew:FindFirstChild("CapEarsUp"), "CapEarsUp")
	end
	if parts.Cap then
		parts.Cap.CFrame += Vector3.new(0, look.CapRaise, 0)
	end
	local sheet = looks.Outfits[outfit][pack] or looks.Outfits[outfit].Day
	local headTex = look.Head[pack] or look.Head.Day
	local atlas = looks.Atlas[pack]
	for name, p in parts do
		if p:IsA("MeshPart") then
			if p:GetAttribute("OutfitPart") then
				p.TextureID = sheet
				p.Color = look.Fur
			elseif name == "Head_" .. a then
				p.TextureID = headTex
			elseif p:GetAttribute("DayTextureID") then
				p.TextureID = atlas or p:GetAttribute("DayTextureID") :: string
			end
		end
	end
	local face = parts["Face_" .. a]
	local exprName = if outfit == "thief" then "Thief" else PACK_FACE[pack]
	local exprFolder = ReplicatedStorage:FindFirstChild("CrewExpressions")
	local tpl = exprFolder and exprFolder:FindFirstChild(exprName)
	if face then
		local oldSa = face:FindFirstChildOfClass("SurfaceAppearance")
		if oldSa then
			oldSa:Destroy()
		end
		if tpl then
			tpl:Clone().Parent = face
		else
			table.insert(missing, "CrewExpressions." .. exprName)
		end
	end
	local torso = parts.Torso
	for _, p in parts do
		p.Anchored = true
		p.Parent = model
	end
	if torso then
		-- pivot = Torso (rest pose); like the HumanoidRootPart, it stands at ground + 3
		model.PrimaryPart = torso
	end
	model:PivotTo(at * CFrame.new(0, 3, 0))
	model:SetAttribute("Species", key)
	model:SetAttribute("Outfit", outfit)
	model:SetAttribute("LookPack", pack)
	model.Parent = parent
	return missing
end

function Kits.clearDemo()
	local old = workspace:FindFirstChild(DEMO_NAME)
	if old then
		old:Destroy()
	end
end

function Kits.demo(looks: Looks): { string }
	Kits.clearDemo()
	local root = Instance.new("Model")
	root.Name = DEMO_NAME
	local problems: { string } = {}
	local keys = {}
	for key in looks.Species do
		table.insert(keys, key)
	end
	table.sort(keys)
	local origin = CFrame.new(0, 0, -60)
	for col, key in keys do
		for row, pack in PACKS do
			-- crew for playable look, civil_a for everyone else; the raccoon wears the thief outfit (Day only)
			local outfit = if key == "raccoon" then "thief" else (if row == 2 then "civil_a" else "crew")
			local at = origin * CFrame.new((col - 1) * 5, 0, (row - 1) * 7) * CFrame.Angles(0, math.pi, 0)
			for _, m in demoRig(looks, key, outfit, pack, at, root) do
				table.insert(problems, string.format("%s %s %s: missing %s", key, outfit, pack, m))
			end
		end
	end
	root.Parent = workspace
	return problems
end

-- Entry point -------------------------------------------------------------------------------------------------------

function Kits.run(opts: Options): string
	local ids: Ids? = opts.ids
	local tex: Tex? = opts.tex
	if opts.baseUrl then
		if not ids then
			ids = HttpService:JSONDecode(httpGet(join(opts.baseUrl, "Assets/import/_asset_ids.json")))
		end
		if not tex then
			tex = HttpService:JSONDecode(httpGet(join(opts.baseUrl, "Assets/textures/character/_texture_ids.json")))
		end
	end
	assert(ids, "asset ids missing: pass opts.ids or opts.baseUrl")
	assert(tex, "texture ids missing: pass opts.tex or opts.baseUrl")
	local looks = resolveLooks(opts)
	local fit = resolveFit(opts)
	local problems: { string } = {}
	local expressions = Kits.buildExpressions(tex, problems)
	local crew: any = Kits.buildCrew(ids, looks, expressions, opts.reload, problems, fit)
	for _, p in Kits.check(looks, tex, fit) do
		table.insert(problems, p)
	end
	if opts.demo then
		for _, p in Kits.demo(looks) do
			table.insert(problems, p)
		end
	end
	local errors = 0
	for _, p in problems do
		if string.sub(p, 1, 6) ~= "note: " then
			errors += 1
		end
	end
	local msg = string.format(
		"crew kit v%d: %d species, %d accessories, %d expressions; %d problem(s)",
		looks.KitVersion,
		#crew.Animals:GetChildren(),
		#crew.Accessories:GetChildren(),
		#expressions:GetChildren(),
		errors
	)
	if #problems > 0 then
		msg ..= "\n" .. table.concat(problems, "\n")
	end
	return msg
end

return Kits
