--!strict
-- Trailer door (user request 2026-10-11, Provisional; MAP-01 §5.5 "porta dos fundos", X 47..51 on the south wall).
-- The back door of the trailer never opened (DEC-054: "does not open from outside" was about the ANM-009 knock, not
-- about the player), so a player at night could not leave the trailer to walk to the Mart. Two actions, both ours:
--   trailer_exit    "Exit Trailer", anchor just inside the door; the caller must be inside (VehicleService:IsInside)
--   trailer_enter   "Enter Trailer", anchor outside the steps; the caller must be outside
-- 2026-10-12 (second request): the prompts now only OPEN / CLOSE the door ("Open door" / "Close door"): no fade, no
-- teleport, the player walks through the open leaf (DoorController frees its collision while open). The door closes by
-- itself AUTO_CLOSE s after nobody is near. The old fade + teleport path stays behind Content.Shift.TrailerDoorTeleport
-- (default false). The notes below describe that legacy path.
-- (The trailer is the only vehicle since 2026-10-12, so both are always on.) The door opens by the prompt (user request
-- 2026-10-12): the trailer Model gets DoorOpen = true and DoorController swings Door_Back (tag ScriptedDoor, hinge on its
-- west edge) open, the cover follows, then the leaf closes. The move is server-side: a 0.6 s fade (Transition
-- "TrailerDoor", only to who used the door), the body held still (Freeze "TrailerDoor") and PivotTo under the black.
-- Refused (the prompt stays, nothing happens): not Active, frozen (cutscene, focus, another door use), knocked or
-- fainted (ragdoll), phases Intro / Resume / NightLost / Finale / RunEnd, cooldown COOLDOWN s per player.
-- Anchors: an Interactable anchor with PromptAction trailer_exit / trailer_enter inside the trailer Model is used as
-- is (the user can author them in Studio). Without one this service creates an Attachment on the trailer's main part at
-- the door (never edits the place), positions taken from the MapPoint TRL (the trailer's pose at the Pad) so they
-- follow every PivotTo of the vehicle. Landing spots: MapPoint TRL-OUT / TRL-IN when the binding has them, else
-- free ground found by raycast + overlap next to the steps, else the closest REV-n point, else the raw offset.
-- No state is saved: the door is a convenience of the current shift.
-- Lock (ANM-004 "The copies", DEC-247, Provisional): the game has no door lock; only an anomaly turns it on, with
-- SetLocked(reason, true). That closes the leaf at once and, while any reason is held, the prompt stays ("Open door")
-- but Use opens nothing: the player who tried gets Transition Kind "DoorLocked" (VehicleController plays the "Locked
-- door" sound, SFX-232) and nothing else. The trailer Model carries the attribute DoorLocked = true meanwhile. The
-- service window is not touched.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)

const EXIT = "trailer_exit"
const ENTER = "trailer_enter"
const ANCHOR_TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const TRAILER = "trailer"
const TRL_POINT = "TRL" -- MapPoint of the trailer's pose at the Pad (VehicleService)
const OUT_POINT = "TRL-OUT" -- optional MapPoint: where Exit Trailer drops the player (floor level)
const IN_POINT = "TRL-IN" -- optional MapPoint: where Enter Trailer drops the player (floor level)
const FREEZE = "TrailerDoor"
const LOCKED_ATTRIBUTE = "DoorLocked" -- on the trailer Model while an anomaly holds the door locked
const DOOR_ATTRIBUTE = "DoorOpen" -- on the trailer Model while the leaf is open (DoorController animates Door_Back, tag ScriptedDoor)
const ANCHOR_IN_NAME = "Prompt_ExitTrailer"
const ANCHOR_OUT_NAME = "Prompt_EnterTrailer"
-- Door of MAP-01 §5.5 in the FRAME OF THE TRL POINT (object space of the trailer pose: local +Z = the back wall, local
-- +X = world -X; the trailer pivot is its centre). Before 2026-10-12 these were absolute MAP numbers and only worked
-- with the trailer parked at the old Pad spot. The back wall now stands against the building, so Exit Trailer lands
-- on the free strip along the west wall (MapPoint TRL-OUT when authored) and Enter Trailer is a prompt there.
const DOOR_X = 9 -- local X of the door (MAP X 47..51 minus the pivot 40)
const WALL_Z = 6 -- local Z of the back wall
const AUTO_CLOSE = 4 -- s without anybody within NEAR studs of the leaf before it closes by itself
const NEAR = 7
const OPEN_TEXT = "Open door"
const CLOSE_TEXT = "Close door"
const ANCHOR_IN = Vector3.new(DOOR_X, 5.2, 2.5) -- y over the TRL point (trailer floor +2, chest height); inside the door
const ANCHOR_OUT = Vector3.new(16.3, 3.2, 3.6) -- outside, on the west strip; ~7.65 studs from ANCHOR_IN, Actions radius 3.6 each keeps the two prompts apart
const LAND_IN = Vector3.new(8.5, 0, 1.5) -- inside, a step in front of the door, clear of the bin
const FLOOR_LIFT = 2 -- trailer floor over the TRL point (MAP-01 §5.5)
-- Outside candidates (local x, local z), the west strip first; tried from a UserId based start so mates do not stack
const OUT_CANDIDATES: { Vector2 } = {
	Vector2.new(16.5, 0.2),
	Vector2.new(16.5, 2),
	Vector2.new(16.5, -1.8),
	Vector2.new(16.5, 4),
	Vector2.new(16.5, -3.6),
	Vector2.new(15.5, 0.2),
	Vector2.new(15.5, -1.8),
}
const COOLDOWN = 1 -- s per player
const SWAP_DELAY = 0.2 -- s after the packet: the cover is black from 0.15 s (VehicleController DOOR_IN)
const RELEASE_DELAY = 0.55 -- s after the packet the body is released
const DOOR_LEAD = 0.5 -- s Exit Trailer waits for the leaf to swing open before the cover starts (Door DoorController OPEN_TIME 0.45)
const DOOR_OPEN_AFTER = 0.4 -- s the leaf stays open after the body moved, then it closes
const DOOR_ENTER_OPEN = 0.9 -- s the leaf is open when somebody walks in (Enter Trailer)
const BODY_LIFT = Vector3.new(0, 3, 0) -- floor point -> character pivot (CharacterService SPAWN_LIFT)
const RAY_UP = 14
const RAY_LENGTH = 40
const GROUND_BAND = 3 -- a hit this far over the Pad floor is a prop, not the ground
const BODY_BOX = Vector3.new(2.6, 5, 2.6)
const BLOCKED_PHASES: { [string]: boolean } = {
	Intro = true,
	Resume = true,
	NightLost = true,
	Finale = true,
	RunEnd = true,
}
const RETRY = 2
const RETRIES = 20

local function stringAttribute(instance: Instance, name: string): string?
	const value = instance:GetAttribute(name)
	return if type(value) == "string" then value else nil
end

local function trailerOf(instance: Instance): Model?
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		if
			current:IsA("Model")
			and CollectionService:HasTag(current, VEHICLE_TAG)
			and current:GetAttribute("Vehicle") == TRAILER
		then
			return current
		end
		current = current.Parent
	end
	return nil
end

const TrailerDoorService = Modux.Service("TrailerDoorService", {
	Require = {
		"PlaceService",
		"NetService",
		"PlayerService",
		"RoundService",
		"RunStateService",
		"InteractionService",
		"VehicleService",
		"CharacterService",
	},
	Priority = 605,
})

function TrailerDoorService:Setup()
	self.Enabled = false :: boolean
	self.ExitAnchors = {} :: { [Instance]: boolean }
	self.EnterAnchors = {} :: { [Instance]: boolean }
	self.LastUse = {} :: { [Player]: number }
	self.Busy = {} :: { [Player]: boolean }
	-- uses holding the leaf open right now (the attribute is on while > 0)
	self.DoorHolds = 0 :: number
	-- lock reasons held by anomalies (SetLocked); the door is locked while any is set
	self.Locks = {} :: { [string]: boolean }
	self.Tries = 0 :: number
	self.NearAt = 0 :: number
	self.Warned = {} :: { [string]: boolean }
end

function TrailerDoorService:WarnOnce(key: string, message: string)
	if not self.Warned[key] then
		self.Warned[key] = true
		warn(message)
	end
end

-- Anchors -----------------------------------------------------------------------------------------------------------

function TrailerDoorService:Model(): Model?
	for _, instance in self.Dependencies.VehicleService:Models() do
		if instance:IsA("Model") and instance:GetAttribute("Vehicle") == TRAILER then
			return instance
		end
	end
	return nil
end

-- The trailer is the vehicle in use (at the Pad, with an interior)
function TrailerDoorService:IsPadded(): boolean
	return self.Dependencies.VehicleService:Current() == TRAILER
end

function TrailerDoorService:Register(anchor: Instance)
	const action = stringAttribute(anchor, "PromptAction")
	if action ~= EXIT and action ~= ENTER then
		return
	end
	if trailerOf(anchor) == nil then
		return
	end
	if action == EXIT then
		self.ExitAnchors[anchor] = true
	else
		self.EnterAnchors[anchor] = true
	end
	self:Refresh()
end

-- Part of the trailer the runtime anchors hang on: PrimaryPart, else the biggest part
function TrailerDoorService:Host(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			const size = descendant.Size
			const volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best = descendant
				bestVolume = volume
			end
		end
	end
	return best
end

-- Attachment on the trailer at `offset` (in the frame of the TRL point; Y over it), tagged Interactable
function TrailerDoorService:Create(model: Model, host: BasePart, pad: CFrame, name: string, action: string, offset: Vector3)
	const anchor = Instance.new("Attachment")
	anchor.Name = name
	anchor:SetAttribute("PromptAction", action)
	anchor.Parent = host
	-- the anchor is placed from the trailer's own pose: right at the Pad, and the same after any PivotTo
	anchor.WorldPosition = model:GetPivot():PointToWorldSpace(offset + Vector3.new(0, pad.Position.Y - model:GetPivot().Position.Y, 0))
	if action == EXIT then
		self.ExitAnchors[anchor] = true
	else
		self.EnterAnchors[anchor] = true
	end
	CollectionService:AddTag(anchor, ANCHOR_TAG)
end

-- Makes sure both anchors exist. False while the trailer or the binding is not there yet.
function TrailerDoorService:EnsureAnchors(): boolean
	for anchor in self.ExitAnchors do
		if not anchor:IsDescendantOf(workspace) then
			self.ExitAnchors[anchor] = nil
		end
	end
	for anchor in self.EnterAnchors do
		if not anchor:IsDescendantOf(workspace) then
			self.EnterAnchors[anchor] = nil
		end
	end
	const needExit = next(self.ExitAnchors) == nil
	const needEnter = next(self.EnterAnchors) == nil
	if not needExit and not needEnter then
		return true
	end
	const model = self:Model()
	const pad = if MapIndex.HasBinding() then MapIndex.FindPoint(TRL_POINT) else nil
	if model == nil or pad == nil then
		return false
	end
	const host = self:Host(model)
	if host == nil then
		return false
	end
	if needExit then
		self:Create(model, host, pad, ANCHOR_IN_NAME, EXIT, ANCHOR_IN)
	end
	if needEnter then
		self:Create(model, host, pad, ANCHOR_OUT_NAME, ENTER, ANCHOR_OUT)
	end
	return true
end

function TrailerDoorService:RefreshAnchor(interaction: any, anchor: Instance, on: boolean)
	const text = if Content.Shift.TrailerDoorTeleport then nil elseif self:IsOpen() then CLOSE_TEXT else OPEN_TEXT
	if anchor:GetAttribute("PromptEnabled") ~= on or anchor:GetAttribute("PromptText") ~= text then
		interaction:SetPrompt(anchor, on, text)
	end
end

-- Prompts on only while the trailer is the vehicle in use
function TrailerDoorService:Refresh()
	const interaction = self.Dependencies.InteractionService
	const on = self:IsPadded()
	for anchor in self.ExitAnchors do
		self:RefreshAnchor(interaction, anchor, on)
	end
	for anchor in self.EnterAnchors do
		self:RefreshAnchor(interaction, anchor, on)
	end
end

-- Landing ----------------------------------------------------------------------------------------------------------

function TrailerDoorService:CastParams(): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return params
end

-- Floor level at (x, z): first collidable surface under `fromY`; nil when none
function TrailerDoorService:Ground(x: number, z: number, fromY: number, params: RaycastParams): Vector3?
	const hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -RAY_LENGTH, 0), params)
	if hit == nil or hit.Normal.Y < 0.7 then
		return nil
	end
	return hit.Position
