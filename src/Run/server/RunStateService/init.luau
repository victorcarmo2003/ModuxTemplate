--!strict
-- Run root state: roster, members, PriceParty, chances, snapshot registry, notices (architecture.md §2.3, §3.1, §7;
-- data.md §2.1, §2.3, §3.3; network.md §3.2, §4.2; TASK-010). Run place only.
-- Wave 1 = dev roster (architecture.md §1): whoever joins becomes a member, up to the party size of the price table.
-- Snapshot lives in memory only (MemoryStore in wave 2). Single writer of the RunState set.
-- Hooks for other tasks: FixPriceParty() at the end of Day 1 and Capture()/Restore(mode) at the shift boundary are
-- called by RoundService (TASK-012); it requires this service, so this one never requires it (no cycle, T12).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Snapshots = require(script.Snapshots)
local Modux = require(ServerScriptService.server.Modux)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type RestoreMode = Snapshots.Mode
export type StashEntry = { Kind: string, Count: number, Extra: string? }

-- data.md §2.1. Owners of the other fields write them through this service later (Vital: State/Sanity,
-- Item: Stash); wave 1 only fills UserId, Class, State and EverJoined.
export type Member = {
	UserId: number,
	Class: string, -- key of Content.Classes, locked when the member is first admitted
	State: LifeState,
	StateBeforeAway: LifeState?,
	Sanity: number,
	Stash: { StashEntry },
	CoffeeReadyAt: number,
	SeenAnomalies: { [string]: boolean },
	RevivesTonight: number,
	EverJoined: boolean,
}

export type Target = Player | "all"

const RECORD = 1 -- RunState is a single record (network.md §3.2)
const MAX_PARTY = #Content.RunParams.PartyPriceMult -- 4 (DEC-047)
const NOTICE_MIN = -1000000 -- Notice.Value wire range (network.md §4.2)
const NOTICE_MAX = 1000000
const SEED_MAX = 2147483647

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

local function newMember(userId: number, class: string): Member
	return {
		UserId = userId,
		Class = class,
		State = "Active",
		StateBeforeAway = nil,
		Sanity = 0,
		Stash = {},
		CoffeeReadyAt = 0,
		SeenAnomalies = {},
		RevivesTonight = 0,
		EverJoined = true,
	}
end

-- Members are shared by reference through the atom: frozen so nobody edits one in place.
local function freeze(member: Member): Member
	table.freeze(member :: any)
	return member
end

local function isLifeState(value: any): boolean
	return value == "Active" or value == "Down" or value == "Reviving" or value == "Spectator" or value == "Away"
end

const RunStateService = Modux.Service(
	"RunStateService",
	{ Require = { "PlaceService", "PlayerService", "ProfileService", "NetService" }, Priority = 760 }
)

function RunStateService:Setup()
	self.RunId = (if game.PrivateServerId ~= "" then game.PrivateServerId else `dev-{game.JobId}`) :: string
	self.StartedAt = workspace:GetServerTimeNow() :: number
	self.Seed = self.Libs.Charm.atom(Random.new():NextInteger(1, SEED_MAX)) :: Charm.Atom<number>
	self.Roster = self.Libs.Charm.atom({}) :: Charm.Atom<{ number }>
	self.Members = self.Libs.Charm.atom({}) :: Charm.Atom<{ [number]: Member }>
	self.PriceParty = self.Libs.Charm.atom(0) :: Charm.Atom<number>
	self.Chances = self.Libs.Charm.atom(Content.RunParams.Chances) :: Charm.Atom<number>
	self.Endless = self.Libs.Charm.atom(false) :: Charm.Atom<boolean>
	self.Counters = self.Libs.Charm.atom({}) :: Charm.Atom<{ [string]: number }>
	self.Registry = Snapshots.new() :: Snapshots.Registry
	self.MemberJoined = self.Libs.Signal.new() :: SignalLib.Signal<Player, Member>
	self.MemberAway = self.Libs.Signal.new() :: SignalLib.Signal<Player, Member>
end

-- Members --------------------------------------------------------------------------------------------------------

function RunStateService:GetMember(player: Player): Member?
	return self.Members()[player.UserId]
end

function RunStateService:IsMember(player: Player): boolean
	return self.Members()[player.UserId] ~= nil
end

-- Member in the server and able to act (InteractionService, TASK-011).
function RunStateService:IsActive(player: Player): boolean
	const member = self.Members()[player.UserId]
	return member ~= nil and member.State == "Active"
