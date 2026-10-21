--!strict
-- Invisible wall around the lobby pad rooms (owner request 2026-10-21, Provisional; emends DEC-344 (d), see DEC-348).
-- Server only, server-authoritative: the walls and the collision groups live here, PartyService decides who goes where.
--
-- Every pad gets a ring of Content.Lobby.Squad.Barrier.Segments invisible anchored Parts (Workspace.PadBarriers.Pad<n>,
-- built from LobbyZones, rebuilt when LobbyZones.Version() moves), one collision group per pad:
--   PadWall<n>   the ring of pad n
--   PadCage<n>   a member of the room of pad n standing on it: always collides with PadWall<n> (cannot leave)
--   PadGuest<n>  a member of that room off the pad, or a friend of its leader near a friends-only room: passes PadWall<n>
-- Players (the lobby characters' own group, LobbyService / CharacterService, DEC-175: players walk through each other)
-- collides with PadWall<n> only while the room of pad n is not Open (Friends / Invite / Closed); PadGuest<n> follows it
-- for the other rings. No room on the pad = the ring stops nobody. Cage and guest groups never collide with Players nor
-- with each other (players still pass through players). Default (props, NPCs) never meets a ring.
-- Character parts get the group of their player; the root is checked every sync, since LobbyService paints new parts
-- Players too. The walls never take queries (CanQuery off while colliding is not allowed by the engine, so they stay
-- thin and invisible instead).
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)

const SETTINGS = Content.Lobby.Squad.Barrier
const FOLDER = "PadBarriers"
const BASE = "Players" -- the lobby characters' group (LobbyService COLLISION_GROUP)
const DEFAULT = "Default"

local Barrier = {}

-- The group of a character outside any room.
Barrier.Base = BASE

local pads = 0
local folder: Folder? = nil
local built = -1 -- LobbyZones.Version() the rings were built for
const blocking: { [number]: boolean } = {}
-- Player -> group their character wears
const wanted: { [Player]: string } = {}
const watched: { [Player]: { RBXScriptConnection } } = {}

local function wall(n: number): string
	return `PadWall{n}`
end

function Barrier.Cage(n: number): string
	return `PadCage{n}`
end

function Barrier.Guest(n: number): string
	return `PadGuest{n}`
end

-- Registers the groups of `count` pads (once, at OnStart of a lobby).
function Barrier.Setup(count: number)
	pads = count
	const riders: { string } = {} -- cage + guest groups
	if not PhysicsService:IsCollisionGroupRegistered(BASE) then
		PhysicsService:RegisterCollisionGroup(BASE) -- LobbyService may set itself up later
	end
	for n = 1, count do
		for _, name in { wall(n), Barrier.Cage(n), Barrier.Guest(n) } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
		table.insert(riders, Barrier.Cage(n))
		table.insert(riders, Barrier.Guest(n))
	end
	for _, a in riders do
		PhysicsService:CollisionGroupSetCollidable(a, BASE, false)
		for _, b in riders do
			PhysicsService:CollisionGroupSetCollidable(a, b, false)
		end
	end
	for n = 1, count do
		for m = 1, count do
			PhysicsService:CollisionGroupSetCollidable(Barrier.Cage(m), wall(n), m == n)
			PhysicsService:CollisionGroupSetCollidable(Barrier.Guest(m), wall(n), false)
			PhysicsService:CollisionGroupSetCollidable(wall(m), wall(n), false)
		end
		PhysicsService:CollisionGroupSetCollidable(BASE, wall(n), false)
		PhysicsService:CollisionGroupSetCollidable(DEFAULT, wall(n), false)
		blocking[n] = false
	end
	const root = Instance.new("Folder")
	root.Name = FOLDER
	root.Parent = workspace
	folder = root
end

local function ring(n: number, zone: LobbyZones.Zone, parent: Instance)
	const model = Instance.new("Model")
	model.Name = `Pad{n}`
	const radius = zone.Radius + SETTINGS.Gap + SETTINGS.Thickness / 2
	const step = 2 * math.pi / SETTINGS.Segments
	-- each piece a little wider than its share of the circle: no slit between two pieces
	const width = 2 * radius * math.tan(step / 2) + SETTINGS.Thickness
	const base = zone.Center + Vector3.new(0, SETTINGS.Height / 2, 0)
	for index = 1, SETTINGS.Segments do
		const angle = (index - 1) * step
		const out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		const part = Instance.new("Part")
		part.Name = `Wall{index}`
		part.Size = Vector3.new(width, SETTINGS.Height, SETTINGS.Thickness)
		-- LookVector = outward: the thin side (Z) faces the centre
		part.CFrame = CFrame.lookAt(base + out * radius, base + out * (radius + 1))
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Locked = true
		part.CollisionGroup = wall(n)
		part.Parent = model
	end
	model.Parent = parent
