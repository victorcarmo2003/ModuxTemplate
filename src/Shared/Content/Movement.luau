--!strict
-- Walking feel of NPCs and passers-by (playtest 2026-10-12: movement too robotic). Every number is PROVISIONAL
-- (frontend-coder, 2026-10-12): tune in Play, no DEC. Code reads only from here.
--   * Corner: rounded corners of a graph walk (NpcService/Walker). Entry / middle / exit points of a quadratic curve
--     replace the corner point; a corner is only rounded when the chords are clear (raycast) and it is no crosswalk
--     point (curb points stay fixed, so the walker still crosses on the middle of the zebra).
--   * Accept: a point that is only passed through (loose) counts as reached inside this radius, so the rig does not stop
--     at it. radius = clamp(PerSpeed * WalkSpeed, Min, Max).
--   * Speed: easing of the Humanoid WalkSpeed at the start and the end of a walk, and the per-NPC variation.
--   * Turn: the body turns with an AlignOrientation (max angular speed) and looks a bit ahead towards the next point.
--   * Pedestrian: client only (PedestrianController): the drawn point is the polyline averaged over +-Smooth studs
--     (rounds the corners, the distance along the path and the server timing do not change) and the yaw is damped.
export type Rules = {
	Corner: {
		Radius: number, -- studs: how far from the corner the curve starts
		MinAngle: number, -- degrees: turns smaller than this stay as they are (the straight line is fine)
		MinRadius: number, -- studs: a corner that fits less than this (short edges) is not rounded
		EdgeShare: number, -- share of an edge a curve may use (two corners share one edge)
		RayHeight: number, -- studs above the floor point of the safety raycast
	},
	Accept: { Min: number, PerSpeed: number, Max: number },
	Speed: {
		Variation: number, -- +- share of WalkSpeed per NPC (0.08 = +-8%)
		StartFactor: number, -- share of WalkSpeed in the first instant of a walk
		StartTime: number, -- seconds to reach full speed
		EndFactor: number, -- share of WalkSpeed at the last point
		BrakeDistance: number, -- studs before the last point where the slow-down starts
	},
	Turn: {
		Rate: number, -- degrees per second (max angular speed)
		Responsiveness: number, -- AlignOrientation response (how fast it closes the gap)
		LookAhead: number, -- studs: from this distance to the point the body already leans towards the next one
		LookBlend: number, -- 0..1 share of the next direction at the point itself
		FaceMin: number, -- degrees: a final facing smaller than this is set at once
		FaceTime: number, -- seconds the final facing may take
	},
	Pedestrian: {
		Smooth: number, -- studs each side of the averaging window on the path (0 = off)
		CrosswalkRamp: number, -- studs before / after a crosswalk where the window closes to 0 (zebra stays exact)
		HeadingHalf: number, -- studs each side of the facing chord (look-ahead)
		TurnRate: number, -- degrees per second, cap of the yaw
		TurnEase: number, -- 1/s exponential ease of the yaw
	},
}

const Movement: Rules = {
	Corner = { Radius = 3.5, MinAngle = 15, MinRadius = 0.8, EdgeShare = 0.45, RayHeight = 2.5 },
	Accept = { Min = 1.0, PerSpeed = 0.13, Max = 2.2 },
	Speed = { Variation = 0.08, StartFactor = 0.55, StartTime = 0.5, EndFactor = 0.45, BrakeDistance = 3.5 },
	Turn = { Rate = 480, Responsiveness = 30, LookAhead = 6, LookBlend = 0.6, FaceMin = 25, FaceTime = 0.7 },
	Pedestrian = { Smooth = 2.2, CrosswalkRamp = 3, HeadingHalf = 2.5, TurnRate = 540, TurnEase = 10 },
}

return table.freeze(Movement)
