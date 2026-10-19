--!strict
-- Pad tables (FEAT-037; UPG-008, UPG-009; Q-178 A, Q-179 a, Q-180 A, Q-181 A; architecture.md §19.28; network.md
-- §14; content-data.md §3.25; TASK-145). Run place only. Single writer of the Tables set (record = table index) and
-- owner of the actions buy_in_place and clean_table.
--
--   Tables    found at OnStart: Models tagged Seating.Binding.Tag with TableIndex 1..Tables (TASK-149). FALLBACK while
--             the tag is missing: Models named Binding.ModelName inside Workspace.<Binding.Folder>, ordered by their
--             distance to MapPoint Q1 (warned once); the tag and TableIndex are then written here so the clients find
--             them the same way. Seats = BaseParts Seat1..Seat4. Prompt anchors Prompt_BuyTable / Prompt_CleanTable
--             when bound, else one runtime Attachment Prompt_Table over the top of the table for both actions.
--   States    Locked (before Seating.UnlockDay) -> Ghost (not bought; only the next one has Price and a prompt) ->
--             Free -> Occupied -> Dirty -> (Clean Table) Free. Not bought = no collision (CanCollide off, written
--             here); the ghost look (transparency) is the client's (TASK-147).
--   Purchase  buy_in_place on the next ghost: UpgradeService:Buy(group.UpgradeKey, player, quiet) -> the group's Stat
--             + 1 (kept in the "Upg" snapshot), notice table_added.
--   Groups    (Content.Seating.Groups, Q-209; one group since 2026-10-12) Trailer = TBL-1..4 (UPG-011), the four tables
--             on the Pad in front of the trailer. A group is Locked (hidden, no collision) while its vehicle is not the
--             current one; the group shows only the next table for sale (GhostAll = false).
--             Other anchors with buy_in_place + attribute Upgrade = Seating.LightsKey sell Patio Lights (UPG-009).
--   Sitting   CustomerService:SetSeater({ Offer, Left }) -> Offer(party) at "Take Order" (Q-209, Provisional): the 5
--             conditions (free table of the group that seats, MaxDiners, SitHeadroom, SitPhases, no tension), then the
--             old chance only when Seating.SitChanceApplies. The table is reserved (Occupied, Npc1/Npc2) at once; the
--             party walks Q1 -> node TBL-n (or the nearest graph node, fallback) -> approach point -> seat (Diner.Sit)
--             and WAITS (Phase Seated: rig attribute Seated, no food). The table anchor ServeAnchor carries
--             serve_table (PromptText "Serve Table n: Ketchup + Cheese", one block per pending hot dog, "|" between a
--             pair's); CustomerService:ServeTable pays it like the counter. Served well -> Left(leader, true) ->
--             Phase Eating (rig attribute Eating: the client gives it the hot dog) for Tables.EatTime, stands
--             (Diner.Stand), leaves TableTip per diner on the table (Dirty), walks back to the node and
--             CustomerService:Dismiss sends it out. Wrong item, patience out, tension or a shift end -> Left(leader,
--             false) / StandAll: up at once, no tray, no tip (the table is Free).
--   Tension   while an anomaly of Seating.TensionAnomalies runs or a customer anomaly is alive: nobody sits, every
--             diner stands within one tick (TICK_RATE).
--   Phases    Closing (night 6 AM): nobody sits, diners finish. Day Last call (DEC-240): sitting still works. Any other non-selling phase: diners stand at once. Drawer closed
--             (Summary, night end...): every table clean, tips on them lost (TipLostAtSummary). ShiftStarted: clean.
--   Restaurant (TASK-386; tech/restaurant-flow.md rev. 2 §3.1, DT-R11; DEC-280). Two data flags, defaults = the trailer:
--   SitAt     Content.Seating.SitAt = "Order" (default): the Q-209 flow above. "Served": the table is offered only AFTER the
--             sale at the pickup counter, with the plate in hand. CustomerService (TASK-380) calls Seater.Offer after the
--             sale with the customer already Leaving + Dining (AtTable false, rig Carrying = true); an Offer in any other
--             state (the "Take Order" one) is refused. SeatingService:OfferServed(party) is the same call for a caller that
--             does not go through the Seater. Same 5 conditions. Taken: the party walks PU-n -> TBL-n, sits and EATS at
--             once (no serve_table wait, Seater.Left is not used for it), stands after EatTime and
--             CustomerService:Dismiss sends it out. Refused (no table, chance, phase, tension): CustomerService sends it
--             out carrying the plate (takeaway, Restaurant.Rules.TakeawayWhenNoTable).
--   DirtyTables  true (default): the tray + TableTip stays on the table (Dirty) until clean_table. false: the table goes
--             straight back to Free and the TableTip per diner goes into the tip jar (EconomyService:AddTip, the jar of
--             TipJarService) when the party stands up after eating.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Diner = require(script.Diner)
local Tables = require(script.Tables)
local Modux = require(ServerScriptService.server.Modux)

export type State = Tables.State

-- Tables set record (network.md §14.1)
export type Record = { State: State, Price: number, Npc1: number, Npc2: number, Tip: number }

export type Spot = {
	Index: number,
	Serve: Instance?, -- anchor of serve_table (bound or runtime)
	ServeText: string, -- last PromptText written on it ("" = off)
	Model: Model?, -- nil = not in the binding (record still published: the client ignores it)
	Seats: { [number]: BasePart },
	Buy: Instance?, -- anchor of buy_in_place
	Node: string?, -- graph node next to the table (TBL-n, or the nearest node)
	Group: Content.SeatingGroup,
	Collide: { [BasePart]: boolean }, -- authored CanCollide of every part
	State: State,
	Price: number,
	Tip: number,
	Party: number?, -- leader NpcId of the party using it
}

export type Member = { Id: number, Seat: number, Rig: Diner.Rig? }

export type Phase = "Walking" | "Seated" | "Eating" | "Leaving"

export type Party = {
	Leader: number,
	Members: { Member },
	Couple: boolean,
	Table: number,
	Phase: Phase,
	StartedAt: number,
	Until: number, -- Eating: server time it stands up (0 while it waits for the food)
	EatTime: number,
	Height: number, -- root Y while standing (approach / stand point)
	Token: number, -- bumped to cancel the walk thread
	Served: boolean, -- SitAt "Served": the food came with it, it eats as soon as it sits (TASK-386)
}

export type SeatParty = { Leader: number, Partner: number?, Couple: boolean, CustomerType: string }

const SEATING = Content.Seating
const BINDING = SEATING.Binding
const MAX_NODE_GAP = 20 -- studs: a table farther than this from every graph node is warned (nobody can walk to it)
const BUY = "buy_in_place"
const ANCHOR_TAG = "Interactable"
const UPGRADE_ATTRIBUTE = "Upgrade"
const TICK_RATE = 5 -- Hz (tension: diners up within 1 s, FEAT-037)
const SEED_MAX = 2147483646
const SEED_DOMAIN = "seating"
const CLOSING = "Closing"
const SERVE = "serve_table"
const SERVE_LIFT = 0.6 -- studs over the top of the table (runtime serve anchor)
const ADDED_NOTICE = "table_added"
const BOUGHT_NOTICE = "upgrade_bought"
const ANCHOR_LIFT = 0.6 -- studs over the top of the table (runtime anchor)
const PARTNER_WALK = 4 -- s for the partner's straight walk to its seat
const DEFAULT_HEIGHT = 3 -- root over the floor when nothing better is known (architecture.md §18.5)
-- In-place upgrades this build sells (UPG-010 Back Bar has no table yet: refused, Q-179 b)
const SOLD: { [string]: boolean } = { [SEATING.LightsKey] = true }
-- upgrade key of a table group -> its group
const GROUP_OF_UPGRADE: { [string]: Content.SeatingGroup } = {}
for _, group in SEATING.Groups do
	SOLD[group.UpgradeKey] = true
	GROUP_OF_UPGRADE[group.UpgradeKey] = group
end

local function groupOfIndex(index: number): Content.SeatingGroup
	for _, group in SEATING.Groups do
		if index >= group.First and index < group.First + group.Count then
			return group
		end
	end
	return SEATING.Groups[1]
end

local function now(): number
	return workspace:GetServerTimeNow()
end

-- djb2, same as CustomerService (architecture.md §4 rule 6)
local function hash(text: string): number
	local h = 5381
	for index = 1, #text do
		h = (h * 33 + string.byte(text, index)) % 4294967296
	end
	return h
end

local function isQueueNode(id: string): boolean
	return string.match(id, "^Q%d+$") ~= nil
end

local function hasNode(id: string): boolean
	const ok = pcall(MapIndex.Node, id)
	return ok
end

const SeatingService = Modux.Service("SeatingService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"EconomyService",
		"InteractionService",
		"UpgradeService",
		"NpcService",
		"CustomerService",
		"AnomalyService",
	},
	Priority = 568,
})

