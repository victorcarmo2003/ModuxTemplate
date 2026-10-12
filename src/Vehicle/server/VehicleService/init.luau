--!strict
-- The vehicle in use and the service window (architecture.md §19.5, §19.14 v4.2; network.md §13.1, §13.6; FEAT-016, FEAT-023;
-- DEC-204, DEC-221; TASK-056, TASK-130). Run place only.
-- 2026-10-12 (user decision, Provisional): ONE vehicle. The Food Trailer is the vehicle from Day 1 and stays where the
-- owner placed it at the Pad (MapPoint TRL = its pose; this service never moves it): no cart, no trailer purchase, no FOR
-- SALE sign, no offer call, no swap and no tarp. The cart models live in ServerStorage (CART_Backup). Kept for the
-- others: Current() (always the trailer key), Models(). The Swapped signal and the "Veh" snapshot stay as inert history
-- (Swapped never fires; Restore ignores the stored key) so the services that still connect to them do not break.
-- Service window (architecture.md §19.14 v4.2, network.md §13.6, T61; FEAT-023; DEC-204, DEC-221; TASK-130): state of
-- the trailer (Content.Vehicles[v].HasShutter). Single writer of the attribute Shutter on the vehicle Models (true =
-- closed). Action shutter_toggle (Prompt_Shutter, hold 0.5, night only, party cooldown 1 s, Active member, anchor of the
-- trailer, caller inside the trailer = LightZone LZ-1); opens by itself on ShiftStarted, NightLost, Resume and restore;
-- not in the snapshot. Gate "Shutter": take_order/serve/refuse refused while closed (reason Shutter:Closed) + Notice
-- shutter_closed to who acted (one per NOTICE_EVERY s). API IsShutterClosed, IsInside, IsInsidePoint, IsProtected,
-- SetShutter; signal ShutterChanged.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(ServerScriptService.server.Modux)
local Shutter = require(script.Shutter)

const VEHICLE_TAG = "Vehicle"
const SNAPSHOT = "Veh"
const VEHICLE = Content.RunParams.StartVehicle
-- MapPoint of the trailer pose at the Pad (MAP-01 §16.3: point = model pivot). Checked, never used to move it.
const TRL_POINT = "TRL"
const POSE_TOLERANCE = 1.5 -- studs between the model pivot and the TRL point before a warning
-- Phases where the window cannot be closed (waiting for the roster / opening cutscene / run end)
const CLOSED_PHASES = { "Resume", "Intro", "RunEnd", "NightLost" }
-- Service window (§19.14)
const SHUTTER_ACTION = "shutter_toggle"
const SHUTTER_ATTRIBUTE = "Shutter"
const SHUTTER_GATE = "Shutter"
const SHUTTER_NOTICE = "shutter_closed"
const SHUTTER_COOLDOWN = 1 -- s between two toggles, party-wide (Q-173; not a Content.Actions field)
const NOTICE_EVERY = 2 -- s between two shutter_closed notices to the same player
-- Counter actions refused while the window is closed (the queue waits, patience keeps running)
const COUNTER_ACTIONS: { [string]: boolean } = { take_order = true, serve = true, refuse = true }
-- PromptText when closed. Content.Actions.shutter_toggle.Text ("Close Window") is the open state; the table has one
-- Text per action. PLACEHOLDER until ui-text.md (content-data.md §6 row shutter_toggle).
const OPEN_TEXT = "Open Window"
-- Phases where the window opens by itself (NightLost; Resume = restore waiting for the roster)
const OPEN_PHASES = { "NightLost", "Resume" }

-- Model tagged Vehicle that contains `instance` (or is it), with its key
local function vehicleOf(instance: Instance): (Instance?, string?)
	local current: Instance? = instance
	while current ~= nil and current ~= workspace do
		if CollectionService:HasTag(current, VEHICLE_TAG) then
			const key = current:GetAttribute("Vehicle")
			return current, if type(key) == "string" then key else nil
		end
		current = current.Parent
	end
	return nil, nil
end

const VehicleService = Modux.Service("VehicleService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"UpgradeService",
		"CharacterService",
	},
	Priority = 620,
})

function VehicleService:Setup()
	self.Vehicle = self.Libs.Charm.atom(VEHICLE) :: Charm.Atom<string>
	self.MissingPoints = {} :: { [string]: boolean }
	-- Legacy (never fired since the trailer is the only vehicle): Item, Kitchen, Light and TrailerDoor still connect
	self.Swapped = self.Libs.Signal.new() :: SignalLib.Signal<string, string>
	-- Service window of the trailer
	self.ShutterClosed = false :: boolean
	self.ShutterAt = 0 :: number -- os.clock() of the last shutter_toggle (party cooldown; 0 = none yet)
	self.ShutterAnchors = {} :: { [Instance]: boolean }
	self.InteriorPart = nil :: BasePart?
	self.NoticeAt = setmetatable({}, { __mode = "k" }) :: { [Player]: number }
	-- (closed, player?) player = who toggled; nil = automatic opening or dev. AnomalyService (570) connects in OnInit
	self.ShutterChanged = self.Libs.Signal.new() :: SignalLib.Signal<boolean, Player?>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function VehicleService:Current(): string
	return self.Vehicle()
