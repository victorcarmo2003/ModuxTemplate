--!strict
-- Free package of the unlock day (DEC-071; FEAT-007; network.md §7 "Pacote grátis"; board N-03, TASK-046, Provisional).
-- Plain module, no Modux and no network: ItemService owns one Pickup and wires it to RoundService.ShiftStarted,
-- InteractionService (action pick_up_item) and the RunStateService snapshot ("Fp").
-- On the ShiftStarted of the day an ingredient unlocks (Content.Ingredients[*].UnlockDay), one display model of its
-- package (a Model cloned from the kit Tool, never a Tool, no touchable Handle) is placed over the ingredient's
-- station, with an Interactable Attachment -> pick_up_item ("Take", tap). The taker gets the full package Tool through
-- ItemService:Give (hotbar 4, DEC-174; package limit 2 / bear 3); refused = Notice from Give and the model stays.
-- It stays in the world until taken: it does not vanish at the end of the day and never comes back once given.
-- Only the day actually entered spawns (DevSetDay jumps skip the days in between). Day 1 ingredients are the start
-- kit, not an unlock: no free package (Provisional).
-- Restock of the taken package is KitchenService's (TASK-025): the Tool is a regular pack_* Tool from Give.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

export type Deps = {
	Template: (item: string) -> Tool?, -- kit Tool of a Content.Items key
	Give: (player: Player, item: string) -> Tool?, -- ItemService:Give (Notice on refusal)
	IsActive: (player: Player) -> boolean, -- RunStateService:IsActive
	SetPrompt: (anchor: Instance, enabled: boolean) -> (), -- InteractionService:SetPrompt
}

export type Entry = {
	Ingredient: string, -- key of Content.Ingredients
	Item: string, -- key of Content.Items (the package Tool)
	Model: Model,
	Anchor: Attachment,
}

export type Pickup = {
	Deps: Deps,
	Given: { [string]: boolean }, -- ingredients whose free package was already placed (never again)
	Live: { [string]: Entry }, -- by ingredient, not taken yet
	ByAnchor: { [Instance]: Entry },
	Folder: Folder?,
}

const ACTION = "pick_up_item"
const TAG = "Interactable"
const STATION_TAG = "Station"
const VEHICLE_TAG = "Vehicle"
const FOLDER = "FreePacks"
const LIFT = 0.75 -- studs between the station top (or the bowl anchor) and the package bottom
const PROMPT_LIFT = 0.5 -- studs above the package top for the prompt anchor
const FIRST_DAY = 1 -- start-kit day: no free package
const STRIP = { "Script", "LocalScript", "ModuleScript", "TouchTransmitter", "Sound" }

local function packageOf(ingredient: string): string?
	for _, row in Content.Packages.List do
		if row.Ingredient == ingredient then
			return row.Item
		end
	end
	return nil
end

local function vehicleOf(instance: Instance): string?
	local node = instance.Parent
	while node ~= nil and node ~= game do
		if CollectionService:HasTag(node, VEHICLE_TAG) then
			const key = node:GetAttribute("Vehicle")
			return if typeof(key) == "string" then key else nil
		end
		node = node.Parent
	end
	return nil
end

