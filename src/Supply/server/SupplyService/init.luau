--!strict
-- Restaurant restock by boxes (FEAT-050; design/restaurant-flow.md; DEC-276; TASK-388, minimum: no van animation). Run
-- place only, and only with Content.Restaurant.Supply.Enabled AND Content.Restaurant.Rules.Enabled: with either off
-- nothing is bound, no action is registered, no snapshot is added (the published game is untouched). Single writer of
-- the Net.Restaurant Supply and Hatch sets.
--
-- Phone (anchor Binding.PhonePrompt, PHONE-R): order_stock, hold Supply.PhoneHold. There is no menu packet yet (the
-- client menu of TASK-389 needs one from the architect), so a tap places the "quick order" of Order.quick: Supply.MaxBoxes
-- boxes over the packages on sale (KitchenService:IsBlocked false), lowest stock first. Any order (Order) is refused
-- while Supply.InTransit calls are on the way (Notice supply_busy, value = seconds left), with no cash (Spend sends
-- not_enough_cash) or when it is empty / above MaxBoxes / has a blocked package. Cost = sum of the Package prices + Fee.
-- Accepted: Supply record 1 = OnTheWay until EndsAt = now + Supply.Eta, Notice supply_ordered to the party.
--
-- Arrival (Eta later, task.delay): each box goes to a product bay of its package (Shelves.luau: tag StockShelf), or, with
-- no bay for it, to the first free hatch spot (Hatch set record 1..Supply.HatchSpots, Package + Amount), or waits outside
-- and comes in as spots free up. A box is a full Mart package (Amount = Package.Amount).
--
-- take_box: on a bay anchor (Prompt_TakeBox under a StockShelf, text "Take <Package name>") gives one box of that bay;
-- on the hatch anchor (Binding.HatchPrompt under Binding.HatchTag) the box on the lowest spot. The box is the package Tool
-- (ItemService:Give, Count = Amount): hotbar and package limit (2, bear 3) are ItemService's (package_limit). Restock at
-- the station is the existing KitchenService one (partial transfer, the rest stays in the box, empty box goes away).
--
-- Start boxes: at the start of the run's first Night 1 shift, Supply.StartBoxes (1 DOGS + 1 BUNS) arrive at once (bays
-- with a StartBoxes attribute use it instead). Snapshot "Sup" (DEC-080): boxes on bays, hatch and outside; restoring
-- drops the calls on the way (the Cash snapshot gives their money back).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Order = require(script.Order)
local Shelves = require(script.Shelves)
local Modux = require(ServerScriptService.server.Modux)

-- A call on the way
export type Call = { Id: number, Boxes: Order.Boxes, EndsAt: number }
-- A box at the hatch or waiting outside
export type Box = { Package: string, Amount: number }

const ORDER = "order_stock"
const TAKE = "take_box"
const ANCHOR_TAG = "Interactable"
const SNAPSHOT = "Sup"
const SKU = "supply_call"
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant, same
-- value as MarketService / PlateService NOTICE_GAP: no Content field holds it yet.
const NOTICE_GAP = 2
-- take_box packets of one player closer than this are refused (cadence; the prompt is a tap). PROVISIONAL constant
const TAKE_GAP = 0.3

local function now(): number
	return workspace:GetServerTimeNow()
end

local function packageName(key: string): string
	const row = Content.Packages.ByKey[key]
	return if row then row.Name else key
end

local function fullBox(key: string): Box
	const row = Content.Packages.ByKey[key]
	return { Package = key, Amount = if row then row.Amount else 1 }
end

const SupplyService = Modux.Service("SupplyService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"ItemService",
		"EconomyService",
		"KitchenService",
	},
	Priority = 612,
})