end

-- World ------------------------------------------------------------------------------------------------------------

function VehicleService:Models(): { Instance }
	const out = {}
	for _, model in CollectionService:GetTagged(VEHICLE_TAG) do
		if model:IsDescendantOf(workspace) and type(model:GetAttribute("Vehicle")) == "string" then
			table.insert(out, model)
		end
	end
	return out
end

-- The trailer sits where the owner put it; the TRL point must say the same (anomaly zones, the trailer door and the
-- cutscene read it). A mismatch is warned once, never fixed here.
function VehicleService:CheckPose()
	if not MapIndex.HasBinding() then
		return
	end
	const point = MapIndex.FindPoint(TRL_POINT)
	if point == nil then
		if not self.MissingPoints[TRL_POINT] then
			self.MissingPoints[TRL_POINT] = true
			warn(`[VehicleService] MapPoint {TRL_POINT} not found (MAP-01 §16)`)
		end
		return
	end
	for _, model in self:Models() do
		if model:IsA("PVInstance") and (model:GetPivot().Position - point.Position).Magnitude > POSE_TOLERANCE then
			const key = `pose:{model.Name}`
			if not self.MissingPoints[key] then
				self.MissingPoints[key] = true
				warn(`[VehicleService] {model.Name} is not at MapPoint {TRL_POINT}: the point must follow the model (trailer_only_map.luau)`)
			end
		end
	end
end

-- Service window (§19.14) -----------------------------------------------------------------------------------------

local function hasShutter(key: string?): boolean
	const row = if key ~= nil then Content.Vehicles.ByKey[key] else nil
	return row ~= nil and row.HasShutter
end

function VehicleService:IsShutterClosed(): boolean
	return self.ShutterClosed and hasShutter(self.Vehicle())
end

-- Interior volume (Shutter.luau: LightZone LZ-1; L3-20). Cached part, scanned again when it leaves the Workspace.
function VehicleService:Interior(): BasePart?
	const cached = self.InteriorPart
	if cached ~= nil and cached:IsDescendantOf(workspace) then
		return cached
	end
	self.InteriorPart = Shutter.findInterior()
	return self.InteriorPart
end

-- Point inside the trailer interior
function VehicleService:IsInsidePoint(position: Vector3): boolean
	if typeof(position) ~= "Vector3" or not hasShutter(self.Vehicle()) then
		return false
	end
	const part = self:Interior()
	return part ~= nil and Shutter.contains(part, position)
end

-- Root of the player's character inside the trailer
function VehicleService:IsInside(player: Player): boolean
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	return self:IsInsidePoint(root.Position)
end

-- N8/N9 protected state (DEC-221): window closed and inside the trailer
function VehicleService:IsProtected(player: Player): boolean
	return self:IsShutterClosed() and self:IsInside(player)
end

