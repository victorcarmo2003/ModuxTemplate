--!strict
--[[
	VehicleController (TASK-058; FEAT-016, FEAT-017; DEC-047, DEC-086, DEC-199; architecture.md §19.5 "Client", T58;
	network.md §13.1 `Transition`; ui-text.md §13)

	Presentation of the vehicle swap, nothing else:
	  * Sale sign at the `SIGN-T` MapPoint (MAP-01 §5.1, P40): "Available on Day 5" before Vehicles.trailer.BuyFromDay,
	    "FOR SALE" from then until the purchase, gone after it (the billboard and, locally, the AST-024 sign model).
	  * Fade of the `Transition { Kind = "VehicleSwap" }` packet: 1.5 s black cover timed from the server StartedAt, for
	    everyone in the group (the server pivots the vehicles under it).
	  * Tarp (`VehicleCover`, AST-043): nothing here. VehicleService toggles its visibility (T38) and it replicates as
	    an instance; the drawer value of the parked cart is hidden by EconomyController (current vehicle only).

	No state of its own (§19.5): the vehicle in use is RoundController.Vehicle (Shift.Vehicle). The only local memory is
	the `trailer_bought` Notice between the purchase and the swap (Shift.Vehicle still says "cart" until the next
	shift). The sale vehicle Model also carries the `Bought` attribute (written by the VehicleService): a client that
	(re)joins in that window reads it and hides the sign too. The last value read is kept while the Model is streamed
	out.

	The client never buys nor moves a vehicle: the prompt (`Prompt_Buy`, buy_trailer) belongs to the VehicleService and
	PromptController, the pivots to the server.

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
	Provisional (TASK-131): the "hang down" default, the quad ease and the flap needing to be Anchored and unwelded.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local PromptRules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local SaleSign = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SaleSign)
local ScreenFade = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ScreenFade)

const START_VEHICLE = Content.RunParams.StartVehicle
const SIGN_POINT = "SIGN-T"
const SIGN_MAP_ID = "SIGN-T" -- MapId of the AST-024 stand placed at the point (MAP-01_placements.luau)
const BOUGHT_NOTICE = "trailer_bought"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const BOUGHT_ATTRIBUTE = "Bought"
const MAP_WAIT = 60 -- seconds MapIndex.WaitReady may wait for streaming
-- Billboard centre over the point when the sign model is not streamed in: AST-024 is 4 studs tall (+ half plate).
const DEFAULT_SIGN_HEIGHT = 4.8
-- Gap between the top of the sign model and the centre of the plate (studs).
const SIGN_GAP = 0.8
const SIGN_DISTANCE = 90 -- readable from the Pad (~80 studs to the lot)

-- Fade of the swap (T58): 1.5 s total. Short fade-in because the server pivots right after sending the packet;
-- Provisional until the VehicleService (TASK-054) fixes its own wait before PivotTo.
const FADE_IN = 0.2
const FADE_HOLD = 0.5
const FADE_OUT = 0.8
const FADE_TOTAL = FADE_IN + FADE_HOLD + FADE_OUT
const FADE_ORDER = 50 -- above the HUD (DisplayOrder 1)

-- Service window (TASK-131; Provisional numbers).
const SHUTTER_ATTRIBUTE = "Shutter"
const HINGE_NAME = "Shutter_Hinge"
const PANEL_NAME = "Shutter_Panel"
const CLOSED_ANGLE_ATTRIBUTE = "ClosedAngle" -- optional override on the hinge, degrees around its X axis
const SHUTTER_TIME = 0.6 -- s of the local tween (§19.14)
const HINGE_RETRY = 5 -- s: one more look for the hinge when the Model replicates before its children
const MIN_SWING = math.rad(5) -- a smaller computed swing means the flap already hangs down (needs ClosedAngle)
const SOUND_CLOSE = "shutter_close"
const SOUND_OPEN = "shutter_open"
const SOUND_BUTTON = "switch_click" -- the window button, with the flap sound (not on the late-join pose)