end

-- A body fits at the floor point (nothing collidable in its box)
function TrailerDoorService:IsFree(floor: Vector3): boolean
	const overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	const ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	overlap.FilterDescendantsInstances = ignore
	overlap.RespectCanCollide = true
	const box = CFrame.new(floor + Vector3.new(0, BODY_BOX.Y / 2 + 0.1, 0))
	return #workspace:GetPartBoundsInBox(box, BODY_BOX, overlap) == 0
end

-- Floor point outside the trailer for `player`, nil only without any binding
function TrailerDoorService:OutsideFor(player: Player): Vector3?
	if not MapIndex.HasBinding() then
		return nil
	end
	const authored = MapIndex.FindPoint(OUT_POINT)
	if authored ~= nil then
		return authored.Position
	end
	const pad = MapIndex.FindPoint(TRL_POINT)
	if pad == nil then
		return nil
	end
	const params = self:CastParams()
	const count = #OUT_CANDIDATES
	for step = 0, count - 1 do
		const candidate = OUT_CANDIDATES[(player.UserId + step) % count + 1]
		const world = pad:PointToWorldSpace(Vector3.new(candidate.X, 0, candidate.Y))
		const ground = self:Ground(world.X, world.Z, pad.Position.Y + RAY_UP, params)
		if ground ~= nil and math.abs(ground.Y - pad.Position.Y) <= GROUND_BAND and self:IsFree(ground) then
			return ground
		end
	end
	-- fallback: the closest REV-n (sidewalk next to the trailer, binding point, floor level)
	const door = pad:PointToWorldSpace(Vector3.new(DOOR_X, 0, WALL_Z))
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, point in MapIndex.Points("REV-") do
		const distance = (point.Position - door).Magnitude
		if distance < bestDistance then
			best = point.Position
			bestDistance = distance
		end
	end
	if best ~= nil then
		self:WarnOnce("outside", `[TrailerDoorService] no free ground behind the trailer: using the closest REV point`)
		return best
	end
	self:WarnOnce("outside_raw", `[TrailerDoorService] no free ground and no REV point: dropping at the steps`)
	const raw: Vector3 = pad:PointToWorldSpace(Vector3.new(ANCHOR_OUT.X, 0, ANCHOR_OUT.Z))
	return raw
