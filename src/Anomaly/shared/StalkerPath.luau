--!strict
-- Path of ANM-006 The stalker (DEC-260, TASK-351), shared by the server (gaze target, step count) and the client (where
-- the figure stands): a straight line on the street from START_OUT studs out of the trailer, across the street, to
-- the service window (TrailerFront). Step 0 = the far end, Steps = at the window. Pure: no Modux, Lync or Vide.
local TrailerFront = require(script.Parent.TrailerFront)

const StalkerPath = {}

const START_OUT = 40 -- studs from the trailer pivot: the far sidewalk, in full view of the service window
const END_OUT = 11 -- studs from the trailer pivot: just outside the service window (TrailerFront window spot is 9)
const HEIGHT = 3 -- studs above the ground: the figure's chest (gaze target)

StalkerPath.Height = HEIGHT

-- Feet of the figure at `step` (0..steps, fractions allowed). `ground` = street height (MapPoint E-IN).
function StalkerPath.At(front: TrailerFront.Front, base: Vector3, ground: number, step: number, steps: number): Vector3
	const t = math.clamp(if steps > 0 then step / steps else 1, 0, 1)
	const out = START_OUT + (END_OUT - START_OUT) * t
	const flat = base + front.Out * out
	return Vector3.new(flat.X, ground, flat.Z)
end

return table.freeze(StalkerPath)
