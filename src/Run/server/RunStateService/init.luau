--!strict
-- Run root state: roster, members, PriceParty, chances, snapshot registry, notices (architecture.md §2.3, §3.1, §7;
-- data.md §2.1, §2.3, §3.3; network.md §3.2, §4.2; TASK-010). Run place only.
-- Wave 1 = dev roster (architecture.md §1): whoever joins becomes a member, up to the party size of the price table.
-- Snapshot lives in memory only (MemoryStore in wave 2). Single writer of the RunState set.
-- Hooks for other tasks: FixPriceParty() at the end of Day 1 and Capture()/Restore(mode) at the shift boundary are
-- called by RoundService (TASK-012); it requires this service, so this one never requires it (no cycle, T12).
-- Wave 2 (A3; architecture.md §19.3, §19.26; data.md §5.2, §5.3; TASK-052): SetLifeState (VitalService only),
-- SetStash (ItemService only), SpendChance, SetEndless, ResetDev (T56) and the LifeChanged signal. Tools left the
-- "M" snapshot: ItemService captures them under its own "T" key (T50).
local Players = game:GetService("Players")
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

-- data.md §5.2. Class is locked on first admission (DEC-069); State is written by VitalService through SetLifeState;
-- Stash (only while out of the server or Down) by ItemService through SetStash; EverJoined feeds PriceParty (DEC-121).
-- Sanity, coffee cooldown, revives and seen anomalies are kept by their owner per UserId (data.md §5.2).
export type Member = {
	UserId: number,
	Class: string,
	State: LifeState,
	StateBeforeAway: LifeState?,
	Stash: { StashEntry },
	EverJoined: boolean,
}

export type Target = Player | "all"

const RECORD = 1 -- RunState is a single record (network.md §3.2)
const MAX_PARTY = #Content.RunParams.PartyPriceMult -- 4 (DEC-047)
const NOTICE_MIN = -1000000 -- Notice.Value wire range (network.md §4.2)
const NOTICE_MAX = 1000000
const SEED_MAX = 2147483647
const STASH_MAX_ENTRIES = 32 -- far above any hotbar; guards a runaway caller
const STASH_MAX_COUNT = 999

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
		Stash = table.freeze({} :: { StashEntry }),
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

