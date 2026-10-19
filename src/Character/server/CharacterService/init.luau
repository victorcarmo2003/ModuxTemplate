--!strict
-- Crew character spawn (TASK-018; DEC-146, DEC-147, DEC-175, DEC-186; architecture.md §1.1, §8.3, §18.5, §18.9.2,
-- T25, T26). Run place only.
--
-- The player never wears the Roblox avatar: the character is CrewRig.Build(species of the locked class, "crew").
-- After the build this service only writes attributes; every client dresses the rig (RigController, T40, §18.9.4).
--
-- Spawn path (Provisional, Q-130 list): the built rig is parked as StarterPlayer.StarterCharacter for one
-- Player:LoadCharacter() call and removed right after. LoadCharacter adds the stock R6 Animate/Health scripts and
-- StarterCharacterScripts, wires the camera and never applies the avatar (no HumanoidDescription). Spawns run one at
-- a time (a single StarterCharacter slot). CharacterAutoLoads = false (T25): this service is the only spawner, and a
-- character that is not a crew rig (Studio autoload, someone calling LoadCharacter) is replaced.
--
-- Players never collide with Players anywhere on the map (DEC-175, Provisional scope "whole map"; T26).
-- WalkSpeed = ClassService WalkSpeed modifier; recomputed when package Tools enter or leave the player (bear, 3 packs)
-- and when the shift starts (owl by day). Freeze and Faint hold it at 0.
--
-- Wave 2 (TASK-061; architecture.md §19.3, §19.7, §19.20, T47, T54; FEAT-025; DEC-122, DEC-167, DEC-216):
--   SpawnPointFor(player, info)  PS-<seat> by day, PS-N<seat> by night, REV-<seat> on a repeated night (DEC-122)
--   CanSpawn                     only Active members: Down / Reviving / Spectator / Away get no character
--   SetLookPack(player, pack)    LookPack attribute (VitalService, by band); kept per UserId, applied on respawn
--   Faint(player)                ragdoll in place, no throw (DEC-216); the body stays down. The Fainted face is
--                                derived on every client from Vitals.State = Down (network.md §5.2)
--   RemoveBody(player, instant?) fade, then the character goes away (PickupHandler fallback T54; ambulance, wave 4)
--   Freeze(player, reason, on)   no walk / jump while any reason holds it (Cutscene...)
--   Prompt_Give anchor           runtime Interactable on each member's HRP, PromptAction = give_coffee (ItemService)
--   Animate ids                  Content.Animations.Locomotion.crew written into the stock R6 Animate (id "" = stock)
--
-- Wave 3 (TASK-100; architecture.md §8.2, §8.3, §19.16, §19.17; DEC-197, DEC-205):
--   Knock(player, seconds, impulse) car hit: ragdoll (sockets prebuilt in Prepare) + push, on the ground `seconds` s,
--                                then Content.Traffic.GetUpTime s getting up in place. Returns the stand-up time
--                                (server clock) for VitalService:SetKnocked; nil = not knocked. The owner's client
--                                already predicted it (TrafficController) and owns the physics: the server only flips
--                                the joints (everyone sees them) and PlatformStand; GettingUp is the client's
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Ragdoll = require(script.Ragdoll)
local Modux = require(ServerScriptService.server.Modux)

export type Pack = CrewRig.Pack
-- RoundService:Info() (data.md §3.3 "Sh")
export type ShiftInfo = { Day: number, Night: number, IsNight: boolean, Attempt: number }

const COLLISION_GROUP = "Players"
const OUTFIT = "crew"
const DEFAULT_PACK: Pack = "Day"
const SPAWN_DAY = "PS-"
const SPAWN_NIGHT = "PS-N"
const SPAWN_REPEAT = "REV-"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const FALLBACK_CLASS = "class_dog"
const TEMPLATE_NAME = "StarterCharacter"
-- Avatar pieces the engine could add on top of the rig. CrewRig accessories are BaseParts, never these classes.
const AVATAR_CLASSES = { "Accessory", "Clothing", "ShirtGraphic", "BodyColors", "CharacterMesh" }
-- Runtime Interactable on the HRP of each member (architecture.md §19.8 "Dar"; Content.Actions give_coffee).
const GIVE_ANCHOR = "Prompt_Give"
const GIVE_ACTION = "give_coffee"
const INTERACTABLE_TAG = "Interactable"
-- Character attribute read by CharacterController (TASK-063: controls locked while frozen). Provisional: attribute
-- name proposed to the architect for network.md §5.2 (TASK-061 note on the board).
const FROZEN_ATTRIBUTE = "Frozen"
-- Body fade of RemoveBody. Provisional presentation timing (TASK-061 note: candidate for Content.Revive).
const BODY_FADE = 1
-- Stock R6 Animate: StringValue folder per role, one or more Animation children (idle has Animation1/Animation2).
const ANIMATE_NAME = "Animate"
const ANIMATE_WAIT = 5