function VehicleService:IsShutterAnchor(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == SHUTTER_ACTION
end

-- Attribute Shutter of every Model with a window and the prompts
function VehicleService:ApplyShutter()
	const current = self.Vehicle()
	for _, model in self:Models() do
		const key = model:GetAttribute("Vehicle") :: string
		if hasShutter(key) then
			model:SetAttribute(SHUTTER_ATTRIBUTE, if key == current then self.ShutterClosed else true)
		end
	end
	const interaction = self.Dependencies.InteractionService
	const enabled = interaction:IsActive(SHUTTER_ACTION)
	const text = if self.ShutterClosed then OPEN_TEXT else nil
	for anchor in self.ShutterAnchors do
		if anchor.Parent == nil then
			self.ShutterAnchors[anchor] = nil
			continue
		end
		const _, key = vehicleOf(anchor)
		const live = enabled and key == current and hasShutter(key)
		interaction:SetPrompt(anchor, live, if live then text else nil)
	end
end

function VehicleService:AddShutterAnchor(anchor: Instance)
	if not self:IsShutterAnchor(anchor) or self.ShutterAnchors[anchor] then
		return
	end
	self.ShutterAnchors[anchor] = true
	self:ApplyShutter()
end

-- Party window state. Closing needs a night shift outside the closed phases and a vehicle with a window (dev goes
-- through here too: "shutter close" by day does nothing); force = automatic opening paths. Opening always works.
-- Returns the state now matches `closed`.
function VehicleService:SetShutter(closed: boolean, player: Player?, force: boolean?): boolean
	if type(closed) ~= "boolean" then
		error("[VehicleService] SetShutter needs a boolean", 2)
	end
	if closed and force ~= true then
		if not hasShutter(self.Vehicle()) or not self:ShutterPhase() then
			return false
		end
	end
	if self.ShutterClosed == closed then
		return true
	end
	self.ShutterClosed = closed
	self:ApplyShutter()
	self.ShutterChanged:Fire(closed, player)
	return true
end

-- Night shift, outside Resume/Intro/RunEnd/NightLost. Follows Actions.shutter_toggle.Night = NightOnly, i.e. the
-- night shift as a whole (its Prep included, same as KitchenService/ItemService read Night; L3-18, PROVISIONAL)
function VehicleService:ShutterPhase(): boolean
	const round = self.Dependencies.RoundService
	return round:IsStarted() and round:IsNight() and table.find(CLOSED_PHASES, round:GetPhase()) == nil
end

-- shutter_toggle Validate: Active member, anchor of the trailer, caller inside it, phase, party cooldown
function VehicleService:CanToggleShutter(player: Player, anchor: Instance): boolean
	if not self.Dependencies.RunStateService:IsActive(player) or not self:ShutterPhase() then
		return false
	end
	const _, key = vehicleOf(anchor)
	if key ~= self.Vehicle() or not hasShutter(key) or not self:IsInside(player) then
		return false -- L3-17: the button works only from inside the trailer
	end
	-- cooldown: silent refusal (L3-19)
	return os.clock() - self.ShutterAt >= SHUTTER_COOLDOWN
end

-- Gate refusal notice, at most one per NOTICE_EVERY s per player (FEAT-005)
function VehicleService:NotifyClosed(player: Player)
	const at = os.clock()
	const last = self.NoticeAt[player]
	if last ~= nil and at - last < NOTICE_EVERY then
		return
	end
	self.NoticeAt[player] = at
	self.Dependencies.RunStateService:Notify(player, SHUTTER_NOTICE)
end

-- Snapshot "Veh" (data.md §3.3): the key of the vehicle. Only one exists now, so a restore just re-opens the window
-- (it is not in the snapshot, §19.14); an old snapshot that says "cart" is accepted and ignored.
function VehicleService:Restore(_data: any)
	self.Vehicle(VEHICLE)
	self:SetShutter(false, nil, true)
	self:ApplyShutter()
end

-- Dev hooks (Commands/Vehicle.luau) ------------------------------------------------------------------------------

function VehicleService:DevCheck(name: string)
	if not self.Dependencies.PlaceService:IsDev() then
		error(`[VehicleService] {name} is dev mode only`, 3)
	end
end

-- /dev trailer reset: window open again
function VehicleService:DevReset()
	self:DevCheck("DevReset")
	self:Restore(VEHICLE)
end

-- /dev trailer status: vehicle, window, distance of the model to the TRL point
function VehicleService:DevStatus(): string
	self:DevCheck("DevStatus")
	local drift = "no model"
	const point = if MapIndex.HasBinding() then MapIndex.FindPoint(TRL_POINT) else nil
	for _, model in self:Models() do
		if model:IsA("PVInstance") and point ~= nil then
			drift = string.format("%.2f studs from TRL", (model:GetPivot().Position - point.Position).Magnitude)
		end
	end
	return `vehicle {self.Vehicle()}; window {if self:IsShutterClosed() then "closed" else "open"}; {drift}`
end

VehicleService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	const round = self.Dependencies.RoundService
	round:SetVehicleProbe(function(): string
		return self.Vehicle()
	end)

	self.Dependencies.RunStateService:RegisterSnapshot(SNAPSHOT, function()
		return self.Vehicle()
	end, function(data, _mode)
		self:Restore(data)
	end)

	-- Service window (§19.14). InteractionService (730) built its handler table in its OnInit, before this one
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(SHUTTER_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:CanToggleShutter(player, anchor)
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self.ShutterAt = os.clock()
			self:SetShutter(not self.ShutterClosed, player, true)
		end,
	})
	interaction:AddGate(SHUTTER_GATE, function(player: Player, action: string, _anchor: Instance): (boolean, string?)
		if COUNTER_ACTIONS[action] and self:IsShutterClosed() then
			-- the prompt is already hidden on clients with the window closed: this is the race (a mate closed it
			-- during the hold)
			self:NotifyClosed(player)
			return false, "Closed"
		end
		return true, nil
	end)
	round.ShiftStarted:Connect(function(_info)
		self:SetShutter(false, nil, true)
	end)
	round.PhaseChanged:Connect(function(phase)
		if table.find(OPEN_PHASES, phase) ~= nil then
			self:SetShutter(false, nil, true)
		end
	end)
end)

VehicleService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end

	CollectionService:GetInstanceAddedSignal("Interactable"):Connect(function(anchor)
		self:AddShutterAnchor(anchor)
	end)

	-- Service window: anchors, attribute of the vehicle and the interior volume
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if self:IsShutterAnchor(anchor) then
			self.ShutterAnchors[anchor] = true
		end
	end
	if self:Interior() == nil then
		warn(`[VehicleService] LightZone {Shutter.InteriorZone} not bound (MAP-01 §16); IsInside is always false`)
	end
	if next(self.ShutterAnchors) == nil then
		warn("[VehicleService] no Prompt_Shutter (PromptAction shutter_toggle) in the Workspace (MAP-01 §16.5)")
	end
	self:ApplyShutter()
	self:CheckPose()
end)

return VehicleService
