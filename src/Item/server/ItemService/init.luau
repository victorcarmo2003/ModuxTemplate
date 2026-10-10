--!strict
-- Hotbar Tools (FEAT-005, FEAT-007; DEC-040, DEC-049, DEC-174, DEC-190; architecture.md §3.1, §18.9.5;
-- network.md §7, §7.1; TASK-022). Run place only.
-- Single writer of the Tool attributes Item, Count, Toppings, Restore and Altered. Tools are cloned from the kit
-- ReplicatedStorage.Assets.Items.Tools/<Content.Items key> and replicate through the native Backpack (no Lync).
-- Limits come from Content.ItemRules: HotbarSlots total Tools (4) and CategoryLimits per category; the package limit
-- goes through ClassService (PackageLimit, bear = 3). Only Tools created here count and are trusted: anything else in
-- a Backpack is ignored by every read below.
-- Wave 2 (TASK-066; architecture.md §19.12, §19.8, §19.5, T50, T51; FEAT-021, FEAT-025, FEAT-036; DEC-103, DEC-197):
--   * Stash/Unstash: Tools -> RunStateService:SetStash on leave (Away), Down (VitalService calls Stash), death and
--     character removal; recreated the same (Count, Toppings, Restore) when the member is Active with a live crew rig.
--   * Snapshot "T" (data.md §5.3): Tools of every member (in play + stash); restore puts them back in the stash and
--     recreates them for whoever is Active and spawned. Items on the ground never enter it (cleared on restore).
--   * RegisterUse (Uses.luau): Tool.Activated only on Tools created here.
--   * give_coffee: hold on a mate's Prompt_Give (CharacterService anchor) moves the held coffee Tool to the mate.
--   * DropHeld / DropStash (Drops.luau): item on the ground, splat, spectator items on the counter (DROP-T).
--   * Free package of the vehicle-bound ingredient (coffee) on the cart -> trailer swap (L2-07, Pickup.swap).
-- The hot dog visual is HotDogVisual (TASK-023), refreshed on the server every time Toppings is written (replicates).
-- It does not cap the count: MaxToppings (DEC-071) is enforced here.
-- Wave 3 (TASK-109; ITM-020; architecture.md §19.12, §19.13; network.md §7.1): GiveOptions.Altered marks a hot dog
--   made with an altered item (Tool attribute Altered = true; KitchenService passes it). Stash and snapshot "T" keep it
--   (Stash.luau). When the phase leaves Night (6:00 AM NightEnd, NightLost, any later phase) every altered hot dog
--   is gone: in play and in the stashes (ClearAltered).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Drops = require(script.Drops)
local Pickup = require(script.Pickup)
local Stash = require(script.Stash)
local Uses = require(script.Uses)
local Modux = require(ServerScriptService.server.Modux)

-- Options of Give. Count: stackable items only (default = Packages[key].Amount for a package, 1 otherwise).
-- Toppings: hot dog only, attribute format "ketchup,cheese" (network.md §7.1). Equip: put it in the hand (default
-- true). Silent: no "Hands full"/"package_limit" notice on refusal (default false). Restore: coffee only, sanity the
-- cup restores (CoffeeRestore of who brewed, architecture.md §19.8), Tool attribute "Restore". Altered: hot dog only,
-- made with an altered item (ITM-020), Tool attribute "Altered" = true.
export type GiveOptions = {
	Count: number?,
	Toppings: string?,
	Equip: boolean?,
	Silent: boolean?,
	Restore: number?,
	Altered: boolean?,
}

export type UseHandler = Uses.Handler

const HOT_DOG = "hot_dog"
const COFFEE = "coffee"
const GIVE_COFFEE = "give_coffee"
const RESTORE = "Restore"
const ALTERED = "Altered"
const ALTER_PHASE = "Night" -- altered items exist only in this phase (ITM-020; same rule as KitchenService)
const MAX_RESTORE = 200
const PACKAGE = "Package"
const MAX_COUNT = 1000000

local function packageAmount(key: string): number?
	for _, row in Content.Packages.List do
		if row.Item == key then
			return row.Amount
		end
	end
	return nil
end

