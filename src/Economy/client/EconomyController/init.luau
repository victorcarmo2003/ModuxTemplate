--!strict
--[[
	EconomyController (TASK-024, FEAT-012; DEC-050, DEC-155; network.md §3.3 and §4.3)

	Reads the `Economy` set (record 1) into the Vide source `Cash` (party money, the HUD reads it, TASK-039) and `Shown` (the
	money the HUD pill shows: it lands with the flying coins, TASK-597). Everyone reads the same record, so everyone sees the
	same number (FEAT-012). The set field `Drawer` is always 0 since the tip jar left (owner 2026-10-22, Provisional): tips go
	straight to Cash with the sale, so there is no jar to fill, no "$N" over the trailer and no "Collect Tips" any more.

	The client never writes money: a sale only changes the number when the server's `Economy` record changes. The "+$N" is
	presentation of the `Sale` packet (its Amount already holds the customer's tip), not a prediction.

	Sound and VFX (TASK-079; sound-list §5.4; AST-092): a Sale with Amount > 0 plays SFX-043 `coin` at the customer (the
	counter), hops 4 coins there (placeholder particles, Fx.luau budget) and flies "+$N" plus a few coins from there straight
	to the HUD money pill. Keys still missing from Content.Sounds are skipped quietly.
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
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
-- shared VFX budget (AST-092 ceiling counts the whole screen)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)

const RECORD_ID = 1 -- single record (network.md §1, rule 5)
const COINS = 4 -- AST-092 payment Emit(4)
const CUSTOMER_TAG = "AnimalRig" -- customer rigs carry the NpcId attribute
const COUNTER_LIFT = 1.5 -- studs above the customer's root: where the sale money starts
const SALE_COINS = 3 -- 2D coins that follow a sale's "+$N" to the pill
-- TASK-597 (owner Play 2026-10-19: the money flew to the top LEFT): the target is the real "Cash" pill of the Hud ScreenGui
-- (top right since 2026-10-12), read every flight; HUD_PILL is only the fallback while the pill is not on screen
const FLY_TIME = 0.8 -- s
const HUD_PILL = Vector2.new(10 + 56, 6 + 19) -- px at scale 1 from the top RIGHT corner: fallback target
const HUD_GUI = "Hud" -- HudController's ScreenGui
const PILL_NAME = "Cash" -- HudScreen's money pill
-- TASK-597: the money shown on the HUD (Shown) catches up with Cash when the first pieces land, so the pill pops, turns
-- green and rolls up in sync with the coins (HudScreen). A drop shows at once.
const LAND_TIME = FLY_TIME + 0.1 -- s after a Cash increase

export type Record = {
	Cash: number,
	Drawer: number,
}

const EconomyController = Modux.Controller("EconomyController", { Require = { "AudioController" }, Priority = 790 })

function EconomyController:Setup()
	self.Cash = Vide.source(0) :: Vide.Source<number>
	-- money the HUD shows (TASK-597): follows Cash, an increase lands LAND_TIME s later with the flying coins
	self.Shown = Vide.source(0) :: Vide.Source<number>
	self.LandSerial = 0 :: number
	-- true once the first Economy record arrived
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Gui = nil :: Instance?
	self.FlyGui = nil :: ScreenGui?
end

function EconomyController:Apply(record: Record)
	if self.Cash() ~= record.Cash then
		self.Cash(record.Cash)
		self:Land(record.Cash, self.Ready())
	end
	if not self.Ready() then
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

-- Where the sale happens: the customer rig (they pay at the counter), else nil (screen centre)
function EconomyController:SalePosition(npc: number): Vector3?
	for _, instance in CollectionService:GetTagged(CUSTOMER_TAG) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			const root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
			if root then
				return root.Position + Vector3.new(0, COUNTER_LIFT, 0)
			end
		end
	end
	return nil
end

-- Sale feedback at the counter: coin sound, coins, and "+$N" (price + tip) flying straight to the HUD money pill.
-- Presentation only.
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

-- One small coin (2D) from a world position to the money pill of the HUD
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
	piece.BackgroundColor3 = Theme.Color.Mustard
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

	-- Presentation only: the money itself comes from Economy. Wrong/Left/Refused carry Amount 0.
	self.Libs.Net.Sale:onClient(function(sale)
		if sale.Amount > 0 then
			self:Chime(sale.Amount, sale.Npc)
		end
	end)
end)

EconomyController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self.Gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	end)
end)

return EconomyController
