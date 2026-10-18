--!strict
-- Game light and dark (architecture.md §19.6, T8, T45; network.md §13.2; data.md §3.3 "Lt"; FEAT-020; DEC-041,
-- DEC-055, DEC-056, DEC-189, DEC-196; TASK-059). Run place only. Single writer of the Lights set (record id =
-- Content.LightGroups.IndexOf[key]) and owner of the switch_light action.
--
-- A LightZone (Zones.luau) is active when it is night AND its group is on AND the Hush is not putting it out
-- (Rules.luau). IsLit(position) is a pure read of the compiled cache (Zones.isLit): the cache is rebuilt only when a
-- group, a radius or the zone list changes. By day every position is lit (FEAT-020 "de dia nada é escuro").
--
-- Switch (Prompt_Switch -> switch_light, tap): party state, cooldown = largest Cooldown of the Switch groups (0.5 s),
-- only on the current vehicle's switch, no effect during the Hush; turns itself on at every night ShiftStarted.
-- Trailer Lights (Kind Upgrade): switch + trailer_lights level >= 1, radius = UpgradeService LightRadius effect.
-- Hush (ANM-010, AnomalyService only): BeginHush(startedAt, holdUntil) puts the posts out from startedAt (record
-- At = startedAt, the client goes post by post by Order x Step); the trailer zones go dark when the last post is out
-- and come back with the posts at EndHush() or at holdUntil (> startedAt). A new shift or a restore ends it.
--
-- Blackout (ANM-020, family C; DEC-254; TASK-273; AnomalyService only): BeginBlackout() puts every HushOff group out at
-- once (posts with At = 0, so the client drops them all in the same frame) and turns on the breaker prompt
-- (breaker_reset, hold 3 s). The breaker sits at the back of the trailer: an Interactable anchor with PromptAction
-- breaker_reset inside the trailer Model (tools/assetplace/breaker.luau builds the panel); without one an Attachment is
-- made on the trailer at BREAKER_OFFSET (never edits the place). Holding it (server checks: blackout on, anchor on the
-- current vehicle, range) ends the blackout; AnomalyService sees it as the Action event. The switch does nothing while
-- the power is out. A new shift or a restore ends it.
--
-- Posts out (ANM-003 bell, TASK-340; AnomalyService only): BeginPostsOut() puts only the HushOff posts out at once (At = 0);
-- the trailer and its switch are untouched (the answer is turning the trailer light off). EndPostsOut() brings them back.
-- A new shift or a restore ends it.
--
-- API: IsLit(pos), IsSwitchOn(), SetSwitch(on, player?) -> boolean, BeginHush(startedAt, holdUntil), EndHush(),
-- IsHush(), BeginBlackout(), EndBlackout(), IsBlackout(), BeginPostsOut(), EndPostsOut(), GroupOn(key); signal
-- SwitchChanged(on, player?).
--
-- Current vehicle: VehicleService:Current() and its Swapped signal (architecture.md §19.2; VehicleService 620 does not
-- require LightService, so no cycle, T42). PROVISIONAL: Hush auto-end at holdUntil and "trailer dark at the last
-- post" are the reading of FEAT-020; Sanity.BasicLampRadius (0) inflates the Switch zones when > 0.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Zones = require(ReplicatedStorage.shared.Light.Zones)
local Rules = require(script.Rules)
local Modux = require(ServerScriptService.server.Modux)

-- Lights set record (network.md §13.2)
export type Record = { On: boolean, At: number }
export type Hush = Rules.Hush