local function splitToppings(raw: string): { string }
	const out: { string } = {}
	if raw == "" then
		return out
	end
	for _, part in string.split(raw, ",") do
		table.insert(out, part)
	end
	return out
end

-- Keeps only known topping keys, no repeats, at most MaxToppings, assembly order preserved.
local function cleanToppings(list: { string }): { string }
	const out: { string } = {}
	for _, key in list do
		if #out >= Content.OrderRules.MaxToppings then
			break
		end
		if table.find(Content.Ingredients.ToppingKeys, key) and not table.find(out, key) then
			table.insert(out, key)
		end
	end
	return out
end

const ItemService = Modux.Service("ItemService", {
	Require = {
		"PlaceService",
		"PlayerService",
		"RunStateService",
		"ClassService",
		"InteractionService",
		"RoundService",
		"UpgradeService",
		"VehicleService",
	},
	Priority = 720,
})

function ItemService:Setup()
	self.Owners = {} :: { [Tool]: Player }
	self.ByPlayer = {} :: { [Player]: { [Tool]: boolean } }
	self.Links = {} :: { [Tool]: { RBXScriptConnection } }
	-- Hotbar of a player changed (Give, Consume, Count, Toppings, Tool lost). CharacterService reads the package
	-- count here for the bear's walk speed (Classes, PackagesAtLeast).
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<Player>
	-- Free package of the unlock day (TASK-046), wired in OnInit.
	self.Pickup = Pickup.new({
		Template = function(key: string): Tool?
			return self:Template(key)
		end,
		Give = function(player: Player, key: string): Tool?
			return self:Give(player, key)
		end,
		IsActive = function(player: Player): boolean
			return self.Dependencies.RunStateService:IsActive(player)
		end,
		SetPrompt = function(anchor: Instance, enabled: boolean)
			self.Dependencies.InteractionService:SetPrompt(anchor, enabled)
		end,
	}) :: Pickup.Pickup
	-- Items on the ground (TASK-066, FEAT-036).
	self.Drops = Drops.new({
		Template = function(key: string): Tool?
			return self:Template(key)
		end,
		Display = Pickup.display,
		Give = function(player: Player, key: string, count: number, toppings: string?): Tool?
			return self:Give(player, key, { Count = count, Toppings = toppings })
		end,
		IsActive = function(player: Player): boolean
			return self.Dependencies.RunStateService:IsActive(player)
		end,
		SetPrompt = function(anchor: Instance, enabled: boolean)
			self.Dependencies.InteractionService:SetPrompt(anchor, enabled)
		end,
		SetPromptHold = function(anchor: Instance, hold: number)
			self.Dependencies.InteractionService:SetPromptHold(anchor, hold)
		end,
	}) :: Drops.Drops
	-- Active items (T51): handlers registered by their owners through RegisterUse.
	self.Uses = Uses.new({
		IsHeld = function(player: Player, tool: Tool): boolean
			return self:GetHeld(player) == tool
		end,
		IsActive = function(player: Player): boolean
			return self.Dependencies.RunStateService:IsActive(player)
		end,
		Notify = function(player: Player, key: string)
			self.Dependencies.RunStateService:Notify(player, key)
		end,
	}) :: Uses.Uses
	-- Shifts started so far; counter drops (DROP-T) last until the end of the next one.
	self.ShiftIndex = 0 :: number
end

-- Kit ----------------------------------------------------------------------------------------------------------------

function ItemService:Template(key: string): Tool?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = assets and assets:FindFirstChild("Items")
	const tools = items and items:FindFirstChild("Tools")
	const tool = tools and tools:FindFirstChild(key)
	if tool == nil or not tool:IsA("Tool") then
		return nil
	end
	return tool
end

-- Missing kit Tools are reported once at boot (altered_item is wave 3 and not in the kit, build_items.luau).
function ItemService:CheckKit()
	const missing: { string } = {}
	for _, item in Content.Items.List do
		if item.Kind ~= "Anomaly" and self:Template(item.Key) == nil then
			table.insert(missing, item.Key)
		end
	end
	if #missing > 0 then
		warn(`[ItemService] Assets.Items.Tools is missing: {table.concat(missing, ", ")} (TASK-007 kit)`)
	end
end

-- Ownership ----------------------------------------------------------------------------------------------------------

