--!strict
-- Sanity and life state per UserId (TASK-062; architecture.md §6.1, §6.2, §19.7, §19.8, T54; network.md §13.1;
-- data.md §5.2; FEAT-019, FEAT-020, FEAT-021, FEAT-025, FEAT-026, FEAT-034; DEC-056, DEC-091..094, DEC-115, DEC-129,
-- DEC-166..169, DEC-216). Run place only. Rewrites the wave 1 template (Health/Armor/Stamina and the Vital component).
--
-- State lives per UserId (survives Away). The life state itself is the RunStateService Member (snapshot source):
-- this service is its only writer (SetLifeState) and mirrors it, with StateEndsAt/KnockedUntil/Class, in the
-- Vitals set (id = UserId). The sanity number goes only to its owner (packet Sanity, DEC-167); the party sees the
-- band through the LookPack (CharacterService:SetLookPack: High = Day, Mid = Mid, Low = Night; day = Day).
--
--   Night start   ShiftStarted of a night: Sanity/Max from the class (SanityStart, SanityMax over Sanity.Start),
--                 RevivesTonight 0, Seen {}. A member who is Away gets the class values on return (once per night)
--   Day           no sanity: packet { 0, 0 }, look Day
--   Dark (1 Hz)   Active, with a character, night shift in Sanity.DarkPhases: not IsLit for DarkDelay s ->
--                 -DarkPerSecond per s (none before ProtectUntil)
--   Sanity 0      RevivesTonight < Revive.MaxPerNight -> Down (Faint, Stash, StateEndsAt = 6:00 AM), else Spectator
--                 at once (Faint, DropStash, DEC-129); LifeEvent; PickupHandler(userId, bodyPos)
--   6:00 AM       phase NightEnd: every Down -> Spectator + ItemService:DropStash(userId, "DROP-T") (FEAT-025)
--   Wipe window   nobody present standing (Active/Reviving) while the night can be lost -> RoundService:SetWipe
--                 (now + Revive.WipeWindow) + LifeEvent Wipe; expired -> LoseNight("wipe"); someone standing
--                 again -> SetWipe(0) + WipeCleared. No freeze before wave 4 (DEC-118)
--   Verdict       RoundService:SetVerdict: someone present Active/Reviving
--   Gate "Vital"  only Active, not knocked, interacts (InteractionService:AddGate)
--   Coffee        ItemService:RegisterUse("coffee"): night only (Sanity.CoffeeNightOnly, Q-170 A Provisional),
--                 not full (no drink cooldown: the machine owns the wait, TASK-328); one sip (Content.CoffeeCup.Sips): the whole Restore once, then Consume
--
-- Hooks left for other tasks (§19.0 rule 1, no Require back):
--   LightService (TASK-059)  in Require (architecture.md §19.2; Light does not require Vital, no cycle). IsLit is read
--                            at tick time only; an error counts as lit (no dark loss). "sanity dark on|off" forces it
--   AnomalyService (wave 3)  SeeAnomaly, Penalize
--   TrafficService (wave 3)  SetKnocked
--   AmbulanceService (w4)    SetPickupHandler (default: RemoveBody after Revive.BodyFallback, T54)
--   ReviveKitService         Revive(player, reviver?) (TASK-317): Down -> Active, same core (Restore) as DevRevive
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Flow = require(ServerScriptService.server.Round.RoundService.Flow)
local Life = require(script.Life)
local Sanity = require(script.Sanity)
local Modux = require(ServerScriptService.server.Modux)

export type LifeState = Life.State
export type Band = Sanity.Band
export type LifeEventKind = "Down" | "Revived" | "Spectating" | "Hit" | "Wipe" | "WipeCleared"
export type PickupHandler = (userId: number, bodyPos: Vector3?) -> ()

export type Entry = {
	UserId: number,
	-- night token the entry belongs to (0 = day, no sanity)
	Night: number,
	-- class start values still to apply (member was not in the server at the night start)
	Fresh: boolean,
	Sanity: number,
	Max: number,
	DarkSince: number?,
	ProtectUntil: number,
	-- Night 1 coffee lesson: server time the HUD emphasis ends (0 = none running); see StartCoffeeHint
	HintUntil: number,
	RevivesTonight: number,
	Seen: { [string]: boolean },
	StateEndsAt: number,
	KnockedUntil: number,
	Band: Band,
	Pending: Band?,
	PendingSince: number,
	SentValue: number,
	SentMax: number,
	LastCause: string,
}

const TICK_RATE = 4 -- Hz: wipe expiry at most 0.25 s late; dark and band hold run every DARK_STEP inside it
const DARK_STEP = 1 -- s (architecture.md §19.7: dark at 1 Hz)
const COFFEE = "coffee"
const GATE = "Vital"
const DROP_POINT = "DROP-T" -- MapPoint of the trailer counter (MAP-01 §5.5; FEAT-025, FEAT-036)
const RESTORE_ATTRIBUTE = "Restore" -- coffee Tool attribute (network.md §7.1; CoffeeMachine)
const NEVER_SENT = -1
const DEV_INFINITE = "DevInfiniteSanity" -- player attribute (dev, TASK-332): read by the settings panel dev row

