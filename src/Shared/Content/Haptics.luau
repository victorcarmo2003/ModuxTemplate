--!strict
-- Haptics: the vibration profiles of the client (TASK-268; owner request 2026-10-14, Provisional). One table for every device
-- that vibrates (PlayStation and Xbox controllers, phones where HapticService supports it): the same profile feels the same on
-- PS and Xbox. Read only by Input/client/Haptics (the one module that touches HapticService); the Settings switch `Vibration`
-- turns all of it off. Only the own player ever vibrates.
--   Large / Small   motor strength 0..1 (Large = the heavy, low rumble; Small = the light, high buzz). A device with a single
--                   motor gets the larger of the two
--   Duration        s; 0 = continuous until stopped (`Haptics.Hold`)
-- Owner: game-designer (numbers), frontend (keys). Tiers by the owner: strong and short on scares, medium on car hits and slams,
-- light on prep actions.
local Table = require(script.Parent.Table)

export type Profile = {
	Large: number,
	Small: number,
	Duration: number,
}

export type Key = "Scare" | "Grab" | "Faint" | "Hit" | "Slam" | "Pour" | "Mark" | "Good" | "Flip" | "Serve" | "Tap"

const profiles: { [Key]: Profile } = {
	-- scares: strong and short
	Scare = { Large = 1, Small = 1, Duration = 0.35 }, -- jump scare face of the V2 anomalies
	Grab = { Large = 1, Small = 0.6, Duration = 0.45 }, -- grabbed by an anomaly
	Faint = { Large = 0.9, Small = 0.3, Duration = 0.5 }, -- the own player went Down
	-- medium
	Hit = { Large = 0.6, Small = 0.4, Duration = 0.3 }, -- run over by a car
	Slam = { Large = 0.5, Small = 0.2, Duration = 0.18 }, -- a door / the window slams
	-- prep (light)
	Pour = { Large = 0, Small = 0.18, Duration = 0 }, -- while a sauce pours (continuous)
	Mark = { Large = 0.35, Small = 0.6, Duration = 0.1 }, -- a Perfect: the mark was hit
	Good = { Large = 0, Small = 0.4, Duration = 0.07 }, -- a Good
	Flip = { Large = 0.25, Small = 0.45, Duration = 0.09 }, -- the sausage flip
	Serve = { Large = 0.2, Small = 0.35, Duration = 0.12 }, -- the plate handed over
	Tap = { Large = 0, Small = 0.25, Duration = 0.05 }, -- a light confirm
}

return Table.record({
	Profiles = profiles,
	-- s: the motors stop by themselves after this even if a continuous profile was never stopped (a leak guard)
	MaxHold = 6,
})
