--!strict
--[[
	SupplyController (FEAT-050 client; design/restaurant-flow.md; TASK-389, minimum version without a menu packet)

	Presents the restaurant restock by boxes. Decides nothing: it reads the Supply and Hatch sets of Net.Restaurant, the
	Stock set and the Boxes attribute the SupplyService writes on each StockShelf bay; the order, the money and the boxes
	are the server's. Inert (no listener, no GUI, no part) unless Content.Restaurant.Supply.Enabled AND
	Content.Restaurant.Rules.Enabled (both false by default, the same gate as the SupplyService).

	  Phone (PHONE-R, anchor Binding.PhonePrompt, action order_stock): while the prompt is the PromptController target
	    (aimed or held) a card under the clock (Interface/Components/StockMenu) shows the quick order the hold will place:
	    the boxes per package, their cost ("$22", red when EconomyController.Cash cannot pay it) and the hold hint of the
	    device. PREDICTION ONLY: same rule as the server's Order.quick (MaxBoxes boxes over the packages on sale, lowest
	    stock first; stock = boxes on the bays + at the hatch as this client sees them, the boxes still outside are not on
	    the wire) and Order.cost (Package prices + Supply.Fee). The server places its own order.
	    While a call is on the way (Supply record 1, State OnTheWay) the card reads "On the way 0:45", counted down from
	    EndsAt (server time).
	  HUD chip (StockMenu.Chip, under the clock, when the card is not up): "On the way 0:45" while a call is on the way;
	    otherwise "Low on <Package>" with the package icon pulsing while any product is low.
	  Low stock: a Stock record (ingredient with a package, not Blocked, not Wrapped, Capacity > 0) at or under
	    Supply.LowAt of its Capacity. Crossing into low (from a record seen above it) pushes the stock_low toast once
	    ("Low on Buns": Content.Notices text with the Package name) through HudController; it re-arms above LowAt.
	  Bays (tag StockShelf): a big "xN" pill (StockMenu.Tag) over the bay's Sign part (else its anchor / first part), from
	    the Boxes attribute; hidden until the server wrote it. Ketchup at x0.
	  Hatch (Hatch set, record = spot 1..Supply.HatchSpots): one local cardboard box per record on the DROP-R spots
	    (Attachments / parts with a number attribute Binding.HatchSpot, else named HatchSpot<n>), with a small name tag.
	    More records than authored spots stack on top. Local parts (CanCollide / CanQuery off): the take_box prompt is
	    the server's anchor, these are only the picture.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local StockMenu = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.StockMenu)

const TICK_RATE = 10
const SHELF_TAG = "StockShelf"
const SHELF_BOXES = "Boxes"
const SHELF_PACKAGE = "Package"
const SIGN_NAME = "Sign"
const SHELF_ANCHOR = "Prompt_TakeBox"
const SPOT_PREFIX = "HatchSpot"
const SUPPLY_RECORD = 1
-- HUD: under the clock pill (HudScreen TOP 6 + 32 + gap 8), px at UI scale 1
const UNDER_CLOCK = 46
-- world tags
const SHELF_TAG_SIZE = Vector2.new(1.7, 1.0)
const SHELF_TAG_RISE = 0.7 -- studs over the top of the sign
const SHELF_MAX_DISTANCE = 26
const BOX_TAG_SIZE = Vector2.new(1.6, 0.55)
const BOX_MAX_DISTANCE = 18
-- local hatch box (cardboard, about a Mart package)
const BOX_SIZE = Vector3.new(1.3, 1.0, 1.0)
const BOX_COLOR = Color3.fromRGB(184, 126, 82)
const BOX_DROP = 3 -- studs searched under a spot for the shelf top

const HINT: { [string]: string } = {
	KeyboardMouse = "Hold E to call",
	Gamepad = "Hold X to call",
	Touch = "Hold to call",
}

export type SupplyRecord = { State: string, EndsAt: number, Boxes: number }
export type HatchRecord = { Package: string, Amount: number }
export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean, Wrapped: boolean? }

type Bay = { Root: Instance, Destroy: () -> (), Gui: BillboardGui, Connections: { RBXScriptConnection } }
type HatchBox = { Part: BasePart, Destroy: () -> (), Gui: BillboardGui }

const IDLE: SupplyRecord = { State = "Idle", EndsAt = 0, Boxes = 0 }

