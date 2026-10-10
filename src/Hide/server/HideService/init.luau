--!strict
-- Hide spots and safe spot (architecture.md §19.14, T52; network.md §13.6; FEAT-023; DEC-054, DEC-176, DEC-177;
-- TASK-102). Run place only. Single writer of the Hides set (record id = UserId, removed when the player gets up).
--
-- Spots: Interactable anchors H1..H4 inside the trailer, PromptAction = "hide", attribute Slot 1..4 (Required.Wave3).
-- Only the current vehicle's spots work (the trailer parked for sale keeps them off) and only up to its
-- Content.Vehicles[v].HidePoints. One player per spot, one spot per player (DEC-176).
--   hide (hold 0.5, NightOnly)  free spot -> Hides[uid] = { Slot }, CharacterService:Freeze(p, "Hide", true) and
--                               PivotTo the spot; taken spot -> Notice hide_taken, refused
--   get_up (tap)                sent by the HideController with the spot's EntityId; only the spot's holder
--   gate "Hide"                 a hidden player can only send get_up (InteractionService:AddGate, T49)
-- Released by itself: phase out of HIDE_PHASES (NightEnd, NightLost, day...), life state not Active (Down...),
-- MemberAway, leaving, character removed, vehicle swap, spot anchor gone, or the root drifting farther than
-- Actions.hide.Radius from the spot (the client owns its character physics: the server does not trust it).
-- Safe spot: no prompt; InZone(player, pointId, radius) reads a MapPoint (AnomalyService: "SS" + radius of its rule).
--
-- API: IsHidden(player), SlotOf(player), InZone(player, pointId, radius), Release(player); signal
-- Changed(player, hidden) (AnomalyService "Hide" event, §19.13).
-- PROVISIONAL (TASK-102 note): hiding allowed in the Call and Night phases; PivotTo keeps the character's height and
-- facing and moves it onto the spot's X/Z; PlayerService added to Require (CharacterRemoving, PlayerRemoving).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Slots = require(script.Slots)
local Modux = require(ServerScriptService.server.Modux)

export type Spot = Slots.Spot

const HIDE_ACTION = "hide"
const GET_UP_ACTION = "get_up"
const GATE = "Hide"
const FREEZE_REASON = "Hide"
const ANCHOR_TAG = "Interactable"
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const SLOT_ATTRIBUTE = "Slot"
-- Shift phases where a player may hide and stay hidden (the night shift before NightEnd/NightLost)
const HIDE_PHASES = { "Call", "Night" }
const TICK_RATE = 2 -- Hz: drift and anchor checks of hidden players

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

local function slotOf(anchor: Instance): number?
	const slot = anchor:GetAttribute(SLOT_ATTRIBUTE)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 then
		return nil
	end
	return slot
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	if character == nil then
		return nil
	end
	const root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

const HideService = Modux.Service("HideService", {
	Require = {
		"PlaceService",
		"PlayerService",
		"NetService",
		"RoundService",
		"RunStateService",
		"InteractionService",
		"CharacterService",
		"VehicleService",
	},
	Priority = 575,
})

function HideService:Setup()
	self.Enabled = false :: boolean
	self.Slots = Slots.new() :: Slots.Slots
	-- hide anchors seen in the Workspace
	self.Anchors = {} :: { [Instance]: boolean }
	-- Hides records written to the set (UserId)
	self.Records = {} :: { [number]: boolean }
	-- Created here so AnomalyService (570) connects in its OnInit (§19.0 rule 2)
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<Player, boolean>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function HideService:IsHidden(player: Player): boolean
	return Slots.spotOf(self.Slots, player) ~= nil
end

function HideService:SlotOf(player: Player): number?
	const spot = Slots.spotOf(self.Slots, player)
	return if spot ~= nil then spot.Slot else nil
end

-- Safe spot (no prompt): the player's root within radius (flat distance) of the MapPoint
function HideService:InZone(player: Player, pointId: string, radius: number): boolean
	if not self.Enabled or not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	const root = rootOf(player)
	const point = MapIndex.FindPoint(pointId)
	if root == nil or point == nil then
		return false
	end
	return flatDistance(root.Position, point.Position) <= radius
end

function HideService:PhaseAllows(): boolean
	const round = self.Dependencies.RoundService
	return round:IsNight() and table.find(HIDE_PHASES, round:GetPhase()) ~= nil
end

-- A spot that works now: hide anchor of the current vehicle, Slot within its HidePoints
function HideService:IsLiveSpot(anchor: Instance): boolean
	if anchor:GetAttribute("PromptAction") ~= HIDE_ACTION or not anchor:IsDescendantOf(workspace) then
		return false
	end
	const slot = slotOf(anchor)
	const vehicle = self.Dependencies.VehicleService:Current()
	const row = Content.Vehicles.ByKey[vehicle]
	if slot == nil or row == nil or slot > row.HidePoints then
		return false
	end
	return vehicleOf(anchor) == vehicle
end

-- Hide and release ----------------------------------------------------------------------------------------------

function HideService:Write(player: Player, slot: number?)
	const net = self.Dependencies.NetService
	if not net:IsRunning() then
		return
	end
	const userId = player.UserId
	if slot ~= nil then
		if self.Records[userId] then
			self.Libs.Net.Hides:update(userId, { Slot = slot })
		else
			self.Records[userId] = true
			self.Libs.Net.Hides:add(userId, { Slot = slot })
		end
	elseif self.Records[userId] then
		self.Records[userId] = nil
		self.Libs.Net.Hides:remove(userId)
	end