end

-- Rebuilds the rings when a pad moved (cheap otherwise: one integer compare).
function Barrier.Build()
	const root = folder
	if root == nil or LobbyZones.Version() == built then
		return
	end
	root:ClearAllChildren()
	for n = 1, pads do
		const zone = LobbyZones.Platform(n)
		if zone ~= nil then
			ring(n, zone, root)
		end
	end
	built = LobbyZones.Version()
end

-- The ring of pad n stops outsiders (the room is not Open).
function Barrier.Block(n: number, on: boolean)
	if pads == 0 or n < 1 or n > pads or blocking[n] == on then
		return
	end
	blocking[n] = on
	PhysicsService:CollisionGroupSetCollidable(BASE, wall(n), on)
	for m = 1, pads do
		if m ~= n then
			PhysicsService:CollisionGroupSetCollidable(Barrier.Guest(m), wall(n), on)
		end
	end
end

local function paint(part: Instance, group: string)
	if part:IsA("BasePart") and part.CollisionGroup ~= group then
		part.CollisionGroup = group
	end
end

local function paintCharacter(character: Model?, group: string)
	if character == nil then
		return
	end
	for _, part in character:GetDescendants() do
		paint(part, group)
	end
end

local function watch(player: Player)
	if watched[player] ~= nil then
		return
	end
	local added: RBXScriptConnection? = nil
	local function hook(character: Model)
		if added ~= nil then
			added:Disconnect()
		end
		added = character.DescendantAdded:Connect(function(part)
			paint(part, wanted[player] or BASE)
		end)
		paintCharacter(character, wanted[player] or BASE)
	end
	const spawned = player.CharacterAdded:Connect(hook)
	watched[player] = { spawned }
	if player.Character ~= nil then
		hook(player.Character)
	end
	-- the DescendantAdded hook of the current character goes with it
	table.insert(
		watched[player],
		player.CharacterRemoving:Connect(function()
			if added ~= nil then
				added:Disconnect()
				added = nil
			end
		end)
	)
end

-- The group the player's character wears (Base, Cage(n), Guest(n)). Repaints when it changed or when another
-- service painted the root over it.
function Barrier.Assign(player: Player, group: string)
	watch(player)
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	const stale = root ~= nil and root:IsA("BasePart") and root.CollisionGroup ~= group
	if wanted[player] == group and not stale then
		return
	end
	wanted[player] = group
	paintCharacter(character, group)
end

function Barrier.Forget(player: Player)
	wanted[player] = nil
	const connections = watched[player]
	watched[player] = nil
	if connections ~= nil then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

-- Where Exit puts a player down: just outside the ring of pad n, on the side that faces the rest of the lobby (the
-- other zones' centre), else toward -X. nil = no pad.
function Barrier.Outside(n: number): Vector3?
	const zone = LobbyZones.Platform(n)
	if zone == nil then
		return nil
	end
	local sum = Vector3.zero
	local count = 0
	for _, other in LobbyZones.List() do
		if other.Platform == 0 then
			sum += other.Center
			count += 1
		end
	end
	local direction = -Vector3.xAxis
	if count > 0 then
		const toward = sum / count - zone.Center
		const flat = Vector3.new(toward.X, 0, toward.Z)
		if flat.Magnitude > 1e-3 then
			direction = flat.Unit
		end
	end
	const distance = zone.Radius + SETTINGS.Gap + SETTINGS.Thickness + SETTINGS.ExitStep
	return zone.Center + direction * distance
end

-- Puts the player's character down at `position` (feet on it), facing away from pad n's centre.
function Barrier.Place(player: Player, position: Vector3, center: Vector3)
	const character = player.Character
	if character == nil then
		return
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	const lift = if humanoid ~= nil then humanoid.HipHeight + 2 else 3
	const at = position + Vector3.new(0, lift, 0)
	local facing = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	if facing.Magnitude < 1e-3 then
		facing = -Vector3.zAxis
	end
	character:PivotTo(CFrame.lookAt(at, at + facing.Unit))
end

-- Back to the middle of pad n (a member seen past the wall: lag, an exploit, a glitch).
function Barrier.Return(player: Player, n: number)
	const zone = LobbyZones.Platform(n)
	if zone == nil then
		return
	end
	Barrier.Place(player, zone.Center, zone.Center)
end

return table.freeze(Barrier)
