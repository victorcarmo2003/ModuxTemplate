--!strict
--[[
	Outfit sheet templates (owner report 2026-10-25: "the frog has the cat's hands"). EDIT MODE ONLY: Command Bar or
	Studio MCP (SurfaceAppearance.ColorMap is not writable by game scripts).

	Why: Roblox draws a MeshPart TextureID ignoring its alpha, so the fur texels of an outfit sheet (hands, forearms,
	shins: alpha 0, neutral grey stored under) came out grey-beige on every species, never MeshPart.Color. A
	SurfaceAppearance with AlphaMode Overlay does show MeshPart.Color under the alpha (verified in Studio 2026-10-25), so
	every outfit sheet gets one template here and CrewRig (Kit.ApplySheet) clones it onto the OutfitPart pieces, with
	MeshPart.Color = the hand colour of the worn pack (CrewLooks Fur / PackFur, SkinLooks HandFur).

	Builds ReplicatedStorage.CrewOutfitSheets (outside Rojo, like CrewExpressions): one SurfaceAppearance per distinct
	sheet id of CrewLooks.Outfits (every pack) and SkinLooks.BySkin (Day / Mid / Night), Name = the numeric id,
	AlphaMode Overlay, ColorMap = the id, attribute Sheet = "rbxassetid://<id>". Idempotent: rows already right are kept,
	stale ones removed. Rerun after any new outfit / skin sheet upload (a new id needs its template), then save the place.

	Usage (rojo serve connected, so ReplicatedStorage.shared.Crew is current):
		local src = ... -- this file's text (e.g. HttpService:GetAsync from a local http server, as build_kits.luau)
		local ms = Instance.new("ModuleScript"); ms.Source = src
		print(require(ms).run())
	Or pass the tables: require(ms).run({ looks = <CrewLooks>, skins = <SkinLooks> }).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

const FOLDER = "CrewOutfitSheets"

type Opts = { looks: any?, skins: any? }

local function fresh(module: Instance): any
	-- a clone, so an edit synced by rojo is never shadowed by the command bar's require cache
	const copy = module:Clone()
	return (require :: any)(copy)
end

local function run(opts: Opts?): string
	const o: Opts = opts or {}
	const crew = (ReplicatedStorage :: any).shared.Crew
	const looks = o.looks or fresh(crew.CrewLooks)
	const skins = o.skins or fresh(crew.SkinLooks)

	const ids: { [string]: string } = {} -- numeric id -> source note
	local function add(sheet: string?, note: string)
		const id = if sheet ~= nil then string.match(sheet, "^rbxassetid://(%d+)$") else nil
		if id ~= nil and ids[id] == nil then
			ids[id] = note
		end
	end
	for outfit, packs in looks.Outfits do
		for pack, sheet in packs do
			add(sheet, `{outfit}/{pack}`)
		end
	end
	for skin, look in skins.BySkin do
		add(look.Day, `{skin}/Day`)
		add(look.Mid, `{skin}/Mid`)
		add(look.Night, `{skin}/Night`)
	end

	local folder = ReplicatedStorage:FindFirstChild(FOLDER)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = ReplicatedStorage
	end
	assert(folder ~= nil)
	local added, kept, removed = 0, 0, 0
	for _, child in folder:GetChildren() do
		const ok = child:IsA("SurfaceAppearance")
			and ids[child.Name] ~= nil
			and child.AlphaMode == Enum.AlphaMode.Overlay
			and child.ColorMap == `rbxassetid://{child.Name}`
		if ok then
			kept += 1
		else
			child:Destroy()
			removed += 1
		end
	end
	for id, note in ids do
		if folder:FindFirstChild(id) == nil then
			const sa = Instance.new("SurfaceAppearance")
			sa.Name = id
			sa.AlphaMode = Enum.AlphaMode.Overlay
			sa.ColorMap = `rbxassetid://{id}`
			sa:SetAttribute("Sheet", `rbxassetid://{id}`)
			sa:SetAttribute("Source", note)
			sa.Parent = folder
			added += 1
		end
	end
	return `CrewOutfitSheets: {added} added, {kept} kept, {removed} removed. Save the place (Ctrl+S).`
end

return { run = run }