const CharacterService = Modux.Service("CharacterService", {
	Require = { "PlayerService", "PlaceService", "RunStateService", "ClassService", "RoundService", "SkinService" },
	Priority = 715,
})

function CharacterService:Setup()
	self.Queue = {} :: { Player }
	self.Working = false :: boolean
	-- players inside LoadCharacter right now: their CharacterAdded is ours
	self.Spawning = {} :: { [Player]: boolean }
	-- point id forced on the next spawn (wave 4 revive: "REV-n" next to the ambulance)
	self.ForcedPoint = {} :: { [Player]: string }
	-- per character life: Died, tool and descendant listeners
	self.Connections = {} :: { [Player]: { RBXScriptConnection } }
	-- LookPack per UserId (survives Away and respawn; VitalService writes the band, DEC-167)
	self.Packs = {} :: { [number]: Pack }
	-- Freeze reasons per player (all must be released)
	self.Frozen = {} :: { [Player]: { [string]: boolean } }
	-- characters that fainted (never stand up again: Revive spawns a new one)
	self.Fainted = setmetatable({}, { __mode = "k" }) :: any
	-- characters knocked down by a car (the token tells a stale timer from the current knock)
	self.Knocked = setmetatable({}, { __mode = "k" }) :: any
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

-- Only Active members get a character (architecture.md §19.3): Down, Reviving, Spectator and Away do not.
function CharacterService:CanSpawn(player: Player): boolean
	if player.Parent == nil then
		return false
	end
	const member = self.Dependencies.RunStateService:GetMember(player)
	if member == nil or member.State ~= "Active" then
		return false
	end
	return true
end

-- Live crew character of the player, or nil.
function CharacterService:CharacterOf(player: Player): Model?
	const character = player.Character
	if character == nil or not self:IsCrew(character) or not character:IsDescendantOf(workspace) then
		return nil
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character
end

function CharacterService:IsFainted(player: Player): boolean
	const character = player.Character
	return character ~= nil and self.Fainted[character] == true
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

-- Class skin worn with the locked class (SkinService; owner request 2026-10-17): nil = the crew uniform. SkinEquip is
-- refused in the Run (outside dev mode), so the skin stays the same for the whole run like the class.
function CharacterService:SkinOf(player: Player): string?
	return self.Dependencies.SkinService:SkinOf(player, self.Dependencies.ClassService:GetClass(player))
end

-- Spawn points ----------------------------------------------------------------------------------------------------

