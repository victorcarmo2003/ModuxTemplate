--!strict
--[[
	Anchors: where the cutscene things are in the real map, read at runtime (never fixed coordinates). Shared by
	CutsceneService (where bodies stand) and CutsceneController (walk, camera focus, prompt, cars), so both sides
	compute the same spots from the same map. Pure reads of the Workspace + MapIndex; only a small instance cache.

	  Poster()  the Help Wanted flyer: tag `HelpWantedPoster`, else the first instance named in
	            Content.Cutscenes.Rules.Poster.Names (blockout: Signs/P-01_Flyer). CFrame at the centre of the printed
	            face, LookVector = out of that face (horizontal). Fallback: the P-01 StreetLight at flyer height,
	            facing CS-P1. The user moves it in Studio: everything follows.
	  Phone()   a phone the party calls from: tag `CutscenePhone` or an instance named CutscenePhone / Payphone.
	            None in the map today -> the poster (the number is on it).
	  Sign()    the NO HELP WANTED sign of the first stop (Rules.Sign): instances tagged `NoHelpWantedSign`; a card
	            wider than Rules.Sign.MinWidth wins, then the first along the sidewalk line (Rules.Sign.Line) within
	            Range. CFrame at its centre. nil = no tagged sign (callers fall back).
	  SignStand()
	            where the body stops for the sign: Rules.Sign.Distance studs straight out of its printed face (the
	            face turned towards the sidewalk line), on the ground, facing the sign. No sign: the
	            Rules.Sign.Fallback MapPoint.
	  Spot(target, slot, count)
	            where a body of `slot` stands for a MoveTo target: Rules.Stand.Target ("CS-P{slot}") = in front of the
	            phone (Rules.Stand.Slots: slot 1 ~3 studs, mates in a half moon), facing it; any other target = its
	            Point ("{slot}" = slot), side by side (Rules.LineSpacing) on a shared one. nil = not in the map
	            (or not streamed in yet on a client).
	  Point(id)  MapPoint by id; "a|b" / "a|b@f" = the point at fraction f (default 0.5) from MapPoint a to b, facing
	            a -> b; "Poster" / "Phone" = those anchors; "Sign" = SignStand(); "Poster>o,s" = a ground spot o studs
	            out of the flyer's printed face and s studs to its right (seen from the flyer), facing along that side
	            line towards the flyer's normal line -- a walk that follows the flyer when the user moves it,
	            with no MapPoint in the place (TASK-493).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

const RULES = Content.Cutscenes.Rules
const SLOT_TOKEN = "{slot}"
const POSTER_TAG = "HelpWantedPoster"
const PHONE_TAG = "CutscenePhone"
const PHONE_NAMES = { "CutscenePhone", "Payphone", "PayPhone", "Pay_Phone" }
const POST_ID = "P-01"
const FLYER_HEIGHT = 4.5 -- studs above the post base (blockout flyer, MAP-01 P-01)
const RETRY = 1 -- s between two Workspace searches of something that is not there
const GROUND_DROP = 14 -- studs searched under a stand spot
const GROUND_ABOVE = 1.5 -- a hit this far above the fallback ground is a prop, not the sidewalk
const STREETLIGHT_TAG = "StreetLight"
const SIGN_TARGET = "Sign" -- MoveTo / Focus target of the NO HELP WANTED stop
const GROUND_LIFT = 4 -- studs above a sidewalk point where the ground ray starts

const Anchors = {}

type Found = { Instance: Instance?, MissAt: number }

const found: { [string]: Found } = {}

local function alive(instance: Instance?): boolean
	return instance ~= nil and instance:IsDescendantOf(Workspace)
end

-- First instance with `tag`, else named one of `names` (BasePart or Model) in the Workspace; cached, searched again
-- at most every RETRY s while missing
local function search(key: string, tag: string, names: { string }): Instance?
	const entry = found[key]
	if entry ~= nil and alive(entry.Instance) then
		return entry.Instance
	end
	const now = os.clock()
	if entry ~= nil and entry.Instance == nil and now - entry.MissAt < RETRY then
		return nil
	end
	local hit: Instance? = nil
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(Workspace) and (instance:IsA("BasePart") or instance:IsA("Model")) then
			hit = instance
			break
		end
	end
	if hit == nil then
		for _, name in names do
			const candidate = Workspace:FindFirstChild(name, true)
			if candidate ~= nil and (candidate:IsA("BasePart") or candidate:IsA("Model")) then
				hit = candidate
				break
			end
		end
	end
	found[key] = { Instance = hit, MissAt = now }
	return hit
end

local function flat(v: Vector3): Vector3?
	const f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else nil
end

-- Printed face of a BasePart: the face of its SurfaceGui, else Front
local function printedFace(part: BasePart): Vector3
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			return (part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(child.Face)))
		end
	end
	return part.CFrame.LookVector
end

-- Centre + outward horizontal normal of a flat sign (BasePart, or a Model with a printed part)
local function signFrame(instance: Instance): CFrame?
	local part: BasePart? = nil
	if instance:IsA("BasePart") then
		part = instance
	elseif instance:IsA("Model") then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("SurfaceGui") and descendant.Parent ~= nil and descendant.Parent:IsA("BasePart") then
				part = descendant.Parent :: BasePart
				break
			end
		end
	end
	local centre: Vector3
	local normal: Vector3?
	if part ~= nil then
		centre = part.Position
		normal = flat(printedFace(part))
	elseif instance:IsA("Model") then
		const pivot = instance:GetPivot()
		centre = pivot.Position
		normal = flat(pivot.LookVector)
	else
		return nil
	end
	if normal == nil then
		return nil
	end
	return CFrame.lookAt(centre, centre + normal)
end

local function postGround(id: string): Vector3?
	for _, instance in CollectionService:GetTagged(STREETLIGHT_TAG) do
		if instance:GetAttribute("PostId") ~= id then
			continue
		end
		if instance:IsA("Model") then
			const box, size = instance:GetBoundingBox()
			return box.Position - Vector3.new(0, size.Y / 2, 0)
		elseif instance:IsA("BasePart") then
			return instance.Position - Vector3.new(0, instance.Size.Y / 2, 0)
		end
	end
	return nil
end

local function mapPoint(id: string): CFrame?
	return if MapIndex.HasBinding() then MapIndex.FindPoint(id) else nil
end

-- The poster instance itself (the client dresses its text; the server too)
function Anchors.PosterInstance(): Instance?
	return search("poster", POSTER_TAG, RULES.Poster.Names)
end

function Anchors.Poster(): CFrame?
	const instance = Anchors.PosterInstance()
	const frame = if instance ~= nil then signFrame(instance) else nil
	if frame ~= nil then
		return frame
	end
	-- fallback: the P-01 post at flyer height, facing where the party stands
	const ground = postGround(POST_ID)
	if ground == nil then
		return nil
	end
	const centre = ground + Vector3.new(0, FLYER_HEIGHT, 0)
	const stand = mapPoint("CS-P1")
	const normal = if stand ~= nil then flat(stand.Position - centre) else nil
	return CFrame.lookAt(centre, centre + (normal or Vector3.new(0, 0, -1)))
end

function Anchors.Phone(): CFrame?
	const instance = search("phone", PHONE_TAG, PHONE_NAMES)
	const frame = if instance ~= nil then signFrame(instance) else nil
	return frame or Anchors.Poster()
end

-- Ground under `position`: raycast down (bodies, actors and cars ignored), else `fallback`
local function groundAt(position: Vector3, fallback: number?): number?
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { "CutsceneActors", "TrafficCars" } do
		const folder = Workspace:FindFirstChild(name)
		if folder ~= nil then
			table.insert(ignore, folder)
		end
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const result = Workspace:Raycast(position, Vector3.new(0, -GROUND_DROP, 0), params)
	if result ~= nil and (fallback == nil or result.Position.Y <= fallback + GROUND_ABOVE) then
		return result.Position.Y
	end
	return fallback
end

-- Centre and horizontal width of a sign instance
local function signBox(instance: Instance): (Vector3?, number)
	if instance:IsA("BasePart") then
		return instance.Position, math.max(instance.Size.X, instance.Size.Z)
	elseif instance:IsA("Model") then
		const box, size = instance:GetBoundingBox()
		return box.Position, math.max(size.X, size.Z)
	end
	return nil, 0
end

-- Fraction along a -> b of `position` (XZ) and its horizontal distance off that segment
local function along(a: Vector3, b: Vector3, position: Vector3): (number, number)
	const ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	const ap = Vector3.new(position.X - a.X, 0, position.Z - a.Z)
	const length2 = ab:Dot(ab)
	const t = if length2 > 1e-6 then ap:Dot(ab) / length2 else 0
	return t, (ap - ab * math.clamp(t, 0, 1)).Magnitude
end

-- The sidewalk line of the sign stop (Rules.Sign.Line)
local function signLine(): (Vector3?, Vector3?)
	const line = RULES.Sign.Line
	const a = mapPoint(line[1])
	const b = mapPoint(line[2])
	return if a ~= nil then a.Position else nil, if b ~= nil then b.Position else nil
end

-- The tagged NO HELP WANTED sign of the stop (Rules.Sign) and its centre
local function signInstance(): (Instance?, Vector3?)
	const rules = RULES.Sign
	const a, b = signLine()
	local best: Instance? = nil
	local bestCentre: Vector3? = nil
	local bestScore = math.huge
	for _, instance in CollectionService:GetTagged(rules.Tag) do
		if not instance:IsDescendantOf(Workspace) then
			continue
		end
		const centre, width = signBox(instance)
		if centre == nil then
			continue
		end
		-- the big card first (+0, small +100), then within Range of the line (+10, farther +20); the first along
		-- the line wins inside a group
		local score = if width > rules.MinWidth then 0 else 100
		if a ~= nil and b ~= nil then
			const t, off = along(a, b, centre)
			score += (if off <= rules.Range then 10 else 20) + math.clamp(t, -1, 2)
		end
		if score < bestScore then
			bestScore = score
			best = instance
			bestCentre = centre
		end
	end
	return best, bestCentre
end

-- Horizontal axis of a box that is its thinnest (the normal of a flat card), among the mostly horizontal ones
local function thinAxis(frame: CFrame, size: Vector3): Vector3?
	local best: Vector3? = nil
	local thinnest = math.huge
	for _, pair in { { frame.RightVector, size.X }, { frame.UpVector, size.Y }, { frame.LookVector, size.Z } } do
		const axis = pair[1] :: Vector3
		const extent = pair[2] :: number
		if math.abs(axis.Y) < 0.7 and extent < thinnest then
			thinnest = extent
			best = axis
		end
	end
	return if best ~= nil then flat(best) else nil
end

-- Outward normal of a sign (either side): the face of its SurfaceGui, else the thinnest horizontal axis of the card
local function signNormal(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		for _, child in instance:GetChildren() do
			if child:IsA("SurfaceGui") then
				return flat(printedFace(instance))
			end
		end
		return thinAxis(instance.CFrame, instance.Size)
	elseif instance:IsA("Model") then
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("SurfaceGui") and descendant.Parent ~= nil and descendant.Parent:IsA("BasePart") then
				return flat(printedFace(descendant.Parent :: BasePart))
			end
		end
		const box, size = instance:GetBoundingBox()
		return thinAxis(box, size)
	end
	return nil
end

function Anchors.Sign(): CFrame?
	const _, centre = signInstance()
	return if centre ~= nil then CFrame.new(centre) else nil
end

-- Stop right in front of the NO HELP WANTED sign (Rules.Sign.Distance out of its face, on the side of the sidewalk
-- line), facing it; the Fallback MapPoint without a sign
function Anchors.SignStand(): CFrame?
	const rules = RULES.Sign
	const instance, centre = signInstance()
	const a, b = signLine()
	if instance == nil or centre == nil then
		return mapPoint(rules.Fallback)
	end
	-- towards the sidewalk: the foot of the sign on the line (or, on the line itself, back towards where the walk
	-- comes from)
	local toward: Vector3? = nil
	local groundY = centre.Y
	if a ~= nil and b ~= nil then
		const t = math.clamp((along(a, b, centre)), 0, 1)
		const foot = a:Lerp(b, t)
		groundY = foot.Y
		toward = flat(foot - centre) or flat(a - b)
	end
	local normal = signNormal(instance) or toward
	if normal == nil then
		return mapPoint(rules.Fallback)
	end
	if toward ~= nil and normal:Dot(toward) < 0 then
		normal = -normal
	end
	const at = Vector3.new(centre.X, groundY, centre.Z) + normal * rules.Distance
	const y = groundAt(at + Vector3.new(0, GROUND_LIFT, 0), groundY) or groundY
	const stand = Vector3.new(at.X, y, at.Z)
	const face = flat(centre - stand) or -normal
	return CFrame.lookAt(stand, stand + face)
end

-- true when `target` stands on a fallback that the real instance may replace once it streams in (plans built on it
-- are built again later, Route Missing)
function Anchors.OnFallback(target: string): boolean
	return target == SIGN_TARGET and Anchors.Sign() == nil
end

-- Ground spot `out` studs out of the flyer's face and `side` studs to its right, facing along the side line towards the
-- flyer's normal line (side 0: facing the flyer)
local function posterOffset(out: number, side: number): CFrame?
	const poster = Anchors.Poster()
	if poster == nil then
		return nil
	end
	const look = flat(poster.LookVector)
	if look == nil then
		return nil
	end
	const right = look:Cross(Vector3.yAxis)
	const at = poster.Position + look * out + right * side
	const fallback = poster.Position.Y - FLYER_HEIGHT
	const y = groundAt(at + Vector3.new(0, GROUND_LIFT, 0), fallback) or fallback
	const position = Vector3.new(at.X, y, at.Z)
	const facing = if side < 0 then right elseif side > 0 then -right else -look
	return CFrame.lookAt(position, position + facing)
end

-- "Poster" / "Phone" / "Sign" / "Poster>o,s" (posterOffset) / "a|b@f" (fraction f of MapPoint a -> b, default the
-- middle, facing a -> b) / MapPoint id
function Anchors.Point(id: string): CFrame?
	if id == "Poster" then
		return Anchors.Poster()
	elseif id == "Phone" then
		return Anchors.Phone()
	elseif id == SIGN_TARGET then
		return Anchors.SignStand()
	end
	const out, side = string.match(id, "^Poster>([%d%.%-]+),([%d%.%-]+)$")
	if out ~= nil and side ~= nil then
		const o, s = tonumber(out), tonumber(side)
		return if o ~= nil and s ~= nil then posterOffset(o, s) else nil
	end
	const a, rest = string.match(id, "^([^|]+)|(.+)$")
	if a ~= nil and rest ~= nil then
		local b = rest
		local fraction = 0.5
		const name, f = string.match(rest, "^([^@]+)@([%d%.%-]+)$")
		if name ~= nil and f ~= nil then
			b = name
			fraction = tonumber(f) or 0.5
		end
		const pa = mapPoint(a)
		const pb = mapPoint(b)
		if pa == nil or pb == nil then
			return nil
		end
		const position = pa.Position:Lerp(pb.Position, fraction)
		const direction = flat(pb.Position - pa.Position)
		return if direction ~= nil then CFrame.lookAt(position, position + direction) else pa:Lerp(pb, fraction)
	end
	return mapPoint(id)
end

function Anchors.Spot(target: string, slot: number, count: number): CFrame?
	const id = (string.gsub(target, SLOT_TOKEN, tostring(slot)))
	if target == RULES.Stand.Target then
		const phone = Anchors.Phone()
		if phone ~= nil then
			const slots = RULES.Stand.Slots
			const row = slots[math.clamp(slot, 1, #slots)]
			const direction = CFrame.Angles(0, math.rad(row.Angle), 0):VectorToWorldSpace(phone.LookVector)
			const at = phone.Position + direction * row.Distance
			const point = mapPoint(id)
			const fallback = if point ~= nil then point.Position.Y else phone.Position.Y - FLYER_HEIGHT
			const y = groundAt(at, fallback) or fallback
			const stand = Vector3.new(at.X, y, at.Z)
			return CFrame.lookAt(stand, Vector3.new(phone.Position.X, y, phone.Position.Z))
		end
	end
	const point = Anchors.Point(id)
	if point == nil then
		return nil
	end
	if string.find(target, SLOT_TOKEN, 1, true) then
		return point
	end
	const offset = (slot - (count + 1) / 2) * RULES.LineSpacing
	return point * CFrame.new(offset, 0, 0)
end

return table.freeze(Anchors)
