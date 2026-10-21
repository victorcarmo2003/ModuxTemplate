--!strict
--[[
	CameraController (TASK-019, TASK-064, TASK-101; architecture.md §19.3, §19.7, §19.14, §19.16; network.md §13.5;
	FEAT-025; DEC-097, DEC-167, DEC-219)

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
	  Spectate     POV of a mate whose `Vitals.State` is `Active` (`Watching` = their UserId): the view follows the
	               mate's real facing (their root yaw, which their own first-person camera turns and the engine
	               replicates) plus a local free look of +-LOOK_LIMIT that eases back to the mate's facing after
	               RECENTER_DELAY s without input. The interact bind (E / ButtonX / touch "Switch") goes to the next
	               mate; bound only with >= 2 mates
	  Fixed        scripted camera on a MapPoint (`SPEC-P` / `SPEC-M`), tilted down FIXED_PITCH (MAP-01 P43)
	  Cutscene     POV of the own head (§19.16). Entered and left only by `Cutscene(on)` (CutsceneController).
	               `Focus(getter, fov)` gives the focus of the beat (a live position: an actor, the poster, a point;
	               nil = where the body faces); `LookAt(position)` is a fixed one. The base view eases to a new focus
	               (smootherstep, Rules.Look.Transition), then follows it (Rules.Look.Follow). Elastic free look:
	               the look input loses gain the farther the view is from the focus (1 - (angle/limit)^Exponent, full
	               gain back towards it) and a critically damped spring brings the view back after Rules.Look.Recenter
	               s without input. Fov narrows the view while that focus holds; a light depth of field keeps the
	               focus sharp (Content.Cutscenes.Rules.Look; 2026-10-11 user feedback).
	  Prep         focused prep mode (DEC-223, PrepController): scripted camera on a station pose, tweened in and out
	               (`Prep(on, frame, options)`); the own rig is hidden by the PrepController (no first person groups);
	               the driver leaves it alone and the mode returns to FirstPerson when the way out is done
	  External     someone else owns the camera: nothing is driven, every part is restored

	Free look (Spectate, Cutscene): mouse (cursor locked to the centre), touch drag on the free screen, gamepad right
	stick. It is camera input, not a command, so it reads UserInputService directly (no InputController bind).

	Gaze (network.md §13.5): every GAZE_INTERVAL s, only at night (RoundController.IsNight), own state `Active` and mode
	`FirstPerson` (so never spectating or in a cutscene), the camera look is sent as `Gaze { Yaw, Pitch }` in
	whole degrees, skipped when unchanged for less than GAZE_HEARTBEAT s. Convention for the reader (AnomalyService):
	  Yaw   = deg(atan2(-Look.X, -Look.Z)) mod 360   (0 = -Z, grows turning left, same as CFrame.fromOrientation)
	  Pitch = deg(asin(Look.Y)) mod 360              (angle(1) is cyclic: a pitch > 180 is pitch - 360, i.e. down)
	  Look  = CFrame.fromOrientation(rad(Pitch), rad(Yaw), 0).LookVector, from the head.

	Driver (10 Hz, presentation only; the server decides the life state):
	  Active                               -> FirstPerson (back on the new / repeated night, run restart)
	  Down, first FAINT_SWITCH s           -> stays put under the faint fade (VitalController)
	  Down with the own body still there   -> Fixed on the SPEC point nearest to the fall (MAP-01 §5.5, line 629)
	  otherwise (body gone, Spectator)     -> Spectate a mate `Active`; none -> Fixed("SPEC-P") (MAP-01 §11)
	Provisional (TASK-064): the nearest-point rule and FAINT_SWITCH. Provisional (TASK-101): the look
	speeds, the spectate follow from the mate's root yaw (pitch stays local: `Gaze` is c -> s only, never relayed) and
	the recentre timing.
	DEC-221 (TASK-131): hiding is gone (the trailer service window replaced it, §19.14 v4.2), so the `Hidden` mode,
	its camera drop and the `Hides` listener are gone too; the camera has no mode for the window.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

export type Mode = "FirstPerson" | "Spectate" | "Fixed" | "Cutscene" | "Prep" | "External"

-- Camera rig of a cutscene shot (CutsceneController/Director.luau; owner request 2026-10-12), all optional
export type Rig = {
	Dolly: Vector3, -- eye offset, camera space (X right, Y up, Z forward)
	Boom: Vector3?, -- detached eye in walker space (X right, Y up, Z forward of the own body): the establishing shot
	BoomLook: Vector3?, -- what a boom looks at, walker space from the head
	Orbit: number, -- radians the eye circles the focus target
	Roll: number,
	Fov: number?, -- overrides the focus fov
	Far: number?, -- depth of field far blur
	Rack: number?, -- 1/s the depth of field follows the focus
	Shake: Vector3, -- hand-held, camera space studs
	Tilt: Vector3, -- hand-held, radians (pitch, yaw, roll)
}

-- Focused prep mode (PrepController; Content.Prep.Rules.Camera): a critically damped glide to the pose of the view (position, the
-- point looked at and the field of view each have their own spring, so a new view in the middle of a glide takes over without a
-- jump of speed) and optional depth of field that follows the focus distance of every view
export type PrepOptions = {
	Fov: number?, -- field of view at the station
	Travel: number?, -- s the glide takes at most (0 = a cut); the real time follows the distance, between Min and Travel
	Min: number?, -- s: the shortest glide (a short hop between two views)
	Look: Vector3?, -- the point the camera looks at (the Focus of the view); nil = along the frame
	Dof: boolean?, -- depth of field behind the work surface (quality > 3 only; the caller decides)
	Focus: number?, -- studs of the DOF focus distance (camera to the point looked at); it glides with the view
	Radius: number?, -- studs in focus around it
	Far: number?, -- far blur intensity
}

type PrepState = {
	Pos: Vector3,
	PosVel: Vector3,
	Look: Vector3,
	LookVel: Vector3,
	Fov: number, -- now
	FovVel: number,
	FocusDist: number,
	FocusVel: number,
	RadiusNow: number,
	RadiusVel: number,
	-- where it is going
	To: CFrame,
	ToLook: Vector3,
	ToFov: number,
	ToFocus: number,
	ToRadius: number,
	Omega: number, -- 1/s of the springs
	BaseFov: number,
	Start: number,
	Travel: number,
	Leaving: boolean,
	Last: number, -- os.clock of the last frame
	Dof: DepthOfFieldEffect?,
	Far: number,
}

-- Horror camera layer (TASK-463; tech/horror-scene.md §4): one shake running, the ramp of the field-of-view delta, one nudge
type HorrorShake = { Amplitude: number, Frequency: number, Duration: number, Start: number, Seed: number }
type HorrorFovRamp = { From: number, Peak: number, Back: number?, Attack: number, Duration: number, Start: number }
type HorrorNudge = { Target: Vector3, Angle: number, Duration: number, Start: number, Done: number }

type Group = "Head" | "Arm" | "Body"

-- the springs of the prep glide settle (98 %) in about PREP_SETTLE / Omega seconds: Omega = PREP_SETTLE / Travel
const PREP_SETTLE = 5.6
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

-- Wave 3 (TASK-101, Provisional numbers).
const LOOK_LIMIT = math.rad(60) -- free look around the base view (§19.16 "olhar livre ±60°")
const PITCH_LIMIT = math.rad(80) -- base + free look never reaches straight up/down
const MOUSE_SPEED = 0.004 -- rad per px at MouseSensitivity 1
const TOUCH_SPEED = 0.006 -- rad per px of drag
const PAD_SPEED = math.rad(150) -- rad/s with the right stick fully pushed
const PAD_DEADZONE = 0.2
const FOLLOW_RATE = 10 -- 1/s ease of the base view (mate's facing, cutscene LookAt)
const RECENTER_DELAY = 1.5 -- s without free-look input before the spectate view eases back to the mate's facing
const RECENTER_RATE = 2 -- 1/s
const GAZE_INTERVAL = 0.1 -- s: 10 Hz (network.md §13.5)
const GAZE_HEARTBEAT = 1 -- s: resend an unchanged gaze this often
const TWO_PI = 2 * math.pi
const NO_GAZE = -1 -- nothing sent yet (wire values are 0..359)

-- Cutscene POV (Content.Cutscenes.Rules.Look, data-driven; see header)
const CUT_LOOK = Content.Cutscenes.Rules.Look
const CUT_YAW = math.rad(CUT_LOOK.Yaw)
const CUT_PITCH = math.rad(CUT_LOOK.Pitch)
const CUT_JUMP = math.rad(25) -- a live focus that jumps this much in a frame (next window card) eases like a new one
const FOV_RATE = 3 -- 1/s ease of the field of view
const SHOT_FOV_RATE = 14 -- 1/s: a shot animates its own fov, the camera only smooths it
const DOF_RATE = 4 -- 1/s ease of the depth of field
const DOF_FAR = 0.3 -- far blur while a focus holds (none while walking)
const DOF_RADIUS_MIN = 8 -- studs in focus around the focus distance

-- Horror camera layer (Content.HorrorScenes.Rules; see the Horror* methods). Provisional (TASK-463): the shake tilt per
-- stud, the decay curve and the attack share of a Fov step that comes back.
const HORROR = Content.HorrorScenes.Rules
const HORROR_RENDER_STEP = "CameraController.HorrorUndo"
-- before the stock CameraModule: it reads the view of the last frame, so the shake offset is taken off first
const HORROR_UNDO_PRIORITY = Enum.RenderPriority.Camera.Value - 1
-- modes the layer plays in (Cutscene, Prep = security monitor and prep, External: someone else owns the camera)
const HORROR_MODES: { [Mode]: boolean } = { FirstPerson = true, Spectate = true, Fixed = true }
const HORROR_TILT = math.rad(8) -- rad of shake tilt per stud of shake amplitude
const HORROR_ATTACK = 0.25 -- share of a Fov step's Duration spent reaching the delta when it comes back
const HORROR_ATTACK_MAX = 1.5 -- s
const HORROR_NUDGE_MIN = 0.05 -- s: a 0 s nudge still eases

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

-- Shortest signed difference to - from, in radians (-pi..pi).
local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % TWO_PI - math.pi
end

-- Heading of a direction: 0 = -Z, same convention as CFrame.fromOrientation's Y angle.
local function yawOf(look: Vector3): number
	return math.atan2(-look.X, -look.Z)
end

-- Look direction -> whole degrees on the angle(1) wire (cyclic 0..359; negative pitch travels as 360 - x).
local function gazeOf(look: Vector3): (number, number)
	const yaw = math.round(math.deg(yawOf(look))) % 360
	const pitch = math.round(math.deg(math.asin(math.clamp(look.Y, -1, 1)))) % 360
	return yaw, pitch
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
-- The loading screen (Loading/Boot) is still up: the cursor stays free until it lifts (playtest 2026-10-11)
local function loadingShown(): boolean
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	const gui = if playerGui ~= nil then playerGui:FindFirstChild("LoadingScreen") else nil
	return gui ~= nil and gui:GetAttribute("Done") ~= true
end

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
	{ Require = { "InputController", "VitalController", "RoundController" }, Priority = 690 }
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
	-- arm parts whose shadow the first-person view switched off (restored with the body)
	self.ArmShadowOff = {} :: { [BasePart]: boolean }
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

	-- Wave 3: POV free look (radians around the base view), base view, Gaze sender.
	self.LookYaw = 0 :: number
	self.LookPitch = 0 :: number
	self.BaseYaw = nil :: number?
	self.BasePitch = 0 :: number
	-- Cutscene focus: live position (nil = the own facing), its field of view, and the eased switch between two
	self.FocusGetter = nil :: (() -> Vector3?)?
	self.FocusFov = nil :: number?
	self.Retarget = false :: boolean
	self.LastTargetYaw = nil :: number?
	self.Transition = nil :: { FromYaw: number, FromPitch: number, At: number, Time: number }?
	-- free look spring velocity (rad/s) and the view settings restored after the cutscene
	self.LookVelocity = Vector2.zero :: Vector2
	-- shot rig of the cutscene (SetRig) and whether the last frame was a detached boom
	self.Rig = nil :: Rig?
	self.WasBoom = false :: boolean
	self.BaseFov = nil :: number?
	self.Dof = nil :: DepthOfFieldEffect?
	-- Prep mode: the pose tween, nil outside the mode
	self.PrepState = nil :: PrepState?
	-- kept for ResetLook (older cutscene base)
	self.HoldYaw = nil :: number?
	self.LastLookInput = 0 :: number
	self.TouchDelta = Vector2.zero :: Vector2
	self.MouseLocked = false :: boolean
	self.NextGaze = 0 :: number
	self.GazeYaw = NO_GAZE :: number
	self.GazePitch = NO_GAZE :: number
	self.GazeAt = 0 :: number
	-- Horror layer: shakes running, field-of-view delta (now, its ramp, the part written on the camera), nudges running
	self.HorrorShakes = {} :: { HorrorShake }
	self.HorrorFovNow = 0 :: number
	self.HorrorFovRamp = nil :: HorrorFovRamp?
	self.HorrorFovApplied = 0 :: number
	self.HorrorNudges = {} :: { HorrorNudge }
	-- shake offset (camera space) written this frame, taken off before the stock camera runs again
	self.HorrorOffset = nil :: CFrame?
end

function CameraController:SetMode(mode: Mode)
	if not HORROR_MODES[mode] then
		-- the camera goes to a mode the horror layer stays out of: its field of view back before the new owner reads it
		self:HorrorClear()
	end
	if mode ~= "Prep" and Vide.untrack(self.Mode) == "Prep" then
		-- someone took the camera while the prep mode was up: drop its effect and field of view
		self:PrepClear()
	end
	if mode ~= "Spectate" and mode ~= "Fixed" then
		self.Target = nil
		self.PointId = nil
		Vide.batch(function()
			self.Watching(nil)
			self.FixedPoint(nil)
		end)
	end
	if Vide.untrack(self.Mode) ~= mode then
		self:ResetLook()
		self.Mode(mode)
	end
	if mode == "FirstPerson" then
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

-- Forgets the prep tween: effect destroyed, field of view back.
function CameraController:PrepClear()
	const state = self.PrepState
	self.PrepState = nil
	if state == nil then
		return
	end
	if state.Dof ~= nil then
		state.Dof:Destroy()
	end
	const camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.FieldOfView = state.BaseFov
	end
end

-- Focused prep mode (PrepController). on = true: tween from the current view to `frame` (a station pose); calling it
-- again while the mode is up retargets (another station). on = false: tween back to the own head and, when done, the
-- mode becomes FirstPerson again (the driver takes over). Entering is only accepted from FirstPerson (or Prep itself):
-- a cutscene, a spectate or an external owner is never overridden. Travel 0 = a cut.
function CameraController:Prep(on: boolean, frame: CFrame?, options: PrepOptions?)
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const opts: PrepOptions = options or {}
	const now = os.clock()
	const existing = self.PrepState
	if on then
		const mode = Vide.untrack(self.Mode)
		if frame == nil or (mode ~= "FirstPerson" and mode ~= "Prep") then
			return
		end
		self:HorrorClear()
		const baseFov = if existing ~= nil then existing.BaseFov else camera.FieldOfView
		local dof = if existing ~= nil then existing.Dof else nil
		const wantedFocus = opts.Focus or 2.5
		if opts.Dof and dof == nil then
			const effect = Instance.new("DepthOfFieldEffect")
			effect.Name = "PrepFocus"
			effect.FarIntensity = 0
			effect.NearIntensity = 0
			effect.FocusDistance = wantedFocus
			effect.InFocusRadius = opts.Radius or 0.4
			effect.Parent = camera
			dof = effect
		elseif not opts.Dof and dof ~= nil then
			dof:Destroy()
			dof = nil
		end
		const look = opts.Look or (frame.Position + frame.LookVector * wantedFocus)
		-- where the glide starts: a retarget keeps the position, the point looked at and their speeds (no jump of velocity)
		local pos, posVel, lookNow, lookVel, fovNow, fovVel = camera.CFrame.Position, Vector3.zero, camera.CFrame.Position + camera.CFrame.LookVector * wantedFocus, Vector3.zero, camera.FieldOfView, 0
		local focusNow, focusVel, radiusNow, radiusVel = wantedFocus, 0, opts.Radius or 0.4, 0
		if existing ~= nil and not existing.Leaving then
			pos, posVel, lookNow, lookVel, fovNow, fovVel = existing.Pos, existing.PosVel, existing.Look, existing.LookVel, existing.Fov, existing.FovVel
			focusNow, focusVel, radiusNow, radiusVel = existing.FocusDist, existing.FocusVel, existing.RadiusNow, existing.RadiusVel
		end
		-- the time it takes grows with the distance, between Min and Travel (a cut when Travel is 0)
		const longest = opts.Travel or 0
		const distance = (frame.Position - pos).Magnitude
		const travel = if longest <= 0 then 0 else math.clamp((opts.Min or longest) + (longest - (opts.Min or longest)) * math.clamp(distance / 8, 0, 1), opts.Min or longest, longest)
		self.PrepState = {
			Pos = pos,
			PosVel = posVel,
			Look = lookNow,
			LookVel = lookVel,
			Fov = fovNow,
			FovVel = fovVel,
			FocusDist = focusNow,
			FocusVel = focusVel,
			RadiusNow = radiusNow,
			RadiusVel = radiusVel,
			To = frame,
			ToLook = look,
			ToFov = opts.Fov or camera.FieldOfView,
			ToFocus = wantedFocus,
			ToRadius = opts.Radius or 0.4,
			Omega = if travel <= 0 then 0 else PREP_SETTLE / travel,
			BaseFov = baseFov,
			Start = now,
			Travel = travel,
			Leaving = false,
			Last = now,
			Dof = dof,
			Far = opts.Far or 0.7,
		}
		self:SetMode("Prep")
		self:SetSwitchBind(false)
		return
	end
	if Vide.untrack(self.Mode) ~= "Prep" or existing == nil then
		return
	end
	const leaveTravel = opts.Travel or 0
	self.PrepState = {
		Pos = existing.Pos,
		PosVel = existing.PosVel,
		Look = existing.Look,
		LookVel = existing.LookVel,
		Fov = existing.Fov,
		FovVel = existing.FovVel,
		FocusDist = existing.FocusDist,
		FocusVel = existing.FocusVel,
		RadiusNow = existing.RadiusNow,
		RadiusVel = existing.RadiusVel,
		To = camera.CFrame,
		ToLook = existing.Look,
		ToFov = existing.BaseFov,
		ToFocus = existing.ToFocus,
		ToRadius = existing.ToRadius,
		Omega = if leaveTravel <= 0 then 0 else PREP_SETTLE / leaveTravel,
		BaseFov = existing.BaseFov,
		Start = now,
		Travel = leaveTravel,
		Leaving = true,
		Last = now,
		Dof = existing.Dof,
		Far = existing.Far,
	}
end

-- A light retarget of the prep camera, meant to be called every frame while the player pans along the trail of stations (feedback
-- 2026-10-12, H): the eye, the point looked at, the field of view and the depth of field take the new goal and the springs that
-- already run (critically damped, the speed carries over) do the smoothing. `omega` = 1/s of the springs while it lasts (nil keeps
-- the ones of the last glide); 0 or less is a cut. Does nothing outside the prep mode or while the way out runs.
function CameraController:PrepGoal(eye: Vector3, look: Vector3, fov: number, omega: number?, focus: number?, radius: number?)
	const state = self.PrepState
	if state == nil or state.Leaving or Vide.untrack(self.Mode) ~= "Prep" then
		return
	end
	const forward = look - eye
	state.To = CFrame.lookAt(eye, look)
	state.ToLook = look
	state.ToFov = fov
	state.ToFocus = focus or forward.Magnitude
	state.ToRadius = radius or state.ToRadius
	if omega ~= nil then
		state.Omega = if omega <= 0 then 0 else omega
	end
	-- the far blur is already up: do not ramp it again
	state.Start = math.min(state.Start, os.clock() - state.Travel)
end

-- Where the view returns to when the prep mode ends: the own head, facing the way the body faces.
function CameraController:PrepExitFrame(): CFrame?
	const character = Players.LocalPlayer.Character
	const head = if character ~= nil then character:FindFirstChild("Head") else nil
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if head == nil or root == nil or not head:IsA("BasePart") or not root:IsA("BasePart") then
		return nil
	end
	return CFrame.new(head.Position) * CFrame.fromOrientation(0, yawOf(root.CFrame.LookVector), 0)
end

-- One step of a critically damped spring (no overshoot; the speed carries over a retarget).
local function damp<T>(value: T, velocity: T, target: T, omega: number, dt: number): (T, T)
	const exp = math.exp(-omega * dt)
	const delta = (value :: any) - (target :: any)
	const temp = ((velocity :: any) + delta * omega) * dt
	const newVelocity = ((velocity :: any) - temp * omega) * exp
	const newValue = (target :: any) + (delta + temp) * exp
	return newValue, newVelocity
end

-- One frame of the prep glide: springs for the position, the point looked at, the field of view and the depth of field; the camera
-- looks AT the point (so the rotation follows the focus of the view). A cut (Travel 0) jumps; leaving ends on the head of the player.
function CameraController:ApplyPrep(camera: Camera)
	const state = self.PrepState
	if state == nil then
		self:SetMode("FirstPerson")
		return
	end
	const player = Players.LocalPlayer
	if player.CameraMode ~= Enum.CameraMode.Classic then
		player.CameraMode = Enum.CameraMode.Classic
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	const now = os.clock()
	const dt = math.clamp(now - state.Last, 0, 0.1)
	state.Last = now
	local goal = state.To
	local goalLook = state.ToLook
	if state.Leaving then
		goal = self:PrepExitFrame() or state.To
		goalLook = goal.Position + goal.LookVector * 4
	end
	if state.Omega <= 0 then
		state.Pos, state.Look, state.Fov = goal.Position, goalLook, state.ToFov
		state.PosVel, state.LookVel, state.FovVel = Vector3.zero, Vector3.zero, 0
		state.FocusDist, state.RadiusNow = state.ToFocus, state.ToRadius
	else
		state.Pos, state.PosVel = damp(state.Pos, state.PosVel, goal.Position, state.Omega, dt)
		state.Look, state.LookVel = damp(state.Look, state.LookVel, goalLook, state.Omega, dt)
		state.Fov, state.FovVel = damp(state.Fov, state.FovVel, state.ToFov, state.Omega, dt)
		state.FocusDist, state.FocusVel = damp(state.FocusDist, state.FocusVel, state.ToFocus, state.Omega, dt)
		state.RadiusNow, state.RadiusVel = damp(state.RadiusNow, state.RadiusVel, state.ToRadius, state.Omega, dt)
	end
	const alpha = if state.Travel <= 0 then 1 else math.clamp((now - state.Start) / state.Travel, 0, 1)
	-- the end of the way out: the head of the player exactly, then the driver takes over
	if state.Leaving and alpha >= 1 then
		camera.CFrame = goal
		camera.FieldOfView = state.BaseFov
		self:PrepClear()
		self:SetMode("FirstPerson")
		self.NextDrive = 0
		return
	end
	const eye = state.Pos
	const target = state.Look
	camera.CFrame = if (target - eye).Magnitude > 1e-3 then CFrame.lookAt(eye, target) else CFrame.new(eye) * goal.Rotation
	camera.FieldOfView = state.Fov
	const dof = state.Dof
	if dof ~= nil then
		dof.FarIntensity = state.Far * (if state.Leaving then 1 - alpha else alpha)
		dof.FocusDistance = math.max(state.FocusDist, 0.5)
		dof.InFocusRadius = math.max(state.RadiusNow, 0.1)
	end
end

-- Free look back to the base view; the base is taken again from the next frame.
function CameraController:ResetLook()
	self.LookYaw = 0
	self.LookPitch = 0
	self.BaseYaw = nil
	self.BasePitch = 0
	self.HoldYaw = nil
	self.TouchDelta = Vector2.zero
	self.LookVelocity = Vector2.zero
	self.Transition = nil
	self.LastTargetYaw = nil
end

-- Cutscene POV on (CutsceneController, §19.16) or off (back to the life-state driver).
function CameraController:Cutscene(on: boolean)
	const camera = workspace.CurrentCamera
	if on then
		self:HorrorClear()
		self.FocusGetter = nil
		self.FocusFov = nil
		if Vide.untrack(self.Mode) ~= "Cutscene" and camera ~= nil then
			self.BaseFov = camera.FieldOfView
			const dof = Instance.new("DepthOfFieldEffect")
			dof.Name = "CutsceneFocus"
			dof.FarIntensity = 0
			dof.NearIntensity = 0
			dof.FocusDistance = 20
			dof.InFocusRadius = 30
			dof.Parent = camera
			const previous = self.Dof
			if previous ~= nil then
				previous:Destroy()
			end
			self.Dof = dof
		end
		self:SetMode("Cutscene")
		self:SetSwitchBind(false)
	elseif Vide.untrack(self.Mode) == "Cutscene" then
		self.FocusGetter = nil
		self.FocusFov = nil
		self.Rig = nil
		self.WasBoom = false
		const dof = self.Dof
		self.Dof = nil
		if dof ~= nil then
			dof:Destroy()
		end
		const fov = self.BaseFov
		self.BaseFov = nil
		if fov ~= nil and camera ~= nil then
			camera.FieldOfView = fov
		end
		self:SetMode("FirstPerson")
		self.NextDrive = 0
	end
end

-- Shot rig of this frame (CutsceneController, every frame of a scene with shots); nil = the plain head POV
function CameraController:SetRig(rig: Rig?)
	self.Rig = rig
end

-- Focus of the cutscene POV (beats `LookAt` / `Focus`): a live position (re-read every frame, so a moving car is
-- followed) or nil = where the own body faces. `fov` narrows the view while it holds (nil = the player's).
function CameraController:Focus(getter: (() -> Vector3?)?, fov: number?)
	self.FocusGetter = getter
	self.FocusFov = fov
	self.HoldYaw = nil
	self.Retarget = true
	-- the free look springs back to the new focus right away
	self.LastLookInput = 0
end

-- Fixed world position as the focus (beat `LookAt`); nil = the own facing.
function CameraController:LookAt(position: Vector3?)
	if position == nil then
		self:Focus(nil, nil)
		return
	end
	const at: Vector3 = position
	self:Focus(function(): Vector3?
		return at
	end, nil)
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
	if mode == "External" or mode == "Cutscene" or mode == "Prep" then
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
	if mode == "FirstPerson" or mode == "Cutscene" then
		const own = Players.LocalPlayer.Character
		return if own ~= nil and own.Parent ~= nil then own else nil
	elseif mode == "Spectate" then
		return bodyOf(self.Target)
	end
	return nil
end

-- Hands the cursor back to the stock camera after a POV mode locked it.
function CameraController:UnlockMouse()
	if self.MouseLocked then
		self.MouseLocked = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

-- Free-look input of this frame (radians): mouse, touch drag, right stick.
function CameraController:LookInput(dt: number): (number, number)
	local yaw = 0
	local pitch = 0

	const mouse = UserInputService:GetMouseDelta()
	if mouse.Magnitude > 0 then
		const sensitivity = UserSettings():GetService("UserGameSettings").MouseSensitivity
		yaw -= mouse.X * MOUSE_SPEED * sensitivity
		pitch -= mouse.Y * MOUSE_SPEED * sensitivity
	end

	const touch = self.TouchDelta
	if touch.Magnitude > 0 then
		self.TouchDelta = Vector2.zero
		yaw -= touch.X * TOUCH_SPEED
		pitch -= touch.Y * TOUCH_SPEED
	end

	if UserInputService.GamepadEnabled then
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.Thumbstick2 then
				const stick = Vector2.new(input.Position.X, input.Position.Y)
				if stick.Magnitude > PAD_DEADZONE then
					yaw -= stick.X * PAD_SPEED * dt
					pitch += stick.Y * PAD_SPEED * dt
				end
				break
			end
		end
	end

	return yaw, pitch
end

-- Scripted POV from a head (Spectate: the mate's; Cutscene: the own) with free look around a base view.
function CameraController:ApplyPov(mode: Mode, camera: Camera, dt: number)
	const body = self:Body()
	const head = if body then body:FindFirstChild("Head") else nil
	if body == nil or head == nil or not head:IsA("BasePart") then
		self:UnlockMouse()
		return -- body not there yet: keep whatever the camera shows
	end
	const player = Players.LocalPlayer
	if player.CameraMode ~= Enum.CameraMode.Classic then
		player.CameraMode = Enum.CameraMode.Classic
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- The subject stays on the watched body (HudController reads it for "Watching").
	const humanoid = humanoidOf(body)
	if humanoid ~= nil and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	self.MouseLocked = true

	-- Base view: the body's facing, or the cutscene focus.
	const root = body:FindFirstChild("HumanoidRootPart")
	const facing: Vector3 = if root and root:IsA("BasePart") then root.CFrame.LookVector else head.CFrame.LookVector
	const now = os.clock()
	local eye = head.Position
	const rig = if mode == "Cutscene" then self.Rig else nil
	local boom = false
	if mode == "Cutscene" then
		boom = rig ~= nil and rig.Boom ~= nil and rig.BoomLook ~= nil
		if boom then
			eye = self:BoomView(rig :: Rig, head.Position, facing)
			if self.WasBoom == false then
				self.WasBoom = true
			end
			self:CutsceneLens(camera, dt, (eye - head.Position).Magnitude)
		else
			if self.WasBoom then
				-- back to the head: the base view starts from the focus again (a dip hides the cut)
				self.WasBoom = false
				self.BaseYaw = nil
				self.Transition = nil
				self.LastTargetYaw = nil
			end
			if rig ~= nil and rig.Orbit ~= 0 then
				eye = self:OrbitEye(eye, rig.Orbit)
			end
			self:CutsceneBase(eye, facing, camera, dt, now)
		end
	else
		const targetYaw = yawOf(facing)
		const ease = 1 - math.exp(-FOLLOW_RATE * dt)
		const baseYaw = self.BaseYaw
		if baseYaw == nil then
			self.BaseYaw = targetYaw
			self.BasePitch = 0
		else
			self.BaseYaw = baseYaw + angleDelta(baseYaw, targetYaw) * ease
			self.BasePitch += (0 - self.BasePitch) * ease
		end
	end

	-- Free look around the base view
	const dYaw, dPitch = self:LookInput(dt)
	if dYaw ~= 0 or dPitch ~= 0 then
		self.LastLookInput = now
	end
	if mode == "Cutscene" then
		self:ElasticLook(dYaw, dPitch, dt, now)
	else
		if dYaw == 0 and dPitch == 0 and now - self.LastLookInput > RECENTER_DELAY then
			const back = math.exp(-RECENTER_RATE * dt)
			self.LookYaw *= back
			self.LookPitch *= back
		end
		self.LookYaw = math.clamp(self.LookYaw + dYaw, -LOOK_LIMIT, LOOK_LIMIT)
		self.LookPitch = math.clamp(self.LookPitch + dPitch, -LOOK_LIMIT, LOOK_LIMIT)
	end

	const yaw = (self.BaseYaw :: number) + self.LookYaw
	const pitch = math.clamp(self.BasePitch + self.LookPitch, -PITCH_LIMIT, PITCH_LIMIT)
	local frame = CFrame.new(eye) * CFrame.fromOrientation(pitch, yaw, 0)
	if rig ~= nil then
		-- shot: hand-held tilt and roll, then the dolly and shake along the camera axes
		frame *= CFrame.Angles(rig.Tilt.X, rig.Tilt.Y, rig.Tilt.Z + rig.Roll)
		const shift = Vector3.new(rig.Dolly.X + rig.Shake.X, rig.Dolly.Y + rig.Shake.Y, -(rig.Dolly.Z + rig.Shake.Z))
		frame += frame:VectorToWorldSpace(shift)
	end
	camera.CFrame = frame
end

-- Eye of a boom shot: the walker's head plus the boom vector in the body's own axes; the base view looks at BoomLook
function CameraController:BoomView(rig: Rig, head: Vector3, facing: Vector3): Vector3
	const space = CFrame.fromOrientation(0, yawOf(facing), 0)
	const boom = rig.Boom :: Vector3
	const look = rig.BoomLook :: Vector3
	const eye = head + space:VectorToWorldSpace(Vector3.new(boom.X, boom.Y, -boom.Z))
	const target = head + space:VectorToWorldSpace(Vector3.new(look.X, look.Y, -look.Z))
	const direction = target - eye
	if direction.Magnitude > 0.01 then
		const unit = direction.Unit
		self.BaseYaw = yawOf(unit)
		self.BasePitch = math.asin(math.clamp(unit.Y, -1, 1))
	end
	return eye
end

-- The eye circles the focus target by `angle` radians around the vertical (orbit shot)
function CameraController:OrbitEye(eye: Vector3, angle: number): Vector3
	const getter = self.FocusGetter
	const target = if getter ~= nil then getter() else nil
	if target == nil then
		return eye
	end
	const offset = eye - target
	const flat = CFrame.Angles(0, angle, 0):VectorToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
	return target + flat + Vector3.new(0, offset.Y, 0)
end

-- Cutscene base view: eased switch to a new focus, then follows it; FOV and depth of field of the focus.
function CameraController:CutsceneBase(eye: Vector3, facing: Vector3, camera: Camera, dt: number, now: number)
	local targetYaw = yawOf(facing)
	local targetPitch = 0
	const getter = self.FocusGetter
	const target = if getter ~= nil then getter() else nil
	local distance: number? = nil
	if target ~= nil then
		const direction = target - eye
		if direction.Magnitude > 0.01 then
			const unit = direction.Unit
			targetYaw = yawOf(unit)
			targetPitch = math.asin(math.clamp(unit.Y, -1, 1))
			distance = direction.Magnitude
		end
	end

	const baseYaw = self.BaseYaw
	if baseYaw == nil then
		self.BaseYaw = targetYaw
		self.BasePitch = targetPitch
		self.Retarget = false
	else
		const lastTarget = self.LastTargetYaw
		const jumped = lastTarget ~= nil and math.abs(angleDelta(lastTarget, targetYaw)) > CUT_JUMP
		if self.Retarget or jumped then
			self.Retarget = false
			const turn = math.abs(angleDelta(baseYaw, targetYaw)) + math.abs(targetPitch - self.BasePitch)
			const spec = CUT_LOOK.Transition
			self.Transition = {
				FromYaw = baseYaw,
				FromPitch = self.BasePitch,
				At = now,
				Time = math.min(spec.Min + spec.PerHalfTurn * turn / math.pi, spec.Max),
			}
		end
		const transition = self.Transition
		if transition ~= nil then
			const x = math.clamp((now - transition.At) / math.max(transition.Time, 1e-3), 0, 1)
			const alpha = x * x * x * (x * (x * 6 - 15) + 10) -- smootherstep
			self.BaseYaw = transition.FromYaw + angleDelta(transition.FromYaw, targetYaw) * alpha
			self.BasePitch = transition.FromPitch + (targetPitch - transition.FromPitch) * alpha
			if x >= 1 then
				self.Transition = nil
			end
		else
			const ease = 1 - math.exp(-CUT_LOOK.Follow * dt)
			self.BaseYaw = baseYaw + angleDelta(baseYaw, targetYaw) * ease
			self.BasePitch += (targetPitch - self.BasePitch) * ease
		end
	end
	self.LastTargetYaw = targetYaw

	self:CutsceneLens(camera, dt, distance)
end

-- Field of view and depth of field of the cutscene: the focus sharp, the far background a little soft (none while
-- walking); a shot rig sets its own fov, far blur and rack speed. `distance` = to the focus (nil = none).
function CameraController:CutsceneLens(camera: Camera, dt: number, distance: number?)
	const rig = self.Rig
	const baseFov = self.BaseFov or camera.FieldOfView
	const fov = (if rig ~= nil then rig.Fov else nil) or self.FocusFov or baseFov
	if math.abs(camera.FieldOfView - fov) > 0.01 then
		const rate = if rig ~= nil and rig.Fov ~= nil then SHOT_FOV_RATE else FOV_RATE
		camera.FieldOfView += (fov - camera.FieldOfView) * (1 - math.exp(-rate * dt))
	end
	const dof = self.Dof
	if dof ~= nil then
		const ease = 1 - math.exp(-((if rig ~= nil then rig.Rack else nil) or DOF_RATE) * dt)
		const shotFar = if rig ~= nil then rig.Far else nil
		const far = shotFar or (if distance ~= nil then DOF_FAR else 0)
		dof.FarIntensity += (far - dof.FarIntensity) * ease
		if distance ~= nil then
			dof.FocusDistance += (distance - dof.FocusDistance) * ease
			dof.InFocusRadius += (math.max(DOF_RADIUS_MIN, distance * 0.6) - dof.InFocusRadius) * ease
		end
	end
end

-- Elastic free look of the cutscene: input gain falls to 0 at the limit when turning away from the focus (full gain
-- back), and after Rules.Look.Recenter s without input a critically damped spring returns the view to the focus.
local function elastic(offset: number, delta: number, limit: number): number
	if delta == 0 then
		return offset
	end
	if offset * delta > 0 then
		const ratio = math.clamp(math.abs(offset) / limit, 0, 1)
		delta *= math.max(1 - ratio ^ CUT_LOOK.Exponent, 0)
	end
	return math.clamp(offset + delta, -limit, limit)
end

function CameraController:ElasticLook(dYaw: number, dPitch: number, dt: number, now: number)
	if dYaw ~= 0 or dPitch ~= 0 then
		self.LookVelocity = Vector2.zero
		self.LookYaw = elastic(self.LookYaw, dYaw, CUT_YAW)
		self.LookPitch = elastic(self.LookPitch, dPitch, CUT_PITCH)
		return
	end
	if now - self.LastLookInput <= CUT_LOOK.Recenter then
		return
	end
	-- x'' = -2w x' - w^2 x (critically damped), integrated in small steps
	const omega = CUT_LOOK.Spring
	local x = Vector2.new(self.LookYaw, self.LookPitch)
	local v = self.LookVelocity
	local left = math.min(dt, 0.1)
	while left > 0 do
		const h = math.min(left, 1 / 120)
		const accel = -2 * omega * v - omega * omega * x
		v += accel * h
		x += v * h
		left -= h
	end
	if x.Magnitude < 1e-4 and v.Magnitude < 1e-3 then
		x = Vector2.zero
		v = Vector2.zero
	end
	self.LookVelocity = v
	self.LookYaw = x.X
	self.LookPitch = x.Y
end

--[[
	Horror camera layer (TASK-463; Content.HorrorScenes steps Shake / Fov / Nudge, called by the scene player). A layer on
	top of the mode, never a mode: it plays in FirstPerson, Spectate and Fixed and stays out of Cutscene, Prep (the
	security monitor uses it) and External; a switch to one of those clears it. Every amount is clamped to the Rules and
	scaled by Rules.ReduceMotion when Motion.Reduced().
	  Shake  camera-space offset and tilt (decaying noise), written after the mode and taken off again before the stock
	         camera reads the view (HorrorUndo), so the first-person look never drifts
	  Fov    a delta added to whatever field of view the mode has (only the change is written, so the player's own value is
	         kept underneath)
	  Nudge  first person only: turns the real look a few degrees towards a point over at most Rules.MaxControlLock and lets
	         go (the view stays where it got; the player's input keeps working the whole time)
]]
local function horrorScale(): number
	return if Motion.Reduced() then HORROR.ReduceMotion else 1
end

local function smooth(x: number): number
	const t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- One shake of a Rules.Shakes profile (Jolt / Step / Door); `scale` multiplies its amplitude (default 1).
function CameraController:HorrorShake(profile: string, scale: number?)
	const spec = HORROR.Shakes[profile]
	if spec == nil then
		warn(`[CameraController] unknown horror shake profile '{profile}'`)
		return
	end
	if not HORROR_MODES[Vide.untrack(self.Mode)] then
		return
	end
	const amplitude = spec.Amplitude * math.max(scale or 1, 0) * horrorScale()
	if amplitude <= 0 or spec.Duration <= 0 then
		return
	end
	table.insert(self.HorrorShakes, {
		Amplitude = amplitude,
		Frequency = spec.Frequency,
		Duration = spec.Duration,
		Start = os.clock(),
		Seed = math.random() * 100,
	})
end

-- Field-of-view delta in degrees (|delta| <= Rules.MaxFov), eased from the delta now. `back` nil: reaches `delta` over
-- `duration` and holds it; `back` set (0 = the player's own fov): reaches `delta` in the first part, then eases to `back`.
function CameraController:HorrorFov(delta: number, back: number?, duration: number)
	if not HORROR_MODES[Vide.untrack(self.Mode)] then
		return
	end
	const scale = horrorScale()
	const peak = math.clamp(delta, -HORROR.MaxFov, HORROR.MaxFov) * scale
	const total = math.max(duration, 0)
	self.HorrorFovRamp = {
		From = self.HorrorFovNow,
		Peak = peak,
		Back = if back ~= nil then math.clamp(back, -HORROR.MaxFov, HORROR.MaxFov) * scale else nil,
		Attack = if back ~= nil then math.min(total * HORROR_ATTACK, HORROR_ATTACK_MAX) else total,
		Duration = total,
		Start = os.clock(),
	}
end

-- Pulls the first-person look at most `degrees` (<= Rules.MaxNudge) towards `target` over `duration` s
-- (<= Rules.MaxControlLock), then lets go. Never stops the player's own look input.
function CameraController:HorrorNudge(target: Vector3, degrees: number, duration: number)
	if Vide.untrack(self.Mode) ~= "FirstPerson" then
		return
	end
	const angle = math.rad(math.clamp(math.abs(degrees), 0, HORROR.MaxNudge)) * horrorScale()
	if angle <= 0 then
		return
	end
	table.insert(self.HorrorNudges, {
		Target = target,
		Angle = angle,
		Duration = math.clamp(duration, HORROR_NUDGE_MIN, HORROR.MaxControlLock),
		Start = os.clock(),
		Done = 0,
	})
end

-- Suspense hijack (TASK-481, DEC-294): the same eased pull as HorrorNudge but up to Rules.MaxPull degrees, so a glance
-- at the edge of the screen is dragged towards the creature. Never stops the player's own look input.
function CameraController:HorrorPull(target: Vector3, degrees: number, duration: number)
	if Vide.untrack(self.Mode) ~= "FirstPerson" then
		return
	end
	const angle = math.rad(math.clamp(math.abs(degrees), 0, HORROR.MaxPull)) * horrorScale()
	if angle <= 0 then
		return
	end
	table.insert(self.HorrorNudges, {
		Target = target,
		Angle = angle,
		Duration = math.clamp(duration, HORROR_NUDGE_MIN, HORROR.MaxControlLock),
		Start = os.clock(),
		Done = 0,
	})
end

-- Ends the layer at once (scene cancelled, the camera goes to another owner): shakes and nudges dropped, the field of
-- view back to what the mode had underneath.
function CameraController:HorrorClear()
	table.clear(self.HorrorShakes)
	table.clear(self.HorrorNudges)
	self.HorrorFovRamp = nil
	self.HorrorFovNow = 0
	const applied = self.HorrorFovApplied
	self.HorrorFovApplied = 0
	const camera = workspace.CurrentCamera
	if applied ~= 0 and camera ~= nil then
		camera.FieldOfView -= applied
	end
end

-- Before the stock camera (HORROR_UNDO_PRIORITY): takes off the shake offset of the last frame, so the stock first-person
-- camera turns from the real look. In Spectate / Fixed the mode writes the view again anyway; harmless there.
function CameraController:HorrorUndo()
	const offset = self.HorrorOffset
	if offset == nil then
		return
	end
	self.HorrorOffset = nil
	const camera = workspace.CurrentCamera
	if camera ~= nil and HORROR_MODES[Vide.untrack(self.Mode)] then
		camera.CFrame *= offset:Inverse()
	end
end

-- Delta of the field of view at `now` (the ramp ends on its last value).
function CameraController:HorrorFovAt(now: number): number
	const ramp = self.HorrorFovRamp
	if ramp == nil then
		return self.HorrorFovNow
	end
	const elapsed = now - ramp.Start
	const back = ramp.Back
	if elapsed >= ramp.Duration then
		self.HorrorFovRamp = nil
		return back or ramp.Peak
	end
	if elapsed < ramp.Attack then
		return ramp.From + (ramp.Peak - ramp.From) * smooth(elapsed / ramp.Attack)
	end
	if back == nil then
		return ramp.Peak
	end
	return ramp.Peak + (back - ramp.Peak) * smooth((elapsed - ramp.Attack) / math.max(ramp.Duration - ramp.Attack, 1e-3))
end

-- One frame of the layer, after the mode wrote the view: nudges (kept), field of view, shake offset (taken off later).
function CameraController:ApplyHorror(now: number)
	const camera = workspace.CurrentCamera
	if camera == nil or loadingShown() or not HORROR_MODES[Vide.untrack(self.Mode)] then
		return
	end

	const fov = self:HorrorFovAt(now)
	self.HorrorFovNow = fov
	if fov ~= self.HorrorFovApplied then
		camera.FieldOfView += fov - self.HorrorFovApplied
		self.HorrorFovApplied = fov
	end

	const nudges = self.HorrorNudges
	if #nudges > 0 then
		if Vide.untrack(self.Mode) ~= "FirstPerson" then
			table.clear(nudges)
		else
			for index = #nudges, 1, -1 do
				const nudge = nudges[index]
				const progress = smooth((now - nudge.Start) / nudge.Duration)
				self:NudgeView(camera, nudge.Target, nudge.Angle * (progress - nudge.Done))
				nudge.Done = progress
				if progress >= 1 then
					table.remove(nudges, index)
				end
			end
		end
	end

	const shakes = self.HorrorShakes
	if #shakes == 0 then
		return
	end
	local shift = Vector3.zero
	for index = #shakes, 1, -1 do
		const shake = shakes[index]
		const elapsed = now - shake.Start
		if elapsed >= shake.Duration then
			table.remove(shakes, index)
		else
			const decay = (1 - elapsed / shake.Duration) ^ 2
			const phase = elapsed * shake.Frequency
			shift += Vector3.new(
				math.noise(phase, shake.Seed, 0.5),
				math.noise(shake.Seed, phase, 1.5),
				math.noise(shake.Seed, 2.5, phase)
			) * (2 * shake.Amplitude * decay)
		end
	end
	if shift.Magnitude <= 1e-5 then
		return
	end
	-- x, y: offset along the camera axes and a matching tilt; z: a small roll
	const offset = CFrame.new(shift.X, shift.Y, 0)
		* CFrame.Angles(shift.Y * HORROR_TILT, -shift.X * HORROR_TILT, shift.Z * HORROR_TILT)
	camera.CFrame *= offset
	self.HorrorOffset = offset
end

-- Turns the first-person look up to `step` radians towards `target` (yaw and pitch, no roll; never past the point).
function CameraController:NudgeView(camera: Camera, target: Vector3, step: number)
	if step <= 0 then
		return
	end
	const frame = camera.CFrame
	const direction = target - frame.Position
	if direction.Magnitude < 0.01 then
		return
	end
	const look = frame.LookVector
	const yaw = yawOf(look)
	const pitch = math.asin(math.clamp(look.Y, -1, 1))
	const unit = direction.Unit
	const dYaw = angleDelta(yaw, yawOf(unit))
	const dPitch = math.asin(math.clamp(unit.Y, -1, 1)) - pitch
	const gap = math.sqrt(dYaw * dYaw + dPitch * dPitch)
	if gap < 1e-4 then
		return
	end
	const k = math.min(step, gap) / gap
	camera.CFrame = CFrame.new(frame.Position)
		* CFrame.fromOrientation(math.clamp(pitch + dPitch * k, -PITCH_LIMIT, PITCH_LIMIT), yaw + dYaw * k, 0)
end

-- Keeps the camera on the mode's subject (only writes what differs).
function CameraController:ApplyCamera(dt: number)
	const mode = Vide.untrack(self.Mode)
	const camera = workspace.CurrentCamera
	if loadingShown() then
		-- under the curtain: no first-person / POV lock, the cursor moves freely
		self:UnlockMouse()
		const player = Players.LocalPlayer
		if player.CameraMode ~= Enum.CameraMode.Classic then
			player.CameraMode = Enum.CameraMode.Classic
		end
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		return
	end
	if mode == "External" or camera == nil then
		self:UnlockMouse()
		return
	end
	if mode == "Spectate" or mode == "Cutscene" then
		self:ApplyPov(mode, camera, dt)
		return
	end
	self:UnlockMouse()
	if mode == "Prep" then
		self:ApplyPrep(camera)
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
	if mode == "Fixed" or mode == "External" or mode == "Prep" then
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

-- Sends the own look to the server (network.md §13.5): night, Active, plain first person. See header.
function CameraController:SendGaze(now: number)
	if now < self.NextGaze then
		return
	end
	self.NextGaze = now + GAZE_INTERVAL
	if
		Vide.untrack(self.Mode) ~= "FirstPerson"
		or not Vide.untrack(self.Dependencies.RoundController.IsNight)
		or Vide.untrack(self.Dependencies.VitalController.LocalState) ~= "Active"
	then
		return
	end
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const yaw, pitch = gazeOf(camera.CFrame.LookVector)
	if yaw == self.GazeYaw and pitch == self.GazePitch and now - self.GazeAt < GAZE_HEARTBEAT then
		return
	end
	self.GazeYaw = yaw
	self.GazePitch = pitch
	self.GazeAt = now
	self.Libs.Net.Gaze:fireServer({ Yaw = yaw, Pitch = pitch })
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
	for part in self.ArmShadowOff do
		part.CastShadow = true
	end
	table.clear(self.ArmShadowOff)
	self.Applied = false
end

function CameraController:Update(dt: number)
	const now = os.clock()
	const ownPosition = rootPosition(Players.LocalPlayer.Character)
	if ownPosition ~= nil then
		self.LastPosition = ownPosition
	end
	if now >= self.NextDrive then
		self.NextDrive = now + DRIVE_INTERVAL
		self:Drive()
	end
	self:ApplyCamera(dt)
	self:SendGaze(now)
	self:ApplyHorror(now)

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
		-- the first-person arms never cast a shadow (user request 2026-10-12)
		if group == "Arm" and part.CastShadow then
			part.CastShadow = false
			self.ArmShadowOff[part] = true
		end
	end
	self.Applied = true
end

CameraController:OnInit(function(self)
	self:Setup()
end)

CameraController:OnStart(function(self)
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

	-- Touch drag of the POV free look: only touches no GUI took (the Switch button, the thumbstick).
	UserInputService.TouchMoved:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		const mode = Vide.untrack(self.Mode)
		if mode == "Spectate" or mode == "Cutscene" then
			self.TouchDelta += Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end)

	RunService:BindToRenderStep(HORROR_RENDER_STEP, HORROR_UNDO_PRIORITY, function()
		self:HorrorUndo()
	end)
	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function(dt: number)
		self:Update(dt)
	end)
end)

return CameraController