-- "<prefix><n>" with a whole n only: "PS-" must not pick "PS-N1".
local function isSeatPoint(id: string, prefix: string): boolean
	return string.sub(id, 1, #prefix) == prefix and string.match(string.sub(id, #prefix + 1), "^%d+$") ~= nil
end

-- Point prefix for a shift (DEC-122: everyone wakes up standing next to the trailer on a repeated night).
function CharacterService:SpawnPrefix(info: ShiftInfo): string
	if info.IsNight and info.Attempt > 0 then
		return SPAWN_REPEAT
	elseif info.IsNight then
		return SPAWN_NIGHT
	end
	return SPAWN_DAY
end

-- First point of a family: <prefix><seat>, any <prefix><n>, nil.
local function familyPoint(prefix: string, seat: number?): CFrame?
	if seat ~= nil then
		const point = MapIndex.FindPoint(prefix .. seat)
		if point ~= nil then
			return point
		end
	end
	const points = MapIndex.Points(prefix)
	const ids: { string } = {}
	for id in points do
		if isSeatPoint(id, prefix) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	if #ids > 0 then
		return points[ids[1]]
	end
	return nil
end

-- Seat in the roster: stable for the whole run (reconnect and respawn land on the same n).
-- PS-n by day, PS-Nn by night, REV-n on a repeated night (architecture.md §19.3; MAP-01 §5.1). A missing point
-- (validated at boot, §18.7) falls back to the same family, then to PS-n.
function CharacterService:SpawnPointFor(player: Player, info: ShiftInfo): CFrame?
	if not MapIndex.HasBinding() then
		warn("[CharacterService] no MapBinding: spawning at the engine default")
		return nil
	end
	const seat = table.find(self.Dependencies.RunStateService.Roster(), player.UserId)
	const prefix = self:SpawnPrefix(info)
	local point = familyPoint(prefix, seat)
	if point == nil and prefix ~= SPAWN_DAY then
		warn(`[CharacterService] no {prefix}* point in the binding; using {SPAWN_DAY}*`)
		point = familyPoint(SPAWN_DAY, seat)
	end
	if point == nil then
		warn(`[CharacterService] no {SPAWN_DAY}* point in the binding`)
	end
	return point
end

function CharacterService:PointFor(player: Player): CFrame?
	const forced = self.ForcedPoint[player]
	if forced ~= nil then
		self.ForcedPoint[player] = nil
		const point = if MapIndex.HasBinding() then MapIndex.FindPoint(forced) else nil
		if point ~= nil then
			return point
		end
		warn(`[CharacterService] forced point {forced} not in the binding`)
	end
	return self:SpawnPointFor(player, self.Dependencies.RoundService:Info())
end

-- Spawn -----------------------------------------------------------------------------------------------------------

-- point: optional MapPoint id for this spawn only (wave 4 revive, "REV-n"); default SpawnPointFor.
function CharacterService:Spawn(player: Player, point: string?)
	if not self:CanSpawn(player) then
		return
	end
	if point ~= nil then
		self.ForcedPoint[player] = point
	end
	const species = self:SpeciesOf(player)
	const template = CrewRig.Build(
		species,
		OUTFIT,
		{ LookPack = self:PackOf(player), Name = TEMPLATE_NAME, Skin = self:SkinOf(player) }
	)
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
		self.ForcedPoint[player] = nil
		error(problem, 0)
	end

	const character = player.Character
	if character == nil or not self:IsCrew(character) then
		self.ForcedPoint[player] = nil
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
	-- the Neck motor goes off in a ragdoll: it must never kill (sanity is not health, §8.3)
	humanoid.RequiresNeck = false
	Ragdoll.Prepare(character)

	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end

	character:SetAttribute("LookPack", self:PackOf(player))

	const point = self:PointFor(player)
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
	-- CanSpawn keeps a Down/Spectator member without a character.
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

	self:AddGiveAnchor(character)
	self:ApplyAnimations(character, bucket)
	self:ApplyFreeze(player)
	self:RefreshSpeed(player)
end

-- Prompt_Give (architecture.md §19.8): the InteractionService registers it by tag; ItemService owns give_coffee and
-- its PromptEnabled. The owner's client hides its own anchor.
function CharacterService:AddGiveAnchor(character: Model)
	const root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") or root:FindFirstChild(GIVE_ANCHOR) ~= nil then
		return
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = GIVE_ANCHOR
	anchor:SetAttribute("PromptAction", GIVE_ACTION)
	anchor.Parent = root
	CollectionService:AddTag(anchor, INTERACTABLE_TAG)
end

-- Animations (architecture.md §19.20, T47) -------------------------------------------------------------------------

-- Locomotion role -> AnimationId from Content.Animations (crew set). Empty ids are left out (stock R6 stays).
local function crewLocomotionIds(): { [string]: string }
	const ids: { [string]: string } = {}
	for role, key in Content.Animations.Locomotion.crew :: { [string]: string } do
		const row = Content.Animations.ByKey[key]
		if row ~= nil and row.Id ~= "" then
			ids[role] = row.Id
		end
	end
	return ids
end

local function writeAnimate(animate: Instance, ids: { [string]: string })
	for role, id in ids do
		const folder = animate:FindFirstChild(role)
		if folder == nil then
			continue
		end
		for _, child in folder:GetChildren() do
			if child:IsA("Animation") then
				child.AnimationId = id
			end
		end
	end
end

-- Server never plays a player animation; it only writes the ids the stock Animate reads (T47).
function CharacterService:ApplyAnimations(character: Model, bucket: { RBXScriptConnection })
	const ids = crewLocomotionIds()
	if next(ids) == nil then
		return
	end
	const animate = character:FindFirstChild(ANIMATE_NAME)
	if animate ~= nil then
		writeAnimate(animate, ids)
		return
	end
	-- the engine may parent Animate after CharacterAdded
	local connection: RBXScriptConnection? = nil
	connection = character.ChildAdded:Connect(function(child)
		if child.Name == ANIMATE_NAME then
			if connection ~= nil then
				connection:Disconnect()
			end
			-- its StringValue children may arrive in the same frame
			task.defer(writeAnimate, child, ids)
		end
	end)
	table.insert(bucket, connection :: RBXScriptConnection)
	task.delay(ANIMATE_WAIT, function()
		if connection ~= nil and connection.Connected then
			connection:Disconnect()
			warn(`[CharacterService] {character.Name} has no {ANIMATE_NAME}: stock locomotion stays`)
		end
	end)
end

-- Look (DEC-167) -------------------------------------------------------------------------------------------------

function CharacterService:PackOf(player: Player): Pack
	return self.Packs[player.UserId] or DEFAULT_PACK
end

-- VitalService writes the sanity band (day: always Day). Kept per UserId and applied again on every spawn.
function CharacterService:SetLookPack(player: Player, pack: Pack)
	if table.find(Content.Looks.Packs, pack) == nil then
		warn(`[CharacterService] SetLookPack: unknown pack {tostring(pack)}`)
		return
	end
	self.Packs[player.UserId] = pack
	const character = player.Character
	if character ~= nil and self:IsCrew(character) then
		character:SetAttribute("LookPack", pack)
	end
end

-- Freeze --------------------------------------------------------------------------------------------------------

function CharacterService:IsFrozen(player: Player): boolean
	const reasons = self.Frozen[player]
	return reasons ~= nil and next(reasons) ~= nil
end

-- Holds the player in place for a reason (Cutscene...). Released only when every reason is off.
function CharacterService:Freeze(player: Player, reason: string, on: boolean)
	local reasons = self.Frozen[player]
	if on then
		if reasons == nil then
			reasons = {}
			self.Frozen[player] = reasons
		end
		reasons[reason] = true
	elseif reasons ~= nil then
		reasons[reason] = nil
		if next(reasons) == nil then
			self.Frozen[player] = nil
		end
	end
	self:ApplyFreeze(player)
	self:RefreshSpeed(player)
end

function CharacterService:ApplyFreeze(player: Player)
	const character = player.Character
	if character == nil or not self:IsCrew(character) then
		return
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	const frozen = self:IsFrozen(player) or self.Fainted[character] == true or self.Knocked[character] ~= nil
	character:SetAttribute(FROZEN_ATTRIBUTE, if self:IsFrozen(player) then true else nil)
	if frozen then
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	end
end

-- Faint and body (DEC-216, T54) ----------------------------------------------------------------------------------

-- Sanity 0 (VitalService, Down or Spectator): ragdoll in place, no throw, controls off. The server takes the
-- physics of the body so the client cannot move it. The body stays until RemoveBody (or a new spawn).
function CharacterService:Faint(player: Player)
	const character = self:CharacterOf(player)
	if character == nil or self.Fainted[character] then
		return
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	const root = character:FindFirstChild("HumanoidRootPart")
	self.Fainted[character] = true
	-- a knocked body that faints stays down: the knock timers see the token gone
	self.Knocked[character] = nil

	humanoid:UnequipTools()
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid.PlatformStand = true
	self:ApplyFreeze(player)

	if root ~= nil and root:IsA("BasePart") then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		const owned, problem = pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if not owned then
			warn(`[CharacterService] Faint: network owner of {player.Name}: {problem}`)
		end
	end
	Ragdoll.Enable(character)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end

-- Knock (car hit; architecture.md §8.2, §19.17; DEC-197) ----------------------------------------------------------

local function finite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

function CharacterService:IsKnocked(player: Player): boolean
	const character = player.Character
	return character ~= nil and self.Knocked[character] ~= nil
end

-- TrafficService, after validating CarHit: ragdoll + push for `seconds` s, then Content.Traffic.GetUpTime s standing
-- up in place. impulse = velocity change in studs/s (direction of the car + up). Returns the stand-up time (server
-- clock) or nil when the player cannot be knocked: no live body, fainted, frozen (hidden, cutscene), already down.
-- Never unequips: ItemService:DropHeld runs right after and needs the Tool in the hand.
function CharacterService:Knock(player: Player, seconds: number, impulse: Vector3): number?
	if type(seconds) ~= "number" or not finite(seconds) or seconds <= 0 then
		return nil
	end
	if typeof(impulse) ~= "Vector3" or not (finite(impulse.X) and finite(impulse.Y) and finite(impulse.Z)) then
		return nil
	end
	const character = self:CharacterOf(player)
	if character == nil or self.Fainted[character] or self.Knocked[character] ~= nil or self:IsFrozen(player) then
		return nil
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	const root = character:FindFirstChild("HumanoidRootPart")
	const getUp = math.max(0, Content.Traffic.GetUpTime)
	const knock = { Until = workspace:GetServerTimeNow() + seconds + getUp }
	self.Knocked[character] = knock

	humanoid.RequiresNeck = false
	humanoid.PlatformStand = true
	Ragdoll.Enable(character)
	self:ApplyFreeze(player)
	self:RefreshSpeed(player)
	-- the owner's client already pushed its own body; this covers a server-owned body
	if root ~= nil and root:IsA("BasePart") and impulse.Magnitude > 0 then
		root:ApplyImpulse(impulse * root.AssemblyMass)
	end

	task.delay(seconds, function()
		if self.Knocked[character] ~= knock or self.Fainted[character] then
			return
		end
		Ragdoll.Disable(character)
		humanoid.PlatformStand = false
	end)
	task.delay(seconds + getUp, function()
		if self.Knocked[character] ~= knock then
			return
		end
		self.Knocked[character] = nil
		if player.Character == character then
			self:ApplyFreeze(player)
			self:RefreshSpeed(player)
		end
	end)
	return knock.Until
end

-- Body goes away (PickupHandler fallback after Revive.BodyFallback, T54; AmbulanceService on Load, wave 4).
-- Fades unless instant; the player stays without a character until someone spawns it.
function CharacterService:RemoveBody(player: Player, instant: boolean?)
	const character = player.Character
	if character == nil then
		return
	end
	self:Disconnect(player)

	local function remove()
		if player.Character == character then
			player.Character = nil
		end
		character:Destroy()
	end
	if instant == true then
		remove()
		return
	end
	const tween = TweenInfo.new(BODY_FADE, Enum.EasingStyle.Linear)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, tween, { Transparency = 1 }):Play()
		elseif descendant:IsA("Decal") then
			TweenService:Create(descendant, tween, { Transparency = 1 }):Play()
		end
	end
	task.delay(BODY_FADE, remove)
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