const ACTION = "switch_light"
const BREAKER_ACTION = "breaker_reset"
const BREAKER_NAME = "Prompt_Breaker"
const TRAILER = "trailer"
-- Runtime breaker anchor when the place has none: in the frame of the trailer pivot (local +X = the west strip, local
-- +Z = the back wall; TrailerDoorService ANCHOR_OUT is (16.3, 3.2, 3.6)), on the outer west wall toward the back,
-- ~8 studs from the Enter Trailer prompt so the two prompt spheres never overlap. PROVISIONAL (TASK-273)
const BREAKER_OFFSET = Vector3.new(15.6, 4.4, -4.6)
const ANCHOR_TAG = "Interactable"
const POST_TAG = "StreetLight"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const RADIUS_STAT = "LightRadius"
const BREAKER_HOLD_STAT = "BreakerHold" -- UPG-014 Breaker Box (TASK-324): hold of the breaker prompt, s
const TICK_RATE = 10 -- Hz: Hush timing (last post, holdUntil) and night/vehicle/upgrade changes
const SNAPSHOT = "Lt"

-- Seconds between two switch toggles: largest Cooldown of the Switch groups (LightGroups.trailer_interior 0.5)
local function switchCooldown(): number
	local cooldown = 0
	for _, group in Content.LightGroups.List do
		if group.Kind == "Switch" then
			cooldown = math.max(cooldown, group.Cooldown)
		end
	end
	return cooldown
end

const COOLDOWN = switchCooldown()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Vehicle key of the Vehicle model that contains the instance (nil = not inside a vehicle)
local function vehicleOf(instance: Instance): string?
	local node: Instance? = instance.Parent
	while node ~= nil and node ~= workspace do
		if CollectionService:HasTag(node, VEHICLE_TAG) then
			const key = node:GetAttribute(VEHICLE_ATTRIBUTE)
			return if type(key) == "string" then key else nil
		end
		node = node.Parent
	end
	return nil
end

const LightService = Modux.Service("LightService", {
	-- RunStateService: snapshot "Lt" (data.md §3.3; not in the §19.2 row, asked to the architect in the TASK-059 note)
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"UpgradeService",
		"VehicleService",
	},
	Priority = 618,
})

function LightService:Setup()
	self.Enabled = false :: boolean
	self.Published = false :: boolean
	self.Switch = true :: boolean
	-- os.clock() of the last switch_light (cooldown)
	self.LastToggle = 0 :: number
	self.Hush = nil :: Hush?
	-- server time the power went out (ANM-020); nil = power on
	self.Blackout = nil :: number?
	-- ANM-003 bell (TASK-340): only the posts are out
	self.PostsOut = false :: boolean
	self.Breakers = {} :: { [Instance]: boolean }
	self.Zones = {} :: { [Instance]: Zones.Zone }
	self.ZonesDirty = true :: boolean
	-- Posts group -> largest StreetLight Order (Hush corner delay)
	self.MaxOrder = {} :: { [string]: number }
	self.Records = {} :: { [string]: Record }
	-- Radius and night flag used in the last compile of the cache
	self.Radii = {} :: { [string]: number }
	self.Night = false :: boolean
	self.Cache = Zones.all() :: Zones.Cache
	self.Switches = {} :: { [Instance]: boolean }
	self.Warned = {} :: { [string]: boolean }
	for _, group in Content.LightGroups.List do
		self.Records[group.Key] = { On = false, At = 0 }
	end
	-- Created here so lower-priority services (AnomalyService, ANM-003) connect in their OnInit
	self.SwitchChanged = self.Libs.Signal.new() :: SignalLib.Signal<boolean, Player?>
end