function SupplyService:Setup()
	self.Enabled = false :: boolean
	self.Shelves = Shelves.new() :: Shelves.State
	-- Hatch spot -> box (1..Supply.HatchSpots), and boxes waiting outside (FIFO)
	self.Spots = {} :: { [number]: Box }
	self.Outside = {} :: { Box }
	self.Calls = {} :: { Call }
	self.NextCall = 0 :: number
	self.HatchAnchor = nil :: Instance?
	self.PhoneAnchor = nil :: Instance?
	-- Start boxes already given this run (Night 1)
	self.Seeded = false :: boolean
	-- Hatch records on the wire, and the Supply record
	self.Published = {} :: { [number]: boolean }
	self.SupplyPublished = false :: boolean
	self.LastTake = {} :: { [Player]: number }
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
end

-- Reads ---------------------------------------------------------------------------------------------------------------

function SupplyService:IsLive(): boolean
	return self.Enabled
end

function SupplyService:IsOpen(key: string): boolean
	const row = Content.Packages.ByKey[key]
	return row ~= nil and not self.Dependencies.KitchenService:IsBlocked(row.Ingredient)
end

-- Packages on sale now, in list order
function SupplyService:OpenPackages(): { string }
	const out: { string } = {}
	for _, row in Content.Packages.List do
		if self:IsOpen(row.Key) then
			table.insert(out, row.Key)
		end
	end
	return out
end

function SupplyService:MaxBoxes(): number
	return Content.Restaurant.Supply.MaxBoxes
end

function SupplyService:Eta(): number
	return Content.Restaurant.Supply.Eta
end

function SupplyService:IsBusy(): boolean
	return #self.Calls >= Content.Restaurant.Supply.InTransit
end

-- Seconds until the first call lands, 0 = none on the way
function SupplyService:SecondsLeft(): number
	local first = math.huge
	for _, call in self.Calls do
		first = math.min(first, call.EndsAt)
	end
	return if first == math.huge then 0 else math.max(0, math.ceil(first - now()))
end

-- Boxes waiting (bays + hatch + outside), by package
function SupplyService:Stock(): { [string]: number }
	const out = Shelves.totals(self.Shelves)
	for _, box in self.Spots do
		out[box.Package] = (out[box.Package] or 0) + 1
	end
	for _, box in self.Outside do
		out[box.Package] = (out[box.Package] or 0) + 1
	end
	return out
end

function SupplyService:CanAct(player: Player): boolean
	return self.Dependencies.RoundService:IsStarted() and self.Dependencies.RunStateService:IsActive(player)
end

-- Sends `key` to `player` unless the same key went to them less than NOTICE_GAP s ago
function SupplyService:NotifyThrottled(player: Player, key: string, value: number?)
	const clock = os.clock()
	local keys = self.NoticeAt[player]
	if keys == nil then
		keys = {}
		self.NoticeAt[player] = keys
	end
	const last = keys[key]
	if last ~= nil and clock - last < NOTICE_GAP then
		return
	end
	keys[key] = clock
	self.Dependencies.RunStateService:Notify(player, key, value)
end

-- Wire and prompts ----------------------------------------------------------------------------------------------------

function SupplyService:PublishSupply()
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	local boxes = 0
	local endsAt = 0
	for _, call in self.Calls do
		boxes += Order.count(call.Boxes)
		endsAt = if endsAt == 0 then call.EndsAt else math.min(endsAt, call.EndsAt)
	end
	const record = {
		State = if #self.Calls > 0 then "OnTheWay" else "Idle",
		EndsAt = endsAt,
		Boxes = math.clamp(boxes, 0, 255),
	}
	if self.SupplyPublished then
		Restaurant.Supply:update(1, record)
	else
		Restaurant.Supply:add(1, record)
		self.SupplyPublished = true
	end
end

function SupplyService:PublishHatch()
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		const box = self.Spots[index]
		if box ~= nil then
			const record = { Package = box.Package, Amount = math.clamp(box.Amount, 0, 999) }
			if self.Published[index] then
				Restaurant.Hatch:update(index, record)
			else
				Restaurant.Hatch:add(index, record)
				self.Published[index] = true
			end
		elseif self.Published[index] then
			Restaurant.Hatch:remove(index)
			self.Published[index] = nil
		end
	end
end

