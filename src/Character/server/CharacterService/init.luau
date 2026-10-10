--!strict
-- Crew character spawn (TASK-018; DEC-146, DEC-147, DEC-175, DEC-186; architecture.md §1.1, §8.3, §18.5, §18.9.2,
-- T25, T26). Run place only.
--
-- The player never wears the Roblox avatar: the character is CrewRig.Build(species of the locked class, "crew") with
-- LookPack = "Day" (wave 1). After the build this service only writes attributes; every client dresses the rig
-- (RigController, T40, §18.9.4).
--
-- Spawn path (Provisional, Q-130 list): the built rig is parked as StarterPlayer.StarterCharacter for one
-- Player:LoadCharacter() call and removed right after. LoadCharacter adds the stock R6 Animate/Health scripts and
-- StarterCharacterScripts, wires the camera and never applies the avatar (no HumanoidDescription). Spawns run one at
-- a time (a single StarterCharacter slot). CharacterAutoLoads = false (T25): this service is the only spawner, and a
-- character that is not a crew rig (Studio autoload, someone calling LoadCharacter) is replaced.
--
-- Spawn point: PS-<seat in the roster> (MAP-01 §5.1), HumanoidRootPart at point + 3 studs facing the point's front.
-- Players never collide with Players anywhere on the map (DEC-175, Provisional scope "whole map"; T26).
-- WalkSpeed = ClassService WalkSpeed modifier; recomputed when package Tools enter or leave the player (bear, 3 packs).
-- No ragdoll joints yet (§8.3, Knock is wave 2 with TrafficService).
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

const COLLISION_GROUP = "Players"
const OUTFIT = "crew"
const LOOK_PACK = "Day" -- wave 1: always Day; wave 2 VitalService writes the sanity band (DEC-167)
const SPAWN_PREFIX = "PS-"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const FALLBACK_CLASS = "class_dog"
const TEMPLATE_NAME = "StarterCharacter"
-- Avatar pieces the engine could add on top of the rig. CrewRig accessories are BaseParts, never these classes.
const AVATAR_CLASSES = { "Accessory", "Clothing", "ShirtGraphic", "BodyColors", "CharacterMesh" }

const CharacterService = Modux.Service("CharacterService", {
	Require = { "PlayerService", "PlaceService", "RunStateService", "ClassService" },
	Priority = 715,
})

function CharacterService:Setup()
	self.Queue = {} :: { Player }
	self.Working = false :: boolean
	-- players inside LoadCharacter right now: their CharacterAdded is ours
	self.Spawning = {} :: { [Player]: boolean }
	-- per character life: Died, tool and descendant listeners
	self.Connections = {} :: { [Player]: { RBXScriptConnection } }
end

-- Collision groups (T26, DEC-175) ----------------------------------------------------------------------------------

function CharacterService:SetupCollision()
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end

local function setGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = COLLISION_GROUP
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

function CharacterService:Disconnect(player: Player)
	const bucket = self.Connections[player]
	if bucket == nil then
		return
	end
	for _, connection in bucket do
		connection:Disconnect()
	end
	self.Connections[player] = nil
end

function CharacterService:IsCrew(character: Model): boolean
	return CollectionService:HasTag(character, CrewRig.Tag) and character:GetAttribute("Outfit") == OUTFIT
end

-- Members only, alive in the run. Down/Reviving/Spectator are spawned by their wave-2 owners.
function CharacterService:CanSpawn(player: Player): boolean
	if player.Parent == nil then
		return false
	end
	const member = self.Dependencies.RunStateService:GetMember(player)
	return member ~= nil and member.State == "Active"
end

-- Spawns run one at a time: StarterCharacter is a single slot.
function CharacterService:Enqueue(player: Player)
	if table.find(self.Queue, player) == nil then
		table.insert(self.Queue, player)
	end
	if self.Working then
		return
	end
	self.Working = true
	task.spawn(function()
		while #self.Queue > 0 do
			const nextPlayer = table.remove(self.Queue, 1) :: Player
			const ok, problem = pcall(function()
				self:Spawn(nextPlayer)
			end)
			if not ok then
				warn(`[CharacterService] spawn of {nextPlayer.Name} failed: {problem}`)
			end
		end
		self.Working = false
	end)
end

-- Species of the class locked for the run (ClassService:GetClass locks it on first read, TASK-017).
function CharacterService:SpeciesOf(player: Player): string
	const class = Content.Classes.ByKey[self.Dependencies.ClassService:GetClass(player)]
	if class ~= nil then
		return class.Species
	end
	return Content.Classes.ByKey[FALLBACK_CLASS].Species
end

