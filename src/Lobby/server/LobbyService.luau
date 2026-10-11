--!strict
-- Lobby spawn (architecture.md §20.4; user request 2026-10-11, Provisional; TASK-155). Lobby roles only.
-- In the lobby the character is the player's own Roblox avatar, R15 (user request 2026-10-11): Roblox loads it
-- (Players.CharacterAutoLoads = true here, whatever the place file says; the game role keeps it false and spawns the
-- class crew rig through CharacterService). The class rig is only shown on the class stage (client, ClassStage).
-- This service only places each new character on the MapPoint "LOBBY-SPAWN" (tag MapPoint, attribute PointId; more
-- spawns = "LOBBY-SPAWN-2"... any id starting with LOBBY-SPAWN, one picked at random, spread a little). Missing = one
-- warning and the first SpawnLocation of the Workspace, else wherever Roblox put it.
-- A StarterPlayer.StarterCharacter left in the place (the game parks the crew rig there for one LoadCharacter) is
-- taken out on lobby servers, so nobody spawns as a crew rig. When the experience forces R6 avatars (Creator Hub
-- setting), the loaded R6 character is swapped once for an R15 model of the same avatar
-- (Players:CreateHumanoidModelFromDescription).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

const SPAWN_PREFIX = "LOBBY-SPAWN"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const SPREAD = 6 -- studs: random offset around the point so a squad does not stack
const TEMPLATE_NAME = "StarterCharacter"
const R15_ATTRIBUTE = "LobbyR15" -- on a character this service built as R15
const ROOT_WAIT = 5 -- s

const LobbyService = Modux.Service("LobbyService", {
	Require = { "RoleService", "PlayerService" },
	Priority = 675,
})

function LobbyService:Setup()
	self.Warned = false :: boolean
	self.Random = Random.new() :: Random
end

-- Spawn point ------------------------------------------------------------------------------------------------------

function LobbyService:SpawnCFrame(): CFrame?
	const points: { CFrame } = {}
	for _, point in MapIndex.Points(SPAWN_PREFIX) do
		table.insert(points, point)
	end
	if #points > 0 then
		const base = points[self.Random:NextInteger(1, #points)]
		const offset = Vector3.new(
			self.Random:NextNumber(-SPREAD / 2, SPREAD / 2),
			0,
			self.Random:NextNumber(-SPREAD / 2, SPREAD / 2)
		)
		return base + offset + SPAWN_LIFT
	end
	if not self.Warned then
		self.Warned = true
		warn(`[LobbyService] no MapPoint {SPAWN_PREFIX} in the Workspace (lobby map pending): fallback spawn`)
	end
	const location = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if location ~= nil then
		return location.CFrame + SPAWN_LIFT
	end
	return nil
end

-- Avatar -----------------------------------------------------------------------------------------------------------

-- The same avatar as an R15 model (experience forced to R6). Test players (UserId <= 0) get the default look.
function LobbyService:SwapToR15(player: Player, old: Model, at: CFrame)
	const ok, result = pcall(function(): Model
		const description = if player.UserId > 0
			then Players:GetHumanoidDescriptionFromUserId(player.UserId)
			else Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[LobbyService] R15 avatar of {player.Name} unavailable ({result}); keeping the loaded one`)
		return
	end
	if player.Parent == nil or player.Character ~= old then
		result:Destroy()
		return
	end
	const model = result
	model.Name = player.Name
	model:SetAttribute(R15_ATTRIBUTE, true)
	model:PivotTo(at)
	player.Character = model
	model.Parent = workspace
	old:Destroy()
end

function LobbyService:OnCharacter(player: Player, character: Model)
	if character:GetAttribute(R15_ATTRIBUTE) == true then
		return -- built here, already placed
	end
	task.spawn(function()
		const root = character:WaitForChild("HumanoidRootPart", ROOT_WAIT)
		if root == nil or player.Character ~= character then
			return
		end
		const at = self:SpawnCFrame() or character:GetPivot()
		character:PivotTo(at)
		const humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			self:SwapToR15(player, character, at)
		end
	end)
end

LobbyService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.RoleService:IsLobby() then
		return
	end

	const parked = StarterPlayer:FindFirstChild(TEMPLATE_NAME)
	if parked ~= nil then
		warn(`[LobbyService] StarterPlayer.{TEMPLATE_NAME} found on a lobby server: removed (lobby uses the avatar)`)
		parked.Parent = nil
	end
	Players.CharacterAutoLoads = true -- the avatar, loaded and respawned by Roblox

	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player, character)
		self:OnCharacter(player, character)
	end)
end)

LobbyService:OnStart(function(self)
	if not self.Dependencies.RoleService:IsLobby() then
		return
	end
	-- joined while the place setting (CharacterAutoLoads false) still held: load them now
	task.defer(function()
		for _, player in Players:GetPlayers() do
			if player.Character == nil and player.Parent ~= nil then
				pcall(function()
					player:LoadCharacter()
				end)
			end
		end
	end)
end)

return LobbyService