-- A Tool is in play while it sits in the owner's Backpack or in the owner's current character.
function ItemService:InPlay(tool: Tool, player: Player): boolean
	const parent = tool.Parent
	if parent == nil then
		return false
	end
	if parent:IsA("Backpack") then
		return parent.Parent == player
	end
	return parent == player.Character and parent:IsDescendantOf(workspace)
end

function ItemService:Forget(tool: Tool)
	const player = self.Owners[tool]
	if player == nil then
		return
	end
	self.Owners[tool] = nil
	const links = self.Links[tool]
	if links then
		for _, link in links do
			link:Disconnect()
		end
		self.Links[tool] = nil
	end
	const owned = self.ByPlayer[player]
	if owned then
		owned[tool] = nil
	end
	if tool.Parent ~= nil then
		-- Deferred: destroying inside AncestryChanged would fight the reparent in progress.
		task.defer(function()
			tool:Destroy()
		end)
	end
	if player.Parent ~= nil then
		self.Changed:Fire(player)
	end
end

function ItemService:Track(player: Player, tool: Tool)
	self.Owners[tool] = player
	local owned = self.ByPlayer[player]
	if owned == nil then
		owned = {}
		self.ByPlayer[player] = owned
	end
	owned[tool] = true
	const links = {
		tool.AncestryChanged:Connect(function()
			const owner = self.Owners[tool]
			if owner ~= nil and not self:InPlay(tool, owner) then
				self:Forget(tool)
			end
		end),
		tool.Destroying:Connect(function()
			self:Forget(tool)
		end),
	}
	-- Active item (T51): only Tools created here are listened to.
	const key = tool:GetAttribute("Item")
	const item = if type(key) == "string" then Content.Items.ByKey[key] else nil
	if item ~= nil and item.Use then
		table.insert(
			links,
			tool.Activated:Connect(function()
				const owner = self.Owners[tool]
				if owner ~= nil then
					Uses.activate(self.Uses, owner, tool, item.Key)
				end
			end)
		)
	end
	self.Links[tool] = links
end

-- Stops tracking a Tool without destroying it (give_coffee moves it to another player).
function ItemService:Untrack(tool: Tool)
	const player = self.Owners[tool]
	if player == nil then
		return
	end
	self.Owners[tool] = nil
	const links = self.Links[tool]
	if links then
		for _, link in links do
			link:Disconnect()
		end
		self.Links[tool] = nil
	end
	const owned = self.ByPlayer[player]
	if owned then
		owned[tool] = nil
	end
end

function ItemService:Release(player: Player)
	const owned = self.ByPlayer[player]
	self.ByPlayer[player] = nil
	if owned == nil then
		return
	end
	for tool in owned do
		self:Forget(tool)
	end
end

-- Reads --------------------------------------------------------------------------------------------------------------

-- Content.Items key of a Tool created here (nil for anything else).
function ItemService:ItemOf(tool: Tool): string?
	if self.Owners[tool] == nil then
		return nil
	end
	const key = tool:GetAttribute("Item")
	return if type(key) == "string" then key else nil
end

-- Every Tool of the player in play (Backpack + hand), in no particular order.
function ItemService:Tools(player: Player): { Tool }
	const out: { Tool } = {}
	const owned = self.ByPlayer[player]
	if owned == nil then
		return out
	end
	for tool in owned do
		if self:InPlay(tool, player) then
			table.insert(out, tool)
		end
	end
	return out
end

-- Tool equipped by the player, if it was created here.
function ItemService:GetHeld(player: Player): Tool?
	const character = player.Character
	if character == nil then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and self.Owners[child] == player then
			return child
		end
	end
	return nil
end

-- Held Tool matching Actions.Requires.Held: an Items key or an ItemRules category ("Package").
function ItemService:Holding(player: Player, spec: string): Tool?
	const tool = self:GetHeld(player)
	if tool == nil then
		return nil
	end
	const key = self:ItemOf(tool)
	const item = key and Content.Items.ByKey[key]
	if item == nil then
		return nil
	end
	if item.Key == spec or item.Category == spec then
		return tool
	end
	return nil
end

-- Hot dog made with an altered item (ITM-020).
function ItemService:IsAltered(tool: Tool): boolean
	return self:ItemOf(tool) == HOT_DOG and tool:GetAttribute(ALTERED) == true