end

-- Floor point inside, a step in front of the door
function TrailerDoorService:InsideFor(player: Player): Vector3?
	if not MapIndex.HasBinding() then
		return nil
	end
	const authored = MapIndex.FindPoint(IN_POINT)
	if authored ~= nil then
		return authored.Position
	end
	const pad = MapIndex.FindPoint(TRL_POINT)
	if pad == nil then
		return nil
	end
	-- a small spread along the door so two mates never share the same spot
	const jitter = ((player.UserId % 4) - 1.5) * 0.8
	const world = pad:PointToWorldSpace(Vector3.new(LAND_IN.X + jitter, 0, LAND_IN.Z))
	const params = self:CastParams()
	const ground = self:Ground(world.X, world.Z, pad.Position.Y + FLOOR_LIFT + 6, params)
	if ground ~= nil and math.abs(ground.Y - (pad.Position.Y + FLOOR_LIFT)) <= GROUND_BAND then
		return ground
	end
	return Vector3.new(world.X, pad.Position.Y + FLOOR_LIFT, world.Z)
end

-- Rules ------------------------------------------------------------------------------------------------------------

-- Common checks of both actions (the InteractionService already checked Active, range and the gates)
function TrailerDoorService:CanUse(player: Player, anchor: Instance, action: string): boolean
	if not self.Enabled or not self:IsPadded() or self.Busy[player] then
		return false
	end
	const anchors = if action == EXIT then self.ExitAnchors else self.EnterAnchors
	if not anchors[anchor] then
		return false
	end
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or BLOCKED_PHASES[round:GetPhase()] then
		return false
	end
	const characters = self.Dependencies.CharacterService
	if
		characters:IsFrozen(player)
		or characters:IsKnocked(player)
		or characters:IsFainted(player)
		or characters:CharacterOf(player) == nil
	then
		return false
	end
	const last = self.LastUse[player]
	if last ~= nil and os.clock() - last < COOLDOWN then
		return false
	end
	if not Content.Shift.TrailerDoorTeleport then
		return true
	end
	const inside = self.Dependencies.VehicleService:IsInside(player)
	return if action == EXIT then inside else not inside
