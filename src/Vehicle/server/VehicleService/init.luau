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
-- trailer, caller inside the trailer = LightZone LZ-1); opens by itself on NightLost, Resume and restore, and
-- AutoOpenAfter s into a selling phase that started shut; not in the snapshot. Gate "Shutter": take_order/serve/refuse refused while closed (reason Shutter:Closed) + Notice
-- shutter_closed to who acted (one per NOTICE_EVERY s). API IsShutterClosed, IsInside, IsInsidePoint, IsProtected,
-- SetShutter; signal ShutterChanged.
-- TASK-284 (owner request 2026-10-14, Provisional Q-270): the window IS the shop, day and night (the red "Open Shop"
-- switch left). It shuts by itself when Prep starts; opening it in Prep starts the selling phase (RoundService:OpenShop);
-- in a selling phase closed = RoundService Paused (no new customer, sign CLOSED). Shift end (owner request 2026-10-21,
-- Provisional; Content.ShopWindow): the Summary shuts it (the report shows with the window closed) and nothing opens it
-- through the break (Call, Prep: the old ShiftStarted opening is gone). A selling phase that starts with it still shut
-- (the Prep ran out) stays Paused and opens it by itself ShopWindow.AutoOpenAfter s later unless it was toggled first.
-- The line leaving angry is CustomerService's (ShutterChanged); anomalies: AnomalyService.
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
-- Phases where the lever works (Content.Actions.shutter_toggle.Requires.Phase: Prep, Open, Closing, Night; TASK-284)
const SHUTTER_PHASES: { string } = Content.Actions.ByKey.shutter_toggle.Requires.Phase or {}
const PREP = "Prep"
const CALL = "Call" -- night call (2026-10-17): the window lever works here too
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
-- Phase that shuts the window by itself: the end of the shift (the report shows with the window closed)
const SUMMARY = "Summary"
-- a player's opening is walking the round through Summary / Call / Prep right now (SyncShop): they keep the window open
local opening = false

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
	-- Pending automatic opening of a selling phase that started shut (ShopWindow.AutoOpenAfter): bumped by every change
	-- of the window, so a toggle in between cancels it
	self.AutoOpenToken = 0 :: number
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

-- Party window state. Closing needs a lever phase (SHUTTER_PHASES) and a vehicle with a window (dev goes through here
-- too); force = automatic paths. Opening always works. Returns the state now matches `closed`.
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
	self.AutoOpenToken += 1
	self:ApplyShutter()
	self.ShutterChanged:Fire(closed, player)
	self:SyncShop(player ~= nil)
	return true
end

-- The shop follows the window (TASK-284): opened by a player in Prep = the selling phase starts (automatic openings,
-- ShiftStarted / restore, never skip a Prep); in a selling phase closed = Paused
function VehicleService:SyncShop(byPlayer: boolean)
	const round = self.Dependencies.RoundService
	const closed = self:IsShutterClosed()
	const phase = round:GetPhase()
	if not closed and byPlayer and (phase == PREP or phase == CALL or phase == SUMMARY) then
		-- OpenShop walks Summary / Call through Prep to the night at once (PhaseChanged fires inline): those phases must
		-- not shut the window the player just opened (owner 2026-10-21: "não consegui abrir a loja")
		opening = true
		round:OpenShop()
		opening = false
	elseif round:IsSelling() then
		round:SetPaused(closed)
	end
end

-- Any shift, in the lever phases (Actions.shutter_toggle: Night = Any, Requires.Phase; TASK-284)
function VehicleService:ShutterPhase(): boolean
	const round = self.Dependencies.RoundService
	return round:IsStarted() and table.find(SHUTTER_PHASES, round:GetPhase()) ~= nil
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

-- /dev window open|close|status: forces the window now (open in a selling phase also lifts the Paused shop)
function VehicleService:DevWindow(arg: string?): string
	self:DevCheck("DevWindow")
	if arg == "open" or arg == "close" then
		self:SetShutter(arg == "close", nil, true)
	elseif arg ~= nil and arg ~= "status" then
		error("usage: window [open | close | status]", 0)
	end
	const round = self.Dependencies.RoundService
	return `window {if self:IsShutterClosed() then "closed" else "open"}; phase {round:GetPhase()}; shop {if round:IsPaused() then "paused" else "not paused"}`
end

-- Selling phase entered with the window still shut: the shop stays closed, the window opens by itself AutoOpenAfter s
-- later if nothing touched it meanwhile (same phase, still shut)
function VehicleService:ScheduleAutoOpen(phase: string)
	const round = self.Dependencies.RoundService
	round:SetPaused(true)
	self.AutoOpenToken += 1
	const token = self.AutoOpenToken
	task.delay(Content.ShopWindow.AutoOpenAfter, function()
		if self.AutoOpenToken == token and round:GetPhase() == phase and self:IsShutterClosed() then
			self:SetShutter(false, nil, true)
		end
	end)
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
	round.PhaseChanged:Connect(function(phase)
		const row = Content.Shift.ByKey[phase]
		if (phase == PREP or phase == CALL or phase == SUMMARY) and not opening then
			-- shop closed until someone opens the window (TASK-284); the night call too (2026-10-17: opening it there
			-- starts the night while Walt keeps talking); the Summary shuts it at the end of the shift (owner 2026-10-21)
			self:SetShutter(true, nil, true)
		elseif table.find(OPEN_PHASES, phase) ~= nil then
			self:SetShutter(false, nil, true)
		elseif row ~= nil and row.Selling and self:IsShutterClosed() then
			-- the Prep ran out with the window shut: closed shop, opens by itself later (owner 2026-10-21, Provisional)
			if Content.ShopWindow.AutoOpenAfter > 0 then
				self:ScheduleAutoOpen(phase)
			else
				self:SetShutter(false, nil, true)
			end
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
end)

return VehicleService