end

-- Units left in a stackable Tool (package leftover, DEC-049). 0 for anything else.
function ItemService:Count(tool: Tool): number
	if self.Owners[tool] == nil then
		return 0
	end
	const count = tool:GetAttribute("Count")
	return if type(count) == "number" then count else 0
end

-- Toppings of a hot dog in assembly order.
function ItemService:Toppings(tool: Tool): { string }
	if self:ItemOf(tool) ~= HOT_DOG then
		return {}
	end
	const raw = tool:GetAttribute("Toppings")
	return splitToppings(if type(raw) == "string" then raw else "")
end

function ItemService:CountCategory(player: Player, category: string): number
	local count = 0
	for _, tool in self:Tools(player) do
		const key = self:ItemOf(tool)
		const item = key and Content.Items.ByKey[key]
		if item and item.Category == category then
			count += 1
		end
	end
	return count
end

function ItemService:PackageCount(player: Player): number
	return self:CountCategory(player, PACKAGE)
end

-- Max packages for the player's class (2, bear 3; DEC-049, DEC-069), always inside HotbarSlots.
function ItemService:PackageLimit(player: Player): number
	return self.Dependencies.ClassService:GetModifier(player, "PackageLimit")
end

function ItemService:CategoryLimit(player: Player, category: string): number
	if category == PACKAGE then
		return self:PackageLimit(player)
	end
	return (Content.ItemRules.CategoryLimits :: { [string]: number })[category] or 0
end

-- Fits in the hotbar and in the category limit? On refusal: the Notice key and its Value (TASK-046 uses this before
-- taking the free package). Unknown item = refused with no notice.
function ItemService:CanGive(player: Player, key: string): (boolean, string?, number?)
	const item = Content.Items.ByKey[key]
	if item == nil or player.Parent == nil then
		return false, nil, nil
	end
	if #self:Tools(player) >= Content.ItemRules.HotbarSlots then
		return false, "hands_full", nil
	end
	const limit = self:CategoryLimit(player, item.Category)
	if self:CountCategory(player, item.Category) >= limit then
		if item.Category == PACKAGE then
			return false, "package_limit", limit
		end
		return false, "hands_full", nil
	end
	return true, nil, nil
end

-- Writes ------------------------------------------------------------------------------------------------------------

function ItemService:Paint(tool: Tool)
	const ok, err = pcall(function()
		HotDogVisual.refresh(tool)
	end)
	if not ok then
		warn(`[ItemService] HotDogVisual.refresh failed: {err}`)
	end
end

-- Creates the Tool for `key` and puts it in the player's hand. Synchronous (no yield between the check and the
-- write), so two callers in the same frame can never pass the limit. Refused = nil (+ Notice unless Silent).
function ItemService:Give(player: Player, key: string, options: GiveOptions?): Tool?
	const ok, notice, value = self:CanGive(player, key)
	if not ok then
		if notice and not (options and options.Silent) then
			self.Dependencies.RunStateService:Notify(player, notice, value)
		end
		return nil
	end
	const item = Content.Items.ByKey[key]
	const template = self:Template(key)
	if template == nil then
		warn(`[ItemService] no kit Tool for "{key}" (Assets.Items.Tools)`)
		return nil
	end
	const backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return nil
	end

	const tool = template:Clone()
	tool.Name = item.Name
	tool.CanBeDropped = false
	tool:SetAttribute("Item", key)
	if item.Stackable then
		const count = math.floor((options and options.Count) or packageAmount(key) or 1)
		tool:SetAttribute("Count", math.clamp(count, 1, MAX_COUNT))
	else
		tool:SetAttribute("Count", nil)
	end
	if key == HOT_DOG then
		const raw = options and options.Toppings or ""
		tool:SetAttribute("Toppings", table.concat(cleanToppings(splitToppings(raw)), ","))
	else
		tool:SetAttribute("Toppings", nil)
	end
	const restore = options and options.Restore
	if key == COFFEE and type(restore) == "number" and restore == restore then
		tool:SetAttribute(RESTORE, math.clamp(math.floor(restore), 0, MAX_RESTORE))
	else
		tool:SetAttribute(RESTORE, nil)
	end
	tool:SetAttribute(ALTERED, if key == HOT_DOG and options and options.Altered == true then true else nil)

	tool.Parent = backpack
	self:Track(player, tool)
	if key == HOT_DOG then
		self:Paint(tool)
	end

	if options == nil or options.Equip ~= false then
		const character = player.Character
		const humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(tool)
		end
	end
	self.Changed:Fire(player)
	return tool
