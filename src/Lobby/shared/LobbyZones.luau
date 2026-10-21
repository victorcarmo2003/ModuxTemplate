--!strict
-- Lobby zones geometry (Content.Lobby; user request 2026-10-11, Provisional). ReplicatedStorage.shared.Lobby.LobbyZones,
-- read by PartyService (server: who stands on which squad platform) and LobbyController (client: panel triggers and
-- the zone VFX). Same source on both sides. Pure: no Modux, Lync, Vide nor self.Libs.
--
-- The map places the zones: a BasePart under Workspace tagged "LobbyZone" with the attribute Zone = a Key of
-- Content.Lobby.Zones is that zone's floor (else, for squad rows, a Part tagged "PartyPlatform" with Party = n).
--  * Shape: a Cylinder Part whose axis is (near) vertical, or attribute Shape = "Circle" -> circle, radius = half the
--    smaller horizontal size; otherwise (or Shape = "Rect") -> rectangle oriented with the Part, half sizes = half its
--    two horizontal sizes. The local axis closest to world Y is "up", so a Part turned on its side still works.
--  * The zone sits on the floor top (Center.Y = top of the Part's world bounding box).
-- Tag added / removed and CFrame / Size / Shape / attribute changes mark the zones dirty; they are resolved again on
-- the next read and Version() moves when a geometry really changed. A Part that leaves (streamed out on the client)
-- keeps its last geometry. A row without any Part falls back to a circle at its MapPoint (PointId; looked up again
-- every REFRESH s while missing; MapIndex's cache is never dropped here) or Content Center, radius Content Radius.
-- Inside(): plane XZ only, any height (owner request 2026-10-21: a jump no longer takes the player out of a zone):
-- circle = planar distance <= Radius, rectangle = the point in the zone frame with |x| <= HalfX and |z| <= HalfZ;
-- + Trigger.Hysteresis on every edge when it was already inside, so the edge does not flicker.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

export type Shape = "Circle" | "Rect"

export type Zone = {
	Key: string,
	Panel: Content.LobbyPanel,
	Platform: number,
	Color: Color3,
	Shape: Shape,
	CFrame: CFrame, -- flat (Y = world up) at the floor top centre; rectangle sides along its X / Z
	Center: Vector3, -- = CFrame.Position
	Radius: number, -- circle: radius; rectangle: half diagonal (bounds, distance culling)
	HalfX: number, -- rectangle half size along CFrame X (circle: Radius)
	HalfZ: number, -- rectangle half size along CFrame Z (circle: Radius)
	FromMap: boolean, -- true = placed by a tagged Part; false = Content fallback
}

type Geometry = {
	Shape: Shape,
	CFrame: CFrame,
	HalfX: number,
	HalfZ: number,
}

const LOBBY = Content.Lobby
const TAG = "LobbyZone"
const KEY_ATTRIBUTE = "Zone"
const SHAPE_ATTRIBUTE = "Shape"
const PLATFORM_TAG = "PartyPlatform"
const PLATFORM_ATTRIBUTE = "Party"
const REFRESH = 5 -- s between two point lookups while one is missing
const VERTICAL = 0.7 -- |axis.Y| over this = the cylinder stands on its axis (a disc)
const EPSILON = 1e-3

local zones: { Zone } = {}
local byPlatform: { [number]: Zone } = {}
local version = 0
local dirty = true
local complete = false
local nextLookup = 0
local started = false
const lastKnown: { [string]: Geometry } = {}
const watched: { [BasePart]: { RBXScriptConnection } } = {}

local function markDirty()
	dirty = true
end

local function findPoint(id: string): CFrame?
	if not MapIndex.HasBinding() then
		return nil
	end
	const ok, point = pcall(MapIndex.FindPoint, id)
	return if ok then point else nil
end

local function geometryOf(part: BasePart): Geometry
	const cf = part.CFrame
	const size = part.Size
	const axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	const sizes = { size.X, size.Y, size.Z }
	local up = 1
	for i = 2, 3 do
		if math.abs(axes[i].Y) > math.abs(axes[up].Y) then
			up = i
		end
	end
	const a = if up == 1 then 2 else 1
	const b = if up == 3 then 2 else 3
	const halfY = 0.5
		* (math.abs(axes[1].Y) * sizes[1] + math.abs(axes[2].Y) * sizes[2] + math.abs(axes[3].Y) * sizes[3])
	const position = part.Position
	const center = Vector3.new(position.X, position.Y + halfY, position.Z)
	local flat = Vector3.new(axes[a].X, 0, axes[a].Z)
	if flat.Magnitude < EPSILON then
		flat = Vector3.xAxis
	end
	const frame = CFrame.fromMatrix(center, flat.Unit, Vector3.yAxis)
	const forced = part:GetAttribute(SHAPE_ATTRIBUTE)
	local circle = forced == "Circle"
	if forced ~= "Circle" and forced ~= "Rect" and part:IsA("Part") then
		circle = part.Shape == Enum.PartType.Cylinder and up == 1 and math.abs(axes[1].Y) >= VERTICAL
	end
	if circle then
		const radius = math.min(sizes[a], sizes[b]) / 2
		return { Shape = "Circle", CFrame = frame, HalfX = radius, HalfZ = radius }
	end
	return { Shape = "Rect", CFrame = frame, HalfX = sizes[a] / 2, HalfZ = sizes[b] / 2 }
end

local function inWorld(instance: Instance): boolean
	return instance:IsA("BasePart") and instance:IsDescendantOf(workspace)
end

-- Tagged floors by zone key: LobbyZone (attribute Zone) first, then PartyPlatform (attribute Party = n -> Squad row).
local function taggedParts(): ({ [string]: BasePart }, { [number]: BasePart })
	const byKey: { [string]: BasePart } = {}
	for _, instance in CollectionService:GetTagged(TAG) do
		const key = instance:GetAttribute(KEY_ATTRIBUTE)
		if inWorld(instance) and typeof(key) == "string" and byKey[key] == nil then
			byKey[key] = instance :: BasePart
		end
	end
	const byParty: { [number]: BasePart } = {}
	for _, instance in CollectionService:GetTagged(PLATFORM_TAG) do
		const n = instance:GetAttribute(PLATFORM_ATTRIBUTE)
		if inWorld(instance) and typeof(n) == "number" and byParty[n] == nil then
			byParty[n] = instance :: BasePart
		end
	end
	return byKey, byParty
end

local function same(a: Zone?, b: Zone): boolean
	return a ~= nil
		and a.Key == b.Key
		and a.Shape == b.Shape
		and a.CFrame == b.CFrame
		and a.HalfX == b.HalfX
		and a.HalfZ == b.HalfZ
end

local function resolve()
	local missing = false
	const byKey, byParty = taggedParts()
	const list: { Zone } = {}
	const platforms: { [number]: Zone } = {}
	for _, row in LOBBY.Zones do
		local part = byKey[row.Key]
		if part == nil and row.Platform > 0 then
			part = byParty[row.Platform]
		end
		local geometry: Geometry? = nil
		if part ~= nil then
			geometry = geometryOf(part)
			lastKnown[row.Key] = geometry
		else
			geometry = lastKnown[row.Key]
		end
		local zone: Zone
		if geometry ~= nil then
			const halfX, halfZ = geometry.HalfX, geometry.HalfZ
			zone = {
				Key = row.Key,
				Panel = row.Panel,
				Platform = row.Platform,
				Color = row.Color,
				Shape = geometry.Shape,
				CFrame = geometry.CFrame,
				Center = geometry.CFrame.Position,
				Radius = if geometry.Shape == "Circle" then halfX else math.sqrt(halfX * halfX + halfZ * halfZ),
				HalfX = halfX,
				HalfZ = halfZ,
				FromMap = true,
			}
		else
			local center = row.Center
			const pointId = row.PointId
			if pointId ~= nil then
				const point = findPoint(pointId)
				if point ~= nil then
					center = point.Position
				else
					missing = true
				end
			end
			-- a fallback with Size is the map's floor apron rectangle (TASK-314); else a circle of Radius
			const size = row.Size
			const halfX = if size ~= nil then size.X / 2 else row.Radius
			const halfZ = if size ~= nil then size.Y / 2 else row.Radius
			zone = {
				Key = row.Key,
				Panel = row.Panel,
				Platform = row.Platform,
				Color = row.Color,
				Shape = if size ~= nil then "Rect" else "Circle",
				CFrame = CFrame.new(center),
				Center = center,
				Radius = if size ~= nil then math.sqrt(halfX * halfX + halfZ * halfZ) else row.Radius,
				HalfX = halfX,
				HalfZ = halfZ,
				FromMap = false,
			}
		end
		table.insert(list, zone)
		if row.Platform > 0 then
			platforms[row.Platform] = zone
		end
	end
	local changed = #list ~= #zones
	if not changed then
		for i, zone in list do
			if not same(zones[i], zone) then
				changed = true
				break
			end
		end
	end
	if changed then
		zones = list
		byPlatform = platforms
		version += 1
	end
	complete = not missing
end

local function watch(instance: Instance)
	dirty = true
	if not instance:IsA("BasePart") or watched[instance] ~= nil then
		return
	end
	const part = instance :: BasePart
	const connections = {
		part:GetPropertyChangedSignal("CFrame"):Connect(markDirty),
		part:GetPropertyChangedSignal("Size"):Connect(markDirty),
		part.AttributeChanged:Connect(markDirty),
		part.AncestryChanged:Connect(markDirty),
	}
	if part:IsA("Part") then
		table.insert(connections, part:GetPropertyChangedSignal("Shape"):Connect(markDirty))
	end
	watched[part] = connections
end

local function unwatch(instance: Instance)
	dirty = true
	if not instance:IsA("BasePart") then
		return
	end
	const part = instance :: BasePart
	if part:HasTag(TAG) or part:HasTag(PLATFORM_TAG) then
		return -- one tag of two removed, or streamed out: still watched
	end
	const connections = watched[part]
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
		watched[part] = nil
	end
end

local function start()
	if started then
		return
	end
	started = true
	for _, tag in { TAG, PLATFORM_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unwatch)
		for _, instance in CollectionService:GetTagged(tag) do
			watch(instance)
		end
	end
end

local function current(): { Zone }
	start()
	const now = os.clock()
	if dirty or (not complete and now >= nextLookup) then
		dirty = false
		nextLookup = now + REFRESH
		resolve()
	end
	return zones
end

local LobbyZones = {}

LobbyZones.Tag = TAG
LobbyZones.KeyAttribute = KEY_ATTRIBUTE

function LobbyZones.List(): { Zone }
	return current()
end

function LobbyZones.Platform(n: number): Zone?
	current()
	return byPlatform[n]
end

-- Moves every time a zone's place, size or shape changed (the VFX rebuilds on it).
function LobbyZones.Version(): number
	current()
	return version
end

function LobbyZones.Inside(zone: Zone, position: Vector3, was: boolean): boolean
	const trigger = LOBBY.Trigger
	const margin = if was then trigger.Hysteresis else 0
	if zone.Shape == "Circle" then
		const dx = position.X - zone.Center.X
		const dz = position.Z - zone.Center.Z
		const radius = zone.Radius + margin
		return dx * dx + dz * dz <= radius * radius
	end
	const point = zone.CFrame:PointToObjectSpace(position)
	return math.abs(point.X) <= zone.HalfX + margin and math.abs(point.Z) <= zone.HalfZ + margin
end

return table.freeze(LobbyZones)
