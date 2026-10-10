--!strict
-- Hotbar Tools (FEAT-005, FEAT-007; DEC-040, DEC-049, DEC-174, DEC-190; architecture.md §3.1, §18.9.5;
-- network.md §7, §7.1; TASK-022). Run place only.
-- Single writer of the Tool attributes Item, Count and Toppings. Tools are cloned from the kit
-- ReplicatedStorage.Assets.Items.Tools/<Content.Items key> and replicate through the native Backpack (no Lync).
-- Limits come from Content.ItemRules: HotbarSlots total Tools (4) and CategoryLimits per category; the package limit
-- goes through ClassService (PackageLimit, bear = 3). Only Tools created here count and are trusted: anything else in
-- a Backpack is ignored by every read below.
-- Wave 1 (board N-01): no stash. A player who leaves loses the Tools; they are destroyed and forgotten here.
-- The hot dog visual is HotDogVisual (TASK-023), refreshed on the server every time Toppings is written (replicates).
-- It does not cap the count: MaxToppings (DEC-071) is enforced here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local Modux = require(ServerScriptService.server.Modux)

-- Options of Give. Count: stackable items only (default = Packages[key].Amount for a package, 1 otherwise).
-- Toppings: hot dog only, attribute format "ketchup,cheese" (network.md §7.1). Equip: put it in the hand (default
-- true). Silent: no "Hands full"/"package_limit" notice on refusal (default false).
export type GiveOptions = {
	Count: number?,
	Toppings: string?,
	Equip: boolean?,
	Silent: boolean?,
}

const HOT_DOG = "hot_dog"
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
	Require = { "PlaceService", "PlayerService", "RunStateService", "ClassService" },
	Priority = 720,
})

function ItemService:Setup()
	self.Owners = {} :: { [Tool]: Player }
	self.ByPlayer = {} :: { [Player]: { [Tool]: boolean } }
	self.Links = {} :: { [Tool]: { RBXScriptConnection } }
	-- Hotbar of a player changed (Give, Consume, Count, Toppings, Tool lost). CharacterService reads the package
	-- count here for the bear's walk speed (Classes, PackagesAtLeast).
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<Player>
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
	self.Links[tool] = {
		tool.AncestryChanged:Connect(function()
			if self.Owners[tool] ~= nil and not self:InPlay(tool, player) then
				self:Forget(tool)
			end
		end),
		tool.Destroying:Connect(function()
			self:Forget(tool)
		end),
	}
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

ItemService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	-- Leaving player: every Tool destroyed and forgotten (board N-01; stash is wave 2).
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
end)

ItemService:OnStart(function(self)
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self:CheckKit()
end)

return ItemService