end

-- Removes a Tool of this player (served hot dog, empty package, Throw Away).
function ItemService:Consume(player: Player, tool: Tool)
	if self.Owners[tool] ~= player then
		return
	end
	self:Forget(tool)
end

-- Sets the leftover of a stackable Tool; 0 or less consumes it ("pacote vazio some", FEAT-007). Returns the count.
function ItemService:SetCount(tool: Tool, count: number): number
	const player = self.Owners[tool]
	const key = self:ItemOf(tool)
	const item = key and Content.Items.ByKey[key]
	if player == nil or item == nil or not item.Stackable then
		return 0
	end
	const value = math.min(math.floor(count), MAX_COUNT)
	if value <= 0 then
		self:Consume(player, tool)
		return 0
	end
	tool:SetAttribute("Count", value)
	self.Changed:Fire(player)
	return value
end

-- Adds one topping to a hot dog. Refuses unknown topping, repeats and more than OrderRules.MaxToppings (DEC-071).
-- Stock is the caller's job (KitchenService takes it before or after, in the same serialized Run).
function ItemService:AddTopping(tool: Tool, ingredient: string): boolean
	const player = self.Owners[tool]
	if player == nil or self:ItemOf(tool) ~= HOT_DOG then
		return false
	end
	if not table.find(Content.Ingredients.ToppingKeys, ingredient) then
		return false
	end
	const toppings = self:Toppings(tool)
	if table.find(toppings, ingredient) or #toppings >= Content.OrderRules.MaxToppings then
		return false
	end
	table.insert(toppings, ingredient)
	tool:SetAttribute("Toppings", table.concat(toppings, ","))
	self:Paint(tool)
	self.Changed:Fire(player)
	return true
end

-- give_coffee (FEAT-021, architecture.md §19.8) ------------------------------------------------------------------

-- Moves a Tool to another player's Backpack keeping every attribute (Count, Restore). False when it cannot.
function ItemService:Transfer(tool: Tool, target: Player): boolean
	const from = self.Owners[tool]
	const backpack = target:FindFirstChildOfClass("Backpack")
	if from == nil or backpack == nil then
		return false
	end
	self:Untrack(tool)
	tool.Parent = backpack
	self:Track(target, tool)
	if from.Parent ~= nil then
		self.Changed:Fire(from)
	end
	self.Changed:Fire(target)
	return true
end

-- Player whose character holds the anchor (Prompt_Give on the HRP of each member, CharacterService).
function ItemService:TargetOf(anchor: Instance): Player?
	local node = anchor.Parent
	while node ~= nil and node ~= workspace do
		if node:IsA("Model") then
			const player = Players:GetPlayerFromCharacter(node)
			if player ~= nil then
				return player
			end
		end
		node = node.Parent
	end
	return nil
end

-- Giver holds a coffee, mate is another Active member with room for it (CategoryLimits.Coffee = 1). Phase rule from
-- Content.Actions.give_coffee.Night. Refusals with a reason the giver can act on send the toast.
function ItemService:CanGiveCoffee(player: Player, anchor: Instance): boolean
	const row = Content.Actions.ByKey[GIVE_COFFEE]
	const round = self.Dependencies.RoundService
	if row.Night == "NightOnly" and not round:IsNight() then
		return false
	elseif row.Night == "DayOnly" and round:IsNight() then
		return false
	end
	const target = self:TargetOf(anchor)
	if target == nil or target == player or not self.Dependencies.RunStateService:IsActive(target) then
		return false
	end
	const character = target.Character
	const humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if self:Holding(player, COFFEE) == nil then
		return false
	end
	const category = Content.Items.ByKey[COFFEE].Category
	if self:CountCategory(target, category) >= self:CategoryLimit(target, category) then
		self.Dependencies.RunStateService:Notify(player, "coffee_has_one")
		return false
	end
	const ok = self:CanGive(target, COFFEE)
	if not ok then
		self.Dependencies.RunStateService:Notify(player, "hands_full")
		return false
	end
	return true
