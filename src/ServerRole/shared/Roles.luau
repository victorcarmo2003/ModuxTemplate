--!strict
-- ServerRole (user request 2026-10-11; architecture.md §20): one place, three server roles.
-- ReplicatedStorage.shared.ServerRole.Roles. Pure: no Modux, Lync, Vide nor self.Libs.
--
--   Lobby         public server of the place: profile, classes, shop, codes, squad (party) and Start
--   Game          reserved server of one squad: the run (RoundService and every gameplay service)
--   PrivateLobby  reserved server that behaves as a lobby (VIP server, or TeleportData Role = "PrivateLobby")
--
-- Resolution (RoleService, once at boot; the result is the ReplicatedStorage attribute "ServerRole"):
--   reserved server (PrivateServerId ~= "", PrivateServerOwnerId == 0)
--       -> TeleportData.Role of the first player (Launch below); missing / unreadable = "Game"
--   VIP server (PrivateServerOwnerId ~= 0)          -> "PrivateLobby"
--   anything else (public server, Studio, Team Test):
--       Workspace attribute "ServerRoleOverride" when it is a valid role (warns outside Studio)
--       Studio only: legacy Workspace.PlaceRole ("Lobby" -> Lobby, "Run" -> Game), else "Game" (current tests)
--       published public server -> "Lobby"
-- PlaceService/PlaceController keep their "Lobby" | "Run" view: Game = "Run", Lobby and PrivateLobby = "Lobby".
-- Client side: PlaceController:GetServerRole() (waits with Wait below). No controller in src/ServerRole/client: the
-- Modux generator reads a path containing "Server" as server code. No file named "Server*": rogen strips the prefix
-- and moves it to ServerScriptService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Role = "Lobby" | "Game" | "PrivateLobby"

-- TeleportData of a squad launch (PartyService writes it, RoleService/PartyRunService read it).
export type Launch = {
	Role: Role,
	PartyId: number,
	Members: { number }, -- UserIds in party order (leader first)
	Leader: number,
	-- members who chose Skip tutorial on the lobby pad (owner request 2026-10-21); TutorialService closes theirs
	SkipTutorial: { number },
}

const ATTRIBUTE = "ServerRole" -- on ReplicatedStorage, written by the server, read by every client
const OVERRIDE = "ServerRoleOverride" -- on Workspace, authored in Studio
const LEGACY = "PlaceRole" -- on Workspace (TASK-010), still honoured in Studio
const MAX_MEMBERS = 8 -- parse guard only; the squad size rule is PartyRules.MaxSize

local function parse(value: any): Role?
	if value == "Lobby" or value == "Game" or value == "PrivateLobby" then
		return value
	end
	return nil
end

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value >= 1 and value % 1 == 0 and value < 2 ^ 53
end

-- Checks a TeleportData table; nil when it is not a squad launch. A reserved server only admits players our
-- servers teleported (access code is server-only), so this is shape checking, not authorization.
local function parseLaunch(data: any): Launch?
	if type(data) ~= "table" then
		return nil
	end
	const role = parse(data.Role)
	if role == nil then
		return nil
	end
	const members: { number } = {}
	if type(data.Members) == "table" then
		for _, userId in data.Members do
			if isUserId(userId) and not table.find(members, userId) and #members < MAX_MEMBERS then
				table.insert(members, userId)
			end
		end
	end
	local leader: number = members[1] or 0
	if isUserId(data.Leader) then
		leader = data.Leader :: number
	end
	local partyId: number = 0
	if type(data.PartyId) == "number" and data.PartyId == data.PartyId then
		partyId = data.PartyId :: number
	end
	const skip: { number } = {}
	if type(data.SkipTutorial) == "table" then
		for _, userId in data.SkipTutorial do
			if table.find(members, userId) and not table.find(skip, userId) then
				table.insert(skip, userId)
			end
		end
	end
	const launch: Launch = {
		Role = role,
		PartyId = partyId,
		Members = table.freeze(members),
		Leader = leader,
		SkipTutorial = table.freeze(skip),
	}
	table.freeze(launch :: any)
	return launch
end

-- Role published on ReplicatedStorage (nil until the server resolved it).
local function read(): Role?
	return parse(ReplicatedStorage:GetAttribute(ATTRIBUTE))
end

-- Client: waits for the server to publish the role (a reserved server publishes it only after its first player's
-- TeleportData was read). Falls back to "Game" after `timeout` s with a warning.
local function waitFor(timeout: number): Role
	const deadline = os.clock() + timeout
	local role = read()
	while role == nil and os.clock() < deadline do
		task.wait(0.1)
		role = read()
	end
	if role == nil then
		warn(`[ServerRole] ReplicatedStorage.{ATTRIBUTE} not set after {timeout} s; reading "Game"`)
		return "Game"
	end
	return role :: Role
end

local function isLobby(role: Role): boolean
	return role == "Lobby" or role == "PrivateLobby"
end

local function placeRole(role: Role): "Lobby" | "Run"
	return if role == "Game" then "Run" else "Lobby"
end

return table.freeze({
	Attribute = ATTRIBUTE,
	Override = OVERRIDE,
	Legacy = LEGACY,
	Parse = parse,
	ParseLaunch = parseLaunch,
	Read = read,
	Wait = waitFor,
	IsLobby = isLobby,
	PlaceRole = placeRole,
})
