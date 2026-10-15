--!strict
-- Front of the trailer, shared by the server and the client of the anomalies that come to the service window
-- (TASK-331 ANM-008 long car; same frame as Effects/Kit/Hide). Pure: no Modux, Lync or Vide; the caller passes the
-- MapPoints (server MapIndex.FindPoint, client ctx.Point), so both sides compute the same pose.
--   Out     horizontal unit from the trailer pivot (MapPoint TRL) to the street: towards WALKER-10 (across the street,
--           MAP-01 §5.6) when the place has it, else the pose's LookVector.
--   Window  service window spot, WINDOW_OUT studs out from the pivot.
--   Stop    where the long car brakes: STOP_OUT studs out (on the street), nose turned to the window.
-- PROVISIONAL (TASK-331): distances measured on MAP-01 (window wall ~6 out, lane ~24 out).
local TrailerFront = {}

const WINDOW_OUT = 9 -- studs from the trailer pivot to the window spot (Kit/Hide WINDOW_OUT)
const STOP_OUT = 21 -- studs from the trailer pivot to the centre of the braked car (nose ~10 from the window)

export type Front = {
	Out: Vector3,
	Window: Vector3,
	Stop: CFrame, -- car pivot on the ground, LookVector = towards the window
}

local function flat(vector: Vector3): Vector3
	const out = Vector3.new(vector.X, 0, vector.Z)
	return if out.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else out.Unit
end

function TrailerFront.Of(trailer: CFrame, across: CFrame?): Front
	const out = if across ~= nil then flat(across.Position - trailer.Position) else flat(trailer.LookVector)
	const base = trailer.Position
	const stop = base + out * STOP_OUT
	return {
		Out = out,
		Window = base + out * WINDOW_OUT,
		Stop = CFrame.lookAt(stop, stop - out),
	}
end

return table.freeze(TrailerFront)