-- PS-<seat>: the seat in the roster is stable for the whole run (reconnect and respawn land on the same point).
function CharacterService:SpawnPoint(player: Player): CFrame?
	if not MapIndex.HasBinding() then
		warn("[CharacterService] no MapBinding: spawning at the engine default (TASK-005 pending)")
		return nil
	end
	const seat = table.find(self.Dependencies.RunStateService.Roster(), player.UserId)
	if seat ~= nil then
		const point = MapIndex.FindPoint(SPAWN_PREFIX .. seat)
		if point ~= nil then
			return point
		end
	end
	-- seat point missing (validated at boot, §18.7): any PS-* point
	for _, point in MapIndex.Points(SPAWN_PREFIX) do
		return point
	end
	warn(`[CharacterService] no {SPAWN_PREFIX}* point in the binding`)
	return nil
end

function CharacterService:Spawn(player: Player)
	if not self:CanSpawn(player) then
		return
	end
	const species = self:SpeciesOf(player)
	const template = CrewRig.Build(species, OUTFIT, { LookPack = LOOK_PACK, Name = TEMPLATE_NAME })
	const humanoid = template:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.BreakJointsOnDeath = false -- §8.3

	self:Disconnect(player)
	self.Spawning[player] = true
	template.Parent = StarterPlayer
	const ok, problem = pcall(function()
		player:LoadCharacter()
	end)
	template:Destroy()
	self.Spawning[player] = nil
	if not ok then
		error(problem, 0)
	end

	const character = player.Character
	if character == nil or not self:IsCrew(character) then
		error("LoadCharacter did not produce the crew rig", 0)
	end
	self:Prepare(player, character)
end

function CharacterService:Prepare(player: Player, character: Model)
	for _, className in AVATAR_CLASSES do
		for _, child in character:GetChildren() do
			if child:IsA(className) then
				child:Destroy()
			end
		end
	end

	const humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.BreakJointsOnDeath = false

	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end

	const point = self:SpawnPoint(player)
	if point ~= nil then
		character:PivotTo(point + SPAWN_LIFT)
	end

	const bucket: { RBXScriptConnection } = {}
	self.Connections[player] = bucket
	table.insert(bucket, character.DescendantAdded:Connect(setGroup))

	-- packages carried (bear speed): Tools move between Backpack and character
	local function refresh(child: Instance)
		if child:IsA("Tool") then
			self:RefreshSpeed(player)
		end
	end
	table.insert(bucket, character.ChildAdded:Connect(refresh))
	table.insert(bucket, character.ChildRemoved:Connect(refresh))
	const backpack = player:FindFirstChildOfClass("Backpack")
	if backpack ~= nil then
		table.insert(bucket, backpack.ChildAdded:Connect(refresh))
		table.insert(bucket, backpack.ChildRemoved:Connect(refresh))
	end

	-- Sanity never kills (§8.3); only the reset button does. Back as the crew rig, never the avatar (T018-04).
	table.insert(
		bucket,
		humanoid.Died:Connect(function()
			task.delay(Players.RespawnTime, function()
				if player.Character == character then
					self:Enqueue(player)
				end
			end)
		end)
	)

	self:RefreshSpeed(player)
end

-- Speed ------------------------------------------------------------------------------------------------------------

function CharacterService:CountPackages(player: Player): number
	local count = 0
	local function scan(container: Instance?)
		if container == nil then
			return
		end
		for _, child in container:GetChildren() do
			if not child:IsA("Tool") then
				continue
			end
			const key = child:GetAttribute("Item")
			const item = if typeof(key) == "string" then Content.Items.ByKey[key] else nil
			if item ~= nil and item.Category == "Package" then
				count += 1
			end
		end
	end
	scan(player.Character)
	scan(player:FindFirstChildOfClass("Backpack"))
	return count
end

-- WalkSpeed from the class (rabbit 18, cat 15, bear 14 with 3 packages, owl 15 by day). Wave 1 has no night.
function CharacterService:RefreshSpeed(player: Player)
	const character = player.Character
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	humanoid.WalkSpeed = self.Dependencies.ClassService:GetModifier(player, "WalkSpeed", nil, {
		Packages = self:CountPackages(player),
		IsNight = false,
	})
end

-- Foreign character (avatar autoload in Studio, LoadCharacter from elsewhere): never shown.
function CharacterService:OnCharacter(player: Player, character: Model)
	if self.Spawning[player] or self:IsCrew(character) then
		return
	end
	task.defer(function()
		if player.Character == character then
			player.Character = nil
		end
		character:Destroy()
		if self:CanSpawn(player) then
			self:Enqueue(player)
		end
	end)
end

CharacterService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	Players.CharacterAutoLoads = false -- T25 (also a place setting, §1.1)
	self:SetupCollision()

	const playerService = self.Dependencies.PlayerService
	playerService.CharacterAdded:Connect(function(player, character)
		self:OnCharacter(player, character)
	end)
	playerService.PlayerRemoving:Connect(function(player)
		self:Disconnect(player)
		self.Spawning[player] = nil
		const index = table.find(self.Queue, player)
		if index ~= nil then
			table.remove(self.Queue, index)
		end
	end)
	-- first admission and reconnect (RunStateService fires after the profile loaded)
	self.Dependencies.RunStateService.MemberJoined:Connect(function(player)
		self:Enqueue(player)
	end)
end)

return CharacterService
