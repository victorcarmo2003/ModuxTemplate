--[[
	MAP-01 map frame (2026-10-10, user's decision): the whole map was turned 180 degrees in Y in Studio around
	(0, y, 33.9436435), so a point (x, y, z) of the MAP-01 coordinates (docs, placements, binding tables: +X east,
	+Z south, origin = Juniper centre on the Ninth axis) is at world (-x, y, 67.887287 - z).

	Measured on the place (73 placements, live pivot z + placement z): K = 67.887287 (spread < 1e-5), x error < 2e-5.

	Every tool keeps its numbers in MAP-01 coordinates and converts ONLY at the Workspace boundary:
	  F(v)    MAP-01 point     -> world point          M(v)    world point     -> MAP-01 point
	  FD(v)   MAP-01 direction -> world direction      MD(v)   world direction -> MAP-01 direction
	  FCF(cf) MAP-01 CFrame    -> world CFrame         MCF(cf) world CFrame    -> MAP-01 CFrame
	  box(r)  { x0, x1, z0, z1 } MAP-01 rectangle -> world rectangle (same fields, x0 <= x1, z0 <= z1)
	So "north" in the docs (MAP-01 -Z) is world +Z, "east" (MAP-01 +X) is world -X.

	Loaded by place_assets / bind_map01 / bind_pieces / check_map01 at require time (sibling ModuleScript "map_frame"
	if there is one, else HTTP from the served repo while the Command Bar loader has HttpEnabled on; MAP-01.md §16.1).
]]

local K = 67.887287 -- world z of the MAP-01 origin's mirror: z_world = K - z_map
-- exact rotation matrix (no math.pi rounding): x -> -x, z -> -z, then + (0, 0, K)
local FRAME = CFrame.new(0, 0, K, -1, 0, 0, 0, 1, 0, 0, 0, -1)
local INV = FRAME:Inverse()

local MapFrame = {}
MapFrame.FRAME = FRAME
MapFrame.K = K
MapFrame.CENTRE = Vector3.new(0, 0, K / 2)

function MapFrame.F(v: Vector3): Vector3
	return FRAME:PointToWorldSpace(v)
end

function MapFrame.M(v: Vector3): Vector3
	return FRAME:PointToObjectSpace(v)
end

function MapFrame.FD(v: Vector3): Vector3
	return FRAME:VectorToWorldSpace(v)
end

function MapFrame.MD(v: Vector3): Vector3
	return FRAME:VectorToObjectSpace(v)
end

function MapFrame.FCF(cf: CFrame): CFrame
	return FRAME * cf
end

function MapFrame.MCF(cf: CFrame): CFrame
	return INV * cf
end

-- MAP-01 rectangle (x0..x1, z0..z1) -> world rectangle; extra fields are copied.
function MapFrame.box(r: { [string]: any }): { [string]: any }
	local out = table.clone(r)
	local a = MapFrame.F(Vector3.new(r.x0, 0, r.z0))
	local b = MapFrame.F(Vector3.new(r.x1, 0, r.z1))
	out.x0, out.x1 = math.min(a.X, b.X), math.max(a.X, b.X)
	out.z0, out.z1 = math.min(a.Z, b.Z), math.max(a.Z, b.Z)
	return out
end

return MapFrame
