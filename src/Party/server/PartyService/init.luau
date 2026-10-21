--!strict
-- Squad (party) in the lobby (architecture.md §20.2, §20.6; network.md §16; user request 2026-10-11, Provisional;
-- TASK-155). Lobby roles only (Lobby, PrivateLobby): elsewhere every squad packet answers PartyNotice "WrongServer".
-- Single writer of the Party set (record = PartyId). Responders for PartyCreate/Invite/Respond/Leave/Kick/Start/
-- Configure/Cancel/QuickPlay.
--
-- Rules (Provisional): up to PartyRules.Rules.MaxSize (4, DEC-012) members, and never more than the squad's
-- MaxPlayers; the creator leads; only the leader invites, kicks, configures and starts; inviting without a squad
-- creates one; accepting an invite leaves the current squad; leader leaves = first member left leads. Simple pad
-- (DEC-344, TASK-618): no ready step and no room setup step: being in the squad is being in, and the leader starts
-- with whoever is there, alone included.
--
-- Squad platforms (user request 2026-10-11, emends DEC-179 back to physical platforms, invites kept): the 4 lobby
-- platforms (Content.Lobby.Zones with Platform 1..4; shape and place = the floor Part tagged LobbyZone with
-- Zone = "Squad<n>", same source as the client) are watched here every
-- Content.Lobby.Squad.Poll s from each HumanoidRootPart (shared.Lobby.LobbyZones, with hysteresis). Stepping on a free
-- platform = a new squad with Platform n, State "Configuring" and Access "Friends" that you lead, ready to START at
-- once (the leader of an invite squad takes the platform with the squad instead). Stepping on an owned platform =
-- joining it when it is not Starting, has room (MaxPlayers) and Access: "Open" any, "Friends" friends of the leader
-- (Player:IsFriendsWith, run aside: it yields), "Invite" or "Closed" nobody by pad. The leader changes Access and
-- MaxPlayers behind the gear (PartyConfigure). Stepping off (or dying) = leaving the squad. A refused player (full,
-- friends only, starting, left or kicked by hand) is not tried again until they step off.
--
-- Start (every squad): State "Starting" + StartAt = server time of the teleport, Rules.Countdown s later (members may
-- still step off meanwhile); at 0: ReserveServer -> TeleportAsync(game.PlaceId, members, ReservedServerAccessCode +
-- TeleportData { Role = "Game", PartyId, Members, Leader }). Reserve or teleport failing retries after 2/5/10 s
-- (PartyRules.Rules.TeleportRetries); all failing = back to the idle state + "TeleportFailed". A member whose own
-- teleport fails later (TeleportInitFailed) retries alone with the same options (same server). Studio cannot teleport:
-- the countdown runs, then "StudioNoTeleport" and back to the idle state.
-- Quick play (the lobby Play button, user request 2026-10-11, Provisional; network.md §16.7): PartyQuickPlay outside a
-- squad creates an invite squad (Platform 0) led by the sender. Mode "Solo" = a squad of one (MaxPlayers 1) started at
-- once (same countdown and teleport as Start); when it comes back to the idle state (Studio, every teleport failing)
-- it is disbanded, so Play offers the choice again. Mode "Squad" = a friends-only invite squad ("Forming") to invite
-- into; its leader may still take it to a free platform.
-- Cancel (PartyCancel, user request 2026-10-12): the leader aborts the countdown until Rules.CancelCutoff s before the
-- teleport (Token invalidates the pending Fire; Launched / late = "CancelTooLate"); idle state again, solo squad gone.
-- Pad room (owner request 2026-10-21, Provisional; emends DEC-344): stepping on a free pad creates the room (Access
-- "Open") already "Starting", with Rules.PadCountdown s on the clock. Others step on and join while it counts down
-- (until Rules.JoinCutoff s before the teleport); stepping off leaves, the last one out ends it. The pad bar (PartyPad):
-- StartNow (leader) drops the clock to Rules.StartNow s, SkipTutorial (each member) rides TeleportData SkipTutorial
-- so the run closes that member's tutorial, FriendsOnly (leader) switches Access Friends / Open. No cancel on a pad: a
-- failed or Studio teleport ends the room, and whoever still stands there starts a fresh one.
-- Pad barrier (owner request 2026-10-21, Provisional; DEC-348 emends DEC-344 (d); Barrier.luau): a room's pad gets an
-- invisible ring. Its members on the pad cannot step or jump off (a member seen past it is put back): the way out is
-- Exit (PartyLeave), which puts them down outside the ring. Outsiders walk in while the room is Open; Friends only lets
-- the leader's friends through (IsFriendsWith, cached per pair, run aside), Invite / Closed nobody. A non-member left
-- inside a ring that now stops them (the leader switched Friends only) is put outside.
-- Server never trusts the client: membership, leadership, state, size, presence of the target, friendship and rate
-- are checked here; TeleportData is written only by this service.
-- Tracked (analytics, owner request 2026-10-17; MetricsService listens): (kind, party, userId, detail) at Created,
-- Configured (the room exists: right after Created, detail = its Access), Joined (detail "pad" | "invite"), Left, Disbanded and Fired (the countdown ended: the
-- teleport begins, Studio included). Only read by the metrics.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Content = require(ReplicatedStorage.shared.Content)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local Teleport = require(script.Teleport)
local Barrier = require(script.Barrier)
local Modux = require(ServerScriptService.server.Modux)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type State = "Forming" | "Configuring" | "Starting"
export type Party = {
	Id: number,
	Leader: number,
	Members: { number }, -- party order, leader first after any change of leader
	State: State,
	Platform: number, -- 1..8 = owns LOBBY-SQUAD-n; 0 = invite squad
	Access: string, -- PartyRules.Access: "Open" | "Friends" | "Invite" | "Closed"
	MaxPlayers: number, -- 1..Rules.MaxSize, never below #Members when set
	StartAt: number, -- workspace:GetServerTimeNow() of the teleport; 0 = no countdown
	Launched: boolean, -- countdown over: reserve / teleport running
	Solo: boolean, -- quick play "Solo": disbanded instead of going back to the idle state
	Token: number, -- bumped by every Begin and Cancel: a countdown thread only fires for the token it was born with
	Skip: { [number]: boolean }, -- members who skip the run's tutorial (pad bar)
}
type Invite = { From: number, ExpiresAt: number }
type Flight = { Options: TeleportOptions, Tries: number, PartyId: number }
type Record = {
	Leader: number,
	Members: { number },
	State: State,
	Platform: number,
	Access: string,
	MaxPlayers: number,
	StartAt: number,
	Skip: { [number]: boolean },
}

