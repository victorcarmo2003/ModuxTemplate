--!strict
-- Hot zones of the run for RoMetrics (owner request 2026-10-21, Provisional; MetricsService/Zones.luau, event
-- Zone:run.<zone>). World-space boxes of the restaurant (MAP01_Restaurant) measured 2026-10-21. The pantry and the
-- kitchen are not here: they come from Restaurant.SafeBoxes[1] and the trailer LightZone (VehicleService:IsInsidePoint).
-- If the restaurant moves, measure the boxes again (phase 2: Parts tagged RunZone instead of numbers).
--   Boxes       ordered list, the first box that holds the player wins; anything else is "street"
--   Hysteresis  studs a box grows by while the player is already inside it (no flicker on the edge)
--   MinStay     s a new zone must hold before it counts (a walk across a box is not a visit)
local Table = require(script.Parent.Table)

export type Box = { Key: string, Min: Vector3, Max: Vector3 }

export type RunZones = {
	Hysteresis: number,
	MinStay: number,
	Boxes: { Box },
}

-- Y is wide on purpose: it covers who jumps and the floor of the whole restaurant
const MIN_Y = -5
const MAX_Y = 40

const runZones: RunZones = {
	Hysteresis = 1.5,
	MinStay = 1,
	Boxes = {
		{ Key = "patio", Min = Vector3.new(-60.75, MIN_Y, 13.6), Max = Vector3.new(-23.75, MAX_Y, 36.3) },
		{ Key = "drive_thru", Min = Vector3.new(-75.5, MIN_Y, -4), Max = Vector3.new(-61, MAX_Y, 52) },
		{ Key = "gear_stand", Min = Vector3.new(-70, MIN_Y, -41), Max = Vector3.new(-36, MAX_Y, -22) },
		{ Key = "backyard", Min = Vector3.new(-50, MIN_Y, -22), Max = Vector3.new(-25, MAX_Y, -11.2) },
		{ Key = "plaza", Min = Vector3.new(57, MIN_Y, 2), Max = Vector3.new(108, MAX_Y, 38) },
	},
}

return Table.record(runZones)