local function now(): number
	return workspace:GetServerTimeNow()
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function newEntry(userId: number): Entry
	return {
		UserId = userId,
		Night = 0,
		Fresh = false,
		Sanity = 0,
		Max = 0,
		DarkSince = nil,
		ProtectUntil = 0,
		HintUntil = 0,
		RevivesTonight = 0,
		Seen = {},
		StateEndsAt = 0,
		KnockedUntil = 0,
		Band = "Day",
		Pending = nil,
		PendingSince = 0,
		SentValue = NEVER_SENT,
		SentMax = NEVER_SENT,
		LastCause = "",
	}
end

local function isDarkPhase(phase: string): boolean
	return table.find(Content.Sanity.DarkPhases, phase) ~= nil
end

const VitalService = Modux.Service("VitalService", {
	Require = {
		"PlaceService",
		"PlayerService",
		"NetService",
		"RunStateService",
		"RoundService",
		"CharacterService",
		"ItemService",
		"InteractionService",
		"ClassService",
		"LightService",
	},
	Priority = 700,
})

function VitalService:Setup()
	self.Enabled = false :: boolean
	-- Lync started and the Vitals set is writable (OnStart)
	self.Live = false :: boolean
	self.Entries = {} :: { [number]: Entry }
	-- Vitals records already added (add once, update after)
	self.Published = {} :: { [number]: boolean }
	-- night token: bumped at every night start (a repeated night is a new token); 0 by day
	self.Night = 0 :: number
	self.NightSerial = 0 :: number
	-- 10 s window (DEC-094): server time it ends, 0 = closed
	self.WipeEndsAt = 0 :: number
	self.WipeQueued = false :: boolean
	self.LastFallen = 0 :: number
	self.NextDarkAt = 0 :: number
	self.PickupHandler = nil :: PickupHandler?
	-- dev override of IsLit: nil = probe, true = everything lit, false = everything dark
	self.DevLit = nil :: boolean?
	-- dev showcase: sanity never reaches 0 by itself (no natural fall); explicit dev falls still work
	self.DevGodMode = false :: boolean
	-- dev, per player (TASK-332): sanity never goes down and the member never faints (only dev falls); mirrored to the
	-- player attribute DEV_INFINITE for the settings panel
	self.DevInfinite = {} :: { [number]: boolean }
	self.DevFalling = false :: boolean
	self.WarnedLight = false :: boolean
	self.MemberStateChanged = self.Libs.Signal.new() :: SignalLib.Signal<number, LifeState, LifeState>
	self.Wipe = self.Libs.Signal.new() :: SignalLib.Signal<boolean, number>
end

-- Entries -----------------------------------------------------------------------------------------------------------

-- Entry of a UserId, moved to the current night (or day) on first touch.
function VitalService:EntryOf(userId: number): Entry
	local entry = self.Entries[userId]
	if entry == nil then
		entry = newEntry(userId)
		self.Entries[userId] = entry
	end
	if self.Night > 0 and entry.Night ~= self.Night then
		entry.Night = self.Night
		entry.Fresh = true
		entry.RevivesTonight = 0
		entry.Seen = {}
		entry.DarkSince = nil
		entry.ProtectUntil = 0
		entry.StateEndsAt = 0
	elseif self.Night == 0 and entry.Night ~= 0 then
		entry.Night = 0
		entry.Fresh = false
		entry.Sanity = 0
		entry.Max = 0
		entry.Seen = {}
		entry.DarkSince = nil
		entry.ProtectUntil = 0
	end
	return entry
end

-- Entry of a player in the server, with the class start values applied when still owed.
function VitalService:Ensure(player: Player): Entry
	const entry = self:EntryOf(player.UserId)
	if entry.Fresh and player.Parent ~= nil then
		entry.Fresh = false
		const rows = Content.Sanity
		const classes = self.Dependencies.ClassService
		const start, max = Sanity.start(
			classes:GetModifier(player, "SanityStart", rows.Start),
			classes:GetModifier(player, "SanityMax", rows.Start)
		)
		-- Night 1 starts low so the rookie learns the coffee (user request 2026-10-11, Provisional): never raises
		const first = if self.Dependencies.RoundService:GetNight() == 1 then rows.FirstNightStart else start
		entry.Sanity = Sanity.clamp(math.min(start, first), max)
		entry.Max = max
		entry.HintUntil = 0
	end
	return entry
end

-- Reads -------------------------------------------------------------------------------------------------------------