const RULES = PartyRules.Rules
const WATCHDOG = 45 -- s a squad may stay "Starting" (after the countdown) with members still in the lobby
const BARRIER = Content.Lobby.Squad.Barrier
const TRIGGER = Content.Lobby.Trigger

-- Not starting: members may join, leave, be kicked; the leader may configure and start.
local function isOpen(party: Party): boolean
	return party.State ~= "Starting"
end

local function idleState(party: Party): State
	return if party.Platform > 0 then "Configuring" else "Forming"
end

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value >= 1 and value % 1 == 0 and value < 2 ^ 53
end

const PartyService = Modux.Service(
	"PartyService",
	{ Require = { "RoleService", "PlayerService", "NetService", "SessionService" }, Priority = 680 }
)

function PartyService:Setup()
	self.Active = false :: boolean
	self.Parties = {} :: { [number]: Party }
	-- UserId -> PartyId
	self.PartyOf = {} :: { [number]: number }
	-- invited UserId -> PartyId -> invite
	self.Invites = {} :: { [number]: { [number]: Invite } }
	-- "PartyId:UserId" -> os.clock() of the last invite
	self.LastInvite = {} :: { [string]: number }
	self.LastId = 0 :: number
	self.RateStart = {} :: { [Player]: number }
	self.RateCount = {} :: { [Player]: number }
	-- UserId -> squad teleport accepted by Roblox, not arrived yet
	self.InFlight = {} :: { [number]: Flight }
	-- UserId -> platform the player stands on (hysteresis applied)
	self.OnPlatform = {} :: { [number]: number }
	-- UserId -> platform that refused them (or that they left by hand) until they step off
	self.Refused = {} :: { [number]: number }
	-- UserId -> friends-only check in flight
	self.Checking = {} :: { [number]: boolean }
	-- UserId -> PartyId whose teleport has begun (countdown over); any other platform is ignored for them until the
	-- squad is back to the idle state or their own teleport gives up (owner request 2026-10-17)
	self.Teleporting = {} :: { [number]: number }
	-- UserId -> leader UserId -> friends (pad barrier of a friends-only room); missing = not asked yet
	self.Friendship = {} :: { [number]: { [number]: boolean } }
	-- "UserId:leader" -> IsFriendsWith in flight
	self.Asking = {} :: { [string]: boolean }
	self.PollAt = 0 :: number
	self.Tracked = self.Libs.Signal.new() :: SignalLib.Signal<string, Party, number, string>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function PartyService:Get(partyId: number): Party?
	return self.Parties[partyId]
end

function PartyService:PartyOfUser(userId: number): Party?
	const id = self.PartyOf[userId]
	return if id ~= nil then self.Parties[id] else nil
end

function PartyService:PlayersOf(party: Party): { Player }
	const out: { Player } = {}
	for _, userId in party.Members do
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil and player.Parent ~= nil then
			table.insert(out, player)
		end
	end
	return out
end

function PartyService:PartyOnPlatform(platform: number): Party?
	for _, party in self.Parties do
		if party.Platform == platform then
			return party
		end
	end
	return nil
end

-- Network ----------------------------------------------------------------------------------------------------------

function PartyService:Allow(player: Player): boolean
	const now = os.clock()
	const start = self.RateStart[player]
	if start == nil or now - start >= RULES.RateWindow then
		self.RateStart[player] = now
		self.RateCount[player] = 1
		return true
	end
	const count = (self.RateCount[player] or 0) + 1
	self.RateCount[player] = count
	if count > RULES.RateMax then
		if count == RULES.RateMax + 1 then
			self:Notice(player, "TooFast", nil)
		end
		return false
	end
	return true