end

function TrailerDoorService:IsOpen(): boolean
	const model = self:Model()
	return model ~= nil and model:GetAttribute(DOOR_ATTRIBUTE) == true
end

-- The trailer back door exists and is in use (the cart has no back door: ANM-004 only costs sanity there)
function TrailerDoorService:HasDoor(): boolean
	return self.Enabled and self:IsPadded() and self:Model() ~= nil
end

function TrailerDoorService:IsLocked(): boolean
	return next(self.Locks) ~= nil
end

-- Locks / unlocks the door for `reason` (an anomaly Ref). Locking closes the leaf at once. Several reasons stack.
function TrailerDoorService:SetLocked(reason: string, on: boolean)
	self.Locks[reason] = if on then true else nil
	if on then
		self:SetOpen(false)
	end
	const model = self:Model()
	if model ~= nil then
		model:SetAttribute(LOCKED_ATTRIBUTE, if self:IsLocked() then true else nil)
	end
end

function TrailerDoorService:ClearLocks()
	if next(self.Locks) ~= nil then
		self.Locks = {}
		const model = self:Model()
		if model ~= nil then
			model:SetAttribute(LOCKED_ATTRIBUTE, nil)
		end
	end
end

function TrailerDoorService:DoorPosition(): Vector3?
	for anchor in self.ExitAnchors do
		if anchor:IsA("Attachment") then
			return anchor.WorldPosition
		end
	end
	return nil
