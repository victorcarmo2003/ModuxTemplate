--!strict
-- Lobby spawn (architecture.md §20.4; user request 2026-10-11, Provisional; TASK-155). Lobby roles only.
-- The lobby map lives in the same place as MAP-01, away from it; its spawn is the MapPoint "LOBBY-SPAWN" (tag
-- MapPoint, attribute PointId; more spawns = "LOBBY-SPAWN-2", "LOBBY-SPAWN-3"... any id starting with LOBBY-SPAWN,
-- one picked at random). Missing = one warning and the first SpawnLocation of the Workspace, else wherever
-- LoadCharacter puts the character.
-- The character is the crew rig of the selected class (DEC-146, DEC-147), built like CharacterService does in the
-- game (CrewRig.Build parked as StarterPlayer.StarterCharacter for one LoadCharacter; one spawn at a time). In the
-- game role CharacterService owns spawning and this service does nothing. Selecting another class in the lobby
-- rebuilds the character where it stands; dying respawns it at the lobby spawn.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

const SPAWN_PREFIX = "LOBBY-SPAWN"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const SPREAD = 6 -- studs: random offset around the point so a squad does not stack
const OUTFIT = "crew"
const TEMPLATE_NAME = "StarterCharacter"
const FALLBACK_CLASS = "class_dog"
const AVATAR_CLASSES = { "Accessory", "Clothing", "ShirtGraphic", "BodyColors", "CharacterMesh" }

type Job = { Player: Player, Keep: boolean }

const LobbyService = Modux.Service("LobbyService", {
	Require = { "RoleService", "PlayerService", "ProfileService" },
	Priority = 675,
})

function LobbyService:Setup()
	self.Queue = {} :: { Job }
	self.Working = false :: boolean
	self.Warned = false :: boolean
	self.Cleanups = {} :: { [Player]: { () -> () } }
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

-- Spawn ------------------------------------------------------------------------------------------------------------

function LobbyService:SpeciesOf(player: Player): string
	const profiles = self.Dependencies.ProfileService
	const profile = profiles:Get(player)
	const key = if profile ~= nil then profiles:SelectedClass(profile) else FALLBACK_CLASS
	const class = Content.Classes.ByKey[key] or Content.Classes.ByKey[FALLBACK_CLASS]
	return class.Species
end

function LobbyService:Spawn(player: Player, keep: boolean)
	if player.Parent == nil then
		return
	end
	local where: CFrame? = nil
	const old = player.Character
	if keep and old ~= nil and old.Parent ~= nil then
		where = old:GetPivot()
	end

	const template = CrewRig.Build(self:SpeciesOf(player), OUTFIT, { LookPack = "Day", Name = TEMPLATE_NAME })
	template.Parent = StarterPlayer
	const ok, problem = pcall(function()
		player:LoadCharacter()
	end)
	template:Destroy()
	if not ok then
		error(problem, 0)
	end

	const character = player.Character
	if character == nil then
		return
	end
	for _, className in AVATAR_CLASSES do
		for _, child in character:GetChildren() do
			if child:IsA(className) then
				child:Destroy()
			end
		end
	end
	const point = where or self:SpawnCFrame()
	if point ~= nil then
		character:PivotTo(point)
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.Died:Connect(function()
			task.delay(Players.RespawnTime, function()
				if player.Character == character then
					self:Enqueue(player, false)
				end
			end)
		end)
	end
end

-- One spawn at a time: StarterCharacter is a single slot.
function LobbyService:Enqueue(player: Player, keep: boolean)
	for _, job in self.Queue do
		if job.Player == player then
			return
		end
	end
	table.insert(self.Queue, { Player = player, Keep = keep })
	if self.Working then
		return
	end
	self.Working = true
	task.spawn(function()
		while #self.Queue > 0 do
			const job = table.remove(self.Queue, 1) :: Job
			const ok, problem = pcall(function()
				self:Spawn(job.Player, job.Keep)
			end)
			if not ok then
				warn(`[LobbyService] spawn of {job.Player.Name} failed: {problem}`)
			end
		end
		self.Working = false
	end)
end

function LobbyService:Forget(player: Player)
	const cleanups = self.Cleanups[player]
	self.Cleanups[player] = nil
	if cleanups ~= nil then
		for _, cleanup in cleanups do
			cleanup()
		end
	end
	for index = #self.Queue, 1, -1 do
		if self.Queue[index].Player == player then
			table.remove(self.Queue, index)
		end
	end
end

LobbyService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.RoleService:IsLobby() then
		return
	end

	Players.CharacterAutoLoads = false -- this service is the only spawner in the lobby
	const profiles = self.Dependencies.ProfileService
	profiles.Loaded:Connect(function(player, profile)
		self:Enqueue(player, false)
		-- another class selected in the lobby: rebuild where the player stands
		const stop = self.Libs.Charm.subscribe(function(): string
			return profiles:SelectedClass(profile)
		end, function()
			if player.Character ~= nil then
				self:Enqueue(player, true)
			end
		end)
		const bucket = self.Cleanups[player] or {}
		table.insert(bucket, stop)
		self.Cleanups[player] = bucket
	end)
	-- a character this service did not build (Studio autoload before CharacterAutoLoads = false): replaced
	self.Dependencies.PlayerService.CharacterAdded:Connect(function(player, character)
		if CollectionService:HasTag(character, CrewRig.Tag) then
			return
		end
		task.defer(function()
			if player.Character == character and profiles:Get(player) ~= nil then
				self:Enqueue(player, true)
			end
		end)
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Forget(player)
	end)
end)

return LobbyService