end

-- Writes one member by copy (atoms hold immutable tables).
function RunStateService:SetMember(userId: number, member: Member)
	const members = table.clone(self.Members())
	members[userId] = freeze(member)
	self.Members(members)
end

-- Dev roster: the first MAX_PARTY players who join; nobody else becomes a member.
function RunStateService:Seat(userId: number): boolean
	const roster = self.Roster()
	if table.find(roster, userId) then
		return true
	end
	if #roster >= MAX_PARTY then
		return false
	end
	const nextRoster = table.clone(roster)
	table.insert(nextRoster, userId)
	self.Roster(table.freeze(nextRoster))
	return true
end

-- First admission locks the class (data.md §2.1); a returning member gets back the state it had (data.md §2.3).
function RunStateService:Admit(player: Player, class: string)
	const userId = player.UserId
	if not self:Seat(userId) then
		warn(`[RunStateService] {player.Name} joined a full run ({MAX_PARTY}); not a member`)
		return
	end

	const current = self.Members()[userId]
	local member: Member
	if current == nil then
		member = newMember(userId, class)
	else
		member = table.clone(current)
		if member.State == "Away" then
			member.State = member.StateBeforeAway or "Active"
		end
		member.StateBeforeAway = nil
	end
	self:SetMember(userId, member)
	self.MemberJoined:Fire(player, self.Members()[userId])
end

function RunStateService:Leave(player: Player)
	const current = self.Members()[player.UserId]
	if current == nil or current.State == "Away" then
		return
	end
	const member = table.clone(current)
	member.StateBeforeAway = member.State
	member.State = "Away"
	self:SetMember(player.UserId, member)
	self.MemberAway:Fire(player, self.Members()[player.UserId])
end

-- PriceParty = members that ever joined, fixed once at the end of Day 1 (DEC-121). Called by RoundService.
function RunStateService:FixPriceParty()
	if self.PriceParty() ~= 0 then
		return
	end
	local joined = 0
	for _, member in self.Members() do
		if member.EverJoined then
			joined += 1
		end
	end
	self.PriceParty(math.clamp(joined, 1, MAX_PARTY))
end

-- Notices ----------------------------------------------------------------------------------------------------------

-- Toast to one player or to the whole audience (network.md §4.2). Works on any place role.
function RunStateService:Notify(target: Target, key: string, value: number?)
	if Content.Notices.ByKey[key] == nil then
		fail(`[RunStateService] Notify: {key} is not a key of Content.Notices`)
		return
	end
	const net = self.Dependencies.NetService
	if not net:IsRunning() then
		return
	end

	local amount = value or 0
	if amount ~= amount then
		amount = 0
	end
	const packet = { Kind = key, Value = math.clamp(math.floor(amount), NOTICE_MIN, NOTICE_MAX) }

	if target == "all" then
		self.Libs.Net.Notice:fireClient(net.Audience, packet)
		return
	end
	if target.Parent == nil or not net:IsReady(target) then
		return
	end
	self.Libs.Net.Notice:fireClient(target, packet)
end

-- Snapshots --------------------------------------------------------------------------------------------------------

-- Each Service with run state registers in its OnInit (architecture.md §7, data.md §2.2 R13).
function RunStateService:RegisterSnapshot(name: string, capture: Snapshots.Capture, restore: Snapshots.Restore)
	Snapshots.register(self.Registry, name, capture, restore)
end

-- Start of the current shift (and run start / repeated night). Kept in memory in wave 1.
function RunStateService:Capture(): Snapshots.Snapshot
	return Snapshots.capture(self.Registry)
end

-- RepeatNight: lost night with chances left; Resume: everyone left or the server fell (architecture.md §7).
function RunStateService:Restore(mode: RestoreMode): boolean
	return Snapshots.restore(self.Registry, mode)
end

function RunStateService:LastSnapshot(): Snapshots.Snapshot?
	return self.Registry.Last
end

-- data.md §3.3 "Run": Chances are not restored on a repeated night (already spent, DEC-110/112).
function RunStateService:CaptureRun(): { [string]: any }
	return {
		Seed = self.Seed(),
		Roster = table.clone(self.Roster()),
		Pp = self.PriceParty(),
		Ch = self.Chances(),
		End = self.Endless(),
		Cnt = table.clone(self.Counters()),
	}
end