end

function PartyService:Notice(target: Player | number, key: string, userId: number?)
	if not PartyRules.IsNoticeKey[key] then
		warn(`[PartyService] Notice: {key} is not a PartyRules notice key`)
		return
	end
	local player: Player? = nil
	if type(target) == "number" then
		player = Players:GetPlayerByUserId(target)
	else
		player = target
	end
	const net = self.Dependencies.NetService
	if player == nil or player.Parent == nil or not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.PartyNotice:fireClient(player, { Key = key, UserId = userId })
end

function PartyService:NoticeParty(party: Party, key: string, userId: number?)
	for _, member in party.Members do
		self:Notice(member, key, userId)
	end
end

-- Party set record (copies: Lync keeps what it is given)
local function record(party: Party): Record
	return {
		Leader = party.Leader,
		Members = table.clone(party.Members),
		State = party.State,
		Platform = party.Platform,
		Access = party.Access,
		MaxPlayers = party.MaxPlayers,
		StartAt = party.StartAt,
		Skip = table.clone(party.Skip),
	}
end

function PartyService:Publish(party: Party, added: boolean)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	if added then
		self.Libs.Net.Party:add(party.Id, record(party))
	else
		self.Libs.Net.Party:update(party.Id, record(party))
	end
end

-- Squad lifecycle --------------------------------------------------------------------------------------------------

function PartyService:NewId(): number
	for _ = 1, RULES.PartyIdMax do
		self.LastId = self.LastId % RULES.PartyIdMax + 1
		if self.Parties[self.LastId] == nil then
			return self.LastId
		end
	end
	error("[PartyService] no free PartyId", 0)
end

-- platform 0 = invite squad ("Forming"); 1..8 = platform squad ("Configuring")
function PartyService:Create(leader: number, platform: number, access: string): Party?
	if self.PartyOf[leader] ~= nil then
		return nil
	end
	const party: Party = {
		Id = self:NewId(),
		Leader = leader,
		Members = { leader },
		State = if platform > 0 then "Configuring" else "Forming",
		Platform = platform,
		Access = access,
		MaxPlayers = math.clamp(RULES.DefaultMaxPlayers, 1, RULES.MaxSize),
		StartAt = 0,
		Launched = false,
		Solo = false,
		Token = 0,
		Skip = {},
	}
	self.Parties[party.Id] = party
	self.PartyOf[leader] = party.Id
	self:Publish(party, true)
	self.Tracked:Fire("Created", party, leader, "")
	self.Tracked:Fire("Configured", party, leader, access)
	return party
end

function PartyService:Disband(party: Party)
	if self.Parties[party.Id] ~= party then
		return
	end
	self.Parties[party.Id] = nil
	self.Tracked:Fire("Disbanded", party, party.Leader, "")
	if party.Platform > 0 then
		-- the platform is free again: whoever stands on it is tried again
		for userId, platform in self.Refused do
			if platform == party.Platform then
				self.Refused[userId] = nil
			end
		end
	end
	for _, userId in party.Members do
		if self.PartyOf[userId] == party.Id then
			self.PartyOf[userId] = nil
		end
	end
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Party:remove(party.Id)
	end
end

-- Takes a member out (leave, kick, left the server, stepped off, left behind by a failed teleport). Empty squad = gone.
function PartyService:RemoveMember(userId: number, kicked: boolean)
	const party = self:PartyOfUser(userId)
	self.PartyOf[userId] = nil
	if party == nil then
		return
	end
	const index = table.find(party.Members, userId)
	if index ~= nil then
		table.remove(party.Members, index)
	end
	party.Skip[userId] = nil
	self.Tracked:Fire("Left", party, userId, if kicked then "kicked" else "")
	if kicked then
		self:Notice(userId, "Kicked", nil)
	end
	if #party.Members == 0 then
		self:Disband(party)
		return
	end
	self:NoticeParty(party, "Left", userId)
	if party.Leader == userId then
		party.Leader = party.Members[1]
		self:NoticeParty(party, "NewLeader", party.Leader)
	end
	self:Publish(party, false)
end

function PartyService:Join(party: Party, userId: number)
	table.insert(party.Members, userId)
	self.PartyOf[userId] = party.Id
	self:Publish(party, false)
	self:NoticeParty(party, "Joined", userId)
	self.Tracked:Fire(
		"Joined",
		party,
		userId,
		if party.Platform > 0 and self.OnPlatform[userId] == party.Platform then "pad" else "invite"
	)
end

-- Leaves by hand (packet, accepted invite): standing on the squad's platform does not pull them back in.
function PartyService:Leave(userId: number)
	const party = self:PartyOfUser(userId)
	if party ~= nil and party.Platform > 0 and self.OnPlatform[userId] == party.Platform then
		self.Refused[userId] = party.Platform
	end
	self:RemoveMember(userId, false)
end

-- Requests (already rate limited and role checked) -----------------------------------------------------------------

function PartyService:HandleCreate(player: Player)
	if self.PartyOf[player.UserId] ~= nil then
		self:Notice(player, "AlreadyInParty", nil)
		return
	end
	if self:Create(player.UserId, 0, "Invite") ~= nil then
		self:Notice(player, "Created", nil)
	end
