--!strict
-- Game light volumes (architecture.md §19.6, T8, T45; FEAT-020; DEC-189, DEC-196; MAP-01 §10.2). Pure module, shared:
-- LightService builds the cache, VitalService asks IsLit through it; a client may build the same cache from the
-- Lights set for a prediction (never for a rule).
--
-- Binding: Part with tag LightZone, attributes ZoneId (LZ-1..5) and Group (key of Content.LightGroups). Part.Shape
-- Block = oriented box, Ball = sphere (a "Shape" string attribute, "Block" | "Ball", wins over Part.Shape).
-- read() is the only function that touches an Instance; compile/isLit/contains work on plain values only.
--
-- isLit cost: a handful of zones (5 in MAP-01), one CFrame multiply per box and one squared distance per ball.

export type Kind = "Box" | "Ball"

export type Zone = {
	Id: string,
	Group: string,
	Kind: Kind,
	CFrame: CFrame, -- centre and orientation
	Half: Vector3, -- box half size (Box)
	Radius: number, -- sphere radius (Ball)
}

type Box = { Inverse: CFrame, Half: Vector3 }
type Ball = { Center: Vector3, Radius2: number }

-- Compiled set of lit volumes. All = everything counts as lit (day: nothing is dark, FEAT-020).
export type Cache = {
	All: boolean,
	Boxes: { Box },
	Balls: { Ball },
}

-- Per group: lit now, and optional overrides of the shape.
export type GroupState = {
	On: boolean,
	Radius: number?, -- replaces the radius of the group's Ball zones (Trailer Lights: LightRadius effect)
	Inflate: number?, -- studs added around the group's zones (Sanity.BasicLampRadius); 0 = none
}

const Zones = {}

Zones.Tag = "LightZone"

-- Reads one LightZone part. Returns nil and the problem when the binding is wrong.
function Zones.read(instance: Instance): (Zone?, string?)
	if not instance:IsA("BasePart") then
		return nil, "not a BasePart"
	end
	const id = instance:GetAttribute("ZoneId")
	const group = instance:GetAttribute("Group")
	if type(id) ~= "string" or id == "" then
		return nil, "missing ZoneId"
	end
	if type(group) ~= "string" or group == "" then
		return nil, "missing Group"
	end
	local kind: Kind = "Box"
	const shape = instance:GetAttribute("Shape")
	if shape == "Ball" then
		kind = "Ball"
	elseif shape == "Block" then
		kind = "Box"
	elseif instance:IsA("Part") and instance.Shape == Enum.PartType.Ball then
		kind = "Ball"
	elseif instance:IsA("Part") and instance.Shape ~= Enum.PartType.Block then
		return nil, `unsupported shape {instance.Shape.Name} (Block or Ball)`
	end
	const size = instance.Size
	return {
		Id = id,
		Group = group,
		Kind = kind,
		CFrame = instance.CFrame,
		Half = size / 2,
		Radius = math.min(size.X, size.Y, size.Z) / 2,
	},
		nil
end

-- Empty cache: nothing lit (night with every group off).
function Zones.empty(): Cache
	return { All = false, Boxes = {}, Balls = {} }
end

-- Cache where every position is lit (day).
function Zones.all(): Cache
	return { All = true, Boxes = {}, Balls = {} }
end

-- Keeps the zones whose group is on, with the group's radius/inflate overrides applied.
function Zones.compile(zones: { Zone }, groups: { [string]: GroupState }): Cache
	const cache = Zones.empty()
	for _, zone in zones do
		const state = groups[zone.Group]
		if state == nil or not state.On then
			continue
		end
		const inflate = math.max(state.Inflate or 0, 0)
		if zone.Kind == "Ball" then
			const radius = (if state.Radius ~= nil then state.Radius else zone.Radius) + inflate
			if radius > 0 then
				table.insert(cache.Balls, { Center = zone.CFrame.Position, Radius2 = radius * radius })
			end
		else
			const half = zone.Half + Vector3.one * inflate
			table.insert(cache.Boxes, { Inverse = zone.CFrame:Inverse(), Half = half })
		end
	end
	return cache
end

-- Is the position inside any lit volume of the cache?
function Zones.isLit(cache: Cache, position: Vector3): boolean
	if cache.All then
		return true
	end
	for _, ball in cache.Balls do
		const d = position - ball.Center
		if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= ball.Radius2 then
			return true
		end
	end
	for _, box in cache.Boxes do
		const p = box.Inverse * position
		const half = box.Half
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

-- One zone, no override (tests, dev command).
function Zones.contains(zone: Zone, position: Vector3): boolean
	if zone.Kind == "Ball" then
		return (position - zone.CFrame.Position).Magnitude <= zone.Radius
	end
	const p = zone.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= zone.Half.X and math.abs(p.Y) <= zone.Half.Y and math.abs(p.Z) <= zone.Half.Z
end

return Zones
