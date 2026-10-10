--!strict
--[[
	EconomyController (TASK-024, FEAT-012; DEC-050, DEC-155; network.md §3.3 and §4.3)

	Reads the `Economy` set (record 1) into the Vide sources `Cash` (party money, the HUD reads it, TASK-039) and
	`Drawer` (cash drawer of the shift). Draws the drawer value in the world over every `Vehicle` and pops "+$N" on
	each `Sale` with Amount > 0. Everyone reads the same record, so everyone sees the same number (FEAT-012).

	Where the value goes (architecture.md §18.3/§18.4): the `Value_Anchor` fitting searched inside the `Vehicle`
	(Attachment or BasePart). TASK-005 creates it on top of the POS, so the old register and the new black POS
	(DEC-155) both work. Without it: warn once and fall back to the top part of the `DRAWER` model (MapId); without
	that either, warn and draw nothing. A late `Value_Anchor` (streaming, model swap) replaces the fallback.

	Only the vehicle in use shows the drawer (TASK-058, closes the TASK-024 Provisional): a `Vehicle` whose attribute
	`Vehicle` differs from RoundController.Vehicle (Shift.Vehicle) draws nothing, so the trailer for sale (wave 2) and
	the parked cart under the tarp after the swap never show a value. The swap redraws from the Shift record.

	The client never writes money: a sale only changes the number when the server's `Economy` record changes. The
	"+$N" is presentation of the `Sale` packet, not a prediction of the drawer.

	Sound and VFX (TASK-079; sound-list §5.4; AST-092, AST-082): a Sale with Amount > 0 plays SFX-043 `coin` on the
	drawer of the vehicle in use and hops 4 coins there (placeholder particles, Fx.luau budget); a Perfect sale (paid
	inside the tip window) adds SFX-044 `tip` and one brighter coin. No drawer drawn = no sound (nothing to hear it
	from). Keys still missing from Content.Sounds are skipped quietly.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Content = require(ReplicatedStorage.shared.Content)
local DrawerValue = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

const RECORD_ID = 1 -- single record (network.md §1, rule 5)
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle" -- key of Content.Vehicles on the tagged Model (architecture.md §18.1, T36)
const ANCHOR_NAME = "Value_Anchor"
const DRAWER_MAP_ID = "DRAWER"
-- Height of the value over the anchor (studs, world up)
const ANCHOR_OFFSET = 0.6
-- Grace for the anchor to stream in before falling back to the DRAWER model
const FALLBACK_DELAY = 5
-- Sales are <= 1/s (network.md §4.3); more than this on screen at once only stacks unreadable text
const MAX_POPS = 4
const COINS = 4 -- AST-092 payment Emit(4)
const TIP_COINS = 1 -- AST-092 tip Emit(1)
const TIP_SPEED = 1.2 -- tip with no `tip` row yet: the coin again, higher (Provisional)

type Mount = {
	Vehicle: Instance,
	Adornee: Instance?,
	Gui: Instance?,
	Unmount: (() -> ())?,
	Connections: { RBXScriptConnection },
	Fallback: thread?,
	Warned: boolean,
}

export type Record = {
	Cash: number,
	Drawer: number,
}

const EconomyController =
	Modux.Controller("EconomyController", { Require = { "RoundController", "AudioController" }, Priority = 790 })

function EconomyController:Setup()
	self.Cash = Vide.source(0) :: Vide.Source<number>
	self.Drawer = Vide.source(0) :: Vide.Source<number>
	-- true once the first Economy record arrived
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Pops = Vide.source({} :: { DrawerValue.Pop }) :: Vide.Source<{ DrawerValue.Pop }>
	self.Mounts = {} :: { [Instance]: Mount }
	self.Gui = nil :: Instance?
	self.Unmount = nil :: (() -> ())?
end

-- True when this tagged Model is the vehicle in use (Shift.Vehicle)
function EconomyController:IsCurrent(vehicle: Instance): boolean
	return vehicle:GetAttribute(VEHICLE_ATTRIBUTE) == self.Dependencies.RoundController.Vehicle()
end

function EconomyController:Apply(record: Record)
	if self.Cash() ~= record.Cash then
		self.Cash(record.Cash)
	end
	if self.Drawer() ~= record.Drawer then
		self.Drawer(record.Drawer)
	end
	if not self.Ready() then
		self.Ready(true)
	end
end

function EconomyController:Pop(amount: number)
	const list = table.clone(self.Pops())
	if #list >= MAX_POPS then
		table.remove(list, 1)
	end
	table.insert(list, { Amount = amount })
	self.Pops(list)
end

function EconomyController:PopDone(pop: DrawerValue.Pop)
	const list = self.Pops()
	const index = table.find(list, pop)
	if index then
		const copy = table.clone(list)
		table.remove(copy, index)
		self.Pops(copy)
	end
end

-- Where the drawer is drawn now (vehicle in use); nil = nothing drawn
function EconomyController:DrawerAnchor(): Instance?
	for _, mount in self.Mounts do
		if mount.Adornee and mount.Adornee.Parent then
			return mount.Adornee
		end
	end
	return nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, instance.Size.Y / 2, 0)
	end
	return nil
end

-- Sale feedback on the drawer: coin sound + coins; Perfect adds the tip (presentation only).
function EconomyController:Chime(amount: number, result: string)
	const anchor = self:DrawerAnchor()
	if anchor == nil or amount <= 0 then
		return
	end
	const audio = self.Dependencies.AudioController
	const position = positionOf(anchor)
	if Content.Sounds.ByKey.coin then
		audio:Play("coin", anchor)
	end
	if position then
		Fx.Burst(position, "Coins", COINS)
	end
	if result == "Perfect" then
		if Content.Sounds.ByKey.tip then
			audio:Play("tip", anchor)
		elseif Content.Sounds.ByKey.coin then
			audio:Play("coin", anchor, { Speed = TIP_SPEED })
		end
		if position then
			Fx.Burst(position, "Tip", TIP_COINS)
		end
	end
end

-- Value_Anchor inside the vehicle, Attachment or BasePart (the same helper rule as the prompts, §18.3)
local function findAnchor(vehicle: Instance): Instance?
	for _, descendant in vehicle:GetDescendants() do
		if descendant.Name == ANCHOR_NAME and (descendant:IsA("Attachment") or descendant:IsA("BasePart")) then
			return descendant
		end
	end
	return nil
end

-- Highest BasePart of the DRAWER model inside the vehicle, and the offset that puts the value on its top
local function findFallback(vehicle: Instance): (BasePart?, number)
	local drawer: Instance? = nil
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("MapId") == DRAWER_MAP_ID then
			drawer = descendant
			break
		end
	end
	if drawer == nil then
		return nil, 0
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
	return best, if best then best.Size.Y / 2 else 0
end

function EconomyController:Draw(mount: Mount, adornee: Instance, offset: number)
	if mount.Adornee == adornee then
		return
	end
	self:Clear(mount)
	const gui = self.Gui
	if gui == nil then
		return
	end
	const unmount, billboard = Vide.root(function()
		return DrawerValue({
			Name = "DrawerValue",
			Adornee = adornee,
			Value = self.Drawer,
			Pops = self.Pops,
			OnPopDone = function(pop)
				self:PopDone(pop)
			end,
			Offset = Vector3.new(0, offset + ANCHOR_OFFSET, 0),
		})
	end)
	billboard.Parent = gui
	mount.Adornee = adornee
	mount.Gui = billboard
	mount.Unmount = unmount
end

function EconomyController:Clear(mount: Mount)
	const unmount = mount.Unmount
	if unmount then
		mount.Unmount = nil
		unmount()
	end
	const billboard = mount.Gui
	if billboard then
		mount.Gui = nil
		billboard:Destroy()
	end
	mount.Adornee = nil
end

function EconomyController:Resolve(mount: Mount)
	if not self:IsCurrent(mount.Vehicle) then
		-- not the vehicle in use: no value (the fallback timer, if pending, resolves again when it fires)
		self:Clear(mount)
		return
	end
	const anchor = findAnchor(mount.Vehicle)
	if anchor then
		self:Draw(mount, anchor, 0)
		return
	end
	if mount.Fallback then
		-- still inside the grace window: wait for the anchor to stream in
		return
	end
	const part, offset = findFallback(mount.Vehicle)
	if not mount.Warned then
		mount.Warned = true
		warn(
			("[EconomyController] %s has no %s (TASK-005 creates it on top of the POS); %s"):format(
				mount.Vehicle:GetFullName(),
				ANCHOR_NAME,
				if part then "using the top of the DRAWER model" else "drawer value not shown"
			)
		)
	end
	if part then
		self:Draw(mount, part, offset)
	else
		self:Clear(mount)
	end
end

function EconomyController:Track(vehicle: Instance)
	if self.Mounts[vehicle] then
		return
	end
	const mount: Mount = {
		Vehicle = vehicle,
		Adornee = nil,
		Gui = nil,
		Unmount = nil,
		Connections = {},
		Fallback = nil,
		Warned = false,
	}
	self.Mounts[vehicle] = mount

	table.insert(
		mount.Connections,
		vehicle.DescendantAdded:Connect(function(descendant)
			if descendant.Name == ANCHOR_NAME and mount.Adornee ~= descendant then
				self:Resolve(mount)
			end
		end)
	)
	table.insert(
		mount.Connections,
		vehicle:GetAttributeChangedSignal(VEHICLE_ATTRIBUTE):Connect(function()
			self:Resolve(mount)
		end)
	)
	table.insert(
		mount.Connections,
		vehicle.DescendantRemoving:Connect(function(descendant)
			if descendant == mount.Adornee then
				-- after the removal lands, so findAnchor no longer sees it
				task.defer(function()
					if self.Mounts[vehicle] == mount then
						self:Clear(mount)
						self:Resolve(mount)
					end
				end)
			end
		end)
	)

	if findAnchor(vehicle) == nil then
		mount.Fallback = task.delay(FALLBACK_DELAY, function()
			mount.Fallback = nil
			if self.Mounts[vehicle] == mount and mount.Adornee == nil then
				self:Resolve(mount)
			end
		end)
	end
	self:Resolve(mount)
end

function EconomyController:Untrack(vehicle: Instance)
	const mount = self.Mounts[vehicle]
	if mount == nil then
		return
	end
	self.Mounts[vehicle] = nil
	for _, connection in mount.Connections do
		connection:Disconnect()
	end
	table.clear(mount.Connections)
	const fallback = mount.Fallback
	if fallback then
		mount.Fallback = nil
		if coroutine.status(fallback) == "suspended" then
			task.cancel(fallback)
		end
	end
	self:Clear(mount)
end

function EconomyController:Watch(gui: Instance)
	self.Gui = gui
	-- Vehicle swap (Shift.Vehicle): redraw every tracked vehicle. The first run of the effect sees no mount yet.
	const round = self.Dependencies.RoundController
	self.Unmount = Vide.root(function()
		Vide.effect(function()
			round.Vehicle()
			Vide.untrack(function()
				for _, mount in self.Mounts do
					self:Resolve(mount)
				end
				return nil
			end)
		end)
	end)
	CollectionService:GetInstanceAddedSignal(VEHICLE_TAG):Connect(function(vehicle)
		self:Track(vehicle)
	end)
	CollectionService:GetInstanceRemovedSignal(VEHICLE_TAG):Connect(function(vehicle)
		self:Untrack(vehicle)
	end)
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		self:Track(vehicle)
	end
end

EconomyController:OnInit(function(self)
	self:Setup()

	const economy = self.Libs.Net.Economy
	economy:onAdded(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)
	economy:onChanged(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)

	-- Presentation only: the drawer number itself comes from Economy. Wrong/Left/Refused carry Amount 0.
	self.Libs.Net.Sale:onClient(function(sale)
		if sale.Amount > 0 then
			self:Pop(sale.Amount)
			self:Chime(sale.Amount, sale.Result)
		end
	end)
end)

EconomyController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return EconomyController
