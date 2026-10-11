--!strict
-- Squad on the game server and the way back to the lobby (architecture.md §20.3; network.md §16.4; TASK-156).
-- Game role only (other roles: LobbyReturn answers "WrongServer").
--
-- Squad of the run = RoleService:GetLaunch() (TeleportData of the first player, written by PartyService):
--   - every member is seated in the RunStateService roster in party order before anyone is admitted, so the
--     roster is the squad (DEC-205) and nobody else takes a seat;
--   - RoundService start gate: the run starts when every member is in, or Content.RunParams.JoinWindow (60 s,
--     DEC-098) after the first one; a late member spawns at work without the intro (DEC-205, CharacterService);
--   - a player who is not in the squad is sent back to the lobby (DEC-205; only possible through a stale teleport).
-- No launch (Studio, Team Test, a reserved server whose first player brought no TeleportData) = solo/dev behaviour:
-- whoever joins is a member (RunStateService dev roster) and the run starts with the first one, as before.
-- Back to the lobby: RunEnded -> after PartyRules.Rules.ReturnDelay s every player goes to a public server of this
-- place (TeleportAsync(game.PlaceId, players), no reserved code = Lobby role). LobbyReturn sends one player at any
-- time. Only on reserved servers: a published public server forced to "Game" (ServerRoleOverride) has no lobby to
-- go back to, and Studio cannot teleport ("StudioNoTeleport").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local Teleport = require(script.Parent.PartyService.Teleport)
local Modux = require(ServerScriptService.server.Modux)

const RULES = PartyRules.Rules
const RETURN_RATE = 2 -- s between two LobbyReturn of one player
const OUTSIDER_DELAY = 3 -- s before an outsider is sent back (lets the client show the notice)

const PartyRunService = Modux.Service("PartyRunService", {
	Require = { "RoleService", "PlayerService", "NetService", "RunStateService", "RoundService" },
	Priority = 745,
})

function PartyRunService:Setup()
	self.Active = false :: boolean
	-- squad UserIds (nil = solo/dev)
	self.Expected = nil :: { number }?
	-- os.clock() of the first member admitted
	self.FirstAt = nil :: number?
	-- tries of a return teleport in flight
	self.Returning = {} :: { [Player]: number }
	self.LastReturn = {} :: { [Player]: number }
end

function PartyRunService:IsExpected(userId: number): boolean
	const expected = self.Expected
	return expected == nil or table.find(expected, userId) ~= nil
end

-- RoundService start gate: every squad member is a member in the server, or the join window ran out.
function PartyRunService:SquadIn(): boolean
	const expected = self.Expected
	if expected == nil then
		return true
	end
	const firstAt = self.FirstAt
	if firstAt ~= nil and os.clock() - firstAt >= RULES.JoinWindow then
		return true
	end
	const runState = self.Dependencies.RunStateService
	for _, userId in expected do
		const member = runState.Members()[userId]
		if member == nil or member.State == "Away" or Players:GetPlayerByUserId(userId) == nil then
			return false
		end
	end
	return true
end

function PartyRunService:Notice(player: Player, key: string)
	const net = self.Dependencies.NetService
	if player.Parent == nil or not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.PartyNotice:fireClient(player, { Key = key, UserId = nil })
end

-- Can this server send players to the lobby?
function PartyRunService:CanReturn(player: Player?): boolean
	if RunService:IsStudio() then
		if player ~= nil then
			self:Notice(player, "StudioNoTeleport")
		end
		return false
	end
	if not self.Dependencies.RoleService:IsReserved() then
		if player ~= nil then
			self:Notice(player, "WrongServer")
		end
		return false
	end
	return true
end

