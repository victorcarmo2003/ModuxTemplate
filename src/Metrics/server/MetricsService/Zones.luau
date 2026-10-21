--!strict
-- Run hot zones (owner request 2026-10-21, Provisional): where the players spend the run, for the RoMetrics hot zones
-- card. Run servers only; MetricsService builds one with Zones.new(env) and feeds it. Server side, from the
-- HumanoidRootPart, like Lobby.luau (Zone:lobby.<zone>).
--   Zone:run.<zone>  each zone change {t = s since join, phase = shift phase, shift = day_N | night_N}; the first zone
--                    is logged as soon as it is known. Zones: pantry, kitchen, patio, drive_thru, gear_stand, backyard,
--                    plaza, street (= none of them)
--   zone_dwell       on leave, s spent per zone (value) {zone = "run.<zone>"}; only while Active
-- Order: pantry (Restaurant.SafeBoxes[1]), kitchen (the trailer LightZone), then Content.RunZones.Boxes, else street.
-- A new zone counts after MinStay s without leaving it (a walk across a box is not a visit); a box already inside grows
-- by Hysteresis studs. A player who is not Active (down, reviving, spectator, away) stops counting and does not re-emit
-- the same zone on return. MinStay / Hysteresis / POLL are Provisional.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Verbose = require(ReplicatedStorage.shared.Verbose)
local RawLog = require(script.Parent.Log)

-- Log with a trace in the Output (Workspace VerboseLogs, Studio checks)
const Log = {
	player = function(player: Player, name: string, value: number?, props: RawLog.Props?)
		Verbose.print(`[MetricsZones] {player.Name} {name} {value or ""}`)
		RawLog.player(player, name, value, props)
	end,
}

const JOIN_DELAY = 2 -- s: the SDK opens the player's session on PlayerAdded too; an event before it is dropped
const POLL = 0.5 -- s between two position reads per player
const STREET = "street"
const PANTRY = "pantry"
const KITCHEN = "kitchen"

-- What the service needs from the others (MetricsService wires them from its Dependencies)
export type Env = {
	InKitchen: (position: Vector3) -> boolean,
	IsActive: (player: Player) -> boolean,
	-- phase and shift name now ("Open", "day_2")
	Shift: () -> (string, string),
}

type Track = {
	JoinedAt: number,
	Zone: string?, -- confirmed zone
	Since: number, -- when the confirmed zone started counting
	Pending: string?, -- a different zone seen, waiting for MinStay
	PendingAt: number,
	InBox: { [string]: boolean }, -- box key -> inside (hysteresis)
	Dwell: { [string]: number },
	Resting: boolean,
}

const Zones = {}
Zones.__index = Zones

export type Zones = typeof(setmetatable(
	{} :: {
		Env: Env,
		Tracks: { [Player]: Track },
		PollAt: number,
	},
	Zones
))

function Zones.new(env: Env): Zones
	return setmetatable({
		Env = env,
		Tracks = {},
		PollAt = 0,
	}, Zones)
end

local function inside(position: Vector3, min: Vector3, max: Vector3, grow: number): boolean
	return position.X >= min.X - grow
		and position.X <= max.X + grow
		and position.Y >= min.Y - grow
		and position.Y <= max.Y + grow
		and position.Z >= min.Z - grow
		and position.Z <= max.Z + grow
end

-- Box test with hysteresis: remembers the result in the track
local function testBox(track: Track, key: string, position: Vector3, min: Vector3, max: Vector3, grow: number): boolean
	const isIn = inside(position, min, max, if track.InBox[key] == true then grow else 0)
	track.InBox[key] = isIn
	return isIn
end

function Zones.Classify(self: Zones, track: Track, position: Vector3): string
	const rules = Content.RunZones
	local found: string? = nil
	-- every box is tested every poll so each one keeps its own hysteresis memory
	const pantry = Content.Restaurant.SafeBoxes[1]
	if pantry ~= nil and testBox(track, PANTRY, position, pantry.Min, pantry.Max, rules.Hysteresis) then
		found = PANTRY
	end
	const kitchen = self.Env.InKitchen(position)
	if found == nil and kitchen then
		found = KITCHEN
	end
	for _, box in rules.Boxes do
		if testBox(track, box.Key, position, box.Min, box.Max, rules.Hysteresis) and found == nil then
			found = box.Key
		end
	end
	return found or STREET
end

-- Dwell of the confirmed zone up to now
local function close(track: Track, now: number)
	const zone = track.Zone
	if zone ~= nil and not track.Resting then
		track.Dwell[zone] = (track.Dwell[zone] or 0) + (now - track.Since)
	end
	track.Since = now
end

function Zones.Join(self: Zones, player: Player)
	self.Tracks[player] = {
		JoinedAt = os.clock(),
		Zone = nil,
		Since = 0,
		Pending = nil,
		PendingAt = 0,
		InBox = {},
		Dwell = {},
		Resting = false,
	}
end

function Zones.Commit(self: Zones, player: Player, track: Track, zone: string, now: number)
	close(track, now)
	track.Zone = zone
	track.Pending = nil
	const phase, shift = self.Env.Shift()
	Log.player(player, `Zone:run.{zone}`, nil, {
		t = math.floor(now - track.JoinedAt),
		phase = phase,
		shift = shift,
	})
end

-- Not Active any more: closes the dwell and stops counting. Back to Active: counts again from now, same zone, no event
function Zones.Rest(self: Zones, player: Player, resting: boolean)
	const track = self.Tracks[player]
	if track == nil or track.Resting == resting then
		return
	end
	const now = os.clock()
	if resting then
		close(track, now)
		track.Resting = true
	else
		track.Resting = false
		track.Since = now
	end
	track.Pending = nil
end

function Zones.Poll(self: Zones)
	const now = os.clock()
	if now < self.PollAt then
		return
	end
	self.PollAt = now + POLL
	for player, track in self.Tracks do
		if now - track.JoinedAt < JOIN_DELAY then
			continue -- the SDK session first
		end
		if not self.Env.IsActive(player) then
			self:Rest(player, true)
			continue
		end
		self:Rest(player, false)
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root == nil then
			continue
		end
		const zone = self:Classify(track, root.Position)
		if track.Zone == nil then
			self:Commit(player, track, zone, now)
		elseif zone == track.Zone then
			track.Pending = nil
		elseif track.Pending ~= zone then
			track.Pending = zone
			track.PendingAt = now
		elseif now - track.PendingAt >= Content.RunZones.MinStay then
			self:Commit(player, track, zone, now)
		end
	end
end

function Zones.Leave(self: Zones, player: Player)
	const track = self.Tracks[player]
	self.Tracks[player] = nil
	if track == nil then
		return
	end
	close(track, os.clock())
	for zone, seconds in track.Dwell do
		if seconds >= 1 then
			Log.player(player, "zone_dwell", math.floor(seconds), { zone = `run.{zone}` })
		end
	end
end

return Zones