-- WalkSpeed from the class (rabbit 18, cat 15, bear 14 with 3 packages, owl 15 by day); 0 while frozen, fainted or
-- knocked down.
function CharacterService:RefreshSpeed(player: Player)
	const character = player.Character
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if character == nil or humanoid == nil then
		return
	end
	if self:IsFrozen(player) or self.Fainted[character] or self.Knocked[character] ~= nil then
		humanoid.WalkSpeed = 0
		return
	end
	humanoid.WalkSpeed = self.Dependencies.ClassService:GetModifier(player, "WalkSpeed", nil, {
		Packages = self:CountPackages(player),
		IsNight = self.Dependencies.RoundService:IsNight(),
	})
end

-- Life state and shifts ----------------------------------------------------------------------------------------

-- Back to Active (repeated night restore, wave 4 revive, return from Away): a member without a standing body spawns.
function CharacterService:OnLifeChanged(userId: number, new: string)
	if new ~= "Active" then
		return
	end
	-- deferred: the restore that changed the state finishes first, so SpawnPointFor reads the new shift
	task.defer(function()
		const player = Players:GetPlayerByUserId(userId)
		if player == nil or not self:CanSpawn(player) then
			return
		end
		-- already on its way (MemberJoined of a return, ShiftStarted of a repeated night)
		if self.Spawning[player] or table.find(self.Queue, player) ~= nil then
			return
		end
		if self:CharacterOf(player) == nil or self:IsFainted(player) then
			self:Enqueue(player)
		end
	end)
