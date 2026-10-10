--!strict
--[[
	CrewRig (TASK-016): production character rig for the crew and every NPC (architecture.md §18.9.2,
	network.md §5 T40). ReplicatedStorage.shared.Crew.CrewRig. Pure shared module: no Modux, Lync, Vide, Charm
	nor self.Libs; no network; no runtime asset loading (kits only, §18.9 rule 1).

	Server × client split (T40):
	  Build(species, outfit, opts) -> Model   server (CharacterService, NpcService) or a client for local rigs
	      geometry from ReplicatedStorage.Assets.Crew, AnimalRig tag, attributes Species, Outfit, CustomerType,
	      LookPack. Afterwards the server only changes attributes.
	  Dress(model, pack?, expression?) -> boolean   client only (RigController dresses every AnimalRig)
	      TextureID of outfit / head / atlas pieces for the pack and the face SurfaceAppearance.
	  PackForSanity(value, bands) -> Pack   pure: DEC-167 band -> pack (bands come from Content.Sanity, wave 2)

	Prototype mapping (tools/assetplace/build_crew.luau): Crew.build -> Build; Crew.applyTime + Crew.setExpression ->
	Dress; Crew.setSanity -> server writes LookPack = PackForSanity(...) and every client re-dresses.
]]
local Build = require(script.Build)
local CrewLooks = require(script.Parent.CrewLooks)
local Dress = require(script.Dress)

export type Pack = CrewLooks.Pack
export type BuildOptions = Build.Options
-- Sanity thresholds in absolute points (DEC-167): >= High -> Day, >= Mid -> Mid, below -> Night.
export type Bands = { High: number, Mid: number }

-- Attributes the client re-dresses on (network.md §5.2). NpcId is identity, not look.
const LOOK_ATTRIBUTES = table.freeze({ "Species", "Outfit", "CustomerType", "LookPack" })

local function packForSanity(value: number, bands: Bands): Pack
	if value >= bands.High then
		return "Day"
	elseif value >= bands.Mid then
		return "Mid"
	end
	return "Night"
end

return table.freeze({
	Tag = Build.Tag,
	LookAttributes = LOOK_ATTRIBUTES,
	Build = Build.Build,
	Dress = Dress.Dress,
	EffectivePack = Dress.EffectivePack,
	AsPack = Dress.AsPack,
	PackForSanity = packForSanity,
})
