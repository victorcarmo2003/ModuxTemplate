--!strict
-- Squad (party) in the lobby (architecture.md §20.2; network.md §16; user request 2026-10-11, Provisional; TASK-155).
-- Lobby roles only (Lobby, PrivateLobby): elsewhere every squad packet answers PartyNotice "WrongServer".
-- Single writer of the Party set (record = PartyId). Responders for PartyCreate/Invite/Respond/Leave/Kick/Ready/Start.
--
-- Rules (Provisional; DEC-179 "plataformas" is replaced by invites at the user's request of 2026-10-11, see
-- architecture.md §20.2): up to PartyRules.Rules.MaxSize (4, DEC-012) members; the creator leads; only the leader
-- invites, kicks and starts; inviting without a squad creates one; accepting an invite leaves the current squad;
-- the leader is always ready, Start needs every other member ready; leader leaves = first member left leads.
-- Start: State "Starting" -> ReserveServer -> TeleportAsync(game.PlaceId, members, ReservedServerAccessCode +
-- TeleportData { Role = "Game", PartyId, Members, Leader }). Reserve or teleport failing retries after 2/5/10 s
-- (PartyRules.Rules.TeleportRetries); all failing = back to "Forming" + "TeleportFailed". A member whose own teleport
-- fails later (TeleportInitFailed) retries alone with the same options (same server). Studio cannot teleport:
-- Start answers "StudioNoTeleport" and nothing changes.
-- Server never trusts the client: membership, leadership, state, size, presence of the target and rate are checked
-- here; TeleportData is written only by this service.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local Teleport = require(script.Teleport)
local Modux = require(ServerScriptService.server.Modux)

export type State = "Forming" | "Starting"
export type Party = {
	Id: number,
	Leader: number,
	Members: { number }, -- party order, leader first after any change of leader
	Ready: { [number]: boolean },
	State: State,
}
type Invite = { From: number, ExpiresAt: number }
type Flight = { Options: TeleportOptions, Tries: number, PartyId: number }

const RULES = PartyRules.Rules
const WATCHDOG = 45 -- s a squad may stay "Starting" with members still in the lobby before it opens again

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value >= 1 and value % 1 == 0 and value < 2 ^ 53
end