-- (value, max); max 0 = no sanity (day).
function VitalService:GetSanity(player: Player): (number, number)
	if not self.Enabled then
		return 0, 0
	end
	const entry = self:Ensure(player)
	return entry.Sanity, entry.Max
end

function VitalService:GetState(userId: number): LifeState?
	const member = self.Dependencies.RunStateService.Members()[userId]
	return if member then member.State else nil
end

function VitalService:IsActive(player: Player): boolean
	return self.Dependencies.RunStateService:IsActive(player)
end

function VitalService:IsKnocked(player: Player): boolean
	const entry = self.Entries[player.UserId]
	return entry ~= nil and entry.KnockedUntil > now()
end

-- Someone present (not Away) standing: Active or Reviving.
function VitalService:Counts(): (number, number)
	const states: { LifeState } = {}
	for _, member in self.Dependencies.RunStateService.Members() do
		table.insert(states, member.State)
	end
	return Life.count(states)
end

function VitalService:Verdict(): boolean
	const _, standing = self:Counts()
	return standing > 0
end

-- Light ---------------------------------------------------------------------------------------------------------------

function VitalService:IsLit(position: Vector3): boolean
	if self.DevLit ~= nil then
		return self.DevLit
	end
	const light = self.Dependencies.LightService
	const ok, lit = pcall(function(): boolean
		return light:IsLit(position)
	end)
	if not ok then
		if not self.WarnedLight then
			self.WarnedLight = true
			warn(`[VitalService] IsLit errored: {lit}`)
		end
		return true
	end
	return lit == true
end

-- Network -----------------------------------------------------------------------------------------------------------

function VitalService:ClassOf(userId: number, class: string): string
	if Content.Classes.ByKey[class] ~= nil then
		return class
	end
	const player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		const locked = self.Dependencies.ClassService:GetClass(player)
		if Content.Classes.ByKey[locked] ~= nil then
			return locked
		end
	end
	return Content.Classes.Keys[1]
end

-- Vitals record of a member (single writer; network.md §13.1).
function VitalService:Publish(userId: number)
	if not self.Live or not self.Dependencies.NetService:IsRunning() then
		return
	end
	const member = self.Dependencies.RunStateService.Members()[userId]
	if member == nil then
		return
	end
	const entry = self:EntryOf(userId)
	const record = {
		State = member.State,
		StateEndsAt = entry.StateEndsAt,
		KnockedUntil = entry.KnockedUntil,
		Class = self:ClassOf(userId, member.Class),
	}
	if self.Published[userId] then
		self.Libs.Net.Vitals:update(userId, record)
	else
		self.Published[userId] = true
		self.Libs.Net.Vitals:add(userId, record)
	end
end

-- Sanity packet to its owner, only on change unless forced (Ready, respawn, return).
function VitalService:SendSanity(player: Player, force: boolean)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or player.Parent == nil or not net:IsReady(player) then
		return
	end
	const entry = self:Ensure(player)
	const max = math.clamp(entry.Max, 0, Sanity.WIRE_MAX)
	const value = Sanity.clamp(entry.Sanity, max)
	if not force and entry.SentValue == value and entry.SentMax == max then
		return
	end
	entry.SentValue = value
	entry.SentMax = max
	self.Libs.Net.Sanity:fireClient(player, { Value = value, Max = max })
end

function VitalService:FireLife(userId: number, event: LifeEventKind)
	const net = self.Dependencies.NetService
	if not net:IsRunning() then
		return
	end
	self.Libs.Net.LifeEvent:fireClient(net.Audience, { UserId = userId, Event = event })
end

-- Look (DEC-167) ---------------------------------------------------------------------------------------------------

function VitalService:ApplyLook(userId: number)
	const player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		self.Dependencies.CharacterService:SetLookPack(player, self:EntryOf(userId).Band)
	end
end

-- Band of the current value; with Sanity.BandMinHold > 0 a new band must hold that long (immediate skips it: night
-- start, day, return, respawn).
function VitalService:RefreshBand(userId: number, immediate: boolean)
	const entry = self:EntryOf(userId)
	const target = Sanity.band(entry.Sanity, entry.Max, Content.Sanity)
	if target == entry.Band then
		entry.Pending = nil
		return
	end
	const hold = Content.Sanity.BandMinHold
	const t = now()
	if not immediate and hold > 0 then
		if entry.Pending ~= target then
			entry.Pending = target
			entry.PendingSince = t
			return
		end
		if t - entry.PendingSince < hold then
			return
		end
	end
	entry.Band = target
	entry.Pending = nil
	self:ApplyLook(userId)
end

-- Sanity ------------------------------------------------------------------------------------------------------------

