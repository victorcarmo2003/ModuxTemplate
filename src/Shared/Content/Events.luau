--!strict
-- Seasonal lobby events (DEC-346, TASK-624). An event is a decoration overlay that lives in its own workspace folder,
-- never inside LOBBY_Assets: the client shows it while Enabled and before EndsAt, and takes it out of the world
-- (locally) otherwise. Plan and coordinates: docs/levels/LOBBY-halloween.md. PROVISIONAL numbers.

export type Halloween = {
	Enabled: boolean,
	EndsAt: number, -- os.time UTC; the overlay goes away after this (same as the Halloween skins, DEC-316)
	Folder: string, -- workspace folder of the overlay (tools/assetplace/HALLOWEEN_placements.luau builds it)
	ActiveDistance: number, -- studs from the camera: animations stop farther than this
	Bubbles: {
		Count: number, -- Neon spheres rising out of the cauldron liquid (client only)
		Period: number, -- s for one bubble to rise and pop
		Rise: number, -- studs over the liquid where a bubble pops
		Size: { number }, -- min, max diameter
	},
	Burst: {
		Radius: number, -- studs from the cauldron centre: walking in makes it bubble harder
		Cooldown: number, -- s between two bursts
		Duration: number, -- s the burst lasts
		Speed: number, -- bubble speed multiplier during a burst
	},
	Bats: {
		Bob: number, -- studs up and down of a flapping bat (attribute HW_Flap on its model)
		Period: number, -- s of one bob
		Sway: number, -- degrees of yaw sway
	},
}

export type Events = {
	Halloween: Halloween,
}

const events: Events = {
	Halloween = {
		Enabled = true,
		EndsAt = 1793934000, -- 2026-11-06 03:00 UTC = HALLOWEEN_END of Content.Skins (DEC-316)
		Folder = "HalloweenEvent",
		ActiveDistance = 140,
		Bubbles = { Count = 7, Period = 2.6, Rise = 1.8, Size = { 0.35, 0.7 } },
		Burst = { Radius = 8, Cooldown = 6, Duration = 2, Speed = 2.5 },
		Bats = { Bob = 0.6, Period = 3.2, Sway = 8 },
	},
}

return events