end

function ItemService:GiveCoffee(player: Player, anchor: Instance)
	const tool = self:Holding(player, COFFEE)
	const target = self:TargetOf(anchor)
	if tool ~= nil and target ~= nil then
		self:Transfer(tool, target)
	end
end

-- Uses (T51) ---------------------------------------------------------------------------------------------------------

-- Owner of an active item registers its use in its OnInit (VitalService "coffee"; ReviveService "revive_kit").
function ItemService:RegisterUse(item: string, handler: UseHandler)
	Uses.register(self.Uses, item, handler)
end

-- Stash (T50) --------------------------------------------------------------------------------------------------------

-- Entries of the Tools the player has in play (Backpack + hand).
function ItemService:EntriesOf(player: Player): { Stash.Entry }
	const out: { Stash.Entry } = {}
	for _, tool in self:Tools(player) do
		const key = self:ItemOf(tool)
		const entry = key
			and Stash.entry(
				key,
				tool:GetAttribute("Count"),
				tool:GetAttribute("Toppings"),
				tool:GetAttribute(RESTORE),
				tool:GetAttribute(ALTERED)
			)
		if entry then
			table.insert(out, entry)
		end
	end
	return out
end

-- Tools in play -> member stash (appended to what is already stashed), then destroyed. Leave (Away), Down
-- (VitalService), death and character removal. True when nothing was lost.
function ItemService:Stash(player: Player): boolean
	const runState = self.Dependencies.RunStateService
	const member = runState:GetMember(player)
	if member == nil then
		return false
	end
	const tools = self:Tools(player)
	if #tools == 0 then
		return true
	end
	if not runState:SetStash(player.UserId, Stash.merge(member.Stash, self:EntriesOf(player))) then
		return false
	end
	for _, tool in tools do
		self:Forget(tool)
	end
	return true
end

-- Live crew character (Tools given before the crew rig spawns would die with the Backpack reset of LoadCharacter).
function ItemService:CanHold(player: Player): boolean
	const character = player.Character
	if character == nil or not character:IsDescendantOf(workspace) or not CollectionService:HasTag(character, CrewRig.Tag) then
		return false
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Stash -> Tools again (same Count, Toppings, Restore, Altered), only for an Active member with a live crew character.
-- Entries that no longer fit stay in the stash. Revive (wave 4) calls this too.
function ItemService:Unstash(player: Player): boolean
	const runState = self.Dependencies.RunStateService
	const member = runState:GetMember(player)
	if member == nil or member.State ~= "Active" or not self:CanHold(player) then
		return false
	end
	if #member.Stash == 0 then
		return true
	end
	const left: { Stash.Entry } = {}
	for _, entry in member.Stash do
		const rebuild = Stash.rebuild(entry)
		const tool = self:Give(player, entry.Kind, {
			Count = rebuild.Count,
			Toppings = rebuild.Toppings,
			Restore = rebuild.Restore,
			Altered = rebuild.Altered,
			Equip = false,
			Silent = true,
		})
		if tool == nil then
			table.insert(left, { Kind = entry.Kind, Count = entry.Count, Extra = entry.Extra })
		end
	end
	runState:SetStash(player.UserId, left)
	return #left == 0
end

-- Snapshot "T" (data.md §5.3): every member, Tools in play + stash.
function ItemService:CaptureTools(): { [string]: any }
	const out: { [string]: any } = {}
	for userId, member in self.Dependencies.RunStateService.Members() do
		const player = Players:GetPlayerByUserId(userId)
		const entries = if player then Stash.merge(member.Stash, self:EntriesOf(player)) else member.Stash
		out[tostring(userId)] = Stash.encode(entries)
	end
	return out
end

