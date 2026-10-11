--!strict
--[[
	SeatingController (TASK-147; FEAT-037; UPG-008; network.md §14; architecture.md §19.28)

	Presents the Pad tables from the server; decides nothing (SeatingService buys, seats, cleans and pays).

	  - Tables set (record id = table index 1..Content.Seating.Tables) -> one Vide source per table.
	  - The table Model is found by the tag Seating.Binding.Tag + attribute TableIndex (bound place, TASK-149, or
	    written at runtime by the server fallback); the attribute is watched, so a late tag/attribute still binds.
	  - Look (Look.luau, local only): Locked = hidden (nothing before the Day 2); Ghost = Seating.GhostTransparency, no
	    shadow (the server writes CanCollide off, which replicates); Free / Occupied / Dirty = authored look.
	  - Price plate (Interface/Components/TableSign, studs-sized, MaxDistance 45) over the next table for sale only
	    (Ghost with Price > 0): "Patio Table" + "$30", the tag red while the party cash (Economy set) cannot pay it.
	    The prompt pill ("Buy Table — $30") is the PromptController's, from the server's anchor attributes.
	  - Bought (Ghost -> Free): confetti (Kitchen Fx budget) + `upgrade_done` (SFX-065) on the table. The toast
	    "Table added!" is HudController's (Notice table_added).
	  - Dirty: tray + wrapper + cup + tip coins (Tray.luau; `Table_Tray` model under ReplicatedStorage.Assets
	    replaces the drawn one) on Tray_Anchor, else the centre of the table top. Rebuilt when the tip changes.
	  - Cleaned (Dirty -> Free with the previous Tip > 0, while the drawer is open): "+$N" rising over the table
	    (DrawerValue Pop, same look as the drawer one), a Tip coin burst and SFX `coin`. The "+$N" on the drawer is
	    EconomyController's (the drawer value goes up). The Summary reset writes the same Dirty -> Free with Tip -> 0:
	    it is told apart by the phase, read one defer later (the Round record of the same flush has landed by then).
	  - Diners (Meal.luau): rigs with the `Seated` attribute hold a hot dog that shrinks in 3 bites; npc_sit /
	    npc_eat_seated play through AnimController when they have an Id.

	Not here yet (TASK-147 rest): Patio Lights string (UPG-009) and Back Bar (UPG-010): no model nor binding yet
	(TASK-149 / TASK-153). Listeners in OnInit (before Lync.start); tags and rigs are scanned in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local TableSign = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TableSign)
local Pop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue.Pop)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local Look = require(script.Look)
local Tray = require(script.Tray)
local Meal = require(script.Meal)

const SEATING = Content.Seating
const BINDING = SEATING.Binding
const ECONOMY_ID = 1 -- single record (network.md §1 rule 5)
const SIGN_TITLE = "Patio Table" -- ui-text.md (TASK-150), Provisional
const SIGN_LIFT = 2.8 -- studs over the table top: clears the prompt pill (anchor at +0.6)
const SIGN_DISTANCE = 45
const POP_LIFT = 1.2 -- studs over the table top where the "+$N" starts
const POP_WIDTH = 180
const POP_HEIGHT = 130
const POP_DISTANCE = 80
const CONFETTI = 14
const TIP_COINS = 3
-- Phases with the drawer open (EconomyService:IsDrawerOpen): a Dirty -> Free there is a cleaning
const OPEN_PHASES: { [string]: boolean } = { Closing = true }
for _, phase in SEATING.SitPhases do
	OPEN_PHASES[phase] = true
end

export type State = "Locked" | "Ghost" | "Free" | "Occupied" | "Dirty"

export type Record = { State: string, Price: number, Npc1: number, Npc2: number, Tip: number }

type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Model: Model?,
	Saved: Look.Saved?, -- authored look of Model
	Top: Attachment?, -- table top centre (Terrain), adornee of the plate and the pops
	TrayAt: CFrame?, -- where the tray goes
	Tray: Model?,
	TrayTip: number, -- tip the tray was built with
	Unmount: (() -> ())?,
	Gui: Instance?,
}