end

function PartyService:HandleInvite(player: Player, target: number)
	const from = player.UserId
	if target == from then
		self:Notice(player, "InviteSelf", nil)
		return
	end
	const invited = if isUserId(target) then Players:GetPlayerByUserId(target) else nil
	if invited == nil then
		self:Notice(player, "PlayerNotFound", nil)
		return
	end

	local found = self:PartyOfUser(from)
	if found == nil then
		found = self:Create(from, 0, "Invite")
		if found ~= nil then
			self:Notice(player, "Created", nil)
		end
	end
	if found == nil then
		return
	end
	const party: Party = found
	if party.Leader ~= from then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if not isOpen(party) then
		self:Notice(player, "Busy", nil)
		return
	end
	if party.Access == "Closed" then
		self:Notice(player, "RoomClosed", nil)
		return
	end
	if table.find(party.Members, target) ~= nil then
		self:Notice(player, "AlreadyInParty", target)
		return
	end
	if #party.Members >= party.MaxPlayers then
		self:Notice(player, "PartyFull", nil)
		return
	end
	const now = os.clock()
	const key = `{party.Id}:{target}`
	const last = self.LastInvite[key]
	if last ~= nil and now - last < RULES.InviteCooldown then
		self:Notice(player, "TooFast", nil)
		return
	end
	self.LastInvite[key] = now

	const bucket = self.Invites[target] or {}
	bucket[party.Id] = { From = from, ExpiresAt = now + RULES.InviteTtl }
	self.Invites[target] = bucket

	const net = self.Dependencies.NetService
	if net:IsRunning() and net:IsReady(invited) then
		self.Libs.Net.PartyInviteReceived:fireClient(invited, { From = from, PartyId = party.Id })
	end
	self:Notice(player, "InviteSent", target)
end

function PartyService:HandleRespond(player: Player, partyId: number, accept: boolean)
	const userId = player.UserId
	const bucket = self.Invites[userId]
	const invite = if bucket ~= nil then bucket[partyId] else nil
	if bucket ~= nil then
		bucket[partyId] = nil
	end
	const party = self.Parties[partyId]
	if
		invite == nil
		or os.clock() > invite.ExpiresAt
		or party == nil
		or not isOpen(party)
		or party.Access == "Closed"
	then
		self:Notice(player, "InviteExpired", nil)
		return
	end
	if not accept then
		self:Notice(party.Leader, "InviteDeclined", userId)
		return
	end
	if table.find(party.Members, userId) ~= nil then
		return
	end
	if #party.Members >= party.MaxPlayers then
		self:Notice(player, "PartyFull", nil)
		return
	end
	const current = self:PartyOfUser(userId)
	if current ~= nil then
		if not isOpen(current) then
			self:Notice(player, "Busy", nil)
			return
		end
		self:Leave(userId)
	end
	self:Join(party, userId)
end

function PartyService:HandleLeave(player: Player)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	const platform = party.Platform
	const standing = platform > 0 and self.OnPlatform[player.UserId] == platform
	self:Leave(player.UserId)
	if standing then
		-- Exit (DEC-348): out of the ring, on the lobby side
		Barrier.Assign(player, Barrier.Base)
		const outside = Barrier.Outside(platform)
		const zone = LobbyZones.Platform(platform)
		if outside ~= nil and zone ~= nil then
			Barrier.Place(player, outside, zone.Center)
		end
	end
end

function PartyService:HandleKick(player: Player, target: number)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.Leader ~= player.UserId then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if not isOpen(party) then
		self:Notice(player, "Busy", nil)
		return
	end
	if target == player.UserId or table.find(party.Members, target) == nil then
		self:Notice(player, "PlayerNotFound", nil)
		return
	end
	if party.Platform > 0 and self.OnPlatform[target] == party.Platform then
		self.Refused[target] = party.Platform
	end
	self:RemoveMember(target, true)
end

