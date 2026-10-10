--!strict
-- AnomalyService/Vision: is a player looking at a point (architecture.md §19.13, T7; network.md §13.5; FEAT-019;
-- TASK-106). Pure: the line-of-sight test comes in as a function (the service raycasts), so the cone math runs in
-- lune too.
--
-- Gaze wire (network.md §13.5): Yaw and Pitch in degrees, Lync.angle(1) = 0..360 cyclic. Convention (PROVISIONAL,
-- TASK-106; the sender is TASK-101): the values of Camera.CFrame:ToOrientation() in degrees, i.e.
--   Pitch = deg(rx), Yaw = deg(ry)   ->   direction = CFrame.fromOrientation(rad(Pitch), rad(Yaw), 0).LookVector
-- A pitch above 180 is negative (340 = -20). Roll is ignored.
-- Looking = target within `range` studs of the eye, inside the cone of full angle `angle` degrees
-- (Sanity.SeeAngle) around the gaze, and nothing blocks the line from the eye to the target.

export type Blocked = (from: Vector3, to: Vector3) -> boolean

const Vision = {}

-- Signed degrees in (-180, 180].
function Vision.Signed(degrees: number): number
	local value = degrees % 360
	if value > 180 then
		value -= 360
	end
	return value
end

-- Unit look direction of a gaze (degrees, wire convention above).
function Vision.Direction(yaw: number, pitch: number): Vector3
	const rx = math.rad(math.clamp(Vision.Signed(pitch), -89, 89))
	const ry = math.rad(Vision.Signed(yaw))
	-- CFrame.fromOrientation(rx, ry, 0).LookVector without building a CFrame
	return Vector3.new(-math.sin(ry) * math.cos(rx), math.sin(rx), -math.cos(ry) * math.cos(rx))
end

-- Is target inside the cone (full angle in degrees) around direction, within range of eye?
function Vision.InCone(eye: Vector3, direction: Vector3, target: Vector3, range: number, angle: number): boolean
	const offset = target - eye
	const distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance < 1e-3 then
		return true
	end
	const cos = offset.Unit:Dot(direction.Unit)
	return cos >= math.cos(math.rad(angle / 2))
end

function Vision.Looking(
	eye: Vector3,
	direction: Vector3,
	target: Vector3,
	range: number,
	angle: number,
	blocked: Blocked?
): boolean
	if not Vision.InCone(eye, direction, target, range, angle) then
		return false
	end
	return blocked == nil or not blocked(eye, target)
end

return table.freeze(Vision)
