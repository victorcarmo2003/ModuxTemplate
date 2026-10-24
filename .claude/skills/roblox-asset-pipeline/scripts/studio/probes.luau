--[[
	Geometry probes for verifying imported/placed assets in Studio (edit mode, Studio MCP execute_luau).

		local Probes = require(<this module>)
		Probes.size(model)                         -> "X, Y, Z" bbox in studs
		Probes.front(model, Vector3.new(1.4, 0.21, 0)) -> which local side (-Z/+Z) a protruding feature is on
		Probes.armTip(pole, 11)                     -> world point of the far end of a pole's arm (rays down)
		Probes.seatOnTip(head, tipWorld)            -> moves head so its bbox centre XZ sits on the tip, returns delta

	front(): casts rays along local Z from both sides at a point offset `feature` from the pivot (a knob, a
	handle) and at the same height on the centre line; the side where the feature ray hits earlier (sticks out)
	is the front. Asset convention: front must be -Z.
]]

local Probes = {}

local function params(model: Instance): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = { model }
	return p
end

function Probes.size(model: Model): string
	local _, s = model:GetBoundingBox()
	return string.format("%.3f, %.3f, %.3f", s.X, s.Y, s.Z)
end

function Probes.front(model: Model, feature: Vector3): string
	local cf = model:GetPivot()
	local p = params(model)
	local function depth(offset: Vector3, side: number): number?
		local origin = cf:PointToWorldSpace(offset + Vector3.new(0, 0, side * 50))
		local dir = cf:VectorToWorldSpace(Vector3.new(0, 0, -side * 100))
		local r = workspace:Raycast(origin, dir, p)
		return r and cf:PointToObjectSpace(r.Position).Z
	end
	local centre = Vector3.new(0, feature.Y, 0)
	local out = {}
	for _, side in { -1, 1 } do
		local f = depth(Vector3.new(feature.X, feature.Y, 0), side)
		local c = depth(centre, side)
		local sticks = f and c and (math.abs(f) - math.abs(c)) > 0.005
		table.insert(out, string.format("%s: feature %.3f centre %.3f%s", side < 0 and "-Z" or "+Z", f or 0, c or 0, sticks and "  <- feature protrudes" or ""))
	end
	return table.concat(out, " | ")
end

-- Far end of a horizontal arm on top of a pole: rays straight down along local +/-Z, keep the farthest hit
-- higher than minHeight above the pivot.
function Probes.armTip(pole: Model, minHeight: number?): Vector3?
	local cf = pole:GetPivot()
	local p = params(pole)
	local best, bestK = nil, -1
	for _, s in { 1, -1 } do
		for k = 0, 60 do
			local o = cf:PointToWorldSpace(Vector3.new(0, 0, s * k * 0.1))
			local r = workspace:Raycast(Vector3.new(o.X, cf.Y + 40, o.Z), Vector3.new(0, -35, 0), p)
			if r and r.Position.Y > cf.Y + (minHeight or 10) and k > bestK then
				best, bestK = r.Position, k
			end
		end
	end
	return best
end

function Probes.seatOnTip(head: Model, tip: Vector3, inset: number?): Vector3
	local hcf = head:GetBoundingBox()
	local delta = Vector3.new(tip.X - hcf.X, 0, tip.Z - hcf.Z)
	if inset then
		delta -= delta.Unit * inset
	end
	head:PivotTo(head:GetPivot() + delta)
	return delta
end

return Probes