-- Changes the sanity of an Active member at night (no sanity by day). 0 makes the member fall. Returns the value.
function VitalService:AddSanity(player: Player, delta: number, cause: string): number
	if not self.Enabled or not finite(delta) then
		return 0
	end
	const entry = self:Ensure(player)
	if entry.Max <= 0 or not self.Dependencies.RunStateService:IsActive(player) then
		return entry.Sanity
	end
	if delta < 0 and self.DevInfinite[player.UserId] then
		return entry.Sanity
	end
	const before = entry.Sanity
	entry.Sanity = Sanity.clamp(before + delta, entry.Max)
	if self.DevGodMode and entry.Sanity <= 0 then
		entry.Sanity = math.min(1, entry.Max)
	end
	if entry.Sanity == before then
		return before
	end
	entry.LastCause = cause
	self:SendSanity(player, false)
	self:RefreshBand(player.UserId, false)
	if entry.Sanity <= 0 then
		self:Fall(player, nil)
	end
	return entry.Sanity
end

-- Broken common rule (FEAT-019: -Sanity.RuleBroken). AnomalyService, wave 3.
function VitalService:Penalize(player: Player, cause: string): number
	return self:AddSanity(player, -Content.Sanity.RuleBroken, cause)
end

-- First sight of an anomaly this night (FEAT-019: -SeeAnomaly, Barista by SeeAnomalyLoss). True when it cost sanity.
-- Down and Spectator never see (FEAT-025).
function VitalService:SeeAnomaly(player: Player, key: string): boolean
	if not self.Enabled or type(key) ~= "string" or not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	const entry = self:Ensure(player)
	if entry.Max <= 0 or entry.Seen[key] then
		return false
	end
	entry.Seen[key] = true
	const loss = self.Dependencies.ClassService:GetModifier(player, "SeeAnomalyLoss", Content.Sanity.SeeAnomaly)
	self:AddSanity(player, -loss, `see:{key}`)
	return true
end

-- Hit by a car until untilT (TrafficService, wave 3). 0 = standing. The gate refuses while knocked.
function VitalService:SetKnocked(player: Player, untilT: number)
	if not self.Enabled or not finite(untilT) then
		return
	end
	const entry = self:EntryOf(player.UserId)
	entry.KnockedUntil = math.max(0, untilT)
	self:Publish(player.UserId)
end

-- Ambulance (wave 4) replaces the default body fallback (T54).
function VitalService:SetPickupHandler(handler: PickupHandler)
	if type(handler) ~= "function" then
		error("[VitalService] SetPickupHandler needs a function", 2)
	end
	self.PickupHandler = handler
end

-- Default PickupHandler (waves 2-3, T54): the body fades after Revive.BodyFallback s, if it is still that body.
function VitalService:DefaultPickup(userId: number, _bodyPos: Vector3?)
	const player = Players:GetPlayerByUserId(userId)
	const character = if player then player.Character else nil
	if player == nil or character == nil then
		return
	end
	task.delay(Content.Revive.BodyFallback, function()
		if player.Parent == nil or player.Character ~= character then
			return
		end
		const state = self:GetState(userId)
		if state ~= "Down" and state ~= "Spectator" then
			return
		end
		self.Dependencies.CharacterService:RemoveBody(player)
	end)
end

function VitalService:Pickup(userId: number, bodyPos: Vector3?)
	const handler = self.PickupHandler
	if handler == nil then
		self:DefaultPickup(userId, bodyPos)
		return
	end
	const ok, problem = pcall(handler, userId, bodyPos)
	if not ok then
		warn(`[VitalService] PickupHandler errored: {problem}; using the body fallback`)
		self:DefaultPickup(userId, bodyPos)
	end
end

-- Life ----------------------------------------------------------------------------------------------------------------

-- Sanity 0 (or a dev command): Down while revives are left tonight, else Spectator at once (DEC-129).
function VitalService:Fall(player: Player, forced: LifeState?)
	const runState = self.Dependencies.RunStateService
	const userId = player.UserId
	if not runState:IsActive(player) then
		return
	end
	if self.DevInfinite[userId] and not self.DevFalling then
		return
	end
	const entry = self:EntryOf(userId)
	const state: LifeState = forced or Life.onZero(entry.RevivesTonight, Content.Revive.MaxPerNight)
	const character = player.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const bodyPos = if root ~= nil and root:IsA("BasePart") then root.Position else nil

	entry.DarkSince = nil
	entry.StateEndsAt = if state == "Down" then self.Dependencies.RoundService:NightEndsAt() else 0
	self.LastFallen = userId
	if not runState:SetLifeState(userId, state) then
		return
	end

	self.Dependencies.CharacterService:Faint(player)
	const items = self.Dependencies.ItemService
	if state == "Down" then
		items:Stash(player)
		self:FireLife(userId, "Down")
	else
		items:DropStash(userId, DROP_POINT)
		self:FireLife(userId, "Spectating")
	end
	self:Pickup(userId, bodyPos)
end

