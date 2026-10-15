--!strict
-- Class skill icons (TASK-302): Assets/textures/ui/skills/<key>.png (tools/icons/skill_icons.py, 512², full colour),
-- uploaded 2026-10-15; the same ids are in Assets/textures/ui/_texture_ids.json. Keyed by Content.Classes Skills[].Icon.
-- A key missing here = not uploaded: the skill card draws the check / warning sheet icon instead.
const IMAGES: { [string]: string } = {
	skill_all_round = "rbxassetid://101277155698783",
	skill_quick_legs = "rbxassetid://109873697593524",
	skill_jumpy = "rbxassetid://74140266588682",
	skill_grill_master = "rbxassetid://109638672607639",
	skill_short_strides = "rbxassetid://76938696308326",
	skill_bear_hug = "rbxassetid://139375411038035",
	skill_heavy_load = "rbxassetid://105661406534864",
	skill_sweet_talk = "rbxassetid://122680449712427",
	skill_short_fuse = "rbxassetid://78689137102988",
	skill_wide_awake = "rbxassetid://70395373336169",
	skill_daydreamer = "rbxassetid://107428949866548",
	skill_double_shot = "rbxassetid://111408607319769",
	skill_spooked = "rbxassetid://97220050409170",
	skill_rally_cry = "rbxassetid://140273171119277",
	skill_big_ego = "rbxassetid://73496536055712",
}

return table.freeze(IMAGES)
