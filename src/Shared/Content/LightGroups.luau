--!strict
-- Light groups of the game rule "dark" (content-data.md §6.4; architecture.md §19.6; FEAT-020; DEC-041, DEC-055,
-- DEC-056, DEC-189, DEC-196). Owner: game-designer + level-designer. Record id of the Lights set = IndexOf.
-- A zone is lit when it is night AND its group is on AND (HushOff = false or no Hush is running).
-- Kind: Always (on every night) · Switch (the trailer switch, only while Vehicle is the current vehicle) ·
-- Upgrade (switch + Upgrade level >= 1; radius from the LightRadius effect) · Posts (street lamps, visual; a volume
-- only where the level-designer marks one, DEC-196).
-- Zones = ZoneId attributes of the LightZone volumes in the binding (MAP-01).
local Table = require(script.Parent.Table)

export type Kind = "Always" | "Switch" | "Upgrade" | "Posts"

export type LightGroup = {
	Key: string,
	Kind: Kind,
	HushOff: boolean, -- the Hush (ANM-010) turns this group off
	Zones: { string },
	Vehicle: string?, -- key of Vehicles: the group exists only while this is the current vehicle
	Upgrade: string?, -- key of Upgrades: needs level >= 1 on the current vehicle (Kind Upgrade)
	Cooldown: number, -- seconds between two switch toggles (Kind Switch); 0 = none
	Step: number, -- seconds per post when the Hush turns the posts off by Order (Kind Posts); 0 = none
}

return Table.new({
	-- the Mart never goes out (ANM-010 safe spot)
	{ Key = "mart", Kind = "Always", HushOff = false, Zones = { "LZ-4", "LZ-5" }, Cooldown = 0, Step = 0 },
	{
		Key = "trailer_interior",
		Kind = "Switch",
		HushOff = true,
		Zones = { "LZ-1", "LZ-2" },
		Vehicle = "trailer",
		Cooldown = 0.5, -- FEAT-020
		Step = 0,
	},
	{
		Key = "trailer_lights",
		Kind = "Upgrade",
		HushOff = true,
		Zones = { "LZ-3" },
		Vehicle = "trailer",
		Upgrade = "trailer_lights",
		Cooldown = 0,
		Step = 0,
	},
	-- MAP-01 §5.6: 1.5 s per post in the Hush; no volume on the Pad <-> Mart route (DEC-196)
	{ Key = "juniper_posts", Kind = "Posts", HushOff = true, Zones = {}, Cooldown = 0, Step = 1.5 },
} :: { LightGroup })
