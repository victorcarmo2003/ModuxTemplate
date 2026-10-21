--!strict
--[[
	SuspenseService (TASK-481; DEC-294; design/horror-cinematic.md §7; tech/suspense.md). Run place only.

	Suspense events are NOT anomalies: no rule, no verb, no warning, no Anomalies record. A creature (Content.Suspense
	row) appears at once on a spot (Content.Suspense.Spots) that NOBODY is looking at; whoever catches it at a glance
	gets the camera pulled to it on their own client and loses Rules.Cost sanity, once per player per event.

	  Agenda    ShiftStarted of a night >= Rules.FromNight: Rules.PerNight draws (seeded by RunSeed, Day, Night,
	            Attempt), one per equal slice of Rules.Window (game minutes), jittered inside the slice. Not in the
	            snapshot; a restore/repeat rebuilds it. Night phase only.
	  Start     a due entry waits while any anomaly occurrence runs, for Rules.AfterAnomaly s after one ends, for
	            Rules.MinGap s after the last event and while one is live (one at a time). It draws an event open on
	            the night (Weight), then a spot of that event where no Active player is looking (AnomalyService:Looking,
	            cone Rules.HiddenAngle up to Rules.HiddenRange; occluded = not looking) and no Active player stands
	            closer than Rules.MinDistance. No free spot = retry in Rules.Retry s; past the window = dropped.
	  Publish   packet Suspense { Id, Event, Spot, Seed } to the Audience; the event is live Rules.Life s.
	  Seen      packet SuspenseSeen { Id } from a client that caught it. Accepted while the event is live (+1 s of
	            latency), from an Active player who has not paid yet, when the Gaze is plausible: inside Rules.SeenAngle
	            now, or at some 5 Hz tick of this event (Gaze is 10 Hz and lags the client). Cost drawn once per event
	            in Rules.Cost; VitalService:AddSanity(player, -cost, "suspense:<key>").

	API: :IsLive() -> boolean; :DevForce(event?, spot?) -> string; :DevList() -> string; :DevStatus() -> string;
	signal Caught(eventKey, player, cost) (analytics).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

type Info = { Day: number, Night: number, IsNight: boolean, Attempt: number }

export type Live = {
	Id: number,
	Event: Content.SuspenseEvent,
	Spot: Content.SuspenseSpot,
	Target: Vector3, -- the "seen" point (head of the creature)
	StartedAt: number,
	EndsAt: number,
	Cost: number,
	Paid: { [number]: boolean },
	-- UserIds whose Gaze was inside Rules.SeenAngle at some tick of this event
	Glimpsed: { [number]: boolean },
}

const RULES = Content.Suspense.Rules
const TICK_RATE = 5 -- Hz
const MAX_ID = 255 -- Suspense.Id wire range
const SEED_MAX = 65535
const SEEN_GRACE = 1 -- s after EndsAt a "seen" claim is still accepted (latency)
const GROUND_UP = 6 -- studs above the feet the floor raycast starts
const GROUND_DOWN = 20 -- studs it looks down
const NIGHT_PHASE = "Night"
const DOMAIN = 0x5355 -- "SU": seed domain of the suspense agenda

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Feet on the floor under `position` (characters ignored); the position itself when nothing is under it.
local function ground(position: Vector3): Vector3
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	const hit = workspace:Raycast(position + Vector3.new(0, GROUND_UP, 0), Vector3.new(0, -GROUND_DOWN, 0), params)
	return if hit ~= nil then hit.Position else position
end

-- Feet of a spot: its MapPoint when the place has it, else the Content position; dropped to the floor.
local function feetOf(spot: Content.SuspenseSpot): Vector3
	const point = MapIndex.FindPoint(spot.Point)
	return ground(if point ~= nil then point.Position else spot.Position)
end

local function targetOf(event: Content.SuspenseEvent, spot: Content.SuspenseSpot): Vector3
	return feetOf(spot) + Vector3.new(0, event.Head * event.Scale * spot.Scale, 0)
end

local function weighted(rows: { Content.SuspenseEvent }, rng: Random): Content.SuspenseEvent?
	local total = 0
	for _, row in rows do
		total += row.Weight
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, row in rows do
		roll -= row.Weight
		if roll <= 0 then
			return row
		end
	end
	return rows[#rows]
end

const SuspenseService = Modux.Service("SuspenseService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"RunStateService",
		"VitalService",
		"AnomalyService",
	},
	Priority = 540,
})

function SuspenseService:Setup()
	self.Enabled = false :: boolean
	-- game minutes of the night's events still to start, ascending
	self.Agenda = {} :: { number }
	self.Live = nil :: Live?
	self.NextId = 0 :: number
	-- server time of the last event start / of the last tick an anomaly was running (0 = none tonight)
	self.LastAt = 0 :: number
	self.BusyAt = 0 :: number
	self.RetryAt = 0 :: number
	self.Night = 0 :: number
	self.Rng = Random.new() :: Random
	-- Caught(eventKey, player, cost): analytics hook (MetricsService may connect in its OnInit)
	self.Caught = self.Libs.Signal.new() :: SignalLib.Signal<string, Player, number>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function SuspenseService:IsLive(): boolean
	const live = self.Live
	return live ~= nil and now() <= live.EndsAt
end

-- Any anomaly occurrence running right now (never during one, DEC-294)
function SuspenseService:AnomalyBusy(): boolean
	const anomaly = self.Dependencies.AnomalyService
	if anomaly:IsTension() then
		return true
	end
	for _, run in anomaly.Running do
		if not run.Done then
			return true
		end
	end
	return false
end

-- Nobody Active looks at `target` (cone Rules.HiddenAngle) and nobody stands closer than Rules.MinDistance.
function SuspenseService:IsHidden(target: Vector3): boolean
	const anomaly = self.Dependencies.AnomalyService
	for _, player in anomaly:ActivePlayers() do
		const character = player.Character
		const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			const offset = root.Position - target
			if Vector2.new(offset.X, offset.Z).Magnitude < RULES.MinDistance then
				return false
			end
		end
		if anomaly:Looking(player, target, RULES.HiddenRange, RULES.HiddenAngle) then
			return false
		end
	end
	return true
end

-- Agenda ----------------------------------------------------------------------------------------------------------

function SuspenseService:OnShiftStarted(info: Info)
	self.Agenda = {}
	self.Live = nil
	self.NextId = 0
	self.LastAt = 0
	self.BusyAt = 0
	self.RetryAt = 0
	self.Night = info.Night
	const seed = (self.Dependencies.RunStateService.Seed() * 31 + info.Day * 977 + info.Night * 7919 + info.Attempt * 104729 + DOMAIN)
		% 2147483647
	self.Rng = Random.new(seed)
	if not info.IsNight or info.Night < RULES.FromNight then
		return
	end
	const count = self.Rng:NextInteger(RULES.PerNight[1], RULES.PerNight[2])
	if count <= 0 then
		return
	end
	const window = RULES.Window
	const slice = (window[2] - window[1]) / count
	for index = 1, count do
		table.insert(self.Agenda, window[1] + slice * (index - 1) + slice * (0.15 + 0.7 * self.Rng:NextNumber()))
	end
	table.sort(self.Agenda)
end

function SuspenseService:OnPhase(phase: string)
	if phase ~= NIGHT_PHASE then
		-- Call and Prep come before the Night phase: the agenda built at ShiftStarted waits for it
		if phase ~= "Call" and phase ~= "Prep" then
			self.Agenda = {}
		end
		self.Live = nil
	end
end

-- Start -----------------------------------------------------------------------------------------------------------

-- Starts one event. eventKey/spotKey nil = drawn. force = dev: any night, and a named spot skips the hidden test.
-- Returns (started, message).
function SuspenseService:Start(eventKey: string?, spotKey: string?, force: boolean): (boolean, string)
	if not self.Dependencies.NetService:IsRunning() then
		return false, "net not running"
	end
	local event: Content.SuspenseEvent? = nil
	if eventKey ~= nil then
		event = Content.Suspense.ByKey[eventKey]
		if event == nil then
			return false, `'{eventKey}' is not a Content.Suspense event`
		end
	else
		const open: { Content.SuspenseEvent } = {}
		for _, row in Content.Suspense.List do
			if force or row.FromNight <= self.Night then
				if spotKey == nil or table.find(row.Spots, spotKey) ~= nil then
					table.insert(open, row)
				end
			end
		end
		event = weighted(open, self.Rng)
	end
	if event == nil then
		return false, if spotKey ~= nil then `no event uses spot '{spotKey}'` else "no event open tonight"
	end
	const chosen: Content.SuspenseEvent = event

	local spot: Content.SuspenseSpot? = nil
	local target = Vector3.zero
	if spotKey ~= nil then
		const row = Content.Suspense.Spots.ByKey[spotKey]
		if row == nil then
			return false, `'{spotKey}' is not a Content.Suspense.Spots key`
		end
		target = targetOf(chosen, row)
		if not force and not self:IsHidden(target) then
			return false, `someone is looking at '{spotKey}'`
		end
		spot = row
	else
		-- spots of the event in a random order; the first one nobody looks at
		const keys = table.clone(chosen.Spots)
		for index = #keys, 2, -1 do
			const other = self.Rng:NextInteger(1, index)
			keys[index], keys[other] = keys[other], keys[index]
		end
		for _, key in keys do
			const row = Content.Suspense.Spots.ByKey[key]
			if row ~= nil then
				const at = targetOf(chosen, row)
				if self:IsHidden(at) then
					spot = row
					target = at
					break
				end
			end
		end
	end
	if spot == nil then
		return false, `every spot of '{chosen.Key}' is in someone's view`
	end

	self.NextId = self.NextId % MAX_ID + 1
	const t = now()
	const live: Live = {
		Id = self.NextId,
		Event = chosen,
		Spot = spot,
		Target = target,
		StartedAt = t,
		EndsAt = t + RULES.Life,
		Cost = self.Rng:NextInteger(RULES.Cost[1], RULES.Cost[2]),
		Paid = {},
		Glimpsed = {},
	}
	self.Live = live
	self.LastAt = t
	self.Libs.Net.Suspense:fireClient(self.Dependencies.NetService.Audience, {
		Id = live.Id,
		Event = chosen.Key,
		Spot = spot.Key,
		Seed = self.Rng:NextInteger(0, SEED_MAX),
	})
	return true, `{chosen.Key} at {spot.Key} (id {live.Id}, cost {live.Cost})`
end

-- Seen ------------------------------------------------------------------------------------------------------------

function SuspenseService:OnSeen(value: any, player: Player)
	if type(value) ~= "table" or type(value.Id) ~= "number" then
		return
	end
	const live = self.Live
	if live == nil or live.Id ~= value.Id or now() > live.EndsAt + SEEN_GRACE then
		return
	end
	if live.Paid[player.UserId] or not self.Dependencies.RunStateService:IsActive(player) then
		return
	end
	const glimpsed = live.Glimpsed[player.UserId]
		or self.Dependencies.AnomalyService:Looking(player, live.Target, RULES.SeenRange, RULES.SeenAngle)
	if not glimpsed then
		return
	end
	live.Paid[player.UserId] = true
	self.Dependencies.VitalService:AddSanity(player, -live.Cost, `suspense:{live.Event.Key}`)
	self.Caught:Fire(live.Event.Key, player, live.Cost)
end

-- Tick ------------------------------------------------------------------------------------------------------------

function SuspenseService:Step()
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or round:GetPhase() ~= NIGHT_PHASE then
		return
	end
	const t = now()
	if self:AnomalyBusy() then
		self.BusyAt = t
	end

	const live = self.Live
	if live ~= nil then
		if t > live.EndsAt + SEEN_GRACE then
			self.Live = nil
		else
			-- Gaze lags the client: remember who had it in the generous cone at any tick of the event
			const anomaly = self.Dependencies.AnomalyService
			for _, player in anomaly:ActivePlayers() do
				if not live.Glimpsed[player.UserId] and anomaly:Looking(player, live.Target, RULES.SeenRange, RULES.SeenAngle) then
					live.Glimpsed[player.UserId] = true
				end
			end
		end
		return
	end

	if #self.Agenda == 0 or self.Dependencies.AnomalyService.DevHeld then
		return
	end
	const minutes = round:Minutes()
	if self.Agenda[1] > minutes then
		return
	end
	if minutes >= RULES.Window[2] then
		table.remove(self.Agenda, 1)
		return
	end
	if
		t < self.RetryAt
		or (self.BusyAt > 0 and t - self.BusyAt < RULES.AfterAnomaly)
		or (self.LastAt > 0 and t - self.LastAt < RULES.MinGap)
		-- the beat budget (AnomalyService:BeatClear, owner 2026-10-21): gap since the last beat, no regular anomaly due soon
		or not self.Dependencies.AnomalyService:BeatClear("suspense")
	then
		return
	end
	const started = self:Start(nil, nil, false)
	if started then
		-- no verb: it takes the gap, it never counts as active
		self.Dependencies.AnomalyService:BeatBegin("suspense", 0)
		table.remove(self.Agenda, 1)
	else
		self.RetryAt = t + RULES.Retry
	end
end

-- Dev (Commands/Suspense.luau) ------------------------------------------------------------------------------------

-- `suspense [event] [spot]`: any phase/night; a named spot skips the "nobody looking" test.
function SuspenseService:DevForce(eventKey: string?, spotKey: string?): string
	if not self.Enabled then
		return "suspense events run only in the Run place"
	end
	const _, message = self:Start(eventKey, spotKey, true)
	return message
end

function SuspenseService:DevList(): string
	const lines: { string } = {}
	for _, row in Content.Suspense.List do
		table.insert(lines, `{row.Key} ({row.Style}, night {row.FromNight}+): {table.concat(row.Spots, ", ")}`)
	end
	table.insert(lines, `spots: {table.concat(Content.Suspense.SpotKeys, ", ")}`)
	return table.concat(lines, "\n")
end

function SuspenseService:DevStatus(): string
	const parts: { string } = {}
	for _, at in self.Agenda do
		const minutes = math.floor(at) % 1440
		table.insert(parts, string.format("%02d:%02d", minutes // 60, minutes % 60))
	end
	const live = self.Live
	return `night {self.Night}; agenda [{table.concat(parts, " ")}]; live {if live ~= nil
		then `{live.Event.Key}@{live.Spot.Key} id {live.Id}`
		else "none"}; anomaly busy {self:AnomalyBusy()}`
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

SuspenseService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Responder only here (Lync.start runs in NetService OnStart)
	self.Libs.Net.SuspenseSeen:onServer(function(value, player: Player)
		self:OnSeen(value, player)
	end)

	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function(info)
		self:OnShiftStarted(info)
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)
end)

SuspenseService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return SuspenseService
