--!strict
-- Textures of the class skins by Content.Skins key (AST-123; design/skins-proposal.md), read by CrewRig.Build / Dress while
-- the rig's Skin attribute names the skin:
--   Day / Mid / Night   outfit sheet of the pieces with the OutfitPart attribute (same UV as T_Crew_Uniform_*)
--   Atlas               the character colour atlas (T_Atlas_Kitchen_<Pack>) with the cap cells in the skin colour and the
--                       species fur cell in the skin fur: worn by the rig's atlas pieces (ears-up cap, ears, tail, beak...),
--                       the ones whose DayTextureID is BaseAtlas
--   Head                (skins with their own fur) the species head over the skin fur, opaque: the uploaded heads carry
--                       the species fur baked in, so MeshPart.Color alone does not recolour them
-- Sources: tools/assetplace/gen_skin_textures.py -> Assets/textures/character/skins/T_Skin_<Sheet>[Atlas]_<Pack>.png, uploaded
-- 2026-10-17 (Studio upload_image), ids in Assets/textures/character/skins/_texture_ids.json. A repaint = new upload = new
-- ids here. A skin without a row here dresses in the crew uniform (warned once by Dress).

export type Pack = "Day" | "Mid" | "Night"
export type Sheets = { Day: string, Mid: string, Night: string }
export type SkinLook = { Day: string, Mid: string, Night: string, Atlas: Sheets, Head: Sheets? }

const looks: { [string]: SkinLook } = {
	skin_dog_pumpkin = { -- T_Skin_Pumpkin_<Pack>, T_Skin_PumpkinAtlas_<Pack>
		Day = "rbxassetid://136643794082102",
		Mid = "rbxassetid://86692085643947",
		Night = "rbxassetid://109901189487301",
		Atlas = {
			Day = "rbxassetid://88217208838016",
			Mid = "rbxassetid://114327212759123",
			Night = "rbxassetid://81765892971829",
		},
	},
	skin_rabbit_ghost = { -- T_Skin_Ghost_<Pack>, T_Skin_GhostAtlas_<Pack>
		Day = "rbxassetid://76539180647041",
		Mid = "rbxassetid://95687172111972",
		Night = "rbxassetid://134457735843344",
		Head = {
			Day = "rbxassetid://125462171527397",
			Mid = "rbxassetid://92632567137487",
			Night = "rbxassetid://90850744550431",
		},
		Atlas = {
			Day = "rbxassetid://113093365085569",
			Mid = "rbxassetid://131371122271677",
			Night = "rbxassetid://84410288153109",
		},
	},
	skin_cat_witch = { -- T_Skin_Witch_<Pack>, T_Skin_WitchAtlas_<Pack>
		Day = "rbxassetid://116341754293027",
		Mid = "rbxassetid://130121208259417",
		Night = "rbxassetid://81413991124515",
		Head = {
			Day = "rbxassetid://96322952312950",
			Mid = "rbxassetid://117702900139378",
			Night = "rbxassetid://85536996754407",
		},
		Atlas = {
			Day = "rbxassetid://98096091102247",
			Mid = "rbxassetid://100335129047369",
			Night = "rbxassetid://83364511646446",
		},
	},
	skin_bear_franken = { -- T_Skin_Franken_<Pack>, T_Skin_FrankenAtlas_<Pack>
		Day = "rbxassetid://112204760630413",
		Mid = "rbxassetid://124737730149808",
		Night = "rbxassetid://103115523149878",
		Head = {
			Day = "rbxassetid://99405424307575",
			Mid = "rbxassetid://87948492578062",
			Night = "rbxassetid://96873088515646",
		},
		Atlas = {
			Day = "rbxassetid://113266356479503",
			Mid = "rbxassetid://75852604627872",
			Night = "rbxassetid://84754145774998",
		},
	},
	skin_fox_vampire = { -- T_Skin_Vampire_<Pack>, T_Skin_VampireAtlas_<Pack>
		Day = "rbxassetid://124733317595961",
		Mid = "rbxassetid://74900902607039",
		Night = "rbxassetid://94936711104374",
		Atlas = {
			Day = "rbxassetid://125738872666617",
			Mid = "rbxassetid://109536438477866",
			Night = "rbxassetid://112581873290893",
		},
	},
	skin_owl_skeleton = { -- T_Skin_Skeleton_<Pack>, T_Skin_SkeletonAtlas_<Pack>
		Day = "rbxassetid://111586331236376",
		Mid = "rbxassetid://89126279364079",
		Night = "rbxassetid://74475644683834",
		Head = {
			Day = "rbxassetid://76176264464136",
			Mid = "rbxassetid://102924057435343",
			Night = "rbxassetid://106187847201869",
		},
		Atlas = {
			Day = "rbxassetid://125323012040716",
			Mid = "rbxassetid://79773283279821",
			Night = "rbxassetid://95954020052660",
		},
	},
}

-- Texture of `sheets` (an outfit look or its Atlas) for a pack.
local function sheet(sheets: Sheets, pack: Pack): string
	return if pack == "Mid" then sheets.Mid elseif pack == "Night" then sheets.Night else sheets.Day
end

for _, look in looks do
	table.freeze(look.Atlas)
	if look.Head then
		table.freeze(look.Head)
	end
	table.freeze(look)
end
return table.freeze({
	-- Day colour atlas of the kit's atlas pieces (embedded in the AST-053 FBX; Mid / Night: CrewLooks.Atlas)
	BaseAtlas = "rbxassetid://114320013905837",
	BySkin = table.freeze(looks),
	Sheet = sheet,
})