function SeatingService:Setup()
	self.Enabled = false :: boolean
	-- Lync started (OnStart): the set is writable
	self.Live = false :: boolean
	self.Spots = {} :: { Spot }
	-- by leader NpcId
	self.Parties = {} :: { [number]: Party }
	-- member NpcId -> leader NpcId
	self.ByMember = {} :: { [number]: number }
	-- buy_in_place anchors of other upgrades (Patio Lights sign)
	self.PlaceAnchors = {} :: { Instance }
	self.Rng = Random.new() :: Random
	self.Warned = {} :: { [string]: boolean }
	-- dev: the next eligible party sits whatever the chance
	self.ForceSit = false :: boolean
end

function SeatingService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[SeatingService] {message}`)
end

-- Reads -----------------------------------------------------------------------------------------------------------

function SeatingService:Get(index: number): Spot?
	return self.Spots[index]
end

-- Tables bought of a group (its Stat on the current vehicle; the Pad group has Pad scope = the same on every vehicle);
-- without a group: every table bought.
function SeatingService:Owned(group: Content.SeatingGroup?): number
	if group == nil then
		local total = 0
		for _, each in SEATING.Groups do
			total += self:Owned(each)
		end
		return total
	end
	return math.clamp(self.Dependencies.UpgradeService:GetEffect(group.Stat), 0, group.Count)
end

-- The group is shown and sold on the current vehicle (Trailer tables: only once the trailer is the vehicle).
-- Anomaly mode (Content.Mode.DayOnly = false, owner request 2026-10-14, Provisional): no group is active, so every table
-- is Locked (hidden, no collision, no prompt, never for sale), nobody sits and the Patio Lights sign stays off. The code
-- stays: DayOnly = true brings the tables back as they were.
function SeatingService:IsActive(group: Content.SeatingGroup): boolean
	if not Content.Mode.DayOnly then
		return false
	end
	return table.find(group.Vehicles, self.Dependencies.UpgradeService:GetVehicle()) ~= nil
end

-- Group that seats now: Trailer as soon as the trailer is the vehicle and one of its tables is bought, else Pad
-- (a party never mixes groups).
function SeatingService:SeatingGroup(): string
	for index = #SEATING.Groups, 2, -1 do
		const group = SEATING.Groups[index]
		if self:IsActive(group) and self:Owned(group) > 0 then
			return group.Key
		end
	end
	return SEATING.Groups[1].Key
end

function SeatingService:IsUnlocked(): boolean
	return self.Dependencies.RoundService:GetDay() >= SEATING.UnlockDay
end

function SeatingService:IsNight(): boolean
	return self.Dependencies.CustomerService:IsNightShift()
end

-- NPCs seated or walking to / from a table.
function SeatingService:Diners(): number
	local count = 0
	for _ in self.ByMember do
		count += 1
	end
	return count
end

-- Tension (FEAT-037): an anomaly of TensionAnomalies runs, or a customer anomaly is alive.
function SeatingService:IsTense(): boolean
	const anomaly = self.Dependencies.AnomalyService
	for _, key in SEATING.TensionAnomalies do
		if anomaly:IsRunning(key) then
			return true
		end
	end
	return self.Dependencies.CustomerService:HasActor()
end

-- Open and Night, plus the day Last call (DEC-240): the line is still served and a customer who orders may sit
function SeatingService:InSitPhase(): boolean
	const round = self.Dependencies.RoundService
	return table.find(SEATING.SitPhases, round:GetPhase()) ~= nil or round:IsLastCall()
end

-- Network ---------------------------------------------------------------------------------------------------------

function SeatingService:Record(spot: Spot): Record
	const party = if spot.Party then self.Parties[spot.Party] else nil
	const members = if party then party.Members else {}
	return {
		State = spot.State,
		Price = spot.Price,
		Npc1 = if members[1] then members[1].Id else 0,
		Npc2 = if members[2] then members[2].Id else 0,
		Tip = spot.Tip,
	}
end

function SeatingService:Publish(spot: Spot, added: boolean?)
	if not self.Live or not self.Dependencies.NetService:IsRunning() then
		return
	end
	if added then
		self.Libs.Net.Tables:add(spot.Index, self:Record(spot))
	else
		self.Libs.Net.Tables:update(spot.Index, self:Record(spot))
	end
end

-- Binding ---------------------------------------------------------------------------------------------------------

-- Bound tables by TableIndex, or the fallback (by name, ordered by distance to Q1).
function SeatingService:FindModels(): { [number]: Model }
	const found: { [number]: Model } = {}
	for _, instance in CollectionService:GetTagged(BINDING.Tag) do
		const index = instance:GetAttribute(BINDING.IndexAttribute)
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) and typeof(index) == "number" then
			if index >= 1 and index <= SEATING.Tables and found[index] == nil then
				found[index] = instance
				const declared = instance:GetAttribute(BINDING.GroupAttribute)
				if typeof(declared) == "string" and declared ~= groupOfIndex(index).Key then
					self:WarnOnce(
						`group:{index}`,
						`{instance:GetFullName()}: {BINDING.GroupAttribute} = {declared} but {BINDING.IndexAttribute} {index} is the {groupOfIndex(index).Key} group`
					)
				end
			end
		end
	end
	if next(found) ~= nil then
		return found
	end
	-- FALLBACK (no SeatTable tag yet, TASK-149): Workspace.MAP01_Assets.PadDecor/AST-100_PicnicTable by distance to Q1
	local folder: Instance? = workspace
	for _, name in BINDING.Folder do
		folder = if folder then folder:FindFirstChild(name) else nil
	end
	if folder == nil then
		self:WarnOnce("nofolder", `no {BINDING.Tag} tables and no Workspace.{table.concat(BINDING.Folder, ".")}: no tables`)
		return found
	end
	const models: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.Name == BINDING.ModelName then
			table.insert(models, child)
		end
	end
	const q1 = MapIndex.FindPoint("Q1")
	const origin = if q1 then q1.Position else Vector3.zero
	const distance: { [Model]: number } = {}
	for _, model in models do
		const offset = model:GetPivot().Position - origin
		distance[model] = Vector3.new(offset.X, 0, offset.Z).Magnitude
	end
	table.sort(models, function(a: Model, b: Model): boolean
		return distance[a] < distance[b]
	end)
	for index, model in models do
		if index > SEATING.Groups[1].Count then
			break -- only the Pad group is found by name; the Trailer tables come tagged (Q-209)
		end
		-- written here so the clients find the tables like a bound place (same contract)
		model:SetAttribute(BINDING.IndexAttribute, index)
		CollectionService:AddTag(model, BINDING.Tag)
		found[index] = model
	end
	self:WarnOnce(
		"fallback",
		`no {BINDING.Tag} tag in the place (TASK-149): {#models} {BINDING.ModelName} found by name, ordered by distance to Q1`
	)
	return found