const SeatingController = Modux.Controller(
	"SeatingController",
	{ Require = { "RoundController", "AudioController", "AnimController" }, Priority = 680 }
)

function SeatingController:Setup()
	self.Spots = {} :: { [number]: Spot }
	-- table Model -> its watcher connections
	self.Tracked = {} :: { [Model]: { RBXScriptConnection } }
	self.Gui = nil :: Instance?
	self.Folder = nil :: Folder?
	-- party cash (Economy.Cash); until the first record arrives the plate is never red
	self.Cash = Vide.source(0) :: Vide.Source<number>
	self.CashReady = Vide.source(false) :: Vide.Source<boolean>
	self.Meal = (Meal.new({
		Play = function(model: Model, key: string, looped: boolean)
			self.Dependencies.AnimController:Play(model, key, { Looped = looped })
		end,
		Stop = function(model: Model, key: string)
			self.Dependencies.AnimController:Stop(model, key)
		end,
	})) :: Meal.Meal
end

-- Reactive read of a table record (nil = unknown). For other controllers and debugging.
function SeatingController:RecordOf(index: number): Record?
	const spot = self.Spots[index]
	if spot == nil then
		return nil
	end
	const record = spot.Record()
	if record == false then
		return nil
	end
	return record
end

function SeatingController:SpotOf(index: number): Spot
	const existing = self.Spots[index]
	if existing ~= nil then
		return existing
	end
	const spot: Spot = {
		Index = index,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Model = nil,
		Saved = nil,
		Top = nil,
		TrayAt = nil,
		Tray = nil,
		TrayTip = 0,
		Unmount = nil,
		Gui = nil,
	}
	self.Spots[index] = spot
	return spot
end

