--!strict
-- Class skill icons (TASK-302): Assets/textures/ui/skills/<key>.png (tools/icons/skill_icons.py, 512², full colour),
-- uploaded 2026-10-15 (re-uploaded the same day: Jumpy redraw, retro sunburst tiles); same ids in
-- Assets/textures/ui/_texture_ids.json. Keyed by Content.Classes Skills[].Icon.
-- A key missing here = not uploaded: the skill card draws the check / warning sheet icon instead.
const IMAGES: { [string]: string } = {
	skill_all_round = "rbxassetid://93045839017014",
	skill_quick_legs = "rbxassetid://99771682520330",
	skill_jumpy = "rbxassetid://78936497381092",
	skill_grill_master = "rbxassetid://132521893430698",
	skill_short_strides = "rbxassetid://130532625260859",
	skill_bear_hug = "rbxassetid://98318401147123",
	skill_heavy_load = "rbxassetid://95742465283871",
	skill_sweet_talk = "rbxassetid://103412077589958",
	skill_short_fuse = "rbxassetid://112499241552093",
	skill_wide_awake = "rbxassetid://106035613791603",
	skill_daydreamer = "rbxassetid://108059087541126",
	skill_double_shot = "rbxassetid://107514534507180",
	skill_spooked = "rbxassetid://104958724036356",
	skill_rally_cry = "rbxassetid://105687573882541",
	skill_big_ego = "rbxassetid://88706500072433",
}

return table.freeze(IMAGES)