type Shutter = {
	Model: Model,
	Part: BasePart,
	Hinge: Attachment,
	HingeOffset: CFrame, -- hinge in part space (authored)
	Rest: CFrame, -- part in model-pivot space (authored = open)
	Closed: number, -- radians around the hinge X axis
	Angle: number,
	From: number,
	To: number,
	StartedAt: number?, -- os.clock of the tween in progress; nil = at rest
	Connections: { RBXScriptConnection },
}

-- Vehicle sold in the lot: the first row with BuyFromDay > 0 (the trailer; content-data.md §3.8)
local function saleVehicle(): Content.Vehicle?
	for _, vehicle in Content.Vehicles.List do
		if vehicle.BuyFromDay > 0 then
			return vehicle
		end
	end
	return nil
end

const SALE = saleVehicle()

-- 0..1 cover at `elapsed` seconds since StartedAt
local function fadeAlpha(elapsed: number): number
	if elapsed < FADE_IN then
		return math.max(elapsed, 0) / FADE_IN
	elseif elapsed < FADE_IN + FADE_HOLD then
		return 1
	end
	return math.clamp(1 - (elapsed - FADE_IN - FADE_HOLD) / FADE_OUT, 0, 1)
end

-- Shutter_Hinge of a vehicle: the one on Shutter_Panel when both exist (P51), else the first one on a BasePart
local function findHinge(model: Model): Attachment?
	local found: Attachment? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == HINGE_NAME then
			const parent = descendant.Parent
			if parent ~= nil and parent:IsA("BasePart") then
				if parent.Name == PANEL_NAME then
					return descendant
				end
				found = found or descendant
			end
		end
	end
	return found
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

local function shutterPose(shutter: Shutter, angle: number): CFrame
	const offset = shutter.HingeOffset
	return shutter.Model:GetPivot() * shutter.Rest * offset * CFrame.Angles(angle, 0, 0) * offset:Inverse()
end

local function samePose(a: CFrame, b: CFrame): boolean
	return a.Position:FuzzyEq(b.Position, 1e-3)
		and a.LookVector:FuzzyEq(b.LookVector, 1e-4)
		and a.UpVector:FuzzyEq(b.UpVector, 1e-4)
end

const VehicleController = Modux.Controller(
	"VehicleController",
	{ Require = { "RoundController", "AudioController" }, Priority = 760 }
)

function VehicleController:Setup()
	self.Fade = Vide.source(0) :: Vide.Source<number>
	self.FadeStartedAt = 0 :: number
	self.FadeConnection = nil :: RBXScriptConnection?
	-- `trailer_bought` seen this session and Day it arrived (cleared by the swap or a new run)
	self.Bought = Vide.source(false) :: Vide.Source<boolean>
	self.BoughtDay = 0 :: number
	-- `Bought` attribute of the sale vehicle Model (VehicleService; authoritative, also for late joiners)
	self.SaleBought = Vide.source(false) :: Vide.Source<boolean>
	self.SaleModels = {} :: { [Instance]: RBXScriptConnection }
	self.SignModel = nil :: Model?
	self.SignAnchor = nil :: Attachment?
	self.Unmounts = {} :: { () -> () }
	-- Service window flaps by vehicle Model (TASK-131)
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

-- Text of the sign for `day` (ui-text.md §13)
function VehicleController:SignText(day: number): string
	if SALE and day < SALE.BuyFromDay then
		return `Available on Day {SALE.BuyFromDay}`
	end
	return "FOR SALE"
end

-- Shown while the run is still on the starting vehicle and nobody bought the trailer
function VehicleController:SignVisible(): boolean
	const round = self.Dependencies.RoundController
	return SALE ~= nil
		and round.Ready()
		and round.Vehicle() == START_VEHICLE
		and not self.Bought()
		and not self.SaleBought()
end

-- Tagged Vehicle model: sale sign latch and service window flap
function VehicleController:WatchVehicle(model: Instance)
	self:WatchSale(model)
	if model:IsA("Model") then
		self:WatchShutter(model, true)
	end
end