function RunStateService:RestoreRun(data: { [string]: any }, mode: RestoreMode)
	self.Libs.Charm.batch(function()
		if type(data.Seed) == "number" then
			self.Seed(data.Seed)
		end
		if type(data.Roster) == "table" then
			self.Roster(table.freeze(table.clone(data.Roster)))
		end
		if type(data.Pp) == "number" then
			self.PriceParty(data.Pp)
		end
		if mode == "Resume" and type(data.Ch) == "number" then
			self.Chances(data.Ch)
		end
		if type(data.End) == "boolean" then
			self.Endless(data.End)
		end
		if type(data.Cnt) == "table" then
			self.Counters(table.clone(data.Cnt))
		end
	end)
end

-- data.md §3.3 "M": C class, S life state, J EverJoined, T stash ({ Kind, Count, Extra? }). Away is a connection
-- state, not a life state: the state before leaving is what goes in.
function RunStateService:CaptureMembers(): { [string]: any }
	const out: { [string]: any } = {}
	for userId, member in self.Members() do
		const stash = {}
		for _, entry in member.Stash do
			table.insert(stash, if entry.Extra then { entry.Kind, entry.Count, entry.Extra } else { entry.Kind, entry.Count })
		end
		const state = if member.State == "Away" then member.StateBeforeAway or "Active" else member.State
		out[tostring(userId)] = { C = member.Class, S = state, J = member.EverJoined, T = stash }
	end
	return out
end

-- RepeatNight: everyone back Active (DEC-111, DEC-113); Resume: life state as captured. Members not in the server
-- stay Away with that state saved for their return.
function RunStateService:RestoreMembers(data: { [string]: any }, mode: RestoreMode)
	const members = table.clone(self.Members())
	for key, saved in data do
		const userId = tonumber(key)
		if userId == nil or type(saved) ~= "table" then
			continue
		end
		const class = if type(saved.C) == "string" and Content.Classes.ByKey[saved.C] then saved.C else nil
		const previous = members[userId]
		const member = if previous then table.clone(previous) else newMember(userId, class or "")
		if class then
			member.Class = class
		end
		member.EverJoined = saved.J == true or member.EverJoined
		member.Stash = {}
		if type(saved.T) == "table" then
			for _, item in saved.T do
				if type(item) == "table" and type(item[1]) == "string" and type(item[2]) == "number" then
					table.insert(member.Stash, { Kind = item[1], Count = item[2], Extra = item[3] })
				end
			end
		end
		const state: LifeState = if mode == "RepeatNight" or not isLifeState(saved.S) then "Active" else saved.S
		if member.State == "Away" then
			member.StateBeforeAway = state
		else
			member.State = state
		end
		members[userId] = freeze(member)
	end
	if mode == "RepeatNight" then
		for userId, member in members do
			if member.State ~= "Away" and member.State ~= "Active" then
				const copy = table.clone(member)
				copy.State = "Active"
				members[userId] = freeze(copy)
			elseif member.State == "Away" and member.StateBeforeAway ~= "Active" then
				const copy = table.clone(member)
				copy.StateBeforeAway = "Active"
				members[userId] = freeze(copy)
			end
		end
	end
	self.Members(members)
end

-- Network ----------------------------------------------------------------------------------------------------------

function RunStateService:Record(): { PriceParty: number, RosterSize: number, Endless: boolean }
	return {
		PriceParty = math.clamp(self.PriceParty(), 0, MAX_PARTY),
		RosterSize = math.clamp(#self.Roster(), 1, MAX_PARTY),
		Endless = self.Endless(),
	}
end

RunStateService:OnInit(function(self)
	-- Atoms only (no connection): RegisterSnapshot/Notify stay callable on any role.
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	self:RegisterSnapshot("Run", function()
		return self:CaptureRun()
	end, function(data, mode)
		self:RestoreRun(data, mode)
	end)
	self:RegisterSnapshot("M", function()
		return self:CaptureMembers()
	end, function(data, mode)
		self:RestoreMembers(data, mode)
	end)

	const profiles = self.Dependencies.ProfileService
	profiles.Loaded:Connect(function(player, profile)
		self:Admit(player, profiles:SelectedClass(profile))
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Leave(player)
	end)
end)

RunStateService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	-- Lync.start already ran (NetService OnStart, priority 1000).
	self.Libs.Net.RunState:add(RECORD, self:Record())
	self.Libs.Charm.effect(function()
		const record = self:Record()
		if self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.RunState:update(RECORD, record)
		end
	end)
end)

return RunStateService