function LightService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[LightService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

-- Pure read of the cache (VitalService 1 Hz per player, anomalies). Day: always true.
function LightService:IsLit(position: Vector3): boolean
	return Zones.isLit(self.Cache, position)
end

function LightService:IsSwitchOn(): boolean
	return self.Switch
end

function LightService:IsHush(): boolean
	return self.Hush ~= nil
end

function LightService:IsBlackout(): boolean
	return self.Blackout ~= nil
end

function LightService:GroupOn(key: string): boolean
	const record = self.Records[key]
	return record ~= nil and record.On
end

function LightService:Vehicle(): string
	return self.Dependencies.VehicleService:Current()
end

function LightService:Radius(group: Content.LightGroup): number
	if group.Kind ~= "Upgrade" then
		return 0
	end
	return self.Dependencies.UpgradeService:GetEffect(RADIUS_STAT, group.Vehicle)
end

function LightService:Input(): Rules.Input
	const upgrades = self.Dependencies.UpgradeService
	return {
		Night = self.Dependencies.RoundService:IsNight(),
		Switch = self.Switch,
		Vehicle = self:Vehicle(),
		Now = now(),
		Hush = self.Hush,
		Blackout = self.Blackout ~= nil,
		PostsOut = self.PostsOut,
		Level = function(upgrade: string, vehicle: string): number
			return upgrades:GetLevel(upgrade, vehicle) or 0
		end,
		Radius = function(group: Content.LightGroup): number
			return self:Radius(group)
		end,
	}
end

-- State -----------------------------------------------------------------------------------------------------------

-- Re-evaluates every group; writes the records that changed and recompiles the cache when needed.
function LightService:Refresh()
	if not self.Enabled then
		return
	end
	const input = self:Input()
	local dirty = self.ZonesDirty or input.Night ~= self.Night
	const states: { [string]: Zones.GroupState } = {}
	for _, group in Content.LightGroups.List do
		const on = Rules.groupOn(group, input)
		const radius = if group.Kind == "Upgrade" then self:Radius(group) else nil
		states[group.Key] = {
			On = on,
			Radius = radius,
			Inflate = if group.Kind == "Switch" then Content.Sanity.BasicLampRadius else nil,
		}
		if radius ~= nil and radius ~= self.Radii[group.Key] then
			self.Radii[group.Key] = radius
			dirty = true
		end
		const record = self.Records[group.Key]
		if record.On ~= on then
			const hush = self.Hush
			-- Hush: the posts go out from its start, post by post on the client (network.md §13.2). Blackout: At = 0,
			-- every post is already past its Order x Step on the client, so they all drop in the same frame
			local at = input.Now
			if not on and group.Kind == "Posts" then
				if (self.Blackout ~= nil or self.PostsOut) and group.HushOff then
					at = 0
				elseif hush ~= nil then
					at = hush.StartedAt
				end
			end
			self:Write(group.Key, { On = on, At = at })
			dirty = true
		end
	end
	if not dirty then
		return
	end
	self.Night = input.Night
	self.ZonesDirty = false
	if not input.Night then
		self.Cache = Zones.all()
		return
	end
	const list: { Zones.Zone } = {}
	for _, zone in self.Zones do
		table.insert(list, zone)
	end
	self.Cache = Zones.compile(list, states)
end

function LightService:Write(key: string, record: Record)
	self.Records[key] = record
	if self.Published and self.Dependencies.NetService:IsRunning() then
		self.Libs.Net.Lights:update(Content.LightGroups.IndexOf[key], record)
	end
end

-- Party switch. Refused (false) during the Hush unless forced (ShiftStarted, restore).
function LightService:SetSwitch(on: boolean, player: Player?, force: boolean?): boolean
	if type(on) ~= "boolean" then
		error("[LightService] SetSwitch needs a boolean", 2)
	end
	const hush = self.Hush
	if ((hush ~= nil and not hush.PostsOnly) or self.Blackout ~= nil) and force ~= true then
		return false
	end
	if self.Switch == on then
		return true
	end
	self.Switch = on
	self:Refresh()
	self.SwitchChanged:Fire(on, player)
	return true
end

-- AnomalyService (ANM-010). holdUntil <= startedAt: the Hush lasts until EndHush(). postsOnly (restaurant, TASK-490):
-- the shop keeps its light and the switch keeps working.
function LightService:BeginHush(startedAt: number, holdUntil: number, postsOnly: boolean?)
	if not finite(startedAt) or not finite(holdUntil) then
		error("[LightService] BeginHush needs finite server times", 2)
	end
	self.Hush = {
		StartedAt = startedAt,
		DarkAt = startedAt + Rules.cornerDelay(self.MaxOrder),
		HoldUntil = if holdUntil > startedAt then holdUntil else 0,
		PostsOnly = postsOnly == true,
	}
	-- a second BeginHush while the posts are already out restarts them from the new start
	for _, group in Content.LightGroups.List do
		const record = self.Records[group.Key]
		if group.Kind == "Posts" and group.HushOff and not record.On then
			self:Write(group.Key, { On = false, At = startedAt })
		end
	end
	self:Refresh()
end

function LightService:EndHush()
	if self.Hush == nil then
		return
	end
	self.Hush = nil
	self:Refresh()
end

-- AnomalyService (ANM-020). Power out at once; the breaker prompt turns on. A second call while out is a no-op.
function LightService:BeginBlackout()
	if self.Blackout ~= nil then
		return
	end
	self.Blackout = now()
	self:EnsureBreaker()
	self:Refresh()
	self:RefreshBreakers()
end

-- Power back (breaker reset, the occurrence ended, new shift, restore).
function LightService:EndBlackout()
	if self.Blackout == nil then
		return
	end
	self.Blackout = nil
	self:Refresh()
	self:RefreshBreakers()
end

-- AnomalyService (ANM-003 bell, TASK-340): the street posts out at once, the trailer untouched.
function LightService:BeginPostsOut()
	if self.PostsOut then
		return
	end
	self.PostsOut = true
	self:Refresh()
end

function LightService:EndPostsOut()
	if not self.PostsOut then
		return
	end
	self.PostsOut = false
	self:Refresh()
end

-- Snapshot "Lt" (data.md §3.3): { S = switch }
function LightService:Capture(): { S: boolean }
	return { S = self.Switch }
end

function LightService:Restore(data: any)
	self.Hush = nil
	self:EndBlackout()
	self:EndPostsOut()
	const saved = if type(data) == "table" then data.S else nil
	self:SetSwitch(if type(saved) == "boolean" then saved else true, nil, true)
	self:Refresh()
end

-- Binding ---------------------------------------------------------------------------------------------------------

function LightService:AddZone(instance: Instance)
	if not instance:IsDescendantOf(workspace) then
		return
	end
	const zone, problem = Zones.read(instance)
	if zone == nil then
		self:WarnOnce(`zone:{instance:GetFullName()}`, `LightZone {instance:GetFullName()}: {problem}`)
		return
	end
	const group = Content.LightGroups.ByKey[zone.Group]
	if group == nil then
		self:WarnOnce(`zone:{zone.Id}`, `LightZone {zone.Id}: unknown Group "{zone.Group}"`)
		return
	end
	if table.find(group.Zones, zone.Id) == nil then
		self:WarnOnce(`zonegroup:{zone.Id}`, `LightZone {zone.Id} is not in LightGroups.{group.Key}.Zones`)
	end
	self.Zones[instance] = zone
	self.ZonesDirty = true
	self:Refresh()
end

function LightService:RemoveZone(instance: Instance)
	if self.Zones[instance] ~= nil then
		self.Zones[instance] = nil
		self.ZonesDirty = true
		self:Refresh()
	end
end

-- Every ZoneId of Content.LightGroups must be bound once (MAP-01 §16)
function LightService:CheckZones()
	const seen: { [string]: number } = {}
	for _, zone in self.Zones do
		seen[zone.Id] = (seen[zone.Id] or 0) + 1
	end
	for _, group in Content.LightGroups.List do
		for _, id in group.Zones do
			const count = seen[id] or 0
			if count ~= 1 then
				warn(`[LightService] LightZone {id} ({group.Key}) bound {count} time(s), expected 1`)
			end
		end
	end
end

function LightService:AddPost(instance: Instance)
	const group = instance:GetAttribute("Group")
	const order = instance:GetAttribute("Order")
	if type(group) ~= "string" or type(order) ~= "number" then
		return
	end
	self.MaxOrder[group] = math.max(self.MaxOrder[group] or 0, order)
end

-- Switch anchors: enabled only on the current vehicle (the trailer for sale keeps its switch off)
function LightService:IsSwitchAnchor(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == ACTION
end

function LightService:RefreshSwitches()
	const vehicle = self:Vehicle()
	const interaction = self.Dependencies.InteractionService
	for anchor in self.Switches do
		if anchor.Parent == nil then
			self.Switches[anchor] = nil
			continue
		end
		const owner = vehicleOf(anchor)
		interaction:SetPrompt(anchor, owner == nil or owner == vehicle)
	end
end

function LightService:AddSwitch(anchor: Instance)
	if not self:IsSwitchAnchor(anchor) or self.Switches[anchor] then
		return
	end
	self.Switches[anchor] = true
	self:RefreshSwitches()
end

-- Breaker (ANM-020) -------------------------------------------------------------------------------------------------

-- Trailer Model (Vehicle tag, Vehicle = "trailer")
function LightService:TrailerModel(): Model?
	for _, instance in CollectionService:GetTagged(VEHICLE_TAG) do
		if instance:IsA("Model") and instance:GetAttribute(VEHICLE_ATTRIBUTE) == TRAILER and instance:IsDescendantOf(workspace) then
			return instance
		end
	end
	return nil
end

function LightService:AddBreaker(anchor: Instance)
	if anchor:GetAttribute("PromptAction") ~= BREAKER_ACTION or self.Breakers[anchor] then
		return
	end
	self.Breakers[anchor] = true
	self:RefreshBreakers()
end

-- Prompt on while the power is out, only on the current vehicle's breaker. Its hold follows the Breaker Box upgrade
-- (UPG-014, TASK-324); nil PromptHold = the table hold (Actions.breaker_reset).
function LightService:RefreshBreakers()
	const vehicle = self:Vehicle()
	const out = self.Blackout ~= nil
	const interaction = self.Dependencies.InteractionService
	const hold = self.Dependencies.UpgradeService:GetEffect(BREAKER_HOLD_STAT)
	const promptHold = if hold == Content.Actions.ByKey[BREAKER_ACTION].Hold then nil else hold
	for anchor in self.Breakers do
		if anchor.Parent == nil then
			self.Breakers[anchor] = nil
			continue
		end
		if anchor:GetAttribute("PromptHold") ~= promptHold then
			interaction:SetPromptHold(anchor, promptHold)
		end
		const owner = vehicleOf(anchor)
		const on = out and (owner == nil or owner == vehicle)
		if anchor:GetAttribute("PromptEnabled") ~= on then
			interaction:SetPrompt(anchor, on)
		end
	end
end

-- No breaker anchor in the place: an Attachment on the trailer's biggest part at BREAKER_OFFSET (PROVISIONAL until
-- tools/assetplace/breaker.luau runs). False when the trailer is not there.
function LightService:EnsureBreaker(): boolean
	for anchor in self.Breakers do
		if anchor:IsDescendantOf(workspace) then
			return true
		end
	end
	const model = self:TrailerModel()
	if model == nil then
		self:WarnOnce("breaker", "no trailer Model: ANM-020 has no breaker to reset")
		return false
	end
	local host: BasePart? = model.PrimaryPart
	if host == nil then
		local best = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				const volume = d.Size.X * d.Size.Y * d.Size.Z
				if volume > best then
					best = volume
					host = d
				end
			end
		end
	end
	if host == nil then
		return false
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = BREAKER_NAME
	anchor:SetAttribute("PromptAction", BREAKER_ACTION)
	anchor:SetAttribute("PromptEnabled", false)
	anchor.Parent = host
	anchor.WorldPosition = model:GetPivot():PointToWorldSpace(BREAKER_OFFSET)
	self.Breakers[anchor] = true
	CollectionService:AddTag(anchor, ANCHOR_TAG)
	self:WarnOnce(
		"breakerfallback",
		`no {BREAKER_ACTION} anchor in the place: runtime Attachment on the trailer (run tools/assetplace/breaker.luau)`
	)
	return true
end

function LightService:CanReset(anchor: Instance): boolean
	if self.Blackout == nil then
		return false
	end
	const owner = vehicleOf(anchor)
	return owner == nil or owner == self:Vehicle()
end

-- Interaction -------------------------------------------------------------------------------------------------------

function LightService:CanToggle(anchor: Instance): boolean
	if self.Hush ~= nil or self.Blackout ~= nil then
		return false -- FEAT-020: no effect during the Hush; ANM-020: no power, only the breaker
	end
	if os.clock() - self.LastToggle < COOLDOWN then
		return false
	end
	const owner = vehicleOf(anchor)
	return owner == nil or owner == self:Vehicle()
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

LightService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(_player: Player, anchor: Instance, _id: number): boolean
			return self:CanToggle(anchor)
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self.LastToggle = os.clock()
			self:SetSwitch(not self.Switch, player)
		end,
	})
	-- ANM-020 breaker (hold Content.Actions.breaker_reset.Hold on the client; the server checks the power is out).
	-- AnomalyService gets the reset through InteractionService.Performed (Action event).
	self.Dependencies.InteractionService:RegisterAction(BREAKER_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			-- the panel is on the outer wall: never through it from inside the trailer
			return self:CanReset(anchor) and not self.Dependencies.VehicleService:IsInside(player)
		end,
		Run = function(_player: Player, _anchor: Instance, _id: number)
			self:EndBlackout()
		end,
	})

	-- RoundService (750) created its signals in its own Setup, before ours
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function(info)
		self.Hush = nil
		self:EndBlackout()
		self:EndPostsOut()
		if info.IsNight then
			self:SetSwitch(true, nil, true) -- every night starts lit (FEAT-020)
		end
		self:Refresh()
	end)
	round.PhaseChanged:Connect(function()
		self:Refresh()
	end)

	self.Dependencies.RunStateService:RegisterSnapshot(SNAPSHOT, function()
		return self:Capture()
	end, function(data, _mode)
		self:Restore(data)
	end)