-- Follows the `Bought` attribute when it is the sale vehicle
function VehicleController:WatchSale(model: Instance)
	if SALE == nil or self.SaleModels[model] ~= nil or model:GetAttribute(VEHICLE_ATTRIBUTE) ~= SALE.Key then
		return
	end
	const read = function()
		self.SaleBought(model:GetAttribute(BOUGHT_ATTRIBUTE) == true)
	end
	self.SaleModels[model] = model:GetAttributeChangedSignal(BOUGHT_ATTRIBUTE):Connect(read)
	read()
end

function VehicleController:UnwatchVehicle(model: Instance)
	const connection = self.SaleModels[model]
	if connection then
		self.SaleModels[model] = nil
		connection:Disconnect()
	end
	self.ShutterPending[model] = nil
	const shutter = self.Shutters[model]
	if shutter then
		self.Shutters[model] = nil
		for _, shutterConnection in shutter.Connections do
			shutterConnection:Disconnect()
		end
	end
end

-- Binds the flap of a vehicle with HasShutter. `retry`: the Model may replicate before its children, so a missing
-- hinge is looked for once more HINGE_RETRY s later before the warn.
function VehicleController:WatchShutter(model: Model, retry: boolean)
	if self.Shutters[model] ~= nil then
		return
	end
	const key = model:GetAttribute(VEHICLE_ATTRIBUTE)
	const row = if typeof(key) == "string" then Content.Vehicles.ByKey[key] else nil
	if row == nil or not row.HasShutter then
		return
	end

	const hinge = findHinge(model)
	if hinge == nil then
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

	const part = hinge.Parent :: BasePart
	if not part.Anchored or #part:GetJoints() > 0 then
		self:WarnOnce(
			`welded:{row.Key}`,
			`{part:GetFullName()} must be Anchored and unwelded to swing locally; the window flap stays still`
		)
		return
	end
	const closed = closedAngle(hinge)
	if closed == nil then
		self:WarnOnce(
			`noangle:{row.Key}`,
			`{part:GetFullName()} already hangs down from {HINGE_NAME}; set its {CLOSED_ANGLE_ATTRIBUTE} (degrees). The window flap stays still`
		)
		return
	end

	const isClosed = model:GetAttribute(SHUTTER_ATTRIBUTE) == true
	const angle = if isClosed then closed else 0
	const shutter: Shutter = {
		Model = model,
		Part = part,
		Hinge = hinge,
		HingeOffset = hinge.CFrame,
		Rest = model:GetPivot():ToObjectSpace(part.CFrame),
		Closed = closed,
		Angle = angle,
		From = angle,
		To = angle,
		StartedAt = nil,
		Connections = {},
	}
	self.Shutters[model] = shutter

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
					if self.Shutters[model] == shutter and shutter.StartedAt == nil then
						self:PoseShutter(shutter)
					end
				end)
			end
		end)
	)
	-- Late join with the window closed: final pose at once, no tween.
	self:PoseShutter(shutter)
end

function VehicleController:PoseShutter(shutter: Shutter)
	const pose = shutterPose(shutter, shutter.Angle)
	if not samePose(shutter.Part.CFrame, pose) then
		shutter.Part.CFrame = pose
	end
end

-- `Shutter` attribute changed: tween from where the flap is now to the new end pose and play the placeholder sound
function VehicleController:SwingShutter(shutter: Shutter)
	const isClosed = shutter.Model:GetAttribute(SHUTTER_ATTRIBUTE) == true
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
	audio:Play(SOUND_BUTTON, shutter.Hinge.WorldPosition)
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

-- Transition packet: start (or restart) the cover from the server time; a late packet only plays what is left
function VehicleController:PlayFade(startedAt: number)
	if workspace:GetServerTimeNow() - startedAt >= FADE_TOTAL then
		return
	end
	self.FadeStartedAt = startedAt
	if self.FadeConnection == nil then
		self.FadeConnection = RunService.RenderStepped:Connect(function()
			self:StepFade()
		end)
	end
	self:StepFade()
end

function VehicleController:StepFade()
	const elapsed = workspace:GetServerTimeNow() - self.FadeStartedAt
	if elapsed >= FADE_TOTAL then
		self.Fade(0)
		const connection = self.FadeConnection
		if connection then
			self.FadeConnection = nil
			connection:Disconnect()
		end
		return
	end
	self.Fade(fadeAlpha(elapsed))