-- 6:00 AM (DEC-115): every Down (connected or Away) becomes a permanent Spectator; packages and the whistle go to
-- the counter, the rest vanishes (FEAT-025).
function VitalService:EndDowns()
	const runState = self.Dependencies.RunStateService
	for userId, member in runState.Members() do
		const state = if member.State == "Away" then member.StateBeforeAway else member.State
		if state ~= "Down" then
			continue
		end
		self:EntryOf(userId).StateEndsAt = 0
		if runState:SetLifeState(userId, "Spectator") then
			self.Dependencies.ItemService:DropStash(userId, DROP_POINT)
			self:FireLife(userId, "Spectating")
		end
	end
end

function VitalService:OnLifeChanged(userId: number, old: LifeState, new: LifeState)
	const entry = self:EntryOf(userId)
	if new == "Active" or new == "Spectator" then
		entry.StateEndsAt = 0
	end
	if new == "Active" then
		entry.DarkSince = nil
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			self:Ensure(player)
			self:SendSanity(player, true)
		end
		-- back by the band of the value it returns with (Provisional, DEC-167 note)
		self:RefreshBand(userId, true)
	end
	self:Publish(userId)
	self.MemberStateChanged:Fire(userId, old, new)
	self:QueueWipe()
end

-- Wipe window (DEC-094) -----------------------------------------------------------------------------------------------

-- Deferred: a restore or a fall changes several members in one go; the window looks at the end result.
function VitalService:QueueWipe()
	if self.WipeQueued then
		return
	end
	self.WipeQueued = true
	task.defer(function()
		self.WipeQueued = false
		self:EvaluateWipe()
	end)
end

function VitalService:EvaluateWipe()
	if not self.Enabled then
		return
	end
	const round = self.Dependencies.RoundService
	const present, standing = self:Counts()
	const losable = round:IsStarted() and Flow.CanLose(round:GetPhase(), round:Info())
	const open = Life.wipe(present, standing, losable)
	if open and self.WipeEndsAt == 0 then
		self.WipeEndsAt = now() + Content.Revive.WipeWindow
		round:SetWipe(self.WipeEndsAt, false)
		self.Wipe:Fire(true, self.WipeEndsAt)
		self:FireLife(self.LastFallen, "Wipe")
	elseif not open and self.WipeEndsAt > 0 then
		self:CloseWipe(standing > 0)
	end
end

-- cleared: someone stands again (late joiner, reconnect; wave 4 revive). Otherwise the phase moved on.
function VitalService:CloseWipe(cleared: boolean)
	self.WipeEndsAt = 0
	self.Dependencies.RoundService:SetWipe(0, false)
	self.Wipe:Fire(false, 0)
	if cleared then
		self:FireLife(self.LastFallen, "WipeCleared")
	end
end

function VitalService:ExpireWipe()
	self:EvaluateWipe()
	if self.WipeEndsAt == 0 or now() < self.WipeEndsAt then
		return
	end
	-- LoseNight -> NightLost -> PhaseChanged closes the window; false (busy) retries on the next tick
	self.Dependencies.RoundService:LoseNight("wipe")
end

-- Shifts ------------------------------------------------------------------------------------------------------------

function VitalService:OnShiftStarted(info: { IsNight: boolean })
	if info.IsNight then
		self.NightSerial += 1
		self.Night = self.NightSerial
	else
		self.Night = 0
		-- a Down never outlives its night (the NightEnd path already did this)
		self:EndDowns()
	end
	for userId in self.Dependencies.RunStateService.Members() do
		self:EntryOf(userId)
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			self:Ensure(player)
			self:SendSanity(player, true)
		end
		self:RefreshBand(userId, true)
	end
	self:QueueWipe()
end

function VitalService:OnPhase(phase: string)
	if not isDarkPhase(phase) then
		self:StepHints(now(), true)
	end
	if phase == "NightEnd" then
		self:EndDowns()
	end
	self:QueueWipe()
end

-- Members -----------------------------------------------------------------------------------------------------------

-- First admission and return from Away: class values owed, record, look, packet.
function VitalService:OnJoined(player: Player)
	const entry = self:Ensure(player)
	entry.DarkSince = nil
	self:Publish(player.UserId)
	self:RefreshBand(player.UserId, true)
	self:ApplyLook(player.UserId)
	self:SendSanity(player, true)
	self:ResendHint(player)
	self:QueueWipe()
end

-- Tick ----------------------------------------------------------------------------------------------------------------

function VitalService:DarkTick(t: number)
	const round = self.Dependencies.RoundService
	const counts = round:IsNight() and isDarkPhase(round:GetPhase())
	const runState = self.Dependencies.RunStateService
	const characters = self.Dependencies.CharacterService
	for _, player in Players:GetPlayers() do
		if not runState:IsActive(player) then
			continue
		end
		const entry = self:Ensure(player)
		const character = characters:CharacterOf(player)
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not counts or entry.Max <= 0 or root == nil or not root:IsA("BasePart") or characters:IsFainted(player) then
			entry.DarkSince = nil
			continue
		end
		if self:IsLit(root.Position) then
			entry.DarkSince = nil
			continue
		end
		if entry.DarkSince == nil then
			entry.DarkSince = t
		end
		const loss = Sanity.darkLoss(entry.DarkSince, entry.ProtectUntil, t, Content.Sanity)
		if loss > 0 then
			self:AddSanity(player, -loss, "dark")
		end
	end
