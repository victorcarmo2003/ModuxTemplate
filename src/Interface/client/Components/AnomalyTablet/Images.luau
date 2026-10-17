--!strict
-- "Photos" of the Anomaly Tablet pages, keyed by Content.Journal key. Flash photos (owner request 2026-10-17): each
-- anomaly staged with the real game pieces in a dark booth in Studio (tools/studio/anomaly_photos.luau), captured and
-- graded as a flash photo (crop 512 x 352, hotspot, vignette, grain), saved as Assets/textures/ui/journal_photo/<key>.png
-- and uploaded through the Roblox Studio MCP. Ids also in Assets/textures/ui/_texture_ids.json ("journal_photo/<key>").
-- The drawn sticker art of TASK-335 / TASK-345 stays in Assets/textures/ui/journal/ ("journal/<key>" ids).
-- A key missing here = not uploaded: the page draws the placeholder ("?" on a dark print).
const IMAGES: { [string]: string } = {
	anm_001_blank_folks = "rbxassetid://93411118395581",
	anm_002_wrong_food = "rbxassetid://85434082247860",
	anm_003_stopped_clock = "rbxassetid://72527470459890",
	anm_004_copies = "rbxassetid://127849355243716",
	anm_005_raincoat_lady = "rbxassetid://127161413498365",
	anm_006_stalker = "rbxassetid://112559536931919",
	anm_007_walker = "rbxassetid://137336318915315",
	anm_008_long_car = "rbxassetid://107979332456309",
	anm_009_knock = "rbxassetid://122437612318104",
	anm_010_hush = "rbxassetid://138604106785686",
	anm_011_shaker = "rbxassetid://98508073816330",
	anm_012_turned_neck = "rbxassetid://74951304086312",
	anm_013_white_eyes = "rbxassetid://102929708473321",
	anm_014_big_head = "rbxassetid://88705198308866",
	anm_015_floater = "rbxassetid://88597122913821",
	anm_016_starer = "rbxassetid://126146357945175",
	anm_017_crawler = "rbxassetid://113714055015815",
	anm_018_grin = "rbxassetid://116836648031335",
	anm_019_roof_walker = "rbxassetid://107194096377875",
	anm_020_blackout = "rbxassetid://116889914786039",
}

return table.freeze(IMAGES)
