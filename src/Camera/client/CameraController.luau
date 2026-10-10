--!strict
--[[
	CameraController (TASK-019, TASK-064; architecture.md §19.3, §19.7; FEAT-025; DEC-097, DEC-167, DEC-219)

	Locked first person with the stock Roblox camera (DEC-039, DEC-097) on the project's
	own crew rig (DEC-146). The stock TransparencyController hides the whole character in
	first person; this controller runs right after it every frame and owns the visibility
	of the body the camera sits in (own character, or the mate being watched):

	  - head group (Head, Face, Cap, ears, hat, accessories and anything welded to the
	    head): always hidden in first person, so a big animal head never covers the view;
	  - arms: visible in first person, day and night (DEC-219; the band skin is the server's
	    `LookPack`, DEC-167). `SetArmsVisible(false)` stays as a hook;
	  - rest of the body (Torso, legs, Apron, tail): hidden, as the stock camera does;
	  - Tools are never touched, so the held item stays visible (DEC-097).

	LocalTransparencyModifier is local: teammates always see the full character.

	Modes (`Mode` source):
	  FirstPerson  own character (LocalState `Active`; also wave 1 and any shift without Vitals records)
	  Spectate     first person of a mate whose `Vitals.State` is `Active` (`Watching` = their UserId). The
	               interact bind (E / ButtonX / touch "Switch") goes to the next mate; bound only with >= 2 mates
	  Fixed        scripted camera on a MapPoint (`SPEC-P` / `SPEC-M`), tilted down FIXED_PITCH (MAP-01 P43)
	  External     someone else owns the camera (cutscene, wave 3): nothing is driven, every part is restored

	Driver (10 Hz, presentation only; the server decides the life state):
	  Active                               -> FirstPerson (back on the new / repeated night, run restart)
	  Down, first FAINT_SWITCH s           -> stays put under the faint fade (VitalController)
	  Down with the own body still there   -> Fixed on the SPEC point nearest to the fall (MAP-01 §5.5, line 629)
	  otherwise (body gone, Spectator)     -> Spectate a mate `Active`; none -> Fixed("SPEC-P") (MAP-01 §11)
	Provisional (TASK-064): the nearest-point rule, FAINT_SWITCH and the free look from the mate's head (the mate's
	gaze arrives with `Gaze`, TASK-101).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Mode = "FirstPerson" | "Spectate" | "Fixed" | "External"

type Group = "Head" | "Arm" | "Body"

const RENDER_STEP = "CameraController.BodyVisibility"
-- Right after the stock CameraModule (which updates its TransparencyController at Camera).
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
-- Camera closer than this to the head counts as first person (stock zoom in LockFirstPerson is 0.5).
const FIRST_PERSON_DISTANCE = 2

-- Spectate driver (TASK-064, Provisional numbers).
const DRIVE_INTERVAL = 0.1 -- s between two decisions
const FAINT_SWITCH = 2 -- s after Down: middle of the dark hold of the faint (FaintIn 1.5 + FaintHold 1)
const FIXED_POINTS = { "SPEC-P", "SPEC-M" }
const DEFAULT_POINT = "SPEC-P" -- nobody standing (MAP-01 §11: "câmera SPEC-P")
const FIXED_PITCH = math.rad(-30) -- MapPoints face horizontally; the camera looks down (MAP-01 P43)
const POINT_RETRY = 2 -- s between two MapIndex refreshes while a SPEC point is not streamed in
const STREAM_INTERVAL = 5 -- s between two RequestStreamAroundAsync on the watched mate
const STREAM_TIMEOUT = 2
const SWITCH_BIND = "SpectateSwitch"
const SWITCH_TOUCH_SIZE = 72 -- px, >= 44 touch target

-- R6 core parts: the head-group walk never crosses them.
const CORE: { [string]: boolean } = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

const ARMS: { [string]: boolean } = {
	["Left Arm"] = true,
	["Right Arm"] = true,
}

-- Name fallback for head pieces that might not be welded to Head (architecture §18.9.1/§18.9.2).
const HEAD_NAMES: { [string]: boolean } = {
	Head = true,
	Face = true,
	Cap = true,
	Hat = true,
	ThiefHat = true,
}
const HEAD_PREFIXES = { "Head_", "Face_", "Ears", "Cap" }

local function isHeadName(name: string): boolean
	if HEAD_NAMES[name] then
		return true
	end
	for _, prefix in HEAD_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function inTool(part: Instance): boolean
	return part:FindFirstAncestorOfClass("Tool") ~= nil
end

local function link(adjacency: { [BasePart]: { BasePart } }, a: BasePart?, b: BasePart?)
	if a == nil or b == nil then
		return
	end
	local fromA = adjacency[a]
	if fromA == nil then
		fromA = {}
		adjacency[a] = fromA
	end
	table.insert(fromA, b)
	local fromB = adjacency[b]
	if fromB == nil then
		fromB = {}
		adjacency[b] = fromB
	end
	table.insert(fromB, a)
end

-- Every non-core part reachable from `root` through welds/joints, Tools excluded.
local function attached(root: BasePart, adjacency: { [BasePart]: { BasePart } }, into: { [BasePart]: Group }, group: Group)
	local stack = { root }
	local seen: { [BasePart]: boolean } = { [root] = true }
	while #stack > 0 do
		local part = table.remove(stack) :: BasePart
		into[part] = group
		for _, neighbor in adjacency[part] or {} do
			if not seen[neighbor] and not CORE[neighbor.Name] and not inTool(neighbor) then
				seen[neighbor] = true
				table.insert(stack, neighbor)
			end
		end
	end
end

local function classify(character: Model): { [BasePart]: Group }
	const adjacency: { [BasePart]: { BasePart } } = {}
	const groups: { [BasePart]: Group } = {}
	const parts: { BasePart } = {}

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("JointInstance") then
			link(adjacency, descendant.Part0, descendant.Part1)
		elseif descendant:IsA("WeldConstraint") then
			link(adjacency, descendant.Part0, descendant.Part1)
		elseif descendant:IsA("BasePart") and not inTool(descendant) then
			table.insert(parts, descendant)
		end
	end

	-- Body first, then arms, then head: the most specific group wins.
	for _, part in parts do
		if part.Name ~= "HumanoidRootPart" then
			groups[part] = "Body"
		end
	end

	for _, part in parts do
		if ARMS[part.Name] and part.Parent == character then
			attached(part, adjacency, groups, "Arm")
		end
	end

	const head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		attached(head, adjacency, groups, "Head")
	end

	for _, part in parts do
		if isHeadName(part.Name) or part:FindFirstAncestorOfClass("Accessory") ~= nil then
			groups[part] = "Head"
		end
	end

	return groups
end

local function humanoidOf(character: Model?): Humanoid?
	if character == nil or character.Parent == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function rootPosition(character: Model?): Vector3?
	if character == nil or character.Parent == nil then
		return nil
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- A mate's character this client can sit in: in the Workspace, with a Humanoid and a Head.
local function bodyOf(userId: number?): Model?
	if userId == nil then
		return nil
	end
	const player = Players:GetPlayerByUserId(userId)
	const character = if player then player.Character else nil
	if character == nil or humanoidOf(character) == nil or character:FindFirstChild("Head") == nil then
		return nil
	end
	return character
end

const CameraController = Modux.Controller(
	"CameraController",
	{ Require = { "InputController", "VitalController" }, Priority = 690 }
)

function CameraController:Setup()
	self.Mode = Vide.source("FirstPerson" :: Mode) :: Vide.Source<Mode>
	-- DEC-219: real arms of the animal visible in first person, day and night.
	self.ArmsVisible = Vide.source(true) :: Vide.Source<boolean>
	-- UserId of the mate being watched (Spectate), nil otherwise. HUD: "Watching: {name}".
	self.Watching = Vide.source(nil :: number?) :: Vide.Source<number?>
	-- MapPoint id of the Fixed camera, nil otherwise. HUD: "Watching the trailer".
	self.FixedPoint = Vide.source(nil :: string?) :: Vide.Source<string?>
	-- The switch bind is live (>= 2 mates standing). HUD: "Tap to switch" / "Press E to switch".
	self.CanSwitch = Vide.source(false) :: Vide.Source<boolean>

	self.Character = nil :: Model?
	self.Groups = {} :: { [BasePart]: Group }
	self.Dirty = true
	self.Applied = false
	self.CharacterConnections = {} :: { RBXScriptConnection }

	self.Target = nil :: number?
	self.PointId = nil :: string?
	self.FallPoint = nil :: string?
	self.LastState = "Active" :: string
	self.DownAt = nil :: number?
	self.LastPosition = nil :: Vector3?
	self.NextDrive = 0 :: number
	self.NextStream = 0 :: number
	self.NextPointRetry = 0 :: number
	self.Bound = false :: boolean
end

function CameraController:SetMode(mode: Mode)
	if mode == "FirstPerson" or mode == "External" then
		self.Target = nil
		self.PointId = nil
		Vide.batch(function()
			self.Watching(nil)
			self.FixedPoint(nil)
		end)
	end
	if Vide.untrack(self.Mode) ~= mode then
		self.Mode(mode)
	end
	if mode == "FirstPerson" then
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

function CameraController:SetArmsVisible(visible: boolean)
	self.ArmsVisible(visible)
end

-- First person of a crew member (presentation only; the driver calls it with a mate `Active`).
function CameraController:Spectate(userId: number)
	self.Target = userId
	self.PointId = nil
	Vide.batch(function()
		if Vide.untrack(self.Watching) ~= userId then
			self.Watching(userId)
		end
		self.FixedPoint(nil)
		if Vide.untrack(self.Mode) ~= "Spectate" then
			self.Mode("Spectate")
		end
	end)
	self:Stream(true)
end

-- Scripted camera on a MapPoint ("SPEC-P" / "SPEC-M").
function CameraController:Fixed(pointId: string)
	self.PointId = pointId
	self.NextPointRetry = 0
	Vide.batch(function()
		self.Watching(nil)
		if Vide.untrack(self.FixedPoint) ~= pointId then
			self.FixedPoint(pointId)
		end
		if Vide.untrack(self.Mode) ~= "Fixed" then
			self.Mode("Fixed")
		end
	end)
end

-- Mates this client can watch: `Vitals.State == "Active"`, not the local player, character present. Sorted by UserId.
function CameraController:Mates(): { number }
	const me = Players.LocalPlayer.UserId
	const states = Vide.untrack(self.Dependencies.VitalController.State)
	const out: { number } = {}
	for userId, state in states do
		if userId ~= me and state == "Active" and bodyOf(userId) ~= nil then
			table.insert(out, userId)
		end
	end
	table.sort(out)
	return out
end

-- Next mate on the switch bind (wraps around).
function CameraController:Next()
	if Vide.untrack(self.Mode) ~= "Spectate" then
		return
	end
	const mates = self:Mates()
	if #mates < 2 then
		return
	end
	const index = table.find(mates, self.Target or -1) or 0
	self:Spectate(mates[index % #mates + 1])
end

function CameraController:NearestPoint(position: Vector3?): string
	if position == nil then
		return DEFAULT_POINT
	end
	local best = DEFAULT_POINT
	local bestDistance = math.huge
	for _, id in FIXED_POINTS do
		const point = MapIndex.FindPoint(id)
		if point then
			const distance = (point.Position - position).Magnitude
			if distance < bestDistance then
				best = id
				bestDistance = distance
			end
		end
	end
	return best
end

function CameraController:PointFrame(id: string?): CFrame?
	if id == nil then
		return nil
	end
	local found = MapIndex.FindPoint(id)
	if found == nil then
		-- Not streamed in yet (or no binding): rebuild the shared cache now and then, never every frame.
		const now = os.clock()
		if now < self.NextPointRetry then
			return nil
		end
		self.NextPointRetry = now + POINT_RETRY
		MapIndex.Refresh()
		found = MapIndex.FindPoint(id)
	end
	if found == nil then
		return nil
	end
	const point: CFrame = found
	return point * CFrame.Angles(FIXED_PITCH, 0, 0)
end

-- Keeps the area around the watched mate streamed in (the spectator has no character to stream around).
function CameraController:Stream(force: boolean)
	if not workspace.StreamingEnabled then
		return
	end
	const now = os.clock()
	if not force and now < self.NextStream then
		return
	end
	self.NextStream = now + STREAM_INTERVAL
	const position = rootPosition(bodyOf(self.Target))
	if position == nil then
		return
	end
	const player = Players.LocalPlayer
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(position, STREAM_TIMEOUT)
		end)
	end)
end

function CameraController:SetSwitchBind(on: boolean)
	if Vide.untrack(self.CanSwitch) ~= on then
		self.CanSwitch(on)
	end
	if self.Bound == on then
		return
	end
	self.Bound = on
	const input = self.Dependencies.InputController
	if not on then
		input:Unbind(SWITCH_BIND)
		return
	end
	-- Same keys as "Interact" (FEAT-025: the interact button switches). A spectator has no prompts, so the two never
	-- compete; the High priority wins if they ever do.
	input
		:Bind({
			Name = SWITCH_BIND,
			Key = Enum.KeyCode.E,
			Keys = { Enum.KeyCode.ButtonX },
			TouchButton = true,
			Title = "Switch",
			TouchSize = SWITCH_TOUCH_SIZE,
			Priority = Enum.ContextActionPriority.High.Value,
			Context = "Gameplay",
		})
		.OnPress(function()
			self:Next()
		end)
end

-- Picks the mode from the own life state (see header). Never decides a state.
function CameraController:Drive()
	const mode = Vide.untrack(self.Mode)
	if mode == "External" then
		self:SetSwitchBind(false)
		return
	end

	const now = os.clock()
	const state = Vide.untrack(self.Dependencies.VitalController.LocalState)
	if state ~= self.LastState then
		self.LastState = state
		self.DownAt = if state == "Down" then now else nil
		self.FallPoint = nil
	end

	if state == "Active" then
		if mode ~= "FirstPerson" then
			self:SetMode("FirstPerson")
		end
		self:SetSwitchBind(false)
		return
	end

	const downAt = self.DownAt
	if downAt ~= nil and now - downAt < FAINT_SWITCH then
		return
	end

	const own = Players.LocalPlayer.Character
	if state == "Down" and own ~= nil and own.Parent ~= nil then
		-- Own body still on the street (until the pickup removes it): watch it from the nearest SPEC point.
		const point: string = self.FallPoint or self:NearestPoint(rootPosition(own) or self.LastPosition)
		self.FallPoint = point
		if mode ~= "Fixed" or self.PointId ~= point then
			self:Fixed(point)
		end
		self:SetSwitchBind(false)
		return
	end

	const mates = self:Mates()
	if #mates > 0 then
		local target = self.Target
		if target == nil or not table.find(mates, target) then
			target = mates[1]
		end
		if mode ~= "Spectate" or target ~= self.Target then
			self:Spectate(target :: number)
		else
			self:Stream(false)
		end
		self:SetSwitchBind(#mates >= 2)
		return
	end

	if mode ~= "Fixed" or self.PointId ~= DEFAULT_POINT then
		self:Fixed(DEFAULT_POINT)
	end
	self:SetSwitchBind(false)
end

-- Character the camera sits in for the current mode.
function CameraController:Body(): Model?
	const mode = Vide.untrack(self.Mode)
	if mode == "FirstPerson" then
		const own = Players.LocalPlayer.Character
		return if own ~= nil and own.Parent ~= nil then own else nil
	elseif mode == "Spectate" then
		return bodyOf(self.Target)
	end
	return nil
end

-- Keeps the stock camera on the mode's subject (only writes what differs).
function CameraController:ApplyCamera()
	const mode = Vide.untrack(self.Mode)
	const camera = workspace.CurrentCamera
	if mode == "External" or camera == nil then
		return
	end
	const player = Players.LocalPlayer

	if mode == "Fixed" then
		const frame = self:PointFrame(self.PointId)
		if frame == nil then
			return -- point not streamed yet: keep whatever the camera shows
		end
		if player.CameraMode ~= Enum.CameraMode.Classic then
			player.CameraMode = Enum.CameraMode.Classic
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.CFrame = frame
		return
	end

	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
	if camera.CameraType ~= Enum.CameraType.Custom then
		camera.CameraType = Enum.CameraType.Custom
	end
	const humanoid = humanoidOf(self:Body())
	if humanoid ~= nil and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

function CameraController:IsFirstPerson(): boolean
	const mode = self.Mode()
	if mode ~= "FirstPerson" and mode ~= "Spectate" then
		return false
	end
	const character = self.Character
	const camera = workspace.CurrentCamera
	if character == nil or camera == nil then
		return false
	end
	const head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude <= FIRST_PERSON_DISTANCE
end

function CameraController:Track(character: Model?)
	if self.Applied then
		self:Restore()
	end
	for _, connection in self.CharacterConnections do
		connection:Disconnect()
	end
	table.clear(self.CharacterConnections)
	self.Groups = {}
	self.Character = character
	self.Applied = false
	self.Dirty = true

	if character == nil then
		return
	end

	local function markDirty(descendant: Instance)
		if
			descendant:IsA("BasePart")
			or descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Accessory")
		then
			self.Dirty = true
		end
	end

	table.insert(self.CharacterConnections, character.DescendantAdded:Connect(markDirty))
	table.insert(self.CharacterConnections, character.DescendantRemoving:Connect(markDirty))
end

function CameraController:Restore()
	for part in self.Groups do
		if part.LocalTransparencyModifier ~= 0 then
			part.LocalTransparencyModifier = 0
		end
	end
	self.Applied = false
end

function CameraController:Update()
	const now = os.clock()
	const ownPosition = rootPosition(Players.LocalPlayer.Character)
	if ownPosition ~= nil then
		self.LastPosition = ownPosition
	end
	if now >= self.NextDrive then
		self.NextDrive = now + DRIVE_INTERVAL
		self:Drive()
	end
	self:ApplyCamera()

	const body = self:Body()
	if body ~= self.Character then
		self:Track(body)
	end

	const character = self.Character
	if character == nil then
		return
	end

	if self.Dirty then
		self.Dirty = false
		self.Groups = classify(character)
	end

	if not self:IsFirstPerson() then
		if self.Applied then
			self:Restore()
		end
		return
	end

	const armTransparency = if self.ArmsVisible() then 0 else 1
	for part, group in self.Groups do
		const target = if group == "Arm" then armTransparency else 1
		if part.LocalTransparencyModifier ~= target then
			part.LocalTransparencyModifier = target
		end
	end
	self.Applied = true
end

CameraController:OnInit(function(self)
	self:Setup()
end)

CameraController:OnStart(function(self)
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function()
		self:Update()
	end)
end)

return CameraController