function PartyService:HandleConfigure(player: Player, requested: string, maxPlayers: number)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.Leader ~= player.UserId then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if not isOpen(party) then
		self:Notice(player, "Busy", nil)
		return
	end
	const max = math.clamp(math.floor(maxPlayers), math.max(#party.Members, 1), RULES.MaxSize)
	const access = if PartyRules.IsAccess[requested] then requested else party.Access
	if party.Access == access and party.MaxPlayers == max then
		return
	end
	party.Access = access
	party.MaxPlayers = max
	self:Publish(party, false)
	for _, userId in party.Members do
		if userId ~= party.Leader then
			self:Notice(userId, "Configured", nil)
		end
	end
end

function PartyService:HandleStart(player: Player)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.Leader ~= player.UserId then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if not isOpen(party) then
		if party.Platform > 0 then
			self:StartNow(party) -- a pad room already counts down: START = start now
			return
		end
		self:Notice(player, "Busy", nil)
		return
	end
	self:Begin(party, RULES.Countdown, true)
end

-- Countdown of `seconds`, then Fire (checks already done by the caller). `notify` = the "Starting" notice.
function PartyService:Begin(party: Party, seconds: number, notify: boolean)
	party.State = "Starting"
	party.StartAt = workspace:GetServerTimeNow() + seconds
	party.Token += 1
	const token = party.Token
	self:Publish(party, false)
	if notify then
		self:NoticeParty(party, "Starting", nil)
	end
	task.delay(seconds, function()
		if party.Token == token then
			self:Fire(party)
		end
	end)
end

-- START NOW: the clock of a starting room drops to Rules.StartNow s (a shorter one is kept).
function PartyService:StartNow(party: Party)
	if party.State ~= "Starting" or party.Launched then
		return
	end
	if party.StartAt - workspace:GetServerTimeNow() <= RULES.StartNow then
		return
	end
	self:Begin(party, RULES.StartNow, true)
end

-- The pad bar (PartyPad; owner request 2026-10-21, Provisional).
function PartyService:HandlePad(player: Player, action: string, on: boolean)
	const userId = player.UserId
	const party = self:PartyOfUser(userId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.Launched then
		self:Notice(player, "Busy", nil)
		return
	end
	if action == "SkipTutorial" then
		if (party.Skip[userId] == true) ~= on then
			party.Skip[userId] = if on then true else nil
			self:Publish(party, false)
		end
		return
	end
	if party.Leader ~= userId then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if action == "StartNow" then
		if party.State == "Starting" then
			self:StartNow(party)
		else
			self:Begin(party, RULES.StartNow, true)
		end
	elseif action == "FriendsOnly" then
		const access = if on then "Friends" else "Open"
		if party.Access ~= access then
			party.Access = access
			self:Publish(party, false)
			self.Tracked:Fire("Configured", party, userId, access)
		end
	end
end

-- Leader aborts the countdown (user request 2026-10-12, Provisional; network.md §16.8). Allowed only while the squad is
-- "Starting", not launched, and before StartAt - CancelCutoff, so it never races the reserve / TeleportAsync call.
function PartyService:HandleCancel(player: Player)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.Leader ~= player.UserId then
		self:Notice(player, "NotLeader", nil)
		return
	end
	if party.State ~= "Starting" or party.Platform > 0 then
		return -- idempotent: already cancelled (or never started); a pad room has no cancel (step off to leave)
	end
	if party.Launched or workspace:GetServerTimeNow() >= party.StartAt - RULES.CancelCutoff then
		self:Notice(player, "CancelTooLate", nil)
		return
	end
	party.Token += 1 -- the countdown thread of this Begin does nothing now
	party.StartAt = 0
	if party.Solo then
		self:Disband(party) -- a solo quick play is not a squad to keep: Play offers the choice again
		return
	end
	party.State = idleState(party)
	self:Publish(party, false)
	for _, userId in party.Members do
		if userId ~= party.Leader then
			self:Notice(userId, "StartCancelled", party.Leader)
		end
	end
end

-- Play button outside a squad: "Solo" = a squad of one started now; "Squad" = an open invite squad to set up.
function PartyService:HandleQuickPlay(player: Player, mode: string)
	const userId = player.UserId
	if self.PartyOf[userId] ~= nil then
		self:Notice(player, "AlreadyInParty", nil)
		return
	end
	-- Solo: a squad of one, closed; Squad: friends only, like a new pad room (DEC-344)
	const party = self:Create(userId, 0, if mode == "Solo" then "Closed" else "Friends")
	if party == nil then
		return
	end
	if mode == "Solo" then
		party.Solo = true
		party.MaxPlayers = 1
		self:Begin(party, RULES.Countdown, true)
	else
		self:Notice(player, "Created", nil)
	end
end

-- Teleport ---------------------------------------------------------------------------------------------------------

-- UserIds of the members who skip the run's tutorial (TeleportData SkipTutorial)
local function skippers(party: Party): { number }
	const out: { number } = {}
	for _, userId in party.Members do
		if party.Skip[userId] == true then
			table.insert(out, userId)
		end
	end
	return out
end

function PartyService:LaunchData(party: Party): { [string]: any }
	return {
		Role = "Game",
		PartyId = party.Id,
		Members = table.clone(party.Members),
		Leader = party.Leader,
		SkipTutorial = skippers(party),
	}
end

-- End of the countdown: reserve + teleport (Studio cannot: back to the idle state).
function PartyService:Fire(party: Party)
	if self.Parties[party.Id] ~= party or party.State ~= "Starting" or party.Launched then
		return
	end
	self.Tracked:Fire("Fired", party, party.Leader, if party.Solo then "solo" else "squad")
	if RunService:IsStudio() then
		self:NoticeParty(party, "StudioNoTeleport", nil)
		self:Reopen(party, false)
		return
	end
	party.Launched = true
	for _, userId in party.Members do
		self.Teleporting[userId] = party.Id
	end
	task.spawn(function()
		self:Launch(party)
	end)
	task.delay(WATCHDOG, function()
		self:Reopen(party, true)
	end)
end

-- Back to the idle state when the squad is still "Starting" with nobody in flight.
function PartyService:Reopen(party: Party, notify: boolean)
	if self.Parties[party.Id] ~= party or party.State ~= "Starting" then
		return
	end
	for _, userId in party.Members do
		if self.InFlight[userId] ~= nil then
			return
		end
	end
	for _, userId in party.Members do
		if self.Teleporting[userId] == party.Id then
			self.Teleporting[userId] = nil
		end
	end
	if party.Solo or party.Platform > 0 then
		-- a solo quick play is not a squad to keep: gone, and Play offers the choice again. A pad room too: whoever
		-- still stands on the pad starts a fresh one (PollPlatforms)
		if notify then
			self:NoticeParty(party, "TeleportFailed", nil)
		end
		self:Disband(party)
		return
	end
	party.State = idleState(party)
	party.StartAt = 0
	party.Launched = false
	self:Publish(party, false)
	if notify then
		self:NoticeParty(party, "TeleportFailed", nil)
	end
end

-- Reserve + teleport with retries. Runs in its own thread.
function PartyService:Launch(party: Party)
	const retries = RULES.TeleportRetries
	local code: string? = nil
	for attempt = 1, #retries + 1 do
		if self.Parties[party.Id] ~= party then
			return -- disbanded meanwhile
		end
		if code == nil then
			const reserved, serverId, problem = Teleport.Reserve()
			code = reserved
			if reserved == nil then
				warn(`[PartyService] ReserveServer failed for party {party.Id} (try {attempt}): {problem}`)
			elseif serverId ~= nil and serverId ~= "" then
				-- the run server claims this record on boot; it is what lets a dropped member rejoin (TASK-360)
				self.Dependencies.SessionService:Register(serverId, reserved, party.Members)
			end
		end
		if code ~= nil then
			const players = self:PlayersOf(party)
			if #players == 0 then
				return
			end
			const options = Teleport.Options(code, self:LaunchData(party))
			const ok, problem = Teleport.Send(players, options)
			if ok then
				for _, member in players do
					self.InFlight[member.UserId] = { Options = options, Tries = 0, PartyId = party.Id }
				end
				return
			end
			warn(`[PartyService] TeleportAsync failed for party {party.Id} (try {attempt}): {problem}`)
		end
		if attempt <= #retries then
			self:NoticeParty(party, "TeleportRetry", nil)
			task.wait(retries[attempt])
		end
	end
	self:Reopen(party, true)
end

-- One member's teleport failed after Roblox accepted it: same options (same reserved server), alone, with retries.
function PartyService:HandleInitFailed(player: Player, result: Enum.TeleportResult, message: string)
	const flight = self.InFlight[player.UserId]
	if flight == nil then
		return
	end
	const retries = RULES.TeleportRetries
	flight.Tries += 1
	warn(`[PartyService] teleport of {player.Name} failed ({result.Name}: {message}); try {flight.Tries}`)
	if result == Enum.TeleportResult.IsTeleporting then
		return -- one already in progress
	end
	if flight.Tries > #retries then
		self.InFlight[player.UserId] = nil
		self.Teleporting[player.UserId] = nil
		const party = self.Parties[flight.PartyId]
		if party ~= nil then
			self:Reopen(party, false)
		end
		self:Notice(player, "TeleportFailed", nil)
		return
	end
	self:Notice(player, "TeleportRetry", nil)
	task.delay(retries[flight.Tries], function()
		if self.InFlight[player.UserId] ~= flight or player.Parent == nil then
			return
		end
		const ok, problem = Teleport.Send({ player }, flight.Options)
		if not ok then
			self:HandleInitFailed(player, Enum.TeleportResult.Failure, problem or "TeleportAsync failed")
		end
	end)
end

-- Platforms --------------------------------------------------------------------------------------------------------

-- Where the player stands: the platform kept with hysteresis, else the first one entered; 0 = none (or dead).
function PartyService:PlatformOf(player: Player, was: number): number
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return 0
	end
	const position = root.Position
	if was > 0 then
		const zone = LobbyZones.Platform(was)
		if zone ~= nil and LobbyZones.Inside(zone, position, true) then
			return was
		end
	end
	for _, zone in LobbyZones.List() do
		if zone.Platform > 0 and LobbyZones.Inside(zone, position, false) then
			return zone.Platform
		end
	end
	return 0
end

-- nil = may join; else the PartyNotice key of the refusal.
function PartyService:CanJoinPlatform(party: Party, platform: number): string?
	if self.Parties[party.Id] ~= party or party.Platform ~= platform or party.Launched then
		return "Busy"
	end
	if party.State == "Starting" and party.StartAt - workspace:GetServerTimeNow() <= RULES.JoinCutoff then
		return "Busy" -- the teleport is about to go
	end
	if party.Access == "Closed" then
		return "RoomClosed"
	elseif party.Access == "Invite" then
		return "InviteOnly"
	end
	if #party.Members >= party.MaxPlayers then
		return "PartyFull"
	end
	return nil
end

function PartyService:JoinPlatform(player: Player, party: Party)
	const userId = player.UserId
	const current = self:PartyOfUser(userId)
	if current == party then
		return
	end
	if current ~= nil then
		if not isOpen(current) then
			return
		end
		self:RemoveMember(userId, false)
	end
	self:Join(party, userId)
end

function PartyService:Refuse(player: Player, platform: number, key: string)
	self.Refused[player.UserId] = platform
	self:Notice(player, key, nil)
end

function PartyService:EnterPlatform(player: Player, platform: number)
	const userId = player.UserId
	const teleporting = self.Teleporting[userId]
	if self.InFlight[userId] ~= nil or (teleporting ~= nil and self.Parties[teleporting] ~= nil) then
		return -- already on its way with another squad: this platform is denied to them
	end
	self.Teleporting[userId] = nil
	const current = self:PartyOfUser(userId)
	if current ~= nil and current.Platform == platform then
		return
	end
	if current ~= nil and not isOpen(current) then
		return -- its squad is starting elsewhere
	end
	const owner = self:PartyOnPlatform(platform)
	if owner == nil then
		if current ~= nil and current.Platform == 0 and current.Leader == userId then
			-- the leader of an invite squad takes the platform with the squad, and its countdown starts
			current.Platform = platform
			self:Begin(current, RULES.PadCountdown, false)
			return
		end
		if current ~= nil then
			self:RemoveMember(userId, false)
		end
		const room = self:Create(userId, platform, "Open")
		if room ~= nil then
			self:Begin(room, RULES.PadCountdown, false)
		end
		return
	end
	const problem = self:CanJoinPlatform(owner, platform)
	if problem ~= nil then
		self:Refuse(player, platform, problem)
		return
	end
	if owner.Access ~= "Friends" then
		self:JoinPlatform(player, owner)
		return
	end
	-- friends only: IsFriendsWith yields, so it runs aside and everything is checked again after it
	self.Checking[userId] = true
	const leader = owner.Leader
	task.spawn(function()
		const ok, friend = pcall(function(): boolean
			return player:IsFriendsWith(leader)
		end)
		self.Checking[userId] = nil
		if player.Parent == nil or self.OnPlatform[userId] ~= platform then
			return
		end
		if not ok or friend ~= true or owner.Leader ~= leader then
			self:Refuse(player, platform, "FriendsOnly")
			return
		end
		const later = self:CanJoinPlatform(owner, platform)
		if later ~= nil then
			self:Refuse(player, platform, later)
			return
		end
		self:JoinPlatform(player, owner)
	end)
end

function PartyService:ExitPlatform(player: Player, platform: number)
	const userId = player.UserId
	if self.Refused[userId] == platform then
		self.Refused[userId] = nil
	end
	const party = self:PartyOfUser(userId)
	if party ~= nil and party.Platform == platform and not party.Launched then
		self:RemoveMember(userId, false)
	end
end

-- Root of a living character; nil = no character or dead.
local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return root
end

-- Planar distance from pad n's centre (math.huge = no pad).
local function fromPad(position: Vector3, n: number): number
	const zone = LobbyZones.Platform(n)
	if zone == nil then
		return math.huge
	end
	return Vector3.new(position.X - zone.Center.X, 0, position.Z - zone.Center.Z).Magnitude
end

-- Living member of the pad room of `platform`: the ring keeps them in (DEC-348).
function PartyService:Holds(player: Player, platform: number): boolean
	const party = self:PartyOfUser(player.UserId)
	return platform > 0 and party ~= nil and party.Platform == platform and rootOf(player) ~= nil
end

-- Is `player` a friend of `leader`? nil = not known yet (asked aside, cached for the pair).
function PartyService:IsFriend(player: Player, leader: number): boolean?
	const userId = player.UserId
	if userId == leader then
		return true
	end
	const known = self.Friendship[userId]
	if known ~= nil and known[leader] ~= nil then
		return known[leader]
	end
	const key = `{userId}:{leader}`
	if not self.Asking[key] then
		self.Asking[key] = true
		task.spawn(function()
			const ok, friend = pcall(function(): boolean
				return player:IsFriendsWith(leader)
			end)
			self.Asking[key] = nil
			if player.Parent == nil then
				return
			end
			const cache = self.Friendship[userId] or {}
			cache[leader] = ok and friend == true
			self.Friendship[userId] = cache
		end)
	end
	return nil
end

-- Collision group of a player's character (Barrier.luau): caged on the pad of their room, passing its ring when off it,
-- passing a friends-only ring when a friend of its leader comes close; Barrier.Base otherwise.
function PartyService:GroupFor(player: Player): string
	const userId = player.UserId
	const party = self:PartyOfUser(userId)
	if party ~= nil and party.Platform > 0 then
		return if self.OnPlatform[userId] == party.Platform
			then Barrier.Cage(party.Platform)
			else Barrier.Guest(party.Platform)
	end
	const root = rootOf(player)
	if root == nil then
		return Barrier.Base
	end
	for n = 1, RULES.Platforms do
		const room = self:PartyOnPlatform(n)
		const zone = LobbyZones.Platform(n)
		if
			room ~= nil
			and room.Access == "Friends"
			and zone ~= nil
			and fromPad(root.Position, n) <= zone.Radius + BARRIER.Near
			and self:IsFriend(player, room.Leader) == true
		then
			return Barrier.Guest(n)
		end
	end
	return Barrier.Base
end

-- Rings on / off by room access, every character in its group, nobody shut inside a ring that stops them.
function PartyService:SyncBarrier()
	Barrier.Build()
	for n = 1, RULES.Platforms do
		const room = self:PartyOnPlatform(n)
		Barrier.Block(n, room ~= nil and room.Access ~= "Open")
	end
	for _, player in Players:GetPlayers() do
		const group = self:GroupFor(player)
		Barrier.Assign(player, group)
		const on = self.OnPlatform[player.UserId]
		const room = if on ~= nil then self:PartyOnPlatform(on) else nil
		if on ~= nil and room ~= nil and room.Access ~= "Open" and group == Barrier.Base then
			-- a friend still being checked stays; anyone else is put outside
			if room.Access ~= "Friends" or self:IsFriend(player, room.Leader) == false then
				const outside = Barrier.Outside(on)
				const zone = LobbyZones.Platform(on)
				if outside ~= nil and zone ~= nil then
					Barrier.Place(player, outside, zone.Center)
				end
			end
		end
	end
end

function PartyService:PollPlatforms()
	for _, player in Players:GetPlayers() do
		const userId = player.UserId
		const was = self.OnPlatform[userId] or 0
		const now = self:PlatformOf(player, was)
		if was > 0 and now ~= was and self:Holds(player, was) then
			-- caged (DEC-348): seen out of the zone = lag at the wall while close, else (an exploit, a glitch) put back
			-- on the pad. Exit is the only way out
			const root = rootOf(player)
			const zone = LobbyZones.Platform(was)
			if root ~= nil and zone ~= nil then
				const reach = zone.Radius + TRIGGER.Hysteresis + BARRIER.Slack
				if fromPad(root.Position, was) > reach then
					Barrier.Return(player, was)
				end
			end
			continue
		end
		if now ~= was then
			self.OnPlatform[userId] = if now > 0 then now else nil
			if was > 0 then
				self:ExitPlatform(player, was)
			end
			if now > 0 then
				self:EnterPlatform(player, now)
			end
		elseif now > 0 and self.Refused[userId] ~= now and not self.Checking[userId] then
			-- still standing there outside its squad (platform freed, refusal cleared): try again
			const party = self:PartyOfUser(userId)
			if party == nil or party.Platform ~= now then
				self:EnterPlatform(player, now)
			end
		end
	end
	self:SyncBarrier()
end

function PartyService:Forget(player: Player)
	const userId = player.UserId
	self.InFlight[userId] = nil
	self.Teleporting[userId] = nil
	self.Invites[userId] = nil
	self.OnPlatform[userId] = nil
	self.Refused[userId] = nil
	self.Checking[userId] = nil
	self.Friendship[userId] = nil
	Barrier.Forget(player)
	self.RateStart[player] = nil
	self.RateCount[player] = nil
	if self.PartyOf[userId] ~= nil then
		self:RemoveMember(userId, false)
	end
end

-- Responders -------------------------------------------------------------------------------------------------------

-- Common gate of every squad packet: rate, then role.
function PartyService:Gate(player: Player): boolean
	if not self:Allow(player) then
		return false
	end
	if not self.Active then
		self:Notice(player, "WrongServer", nil)
		return false
	end
	return true
end

PartyService:OnInit(function(self)
	self:Setup()
	self.Active = self.Dependencies.RoleService:IsLobby()
	const net = self.Libs.Net

	-- Responders on every role (Lync locks definitions at start); outside a lobby they answer WrongServer.
	net.PartyCreate:onServer(function(_, player: Player)
		if self:Gate(player) then
			self:HandleCreate(player)
		end
	end)
	net.PartyInvite:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleInvite(player, data.UserId)
		end
	end)
	net.PartyRespond:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleRespond(player, data.PartyId, data.Accept == true)
		end
	end)
	net.PartyLeave:onServer(function(_, player: Player)
		if self:Gate(player) then
			self:HandleLeave(player)
		end
	end)
	net.PartyKick:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleKick(player, data.UserId)
		end
	end)
	net.PartyStart:onServer(function(_, player: Player)
		if self:Gate(player) then
			self:HandleStart(player)
		end
	end)
	net.PartyConfigure:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleConfigure(player, data.Access, data.MaxPlayers)
		end
	end)
	net.PartyCancel:onServer(function(_, player: Player)
		if self:Gate(player) then
			self:HandleCancel(player)
		end
	end)
	net.PartyPad:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandlePad(player, data.Action, data.On == true)
		end
	end)
	net.PartyQuickPlay:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleQuickPlay(player, if data.Mode == "Solo" then "Solo" else "Squad")
		end
	end)

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
	if not self.Active then
		return
	end
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		self:HandleInitFailed(player, result, message)
	end)
end)

PartyService:OnStart(function(self)
	if not self.Active then
		return
	end
	Barrier.Setup(RULES.Platforms)
	-- platforms: one cheap check of every root every Content.Lobby.Squad.Poll s
	const poll = Content.Lobby.Squad.Poll
	RunService.Heartbeat:Connect(function()
		const now = os.clock()
		if now < self.PollAt then
			return
		end
		self.PollAt = now + poll
		self:PollPlatforms()
	end)
end)

return PartyService