-- Teleports to a public server of this place (= Lobby role), with retries; failures come back per player through
-- TeleportInitFailed.
function PartyRunService:SendToLobby(players: { Player })
	const list: { Player } = {}
	for _, player in players do
		if player.Parent ~= nil and self.Returning[player] == nil then
			self.Returning[player] = 0
			self:Notice(player, "ReturningToLobby")
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return
	end
	task.spawn(function()
		const retries = RULES.TeleportRetries
		for attempt = 1, #retries + 1 do
			const still: { Player } = {}
			for _, player in list do
				if player.Parent ~= nil then
					table.insert(still, player)
				end
			end
			if #still == 0 then
				return
			end
			const ok, problem = Teleport.Send(still, Teleport.Options(nil, nil))
			if ok then
				return
			end
			warn(`[PartyRunService] return to lobby failed (try {attempt}): {problem}`)
			if attempt <= #retries then
				task.wait(retries[attempt])
			end
		end
		for _, player in list do
			self.Returning[player] = nil
			self:Notice(player, "ReturnFailed")
		end
	end)
end

function PartyRunService:OnReturnFailed(player: Player, result: Enum.TeleportResult, message: string)
	const tries = self.Returning[player]
	if tries == nil or result == Enum.TeleportResult.IsTeleporting then
		return
	end
	const retries = RULES.TeleportRetries
	warn(`[PartyRunService] return of {player.Name} failed ({result.Name}: {message}); try {tries + 1}`)
	if tries >= #retries then
		self.Returning[player] = nil
		self:Notice(player, "ReturnFailed")
		return
	end
	self.Returning[player] = tries + 1
	task.delay(retries[tries + 1], function()
		if player.Parent == nil or self.Returning[player] == nil then
			return
		end
		const ok, problem = Teleport.Send({ player }, Teleport.Options(nil, nil))
		if not ok then
			self:OnReturnFailed(player, Enum.TeleportResult.Failure, problem or "TeleportAsync failed")
		end
	end)
end

function PartyRunService:HandleReturn(player: Player)
	const now = os.clock()
	const last = self.LastReturn[player]
	if last ~= nil and now - last < RETURN_RATE then
		return
	end
	self.LastReturn[player] = now
	if not self.Active then
		self:Notice(player, "WrongServer")
		return
	end
	if self:CanReturn(player) then
		self:SendToLobby({ player })
	end
end

function PartyRunService:OnPlayerAdded(player: Player)
	if self:IsExpected(player.UserId) then
		return
	end
	warn(`[PartyRunService] {player.Name} is not in this server's squad; back to the lobby (DEC-205)`)
	task.delay(OUTSIDER_DELAY, function()
		if player.Parent ~= nil and self:CanReturn(nil) then
			self:Notice(player, "WrongServer")
			self:SendToLobby({ player })
		end
	end)
end

PartyRunService:OnInit(function(self)
	self:Setup()
	self.Active = self.Dependencies.RoleService:IsGame()

	-- Responder on every role (Lync locks definitions at start)
	self.Libs.Net.LobbyReturn:onServer(function(_, player: Player)
		self:HandleReturn(player)
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.Returning[player] = nil
		self.LastReturn[player] = nil
	end)
	if not self.Active then
		return
	end

	const runState = self.Dependencies.RunStateService
	const launch = self.Dependencies.RoleService:GetLaunch()
	if launch ~= nil and #launch.Members > 0 then
		const expected: { number } = {}
		for _, userId in launch.Members do
			if #expected >= RULES.MaxSize then
				break
			end
			-- seats in party order before anyone is admitted (RunStateService admits on profile load)
			if runState:Seat(userId) then
				table.insert(expected, userId)
			end
		end
		self.Expected = expected
		self.Dependencies.RoundService:SetStartGate(function(): boolean
			return self:SquadIn()
		end)
	end

	runState.MemberJoined:Connect(function()
		if self.FirstAt == nil then
			self.FirstAt = os.clock()
		end
	end)
	self.Dependencies.PlayerService.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	self.Dependencies.RoundService.RunEnded:Connect(function()
		if not self:CanReturn(nil) then
			return
		end
		task.delay(RULES.ReturnDelay, function()
			self:SendToLobby(Players:GetPlayers())
		end)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		self:OnReturnFailed(player, result, message)
	end)
end)

return PartyRunService