end

-- Repeated night (DEC-122): everyone wakes up standing at REV-n. Standing bodies move there; fainted or missing
-- ones spawn there.
function CharacterService:OnShiftStarted(info: ShiftInfo)
	for _, player in Players:GetPlayers() do
		if self:CharacterOf(player) ~= nil then
			self:RefreshSpeed(player)
		end
	end
	if not (info.IsNight and info.Attempt > 0) then
		return
	end
	for _, player in Players:GetPlayers() do
		if not self:CanSpawn(player) then
			continue
		end
		const character = self:CharacterOf(player)
		if character == nil or self.Fainted[character] then
			self:Enqueue(player)
			continue
		end
		const point = self:SpawnPointFor(player, info)
		if point ~= nil then
			character:PivotTo(point + SPAWN_LIFT)
		end
	end
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
		self.ForcedPoint[player] = nil
		self.Frozen[player] = nil
		const index = table.find(self.Queue, player)
		if index ~= nil then
			table.remove(self.Queue, index)
		end
	end)
	const runState = self.Dependencies.RunStateService
	-- first admission and reconnect (RunStateService fires after the profile loaded); CanSpawn filters the state
	runState.MemberJoined:Connect(function(player)
		self:Enqueue(player)
	end)
	runState.LifeChanged:Connect(function(userId, _old, new)
		self:OnLifeChanged(userId, new)
	end)
	-- RoundService (750) ran its Setup before this OnInit (§19.0 rule 2)
	self.Dependencies.RoundService.ShiftStarted:Connect(function(info)
		self:OnShiftStarted(info)
	end)
end)

return CharacterService
