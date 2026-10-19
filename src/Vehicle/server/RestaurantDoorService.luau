--!strict
-- RestaurantDoorService (owner 2026-10-18: "a porta dos fundos não seja automática, aberta com um ProximityPrompt; isso
-- abre margem para anomalia de deixar a porta fechada"). Run place only, and only with Content.Restaurant.Rules.Enabled.
--
-- Doors: every Model tagged AutoDoor whose MapId is in Content.Restaurant.ManualDoors (DOOR-B, the pantry's exit). At
-- start the Model gets DoorManual = true and DoorOpen = false: the client DoorController stops opening it by proximity and
-- follows DoorOpen. One prompt anchor (an Attachment in the leaf's plane at handle height, PromptAction door_toggle,
-- reached from both sides; owner 2026-10-18: "na porta tem dois proximity prompts", there used to be one per face) opens
-- and closes it. While open the server copy of the leaf does not collide (customers and players walk through).
-- Lock (anomalies): SetLocked(reason, on) - while any reason holds, the door closes at once, the prompt reads "Locked"
-- and pressing it does nothing but fire Tried. Several reasons stack (as TrailerDoorService:SetLocked).
-- Signals: Opened(player, mapId), Closed(player?, mapId), Tried(player, mapId) (pressed while locked). Readers: the
-- anomalies that test "do not open the back door" (ANM-009 in the restaurant).
-- API: IsOpen(mapId?), SetOpen(mapId, open, player?), SetLocked(reason, on), IsLocked(), DoorPosition(mapId?).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

type Door = {
	MapId: string,
	Model: Model,
	Leaves: { BasePart },
	Collide: { [BasePart]: boolean },
	Anchors: { Attachment },
	Open: boolean,
}

const AUTO_TAG = "AutoDoor"
const ANCHOR_TAG = "Interactable"
const ACTION = "door_toggle"
const OPEN_TEXT = "Open Door"
const CLOSE_TEXT = "Close Door"
const LOCKED_TEXT = "Locked"
const HANDLE_Y = 3.6 -- studs above the leaf bottom

const RestaurantDoorService = Modux.Service("RestaurantDoorService", {
	Require = { "PlaceService", "InteractionService", "RoundService" },
	Priority = 606,
})

function RestaurantDoorService:Setup()
	self.Enabled = false :: boolean
	self.Doors = {} :: { [string]: Door }
	self.AnchorDoor = {} :: { [Instance]: string }
	self.Locks = {} :: { [string]: boolean }
	self.Opened = self.Libs.Signal.new() :: SignalLib.Signal<Player, string>
	self.Closed = self.Libs.Signal.new() :: SignalLib.Signal<Player?, string>
	self.Tried = self.Libs.Signal.new() :: SignalLib.Signal<Player, string>
end

-- Reads ---------------------------------------------------------------------------------------------------------------

local function wanted(mapId: string): boolean
	return table.find(Content.Restaurant.ManualDoors, mapId) ~= nil
end

function RestaurantDoorService:Door(mapId: string?): Door?
	if mapId ~= nil then
		return self.Doors[mapId]
	end
	for _, door in self.Doors do
		return door
	end
	return nil
end

function RestaurantDoorService:IsOpen(mapId: string?): boolean
	const door = self:Door(mapId)
	return door ~= nil and door.Open
end

function RestaurantDoorService:IsLocked(): boolean
	return next(self.Locks) ~= nil
end

function RestaurantDoorService:DoorPosition(mapId: string?): Vector3?
	const door = self:Door(mapId)
	if door == nil or door.Leaves[1] == nil then
		return nil
	end
	return door.Leaves[1].Position
end

-- Writes --------------------------------------------------------------------------------------------------------------

function RestaurantDoorService:Refresh(door: Door)
	const locked = self:IsLocked()
	const text = if locked then LOCKED_TEXT elseif door.Open then CLOSE_TEXT else OPEN_TEXT
	for _, anchor in door.Anchors do
		self.Dependencies.InteractionService:SetPrompt(anchor, true, text)
	end
end

function RestaurantDoorService:SetOpen(mapId: string, open: boolean, player: Player?)
	const door = self.Doors[mapId]
	if door == nil or door.Open == open then
		return
	end
	door.Open = open
	for _, leaf in door.Leaves do
		leaf.CanCollide = if open then false else door.Collide[leaf]
	end
	if open and player ~= nil then
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			door.Model:SetAttribute("DoorFrom", root.Position)
		end
	end
	door.Model:SetAttribute("DoorOpen", open)
	self:Refresh(door)
	if open then
		if player ~= nil then
			self.Opened:Fire(player, mapId)
		end
	else
		self.Closed:Fire(player, mapId)
	end
end

function RestaurantDoorService:SetLocked(reason: string, on: boolean)
	if on then
		self.Locks[reason] = true
	else
		self.Locks[reason] = nil
	end
	for mapId, door in self.Doors do
		if on then
			self:SetOpen(mapId, false, nil)
		end
		self:Refresh(door)
	end
end

-- Binding -------------------------------------------------------------------------------------------------------------

function RestaurantDoorService:Bind(model: Instance)
	if not model:IsA("Model") then
		return
	end
	const mapId = model:GetAttribute("MapId")
	if type(mapId) ~= "string" or not wanted(mapId) or self.Doors[mapId] ~= nil then
		return
	end
	const leaves: { BasePart } = {}
	const collide: { [BasePart]: boolean } = {}
	local main: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(leaves, part)
			const orig = part:GetAttribute("DoorOrigCanCollide")
			collide[part] = if type(orig) == "boolean" then orig else part.CanCollide
			if part.Name == "Leaf" or main == nil then
				main = part
			end
		end
	end
	if main == nil then
		return
	end
	const leaf: BasePart = main
	-- one prompt anchor in the leaf's plane at handle height; parented to the model (not the leaf: the leaf moves on
	-- the client, the prompt must stay at the frame). PromptController's sight check ignores the door's own Model.
	const holder = Instance.new("Part")
	holder.Name = "DoorPromptHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = leaf.CFrame
	holder.Parent = model
	const anchors: { Attachment } = {}
	const attachment = Instance.new("Attachment")
	attachment.Name = "Prompt_Door"
	attachment.Position = Vector3.new(0, -leaf.Size.Y / 2 + HANDLE_Y, 0)
	attachment:SetAttribute("PromptAction", ACTION)
	attachment.Parent = holder
	CollectionService:AddTag(attachment, ANCHOR_TAG)
	table.insert(anchors, attachment)
	self.AnchorDoor[attachment] = mapId
	model:SetAttribute("DoorManual", true)
	model:SetAttribute("DoorOpen", false)
	const door: Door = { MapId = mapId, Model = model, Leaves = leaves, Collide = collide, Anchors = anchors, Open = false }
	self.Doors[mapId] = door
	for _, part in leaves do
		part.CanCollide = collide[part]
	end
	self:Refresh(door)
end

-- Lifecycle -----------------------------------------------------------------------------------------------------------

RestaurantDoorService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(_player: Player, anchor: Instance, _id: number): boolean
			return self.AnchorDoor[anchor] ~= nil
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			const mapId = self.AnchorDoor[anchor]
			const door = if mapId ~= nil then self.Doors[mapId] else nil
			if mapId == nil or door == nil then
				return
			end
			if self:IsLocked() then
				self.Tried:Fire(player, mapId)
				return
			end
			self:SetOpen(mapId, not door.Open, player)
		end,
	})
end)

RestaurantDoorService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	for _, model in CollectionService:GetTagged(AUTO_TAG) do
		self:Bind(model)
	end
	CollectionService:GetInstanceAddedSignal(AUTO_TAG):Connect(function(model)
		self:Bind(model)
	end)
	-- every shift starts with the door shut and unlocked
	self.Dependencies.RoundService.ShiftStarted:Connect(function(_info)
		table.clear(self.Locks)
		for mapId in self.Doors do
			self:SetOpen(mapId, false, nil)
		end
		for _, door in self.Doors do
			self:Refresh(door)
		end
	end)
end)

return RestaurantDoorService
