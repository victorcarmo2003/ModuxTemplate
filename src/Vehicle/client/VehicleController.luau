--!strict
--[[
	VehicleController (TASK-058; FEAT-016, FEAT-017; DEC-047, DEC-086, DEC-199; architecture.md §19.5 "Client", T58;
	network.md §13.1 `Transition`; ui-text.md §13)

	Presentation of the vehicle, nothing else. 2026-10-12 (user decision, Provisional): the Food Trailer is the only vehicle,
	so the FOR SALE sign, the swap fade, the trailer purchase latch and the offer camera focus left this file; what stays
	is the short cover of the trailer door (Transition "TrailerDoor", TrailerDoorService) and the service window flap.

	No state of its own (§19.5): the vehicle in use is RoundController.Vehicle (Shift.Vehicle).

	Service window (TASK-131, DEC-221, architecture.md §19.14 v4.2, network.md §13.6): the `Shutter` attribute of each
	`Vehicle` Model with `Vehicles[v].HasShutter` (true = closed, false/absent = open) is written only by the
	VehicleService. Here it only moves the flap: the BasePart holding the `Shutter_Hinge` Attachment (`Shutter_Panel`
	first, else the `Awning` mesh; MAP-01 §7.2, P51) turns around the hinge X axis, local tween SHUTTER_TIME s. The
	authored pose is "open"; "closed" is the hinge attribute `ClosedAngle` (degrees) or, without it, the angle that
	makes the flap hang straight down from the hinge. A client that joins with the window closed gets the final pose
	at once. No hinge (binding TASK-132 not done) = nothing moves, one warn. Sounds `shutter_close` / `shutter_open`
	(placeholder: no key in Content.Sounds = silence). It also gives PromptController the `Shutter` probe of the
	vehicle in use (Rules.SetShutterProbe: no counter prompt with the window closed). The server decides; nothing
	here changes the state.
	Serving-window panel (TASK-284, owner request 2026-10-14, Provisional): the window IS the shop. In the lever phases
	(Content.Actions.shutter_toggle Requires.Phase: Prep, Open, Closing, Night) only the `Shutter` attribute decides
	(the server shuts it in Prep); outside them the flap hangs closed while the shop is not selling (Summary, Call, ...).
	Local only: a 4 Hz tick compares the wanted pose with the flap.
	Provisional (TASK-131): the "hang down" default, the quad ease and the flap needing to be Anchored and unwelded.
	Linked flaps (TASK-480, DEC-294): a vehicle may hold more than one flap. Every BasePart named `Shutter_Panel*` with a
	`Shutter_Hinge` swings (the drive-thru one is `Shutter_Panel_DT`); they all read the same `Shutter` attribute, so
	whatever closes or opens the main window moves them together, same tween and same sound (each at its own hinge).
	The button click plays once, at the main flap.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local PromptRules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local ScreenFade = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ScreenFade)
local Zones = require(ReplicatedStorage.shared.Light.Zones)

const VEHICLE_TAG = "Vehicle"
const INTERIOR_ZONE = "LZ-1" -- LightZone of the trailer interior (VehicleService/Shutter.InteriorZone)
const VEHICLE_ATTRIBUTE = "Vehicle"
-- Legacy fade of the old vehicle swap (Transition "VehicleSwap"; nobody sends it since 2026-10-12): 1.5 s total.
const FADE_IN = 0.2
const FADE_HOLD = 0.5
const FADE_OUT = 0.8
const FADE_TOTAL = FADE_IN + FADE_HOLD + FADE_OUT
const FADE_ORDER = 50 -- above the HUD (DisplayOrder 1)
-- Trailer door (TrailerDoorService, user request 2026-10-11): short cover, the server moves the body at DOOR_SWAP s
const DOOR_IN = 0.15
const DOOR_HOLD = 0.2
const DOOR_OUT = 0.3

-- Service window (TASK-131; Provisional numbers).
const SHUTTER_ATTRIBUTE = "Shutter"
const HINGE_NAME = "Shutter_Hinge"
const PANEL_NAME = "Shutter_Panel"
const PANEL_PREFIX = "Shutter_Panel_" -- extra flaps linked to the main one (TASK-480: Shutter_Panel_DT)
const CLOSED_ANGLE_ATTRIBUTE = "ClosedAngle" -- optional override on the hinge, degrees around its X axis
const SHUTTER_TIME = 0.6 -- s of the local tween (§19.14)
const HINGE_RETRY = 5 -- s: one more look for the hinge when the Model replicates before its children
const MIN_SWING = math.rad(5) -- a smaller computed swing means the flap already hangs down (needs ClosedAngle)
const SOUND_CLOSE = "shutter_close"
const SOUND_OPEN = "shutter_open"
const SOUND_LOCKED = "locked_door" -- SFX-232: the anomaly (ANM-004, DEC-247) locked the back door and this player tried it
const DOOR_NAME = "Door_Back"
const SOUND_BUTTON = "switch_click" -- the window button, with the flap sound (not on the late-join pose)
const PANEL_TICK = 4 -- Hz: shop open / closed against the flap pose
-- phases where the window lever works: the `Shutter` attribute alone decides the flap (TASK-284)
const LEVER_PHASES: { string } = Content.Actions.ByKey.shutter_toggle.Requires.Phase or {}

type Shutter = {
	Model: Model,
	Part: BasePart,
	Hinge: Attachment,
	HingeOffset: CFrame, -- hinge in part space (authored)
	Base: BasePart, -- still part of the vehicle the pose follows (TASK-480: never the Model pivot, see baseOf)
	Rest: CFrame, -- part in Base space (authored = open)
	Closed: number, -- radians around the hinge X axis
	Angle: number,
	From: number,
	To: number,
	StartedAt: number?, -- os.clock of the tween in progress; nil = at rest
	Connections: { RBXScriptConnection },
}

-- 0..1 cover at `elapsed` seconds since StartedAt
local function fadeAlpha(elapsed: number, fadeIn: number, hold: number, out: number): number
	if elapsed < fadeIn then
		return math.max(elapsed, 0) / fadeIn
	elseif elapsed < fadeIn + hold then
		return 1
	end
	return math.clamp(1 - (elapsed - fadeIn - hold) / out, 0, 1)
end

local function isPanel(part: Instance): boolean
	return part.Name == PANEL_NAME or string.sub(part.Name, 1, #PANEL_PREFIX) == PANEL_PREFIX
end

-- Shutter_Hinge Attachments of a vehicle: every one on a Shutter_Panel* part (main + linked flaps, TASK-480); with no
-- panel at all, the first one on any BasePart (P51: the Awning mesh)
local function findHinges(model: Model): { Attachment }
	const hinges: { Attachment } = {}
	local fallback: Attachment? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == HINGE_NAME then
			const parent = descendant.Parent
			if parent ~= nil and parent:IsA("BasePart") then
				if isPanel(parent) then
					table.insert(hinges, descendant)
				end
				fallback = fallback or descendant
			end
		end
	end
	if #hinges == 0 and fallback ~= nil then
		table.insert(hinges, fallback)
	end
	return hinges
end

-- Swing (radians around the hinge X axis) from the authored pose to the closed one; nil = cannot tell
local function closedAngle(hinge: Attachment): number?
	const override = hinge:GetAttribute(CLOSED_ANGLE_ATTRIBUTE)
	if typeof(override) == "number" then
		return math.rad(override)
	end
	-- Part centre and world down, both in hinge space; turn the first onto the second in the hinge's Y-Z plane.
	const centre = hinge.CFrame:PointToObjectSpace(Vector3.zero)
	const down = hinge.WorldCFrame:VectorToObjectSpace(Vector3.new(0, -1, 0))
	if Vector2.new(centre.Y, centre.Z).Magnitude < 0.05 or Vector2.new(down.Y, down.Z).Magnitude < 0.05 then
		return nil
	end
	local angle = math.atan2(down.Z, down.Y) - math.atan2(centre.Z, centre.Y)
	angle = (angle + math.pi) % (2 * math.pi) - math.pi
	if math.abs(angle) < MIN_SWING then
		return nil
	end
	return angle
end

-- Part the flap poses follow. Not Model:GetPivot(): without a PrimaryPart that is the bounding-box centre, which
-- moves when the flaps themselves swing (TASK-480: the closed flaps slid ~2 studs into the windows). PrimaryPart when
-- there is one, else the biggest anchored BasePart of the vehicle that is not a flap (shell/floor: no door leaf or prop
-- that other controllers move).
local function baseOf(model: Model): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestVolume = -1
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Anchored and descendant:FindFirstChild(HINGE_NAME) == nil then
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

local function shutterPose(shutter: Shutter, angle: number): CFrame
	const offset = shutter.HingeOffset
	return shutter.Base.CFrame * shutter.Rest * offset * CFrame.Angles(angle, 0, 0) * offset:Inverse()
end

local function samePose(a: CFrame, b: CFrame): boolean
	return a.Position:FuzzyEq(b.Position, 1e-3)
		and a.LookVector:FuzzyEq(b.LookVector, 1e-4)
		and a.UpVector:FuzzyEq(b.UpVector, 1e-4)
end

const VehicleController = Modux.Controller(
	"VehicleController",
	{ Require = { "RoundController", "AudioController", "ObjectiveController" }, Priority = 760 }
)

function VehicleController:Setup()
	self.Fade = Vide.source(0) :: Vide.Source<number>
	self.FadeStartedAt = 0 :: number
	self.FadeIsDoor = false :: boolean
	self.FadeConnection = nil :: RBXScriptConnection?
	self.Unmounts = {} :: { () -> () }
	-- Service window flaps by flap part (TASK-131; several per vehicle Model since TASK-480)
	self.Shutters = {} :: { [Instance]: Shutter }
	self.ShutterPending = {} :: { [Instance]: boolean }
	self.ShutterStep = nil :: RBXScriptConnection?
	self.Warned = {} :: { [string]: boolean }
end

function VehicleController:WarnOnce(tag: string, message: string)
	if not self.Warned[tag] then
		self.Warned[tag] = true
		warn(`[VehicleController] {message}`)
	end
end

-- Tagged Vehicle model: service window flap
function VehicleController:WatchVehicle(model: Instance)
	if model:IsA("Model") then
		self:WatchShutter(model, true)
	end
end

function VehicleController:UnwatchVehicle(model: Instance)
	self.ShutterPending[model] = nil
	for part, shutter in self.Shutters do
		if shutter.Model == model then
			self.Shutters[part] = nil
			for _, shutterConnection in shutter.Connections do
				shutterConnection:Disconnect()
			end
		end
	end
end

function VehicleController:HasShutter(model: Model): boolean
	for _, shutter in self.Shutters do
		if shutter.Model == model then
			return true
		end
	end
	return false
end

-- Binds the flap of a vehicle with HasShutter. `retry`: the Model may replicate before its children, so a missing
-- hinge is looked for once more HINGE_RETRY s later before the warn.
function VehicleController:WatchShutter(model: Model, retry: boolean)
	if self:HasShutter(model) then
		return
	end
	const key = model:GetAttribute(VEHICLE_ATTRIBUTE)
	const row = if typeof(key) == "string" then Content.Vehicles.ByKey[key] else nil
	if row == nil or not row.HasShutter then
		return
	end

	const hinges = findHinges(model)
	if #hinges == 0 then
		if retry then
			self.ShutterPending[model] = true
			task.delay(HINGE_RETRY, function()
				if self.ShutterPending[model] then
					self.ShutterPending[model] = nil
					self:WatchShutter(model, false)
				end
			end)
		else
			self:WarnOnce(
				`nohinge:{row.Key}`,
				`no {HINGE_NAME} Attachment in vehicle {row.Key} (binding TASK-132, MAP-01 §7.2); the window flap stays still`
			)
		end
		return
	end
	self.ShutterPending[model] = nil
	for _, hinge in hinges do
		self:WatchFlap(model, hinge)
	end
end

-- One flap (hinge on its part) of a watched vehicle
function VehicleController:WatchFlap(model: Model, hinge: Attachment)
	const part = hinge.Parent :: BasePart
	if not part.Anchored or #part:GetJoints() > 0 then
		self:WarnOnce(
			`welded:{part:GetFullName()}`,
			`{part:GetFullName()} must be Anchored and unwelded to swing locally; the window flap stays still`
		)
		return
	end
	const closed = closedAngle(hinge)
	if closed == nil then
		self:WarnOnce(
			`noangle:{part:GetFullName()}`,
			`{part:GetFullName()} already hangs down from {HINGE_NAME}; set its {CLOSED_ANGLE_ATTRIBUTE} (degrees). The window flap stays still`
		)
		return
	end

	const base = baseOf(model)
	if base == nil then
		return
	end

	const isClosed = self:WantClosed(model)
	const angle = if isClosed then closed else 0
	const shutter: Shutter = {
		Model = model,
		Part = part,
		Hinge = hinge,
		HingeOffset = hinge.CFrame,
		Base = base,
		Rest = base.CFrame:ToObjectSpace(part.CFrame),
		Closed = closed,
		Angle = angle,
		From = angle,
		To = angle,
		StartedAt = nil,
		Connections = {},
	}
	self.Shutters[part] = shutter

	table.insert(
		shutter.Connections,
		model:GetAttributeChangedSignal(SHUTTER_ATTRIBUTE):Connect(function()
			self:SwingShutter(shutter)
		end)
	)
	-- The server pivots vehicles (swap) and its CFrame replaces the local one: put the flap back on the next frame.
	table.insert(
		shutter.Connections,
		part:GetPropertyChangedSignal("CFrame"):Connect(function()
			if shutter.StartedAt == nil then
				task.defer(function()
					if self.Shutters[part] == shutter and shutter.StartedAt == nil then
						self:PoseShutter(shutter)
					end
				end)
			end
		end)
	)
	-- Late join with the window closed: final pose at once, no tween.
	self:PoseShutter(shutter)
end

-- The flap is down when the window is closed (server attribute) or, outside the lever phases, the shop is not selling
-- (panel). A phase this client does not know yet counts as selling: the flap never closes on a guess.
function VehicleController:WantClosed(model: Model): boolean
	if model:GetAttribute(SHUTTER_ATTRIBUTE) == true then
		return true
	end
	const phase = self.Dependencies.RoundController.Phase()
	const row = Content.Shift.ByKey[phase]
	if row == nil or table.find(LEVER_PHASES, phase) ~= nil then
		return false
	end
	return not row.Selling
end

function VehicleController:PoseShutter(shutter: Shutter)
	const pose = shutterPose(shutter, shutter.Angle)
	if not samePose(shutter.Part.CFrame, pose) then
		shutter.Part.CFrame = pose
	end
end

-- `Shutter` attribute changed: tween from where the flap is now to the new end pose and play the placeholder sound
function VehicleController:SwingShutter(shutter: Shutter)
	const isClosed = self:WantClosed(shutter.Model)
	const target = if isClosed then shutter.Closed else 0
	if shutter.To == target and (shutter.StartedAt ~= nil or shutter.Angle == target) then
		return
	end
	shutter.From = shutter.Angle
	shutter.To = target
	shutter.StartedAt = os.clock()
	if self.ShutterStep == nil then
		self.ShutterStep = RunService.RenderStepped:Connect(function()
			self:StepShutters()
		end)
	end

	const sound = if isClosed then SOUND_CLOSE else SOUND_OPEN
	const audio = self.Dependencies.AudioController
	if shutter.Part.Name == PANEL_NAME or not isPanel(shutter.Part) then
		audio:Play(SOUND_BUTTON, shutter.Hinge.WorldPosition)
	end
	if Content.Sounds.ByKey[sound] ~= nil then
		audio:Play(sound, shutter.Hinge.WorldPosition)
	end
end

function VehicleController:StepShutters()
	const now = os.clock()
	local moving = false
	for _, shutter in self.Shutters do
		const startedAt = shutter.StartedAt
		if startedAt == nil then
			continue
		end
		const alpha = math.clamp((now - startedAt) / SHUTTER_TIME, 0, 1)
		const eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		shutter.Angle = shutter.From + (shutter.To - shutter.From) * eased
		if alpha >= 1 then
			shutter.Angle = shutter.To
			shutter.StartedAt = nil
		else
			moving = true
		end
		self:PoseShutter(shutter)
	end
	if not moving then
		const step = self.ShutterStep
		if step then
			self.ShutterStep = nil
			step:Disconnect()
		end
	end
end

-- Shop phase changes move the flap even though no attribute changed
function VehicleController:RefreshPanels()
	for _, shutter in self.Shutters do
		self:SwingShutter(shutter)
	end
end

-- Service window of the vehicle in use is closed (PromptController probe). No Model or no attribute = open.
function VehicleController:IsShutterClosed(): boolean
	const current = self.Dependencies.RoundController.Vehicle()
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		if model:GetAttribute(VEHICLE_ATTRIBUTE) == current then
			return model:GetAttribute(SHUTTER_ATTRIBUTE) == true
		end
	end
	return false
end

-- Own character inside the trailer: LightZone LZ-1, the volume VehicleService:IsInside reads on the server
function VehicleController:IsInside(): boolean
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	for _, instance in CollectionService:GetTagged(Zones.Tag) do
		if instance:IsA("BasePart") and instance:GetAttribute("ZoneId") == INTERIOR_ZONE then
			const zone = Zones.read(instance)
			return zone ~= nil and Zones.contains(zone, root.Position)
		end
	end
	return false
end

-- Transition packet: start (or restart) the cover from the server time; a late packet only plays what is left
-- "Locked door": the server refused Open door (TrailerDoorService lock). Only the sound, at the leaf when it is found.
function VehicleController:PlayLocked()
	local at: Vector3? = nil
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		const door = model:FindFirstChild(DOOR_NAME, true)
		if door ~= nil and door:IsA("PVInstance") then
			at = door:GetPivot().Position
			break
		end
	end
	self.Dependencies.AudioController:Play(SOUND_LOCKED, at)
end

function VehicleController:PlayFade(startedAt: number, door: boolean?)
	const isDoor = door == true
	const total = if isDoor then DOOR_IN + DOOR_HOLD + DOOR_OUT else FADE_TOTAL
	if workspace:GetServerTimeNow() - startedAt >= total then
		return
	end
	self.FadeStartedAt = startedAt
	self.FadeIsDoor = isDoor
	if self.FadeConnection == nil then
		self.FadeConnection = RunService.RenderStepped:Connect(function()
			self:StepFade()
		end)
	end
	self:StepFade()
end

function VehicleController:StepFade()
	const elapsed = workspace:GetServerTimeNow() - self.FadeStartedAt
	const isDoor = self.FadeIsDoor
	const fadeIn = if isDoor then DOOR_IN else FADE_IN
	const hold = if isDoor then DOOR_HOLD else FADE_HOLD
	const out = if isDoor then DOOR_OUT else FADE_OUT
	if elapsed >= fadeIn + hold + out then
		self.Fade(0)
		const connection = self.FadeConnection
		if connection then
			self.FadeConnection = nil
			connection:Disconnect()
		end
		return
	end
	self.Fade(fadeAlpha(elapsed, fadeIn, hold, out))
end

-- Fade cover: mounted at once, so a Transition right after the join still shows
function VehicleController:MountFade(playerGui: Instance)
	const unmount, gui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "VehicleFade",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = FADE_ORDER,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			ScreenFade({ Alpha = self.Fade }),
		})
	end)
	table.insert(self.Unmounts, unmount)
	gui.Parent = playerGui
end

VehicleController:OnInit(function(self)
	self:Setup()

	PromptRules.SetShutterProbe({
		IsClosed = function(): boolean
			return self:IsShutterClosed()
		end,
		IsInside = function(): boolean
			return self:IsInside()
		end,
	})

	self.Libs.Net.Transition:onClient(function(transition)
		if transition.Kind == "VehicleSwap" then
			self:PlayFade(transition.StartedAt)
		elseif transition.Kind == "TrailerDoor" then
			self:PlayFade(transition.StartedAt, true)
		elseif transition.Kind == "DoorLocked" then
			self:PlayLocked()
		end
	end)
end)

VehicleController:OnStart(function(self)
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		self:WatchVehicle(model)
	end
	CollectionService:GetInstanceAddedSignal(VEHICLE_TAG):Connect(function(model)
		self:WatchVehicle(model)
	end)
	CollectionService:GetInstanceRemovedSignal(VEHICLE_TAG):Connect(function(model)
		self:UnwatchVehicle(model)
	end)

	-- PlayerGui may arrive late; do not hold up the other OnStart.
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		self:MountFade(playerGui)
	end)
end)

VehicleController:OnTick(function(self)
	self:RefreshPanels()
end, PANEL_TICK)

return VehicleController