local function anchorPosition(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

-- Point the package bottom sits on: top of the station Model, or above the ingredient's own anchor on a shared
-- station (toppings grid, Stations.PerAnchor). The map binding has no "free package" point (MapIndex reads points
-- and nodes only; stations belong to KitchenService), so the station is read by tag here, read-only (Provisional).
local function spotFor(ingredient: string, vehicle: string): Vector3?
	const row = Content.Ingredients.ByKey[ingredient]
	const stationRow = row and Content.Stations.ByKey[row.Station]
	if row == nil or stationRow == nil then
		return nil
	end
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if not station:IsA("Model") or not station:IsDescendantOf(Workspace) then
			continue
		end
		if station:GetAttribute("StationKind") ~= row.Station then
			continue
		end
		const owner = vehicleOf(station)
		if owner ~= nil and owner ~= vehicle then
			continue
		end
		if stationRow.Ingredient == Content.Stations.PerAnchor then
			for _, anchor in station:GetDescendants() do
				if CollectionService:HasTag(anchor, TAG) and anchor:GetAttribute("Ingredient") == ingredient then
					const position = anchorPosition(anchor)
					if position then
						return position + Vector3.yAxis * LIFT
					end
				end
			end
		else
			const cframe, size = station:GetBoundingBox()
			return cframe.Position + Vector3.yAxis * (size.Y / 2 + LIFT)
		end
	end
	return nil
end

-- Display copy of the kit Tool: plain Model, every part anchored and untouchable, scripts stripped, no "Handle".
local function buildModel(template: Tool?, item: string): Model
	const model = Instance.new("Model")
	model.Name = `FreePack_{item}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	if template then
		for _, child in template:Clone():GetChildren() do
			child.Parent = model
		end
	end
	for _, descendant in model:GetDescendants() do
		if table.find(STRIP, descendant.ClassName) then
			descendant:Destroy()
		end
	end
	local primary: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			if descendant.Name == "Handle" then
				descendant.Name = "Body"
				primary = descendant
			end
			primary = primary or descendant
		end
	end
	if primary == nil then
		const box = Instance.new("Part")
		box.Name = "Body"
		box.Size = Vector3.new(1.2, 1, 0.8)
		box.Anchored = true
		box.CanCollide = false
		box.CanTouch = false
		box.CanQuery = false
		box.Parent = model
		primary = box
		warn(`[ItemService] no kit Tool for free package "{item}": placeholder box`)
	end
	model.PrimaryPart = primary
	return model
end

const Pickup = {}

Pickup.Action = ACTION

function Pickup.new(deps: Deps): Pickup
	return { Deps = deps, Given = {}, Live = {}, ByAnchor = {}, Folder = nil }
end

local function folderOf(pickup: Pickup): Folder
	const existing = pickup.Folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = Workspace
	pickup.Folder = folder
	return folder
end

-- Places the package of `ingredient` over its station. False when the binding has no such station (warned).
function Pickup.place(pickup: Pickup, ingredient: string, vehicle: string): boolean
	if pickup.Live[ingredient] ~= nil then
		return true
	end
	const item = packageOf(ingredient)
	if item == nil then
		warn(`[ItemService] free package: no Content.Packages row for ingredient "{ingredient}"`)
		return false
	end
	const spot = spotFor(ingredient, vehicle)
	if spot == nil then
		warn(`[ItemService] free package: no station for "{ingredient}" in the {vehicle} (map binding)`)
		return false
	end

	const model = buildModel(pickup.Deps.Template(item), item)
	const cframe, size = model:GetBoundingBox()
	const offset = model:GetPivot().Position - cframe.Position
	model:PivotTo(CFrame.new(spot + Vector3.yAxis * (size.Y / 2) + offset))

	const primary = model.PrimaryPart :: BasePart
	const anchor = Instance.new("Attachment")
	anchor.Name = "Prompt_Take"
	anchor.Parent = primary
	const top = model:GetBoundingBox().Position + Vector3.yAxis * (size.Y / 2 + PROMPT_LIFT)
	anchor.WorldPosition = top
	anchor:SetAttribute("PromptAction", ACTION)
	pickup.Deps.SetPrompt(anchor, true)

	const entry: Entry = { Ingredient = ingredient, Item = item, Model = model, Anchor = anchor }
	pickup.Live[ingredient] = entry
	pickup.ByAnchor[anchor] = entry
	model.Parent = folderOf(pickup)
	-- Tag last: InteractionService gives the EntityId as soon as the tagged anchor is in the Workspace.
	CollectionService:AddTag(anchor, TAG)
	return true
end

function Pickup.remove(pickup: Pickup, entry: Entry)
	pickup.Live[entry.Ingredient] = nil
	pickup.ByAnchor[entry.Anchor] = nil
	entry.Model:Destroy()
end

-- ShiftStarted: every ingredient unlocking exactly on `day` (and allowed on the vehicle) that never got its package.
function Pickup.shift(pickup: Pickup, day: number, vehicle: string)
	if day <= FIRST_DAY then
		return
	end
	for _, row in Content.Ingredients.List do
		if row.UnlockDay ~= day or pickup.Given[row.Key] then
			continue
		end
		if row.Vehicle ~= nil and row.Vehicle ~= vehicle then
			continue
		end
		if Pickup.place(pickup, row.Key, vehicle) then
			pickup.Given[row.Key] = true
		end
	end
end

-- InteractionService Validate: a live free package and an active member. Hotbar and package limit are checked in
-- Run by ItemService:Give, which sends the Notice (hands_full / package_limit) and leaves the package in the world.
function Pickup.validate(pickup: Pickup, player: Player, anchor: Instance): boolean
	const entry = pickup.ByAnchor[anchor]
	return entry ~= nil and entry.Model.Parent ~= nil and pickup.Deps.IsActive(player)
end

-- InteractionService Run (serialized per target: a second taker in the same frame fails validate).
function Pickup.take(pickup: Pickup, player: Player, anchor: Instance)
	const entry = pickup.ByAnchor[anchor]
	if entry == nil then
		return
	end
	if pickup.Deps.Give(player, entry.Item) ~= nil then
		Pickup.remove(pickup, entry)
	end
end

-- Snapshot "Fp" (Provisional key, not in data.md §3.3 yet): G = ingredients already given, L = still in the world.
function Pickup.capture(pickup: Pickup): { [string]: any }
	const given: { string } = {}
	for key in pickup.Given do
		table.insert(given, key)
	end
	const live: { string } = {}
	for key in pickup.Live do
		table.insert(live, key)
	end
	table.sort(given)
	table.sort(live)
	return { G = given, L = live }
end

function Pickup.restore(pickup: Pickup, data: { [string]: any }, vehicle: string)
	for _, entry in pickup.Live do
		Pickup.remove(pickup, entry)
	end
	pickup.Given = {}
	if type(data.G) == "table" then
		for _, key in data.G do
			if type(key) == "string" and Content.Ingredients.ByKey[key] ~= nil then
				pickup.Given[key] = true
			end
		end
	end
	if type(data.L) == "table" then
		for _, key in data.L do
			if type(key) == "string" and Content.Ingredients.ByKey[key] ~= nil then
				pickup.Given[key] = true
				Pickup.place(pickup, key, vehicle)
			end
		end
	end
end

return table.freeze(Pickup)
