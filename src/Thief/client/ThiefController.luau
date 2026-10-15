--!strict
--[[
	ThiefController (TASK-073; FEAT-013; architecture.md §19.10; network.md §13.4; style guide §7.3)

	Reads the `Thief` set (record 1) and draws the thief bar over the cash drawer of the current vehicle: the same
	ProgressBar as the sausage, in Theme.Color.Violet (#6A5ACD), filled by (GetServerTimeNow() - StartedAt) / Duration.
	Everyone reads the same record, so everyone sees the same bar, and a late joiner gets the current one.

	Visible only while State == "Opening" (Provisional: Lurking/Approaching have no bar to show, the drawer is not
	being opened yet); hidden on Fleeing and None (caught, stolen or gone).

	Where (architecture.md §18.4, MAP-01 §6): searched inside the `Vehicle` whose `Vehicle` attribute equals
	RoundController.Vehicle:
	  1. `Bar_Thief` (Attachment or BasePart) - the fitting does not exist yet, so its absence is expected;
	  2. `Value_Anchor`, raised above the drawer value (DrawerValue) so both stay readable;
	  3. top part of the jar model (`MapId` "TRL-TIPJAR"; legacy "DRAWER" on the cart, "TRL-DRAWER" on the trailer).
	No fitting at all = no bar, no error. A late fitting (streaming, model swap) re-resolves.
	Billboard size has a pixel floor so it reads from the Mart door (~114 studs; MaxDistance >= 130, MAP-01 §6).

	Sound (user request 2026-10-10): `thief_open` at the drawer when the record turns Opening. Not for a late joiner who
	gets an Opening already under way (StartedAt older than OPEN_SOUND_WINDOW). The catch sound is the `thief_caught`
	notice (HudController).

	Presentation only: the client never decides catch or theft (ThiefService does).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local ProgressBar = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ProgressBar)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const RECORD_ID = 1 -- single record (network.md §13.4)
const VEHICLE_TAG = "Vehicle"
const BAR_NAME = "Bar_Thief"
const VALUE_NAME = "Value_Anchor"
-- the tip jar (2026-10-13) replaced the register; the legacy ids stay for old places
const DRAWER_IDS = { ["TRL-TIPJAR"] = true, DRAWER = true, ["TRL-DRAWER"] = true }
const VISIBLE_STATE = "Opening"
-- Studs over each kind of adornee (world up). Over Value_Anchor it clears the DrawerValue (0.6 + its height).
const OFFSET_BAR = Vector3.new(0, 0.3, 0)
const OFFSET_VALUE = Vector3.new(0, 2.4, 0)
const OFFSET_DRAWER = 2.6 -- plus half the part height
-- Scale part grows with the world, offset part keeps it readable far away (Provisional, MAP-01 §6).
const BAR_SIZE = UDim2.new(1.6, 72, 0.3, 12)
const MAX_DISTANCE = 140
const OPEN_SOUND = "thief_open"
const OPEN_SOUND_WINDOW = 1 -- s of server time: an older Opening is the state a joiner found, not a new one

export type Record = {
	State: string,
	StartedAt: number,
	Duration: number,
}

type Mount = {
	Adornee: Instance,
	Gui: BillboardGui,
	Unmount: () -> (),
}

const ThiefController =
	Modux.Controller("ThiefController", { Require = { "RoundController", "AudioController" }, Priority = 600 })

function ThiefController:Setup()
	self.State = Vide.source("None") :: Vide.Source<string>
	self.StartedAt = Vide.source(0) :: Vide.Source<number>
	self.Duration = Vide.source(0) :: Vide.Source<number>
	self.Now = Vide.source(workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Mount = nil :: Mount?
	self.Gui = nil :: Instance?
	self.Vehicle = nil :: Instance?
	self.VehicleConnections = {} :: { RBXScriptConnection }
	self.Ticker = nil :: RBXScriptConnection?
end

function ThiefController:Progress(): number
	const duration = self.Duration()
	if duration <= 0 then
		return 0
	end
	return math.clamp((self.Now() - self.StartedAt()) / duration, 0, 1)
end

function ThiefController:Apply(record: Record)
	const opened = record.State == VISIBLE_STATE and Vide.untrack(self.State) ~= VISIBLE_STATE
	Vide.batch(function()
		self.StartedAt(record.StartedAt)
		self.Duration(record.Duration)
		self.Now(workspace:GetServerTimeNow())
		self.State(record.State)
	end)
	self:Tick()
	if opened and workspace:GetServerTimeNow() - record.StartedAt <= OPEN_SOUND_WINDOW then
		self:PlayOpen()
	end
end

-- Heartbeat only while the bar is up.
function ThiefController:Tick()
	const opening = self.State() == VISIBLE_STATE
	if opening and self.Ticker == nil then
		self.Ticker = RunService.Heartbeat:Connect(function()
			self.Now(workspace:GetServerTimeNow())
		end)
		-- the fitting may have streamed in since the last resolve
		self:Resolve()
	elseif not opening then
		const ticker = self.Ticker
		if ticker then
			self.Ticker = nil
			ticker:Disconnect()
		end
	end
end

-- Current vehicle model: tag Vehicle + attribute Vehicle == Shift.Vehicle
function ThiefController:FindVehicle(): Instance?
	const key = self.Dependencies.RoundController.Vehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute("Vehicle") == key then
			return vehicle
		end
	end
	return nil
end

local function findNamed(root: Instance, name: string): Instance?
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and (descendant:IsA("Attachment") or descendant:IsA("BasePart")) then
			return descendant
		end
	end
	return nil
end

-- Highest BasePart of the drawer model
local function findDrawerTop(vehicle: Instance): BasePart?
	local drawer: Instance? = nil
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") then
			const id = descendant:GetAttribute("MapId")
			if type(id) == "string" and DRAWER_IDS[id] then
				drawer = descendant
				break
			end
		end
	end
	if drawer == nil then
		return nil
	end
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, descendant in drawer:GetDescendants() do
		if descendant:IsA("BasePart") then
			const top = descendant.Position.Y + descendant.Size.Y / 2
			if top > bestTop then
				bestTop = top
				best = descendant
			end
		end
	end
	return best
end

-- Adornee and offset, by the order in the header. nil = draw nothing.
local function locate(vehicle: Instance): (Instance?, Vector3)
	const bar = findNamed(vehicle, BAR_NAME)
	if bar then
		return bar, OFFSET_BAR
	end
	const value = findNamed(vehicle, VALUE_NAME)
	if value then
		return value, OFFSET_VALUE
	end
	const part = findDrawerTop(vehicle)
	if part then
		return part, Vector3.new(0, part.Size.Y / 2 + OFFSET_DRAWER, 0)
	end
	return nil, Vector3.zero
end

-- At the drawer of the current vehicle (the bar adornee, else the drawer top); on screen when neither is found.
function ThiefController:PlayOpen()
	const mount = self.Mount
	local at: Instance? = if mount then mount.Adornee else nil
	if at == nil then
		const vehicle = self.Vehicle or self:FindVehicle()
		at = if vehicle then findDrawerTop(vehicle) else nil
	end
	self.Dependencies.AudioController:Play(OPEN_SOUND, at)
end

function ThiefController:Clear()
	const mount = self.Mount
	if mount == nil then
		return
	end
	self.Mount = nil
	mount.Unmount()
	mount.Gui:Destroy()
end

function ThiefController:Draw(adornee: Instance, offset: Vector3)
	const current = self.Mount
	if current and current.Adornee == adornee then
		return
	end
	self:Clear()
	const gui = self.Gui
	if gui == nil then
		return
	end
	const unmount, billboard = Vide.root(function()
		return ProgressBar({
			Name = "ThiefBar",
			Adornee = adornee,
			Progress = function()
				return self:Progress()
			end,
			Visible = function()
				return self.State() == VISIBLE_STATE
			end,
			FillColor = function()
				return Theme.Color.Violet
			end,
			Size = BAR_SIZE,
			StudsOffset = offset,
			MaxDistance = MAX_DISTANCE,
		})
	end)
	billboard.Parent = gui
	self.Mount = { Adornee = adornee, Gui = billboard, Unmount = unmount }
end

-- Re-reads the fitting inside the current vehicle and moves the bar if it changed.
function ThiefController:Resolve()
	const vehicle = self.Vehicle
	if vehicle == nil then
		self:Clear()
		return
	end
	const adornee, offset = locate(vehicle)
	if adornee then
		self:Draw(adornee, offset)
	else
		self:Clear()
	end
end

-- Follows the current vehicle model (Shift.Vehicle change, model streamed in or swapped).
function ThiefController:Track()
	const vehicle = self:FindVehicle()
	if vehicle == self.Vehicle then
		self:Resolve()
		return
	end
	for _, connection in self.VehicleConnections do
		connection:Disconnect()
	end
	table.clear(self.VehicleConnections)
	self.Vehicle = vehicle
	if vehicle then
		local function relevant(descendant: Instance): boolean
			return descendant.Name == BAR_NAME
				or descendant.Name == VALUE_NAME
				or (descendant:IsA("Model") and type(descendant:GetAttribute("MapId")) == "string")
		end
		table.insert(
			self.VehicleConnections,
			vehicle.DescendantAdded:Connect(function(descendant)
				if relevant(descendant) then
					self:Resolve()
				end
			end)
		)
		table.insert(
			self.VehicleConnections,
			vehicle.DescendantRemoving:Connect(function(descendant)
				const mount = self.Mount
				if mount and (descendant == mount.Adornee or descendant:IsAncestorOf(mount.Adornee)) then
					-- after the removal lands, so locate no longer sees it
					task.defer(function()
						if self.Vehicle == vehicle then
							self:Clear()
							self:Resolve()
						end
					end)
				end
			end)
		)
	end
	self:Resolve()
end

function ThiefController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(VEHICLE_TAG):Connect(function()
		self:Track()
	end)
	CollectionService:GetInstanceRemovedSignal(VEHICLE_TAG):Connect(function(vehicle)
		if vehicle == self.Vehicle then
			self:Track()
		end
	end)
	Vide.root(function()
		Vide.effect(function()
			self.Dependencies.RoundController.Vehicle()
			Vide.untrack(function()
				self:Track()
			end)
		end)
	end)
end

ThiefController:OnInit(function(self)
	self:Setup()

	const thief = self.Libs.Net.Thief
	thief:onAdded(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)
	thief:onChanged(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)
	thief:onRemoved(function(id)
		if id == RECORD_ID then
			self:Apply({ State = "None", StartedAt = 0, Duration = 0 })
		end
	end)
end)

ThiefController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return ThiefController
