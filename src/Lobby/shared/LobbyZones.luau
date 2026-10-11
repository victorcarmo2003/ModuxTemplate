--!strict
-- Lobby zones geometry (Content.Lobby; user request 2026-10-11, Provisional). ReplicatedStorage.shared.Lobby.LobbyZones,
-- read by PartyService (server: who stands on which squad platform) and LobbyController (client: panel triggers and
-- the ring VFX). Pure: no Modux, Lync, Vide nor self.Libs.
--
-- Zone centre = its MapPoint (PointId) when the map has it, else Content.Lobby.Zones[i].Center. Points are looked up
-- again every REFRESH s while one is missing (the lobby map may stream in late on the client); MapIndex's cache is
-- never dropped here.
-- Inside(): planar distance to the centre <= Radius (or <= Radius + Hysteresis when it was already inside, so the
-- edge does not flicker) and |dy| <= Trigger.Height.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)

export type Zone = {
	Key: string,
	Panel: Content.LobbyPanel,
	Platform: number,
	Center: Vector3,
	Radius: number,
	Color: Color3,
}

const LOBBY = Content.Lobby
const REFRESH = 5 -- s between two point lookups while one is missing

local zones: { Zone } = {}
local byPlatform: { [number]: Zone } = {}
local nextLookup = 0
local complete = false

local function findPoint(id: string): CFrame?
	if not MapIndex.HasBinding() then
		return nil
	end
	const ok, point = pcall(MapIndex.FindPoint, id)
	return if ok then point else nil
end

local function resolve()
	local missing = false
	const list: { Zone } = {}
	const platforms: { [number]: Zone } = {}
	for _, row in LOBBY.Zones do
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
		const zone: Zone = {
			Key = row.Key,
			Panel = row.Panel,
			Platform = row.Platform,
			Center = center,
			Radius = row.Radius,
			Color = row.Color,
		}
		table.insert(list, zone)
		if row.Platform > 0 then
			platforms[row.Platform] = zone
		end
	end
	zones = list
	byPlatform = platforms
	complete = not missing
end

local function current(): { Zone }
	const now = os.clock()
	if #zones == 0 or (not complete and now >= nextLookup) then
		nextLookup = now + REFRESH
		resolve()
	end
	return zones
end

local LobbyZones = {}

function LobbyZones.List(): { Zone }
	return current()
end

function LobbyZones.Platform(n: number): Zone?
	current()
	return byPlatform[n]
end

function LobbyZones.Inside(zone: Zone, position: Vector3, was: boolean): boolean
	const trigger = LOBBY.Trigger
	if math.abs(position.Y - zone.Center.Y) > trigger.Height then
		return false
	end
	const dx = position.X - zone.Center.X
	const dz = position.Z - zone.Center.Z
	const radius = if was then zone.Radius + trigger.Hysteresis else zone.Radius
	return dx * dx + dz * dz <= radius * radius
end

return table.freeze(LobbyZones)