-- Packages key by ingredient key (first package of each ingredient)
const PACKAGE_OF: { [string]: any } = {}
for _, row in Content.Packages.List do
	if PACKAGE_OF[row.Ingredient] == nil then
		PACKAGE_OF[row.Ingredient] = row
	end
end

-- Ingredient key by Stock record id (Content.Ingredients.IndexOf)
const INGREDIENT_AT: { [number]: string } = {}
for key, index in Content.Ingredients.IndexOf do
	INGREDIENT_AT[index] = key
end

const SupplyController = Modux.Controller("SupplyController", {
	Require = { "PromptController", "HudController", "EconomyController", "InputController" },
	Priority = 280,
})

function SupplyController:Setup()
	self.Live = (Content.Restaurant.Supply.Enabled and Content.Restaurant.Rules.Enabled) :: boolean
	self.Supply = Vide.source(IDLE) :: Vide.Source<SupplyRecord>
	self.Now = Vide.source(workspace:GetServerTimeNow()) :: Vide.Source<number>
	self.Hatch = {} :: { [number]: HatchRecord }
	self.Stock = {} :: { [string]: StockRecord }
	-- ingredient keys under LowAt now, and the ones already toasted this drop
	self.LowKeys = Vide.source({}) :: Vide.Source<{ string }>
	self.Toasted = {} :: { [string]: boolean }
	self.PhoneOpen = Vide.source(false) :: Vide.Source<boolean>
	self.Lines = Vide.source({}) :: Vide.Source<{ StockMenu.Line }>
	self.Cost = Vide.source(0) :: Vide.Source<number>
	self.Bays = {} :: { [Instance]: Bay }
	self.Boxes = {} :: { [number]: HatchBox }
	self.Spots = {} :: { Instance }
	self.Folder = nil :: Folder?
	self.Gui = nil :: ScreenGui?
end

-- Reads -----------------------------------------------------------------------------------------------------------------

-- Seconds until the call on the way lands (0 = none)
function SupplyController:SecondsLeft(): number
	const record = self.Supply()
	if record.State ~= "OnTheWay" or record.EndsAt <= 0 then
		return 0
	end
	return math.max(0, math.ceil(record.EndsAt - self.Now()))
end

-- Packages on sale now (Stock record of its ingredient seen and not Blocked), in list order
function SupplyController:OpenPackages(): { string }
	const out: { string } = {}
	for _, row in Content.Packages.List do
		const stock = self.Stock[row.Ingredient]
		if stock ~= nil and not stock.Blocked then
			table.insert(out, row.Key)
		end
	end
	return out
end

-- Boxes this client sees waiting, by package: bay Boxes attributes + hatch records
function SupplyController:BoxesWaiting(): { [string]: number }
	const out: { [string]: number } = {}
	for root in self.Bays do
		const package = root:GetAttribute(SHELF_PACKAGE)
		const boxes = root:GetAttribute(SHELF_BOXES)
		if type(package) == "string" and type(boxes) == "number" then
			out[package] = (out[package] or 0) + boxes
		end
	end
	for _, record in self.Hatch do
		out[record.Package] = (out[record.Package] or 0) + 1
	end
	return out
end

-- Prediction of the server's quick order (Order.quick + Order.cost), for the card only
function SupplyController:Predict(): ({ StockMenu.Line }, number)
	const open = self:OpenPackages()
	const stock = self:BoxesWaiting()
	const picked: { [string]: number } = {}
	if #open > 0 then
		for _ = 1, Content.Restaurant.Supply.MaxBoxes do
			local best: string? = nil
			local bestCount = math.huge
			for _, key in open do
				const count = (stock[key] or 0) + (picked[key] or 0)
				if count < bestCount then
					best = key
					bestCount = count
				end
			end
			if best == nil then
				break
			end
			picked[best] = (picked[best] or 0) + 1
		end
	end
	const lines: { StockMenu.Line } = {}
	local cost = 0
	for _, row in Content.Packages.List do
		const count = picked[row.Key]
		if count ~= nil then
			table.insert(lines, { Package = row.Key, Name = row.Name, Count = count })
			cost += row.Price * count
		end
	end
	if #lines > 0 then
		cost += Content.Restaurant.Supply.Fee
	end
	return lines, cost
end

local function isLow(record: StockRecord): boolean
	return not record.Blocked
		and record.Wrapped ~= true
		and record.Capacity > 0
		and record.Amount / record.Capacity <= Content.Restaurant.Supply.LowAt
end

-- Writes ----------------------------------------------------------------------------------------------------------------

