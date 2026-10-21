--!strict
--[[
	EconomyController (TASK-024, FEAT-012; DEC-050, DEC-155; network.md §3.3 and §4.3)

	Reads the `Economy` set (record 1) into the Vide sources `Cash` (party money, the HUD reads it, TASK-039) and
	`Drawer` (since 2026-10-13: the TIPS in the tip jar; a sale goes straight to Cash). Draws the jar value in the world
	over every `Vehicle`, fills the jar model with bills and coins (TipJar.luau) and pops "+$N" over it when a tip
	arrives (Drawer rises). Everyone reads the same record, so everyone sees the same number (FEAT-012).

	Where the value goes (architecture.md §18.3/§18.4): the `Value_Anchor` fitting searched inside the `Vehicle`
	(Attachment or BasePart). TASK-005 creates it on top of the POS, so the old register and the new black POS
	(DEC-155) both work. Without it: warn once and fall back to the top part of the `DRAWER` model (MapId); without
	that either (TRL-TIPJAR / legacy ids), warn and draw nothing. A late `Value_Anchor` (streaming, model swap) replaces the fallback.

	Only the vehicle in use shows the drawer (TASK-058, closes the TASK-024 Provisional): a `Vehicle` whose attribute
	`Vehicle` differs from RoundController.Vehicle (Shift.Vehicle) draws nothing, so the trailer for sale (wave 2) and
	the parked cart under the tarp after the swap never show a value. The swap redraws from the Shift record.

	The client never writes money: a sale only changes the number when the server's `Economy` record changes. The
	"+$N" is presentation of the `Sale` packet, not a prediction of the drawer.

	Sound and VFX (TASK-079; sound-list §5.4; AST-092, AST-082): a Sale with Amount > 0 plays SFX-043 `coin` at the
	customer (the counter), hops 4 coins there (placeholder particles, Fx.luau budget) and flies "+$N" plus a few coins
	from there straight to the HUD money pill: the sale never passes through the jar. A tip (Drawer rises) plays SFX-044
	`tip` and a brighter coin on the jar and pops the pieces in. "Collect Tips" (CashCollected) sends every piece of the
	heap to the pill. Keys still missing from Content.Sounds are skipped quietly.
]]
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Content = require(ReplicatedStorage.shared.Content)
local DrawerValue = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local TipJar = require(script.TipJar)

const RECORD_ID = 1 -- single record (network.md §1, rule 5)
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle" -- key of Content.Vehicles on the tagged Model (architecture.md §18.1, T36)
const ANCHOR_NAME = "Value_Anchor"
-- Height of the value over the anchor (studs, world up)
const ANCHOR_OFFSET = 0.6
-- Grace for the anchor to stream in before falling back to the DRAWER model
const FALLBACK_DELAY = 5
-- Sales are <= 1/s (network.md §4.3); more than this on screen at once only stacks unreadable text
const MAX_POPS = 4
const COINS = 4 -- AST-092 payment Emit(4)
const TIP_COINS = 1 -- AST-092 tip Emit(1)
const TIP_SPEED = 1.2 -- tip with no `tip` row yet: the coin again, higher (Provisional)
const CUSTOMER_TAG = "AnimalRig" -- customer rigs carry the NpcId attribute
const COUNTER_LIFT = 1.5 -- studs above the customer's root: where the sale money starts
const SALE_COINS = 3 -- 2D coins that follow a sale's "+$N" to the pill
-- "Collect Cash" (Q-201): "+$N" leaves the register and flies to the money pill of the HUD. TASK-597 (owner Play
-- 2026-10-19: the money flew to the top LEFT): the target is the real "Cash" pill of the Hud ScreenGui (top right since
-- 2026-10-12), read every flight; HUD_PILL is only the fallback while the pill is not on screen
const FLY_TIME = 0.8 -- s
const FLY_COINS = 8 -- coins of the burst at the register
const BILL_COLOR = Color3.fromHex("#6FB26B") -- note green (same as the 3D bills)
const HUD_PILL = Vector2.new(10 + 56, 6 + 19) -- px at scale 1 from the top RIGHT corner: fallback target
const HUD_GUI = "Hud" -- HudController's ScreenGui
const PILL_NAME = "Cash" -- HudScreen's money pill
-- TASK-597: the money shown on the HUD (Shown) catches up with Cash when the first pieces land, so the pill pops, turns
-- green and rolls up in sync with the coins (HudScreen). A drop shows at once.
const LAND_TIME = FLY_TIME + 0.1 -- s after a Cash increase