end

-- Interactable anchor of a table: the bound one, else nil.
local function boundAnchor(model: Model, name: string): Instance?
	const anchor = model:FindFirstChild(name, true)
	if anchor ~= nil and (anchor:IsA("Attachment") or anchor:IsA("BasePart")) then
		return anchor
	end
	return nil
end

-- Runtime anchor over the top of the table (centre of its bounding box, `lift` above the top).
local function runtimeAnchor(model: Model, name: string, lift: number): Attachment?
	const frame, size = model:GetBoundingBox()
	const top = frame.Position + Vector3.new(0, size.Y / 2 + lift, 0)
	local host: BasePart? = model.PrimaryPart
	if host == nil then
		local best = -1
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				const area = part.Size.X * part.Size.Z
				if area > best then
					best = area
					host = part
				end
			end
		end
	end
	if host == nil then
		return nil
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = host
	attachment.WorldPosition = top
	return attachment
end

-- Attributes before the tag: InteractionService reads them when the anchor is tracked.
local function prepareAnchor(anchor: Instance, action: string, index: number?, upgrade: string)
	anchor:SetAttribute("PromptAction", action)
	anchor:SetAttribute("PromptEnabled", false)
	if upgrade ~= "" then
		anchor:SetAttribute(UPGRADE_ATTRIBUTE, upgrade)
	end
	if index ~= nil then
		anchor:SetAttribute(BINDING.IndexAttribute, index)
	end
	if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end
end