-- Restore after "M" (RunState 760 registers first): current Tools discarded, saved ones go to the stash and come
-- back now for whoever is Active and spawned (later spawns pick them up in OnCharacter). Ground items vanish.
function ItemService:RestoreTools(data: { [string]: any })
	Drops.clear(self.Drops)
	const runState = self.Dependencies.RunStateService
	for userId in runState.Members() do
		const player = Players:GetPlayerByUserId(userId)
		if player then
			self:Release(player)
		end
		runState:SetStash(userId, Stash.decode(data[tostring(userId)]))
		if player then
			self:Unstash(player)
		end
	end
end

-- Character life: Tools are stashed before the old character (and its Backpack) goes away, and come back on the
-- next crew character.
function ItemService:OnCharacter(player: Player, character: Model)
	if not CollectionService:HasTag(character, CrewRig.Tag) then
		return
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.Died:Once(function()
			self:Stash(player)
		end)
	end
	task.defer(function()
		if player.Character == character then
			self:Unstash(player)
		end
	end)
end

-- Altered items (wave 3, TASK-109) -----------------------------------------------------------------------------------

-- Removes every altered hot dog: Tools in play of every player and stash entries of every member. Returns how many.
function ItemService:ClearAltered(): number
	local removed = 0
	for player, owned in self.ByPlayer do
		const doomed: { Tool } = {}
		for tool in owned do
			if self:IsAltered(tool) then
				table.insert(doomed, tool)
			end
		end
		for _, tool in doomed do
			self:Consume(player, tool)
			removed += 1
		end
	end
	const runState = self.Dependencies.RunStateService
	for userId, member in runState.Members() do
		const kept: { Stash.Entry } = {}
		for _, entry in member.Stash do
			if not Stash.isAltered(entry) then
				table.insert(kept, entry)
			end
		end
		if #kept < #member.Stash then
			removed += #member.Stash - #kept
			runState:SetStash(userId, kept)
		end
	end
	return removed
end

-- Items on the ground (FEAT-036) -------------------------------------------------------------------------------------

-- Held Tool falls (car hit, DEC-103: only the equipped one). By Items[k].DropOnHit: Keep -> item on the ground
-- (sidewalk if it lands on the road), Lost -> splat, Vanish -> gone. False when nothing was held.
function ItemService:DropHeld(player: Player, _reason: string): boolean
	const tool = self:GetHeld(player)
	const key = tool and self:ItemOf(tool)
	const item = key and Content.Items.ByKey[key]
	if tool == nil or item == nil then
		return false
	end
	const character = player.Character
	const root = character and character:FindFirstChild("HumanoidRootPart")
	const handle = tool:FindFirstChild("Handle")
	local position: Vector3? = nil
	if root and root:IsA("BasePart") then
		position = root.Position
	elseif handle and handle:IsA("BasePart") then
		position = handle.Position
	end
	const count = math.max(1, self:Count(tool))
	const toppings = tool:GetAttribute("Toppings")
	self:Consume(player, tool)
	if position == nil or item.DropOnHit == "Vanish" then
		return true
	end

	const ignore: { Instance } = if character then { character } else {}
	if item.DropOnHit == "Keep" then
		const ground = Drops.ground(self.Drops, Drops.sidewalk(position), ignore)
		Drops.keep(self.Drops, item.Key, count, if type(toppings) == "string" then toppings else nil, ground, nil)
	else
		Drops.lost(self.Drops, item.Key, Drops.ground(self.Drops, position, ignore))
	end
	self.Dependencies.RunStateService:Notify(player, "item_dropped", Content.Items.IndexOf[item.Key])
	return true
end

