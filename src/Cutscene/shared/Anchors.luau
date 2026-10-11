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
	  Spot(target, slot, count)
	            where a body of `slot` stands for a MoveTo target: Rules.Stand.Target ("CS-P{slot}") = in front of the
	            phone (Rules.Stand.Slots: slot 1 ~3 studs, mates in a half moon), facing it; any other target = its
	            MapPoint ("{slot}" = slot), side by side (Rules.LineSpacing) on a shared one. nil = not in the map
	            (or not streamed in yet on a client).
	  Point(id)  MapPoint by id; "a|b" = the middle of two MapPoints; "Poster" / "Phone" = those anchors.
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

-- "Poster" / "Phone" / "a|b" (middle of two MapPoints) / MapPoint id
function Anchors.Point(id: string): CFrame?
	if id == "Poster" then
		return Anchors.Poster()
	elseif id == "Phone" then
		return Anchors.Phone()
	end
	const a, b = string.match(id, "^([^|]+)|([^|]+)$")
	if a ~= nil and b ~= nil then
		const pa = mapPoint(a)
		const pb = mapPoint(b)
		if pa == nil or pb == nil then
			return nil
		end
		return pa:Lerp(pb, 0.5)
	end
	return mapPoint(id)
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
	const point = mapPoint(id)
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