function SupplyController:WriteSupply(record: SupplyRecord?)
	self.Supply(record or IDLE)
end

function SupplyController:WriteStock(id: number, record: StockRecord?)
	const key = INGREDIENT_AT[id]
	if key == nil or PACKAGE_OF[key] == nil then
		return
	end
	const before = self.Stock[key]
	self.Stock[key] = record
	if record == nil or not isLow(record) then
		self.Toasted[key] = nil
	elseif before ~= nil and not isLow(before) and not self.Toasted[key] then
		-- one toast per drop under LowAt (a late joiner's first record, already low, is silent)
		self.Toasted[key] = true
		self:ToastLow(key)
	elseif before == nil then
		self.Toasted[key] = true
	end
	const low: { string } = {}
	for _, row in Content.Ingredients.List do
		const stock = self.Stock[row.Key]
		if stock ~= nil and PACKAGE_OF[row.Key] ~= nil and isLow(stock) then
			table.insert(low, row.Key)
		end
	end
	self.LowKeys(low)
	if Vide.untrack(self.PhoneOpen) then
		self:RefreshOrder()
	end
end

function SupplyController:ToastLow(ingredient: string)
	const package = PACKAGE_OF[ingredient]
	const notice = Content.Notices.ByKey.stock_low
	if package == nil or notice == nil then
		return
	end
	const name = string.gsub(package.Name, "%%", "%%%%")
	const text = string.gsub(notice.Text, "{item}", name)
	pcall(function()
		self.Dependencies.HudController:PushText(text, "Alert")
	end)
end

function SupplyController:WriteHatch(id: number, record: HatchRecord?)
	self.Hatch[id] = record
	self:DrawHatch()
	if Vide.untrack(self.PhoneOpen) then
		self:RefreshOrder()
	end
end

-- Bays ------------------------------------------------------------------------------------------------------------------

local function firstPart(root: Instance): BasePart?
	if root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") and root.PrimaryPart then
		return root.PrimaryPart
	end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

function SupplyController:UnmountBay(root: Instance)
	const bay = self.Bays[root]
	if bay == nil then
		return
	end
	self.Bays[root] = nil
	for _, connection in bay.Connections do
		connection:Disconnect()
	end
	bay.Destroy()
	bay.Gui:Destroy()
end

function SupplyController:MountBay(root: Instance)
	if self.Bays[root] ~= nil or not root:IsDescendantOf(workspace) then
		return
	end
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	const sign = root:FindFirstChild(SIGN_NAME, true)
	local adornee: Instance? = nil
	local rise = SHELF_TAG_RISE
	if sign ~= nil and sign:IsA("BasePart") then
		adornee = sign
		rise += sign.Size.Y / 2
	else
		adornee = root:FindFirstChild(SHELF_ANCHOR, true) or firstPart(root)
		rise += 2.5
	end
	if adornee == nil then
		return
	end
	-- Boxes attribute, -1 = not written by the server yet
	local function read(): number
		const value = root:GetAttribute(SHELF_BOXES)
		return if type(value) == "number" then value else -1
	end
	const boxes = Vide.source(read()) :: Vide.Source<number>
	const destroy, gui = Vide.root(function(): BillboardGui
		local function count(): number
			return math.max(boxes(), 0)
		end
		return StockMenu.Tag({
			Name = `StockShelf_{root.Name}`,
			Adornee = adornee,
			Visible = function()
				return boxes() >= 0
			end,
			Text = function()
				return `x{count()}`
			end,
			Empty = function()
				return count() <= 0
			end,
			Count = count,
			Size = SHELF_TAG_SIZE,
			StudsOffset = Vector3.new(0, rise, 0),
			MaxDistance = SHELF_MAX_DISTANCE,
		})
	end)
	gui.Parent = playerGui
	const bay: Bay = { Root = root, Destroy = destroy, Gui = gui, Connections = {} }
	self.Bays[root] = bay
	table.insert(
		bay.Connections,
		root:GetAttributeChangedSignal(SHELF_BOXES):Connect(function()
			boxes(read())
			if Vide.untrack(self.PhoneOpen) then
				self:RefreshOrder()
			end
		end)
	)
	table.insert(
		bay.Connections,
		root.AncestryChanged:Connect(function()
			if not root:IsDescendantOf(workspace) then
				self:UnmountBay(root)
			end
		end)
	)
end

function SupplyController:WatchBays()
	CollectionService:GetInstanceAddedSignal(SHELF_TAG):Connect(function(root)
		self:MountBay(root)
	end)
	CollectionService:GetInstanceRemovedSignal(SHELF_TAG):Connect(function(root)
		self:UnmountBay(root)
	end)
	for _, root in CollectionService:GetTagged(SHELF_TAG) do
		self:MountBay(root)
	end
end

-- Hatch -----------------------------------------------------------------------------------------------------------------

local function spotIndex(instance: Instance): number?
	if not (instance:IsA("Attachment") or instance:IsA("BasePart")) then
		return nil
	end
	const attribute = instance:GetAttribute(Content.Restaurant.Binding.HatchSpot)
	if type(attribute) == "number" then
		return math.floor(attribute)
	end
	const digits = string.match(instance.Name, `^{SPOT_PREFIX}(%d+)$`)
	return if digits then tonumber(digits) else nil
end

-- Spot instances by index (1..n, no holes), from the workspace; cached until one leaves it
function SupplyController:FindSpots(): { Instance }
	for _, spot in self.Spots do
		if not spot:IsDescendantOf(workspace) then
			table.clear(self.Spots)
			break
		end
	end
	if #self.Spots > 0 then
		return self.Spots
	end
	const found: { [number]: Instance } = {}
	for _, instance in workspace:GetDescendants() do
		const index = spotIndex(instance)
		if index ~= nil and index >= 1 and found[index] == nil and not instance:IsDescendantOf(self.Folder :: any) then
			found[index] = instance
		end
	end
	local index = 1
	while found[index] ~= nil do
		table.insert(self.Spots, found[index])
		index += 1
	end
	return self.Spots
end

local function worldOf(spot: Instance): Vector3
	if spot:IsA("Attachment") then
		return spot.WorldPosition
	end
	return (spot :: BasePart).Position
end

-- Bottom of a box at this spot: the surface under it, else the spot itself
local function floorUnder(position: Vector3, ignore: { Instance }): Vector3
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	const hit = workspace:Raycast(position + Vector3.new(0, 0.2, 0), Vector3.new(0, -BOX_DROP, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, BOX_SIZE.Y / 2, 0)
end

function SupplyController:ClearBox(index: number)
	const box = self.Boxes[index]
	if box == nil then
		return
	end
	self.Boxes[index] = nil
	box.Destroy()
	box.Gui:Destroy()
	box.Part:Destroy()
end

function SupplyController:DrawHatch()
	if self.Folder == nil then
		return -- OnStart not run yet: drawn there
	end
	const spots = self:FindSpots()
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	const ignore: { Instance } = { self.Folder :: Folder }
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		const record = self.Hatch[index]
		self:ClearBox(index)
		if record == nil or #spots == 0 or playerGui == nil then
			continue
		end
		const base = spots[((index - 1) % #spots) + 1]
		const level = (index - 1) // #spots
		const ground = floorUnder(worldOf(base), ignore)
		const part = Instance.new("Part")
		part.Name = `HatchBox{index}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Size = BOX_SIZE
		part.Material = Enum.Material.Cardboard
		part.Color = BOX_COLOR
		part.CFrame = CFrame.new(ground + Vector3.new(0, BOX_SIZE.Y * (level + 0.5) + 0.02 * level, 0))
		part.Parent = self.Folder
		const row = Content.Packages.ByKey[record.Package]
		const name = if row then row.Name else record.Package
		const destroy, gui = Vide.root(function(): BillboardGui
			return StockMenu.Tag({
				Name = `HatchBox{index}`,
				Adornee = part,
				Visible = function()
					return true
				end,
				Text = function()
					return name
				end,
				Empty = function()
					return false
				end,
				Size = BOX_TAG_SIZE,
				StudsOffset = Vector3.new(0, BOX_SIZE.Y / 2 + 0.35, 0),
				MaxDistance = BOX_MAX_DISTANCE,
			})
		end)
		gui.Parent = playerGui
		self.Boxes[index] = { Part = part, Destroy = destroy, Gui = gui }
	end
end

-- Phone and HUD ---------------------------------------------------------------------------------------------------------

function SupplyController:RefreshOrder()
	const lines, cost = self:Predict()
	self.Lines(lines)
	self.Cost(cost)
end

-- Is the phone the prompt aimed at or held now?
function SupplyController:PhoneTargeted(): boolean
	const prompts = self.Dependencies.PromptController
	const target = prompts.Holding or prompts.Target
	return target ~= nil and target.Anchor.Name == Content.Restaurant.Binding.PhonePrompt
end

function SupplyController:ChipText(): string
	const left = self:SecondsLeft()
	if left > 0 then
		return `On the way {StockMenu.Clock(left)}`
	end
	const low = self.LowKeys()[1]
	const package = if low then PACKAGE_OF[low] else nil
	return if package then `Low on {package.Name}` else ""
end

function SupplyController:ChipIcon(): string
	const low = self.LowKeys()[1]
	const package = if low then PACKAGE_OF[low] else nil
	return `Item/{if package then package.Key else Content.Packages.List[1].Key}`
end

function SupplyController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	const hud = self.Dependencies.HudController
	const _, gui = Vide.root(function(): ScreenGui
		const scale = function(): number
			return hud.Scale()
		end
		return Vide.create("ScreenGui")({
			Name = "Supply",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 1,
			Enabled = function()
				return not Cinematic.Active()
			end,
			Vide.create("Frame")({
				Name = "Layer",
				BackgroundTransparency = 1,
				Size = function()
					const s = scale()
					return UDim2.fromScale(1 / s, 1 / s)
				end,
				(Vide.create :: any)("UIScale")({ Scale = scale }),
				StockMenu.new({
					Visible = self.PhoneOpen,
					Lines = self.Lines,
					Cost = self.Cost,
					CanPay = function()
						return self.Dependencies.EconomyController.Cash() >= self.Cost()
					end,
					SecondsLeft = function()
						return self:SecondsLeft()
					end,
					Hint = function()
						return HINT[self.Dependencies.InputController.Device()] or HINT.KeyboardMouse
					end,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, UNDER_CLOCK),
				}),
				StockMenu.Chip({
					Visible = function()
						return not self.PhoneOpen() and self:ChipText() ~= ""
					end,
					Icon = function()
						return self:ChipIcon()
					end,
					Text = function()
						return self:ChipText()
					end,
					Pulse = function()
						return #self.LowKeys() > 0 and self:SecondsLeft() == 0
					end,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, UNDER_CLOCK),
				}),
			}),
		})
	end)
	gui.Parent = playerGui
	self.Gui = gui
end

SupplyController:OnInit(function(self)
	self:Setup()
	if not self.Live then
		return
	end
	-- listeners before Lync.start (README "Rede"); late joiners get the records through onAdded
	const restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant) :: any
	restaurant.Supply:onAdded(function(id: number, record: SupplyRecord)
		if id == SUPPLY_RECORD then
			self:WriteSupply(record)
		end
	end)
	restaurant.Supply:onChanged(function(id: number, record: SupplyRecord)
		if id == SUPPLY_RECORD then
			self:WriteSupply(record)
		end
	end)
	restaurant.Supply:onRemoved(function(id: number)
		if id == SUPPLY_RECORD then
			self:WriteSupply(nil)
		end
	end)
	restaurant.Hatch:onAdded(function(id: number, record: HatchRecord)
		self:WriteHatch(id, record)
	end)
	restaurant.Hatch:onChanged(function(id: number, record: HatchRecord)
		self:WriteHatch(id, record)
	end)
	restaurant.Hatch:onRemoved(function(id: number)
		self:WriteHatch(id, nil)
	end)
	const net = self.Libs.Net
	net.Stock:onAdded(function(id, record)
		self:WriteStock(id, record :: any)
	end)
	net.Stock:onChanged(function(id, record)
		self:WriteStock(id, record :: any)
	end)
	net.Stock:onRemoved(function(id)
		self:WriteStock(id, nil)
	end)
end)

SupplyController:OnStart(function(self)
	if not self.Live then
		return
	end
	const folder = Instance.new("Folder")
	folder.Name = "SupplyHatchBoxes" -- local only: the server never sees these parts
	folder.Parent = workspace
	self.Folder = folder
	-- PlayerGui and the map may arrive a little late; do not hold up the other OnStart
	task.spawn(function()
		self:Mount()
		self:WatchBays()
		self:DrawHatch()
	end)
end)

SupplyController:OnTick(function(self)
	if not self.Live or self.Gui == nil then
		return
	end
	self.Now(workspace:GetServerTimeNow())
	const open = self:PhoneTargeted()
	if open and not Vide.untrack(self.PhoneOpen) then
		self:RefreshOrder()
	end
	self.PhoneOpen(open)
end, TICK_RATE)

return SupplyController