type Mount = {
	Vehicle: Instance,
	Adornee: Instance?,
	Gui: Instance?,
	Unmount: (() -> ())?,
	Connections: { RBXScriptConnection },
	Fallback: thread?,
	Warned: boolean,
	Jar: TipJar.TipJar?,
}

export type Record = {
	Cash: number,
	Drawer: number,
}

const EconomyController =
	Modux.Controller("EconomyController", { Require = { "RoundController", "AudioController" }, Priority = 790 })

function EconomyController:Setup()
	self.Cash = Vide.source(0) :: Vide.Source<number>
	-- money the HUD shows (TASK-597): follows Cash, an increase lands LAND_TIME s later with the flying coins
	self.Shown = Vide.source(0) :: Vide.Source<number>
	self.LandSerial = 0 :: number
	self.Drawer = Vide.source(0) :: Vide.Source<number>
	-- true once the first Economy record arrived
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Pops = Vide.source({} :: { DrawerValue.Pop }) :: Vide.Source<{ DrawerValue.Pop }>
	self.Mounts = {} :: { [Instance]: Mount }
	self.Gui = nil :: Instance?
	self.FlyGui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?
	self.JarConfig = TipJar.Config() :: TipJar.Config
end

-- True when this tagged Model is the vehicle in use (Shift.Vehicle)
function EconomyController:IsCurrent(vehicle: Instance): boolean
	return vehicle:GetAttribute(VEHICLE_ATTRIBUTE) == self.Dependencies.RoundController.Vehicle()
end

function EconomyController:Apply(record: Record)
	if self.Cash() ~= record.Cash then
		self.Cash(record.Cash)
		self:Land(record.Cash, self.Ready())
	end
	const before = self.Drawer()
	const ready = self.Ready()
	if before ~= record.Drawer then
		self.Drawer(record.Drawer)
		for _, mount in self.Mounts do
			const jar = mount.Jar
			if jar then
				TipJar.Set(jar, record.Drawer)
			end
		end
		-- a tip arrived (the jar rose): "+$N" over the jar and the tip sound; theft, collect and the shift reset only go down
		if ready and record.Drawer > before then
			self:Tipped(record.Drawer - before)
		end
	end
	if not ready then
		self.Ready(true)
	end
end

-- HUD money (Shown): a drop or the first record shows at once; a rise waits for the coins (LAND_TIME), the newest wins
function EconomyController:Land(cash: number, ready: boolean)
	self.LandSerial += 1
	if not ready or cash < Vide.untrack(self.Shown) then
		self.Shown(cash)
		return
	end
	const serial = self.LandSerial
	task.delay(LAND_TIME, function()
		if serial == self.LandSerial then
			self.Shown(Vide.untrack(self.Cash))
		end
	end)
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

-- A tip fell into the jar (presentation only: the jar already holds it, the number came with the Economy record)
function EconomyController:Tipped(amount: number)
	const anchor = self:DrawerAnchor()
	if anchor == nil then
		return
	end
	self:Pop(amount)
	const audio = self.Dependencies.AudioController
	const position = positionOf(anchor)
	if Content.Sounds.ByKey.tip then
		audio:Play("tip", anchor)
	elseif Content.Sounds.ByKey.coin then
		audio:Play("coin", anchor, { Speed = TIP_SPEED })
	end
	if position then
		Fx.Burst(position, "Tip", TIP_COINS)
	end
end

-- Where the sale happens: the customer rig (they pay at the counter), else the jar, else nil (screen centre)
function EconomyController:SalePosition(npc: number): Vector3?
	for _, instance in CollectionService:GetTagged(CUSTOMER_TAG) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			const root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
			if root then
				return root.Position + Vector3.new(0, COUNTER_LIFT, 0)
			end
		end
	end
	const anchor = self:DrawerAnchor()
	return if anchor then positionOf(anchor) else nil
end

-- Sale feedback at the counter: coin sound, coins, and "+$N" flying straight to the HUD money pill. A tip, if any,
-- arrives separately through the jar (Economy.Drawer). Presentation only.
function EconomyController:Chime(amount: number, npc: number)
	if amount <= 0 then
		return
	end
	const position = self:SalePosition(npc)
	const audio = self.Dependencies.AudioController
	if Content.Sounds.ByKey.coin then
		audio:Play("coin", position)
	end
	if position then
		Fx.Burst(position, "Coins", COINS)
	end
	self:Fly(amount, position)
	for index = 1, SALE_COINS do
		self:FlyPiece(position, true, 0.05 + index * 0.06)
	end
