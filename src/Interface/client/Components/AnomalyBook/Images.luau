--!strict
-- "Photos" of the Anomaly Book pages (TASK-335): Assets/textures/ui/journal/<key>.png, drawn by
-- tools/icons/journal_art.py (house sticker style, 512 x 352 full-bleed night scenes) and uploaded through the Roblox
-- Studio MCP. Ids also in Assets/textures/ui/_texture_ids.json ("journal/<key>"). Keyed by Content.Journal key.
-- A key missing here = not uploaded: the page draws the placeholder (Ref + "?" on a dark photo).
const IMAGES: { [string]: string } = {
	anm_001_blank_folks = "rbxassetid://76000405654794",
	anm_002_wrong_food = "rbxassetid://86041011680876",
	anm_003_stopped_clock = "rbxassetid://117343956512612",
	anm_004_copies = "rbxassetid://77521369000258",
	anm_005_raincoat_lady = "rbxassetid://129526796423118",
	anm_007_walker = "rbxassetid://89432669206770",
	anm_008_long_car = "rbxassetid://75671419738450",
	anm_009_knock = "rbxassetid://89576581841548",
	anm_010_hush = "rbxassetid://110216234677874",
	anm_011_shaker = "rbxassetid://128515378905398",
	anm_012_turned_neck = "rbxassetid://110789421900817",
	anm_013_white_eyes = "rbxassetid://85373832088968",
	anm_014_big_head = "rbxassetid://108745247640085",
	anm_015_floater = "rbxassetid://131390424347349",
	anm_016_starer = "rbxassetid://106958151892432",
	anm_017_crawler = "rbxassetid://116338746621073",
	anm_018_grin = "rbxassetid://83205393071431",
	anm_019_roof_walker = "rbxassetid://80872657964057",
	anm_020_blackout = "rbxassetid://94051016985185",
}

return table.freeze(IMAGES)
