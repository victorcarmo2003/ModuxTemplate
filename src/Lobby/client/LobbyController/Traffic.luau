--!strict
-- Lobby street traffic (owner request 2026-10-16, Provisional): cars drive between the two lobby car tunnels, one lane
-- each way, appearing deep inside one tunnel's dark and vanishing deep inside the other. Local only (this client
-- clones and moves them, nothing replicates), presentation only.
--   Templates  the parked cars of LobbyStart (LB-CAR-1, LB-CAR-2, LB-VAN): they are hidden locally and cloned; a car
--              faces its pivot LookVector (the Headlights sit on local -Z).
--   Lanes      read from the map: the parked cars give each lane's X (heading by their LookVector), the two
--              CarTunnel models under LOBBY_Assets give the ends; each lane runs from TUNNEL_DEPTH studs inside the
--              tunnel behind it to TUNNEL_DEPTH inside the tunnel ahead (the dark interior hides the spawn and the
--              despawn).
--   Pace       SPEED studs/s, a new car every SPAWN_EVERY s per lane (random within the range), never closer than GAP.
-- Nothing in the map (no templates or no tunnels) = no traffic, silently.
local Workspace = game:GetService("Workspace")

const TEMPLATES = { "LB-CAR-1_AST-035_CarSedan", "LB-CAR-2_AST-035_CarPickup", "LB-VAN_AST-035_CarVan" }
const TEMPLATE_FOLDER = "LobbyStart"
const TUNNEL = "CarTunnel"
const TUNNEL_DEPTH = 22 -- studs inside the tunnel mouth where a car appears / disappears (dark)
const SPEED = 26 -- studs/s
const SPAWN_EVERY = { 3.5, 8 } -- s between two cars of one lane
const GAP = 24 -- studs: no spawn while the last car of the lane is closer than this to the start
const LANE_MERGE = 4 -- studs: parked cars whose X differ less than this share a lane
const FOLDER = "LobbyTraffic"

type Lane = {
	From: Vector3, -- start (inside a tunnel), at the road height of the templates
	To: Vector3,
	Heading: Vector3, -- unit, From -> To
	Length: number,
	Cars: { { Model: Model, S: number } },
	NextAt: number,
}

export type Traffic = {
	Step: (dt: number) -> (),
	Destroy: () -> (),
}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Inner ends of the two tunnels along the road (Z), deepest point first per side
local function tunnels(root: Instance): { Model }
	const found: { Model } = {}
	for _, child in root:GetChildren() do
		if child.Name == TUNNEL and child:IsA("Model") then
			table.insert(found, child)
		end
	end
	return found
end

return function(): Traffic?
	const root = Workspace:FindFirstChild("LOBBY_Assets")
	const holder = if root ~= nil then root:FindFirstChild(TEMPLATE_FOLDER) else nil
	if root == nil or holder == nil then
		return nil
	end
	const templates: { Model } = {}
	for _, name in TEMPLATES do
		const model = holder:FindFirstChild(name)
		if model ~= nil and model:IsA("Model") then
			table.insert(templates, model)
		end
	end
	const ends = tunnels(root)
	if #templates == 0 or #ends < 2 then
		return nil
	end
	-- the two tunnels ordered along the road direction (by Z)
	table.sort(ends, function(a: Model, b: Model): boolean
		return a:GetPivot().Position.Z < b:GetPivot().Position.Z
	end)
	const southCf, southSize = ends[1]:GetBoundingBox()
	const northCf, northSize = ends[#ends]:GetBoundingBox()
	-- mouth = the tunnel box face that looks at the road; "inside" = TUNNEL_DEPTH past it
	const southMouth = southCf.Position.Z + southSize.Z / 2
	const northMouth = northCf.Position.Z - northSize.Z / 2

	-- lanes from the parked cars (X and heading), then the parked cars leave the world locally
	const lanes: { Lane } = {}
	const rng = Random.new()
	for _, template in templates do
		const pivot = template:GetPivot()
		const goingNorth = pivot.LookVector.Z > 0
		local lane: Lane? = nil
		for _, other in lanes do
			if math.abs(other.From.X - pivot.X) < LANE_MERGE and (other.Heading.Z > 0) == goingNorth then
				lane = other
			end
		end
		if lane == nil then
			const y = pivot.Y
			const southPoint = Vector3.new(pivot.X, y, southMouth - TUNNEL_DEPTH)
			const northPoint = Vector3.new(pivot.X, y, northMouth + TUNNEL_DEPTH)
			const from = if goingNorth then southPoint else northPoint
			const to = if goingNorth then northPoint else southPoint
			const created: Lane = {
				From = from,
				To = to,
				Heading = flat(to - from).Unit,
				Length = flat(to - from).Magnitude,
				Cars = {},
				NextAt = os.clock() + rng:NextNumber() * SPAWN_EVERY[2],
			}
			table.insert(lanes, created)
		end
		template.Parent = nil -- local only: the server copy stays; the clones below are the moving ones
	end

	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = Workspace
	const pool: { Model } = {}
	for _, template in templates do
		for _, piece in template:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = true
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
			end
		end
		table.insert(pool, template)
	end

	local function poseOf(lane: Lane, s: number): CFrame
		const at = lane.From + lane.Heading * s
		return CFrame.lookAt(at, at + lane.Heading)
	end

	local function spawn(lane: Lane)
		const model = pool[rng:NextInteger(1, #pool)]:Clone()
		model:PivotTo(poseOf(lane, 0))
		model.Parent = folder
		table.insert(lane.Cars, { Model = model, S = 0 })
	end

	return {
		Step = function(dt: number)
			const now = os.clock()
			for _, lane in lanes do
				for index = #lane.Cars, 1, -1 do
					const car = lane.Cars[index]
					car.S += SPEED * dt
					if car.S >= lane.Length then
						car.Model:Destroy()
						table.remove(lane.Cars, index)
					else
						car.Model:PivotTo(poseOf(lane, car.S))
					end
				end
				const last = lane.Cars[#lane.Cars]
				if now >= lane.NextAt and (last == nil or last.S > GAP) then
					spawn(lane)
					lane.NextAt = now + SPAWN_EVERY[1] + rng:NextNumber() * (SPAWN_EVERY[2] - SPAWN_EVERY[1])
				end
			end
		end,
		Destroy = function()
			folder:Destroy()
		end,
	}
end