end

function HideService:Hide(player: Player, anchor: Instance): boolean
	const slot = slotOf(anchor)
	if slot == nil or not Slots.claim(self.Slots, player, slot, anchor) then
		return false
	end
	self.Dependencies.CharacterService:Freeze(player, FREEZE_REASON, true)
	const character = player.Character
	const position = self.Dependencies.InteractionService:Position(anchor)
	if character ~= nil and position ~= nil then
		const pivot = character:GetPivot()
		character:PivotTo(CFrame.new(position.X, pivot.Position.Y, position.Z) * pivot.Rotation)
	end
	self:Write(player, slot)
	self.Changed:Fire(player, true)
	return true
end

-- Gets the player up (get_up, or any automatic release). No-op when not hidden.
function HideService:Release(player: Player)
	if Slots.release(self.Slots, player) == nil then
		return
	end
	self.Dependencies.CharacterService:Freeze(player, FREEZE_REASON, false)
	self:Write(player, nil)
	self.Changed:Fire(player, false)
end

function HideService:ReleaseAll()
	for _, player in Slots.players(self.Slots) do
		self:Release(player)
	end
end

-- Hidden players whose spot or body no longer holds them
function HideService:Check()
	const interaction = self.Dependencies.InteractionService
	const radius = Content.Actions.ByKey[HIDE_ACTION].Radius
	for _, player in Slots.players(self.Slots) do
		const spot = Slots.spotOf(self.Slots, player)
		if spot == nil then
			continue
		end
		const root = rootOf(player)
		const position = interaction:Position(spot.Anchor)
		if
			root == nil
			or position == nil
			or not self:IsLiveSpot(spot.Anchor)
			or flatDistance(root.Position, position) > radius
		then
			self:Release(player)
		end
	end
end

-- Prompts ---------------------------------------------------------------------------------------------------------

function HideService:RefreshPrompts()
	const interaction = self.Dependencies.InteractionService
	const active = interaction:IsActive(HIDE_ACTION)
	for anchor in self.Anchors do
		if anchor.Parent == nil then
			self.Anchors[anchor] = nil
			continue
		end
		interaction:SetPrompt(anchor, active and self:IsLiveSpot(anchor))
	end
end

function HideService:AddAnchor(anchor: Instance)
	if anchor:GetAttribute("PromptAction") ~= HIDE_ACTION or self.Anchors[anchor] then
		return
	end
	if slotOf(anchor) == nil then
		warn(`[HideService] hide anchor {anchor:GetFullName()} has no valid Slot attribute`)
	end
	self.Anchors[anchor] = true
	self:RefreshPrompts()
end

-- Interaction -------------------------------------------------------------------------------------------------------

function HideService:CanHide(player: Player, anchor: Instance): boolean
	if not self:PhaseAllows() or self:IsHidden(player) or not self:IsLiveSpot(anchor) then
		return false
	end
	if not self.Dependencies.RunStateService:IsActive(player) then
		return false
	end
	const slot = slotOf(anchor) :: number
	if Slots.holder(self.Slots, slot) ~= nil then
		self.Dependencies.RunStateService:Notify(player, "hide_taken")
		return false
	end
	return true
end

function HideService:CanGetUp(player: Player, anchor: Instance): boolean
	const spot = Slots.spotOf(self.Slots, player)
	return spot ~= nil and spot.Anchor == anchor
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

HideService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(HIDE_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:CanHide(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			self:Hide(player, anchor)
		end,
	})
	interaction:RegisterAction(GET_UP_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:CanGetUp(player, anchor)
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			self:Release(player)
		end,
		On = { HIDE_ACTION }, -- get_up arrives on the hide slot anchor
	})
	interaction:AddGate(GATE, function(player: Player, action: string, _anchor: Instance): (boolean, string?)
		if action ~= GET_UP_ACTION and self:IsHidden(player) then
			return false, "Hidden"
		end
		return true, nil
	end)

	-- Higher-priority services ran their Setup before this OnInit (§19.0 rule 2)
	self.Dependencies.RoundService.PhaseChanged:Connect(function()
		if not self:PhaseAllows() then
			self:ReleaseAll()
		end
	end)
	const runState = self.Dependencies.RunStateService
	runState.LifeChanged:Connect(function(userId, _old, new)
		if new == "Active" then
			return
		end
		for _, player in Slots.players(self.Slots) do
			if player.UserId == userId then
				self:Release(player)
			end
		end
	end)
	runState.MemberAway:Connect(function(player)
		self:Release(player)
	end)
	const players = self.Dependencies.PlayerService
	players.CharacterRemoving:Connect(function(player)
		self:Release(player)
	end)
	players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
	self.Dependencies.VehicleService.Swapped:Connect(function(_from, _to)
		self:ReleaseAll()
		self:RefreshPrompts()
	end)
end)

HideService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		self:AddAnchor(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		self:AddAnchor(anchor)
	end)
end)

HideService:OnTick(function(self)
	if not self.Enabled then
		return
	end
	self:Check()
end, TICK_RATE)

return HideService