end

-- "Collect Tips" feedback (presentation only: Cash already changed with the Economy record): every piece of the heap
-- leaves the jar and flies to the money pill, with the coin sound and a "+$N".
function EconomyController:Collected(amount: number)
	const anchor = self:DrawerAnchor()
	const position = if anchor then positionOf(anchor) else nil
	local flown = 0
	for _, mount in self.Mounts do
		const jar = mount.Jar
		if jar then
			flown += TipJar.Collect(jar, function(at, coin, delay)
				self:FlyPiece(at, coin, delay)
			end)
		end
	end
	if anchor ~= nil then
		const audio = self.Dependencies.AudioController
		if Content.Sounds.ByKey.coin then
			audio:Play("coin", anchor)
			task.delay(0.12, function()
				audio:Play("coin", anchor, { Speed = 1.15 })
			end)
		end
	end
	if position ~= nil then
		Fx.Burst(position, "Coins", FLY_COINS)
	end
	if flown == 0 then
		-- no heap drawn (legacy model): a few coins stand in for it
		for index = 1, FLY_COINS do
			self:FlyPiece(position, index % 3 == 0, (index - 1) * 0.04)
		end
	end
	self:Fly(amount, position)
end

-- ScreenGui of the flights (created on first use)
function EconomyController:FlyScreen(): ScreenGui?
	const parent = self.Gui
	if parent == nil then
		return nil
	end
	local screen = self.FlyGui :: ScreenGui?
	if screen == nil or screen.Parent == nil then
		const created = Instance.new("ScreenGui")
		created.Name = "CashFly"
		created.ResetOnSpawn = false
		created.IgnoreGuiInset = true
		created.ScreenInsets = Enum.ScreenInsets.None
		created.DisplayOrder = 40
		created.Parent = parent
		self.FlyGui = created
		screen = created
	end
	return screen
end

-- Centre of the HUD money pill in the flight ScreenGui's space (IgnoreGuiInset): the Hud ScreenGui keeps the inset, so
-- its AbsolutePosition is under the top bar. Fallback HUD_PILL (scaled, top right) while the pill is hidden or not built.
function EconomyController:PillTarget(scale: number, viewport: Vector2): Vector2
	const playerGui = self.Gui
	const hud = if playerGui then playerGui:FindFirstChild(HUD_GUI) else nil
	if hud and hud:IsA("ScreenGui") then
		for _, item in hud:GetDescendants() do
			if item.Name == PILL_NAME and item:IsA("GuiObject") and item.Visible and item.AbsoluteSize.X > 0 then
				const inset = if hud.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
				return item.AbsolutePosition + item.AbsoluteSize / 2 + inset
			end
		end
	end
	return Vector2.new(viewport.X - HUD_PILL.X * scale, HUD_PILL.Y * scale)
end

-- One small bill or coin (2D) from a world position to the money pill of the HUD
function EconomyController:FlyPiece(position: Vector3?, coin: boolean, delay: number)
	const camera = workspace.CurrentCamera
	const screen = self:FlyScreen()
	if camera == nil or screen == nil then
		return
	end
	const viewport = camera.ViewportSize
	local start = viewport / 2
	if position ~= nil then
		const point, onScreen = camera:WorldToViewportPoint(position)
		if onScreen then
			start = Vector2.new(point.X, point.Y)
		end
	end
	const scale = Theme.ScaleOf(viewport)
	const piece = Instance.new("Frame")
	piece.Name = "FlyPiece"
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromOffset(start.X, start.Y)
	piece.Size = if coin then UDim2.fromOffset(16 * scale, 16 * scale) else UDim2.fromOffset(24 * scale, 13 * scale)
	piece.BackgroundColor3 = if coin then Theme.Color.Mustard else BILL_COLOR
	piece.BorderSizePixel = 0
	piece.Visible = false
	piece.ZIndex = 4
	const corner = Instance.new("UICorner")
	corner.CornerRadius = if coin then UDim.new(0.5, 0) else UDim.new(0, 3)
	corner.Parent = piece
	const stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.Color.Ink
	stroke.Parent = piece
	piece.Parent = screen
	task.delay(delay, function()
		if piece.Parent == nil then
			return
		end
		piece.Visible = true
		const target = self:PillTarget(scale, viewport)
		const tween = TweenService:Create(
			piece,
			TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(target.X, target.Y), BackgroundTransparency = 0.3, Size = UDim2.fromOffset(8 * scale, 8 * scale) }
		)
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		tween:Play()
	end)
