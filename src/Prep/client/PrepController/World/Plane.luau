--!strict
-- World/Plane: the maths between the pointer ray and the BUN SPACE of Content.Prep.Build (docs/tech/prep-3d.md §2.3, DT-13,
-- TASK-197). A plane is the top of the bun: its frame is the pose of the bun (X along the length, Y up = the normal, Z toward
-- the player), its Length and Width are the studs of the bun; uv is 0..1 on both axes, u to the right along the length, v
-- toward the player (down on the screen), the same space the cut line (y 0.5), the groove (0.5, 0.5), the sauce path and the
-- bacon rings are written in. Gestures reads a PlaneRegion built from this instead of a GuiObject, so slice, place, trace,
-- slide, taps, hold and Score never learn that the board became 3D.
-- Pure: Vector2 / Vector3 / CFrame only, no services, no Instances (Spec.luau runs the table of cases below).
local Types = require(script.Parent.Types)

export type Plane = {
	Frame: CFrame, -- centre of the bun top; the frame's Y axis is the normal, X the length, Z the width
	Length: number, -- studs along X
	Width: number, -- studs along Z
}

-- Maps a screen point (px) to a ray: its origin and unit direction. nil = no ray (the camera is not ready).
export type RayOf = (px: Vector2) -> (Vector3?, Vector3?)

const EPSILON = 1e-6

const Plane = {}

function Plane.new(frame: CFrame, length: number, width: number): Plane
	return { Frame = frame, Length = math.max(length, EPSILON), Width = math.max(width, EPSILON) }
end

-- Width / height of the bun: the `Aspect` of a PlaneRegion (Gestures needs it for the path length).
function Plane.Aspect(plane: Plane): number
	return plane.Length / plane.Width
end

function Plane.Normal(plane: Plane): Vector3
	return plane.Frame.UpVector
end

-- Where the ray meets the infinite plane through `origin` with `normal`: the point, nil when the ray is parallel to the plane
-- or looks away from it.
function Plane.Intersect(rayOrigin: Vector3, direction: Vector3, origin: Vector3, normal: Vector3): Vector3?
	const denominator = direction:Dot(normal)
	if math.abs(denominator) < EPSILON then
		return nil
	end
	const distance = (origin - rayOrigin):Dot(normal) / denominator
	if distance < 0 then
		return nil
	end
	return rayOrigin + direction * distance
end

-- World point -> uv (the point is projected on the plane first, so a lifted point maps to the uv under it).
function Plane.ToUV(plane: Plane, world: Vector3): Vector2
	const local_ = plane.Frame:PointToObjectSpace(world)
	return Vector2.new(local_.X / plane.Length + 0.5, local_.Z / plane.Width + 0.5)
end

-- uv -> world point on the bun top, `lift` studs above it along the normal (a carried object floats Rules.World.Lift).
function Plane.ToWorld(plane: Plane, uv: Vector2, lift: number?): Vector3
	const local_ = Vector3.new((uv.X - 0.5) * plane.Length, lift or 0, (uv.Y - 0.5) * plane.Width)
	return plane.Frame * local_
end

-- Ray -> uv on the bun top, and the world point; nil when the ray misses the plane (it may land outside 0..1: the bun edge).
function Plane.FromRay(plane: Plane, rayOrigin: Vector3, direction: Vector3): (Vector2?, Vector3?)
	const point = Plane.Intersect(rayOrigin, direction, plane.Frame.Position, plane.Frame.UpVector)
	if point == nil then
		return nil, nil
	end
	return Plane.ToUV(plane, point), point
end

-- A pixel inside the bun?
local function insideUV(uv: Vector2): boolean
	return uv.X >= 0 and uv.X <= 1 and uv.Y >= 0 and uv.Y <= 1
end

-- The PlaneRegion Gestures arms on: `rayOf` is the pointer ray of the camera (World/Ray) or a synthetic one in the tests.
-- Normalise of a pixel that misses the plane answers (0, 0) like a GuiObject with no size; Inside is false then.
function Plane.Region(plane: Plane, rayOf: RayOf): Types.PlaneRegion
	local function uvOf(px: Vector2): Vector2?
		const origin, direction = rayOf(px)
		if origin == nil or direction == nil then
			return nil
		end
		return (Plane.FromRay(plane, origin, direction))
	end
	return {
		Inside = function(px: Vector2): boolean
			const uv = uvOf(px)
			return uv ~= nil and insideUV(uv)
		end,
		Normalise = function(px: Vector2): Vector2
			return uvOf(px) or Vector2.zero
		end,
		Aspect = Plane.Aspect(plane),
	}
end

-- The ray of a pinhole camera: `frame` looks down -Z, `fovY` degrees (vertical), `viewport` px, `px` from the top left. The same
-- thing Camera:ViewportPointToRay does, in pure maths (the tests and a camera that is not the current one).
function Plane.PinholeRay(frame: CFrame, fovY: number, viewport: Vector2, px: Vector2): (Vector3, Vector3)
	const halfHeight = math.tan(math.rad(fovY) / 2)
	const x = (px.X / viewport.X * 2 - 1) * halfHeight * viewport.X / viewport.Y
	const y = (1 - px.Y / viewport.Y * 2) * halfHeight
	return frame.Position, frame:VectorToWorldSpace(Vector3.new(x, y, -1)).Unit
end

-- The inverse: where a world point lands on the screen (px), nil when it is behind the camera.
function Plane.PinholeProject(frame: CFrame, fovY: number, viewport: Vector2, world: Vector3): Vector2?
	const local_ = frame:PointToObjectSpace(world)
	if local_.Z >= -EPSILON then
		return nil
	end
	const halfHeight = math.tan(math.rad(fovY) / 2)
	const x = local_.X / -local_.Z / (halfHeight * viewport.X / viewport.Y)
	const y = local_.Y / -local_.Z / halfHeight
	return Vector2.new((x + 1) / 2 * viewport.X, (1 - y) / 2 * viewport.Y)
end

return table.freeze(Plane)