-- Copies and checks stash entries (Kind of Content.Items, whole Count >= 1, Extra string). Nil when any entry is bad.
local function cleanStash(entries: any): { StashEntry }?
	if type(entries) ~= "table" or #entries > STASH_MAX_ENTRIES then
		return nil
	end
	const out: { StashEntry } = {}
	for _, entry in entries do
		if type(entry) ~= "table" then
			return nil
		end
		const kind, count, extra = entry.Kind, entry.Count, entry.Extra
		if type(kind) ~= "string" or Content.Items.ByKey[kind] == nil then
			return nil
		end
		if type(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > STASH_MAX_COUNT then
			return nil
		end
		if extra ~= nil and type(extra) ~= "string" then
			return nil
		end
		const clean: StashEntry = { Kind = kind, Count = count, Extra = extra }
		table.freeze(clean :: any)
		table.insert(out, clean)
	end
	table.freeze(out :: any)
	return out
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
	self.LifeChanged = self.Libs.Signal.new() :: SignalLib.Signal<number, LifeState, LifeState>
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

-- LifeChanged(userId, old, new) for every member whose State differs between two member maps (a new member counts
-- from Active, so admission fires nothing).
function RunStateService:EmitLifeChanges(before: { [number]: Member }, after: { [number]: Member })
	for userId, member in after do
		const previous = before[userId]
		const old: LifeState = if previous then previous.State else "Active"
		if old ~= member.State then
			self.LifeChanged:Fire(userId, old, member.State)
		end
	end
end

-- Writes one member by copy (atoms hold immutable tables).
function RunStateService:SetMember(userId: number, member: Member)
	const before = self.Members()
	const members = table.clone(before)
	members[userId] = freeze(member)
	self.Members(members)
	self:EmitLifeChanges(before, members)
end

-- Life state of a member (VitalService only; data.md §5.2). Away is a connection state owned by Admit/Leave: a member
-- who is Away keeps the new state for the return. False when the user is not a member or the state is not writable.
function RunStateService:SetLifeState(userId: number, state: LifeState): boolean
	const current = self.Members()[userId]
	if current == nil then
		return false
	end
	if not isLifeState(state) or state == "Away" then
		fail(`[RunStateService] SetLifeState: {state} is not a life state VitalService can write`)
		return false
	end
	const member = table.clone(current)
	if member.State == "Away" then
		if member.StateBeforeAway == state then
			return true
		end
		member.StateBeforeAway = state
	else
		if member.State == state then
			return true
		end
		member.State = state
	end
	self:SetMember(userId, member)
	return true
end

-- Stash of a member (ItemService only; data.md §5.2). The list replaces the previous one; an empty list clears it.
function RunStateService:SetStash(userId: number, entries: { StashEntry }): boolean
	const current = self.Members()[userId]
	if current == nil then
		return false
	end
	const stash = cleanStash(entries)
	if stash == nil then
		fail(`[RunStateService] SetStash: bad stash for {userId}`)
		return false
	end
	const member = table.clone(current)
	member.Stash = stash
	self:SetMember(userId, member)
	return true
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

-- Run ------------------------------------------------------------------------------------------------------------

-- End of a lost night (architecture.md §19.4): true = one chance spent (the night repeats); false = none left (run
-- ends). Chances never come back on RepeatNight (DEC-110, DEC-112).
function RunStateService:SpendChance(): boolean
	const left = self.Chances()
	if left <= 0 then
		return false
	end
	self.Chances(left - 1)
	return true
end

-- Endless mode (DEC-084), decided by RoundService at each shift boundary.
function RunStateService:SetEndless(on: boolean)
	self.Endless(on == true)
end

-- Dev RunEnd (waves 2-3, T56): back to the first capture of the run in Resume mode, with every chance back. The dev
-- roster keeps whoever joined after that capture (appended in join order) and every member comes back Active.
-- False when nothing was captured yet.
function RunStateService:ResetDev(): boolean
	const roster = self.Roster()
	if not Snapshots.rewind(self.Registry, "Resume") then
		return false
	end

	const before = self.Members()
	const members = table.clone(before)
	for userId, member in members do
		if member.State ~= "Active" and member.State ~= "Away" then
			const copy = table.clone(member)
			copy.State = "Active"
			members[userId] = freeze(copy)
		elseif member.State == "Away" and member.StateBeforeAway ~= "Active" then
			const copy = table.clone(member)
			copy.StateBeforeAway = "Active"
			members[userId] = freeze(copy)
		end
	end

	const nextRoster = table.clone(self.Roster())
	for _, userId in roster do
		if not table.find(nextRoster, userId) and #nextRoster < MAX_PARTY then
			table.insert(nextRoster, userId)
		end
	end

	self.Libs.Charm.batch(function()
		self.Roster(table.freeze(nextRoster))
		self.Members(members)
		self.Chances(Content.RunParams.Chances)
	end)
	self:EmitLifeChanges(before, members)
	return true
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

-- Resume boot (SessionService, DEC-080; architecture.md §5.5 step 3): the snapshot read from Snap[RunId] becomes the last
-- capture; Restore("Resume") then puts it back. False when the format is unknown.
function RunStateService:Load(snapshot: any): boolean
	return Snapshots.load(self.Registry, snapshot)
end

-- data.md §5.3 "Run": Chances are not restored on a repeated night (already spent, DEC-110/112).
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

-- data.md §5.3 "M": C class, S life state, J EverJoined (Tools are ItemService's own "T" key, T50). Away is a
-- connection state, not a life state: the state before leaving is what goes in.
function RunStateService:CaptureMembers(): { [string]: any }
	const out: { [string]: any } = {}
	for userId, member in self.Members() do
		const state = if member.State == "Away" then member.StateBeforeAway or "Active" else member.State
		out[tostring(userId)] = { C = member.Class, S = state, J = member.EverJoined }
	end
	return out
end

-- RepeatNight: everyone back Active (DEC-111, DEC-113); Resume: life state as captured. Members not in the server
-- stay Away with that state saved for their return. The stash is left as is: ItemService restores "T" after this.
function RunStateService:RestoreMembers(data: { [string]: any }, mode: RestoreMode)
	const before = self.Members()
	const members = table.clone(before)
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
		const state: LifeState = if mode == "RepeatNight" or not isLifeState(saved.S) then "Active" else saved.S
		-- a resumed run on a fresh server (DEC-080): who is not back yet is Away, their state kept for the return (Admit)
		if previous == nil and Players:GetPlayerByUserId(userId) == nil then
			member.State = "Away"
		end
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
	self:EmitLifeChanges(before, members)
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