end

function EconomyController:Fly(amount: number, position: Vector3?)
	const camera = workspace.CurrentCamera
	const screen = self:FlyScreen()
	if camera == nil or screen == nil then
		return
	end
	const viewport = camera.ViewportSize
	local start = viewport / 2
	if position ~= nil then
		const point, onScreen = camera:WorldToViewportPoint(position)
		if onScreen then
			start = Vector2.new(point.X, point.Y)
		end
	end
	const scale = Theme.ScaleOf(viewport)
	const label = Instance.new("TextLabel")
	label.Name = "Fly"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(start.X, start.Y)
	label.Size = UDim2.fromOffset(120 * scale, 36 * scale)
	label.BackgroundTransparency = 1
	label.Text = `+${amount}`
	label.FontFace = Theme.Font.Title
	label.TextSize = math.round(24 * scale)
	label.TextColor3 = Theme.Color.Mustard
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Theme.Color.Ink
	label.ZIndex = 5
	label.Parent = screen
	const target = self:PillTarget(scale, viewport)
	const tween = TweenService:Create(
		label,
		TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromOffset(target.X, target.Y), TextTransparency = 0.35, TextSize = math.round(16 * scale) }
	)
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
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

-- Highest BasePart of the jar model (TRL-TIPJAR or legacy DRAWER) inside the vehicle, and the offset that puts the value on its top
local function findFallback(vehicle: Instance, config: TipJar.Config): (BasePart?, number)
	local drawer: Instance? = nil
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") and TipJar.IsJarId(descendant:GetAttribute("MapId"), config) then
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

-- Builds / drops the heap of the jar for this vehicle (only the vehicle in use shows one)
function EconomyController:ResolveJar(mount: Mount)
	const current = mount.Jar
	if not self:IsCurrent(mount.Vehicle) then
		if current then
			mount.Jar = nil
			TipJar.Destroy(current)
		end
		return
	end
	const model = TipJar.FindModel(mount.Vehicle, self.JarConfig)
	if current and current.Model == model and current.Volume.Parent ~= nil then
		return
	end
	if current then
		mount.Jar = nil
		TipJar.Destroy(current)
	end
	if model == nil then
		return
	end
	const volume = model:FindFirstChild(TipJar.FillName, true)
	if volume == nil or not volume:IsA("BasePart") then
		return
	end
	const jar = TipJar.new(model, volume, self.JarConfig)
	mount.Jar = jar
	TipJar.Set(jar, self.Drawer())
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
	self:ResolveJar(mount)
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
	const part, offset = findFallback(mount.Vehicle, self.JarConfig)
	if not mount.Warned then
		mount.Warned = true
		warn(
			("[EconomyController] %s has no %s (TASK-005 creates it on top of the POS); %s"):format(
				mount.Vehicle:GetFullName(),
				ANCHOR_NAME,
				if part then "using the top of the tip jar model" else "drawer value not shown"
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
		Jar = nil,
	}
	self.Mounts[vehicle] = mount

	table.insert(
		mount.Connections,
		vehicle.DescendantAdded:Connect(function(descendant)
			if descendant.Name == ANCHOR_NAME and mount.Adornee ~= descendant then
				self:Resolve(mount)
			elseif
				descendant.Name == TipJar.FillName
				or (descendant:IsA("Model") and TipJar.IsJarId(descendant:GetAttribute("MapId"), self.JarConfig))
			then
				-- the jar (or its fill volume) streamed in
				task.defer(function()
					if self.Mounts[vehicle] == mount then
						self:ResolveJar(mount)
					end
				end)
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
	const jar = mount.Jar
	if jar then
		mount.Jar = nil
		TipJar.Destroy(jar)
	end
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

	-- "Collect Tips": the jar went to Cash (Economy already says so); the heap flying to the HUD is presentation
	self.Libs.Net.CashCollected:onClient(function(collected)
		self:Collected(collected.Amount)
	end)

	-- Presentation only: the jar number itself comes from Economy. Wrong/Left/Refused carry Amount 0.
	self.Libs.Net.Sale:onClient(function(sale)
		if sale.Amount > 0 then
			self:Chime(sale.Amount, sale.Npc)
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