end

-- Open <-> closed (DoorOpen on the trailer Model; DoorController swings the leaf) and the prompt texts follow
function TrailerDoorService:SetOpen(open: boolean)
	const model = self:Model()
	if model == nil then
		return
	end
	model:SetAttribute(DOOR_ATTRIBUTE, if open then true else nil)
	self.NearAt = os.clock()
	self:Refresh()
end

-- The leaf of Door_Back stays open for `seconds` (DoorOpen on the trailer Model, animated by DoorController)
function TrailerDoorService:HoldDoor(seconds: number)
	const model = self:Model()
	if model == nil then
		return
	end
	self.DoorHolds += 1
	model:SetAttribute(DOOR_ATTRIBUTE, true)
	task.delay(seconds, function()
		self.DoorHolds = math.max(0, self.DoorHolds - 1)
		if self.DoorHolds == 0 and model.Parent ~= nil then
			model:SetAttribute(DOOR_ATTRIBUTE, nil)
		end
	end)
end

-- Run: freeze now, never yields (the interaction queue waits for it). Exit Trailer: the leaf swings open (DOOR_LEAD),
-- then the cover, the body moves under it, the leaf closes. Enter Trailer: cover, move, the leaf swings open and shut
-- behind the player.
function TrailerDoorService:Use(player: Player, action: string)
	self.LastUse[player] = os.clock()
	if self:IsLocked() then
		-- locked by an anomaly: nothing opens, only the player who tried hears it
		if player.Parent ~= nil and self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Transition:fireClient(player, { Kind = "DoorLocked", StartedAt = workspace:GetServerTimeNow() })
		end
		return
	end
	if not Content.Shift.TrailerDoorTeleport then
		self:SetOpen(not self:IsOpen())
		return
	end
	self.Busy[player] = true
	const characters = self.Dependencies.CharacterService
	characters:Freeze(player, FREEZE, true)
	const lead = if action == EXIT then DOOR_LEAD else 0
	if action == EXIT then
		self:HoldDoor(lead + SWAP_DELAY + DOOR_OPEN_AFTER)
	end
	task.delay(lead, function()
		if player.Parent ~= nil and self.Dependencies.NetService:IsRunning() then
			self.Libs.Net.Transition:fireClient(player, { Kind = "TrailerDoor", StartedAt = workspace:GetServerTimeNow() })
		end
	end)
	task.delay(lead + SWAP_DELAY, function()
		self:Move(player, action)
		if action == ENTER then
			self:HoldDoor(DOOR_ENTER_OPEN)
		end
	end)
	task.delay(lead + RELEASE_DELAY, function()
		self.Busy[player] = nil
		if player.Parent ~= nil then
			characters:Freeze(player, FREEZE, false)
		end
	end)