function SeatingService:BuildSpot(index: number, model: Model?): Spot
	const spot: Spot = {
		Index = index,
		Serve = nil,
		ServeText = "",
		Model = model,
		Seats = {},
		Buy = nil,
		Clean = nil,
		Node = nil,
		Group = groupOfIndex(index),
		Collide = {},
		State = "Locked",
		Price = 0,
		Tip = 0,
		Party = nil,
	}
	if model == nil then
		return spot
	end
	for seat = 1, BINDING.SeatCount do
		const part = model:FindFirstChild(`{BINDING.SeatPrefix}{seat}`, true)
		if part ~= nil and part:IsA("BasePart") then
			spot.Seats[seat] = part
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			spot.Collide[part] = part.CanCollide
		end
	end
	const buy = boundAnchor(model, BINDING.BuyAnchor) or runtimeAnchor(model, BINDING.RuntimeAnchor, ANCHOR_LIFT)
	spot.Buy = buy
	if buy ~= nil then
		prepareAnchor(buy, BUY, index, spot.Group.UpgradeKey)
	end
	-- serve_table anchor (Q-209): its own, on while a customer waits there for its food
	const serve = boundAnchor(model, BINDING.ServeAnchor) or runtimeAnchor(model, BINDING.RuntimeServeAnchor, SERVE_LIFT)
	spot.Serve = serve
	if serve ~= nil then
		prepareAnchor(serve, SERVE, index, "")
	end
	-- Graph node next to the table: TBL-n (TASK-149), else the nearest node that is not a queue slot (fallback)
	const named = `{BINDING.NodePrefix}{index}`
	if hasNode(named) then
		spot.Node = named
	else
		spot.Node = MapIndex.NearestNode(model:GetPivot().Position, isQueueNode)
		const ok, node = pcall(MapIndex.Node, spot.Node :: string)
		if not ok or (node.Position - model:GetPivot().Position).Magnitude > MAX_NODE_GAP then
			self:WarnOnce(
				`gap:{index}`,
				`TBL-{index} ({spot.Group.Key}) has no graph node within {MAX_NODE_GAP} studs: add NpcNode {named} next to it and an edge to the queue`
			)
		end
	end
	return spot
end

-- Other in-place sellers (Patio Lights sign): Interactable anchors with buy_in_place and an Upgrade attribute.
function SeatingService:FindPlaceAnchors()
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if not anchor:IsDescendantOf(workspace) or anchor:GetAttribute("PromptAction") ~= BUY then
			continue
		end
		const key = anchor:GetAttribute(UPGRADE_ATTRIBUTE)
		if typeof(key) ~= "string" or GROUP_OF_UPGRADE[key] ~= nil then
			continue
		end
		table.insert(self.PlaceAnchors, anchor)
	end
	-- by name too (MAP-01 binding of the sign, TASK-149)
	const sign = workspace:FindFirstChild(BINDING.LightsAnchor, true)
	if sign ~= nil and table.find(self.PlaceAnchors, sign) == nil then
		prepareAnchor(sign, BUY, nil, SEATING.LightsKey)
		table.insert(self.PlaceAnchors, sign)
	end
end

-- State -----------------------------------------------------------------------------------------------------------

-- No collision while not bought (written here, replicates); the authored value once bought.
function SeatingService:ApplyCollision(spot: Spot)
	const solid = spot.State ~= "Locked" and spot.State ~= "Ghost"
	for part, authored in spot.Collide do
		if part.Parent ~= nil then
			part.CanCollide = solid and authored
		end
	end
end

-- Prompt text "Buy Table — $30" (Actions.buy_in_place.Text with {item} and {price}).
local function buyText(label: string, price: number): string
	const text = Content.Actions.ByKey[BUY].Text
	return (string.gsub(string.gsub(text, "{item}", label), "{price}", tostring(price)))
end