end

function VitalService:Step()
	const t = now()
	self:StepHints(t, false)
	if self.WipeEndsAt > 0 and t >= self.WipeEndsAt then
		self:ExpireWipe()
	end
	if t < self.NextDarkAt then
		return
	end
	self.NextDarkAt = t + DARK_STEP
	self:DarkTick(t)
	if Content.Sanity.BandMinHold > 0 then
		for userId, entry in self.Entries do
			if entry.Pending ~= nil then
				self:RefreshBand(userId, false)
			end
		end
	end
end

-- Coffee (architecture.md §19.8; FEAT-021) -------------------------------------------------------------------------

function VitalService:RestoreOf(player: Player, tool: Tool): number
	const value = tool:GetAttribute(RESTORE_ATTRIBUTE)
	if finite(value) then
		return math.clamp(math.floor(value :: number), 0, Sanity.WIRE_MAX)
	end
	return self.Dependencies.ClassService:GetModifier(player, "CoffeeRestore", Content.Sanity.Coffee)
end

-- Validate of the coffee use. Day (Q-170 A): toast, the Tool stays. No cooldown (TASK-328: the machine cleans after each
-- cup, Stations.coffee_machine.Params.CleanTime). A coffee that is already being drunk (Tool attribute `Drinking`)
-- cannot be used again.
function VitalService:CanDrink(player: Player, tool: Tool): (boolean, string?)
	const rows = Content.Sanity
	if tool:GetAttribute(Content.CoffeeCup.Sips.DrinkingAttribute) == true then
		return false, nil
	end
	const entry = self:Ensure(player)
	const night = self.Dependencies.RoundService:IsNight() and entry.Max > 0
	if rows.CoffeeNightOnly and not night then
		return false, "coffee_night_only"
	end
	if entry.Max <= 0 then
		return false, nil
	end
	if entry.Sanity >= entry.Max then
		return false, "coffee_full"
	end
	return true, nil
end