end

function TrailerDoorService:Move(player: Player, action: string)
	if player.Parent == nil or not self.Dependencies.RunStateService:IsActive(player) then
		return
	end
	const character = self.Dependencies.CharacterService:CharacterOf(player)
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	const floor = if action == EXIT then self:OutsideFor(player) else self:InsideFor(player)
	if floor == nil then
		return
	end
	-- facing: the service window / the street (world +Z) both ways (the world is turned 180 degrees from the MAP frame)
	const look = Vector3.new(0, 0, 1)
	const target = floor + BODY_LIFT
	character:PivotTo(CFrame.lookAt(target, target + look))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

-- Lifecycle ----------------------------------------------------------------------------------------------------------

TrailerDoorService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- InteractionService (730) built its handler table in its own OnInit, before this one (605).
	const interaction = self.Dependencies.InteractionService
	for _, action in { EXIT, ENTER } do
		interaction:RegisterAction(action, {
			Validate = function(player: Player, anchor: Instance, _id: number): boolean
				return self:CanUse(player, anchor, action)
			end,
			Run = function(player: Player, _anchor: Instance, _id: number)
				self:Use(player, action)
			end,
		})
	end

	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self.LastUse[player] = nil
		self.Busy[player] = nil
	end)
end)

TrailerDoorService:OnStart(function(self)
	if not self.Enabled then
		return
	end

	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		self:Register(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		self:Register(anchor)
	end)

	-- Anchors are made once the trailer and the binding are in the Workspace (they may stream in late)
	task.spawn(function()
		while self.Tries < RETRIES do
			if self:EnsureAnchors() then
				self:Refresh()
				return
			end
			self.Tries += 1
			task.wait(RETRY)
		end
		self:WarnOnce(
			"anchors",
			"[TrailerDoorService] no trailer Model / MapPoint TRL: Exit Trailer and Enter Trailer have no anchor"
		)
	end)

	self.Dependencies.VehicleService.Swapped:Connect(function(_from: string, _to: string)
		self:EnsureAnchors()
		self:Refresh()
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function(_info)
		self:ClearLocks()
		self:EnsureAnchors()
		self:Refresh()
	end)
	self:Refresh()
end)

-- Auto close: nobody near the leaf for AUTO_CLOSE s
TrailerDoorService:OnTick(function(self)
	if not self.Enabled or Content.Shift.TrailerDoorTeleport or not self:IsOpen() or self.DoorHolds > 0 then
		return
	end
	const center = self:DoorPosition()
	if center == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		const character = player.Character
		const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") and (root.Position - center).Magnitude <= NEAR then
			self.NearAt = os.clock()
			return
		end
	end
	if os.clock() - self.NearAt >= AUTO_CLOSE then
		self:SetOpen(false)
	end
end, 2)

return TrailerDoorService