end)

LightService:OnStart(function(self)
	if not self.Enabled then
		return
	end

	for _, post in CollectionService:GetTagged(POST_TAG) do
		self:AddPost(post)
	end
	CollectionService:GetInstanceAddedSignal(POST_TAG):Connect(function(post)
		self:AddPost(post)
	end)

	for _, part in CollectionService:GetTagged(Zones.Tag) do
		self:AddZone(part)
	end
	CollectionService:GetInstanceAddedSignal(Zones.Tag):Connect(function(part)
		self:AddZone(part)
	end)
	CollectionService:GetInstanceRemovedSignal(Zones.Tag):Connect(function(part)
		self:RemoveZone(part)
	end)
	self:CheckZones()

	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		self:AddSwitch(anchor)
		self:AddBreaker(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		self:AddSwitch(anchor)
		self:AddBreaker(anchor)
	end)

	-- Vehicle swap (§19.2: LightService connects to VehicleService.Swapped in OnStart). Also fires on a
	-- restore that changes the vehicle.
	self.Dependencies.VehicleService.Swapped:Connect(function(_from, _to)
		self:RefreshSwitches()
		self:RefreshBreakers()
		self:Refresh()
	end)
	self.Dependencies.UpgradeService.Changed:Connect(function()
		self:RefreshBreakers()
		self:Refresh()
	end)

	-- Lync.start already ran (NetService OnStart, priority 1000). Late joiners get the records from the set.
	self:Refresh()
	for index, group in Content.LightGroups.List do
		self.Libs.Net.Lights:add(index, self.Records[group.Key])
	end
	self.Published = true
end)

LightService:OnTick(function(self)
	if not self.Enabled then
		return
	end
	const hush = self.Hush
	if hush ~= nil and hush.HoldUntil > 0 and now() >= hush.HoldUntil then
		self:EndHush()
		return
	end
	self:Refresh()
end, TICK_RATE)

return LightService