const PartyService = Modux.Service(
	"PartyService",
	{ Require = { "RoleService", "PlayerService", "NetService" }, Priority = 680 }
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
local function record(party: Party): { Leader: number, Members: { number }, Ready: { [number]: boolean }, State: string }
	const ready: { [number]: boolean } = {}
	for _, userId in party.Members do
		ready[userId] = userId == party.Leader or party.Ready[userId] == true
	end
	return {
		Leader = party.Leader,
		Members = table.clone(party.Members),
		Ready = ready,
		State = party.State,
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

function PartyService:Create(leader: number): Party?
	if self.PartyOf[leader] ~= nil then
		return nil
	end
	const party: Party = {
		Id = self:NewId(),
		Leader = leader,
		Members = { leader },
		Ready = { [leader] = true },
		State = "Forming",
	}
	self.Parties[party.Id] = party
	self.PartyOf[leader] = party.Id
	self:Publish(party, true)
	return party
end

function PartyService:Disband(party: Party)
	if self.Parties[party.Id] ~= party then
		return
	end
	self.Parties[party.Id] = nil
	for _, userId in party.Members do
		if self.PartyOf[userId] == party.Id then
			self.PartyOf[userId] = nil
		end
	end
	if self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Party:remove(party.Id)
	end
end

-- Takes a member out (leave, kick, left the server, left behind by a failed teleport). Empty squad = gone.
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
	party.Ready[userId] = nil
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
		party.Ready[party.Leader] = true
		self:NoticeParty(party, "NewLeader", party.Leader)
	end
	self:Publish(party, false)
end

function PartyService:Join(party: Party, userId: number)
	table.insert(party.Members, userId)
	party.Ready[userId] = false
	self.PartyOf[userId] = party.Id
	self:Publish(party, false)
	self:NoticeParty(party, "Joined", userId)
end

-- Requests (already rate limited and role checked) -----------------------------------------------------------------

function PartyService:HandleCreate(player: Player)
	if self.PartyOf[player.UserId] ~= nil then
		self:Notice(player, "AlreadyInParty", nil)
		return
	end
	if self:Create(player.UserId) ~= nil then
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
		found = self:Create(from)
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
	if party.State ~= "Forming" then
		self:Notice(player, "Busy", nil)
		return
	end
	if table.find(party.Members, target) ~= nil then
		self:Notice(player, "AlreadyInParty", target)
		return
	end
	if #party.Members >= RULES.MaxSize then
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
	if invite == nil or os.clock() > invite.ExpiresAt or party == nil or party.State ~= "Forming" then
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
	if #party.Members >= RULES.MaxSize then
		self:Notice(player, "PartyFull", nil)
		return
	end
	const current = self:PartyOfUser(userId)
	if current ~= nil then
		if current.State ~= "Forming" then
			self:Notice(player, "Busy", nil)
			return
		end
		self:RemoveMember(userId, false)
	end
	self:Join(party, userId)
end

function PartyService:HandleLeave(player: Player)
	if self:PartyOfUser(player.UserId) == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	self:RemoveMember(player.UserId, false)
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
	if party.State ~= "Forming" then
		self:Notice(player, "Busy", nil)
		return
	end
	if target == player.UserId or table.find(party.Members, target) == nil then
		self:Notice(player, "PlayerNotFound", nil)
		return
	end
	self:RemoveMember(target, true)
end

function PartyService:HandleReady(player: Player, ready: boolean)
	const party = self:PartyOfUser(player.UserId)
	if party == nil then
		self:Notice(player, "NotInParty", nil)
		return
	end
	if party.State ~= "Forming" then
		self:Notice(player, "Busy", nil)
		return
	end
	if party.Leader == player.UserId or party.Ready[player.UserId] == ready then
		return
	end
	party.Ready[player.UserId] = ready
	self:Publish(party, false)
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
	if party.State ~= "Forming" then
		self:Notice(player, "Busy", nil)
		return
	end
	for _, userId in party.Members do
		if userId ~= party.Leader and party.Ready[userId] ~= true then
			self:Notice(player, "NotAllReady", userId)
			return
		end
	end
	if RunService:IsStudio() then
		self:Notice(player, "StudioNoTeleport", nil)
		return
	end
	party.State = "Starting"
	self:Publish(party, false)
	self:NoticeParty(party, "Starting", nil)
	task.spawn(function()
		self:Launch(party)
	end)
	task.delay(WATCHDOG, function()
		self:Reopen(party, true)
	end)
end

-- Teleport ---------------------------------------------------------------------------------------------------------

function PartyService:LaunchData(party: Party): { [string]: any }
	return {
		Role = "Game",
		PartyId = party.Id,
		Members = table.clone(party.Members),
		Leader = party.Leader,
	}
end

-- Back to "Forming" (others not ready again) when the squad is still "Starting" with nobody in flight.
function PartyService:Reopen(party: Party, notify: boolean)
	if self.Parties[party.Id] ~= party or party.State ~= "Starting" then
		return
	end
	for _, userId in party.Members do
		if self.InFlight[userId] ~= nil then
			return
		end
	end
	party.State = "Forming"
	for _, userId in party.Members do
		if userId ~= party.Leader then
			party.Ready[userId] = false
		end
	end
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
			const reserved, problem = Teleport.Reserve()
			code = reserved
			if reserved == nil then
				warn(`[PartyService] ReserveServer failed for party {party.Id} (try {attempt}): {problem}`)
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

function PartyService:Forget(player: Player)
	const userId = player.UserId
	self.InFlight[userId] = nil
	self.Invites[userId] = nil
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
	net.PartyReady:onServer(function(data, player: Player)
		if self:Gate(player) then
			self:HandleReady(player, data.Ready == true)
		end
	end)
	net.PartyStart:onServer(function(_, player: Player)
		if self:Gate(player) then
			self:HandleStart(player)
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

return PartyService