-- Run of the coffee use: ONE sip drinks the whole cup (Content.CoffeeCup.Sips, owner request 2026-10-12, Provisional).
-- It takes Sips.DrinkTime; the hand, the state and the rules are checked again at the end. The Restore applies once,
-- right then, with the Tool marked `Drinking` (no second use, the hand cup sinks on every client), and the Tool is
-- consumed Sips.EmptySeconds later. Never above the max (Sanity.restore through AddSanity's clamp).
function VitalService:Drink(player: Player, tool: Tool)
	const sips = Content.CoffeeCup.Sips
	task.wait(sips.DrinkTime)
	if player.Parent == nil or not self.Dependencies.RunStateService:IsActive(player) then
		return
	end
	if self.Dependencies.ItemService:GetHeld(player) ~= tool then
		return
	end
	const allowed = self:CanDrink(player, tool)
	if not allowed then
		return
	end
	const entry = self:Ensure(player)
	const restore = self:RestoreOf(player, tool)
	tool:SetAttribute(sips.DrinkingAttribute, true)
	const before = entry.Sanity
	const after = self:AddSanity(player, Sanity.restore(entry.Sanity, entry.Max, restore) - entry.Sanity, COFFEE)
	-- feedback for the owner (green glow + "+N" on the bar) and the end of the Night 1 emphasis
	self:SendCue(player, "Gain", math.max(0, after - before), 0)
	self:EndHint(player, entry)
	task.wait(sips.EmptySeconds)
	self.Dependencies.ItemService:Consume(player, tool)
	if tool.Parent ~= nil then
		tool:Destroy() -- handed to a mate during the sip: still gone
	end
end

-- Night 1 coffee lesson (user request 2026-10-11, Provisional) -----------------------------------------------------

-- Cue packet to the owner of the sanity (SanityCue; only when the client is ready)
function VitalService:SendCue(player: Player, kind: "Hint" | "Gain" | "End", amount: number, untilT: number)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or player.Parent == nil or not net:IsReady(player) then
		return
	end
	self.Libs.Net.SanityCue:fireClient(player, {
		Kind = kind,
		Amount = math.clamp(math.floor(amount + 0.5), 0, Sanity.WIRE_MAX),
		Until = untilT,
	})
end

function VitalService:EndHint(player: Player, entry: Entry)
	if entry.HintUntil > 0 then
		entry.HintUntil = 0
		self:SendCue(player, "End", 0, 0)
	end
end

-- Walt's coffee call (BossService cue CoffeeHint): every Active member with sanity to gain gets the emphasis of the
-- sanity bar and the coffee machine until the first coffee or Sanity.CoffeeHint s after the call ends (`callLeft` =
-- seconds of the call still to run). Server-authoritative: the clients only draw it. Returns how many players got it.
function VitalService:StartCoffeeHint(callLeft: number): number
	if not self.Enabled or not finite(callLeft) then
		return 0
	end
	const untilT = now() + math.max(0, callLeft) + Content.Sanity.CoffeeHint
	const vehicle = Content.Vehicles.ByKey[self.Dependencies.RoundService:CurrentVehicle()]
	const machine = vehicle ~= nil and vehicle.HasCoffee
	local count = 0
	for _, player in Players:GetPlayers() do
		if not self.Dependencies.RunStateService:IsActive(player) then
			continue
		end
		const entry = self:Ensure(player)
		if entry.Max <= 0 or entry.Sanity >= entry.Max then
			continue
		end
		entry.HintUntil = untilT
		self:SendCue(player, "Hint", 0, untilT)
		count += 1
		-- vehicle without a coffee machine (the cart): the lesson cup goes straight into the hand, no brewing
		if not machine then
			self.Dependencies.ItemService:Give(player, COFFEE, { Restore = Content.Sanity.Coffee, Silent = true })
		end
	end
	return count
end

-- A client that (re)joins while the emphasis runs gets it again
function VitalService:ResendHint(player: Player)
	const entry = self.Entries[player.UserId]
	if entry ~= nil and entry.HintUntil > now() then
		self:SendCue(player, "Hint", 0, entry.HintUntil)
	end
end

-- Timed end of the emphasis, and the end when the night is over (any phase but Call, Prep, Night)
function VitalService:StepHints(t: number, over: boolean)
	for userId, entry in self.Entries do
		if entry.HintUntil > 0 and (over or t >= entry.HintUntil) then
			const player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				self:EndHint(player, entry)
			else
				entry.HintUntil = 0
			end
		end
	end
end

-- Dev (Commands/Vital.luau) -----------------------------------------------------------------------------------------

function VitalService:DevSetSanity(player: Player, value: number): number
	if not self.Dependencies.RunStateService:IsActive(player) then
		error(`{player.Name} is not Active`, 0)
	end
	const entry = self:Ensure(player)
	if entry.Max <= 0 then
		error("no sanity by day", 0)
	end
	return self:AddSanity(player, Sanity.clamp(value, entry.Max) - entry.Sanity, "dev")
end

function VitalService:DevFall(player: Player, state: LifeState?)
	if not self.Dependencies.RunStateService:IsActive(player) then
		error(`{player.Name} is not Active`, 0)
	end
	const entry = self:Ensure(player)
	entry.Sanity = 0
	entry.LastCause = "dev"
	self:SendSanity(player, false)
	self:RefreshBand(player.UserId, true)
	self.DevFalling = true
	const ok, problem = pcall(function()
		self:Fall(player, state)
	end)
	self.DevFalling = false
	if not ok then
		error(problem, 0)
	end
end

-- Dev (TASK-332): infinite sanity for one player, on or off. On fills the sanity (Active at night). Returns the state.
function VitalService:DevInfiniteSanity(player: Player, on: boolean): boolean
	if not self.Dependencies.PlaceService:IsDev() then
		error("dev mode only", 0)
	end
	self.DevInfinite[player.UserId] = if on then true else nil
	player:SetAttribute(DEV_INFINITE, if on then true else nil)
	const entry = self:Ensure(player)
	if on and entry.Max > 0 and self.Dependencies.RunStateService:IsActive(player) then
		self:AddSanity(player, entry.Max - entry.Sanity, "dev")
	end
	return on
end

function VitalService:IsDevInfinite(player: Player): boolean
	return self.DevInfinite[player.UserId] == true
end

function VitalService:DevDark(mode: boolean?)
	self.DevLit = if mode == nil then nil else not mode
end

-- Showcase (ShowcaseService): no natural fall while on (sanity stops at 1).
function VitalService:DevGod(on: boolean)
	if not self.Dependencies.PlaceService:IsDev() then
		error("dev mode only", 2)
	end
	self.DevGodMode = on
end

function VitalService:IsDevGod(): boolean
	return self.DevGodMode
end

-- -1 forced dark, 1 forced lit, 0 = LightService (readout for the showcase panel)
function VitalService:DevDarkMode(): number
	if self.DevLit == nil then
		return 0
	end
	return if self.DevLit then 1 else -1
end

-- Stand-in for the wave 4 ReviveService (no ambulance in this build): a Down or Spectator member comes back Active
-- with half of the sanity, a new character at the normal spawn and the stash returned. A Down counts as a revive used.
function VitalService:DevRevive(player: Player): string
	if not self.Dependencies.PlaceService:IsDev() then
		error("dev mode only", 2)
	end
	const state = self:GetState(player.UserId)
	if state ~= "Down" and state ~= "Spectator" then
		error(`{player.Name} is {state or "not a member"}: only Down or Spectator can be revived`, 0)
	end
	if not self:Restore(player, state) then
		error("SetLifeState refused", 0)
	end
	const entry = self:Ensure(player)
	return `{player.Name} revived ({state} -> Active, sanity {entry.Sanity}/{entry.Max})`
end

-- Public revive (TASK-317; DEC-117, DEC-129, DEC-255): a Down member back Active, the same way as DevRevive. Only a Down
-- with revives left tonight (Content.Revive.MaxPerNight); a Spectator stays out. reviver: the mate who used the kit (nil or
-- the player = self). The caller pays (ReviveKitService spends the credit only when this returns true).
function VitalService:Revive(player: Player, reviver: Player?): boolean
	if not self.Enabled or self:GetState(player.UserId) ~= "Down" then
		return false
	end
	if reviver ~= nil and reviver ~= player and not self:IsActive(reviver) then
		return false
	end
	if self:Ensure(player).RevivesTonight >= Content.Revive.MaxPerNight then
		return false
	end
	-- only while the night is still playable: a revive in NightLost / RunEnd would burn the kit for nothing (TASK-330)
	const round = self.Dependencies.RoundService
	if not Flow.CanLose(round:GetPhase(), round:Info()) then
		return false
	end
	return self:Restore(player, "Down")
end

-- Core of every revive: half of the sanity, a Down counts as a revive used, new character at the normal spawn, stash
-- back once it can hold tools, LifeEvent Revived. False = RunStateService refused the state.
function VitalService:Restore(player: Player, state: LifeState): boolean
	const runState = self.Dependencies.RunStateService
	const entry = self:Ensure(player)
	if entry.Max > 0 then
		entry.Sanity = math.max(1, math.floor(entry.Max * 0.5 + 0.5))
	end
	if state == "Down" then
		entry.RevivesTonight += 1
	end
	entry.StateEndsAt = 0
	entry.KnockedUntil = 0
	if not runState:SetLifeState(player.UserId, "Active") then
		if state == "Down" then
			entry.RevivesTonight -= 1
		end
		return false
	end
	const characters = self.Dependencies.CharacterService
	characters:RemoveBody(player, true)
	task.spawn(function()
		const ok, problem = pcall(function()
			characters:Spawn(player)
		end)
		if not ok then
			warn(`[VitalService] Restore spawn: {problem}`)
			return
		end
		-- the character finishes loading after LoadCharacter returns: give the stash back once it can hold tools
		task.delay(1.5, function()
			if player.Parent ~= nil then
				pcall(function()
					self.Dependencies.ItemService:Unstash(player)
				end)
			end
		end)
	end)
	self:FireLife(player.UserId, "Revived")
	return true
end

-- Lifecycle -----------------------------------------------------------------------------------------------------------

VitalService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Higher-priority services ran their Setup before this OnInit (§19.0 rule 2).
	self.Dependencies.InteractionService:AddGate(GATE, function(player: Player): (boolean, string?)
		const member = self.Dependencies.RunStateService:GetMember(player)
		if member == nil then
			return false, "NotMember"
		end
		if member.State ~= "Active" then
			return false, member.State
		end
		if self:IsKnocked(player) then
			return false, "Knocked"
		end
		return true, nil
	end)

	self.Dependencies.ItemService:RegisterUse(COFFEE, {
		Validate = function(player: Player, tool: Tool): (boolean, string?)
			return self:CanDrink(player, tool)
		end,
		Run = function(player: Player, tool: Tool)
			self:Drink(player, tool)
		end,
	})

	const round = self.Dependencies.RoundService
	round:SetVerdict(function(): boolean
		return self:Verdict()
	end)
	round.ShiftStarted:Connect(function(info)
		self:OnShiftStarted(info)
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)

	const runState = self.Dependencies.RunStateService
	runState.MemberJoined:Connect(function(player)
		self:OnJoined(player)
	end)
	runState.LifeChanged:Connect(function(userId, old, new)
		self:OnLifeChanged(userId, old, new)
	end)

	self.Dependencies.NetService.ClientReady:Connect(function(player)
		if runState:IsMember(player) then
			self:SendSanity(player, true)
			self:ResendHint(player)
		end
	end)
	-- respawn: the packet again (network.md §6.1); CharacterService reapplies the LookPack it keeps per UserId
	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player)
		if runState:IsMember(player) then
			self:EntryOf(player.UserId).DarkSince = nil
			self:SendSanity(player, true)
		end
	end)
end)

VitalService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the records from the set.
	self.Live = true
	for userId in self.Dependencies.RunStateService.Members() do
		self:Publish(userId)
	end
	self:QueueWipe()
end)

VitalService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return VitalService