-- Client folder for the trays (never inside the server's table models).
function SeatingController:FolderOf(): Folder
	local folder = self.Folder
	if folder == nil or folder.Parent == nil then
		const created = Instance.new("Folder")
		created.Name = "Seating_Client"
		created.Parent = workspace
		folder = created
		self.Folder = created
	end
	return folder :: Folder
end

function SeatingController:Cue(key: string, at: Instance)
	if Content.Sounds.ByKey[key] then
		self.Dependencies.AudioController:Play(key, at)
	end
end

-- Records ---------------------------------------------------------------------------------------------------------

-- Copies: the set may reuse its record table, and Vide needs a new value to notice a change.
function SeatingController:WriteRecord(index: number, record: Record?)
	const spot = self:SpotOf(index)
	const old = Vide.untrack(spot.Record)
	if record == nil then
		spot.Record(false)
		self:Apply(spot)
		return
	end
	const copy: Record = {
		State = record.State,
		Price = record.Price,
		Npc1 = record.Npc1,
		Npc2 = record.Npc2,
		Tip = record.Tip,
	}
	spot.Record(copy)
	self:Apply(spot)
	if old == false then
		return -- first sight (late join, run start): no celebration
	end
	if old.State == "Ghost" and copy.State ~= "Ghost" and copy.State ~= "Locked" then
		self:Bought(spot)
	elseif old.State == "Dirty" and copy.State == "Free" and old.Tip > 0 then
		const tip = old.Tip
		-- the Summary reset writes the same thing; the phase of the same flush is read one defer later
		task.defer(function()
			if OPEN_PHASES[Vide.untrack(self.Dependencies.RoundController.Phase)] then
				self:Cleaned(spot, tip)
			end
		end)
	end
end

-- Binding ---------------------------------------------------------------------------------------------------------

local function topOf(model: Model): (Vector3, CFrame)
	const frame, size = model:GetBoundingBox()
	const top = frame.Position + Vector3.new(0, size.Y / 2, 0)
	-- yaw of the table, Y up
	const look = frame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return top, CFrame.lookAt(top, top + flat.Unit)
end

-- Tray frame: Tray_Anchor of the table (Attachment or Part, Y up), else the centre of the table top.
local function trayFrame(model: Model, fallback: CFrame): CFrame
	const anchor = model:FindFirstChild(BINDING.TrayAnchor, true)
	if anchor ~= nil and anchor:IsA("Attachment") then
		return anchor.WorldCFrame
	elseif anchor ~= nil and anchor:IsA("BasePart") then
		return anchor.CFrame
	end
	return fallback
end

function SeatingController:Bind(spot: Spot, model: Model)
	if spot.Model == model then
		return
	end
	self:Unbind(spot)
	spot.Model = model
	spot.Saved = Look.Capture(model)
	const top, frame = topOf(model)
	spot.TrayAt = trayFrame(model, frame)
	const attachment = Instance.new("Attachment")
	attachment.Name = `Seating_Top_{spot.Index}`
	attachment.WorldPosition = top
	attachment.Parent = workspace.Terrain
	spot.Top = attachment
	self:MountSign(spot)
	self:Apply(spot)
end

-- Back to the authored look, tray, plate and anchor gone.
function SeatingController:Unbind(spot: Spot)
	if spot.Saved ~= nil then
		Look.Apply(spot.Saved, "Solid", 0)
	end
	self:ClearTray(spot)
	const unmount = spot.Unmount
	if unmount then
		spot.Unmount = nil
		unmount()
	end
	if spot.Gui then
		spot.Gui:Destroy()
		spot.Gui = nil
	end
	if spot.Top then
		spot.Top:Destroy()
		spot.Top = nil
	end
	spot.Model = nil
	spot.Saved = nil
	spot.TrayAt = nil
end

-- Re-reads the TableIndex of a tagged model.
function SeatingController:Rebind(model: Model)
	for _, spot in self.Spots do
		if spot.Model == model then
			self:Unbind(spot)
		end
	end
	const value = model:GetAttribute(BINDING.IndexAttribute)
	if not CollectionService:HasTag(model, BINDING.Tag) or not model:IsDescendantOf(workspace) then
		return
	end
	if typeof(value) ~= "number" or value < 1 or value > SEATING.Tables or value % 1 ~= 0 then
		return
	end
	const spot = self:SpotOf(value)
	if spot.Model == nil then
		self:Bind(spot, model)
	end
end

function SeatingController:Track(instance: Instance)
	if not instance:IsA("Model") or self.Tracked[instance] ~= nil then
		return
	end
	const model = instance
	self.Tracked[model] = {
		model:GetAttributeChangedSignal(BINDING.IndexAttribute):Connect(function()
			self:Rebind(model)
		end),
		model.Destroying:Connect(function()
			self:Untrack(model)
		end),
	}
	self:Rebind(model)
end

function SeatingController:Untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const connections = self.Tracked[instance]
	if connections == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, spot in self.Spots do
		if spot.Model == instance then
			self:Unbind(spot)
		end
	end
end

-- Presentation ----------------------------------------------------------------------------------------------------

function SeatingController:Apply(spot: Spot)
	const saved = spot.Saved
	if saved == nil then
		return
	end
	const record = Vide.untrack(spot.Record)
	if record == false then
		Look.Apply(saved, "Solid", 0) -- no record (lobby, before the first replication): as authored
		self:ClearTray(spot)
		return
	end
	const mode: Look.Mode = if record.State == "Locked"
		then "Hidden"
		elseif record.State == "Ghost" then "Ghost"
		else "Solid"
	Look.Apply(saved, mode, SEATING.GhostTransparency)
	if record.State == "Dirty" then
		self:ShowTray(spot, record.Tip)
	else
		self:ClearTray(spot)
	end
end

function SeatingController:ShowTray(spot: Spot, tip: number)
	const at = spot.TrayAt
	if at == nil or (spot.Tray ~= nil and spot.Tray.Parent ~= nil and spot.TrayTip == tip) then
		return
	end
	self:ClearTray(spot)
	const tray = Tray.Build(at, tip, SEATING.TableTip)
	tray.Name = `Seating_Tray_{spot.Index}`
	tray.Parent = self:FolderOf()
	spot.Tray = tray
	spot.TrayTip = tip
end

function SeatingController:ClearTray(spot: Spot)
	if spot.Tray ~= nil then
		spot.Tray:Destroy()
		spot.Tray = nil
	end
	spot.TrayTip = 0
end

function SeatingController:CanPay(price: number): boolean
	return not self.CashReady() or self.Cash() >= price
end

-- Price plate of the table (mounted once per bound table; shown only on the next one for sale).
function SeatingController:MountSign(spot: Spot)
	const gui = self.Gui
	const top = spot.Top
	if gui == nil or top == nil or spot.Unmount ~= nil then
		return
	end
	const unmount, billboard = Vide.root(function()
		local function price(): number
			const record = spot.Record()
			return if record ~= false and record.State == "Ghost" then record.Price else 0
		end
		return TableSign({
			Name = `TableSign_{spot.Index}`,
			Adornee = top,
			Visible = function()
				return price() > 0
			end,
			Mode = function(): TableSign.Mode
				return if self:CanPay(price()) then "Buy" else "NoCash"
			end,
			Title = function()
				return SIGN_TITLE
			end,
			Price = function()
				return `${price()}`
			end,
			Offset = Vector3.new(0, SIGN_LIFT, 0),
			MaxDistance = SIGN_DISTANCE,
		})
	end)
	billboard.Parent = gui
	spot.Unmount = unmount
	spot.Gui = billboard
end

-- Ghost -> bought: confetti + SFX-065 on the table.
function SeatingController:Bought(spot: Spot)
	const top = spot.Top
	if top == nil then
		return
	end
	Fx.Burst(top.WorldPosition, "Confetti", CONFETTI)
	self:Cue("upgrade_done", top)
end

-- Clean Table done: "+$N" rising over the table, coin burst and sound.
function SeatingController:Cleaned(spot: Spot, tip: number)
	const top = spot.Top
	const gui = self.Gui
	if top == nil or gui == nil then
		return
	end
	Fx.Burst(top.WorldPosition, "Tip", TIP_COINS)
	self:Cue("coin", top)
	local billboard: BillboardGui? = nil
	local unmount: (() -> ())? = nil
	local function finish()
		task.defer(function()
			if unmount then
				unmount()
				unmount = nil
			end
			if billboard then
				billboard:Destroy()
				billboard = nil
			end
		end)
	end
	unmount, billboard = Vide.root(function()
		return Vide.create("BillboardGui")({
			Name = `TablePop_{spot.Index}`,
			Adornee = top,
			Size = UDim2.fromOffset(POP_WIDTH, POP_HEIGHT),
			SizeOffset = Vector2.new(0, 0.5),
			StudsOffsetWorldSpace = Vector3.new(0, POP_LIFT, 0),
			AlwaysOnTop = true,
			MaxDistance = POP_DISTANCE,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Pop.Render({ Amount = tip }, { Bottom = POP_HEIGHT, OnDone = finish }),
		})
	end)
	if billboard then
		billboard.Parent = gui
	end
end

function SeatingController:Watch(gui: Instance)
	self.Gui = gui
	CollectionService:GetInstanceAddedSignal(BINDING.Tag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BINDING.Tag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(BINDING.Tag) do
		self:Track(instance)
	end
	-- signs of tables bound before the gui existed
	for _, spot in self.Spots do
		self:MountSign(spot)
	end

	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance)
		self.Meal:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance)
		self.Meal:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self.Meal:Track(instance)
	end
end

SeatingController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net
	net.Tables:onAdded(function(index, record)
		self:WriteRecord(index, record)
	end)
	net.Tables:onChanged(function(index, record)
		self:WriteRecord(index, record)
	end)
	net.Tables:onRemoved(function(index)
		self:WriteRecord(index, nil)
	end)

	const applyCash = function(id: number, record: { Cash: number, Drawer: number })
		if id == ECONOMY_ID then
			Vide.batch(function()
				self.Cash(record.Cash)
				self.CashReady(true)
			end)
		end
	end
	net.Economy:onAdded(applyCash)
	net.Economy:onChanged(applyCash)
	net.Economy:onRemoved(function(id)
		if id == ECONOMY_ID then
			self.CashReady(false)
		end
	end)
end)

SeatingController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return SeatingController
