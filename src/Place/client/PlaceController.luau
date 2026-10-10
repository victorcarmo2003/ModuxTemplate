--!strict
-- Client side of PlaceService (architecture.md §1, §3.2; TASK-010): same rules, read locally.
-- Role = Workspace.PlaceRole (authored, replicated); missing reads as "Run" (wave 1). Dev = Run in Studio without
-- PrivateServerId. Only for presentation (dev panels, labels): the server decides everything dev-only.
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Role = "Lobby" | "Run"

const ROLE_ATTRIBUTE = "PlaceRole"
const DEFAULT_ROLE: Role = "Run"

local function readRole(): Role
	const raw = workspace:GetAttribute(ROLE_ATTRIBUTE)
	if raw == "Lobby" or raw == "Run" then
		return raw
	end
	return DEFAULT_ROLE
end

const PlaceController = Modux.Controller("PlaceController", { Priority = 950 })

function PlaceController:Setup()
	const role = readRole()
	self.Role = role :: Role
	self.Dev = (role == "Run" and game.PrivateServerId == "" and RunService:IsStudio()) :: boolean
end

function PlaceController:Is(role: Role): boolean
	return self.Role == role
end

function PlaceController:IsDev(): boolean
	return self.Dev
end

PlaceController:OnInit(function(self)
	self:Setup()
end)

return PlaceController
