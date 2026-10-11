--!strict
-- Client side of PlaceService (architecture.md §1, §3.2, §20.1; TASK-010, TASK-154): same rules, read locally.
-- Role = ReplicatedStorage.ServerRole (RoleService) seen as "Lobby" | "Run" (Game = "Run"); OnInit waits for
-- it (a reserved server publishes it after reading its first player's TeleportData). GetServerRole() gives the full
-- role ("Lobby" | "Game" | "PrivateLobby"). Dev = Run in Studio without PrivateServerId. Only for presentation (dev
-- panels, labels, lobby UI): the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Role = "Lobby" | "Run"

const SERVER_ROLE_WAIT = 30 -- s

const PlaceController = Modux.Controller("PlaceController", { Priority = 950 })

function PlaceController:Setup()
	const serverRole = Roles.Wait(SERVER_ROLE_WAIT)
	self.ServerRole = serverRole :: Roles.Role
	const role = Roles.PlaceRole(serverRole)
	self.Role = role :: Role
	self.Dev = (role == "Run" and game.PrivateServerId == "" and RunService:IsStudio()) :: boolean
end

function PlaceController:Is(role: Role): boolean
	return self.Role == role
end

-- "Lobby" | "Game" | "PrivateLobby" (architecture.md §20.1)
function PlaceController:GetServerRole(): Roles.Role
	return self.ServerRole
end

function PlaceController:IsDev(): boolean
	return self.Dev
end

PlaceController:OnInit(function(self)
	self:Setup()
end)

return PlaceController
