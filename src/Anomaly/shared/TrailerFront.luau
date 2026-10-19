--!strict
-- Front of the trailer, shared by the server and the client of the anomalies that come to the service window
-- (TASK-331 ANM-008 long car; same frame as Effects/Kit/Hide). Pure: no Modux, Lync or Vide; the caller passes the
-- MapPoints (server MapIndex.FindPoint, client ctx.Point), so both sides compute the same pose.
--   Out     horizontal unit from the trailer pivot (MapPoint TRL) to the street: towards WALKER-10 (across the street,
--           MAP-01 §5.6) when the place has it, else the pose's LookVector.
--   Window  service window spot, WINDOW_OUT studs out from the pivot.
--   Stop    where the long car brakes: STOP_OUT studs out (on the street), nose turned to the window. Its height is
--           `ground` (the street: the lane MapPoint E-IN) when given: the TRL pivot sits below the street (MAP-01: Y -1.52
--           vs road ~0), so a car at the pivot height was sunk in the ground (TASK-348).
-- PROVISIONAL (TASK-331): distances measured on MAP-01 (window wall ~6 out, lane ~24 out).
local TrailerFront = {}

const WINDOW_OUT = 9 -- studs from the trailer pivot to the window spot (Kit/Hide WINDOW_OUT)
const STOP_OUT = 21 -- studs from the trailer pivot to the centre of the braked car (nose ~10 from the window)

export type Front = {
	Out: Vector3,
	Window: Vector3,
	Stop: CFrame, -- car pivot on the ground (Y = `ground` when given), LookVector = towards the window
}

local function flat(vector: Vector3): Vector3
	const out = Vector3.new(vector.X, 0, vector.Z)
	return if out.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else out.Unit
end

function TrailerFront.Of(trailer: CFrame, across: CFrame?, ground: number?): Front
	const out = if across ~= nil then flat(across.Position - trailer.Position) else flat(trailer.LookVector)
	const base = trailer.Position
	const flatStop = base + out * STOP_OUT
	const stop = if ground ~= nil then Vector3.new(flatStop.X, ground, flatStop.Z) else flatStop
	return {
		Out = out,
		Window = base + out * WINDOW_OUT,
		Stop = CFrame.lookAt(stop, stop - out),
	}
end

-- Restaurant (TASK-490, DEC-279 "the long car goes to the drive-thru"): the car comes down the drive-thru lane from the
-- street and brakes at MapPoint DT-STOP with its nose turned NOSE_YAW towards the kitchen (MapPoint TRL), so its high
-- beam lands on the drive-thru window. `from` = a point it comes from (the street abeam the stop).
const NOSE_YAW = math.rad(28)
const DT_WINDOW_OUT = 6 -- studs from DT-STOP towards the kitchen to the drive-thru window spot

function TrailerFront.DriveThru(stop: CFrame, kitchen: CFrame, from: Vector3, ground: number?): Front
	const toKitchen = flat(kitchen.Position - stop.Position)
	const travel = flat(stop.Position - from)
	-- yaw the travel direction a little towards the kitchen side
	const side = if travel:Cross(Vector3.yAxis):Dot(toKitchen) > 0 then -1 else 1
	const nose = (CFrame.fromAxisAngle(Vector3.yAxis, side * NOSE_YAW) * CFrame.new(Vector3.zero, travel)).LookVector
	const base = stop.Position
	const position = if ground ~= nil then Vector3.new(base.X, ground, base.Z) else base
	return {
		Out = -toKitchen,
		Window = base + toKitchen * DT_WINDOW_OUT,
		Stop = CFrame.lookAt(position, position + flat(nose)),
	}
end

-- The front for the current map: the drive-thru stop when DT-STOP is bound (coming from the lane of
-- `lane`, abeam the stop), else the trailer front. Same call on the server (Anomalies/ANM-008) and the client.
function TrailerFront.Pick(trailer: CFrame, across: CFrame?, lane: CFrame?, driveStop: CFrame?): Front
	const ground = if lane ~= nil then lane.Position.Y else nil
	if driveStop ~= nil then
		local from = driveStop.Position + Vector3.new(0, 0, 40)
		if lane ~= nil then
			const dir = flat(lane.LookVector)
			from = lane.Position + dir * (driveStop.Position - lane.Position):Dot(dir)
		end
		return TrailerFront.DriveThru(driveStop, trailer, from, ground)
	end
	return TrailerFront.Of(trailer, across, ground)
end

return table.freeze(TrailerFront)
