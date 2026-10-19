--!strict
-- Restaurant restock by boxes (FEAT-050; design/restaurant-flow.md; DEC-276; TASK-388). Run place only, and only with
-- Content.Restaurant.Supply.Enabled AND Content.Restaurant.Rules.Enabled: with either off nothing is bound and no action
-- is registered (the published game is untouched).
--
-- Infinite stock room (owner 2026-10-17, Provisional): there is no phone order, no van, no hatch and no cost. Every
-- product bay (Shelves.luau: tag StockShelf, attribute Package) always gives one box of its package with take_box (anchor
-- Prompt_TakeBox, text "Take <Package name>"): no counter, it never runs out. The box is the package Tool
-- (ItemService:Give, Count = Package.Amount): hotbar and package limit (2, bear 3) are ItemService's (package_limit).
-- The limit lives in the stations (Stock / Capacity): Restock at the station is the existing KitchenService one (partial
-- transfer, the rest stays in the box, empty box goes away), so the crew keeps walking to the stock room to refill.
--
-- A bay of a package that is not on sale (KitchenService:IsBlocked of its ingredient) has its prompt off and refuses
-- take_box. The PHONE-R phone keeps only the boss calls (answer_phone, BossService); nothing here binds it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Shelves = require(script.Shelves)
local Modux = require(ServerScriptService.server.Modux)

const TAKE = "take_box"
const ANCHOR_TAG = "Interactable"
-- take_box packets of one player closer than this are refused (cadence; the prompt is a tap). PROVISIONAL constant
const TAKE_GAP = 0.3

local function packageName(key: string): string
	const row = Content.Packages.ByKey[key]
	return if row then row.Name else key
end

const SupplyService = Modux.Service("SupplyService", {
	Require = {
		"PlaceService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"ItemService",
		"KitchenService",
	},
	Priority = 612,
})

function SupplyService:Setup()
	self.Enabled = false :: boolean
	self.Shelves = Shelves.new() :: Shelves.State
	self.LastTake = {} :: { [Player]: number }
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

function SupplyService:CanAct(player: Player): boolean
	return self.Dependencies.RoundService:IsStarted() and self.Dependencies.RunStateService:IsActive(player)
end

-- Prompts -------------------------------------------------------------------------------------------------------------

function SupplyService:RefreshPrompts()
	const interaction = self.Dependencies.InteractionService
	for _, shelf in self.Shelves.List do
		interaction:SetPrompt(shelf.Anchor, self:IsOpen(shelf.Package), `Take {packageName(shelf.Package)}`)
	end
end

-- Boxes -----------------------------------------------------------------------------------------------------------------

-- Package of a bay anchor that can give a box now, nil = not a bay or not on sale
function SupplyService:BoxAt(anchor: Instance): string?
	const shelf = self.Shelves.ByAnchor[anchor]
	if shelf == nil or not self:IsOpen(shelf.Package) then
		return nil
	end
	return shelf.Package
end

-- Gives one box of the bay to the player. true = the Tool landed (the bay never runs out)
function SupplyService:Take(player: Player, anchor: Instance): boolean
	const package = self:BoxAt(anchor)
	if package == nil then
		return false
	end
	const row = Content.Packages.ByKey[package]
	-- package_limit / hands_full already sent by Give
	return self.Dependencies.ItemService:Give(player, row.Item, { Count = row.Amount }) ~= nil
end

function SupplyService:ValidateTake(player: Player, anchor: Instance): boolean
	if not self:CanAct(player) or self:BoxAt(anchor) == nil then
		return false
	end
	const last = self.LastTake[player]
	return last == nil or os.clock() - last >= TAKE_GAP
end

-- Binding ---------------------------------------------------------------------------------------------------------------

function SupplyService:BindAnchor(anchor: Instance, action: string)
	-- Attributes before the tag: InteractionService reads them when the anchor is tagged
	anchor:SetAttribute("PromptAction", action)
	anchor:SetAttribute("PromptEnabled", false)
	if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end
end

function SupplyService:Bind()
	Shelves.bind(self.Shelves, Content.Packages.ByKey)
	for _, shelf in self.Shelves.List do
		self:BindAnchor(shelf.Anchor, TAKE)
	end
	if #self.Shelves.List == 0 then
		warn(`[SupplyService] supply on but no {Shelves.Tag} bay in the map: boxes cannot be taken`)
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
	const lines: { string } = { `supply: infinite stock room, {#self.Shelves.List} bay(s)` }
	for _, shelf in self.Shelves.List do
		const open = if self:IsOpen(shelf.Package) then "open" else "blocked"
		table.insert(lines, `  bay {shelf.Id} {shelf.Root.Name} [{shelf.Package}]: {open}`)
	end
	table.insert(lines, `  on sale: {table.concat(self:OpenPackages(), ", ")}`)
	return table.concat(lines, "\n")
end

-- Takes a box of `package` for `player` as the prompt would (no range check), from its first bay
function SupplyService:DevTake(player: Player, package: string): string
	self:DevCheck()
	for _, shelf in self.Shelves.List do
		if shelf.Package == package then
			return if self:Take(player, shelf.Anchor) then "box in hand" else "refused (limit, hotbar or not on sale)"
		end
	end
	return `no bay for {package}`
end

SupplyService:OnInit(function(self)
	self:Setup()
	if
		not self.Dependencies.PlaceService:Is("Run")
		or not Content.Restaurant.Supply.Enabled
	then
		return
	end
	self.Enabled = true

	-- Priority 612 < 730: InteractionService already built its handler table
	self.Dependencies.InteractionService:RegisterAction(TAKE, {
		Validate = function(player: Player, anchor: Instance): boolean
			return self:ValidateTake(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance)
			self.LastTake[player] = os.clock()
			self:Take(player, anchor)
		end,
	})
	Players.PlayerRemoving:Connect(function(player: Player)
		self.LastTake[player] = nil
	end)
end)

SupplyService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57); InteractionService (730) watches the anchors tagged here
	self:Bind()
	self:RefreshPrompts()
	-- day / vehicle change opens packages: the bay prompts follow
	self.Dependencies.RoundService.PhaseChanged:Connect(function()
		self:RefreshPrompts()
	end)
end)

return SupplyService