-- Lowest occupied hatch spot
function SupplyService:FirstSpot(): number?
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		if self.Spots[index] ~= nil then
			return index
		end
	end
	return nil
end

function SupplyService:RefreshPrompts()
	const interaction = self.Dependencies.InteractionService
	const action = Content.Actions.ByKey[TAKE].Text
	for _, shelf in self.Shelves.List do
		Shelves.mark(shelf)
		interaction:SetPrompt(shelf.Anchor, shelf.Boxes > 0, `Take {packageName(shelf.Package)}`)
	end
	const hatch = self.HatchAnchor
	if hatch ~= nil then
		const spot = self:FirstSpot()
		const box = if spot then self.Spots[spot] else nil
		interaction:SetPrompt(hatch, box ~= nil, if box then `Take {packageName(box.Package)}` else action)
	end
	const phone = self.PhoneAnchor
	if phone ~= nil then
		interaction:SetPrompt(phone, #self:OpenPackages() > 0, nil)
	end
end

function SupplyService:Refresh()
	self:PublishSupply()
	self:PublishHatch()
	self:RefreshPrompts()
end

-- Boxes -----------------------------------------------------------------------------------------------------------------

-- One box lands: its bay, else a free hatch spot, else outside. No refresh (the caller does it once)
function SupplyService:Land(box: Box)
	const shelf = Shelves.target(self.Shelves, box.Package)
	if shelf ~= nil then
		shelf.Boxes += 1
		return
	end
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		if self.Spots[index] == nil then
			self.Spots[index] = box
			return
		end
	end
	table.insert(self.Outside, box)
end

-- Outside boxes enter the free hatch spots (FIFO)
function SupplyService:PullOutside()
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		if #self.Outside == 0 then
			return
		end
		if self.Spots[index] == nil then
			self.Spots[index] = table.remove(self.Outside, 1) :: Box
		end
	end
end

function SupplyService:LandAll(boxes: Order.Boxes)
	for _, row in Content.Packages.List do
		for _ = 1, boxes[row.Key] or 0 do
			self:Land(fullBox(row.Key))
		end
	end
end

-- Call `id` arrives now (timer or /dev). false = no such call
function SupplyService:Arrive(id: number): boolean
	for index, call in self.Calls do
		if call.Id == id then
			table.remove(self.Calls, index)
			self:LandAll(call.Boxes)
			self:Refresh()
			return true
		end
	end
	return false
end

-- Places an order. player = who called (nil from /dev without a caller). Returns ok and a reason for /dev
function SupplyService:Order(player: Player?, boxes: Order.Boxes): (boolean, string)
	if not self.Enabled then
		return false, "off"
	end
	if self:IsBusy() then
		const left = self:SecondsLeft()
		if player then
			self:NotifyThrottled(player, "supply_busy", left)
		end
		return false, `busy ({left} s left)`
	end
	const allowed: { [string]: boolean } = {}
	for _, key in self:OpenPackages() do
		allowed[key] = true
	end
	const ok, reason = Order.validate(boxes, self:MaxBoxes(), Content.Packages.ByKey, allowed)
	if not ok then
		return false, reason or "invalid"
	end
	const prices: Order.Price = {}
	for key in boxes do
		prices[key] = Content.Packages.ByKey[key].Price
	end
	const cost = Order.cost(boxes, prices, Content.Restaurant.Supply.Fee)
	if not self.Dependencies.EconomyService:Spend(cost, player, SKU) then
		return false, `not_enough_cash (${cost})` -- Spend already told the player
	end
	self.NextCall += 1
	const eta = self:Eta()
	const call: Call = { Id = self.NextCall, Boxes = table.clone(boxes), EndsAt = now() + eta }
	table.insert(self.Calls, call)
	task.delay(eta, function()
		self:Arrive(call.Id)
	end)
	self:Refresh()
	self.Dependencies.RunStateService:Notify("all", "supply_ordered", eta)
	return true, `{Order.count(boxes)} boxes, ${cost}, {eta} s`
end

-- The tap order of the phone (Order.quick over the stock waiting now)
function SupplyService:QuickOrder(player: Player?): (boolean, string)
	const boxes = Order.quick(self:OpenPackages(), self:Stock(), self:MaxBoxes())
	if next(boxes) == nil then
		return false, "nothing on sale"
	end
	return self:Order(player, boxes)
end

-- Box of an anchor: a bay or the hatch. Returns the package key, nil = nothing to take there
function SupplyService:BoxAt(anchor: Instance): string?
	const shelf = self.Shelves.ByAnchor[anchor]
	if shelf ~= nil then
		return if shelf.Boxes > 0 then shelf.Package else nil
	end
	if anchor == self.HatchAnchor then
		const spot = self:FirstSpot()
		return if spot then self.Spots[spot].Package else nil
	end
	return nil
end

-- Gives the box of the anchor to the player. true = the Tool landed and the box left the bay / hatch
function SupplyService:Take(player: Player, anchor: Instance): boolean
	const shelf = self.Shelves.ByAnchor[anchor]
	if shelf ~= nil then
		if shelf.Boxes <= 0 then
			return false
		end
		const row = Content.Packages.ByKey[shelf.Package]
		if self.Dependencies.ItemService:Give(player, row.Item, { Count = row.Amount }) == nil then
			return false -- package_limit / hands_full already sent by Give
		end
		shelf.Boxes -= 1
		self:Refresh()
		return true
	end
	if anchor ~= self.HatchAnchor then
		return false
	end
	const spot = self:FirstSpot()
	if spot == nil then
		return false
	end
	const box = self.Spots[spot]
	const row = Content.Packages.ByKey[box.Package]
	if self.Dependencies.ItemService:Give(player, row.Item, { Count = box.Amount }) == nil then
		return false
	end
	self.Spots[spot] = nil
	self:PullOutside()
	self:Refresh()
	return true
end

function SupplyService:ValidateTake(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) or self:BoxAt(anchor) == nil then
		return false
	end
	const last = self.LastTake[player]
	return last == nil or os.clock() - last >= TAKE_GAP
end

function SupplyService:ValidateOrder(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) or anchor ~= self.PhoneAnchor then
		return false
	end
	if self:IsBusy() then
		self:NotifyThrottled(player, "supply_busy", self:SecondsLeft())
		return false
	end
	return true
end

-- Run state -------------------------------------------------------------------------------------------------------------

-- Every box gone and every call dropped (new run, restore)
function SupplyService:Clear()
	Shelves.clear(self.Shelves)
	table.clear(self.Spots)
	table.clear(self.Outside)
	table.clear(self.Calls) -- a pending timer finds no call and does nothing
end

-- Start boxes of the run (Night 1): bays with a StartBoxes attribute get it, the other packages Supply.StartBoxes
function SupplyService:Seed()
	self.Seeded = true
	for _, shelf in self.Shelves.List do
		if shelf.Start ~= nil then
			shelf.Boxes += shelf.Start
		end
	end
	for _, row in Content.Packages.List do
		const count = Content.Restaurant.Supply.StartBoxes[row.Key] or 0
		if count > 0 and not Shelves.authoredStart(self.Shelves, row.Key) then
			for _ = 1, count do
				self:Land(fullBox(row.Key))
			end
		end
	end
	self:Refresh()
end

function SupplyService:Capture(): any
	const hatch: { { P: string, A: number } } = {}
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		const box = self.Spots[index]
		if box ~= nil then
			table.insert(hatch, { P = box.Package, A = box.Amount })
		end
	end
	for _, box in self.Outside do
		table.insert(hatch, { P = box.Package, A = box.Amount })
	end
	const bays: { [string]: number } = {}
	for _, shelf in self.Shelves.List do
		bays[tostring(shelf.Id)] = shelf.Boxes
	end
	return { S = bays, H = hatch, Seeded = self.Seeded }
end

function SupplyService:Restore(data: any)
	self:Clear()
	if type(data) ~= "table" then
		self:Refresh()
		return
	end
	self.Seeded = data.Seeded == true
	if type(data.S) == "table" then
		for _, shelf in self.Shelves.List do
			const count = data.S[tostring(shelf.Id)]
			if type(count) == "number" and count >= 0 then
				shelf.Boxes = math.floor(count)
			end
		end
	end
	if type(data.H) == "table" then
		for _, entry in data.H do
			if type(entry) == "table" and type(entry.P) == "string" and Content.Packages.ByKey[entry.P] ~= nil then
				const amount = if type(entry.A) == "number" then math.max(1, math.floor(entry.A)) else fullBox(entry.P).Amount
				const box: Box = { Package = entry.P, Amount = amount }
				local placed = false
				for index = 1, Content.Restaurant.Supply.HatchSpots do
					if self.Spots[index] == nil then
						self.Spots[index] = box
						placed = true
						break
					end
				end
				if not placed then
					table.insert(self.Outside, box)
				end
			end
		end
	end
	self:Refresh()
end

-- Binding ---------------------------------------------------------------------------------------------------------------

function SupplyService:BindAnchor(anchor: Instance, action: string, hold: number?)
	-- Attributes before the tag: InteractionService reads them when the anchor is tagged
	anchor:SetAttribute("PromptAction", action)
	anchor:SetAttribute("PromptEnabled", false)
	if hold ~= nil then
		self.Dependencies.InteractionService:SetPromptHold(anchor, hold)
	end
	if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end
end

function SupplyService:Bind()
	const binding = Content.Restaurant.Binding
	Shelves.bind(self.Shelves, Content.Packages.ByKey)
	for _, shelf in self.Shelves.List do
		self:BindAnchor(shelf.Anchor, TAKE, nil)
	end
	for _, hatch in CollectionService:GetTagged(binding.HatchTag) do
		if not hatch:IsDescendantOf(workspace) then
			continue
		end
		const anchor = if hatch.Name == binding.HatchPrompt then hatch else hatch:FindFirstChild(binding.HatchPrompt, true)
		if anchor ~= nil and self.Shelves.ByAnchor[anchor] == nil then
			self.HatchAnchor = anchor
			self:BindAnchor(anchor, TAKE, nil)
			break
		end
	end
	const phone = workspace:FindFirstChild(binding.PhonePrompt, true)
	if phone ~= nil then
		self.PhoneAnchor = phone
		self:BindAnchor(phone, ORDER, Content.Restaurant.Supply.PhoneHold)
	end
	if #self.Shelves.List == 0 and self.HatchAnchor == nil then
		warn(`[SupplyService] supply on but no {Shelves.Tag} bay and no {binding.HatchTag} {binding.HatchPrompt}: boxes cannot be taken`)
	end
	if self.PhoneAnchor == nil then
		warn(`[SupplyService] supply on but no {binding.PhonePrompt} in the map: no phone order (only /dev supply)`)
	end
end

-- Dev (PlaceService:IsDev; /dev supply) -------------------------------------------------------------------------------

function SupplyService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[SupplyService] dev mode only", 3)
	end
	if not self.Enabled then
		error("supply off (Content.Restaurant.Supply.Enabled and Rules.Enabled)", 0)
	end
end

function SupplyService:DevState(): string
	self:DevCheck()
	const lines: { string } = {}
	table.insert(
		lines,
		string.format(
			"supply: %d call(s) on the way, %d s left, max %d boxes, eta %d s, fee $%d, seeded %s",
			#self.Calls,
			self:SecondsLeft(),
			self:MaxBoxes(),
			self:Eta(),
			Content.Restaurant.Supply.Fee,
			tostring(self.Seeded)
		)
	)
	for _, call in self.Calls do
		const parts: { string } = {}
		for key, count in call.Boxes do
			table.insert(parts, `{key} x{count}`)
		end
		table.sort(parts)
		table.insert(lines, `  call #{call.Id}: {table.concat(parts, ", ")} in {math.max(0, math.ceil(call.EndsAt - now()))} s`)
	end
	for _, shelf in self.Shelves.List do
		table.insert(lines, `  bay {shelf.Id} {shelf.Root.Name} [{shelf.Package}]: {shelf.Boxes} box(es)`)
	end
	for index = 1, Content.Restaurant.Supply.HatchSpots do
		const box = self.Spots[index]
		if box ~= nil then
			table.insert(lines, `  hatch {index}: {box.Package} ({box.Amount})`)
		end
	end
	if #self.Outside > 0 then
		table.insert(lines, `  outside: {#self.Outside} box(es)`)
	end
	table.insert(lines, `  on sale: {table.concat(self:OpenPackages(), ", ")}`)
	table.insert(
		lines,
		`  hatch prompt {if self.HatchAnchor then "bound" else "missing"}, phone {if self.PhoneAnchor then "bound" else "missing"}`
	)
	return table.concat(lines, "\n")
end

function SupplyService:DevOrder(player: Player?, boxes: Order.Boxes?): string
	self:DevCheck()
	local ok, reason
	if boxes then
		ok, reason = self:Order(player, boxes)
	else
		ok, reason = self:QuickOrder(player)
	end
	return if ok then `ordered: {reason}` else `refused: {reason}`
end

function SupplyService:DevArrive(): string
	self:DevCheck()
	local count = 0
	while #self.Calls > 0 do
		self:Arrive(self.Calls[1].Id)
		count += 1
	end
	return `{count} call(s) arrived`
end

-- Takes a box for `player` as the prompt would (no range check): package key = its first bay, nil = the hatch
function SupplyService:DevTake(player: Player, package: string?): string
	self:DevCheck()
	local anchor: Instance? = self.HatchAnchor
	if package ~= nil then
		anchor = nil
		for _, shelf in self.Shelves.List do
			if shelf.Package == package and shelf.Boxes > 0 then
				anchor = shelf.Anchor
				break
			end
		end
	end
	if anchor == nil then
		return `nothing to take ({package or "hatch"})`
	end
	return if self:Take(player, anchor) then "box in hand" else "refused (limit, hotbar or empty)"
end

function SupplyService:DevSeed(): string
	self:DevCheck()
	self:Seed()
	return "start boxes landed"
end

function SupplyService:DevClear(): string
	self:DevCheck()
	self:Clear()
	self:Refresh()
	return "every box and call gone"
end

SupplyService:OnInit(function(self)
	self:Setup()
	const supply = Content.Restaurant.Supply
	if not self.Dependencies.PlaceService:Is("Run") or not supply.Enabled or not Content.Restaurant.Rules.Enabled then
		return
	end
	self.Enabled = true

	-- Priority 612 < 730: InteractionService already built its handler table
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(ORDER, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidateOrder(player, anchor)
		end,
		Run = function(player: Player, _anchor: Instance)
			self:QuickOrder(player)
		end,
	})
	interaction:RegisterAction(TAKE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidateTake(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self.LastTake[player] = os.clock()
			self:Take(player, anchor)
		end,
	})
	-- RunStateService (760) built its registry in its own OnInit
	self.Dependencies.RunStateService:RegisterSnapshot(SNAPSHOT, function()
		return self:Capture()
	end, function(data: any, _mode)
		self:Restore(data)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self.LastTake[player] = nil
		self.NoticeAt[player] = nil
	end)
end)

SupplyService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57); InteractionService (730) watches the anchors tagged here
	self:Bind()
	self:Refresh()

	const round = self.Dependencies.RoundService
	-- ShiftStarted fires before the shift capture, so the start boxes enter the Night 1 snapshot
	round.ShiftStarted:Connect(function(info)
		if info.IsNight and info.Night == 1 and not self.Seeded then
			self:Seed()
		end
	end)
	round.RunEnded:Connect(function()
		self:Clear()
		self.Seeded = false
		self:Refresh()
	end)
	-- day / vehicle change opens packages: the phone prompt follows
	round.PhaseChanged:Connect(function()
		self:RefreshPrompts()
	end)
end)

return SupplyService