-- Permanent spectator (FEAT-025, VitalService at 6 AM): Tools in play are stashed, then the stash empties. Keep items
-- (packages with their count, Rescue Whistle) go on the counter at `pointId` until the end of the next shift; the
-- rest (Hot Dog, Coffee, altered item) is gone. KeepOnSpectate items stay in the stash.
function ItemService:DropStash(userId: number, pointId: string)
	const player = Players:GetPlayerByUserId(userId)
	if player then
		self:Stash(player)
	end
	const runState = self.Dependencies.RunStateService
	const member = runState.Members()[userId]
	if member == nil then
		return
	end
	const kept: { Stash.Entry } = {}
	const drop: { Stash.Entry } = {}
	for _, entry in member.Stash do
		const item = Content.Items.ByKey[entry.Kind]
		if item == nil then
			continue
		end
		if item.KeepOnSpectate then
			table.insert(kept, entry)
		elseif item.DropOnHit == "Keep" then
			table.insert(drop, entry)
		end
	end
	runState:SetStash(userId, kept)

	const point = MapIndex.FindPoint(pointId)
	if point == nil then
		if #drop > 0 then
			warn(`[ItemService] DropStash: MapPoint {pointId} not found, {#drop} item(s) lost`)
		end
		return
	end
	for index, entry in drop do
		const spot = Drops.spread(point, index, #drop)
		Drops.keep(self.Drops, entry.Kind, entry.Count, entry.Extra, Drops.ground(self.Drops, spot, {}), self.ShiftIndex + 1)
	end
end

-- Free package (TASK-046) and vehicle swap ---------------------------------------------------------------------------

-- Vehicle in use (architecture.md §19.2, §19.5; TASK-056).
function ItemService:CurrentVehicle(): string
	return self.Dependencies.VehicleService:Current()
end

-- Swap reaction (L2-07, architecture.md §19.5): free package of the ingredient bound to the new vehicle (coffee).
function ItemService:OnSwapped(_from: string, to: string)
	Pickup.swap(self.Pickup, to, self.Dependencies.RoundService:GetDay())
end

-- InteractionService (730) and RoundService (750) ran their OnInit before this one (720): handler table and
-- ShiftStarted exist. Spawn on ShiftStarted happens before RoundService captures the shift snapshot.
-- pick_up_item has one owner (InteractionService refuses a second): free packages and dropped items share it.
function ItemService:WirePickup()
	const pickup = self.Pickup
	const drops = self.Drops
	self.Dependencies.InteractionService:RegisterAction(Pickup.Action, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			if Pickup.owns(pickup, anchor) then
				return Pickup.validate(pickup, player, anchor)
			end
			return Drops.validate(drops, player, anchor)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			if Pickup.owns(pickup, anchor) then
				Pickup.take(pickup, player, anchor)
			elseif Drops.owns(drops, anchor) then
				Drops.take(drops, player, anchor)
			end
		end,
	})
	self.Dependencies.RoundService.ShiftStarted:Connect(function(info)
		self.ShiftIndex += 1
		Pickup.shift(pickup, info.Day, self:CurrentVehicle())
	end)
	self.Dependencies.RoundService.ShiftEnded:Connect(function(_info)
		Drops.shiftEnded(drops, self.ShiftIndex)
	end)
	self.Dependencies.RunStateService:RegisterSnapshot("Fp", function()
		return Pickup.capture(pickup)
	end, function(data, _mode)
		Pickup.restore(pickup, data, self:CurrentVehicle())
	end)
end

function ItemService:WireWave2()
	self.Dependencies.InteractionService:RegisterAction(GIVE_COFFEE, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			return self:CanGiveCoffee(player, anchor)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			self:GiveCoffee(player, anchor)
		end,
	})
	self.Dependencies.RunStateService:RegisterSnapshot("T", function()
		return self:CaptureTools()
	end, function(data, _mode)
		self:RestoreTools(data)
	end)
	const players = self.Dependencies.PlayerService
	players.CharacterAdded:Connect(function(player, character)
		self:OnCharacter(player, character)
	end)
	players.CharacterRemoving:Connect(function(player, _character)
		self:Stash(player)
	end)
	-- ITM-020: an altered hot dog never outlives the Night phase (RoundService 750 > 720: PhaseChanged exists).
	self.Dependencies.RoundService.PhaseChanged:Connect(function(phase: string)
		if phase ~= ALTER_PHASE then
			self:ClearAltered()
		end
	end)
end

ItemService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	-- Leaving player: Tools go to the stash (Away), leftovers are forgotten.
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Stash(player)
		self:Release(player)
		Uses.forget(self.Uses, player)
	end)
	self:WirePickup()
	self:WireWave2()
end)

ItemService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self:CheckKit()
	-- Vehicle swap (§19.2: VehicleService has a lower priority, so its Swapped exists only from OnStart on).
	-- Also fired by a "Veh" restore that changes the vehicle (TASK-056).
	self.Dependencies.VehicleService.Swapped:Connect(function(from: string, to: string)
		self:OnSwapped(from, to)
	end)
end)

return ItemService
