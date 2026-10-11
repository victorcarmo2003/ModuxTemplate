--!strict
-- Server role resolved once at boot (architecture.md §20.1; rules in shared/Roles.luau). Priority 990: right
-- after NetService, before PlaceService (950), which maps it to its "Lobby" | "Run" view for every gameplay service.
-- A reserved server only learns its role from the first player's TeleportData, so OnInit waits for that player (up
-- to FIRST_PLAYER_WAIT s; the server exists because a teleport is on its way). Players who join meanwhile are picked
-- up by PlayerService's OnStart scan. Publishes ReplicatedStorage.ServerRole for the clients (PlaceController:GetServerRole()).
-- Named RoleService (not ServerRoleService) and Roles.luau (not ServerRole.luau): rogen strips a leading "Server" from
-- file names and places such a file in ServerScriptService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)
local Modux = require(ServerScriptService.server.Modux)

export type Role = Roles.Role
export type Launch = Roles.Launch

const FIRST_PLAYER_WAIT = 30 -- s a reserved server waits for its first player before defaulting to "Game"
const POLL = 0.1

local function joinData(player: Player): any
	const ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok and type(data) == "table" then data.TeleportData else nil
end

local function firstPlayer(timeout: number): Player?
	const deadline = os.clock() + timeout
	while os.clock() < deadline do
		const player = Players:GetPlayers()[1]
		if player ~= nil then
			return player
		end
		task.wait(POLL)
	end
	return nil
end

const RoleService = Modux.Service("RoleService", { Priority = 990 })

function RoleService:Setup()
	self.Role = "Game" :: Role
	self.Reserved = (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0) :: boolean
	-- squad launch read from the first player's TeleportData (Game / PrivateLobby reserved servers only)
	self.Launch = nil :: Launch?
end

-- Returns the role and, on a reserved server, the launch it came from.
function RoleService:Resolve(): (Role, Launch?)
	if self.Reserved then
		const player = firstPlayer(FIRST_PLAYER_WAIT)
		if player == nil then
			warn(`[RoleService] reserved server: no player in {FIRST_PLAYER_WAIT} s; role "Game"`)
			return "Game", nil
		end
		const launch = Roles.ParseLaunch(joinData(player))
		if launch == nil then
			warn(`[RoleService] reserved server: {player.Name} brought no squad TeleportData; role "Game" (solo)`)
			return "Game", nil
		end
		-- "Lobby" on a reserved server is a private lobby
		return (if launch.Role == "Lobby" then "PrivateLobby" else launch.Role), launch
	end

	if game.PrivateServerId ~= "" then
		return "PrivateLobby", nil -- VIP server
	end

	const studio = RunService:IsStudio()
	const override = Roles.Parse(workspace:GetAttribute(Roles.Override))
	if override ~= nil then
		if not studio then
			warn(`[RoleService] Workspace.{Roles.Override} = "{override}" on a live server (clear it before publishing)`)
		end
		return override, nil
	end
	if studio then
		const legacy = workspace:GetAttribute(Roles.Legacy)
		if legacy == "Lobby" then
			return "Lobby", nil
		end
		return "Game", nil -- Studio default: the run, as every test so far
	end
	return "Lobby", nil
end

function RoleService:Get(): Role
	return self.Role
end

function RoleService:Is(role: Role): boolean
	return self.Role == role
end

function RoleService:IsLobby(): boolean
	return Roles.IsLobby(self.Role)
end

function RoleService:IsGame(): boolean
	return self.Role == "Game"
end

-- Reserved server created by ReserveServer (a Game or a PrivateLobby launched from a lobby).
function RoleService:IsReserved(): boolean
	return self.Reserved
end

-- Squad launch of this server (TeleportData of its first player); nil on public servers, in Studio and when the
-- first player brought none.
function RoleService:GetLaunch(): Launch?
	return self.Launch
end

RoleService:OnInit(function(self)
	self:Setup()
	const role, launch = self:Resolve()
	self.Role = role
	self.Launch = launch
	ReplicatedStorage:SetAttribute(Roles.Attribute, role)
	local suffix = ""
	if launch ~= nil then
		suffix = ` (party {launch.PartyId}, {#launch.Members} member(s))`
	end
	print(`[RoleService] role {role}{suffix}`)
end)

return RoleService