end

function VehicleController:OnBought()
	self.BoughtDay = self.Dependencies.RoundController.Day()
	self.Bought(true)
end

-- AST-024 stand placed at SIGN-T: a Model with MapId "SIGN-T" outside any Vehicle (nil when not streamed in)
local function findSignModel(): Model?
	const root = workspace:FindFirstChild("MAP01_Assets") or workspace
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("MapId") == SIGN_MAP_ID then
			local inside = false
			for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
				if descendant:IsDescendantOf(vehicle) then
					inside = true
					break
				end
			end
			if not inside then
				return descendant
			end
		end
	end
	return nil
end

-- Local only: hides the physical sign after the purchase (the server keeps it; nothing replicates)
local function setSignHidden(model: Model, hidden: boolean)
	const modifier = if hidden then 1 else 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = modifier
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = modifier
		end
	end
end

-- Fade cover and the purchase latch: mounted at once, so a Transition right after the join still shows
function VehicleController:MountFade(playerGui: Instance)
	const round = self.Dependencies.RoundController
	const unmount, gui = Vide.root(function()
		-- The swap (Vehicle leaves the start vehicle) or a new run (Day goes back) clears the purchase latch
		Vide.effect(function()
			const vehicle = round.Vehicle()
			const day = round.Day()
			Vide.untrack(function()
				if self.Bought() and (vehicle ~= START_VEHICLE or day < self.BoughtDay) then
					self.Bought(false)
				end
				return nil
			end)
		end)

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

-- Sale sign: waits for the binding to stream in (Attachment in Terrain over the SIGN-T point)
function VehicleController:MountSign(playerGui: Instance)
	if SALE == nil then
		warn("[VehicleController] no vehicle with BuyFromDay > 0 in Content.Vehicles; sale sign not shown")
		return
	end
	if not MapIndex.WaitReady(MAP_WAIT) then
		warn("[VehicleController] MapBinding not streamed in; sale sign not shown")
		return
	end
	const point = MapIndex.FindPoint(SIGN_POINT)
	if point == nil then
		warn(`[VehicleController] MapPoint {SIGN_POINT} not found (binding wave 2, MAP-01 §16); sale sign not shown`)
		return
	end

	const model = findSignModel()
	self.SignModel = model
	local height = DEFAULT_SIGN_HEIGHT
	if model then
		const box, size = model:GetBoundingBox()
		height = box.Position.Y + size.Y / 2 - point.Position.Y + SIGN_GAP
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = "VehicleSaleSign"
	anchor.WorldPosition = point.Position + Vector3.new(0, height, 0)
	anchor.Parent = workspace.Terrain
	self.SignAnchor = anchor

	const round = self.Dependencies.RoundController
	const unmount, sign = Vide.root(function()
		const visible = function(): boolean
			return self:SignVisible()
		end
		const signModel = model
		if signModel then
			Vide.effect(function()
				setSignHidden(signModel, not visible())
			end)
		end
		return SaleSign({
			Name = "VehicleSaleSign",
			Adornee = anchor,
			Visible = visible,
			Text = function()
				return self:SignText(round.Day())
			end,
			MaxDistance = SIGN_DISTANCE,
		})
	end)
	table.insert(self.Unmounts, unmount)
	sign.Parent = playerGui
end

VehicleController:OnInit(function(self)
	self:Setup()

	PromptRules.SetShutterProbe({
		IsClosed = function(): boolean
			return self:IsShutterClosed()
		end,
	})

	self.Libs.Net.Transition:onClient(function(transition)
		if transition.Kind == "VehicleSwap" then
			self:PlayFade(transition.StartedAt)
		end
	end)

	self.Libs.Net.Notice:onClient(function(notice)
		if notice.Kind == BOUGHT_NOTICE then
			self:OnBought()
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

	-- PlayerGui and the MapBinding may arrive late; do not hold up the other OnStart.
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		self:MountFade(playerGui)
		self:MountSign(playerGui)
	end)
end)

return VehicleController