-- "Serve Table 2: Ketchup + Cheese" / "... | Mustard" (a pair): one block per pending hot dog, toppings by name.
local function serveText(index: number, lines: { { string } }): string
	const parts: { string } = {}
	for _, toppings in lines do
		const names: { string } = {}
		for _, key in toppings do
			const row = Content.Ingredients.ByKey[key]
			table.insert(names, if row then row.Name else key)
		end
		table.insert(parts, if #names > 0 then table.concat(names, " + ") else "Plain")
	end
	return `Serve Table {index}: {table.concat(parts, " | ")}`
end

-- The serve_table prompt: on while the party sits at the table and its food is still pending; the text names the table
-- and what it ordered (Q-209). Writes only when the text changed.
function SeatingService:RefreshServe(spot: Spot)
	const anchor = spot.Serve
	if anchor == nil then
		return
	end
	const party = if spot.Party then self.Parties[spot.Party] else nil
	local text = ""
	if party ~= nil and party.Phase == "Seated" then
		const customers = self.Dependencies.CustomerService
		if customers:IsWaitingAtTable(party.Leader) then
			text = serveText(spot.Index, customers:PendingToppings(party.Leader))
		end
	end
	if text == spot.ServeText then
		return
	end
	spot.ServeText = text
	self.Dependencies.InteractionService:SetPrompt(anchor, text ~= "", if text ~= "" then text else nil)
end

function SeatingService:ApplyPrompts(spot: Spot)
	self:RefreshServe(spot)
	const interaction = self.Dependencies.InteractionService
	const buy = spot.Buy
	const forSale = spot.State == "Ghost" and spot.Price > 0
	if buy ~= nil then
		interaction:SetPrompt(buy, forSale, if forSale then buyText(spot.Group.Label, spot.Price) else nil)
	end
end

-- State of a table not in use: its group's purchases, the day and the vehicle.
function SeatingService:Idle(spot: Spot): State
	const group = spot.Group
	const position = spot.Index - group.First + 1
	if not self:IsActive(group) then
		return "Locked" -- the Trailer tables before the trailer is bought: hidden, no collision
	end
	return Tables.Next(spot.State, position, self:Owned(group), self:IsUnlocked(), group.GhostAll)
end

-- Recomputes every table from the purchases, the day and the vehicle; writes what changed.
function SeatingService:Refresh()
	const upgrades = self.Dependencies.UpgradeService
	for _, spot in self.Spots do
		const group = spot.Group
		const position = spot.Index - group.First + 1
		const busy = spot.State == "Occupied" or spot.State == "Dirty"
		const state = if busy and not self:IsActive(group) then spot.State else self:Idle(spot)
		const nextRow = upgrades:NextLevel(group.UpgradeKey)
		-- a table missing from the map (the place may have fewer than Seating.Tables) is never for sale
		const price = if state == "Ghost"
				and position == self:Owned(group) + 1
				and nextRow ~= nil
				and spot.Model ~= nil
			then nextRow.Price
			else 0
		if state == spot.State and price == spot.Price then
			continue
		end
		spot.State = state
		spot.Price = price
		if state ~= "Dirty" and state ~= "Occupied" then
			spot.Tip = 0
		end
		self:ApplyCollision(spot)
		self:ApplyPrompts(spot)
		self:Publish(spot)
	end
	self:RefreshPlaceAnchors()
end

-- Patio Lights sign (and any other in-place seller): on while it can be bought.
function SeatingService:RefreshPlaceAnchors()
	const upgrades = self.Dependencies.UpgradeService
	const interaction = self.Dependencies.InteractionService
	for _, anchor in self.PlaceAnchors do
		const key = anchor:GetAttribute(UPGRADE_ATTRIBUTE)
		local text: string? = nil
		local on = false
		if typeof(key) == "string" and SOLD[key] then
			const row = upgrades:NextLevel(key)
			const ok = upgrades:CanBuy(key)
			-- the Pad is an empty lot on the trailer (Q-216): its Patio Lights sign is not sold there
			on = ok and row ~= nil and self:IsActive(SEATING.Groups[1])
			if on and row ~= nil then
				text = buyText(Content.Upgrades.ByKey[key].Name, row.Price)
			end
		elseif typeof(key) == "string" then
			self:WarnOnce(`unsold:{key}`, `in-place upgrade {key} is not sold in this build (UPG-010: no TBL-6 yet)`)
		end
		interaction:SetPrompt(anchor, on, text)
	end
end

function SeatingService:SetState(spot: Spot, state: State)
	if spot.State == state then
		self:Publish(spot)
		return
	end
	spot.State = state
	self:ApplyCollision(spot)
	self:ApplyPrompts(spot)
	self:Publish(spot)
end

-- Every table back to idle (Summary, night end, new shift): Dirty -> Free, tip on it lost (Q-181 A).
function SeatingService:ResetTables()
	for _, spot in self.Spots do
		if spot.Party ~= nil then
			continue
		end
		spot.Tip = 0
		if spot.State == "Dirty" or spot.State == "Occupied" then
			spot.State = "Free"
			self:ApplyCollision(spot)
			self:ApplyPrompts(spot)
			self:Publish(spot)
		end
	end
	self:Refresh()
end

-- Sitting ---------------------------------------------------------------------------------------------------------

-- Seats a party may use at `spot` (every seat of its layout bound).
local function hasSeats(spot: Spot, seats: { number }): boolean
	if spot.Model == nil then
		return false
	end
	for _, seat in seats do
		if spot.Seats[seat] == nil then
			return false
		end
	end
	return true
end

-- CustomerService seater (SetSeater.Offer): the party just had its order taken. Must not yield (runs inside the Take
-- Order Run). true = reserved a table, the party is ours until Dismiss.
function SeatingService:TrySeat(party: SeatParty): boolean
	if not self.Enabled or not self.Live or not Content.Mode.DayOnly then
		return false
	end
	if self.ByMember[party.Leader] ~= nil then
		return false
	end
	const customers = self.Dependencies.CustomerService
	-- SitAt "Served" (TASK-386): only after the sale (CustomerService already ran Leave(..., dining): Leaving + Dining),
	-- never at "Take Order"
	const record = customers:Get(party.Leader)
	if record == nil or record.State ~= "Leaving" or not record.Dining then
		return false
	end
	const size = if party.Partner ~= nil then 2 else 1
	-- (4) phase, (5) tension
	if not self:InSitPhase() or self:IsTense() then
		return false
	end
	-- (2) MaxDiners of the shift
	const isNight = self:IsNight()
	if self:Diners() + size > Tables.MaxDiners(isNight) then
		return false
	end
	-- (3) headroom in the customer cap (the diners count themselves, Q-180 A)
	if customers:Count() > customers:MaxCustomers() - SEATING.SitHeadroom then
		return false
	end
	-- (1) a bought, clean, free table with the seats of this party, nearest to Q1
	const seats = Tables.Seats(size, party.Couple)
	const states: { State } = {}
	for index, spot in self.Spots do
		states[index] = spot.State
	end
	const seating = self:SeatingGroup()
	const index = Tables.Pick(states, function(candidate: number): boolean
		const spot = self.Spots[candidate]
		return spot.Group.Key == seating and hasSeats(spot, seats)
	end)
	if index == nil then
		return false
	end
	-- chance (FEAT-037), drawn only for an eligible party and only when the build still uses it (Q-209: a free table
	-- seats whoever took the order; a type that never sits, SitChance 0, still never does)
	const row = Content.CustomerTypes.ByKey[party.CustomerType]
	if not self.ForceSit and (row == nil or row.SitChance <= 0) then
		return false
	end
	if SEATING.SitChanceApplies and not self.ForceSit and row ~= nil then
		const bonus = self.Dependencies.UpgradeService:GetEffect("SitBonus")
		const chance = Tables.Chance(row.SitChance, isNight, size > 1, bonus)
		if self.Rng:NextNumber() >= chance then
			return false
		end
	end
	self.ForceSit = false
	self:Reserve(index, party, seats, isNight)
	return true
end

-- Restaurant (TASK-386, SitAt "Served"): offer a table to a party that was just served at the pickup counter, already
-- Leaving + Dining (CustomerService:Leave(leader, mood, reason, true)), plate in hand. Same rules as the Seater's Offer;
-- must not yield. true = a table was reserved, the party is ours until Dismiss. false = no table (or SitAt is "Order"):
-- the caller sends it out carrying the plate.
function SeatingService:OfferServed(party: SeatParty): boolean
	return self:TrySeat(party)
end

function SeatingService:Reserve(index: number, party: SeatParty, seats: { number }, isNight: boolean)
	const spot = self.Spots[index]
	const npc = self.Dependencies.NpcService
	const members: { Member } = { { Id = party.Leader, Seat = seats[1], Rig = npc:GetRig(party.Leader) } }
	if party.Partner ~= nil then
		table.insert(members, { Id = party.Partner, Seat = seats[2], Rig = npc:GetRig(party.Partner) })
	end
	const leaderRig = members[1].Rig
	const record: Party = {
		Leader = party.Leader,
		Members = members,
		Couple = party.Couple,
		Table = index,
		Phase = "Walking",
		StartedAt = now(),
		Until = 0,
		EatTime = Tables.EatTime(isNight, #members > 1, self.Rng),
		Height = if leaderRig then leaderRig.Root.Position.Y else DEFAULT_HEIGHT,
		Token = 1,
		Served = true,
	}
	self.Parties[party.Leader] = record
	for _, member in members do
		self.ByMember[member.Id] = party.Leader
	end
	spot.Party = party.Leader
	self:SetState(spot, "Occupied")
	-- after the caller's Leave (dining) has run: CustomerService no longer walks them
	task.defer(function()
		self:WalkIn(record)
	end)
end

-- Q1 -> table node -> approach -> seat. A failed walk still ends on the seat (snapped), the party is never stuck.
function SeatingService:WalkIn(party: Party)
	const token = party.Token
	local function alive(): boolean
		return self.Parties[party.Leader] == party and party.Token == token and party.Phase == "Walking"
	end
	const spot = self.Spots[party.Table]
	const npc = self.Dependencies.NpcService
	const leader = party.Members[1]
	if spot.Node ~= nil and npc:GetNode(leader.Id) ~= spot.Node then
		npc:WalkTo(leader.Id, spot.Node, { AvoidQueue = true, Face = false })
	end
	if not alive() then
		return
	end
	const seat = spot.Seats[leader.Seat]
	npc:WalkToPosition(leader.Id, Diner.ApproachPoint(seat, party.Height), SEATING.WalkTimeout)
	if not alive() then
		return
	end
	-- the partner stops following and takes its own seat (straight walk, no pathfinding: FEAT-038)
	const partner = party.Members[2]
	if partner ~= nil then
		self.Dependencies.CustomerService:SetHeld(partner.Id, true)
		npc:WalkToPosition(partner.Id, Diner.ApproachPoint(spot.Seats[partner.Seat], party.Height), PARTNER_WALK)
		if not alive() then
			return
		end
	end
	self:SitDown(party)
end

function SeatingService:SitDown(party: Party)
	const spot = self.Spots[party.Table]
	for _, member in party.Members do
		const rig = member.Rig
		const seat = spot.Seats[member.Seat]
		if rig ~= nil and seat ~= nil and rig.Root:IsDescendantOf(workspace) then
			Diner.Sit(rig, seat, party.Table)
		end
	end
	-- it waits for the food (Q-209): the serve_table prompt is on, nothing times it out here (the Order patience clock
	-- is CustomerService's)
	party.Phase = "Seated"
	party.Until = 0
	if party.Served then
		-- SitAt "Served": the plate came with it, the meal starts on the seat (no serve_table wait)
		self:StartMeal(party)
		return
	end
	self:RefreshServe(spot)
	self:Publish(spot)
end

-- The food was served (CustomerService Left(leader, true)): the diners eat for EatTime, then StandUp.
function SeatingService:StartMeal(party: Party)
	if party.Phase ~= "Seated" then
		return
	end
	party.Phase = "Eating"
	party.Until = now() + party.EatTime
	for _, member in party.Members do
		if member.Rig ~= nil then
			Diner.Eat(member.Rig)
		end
	end
	self:RefreshServe(self.Spots[party.Table])
	self:Publish(self.Spots[party.Table])
end

-- CustomerService Left(leader, ate): a customer of ours is leaving. ate = served well: it eats first; else it stands
-- up at once. A party already standing (StandUp started it) is left alone.
function SeatingService:OnCustomerLeft(leader: number, ate: boolean)
	const party = self.Parties[leader]
	if party == nil or party.Phase == "Leaving" then
		return
	end
	if ate and party.Served then
		return -- SitAt "Served": already paid for, it eats once it sits (SitDown)
	end
	if ate and party.Phase == "Seated" then
		self:StartMeal(party)
	else
		self:StandUp(party)
	end
end

-- Up from the table: tray + TableTip per diner on it (Dirty), back to the graph, then CustomerService sends them out.
function SeatingService:StandUp(party: Party)
	if party.Phase == "Leaving" then
		return
	end
	const wasSeated = party.Phase == "Seated" or party.Phase == "Eating"
	const ate = party.Phase == "Eating"
	party.Phase = "Leaving"
	party.Token += 1
	const spot = self.Spots[party.Table]
	const npc = self.Dependencies.NpcService
	-- still waiting for the food (patience, shift end, tension): the customer record goes too (Q-209)
	const customers = self.Dependencies.CustomerService
	const record = customers:Get(party.Leader)
	if record ~= nil and record.State ~= "Leaving" then
		customers:Leave(party.Leader, nil, "service", false)
	end
	for _, member in party.Members do
		const rig = member.Rig
		if rig ~= nil and self.Dependencies.CustomerService:Get(member.Id) ~= nil then
			const seat = spot.Seats[member.Seat]
			Diner.Stand(rig, if wasSeated and seat then Diner.ApproachPoint(seat, party.Height) else nil)
		end
	end
	spot.Party = nil
	if ate then
		-- nobody cleans (TASK-386, DEC-307): the table tip goes straight into the tip jar
		const tip = math.floor(Tables.Tip(0, #party.Members))
		const economy = self.Dependencies.EconomyService
		if tip > 0 and economy:IsDrawerOpen() then
			economy:AddTip(tip)
		end
	end
	self:SetState(spot, "Free")
	self:RefreshServe(spot)
	task.spawn(function()
		const leader = party.Members[1]
		if spot.Node ~= nil and self.Dependencies.CustomerService:Get(leader.Id) ~= nil then
			const ok, node = pcall(MapIndex.Node, spot.Node)
			if ok then
				npc:WalkToPosition(leader.Id, Vector3.new(node.Position.X, party.Height, node.Position.Z), SEATING.WalkTimeout)
				npc:SetNode(leader.Id, spot.Node)
			end
		end
		self:Release(party)
		self.Dependencies.CustomerService:Dismiss(leader.Id)
	end)
end

-- The party is no longer ours (dismissed or gone).
function SeatingService:Release(party: Party)
	if self.Parties[party.Leader] ~= party then
		return
	end
	self.Parties[party.Leader] = nil
	for _, member in party.Members do
		if self.ByMember[member.Id] == party.Leader then
			self.ByMember[member.Id] = nil
		end
	end
	const spot = self.Spots[party.Table]
	if spot.Party == party.Leader then
		spot.Party = nil
		self:SetState(spot, if spot.State == "Occupied" then "Free" else spot.State)
	end
end

-- A diner's record vanished (new shift, despawn): its rig is straightened and the party dropped when empty.
function SeatingService:OnRemoved(id: number)
	const leaderId = self.ByMember[id]
	if leaderId == nil then
		return
	end
	const party = self.Parties[leaderId]
	self.ByMember[id] = nil
	if party == nil then
		return
	end
	for index, member in party.Members do
		if member.Id == id then
			if member.Rig ~= nil then
				Diner.Unpose(member.Rig)
				member.Rig.Root.Anchored = false
			end
			table.remove(party.Members, index)
			break
		end
	end
	if #party.Members == 0 or id == party.Leader then
		party.Token += 1
		const spot = self.Spots[party.Table]
		for _, member in party.Members do
			self.ByMember[member.Id] = nil
			if member.Rig ~= nil then
				Diner.Unpose(member.Rig)
				member.Rig.Root.Anchored = false
			end
		end
		self.Parties[leaderId] = nil
		if spot.Party == leaderId then
			spot.Party = nil
			self:SetState(spot, "Free")
		end
	else
		self:Publish(self.Spots[party.Table])
	end
end

-- Every party up now (tension, phase change).
function SeatingService:StandAll()
	const leaders: { number } = {}
	for leader, party in self.Parties do
		if party.Phase ~= "Leaving" then
			table.insert(leaders, leader)
		end
	end
	table.sort(leaders)
	for _, leader in leaders do
		const party = self.Parties[leader]
		if party ~= nil then
			self:StandUp(party)
		end
	end
end

function SeatingService:Step()
	const t = now()
	if next(self.Parties) == nil then
		return
	end
	if self:IsTense() then
		self:StandAll()
		return
	end
	for _, party in table.clone(self.Parties) do
		if party.Phase == "Eating" and t >= party.Until then
			self:StandUp(party)
		elseif party.Phase == "Seated" then
			self:RefreshServe(self.Spots[party.Table]) -- the pending hot dogs of a pair change after a partial serve
		elseif party.Phase == "Walking" and t - party.StartedAt > SEATING.StandTimeout then
			self:WarnOnce("walk", `party of {party.Leader} never reached TBL-{party.Table}: sent away`)
			self:StandUp(party)
		end
	end
end

-- Actions ---------------------------------------------------------------------------------------------------------

local function indexOf(anchor: Instance): number?
	const value = anchor:GetAttribute(BINDING.IndexAttribute)
	return if typeof(value) == "number" then value else nil
end

-- buy_in_place: the anchor's Upgrade must be sold here; a table must be the next ghost (fixed order, FEAT-037).
-- Cash is not checked here: Buy refuses with not_enough_cash (notice to the buyer).
function SeatingService:CanBuyAt(anchor: Instance): boolean
	if not Content.Mode.DayOnly then
		return false
	end
	const key = anchor:GetAttribute(UPGRADE_ATTRIBUTE)
	if typeof(key) ~= "string" or not SOLD[key] then
		return false
	end
	const group = GROUP_OF_UPGRADE[key]
	if group ~= nil then
		const index = indexOf(anchor)
		const spot = if index then self.Spots[index] else nil
		if
			spot == nil
			or spot.Group ~= group
			or spot.State ~= "Ghost"
			or spot.Price <= 0
			or spot.Index ~= group.First + self:Owned(group)
		then
			return false
		end
	end
	return (self.Dependencies.UpgradeService:CanBuy(key))
end

function SeatingService:BuyAt(player: Player, anchor: Instance)
	const key = anchor:GetAttribute(UPGRADE_ATTRIBUTE)
	if typeof(key) ~= "string" then
		return
	end
	const index = indexOf(anchor)
	const ok = self.Dependencies.UpgradeService:Buy(key, player, true)
	if not ok then
		return
	end
	const group = GROUP_OF_UPGRADE[key]
	if group ~= nil then
		self.Dependencies.RunStateService:Notify("all", ADDED_NOTICE, index or (group.First + self:Owned(group) - 1))
	else
		self.Dependencies.RunStateService:Notify("all", BOUGHT_NOTICE, Content.Upgrades.IndexOf[key])
	end
	self:Refresh()
end

-- serve_table: leader NpcId of the party sitting at the table of this anchor and waiting for its food, else nil.
function SeatingService:ServeLeader(anchor: Instance): number?
	const index = indexOf(anchor)
	const spot = if index then self.Spots[index] else nil
	const party = if spot and spot.Party then self.Parties[spot.Party] else nil
	if spot == nil or party == nil or party.Phase ~= "Seated" or spot.Serve ~= anchor then
		return nil
	end
	return party.Leader
end

function SeatingService:RegisterActions()
	const interaction = self.Dependencies.InteractionService
	-- the verdict, pay, tip and Sale are the counter's (CustomerService:ServeTable)
	interaction:RegisterAction(SERVE, {
		Validate = function(player: Player, anchor: Instance): boolean
			const leader = self:ServeLeader(anchor)
			return leader ~= nil and self.Dependencies.CustomerService:CanServeTable(player, leader)
		end,
		Run = function(player: Player, anchor: Instance)
			const leader = self:ServeLeader(anchor)
			if leader == nil then
				return
			end
			self.Dependencies.CustomerService:ServeTable(player, leader)
			const index = indexOf(anchor)
			const spot = if index then self.Spots[index] else nil
			if spot ~= nil then
				self:RefreshServe(spot)
			end
		end,
	})
	interaction:RegisterAction(BUY, {
		Validate = function(_player: Player, anchor: Instance): boolean
			return self:CanBuyAt(anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self:BuyAt(player, anchor)
		end,
	})
end

-- Shift and phases ------------------------------------------------------------------------------------------------

function SeatingService:Reseed()
	const info = self.Dependencies.RoundService:Info()
	const seed = self.Dependencies.RunStateService.Seed()
	const base = `{seed}|{info.Day}|{if info.IsNight then 1 else 0}|{info.Attempt}|{SEED_DOMAIN}`
	self.Rng = Random.new(hash(base) % SEED_MAX + 1)
end

function SeatingService:OnPhase(phase: string)
	if not self:InSitPhase() and phase ~= CLOSING then
		self:StandAll() -- Summary, night end, 6 AM...: up at once (Closing: they finish eating)
	end
	if not self.Dependencies.EconomyService:IsDrawerOpen() then
		self:ResetTables() -- tables clean, tips on them lost (Q-181 A)
	else
		self:Refresh()
	end
end

-- Dev (/dev seating, TASK-145) --------------------------------------------------------------------------------------

function SeatingService:DevCheck()
	if not self.Dependencies.PlaceService:IsDev() then
		error("[SeatingService] dev only", 3)
	end
end

-- Group by key ("pad" / "trailer", any case); nil = the one that seats now.
function SeatingService:DevGroup(key: string?): Content.SeatingGroup
	const wanted = if key then string.lower(key) else string.lower(self:SeatingGroup())
	for _, group in SEATING.Groups do
		if string.lower(group.Key) == wanted then
			return group
		end
	end
	error(`unknown table group '{wanted}'`, 3)
end

-- Free purchase of the next table of a group (default: the one that seats now). The Trailer group can be bought
-- while the cart is the vehicle (its level lives on the trailer; the tables show once the trailer is bought).
-- Returns the tables of that group owned after it.
function SeatingService:DevBuy(groupKey: string?): number
	self:DevCheck()
	const group = self:DevGroup(groupKey)
	const upgrades = self.Dependencies.UpgradeService
	const vehicle = if self:IsActive(group) then upgrades:GetVehicle() else group.Vehicles[1]
	const nextRow = upgrades:NextLevel(group.UpgradeKey, vehicle)
	if nextRow == nil then
		error(`every {group.Key} table is bought`, 2)
	end
	upgrades:SetLevel(vehicle, group.UpgradeKey, nextRow.Level)
	self:Refresh()
	return self:Owned(group)
end

-- The next customer that takes its order sits whatever its type (the conditions still apply: free table, phase...).
function SeatingService:DevForceSit()
	self:DevCheck()
	self.ForceSit = true
end

function SeatingService:DevList(groupKey: string?): string
	self:DevCheck()
	const only = if groupKey then self:DevGroup(groupKey) else nil
	const parts: { string } = {}
	for _, spot in self.Spots do
		if only ~= nil and spot.Group ~= only then
			continue
		end
		const party = if spot.Party then self.Parties[spot.Party] else nil
		table.insert(
			parts,
			`TBL-{spot.Index} {spot.Group.Key} {spot.State}{if spot.Price > 0 then ` ${spot.Price}` else ""}`
				.. `{if spot.Tip > 0 then ` tip ${spot.Tip}` else ""}`
				.. `{if party then ` {party.Phase} {#party.Members}p` else ""}`
				.. `{if spot.Model == nil then " (no model)" else ""}`
		)
	end
	const bought: { string } = {}
	for _, group in SEATING.Groups do
		table.insert(
			bought,
			`{group.Key} {self:Owned(group)}/{group.Count}{if self:IsActive(group) then "" else " (hidden: not this vehicle)"}`
		)
	end
	const header = `vehicle {self.Dependencies.UpgradeService:GetVehicle()}, seating group {self:SeatingGroup()}`
		.. `, owned {table.concat(bought, ", ")}, diners {self:Diners()}/{Tables.MaxDiners(self:IsNight())}`
		.. `, tense {self:IsTense()}`
	return header .. "\n  " .. table.concat(parts, "\n  ")
end

SeatingService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	if SEATING.SeatedOutsideCap then
		warn("[SeatingService] Seating.SeatedOutsideCap = true is not implemented (Q-180 B): diners stay in the cap")
	end
	if not SEATING.TipLostAtSummary then
		warn("[SeatingService] Seating.TipLostAtSummary = false is not implemented (Q-181 B): tips are lost")
	end
	self:RegisterActions()

	const customers = self.Dependencies.CustomerService
	customers:SetSeater({
		Offer = function(party): boolean
			return self:TrySeat(party)
		end,
		Left = function(leader: number, ate: boolean)
			self:OnCustomerLeft(leader, ate)
		end,
	})
	customers.Removed:Connect(function(id: number)
		self:OnRemoved(id)
	end)
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function()
		self:Reseed()
		self:ResetTables()
	end)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhase(phase)
	end)
	-- any level change: tables bought, Patio Lights prerequisite, vehicle swap (Changed fires for the new vehicle)
	self.Dependencies.UpgradeService.Changed:Connect(function()
		self:Refresh()
	end)
end)

SeatingService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- Lync is started (NetService OnStart, 1000) and the map is loaded (StreamingEnabled off, T57)
	self.Live = true
	const models = self:FindModels()
	for index = 1, SEATING.Tables do
		const spot = self:BuildSpot(index, models[index])
		self.Spots[index] = spot
		if spot.Model ~= nil and (spot.Seats[1] == nil or spot.Buy == nil) then
			self:WarnOnce(`spot:{index}`, `TBL-{index}: no Seat1 or no prompt anchor (nobody sits there)`)
		end
	end
	self:FindPlaceAnchors()
	self:Reseed()
	-- every table starts Locked (hidden, no collision); Refresh below writes what each group says
	for _, spot in self.Spots do
		spot.State = "Locked"
		self:ApplyCollision(spot)
		self:Publish(spot, true)
	end
	self:Refresh()
	for _, spot in self.Spots do
		self:ApplyPrompts(spot)
	end
end)

SeatingService:OnTick(function(self)
	if self.Enabled and self.Live then
		self:Step()
	end
end, TICK_RATE)

return SeatingService
