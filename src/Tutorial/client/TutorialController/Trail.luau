--!strict
--[[
	Trail: dashed 3D path on the ground between the trailer door and the Mart door (TASK-322, owner request 2026-10-15,
	Provisional). Shown on the shopping steps mart_go (trailer -> Mart) and mart_back (Mart -> trailer).

	  - Route: MapPoint TRL-OUT (where Exit Trailer drops the player) -> NpcNode graph (MapIndex.Path, queue slots never
	    in the middle, crosswalk edges kept, so it follows the sidewalk and the zebra) -> MapPoint MKT-DOOR. The owner
	    builds the point list (Route) and hands it to Show; mart_back passes it reversed.
	  - Look: short flat Mustard dashes with one Ink-outlined Highlight on the whole trail (same colours as Arrow3D),
	    occluded by buildings so it reads as paint on the floor.
	  - Motion: the dashes slide toward the destination; the ones the player already walked past are hidden. Reduced
	    motion (Motion.Reduced): still dashes.
	  - Under a cinematic (Cinematic.Active) it is taken out of the world and comes back when it ends.
	Local only (client parts in a Workspace folder, no collision, no query, no touch, no shadow).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)

export type Trail = {
	-- Draws the trail along `points` (walking order, first = start). Same list again = no rebuild.
	Show: (points: { Vector3 }) -> (),
	Hide: () -> (),
	-- every frame: slides the dashes and hides the walked part
	Step: () -> (),
	Shown: () -> boolean,
	Destroy: () -> (),
}

-- PROVISIONAL sizes and timings (tune in play)
const DASH_LENGTH = 1.4
const DASH_WIDTH = 0.55
const DASH_THICKNESS = 0.12
const GAP = 2.6 -- studs between two dash starts
const SPEED = 2.5 -- studs/s toward the destination
const LIFT = 0.06 -- studs over the floor
const FILL = 0.35 -- Highlight fill (Arrow3D ARROW_FILL)
const BEHIND = 2 -- studs: dashes this far behind the player's spot on the trail are hidden
const NEAR_PATH = 14 -- studs: farther from the trail than this, nothing counts as walked
const GROUND_STEP = 1 -- studs between two floor height samples
const GROUND_PROBE = 4 -- studs above / below the route height the floor ray looks
const GROUND_TOLERANCE = 1.5 -- a hit farther than this from the route height is a car or a prop, not the floor
const MARGIN = 0.5 -- studs kept free at both ends
const PARK = CFrame.new(0, -1e4, 0)

const TRAILER_DOOR = "TRL-OUT"
const MART_DOOR = "MKT-DOOR"

const Trail = {}

local function isQueue(id: string): boolean
	return string.match(id, "^Q%d+$") ~= nil
end

-- Trailer door -> Mart door through the graph; nil while the binding / the nodes are not streamed in.
function Trail.Route(): { Vector3 }?
	const ok, points = pcall(function(): { Vector3 }?
		const from = MapIndex.FindPoint(TRAILER_DOOR)
		const to = MapIndex.FindPoint(MART_DOOR)
		if from == nil or to == nil then
			return nil
		end
		const first = MapIndex.NearestNode(from.Position, isQueue)
		const last = MapIndex.NearestNode(to.Position, isQueue)
		if first == nil or last == nil then
			return nil
		end
		const ids = MapIndex.Path(first, last, { AvoidQueue = true })
		if ids == nil then
			return nil
		end
		const out = { from.Position }
		for _, id in ids do
			table.insert(out, MapIndex.Node(id).Position)
		end
		table.insert(out, to.Position)
		return out
	end)
	return if ok then points else nil
end

function Trail.Reversed(points: { Vector3 }): { Vector3 }
	const out: { Vector3 } = {}
	for i = #points, 1, -1 do
		table.insert(out, points[i])
	end
	return out
end

local function samePoints(a: { Vector3 }, b: { Vector3 }): boolean
	if #a ~= #b then
		return false
	end
	for i, point in a do
		if (point - b[i]).Magnitude > 0.05 then
			return false
		end
	end
	return true
end

function Trail.new(folder: () -> Instance): Trail
	local points: { Vector3 } = {}
	local starts: { number } = {} -- distance along the trail at each point
	local length = 0
	local ground: { number } = {} -- floor height every GROUND_STEP studs
	local dashes: { BasePart } = {}
	local on = false
	local startClock = os.clock()

	const model = Instance.new("Model")
	model.Name = "TutorialTrail"
	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillColor = Theme.Color.Mustard
	outline.FillTransparency = FILL
	outline.OutlineColor = Theme.Color.Ink
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = model
	outline.Parent = model

	-- position and heading at distance s (clamped)
	local function at(s: number): (Vector3, Vector3)
		const count = #points
		for i = 1, count - 1 do
			if s <= starts[i + 1] or i == count - 1 then
				const a, b = points[i], points[i + 1]
				const span = starts[i + 1] - starts[i]
				const t = if span > 0 then math.clamp((s - starts[i]) / span, 0, 1) else 0
				const flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				return a:Lerp(b, t), if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
			end
		end
		return points[1] or Vector3.zero, Vector3.zAxis
	end

	local function floorAt(s: number): number
		const index = math.clamp(s / GROUND_STEP, 0, #ground - 1)
		const low = math.floor(index)
		const high = math.min(low + 1, #ground - 1)
		const a, b = ground[low + 1], ground[high + 1]
		return a + (b - a) * (index - low)
	end

	-- closest distance along the trail to `position` (XZ), nil when the player is far from it
	local function progressOf(position: Vector3): number?
		local best: number? = nil
		local bestDistance = NEAR_PATH * NEAR_PATH
		for i = 1, #points - 1 do
			const a, b = points[i], points[i + 1]
			const ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			const ap = Vector3.new(position.X - a.X, 0, position.Z - a.Z)
			const span = ab:Dot(ab)
			const t = if span > 0 then math.clamp(ap:Dot(ab) / span, 0, 1) else 0
			const offset = ap - ab * t
			const distance = offset:Dot(offset)
			if distance < bestDistance then
				bestDistance = distance
				best = starts[i] + (starts[i + 1] - starts[i]) * t
			end
		end
		return best
	end

	local function sampleGround()
		const params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		const skip: { Instance } = { model }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(skip, player.Character)
			end
		end
		params.FilterDescendantsInstances = skip
		table.clear(ground)
		const samples = math.max(math.ceil(length / GROUND_STEP), 1)
		for i = 0, samples do
			const route = at(i * GROUND_STEP)
			const hit = workspace:Raycast(route + Vector3.yAxis * GROUND_PROBE, -Vector3.yAxis * GROUND_PROBE * 2, params)
			const y = if hit and math.abs(hit.Position.Y - route.Y) <= GROUND_TOLERANCE then hit.Position.Y else route.Y
			table.insert(ground, y)
		end
	end

	local function makeDash(index: number): BasePart
		const dash = Instance.new("Part")
		dash.Name = "Dash" .. index
		dash.Size = Vector3.new(DASH_WIDTH, DASH_THICKNESS, DASH_LENGTH)
		dash.Anchored = true
		dash.CanCollide = false
		dash.CanQuery = false
		dash.CanTouch = false
		dash.CastShadow = false
		dash.Massless = true
		dash.Material = Enum.Material.SmoothPlastic
		dash.Color = Theme.Color.Mustard
		dash.CFrame = PARK
		dash.Parent = model
		return dash
	end

	local function build(list: { Vector3 })
		points = table.clone(list)
		table.clear(starts)
		length = 0
		for i, point in points do
			if i > 1 then
				const previous = points[i - 1]
				length += Vector3.new(point.X - previous.X, 0, point.Z - previous.Z).Magnitude
			end
			starts[i] = length
		end
		sampleGround()
		const count = math.max(math.floor((length - 2 * MARGIN) / GAP) + 1, 0)
		for i = #dashes + 1, count do
			dashes[i] = makeDash(i)
		end
		for i = #dashes, count + 1, -1 do
			dashes[i]:Destroy()
			dashes[i] = nil
		end
		startClock = os.clock()
	end

	return {
		Show = function(list: { Vector3 })
			if #list < 2 then
				return
			end
			if not on or not samePoints(points, list) then
				build(list)
			end
			on = true
		end,
		Hide = function()
			on = false
			model.Parent = nil
		end,
		Step = function()
			if not on or #points < 2 then
				return
			end
			if Cinematic.Active() then
				model.Parent = nil
				return
			end
			if model.Parent == nil then
				model.Parent = folder()
			end
			const phase = if Motion.Reduced() then 0 else ((os.clock() - startClock) * SPEED) % GAP
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			const walked = if root and root:IsA("BasePart") then progressOf(root.Position) else nil
			const first = MARGIN + DASH_LENGTH / 2
			const last = length - MARGIN - DASH_LENGTH / 2
			const parts: { BasePart } = {}
			const frames: { CFrame } = {}
			for i, dash in dashes do
				const s = first + (i - 1) * GAP + phase
				local frame = PARK
				if s <= last and (walked == nil or s >= walked - BEHIND) then
					const position, heading = at(s)
					const floor = Vector3.new(position.X, floorAt(s) + LIFT + DASH_THICKNESS / 2, position.Z)
					frame = CFrame.lookAt(floor, floor + heading)
				end
				table.insert(parts, dash)
				table.insert(frames, frame)
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end,
		Shown = function(): boolean
			return on
		end,
		Destroy = function()
			on = false
			model:Destroy()
		end,
	}
end

return table.freeze(Trail)
