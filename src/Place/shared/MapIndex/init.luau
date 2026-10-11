--!strict
-- MapIndex: shared read of the map binding by tag + attribute (architecture.md §18.0, §18.5, §18.6, §18.8; TASK-010).
-- ReplicatedStorage.shared.Place.MapIndex. Pure: no Modux, Lync, Vide nor self.Libs; cache built on first use.
-- Only the Workspace counts (§18.0 item 5). Interactable and Station registries are NOT here: they belong to
-- InteractionService and KitchenService (single owners, §4 rule 1). Validate only checks that they are authored.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Graph = require(script.Graph)
local Required = require(script.Required)

export type NodeInfo = { Position: Vector3, Links: { string }, Crosswalk: string? }
export type PathOptions = Graph.PathOptions
export type List = Required.List

type Cache = {
	Points: { [string]: CFrame },
	Nodes: { [string]: Graph.Node },
	Adjacency: Graph.Adjacency,
}

const ROOT_TAG = "MapBinding"
const DEFAULT_WAIT = 30 -- seconds WaitReady waits for streaming by default
const POLL = 0.1
-- Root present but a count short and nothing new streamed in for this long: the counts are stale (the binding changed
-- after check_map01 last wrote them, e.g. hide spots removed by TASK-133) and the map is what the server has.
const SETTLE = 8
-- Counts written on the root by the edit-time check (§18.7 item 8): what the client must have streamed in.
const COUNTS = {
	{ Attribute = "PointCount", Tag = "MapPoint" },
	{ Attribute = "NodeCount", Tag = "NpcNode" },
	{ Attribute = "InteractableCount", Tag = "Interactable" },
}

local cache: Cache? = nil

local function tagged(tag: string): { Instance }
	const out: { Instance } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(Workspace) then
			table.insert(out, instance)
		end
	end
	table.sort(out, function(a: Instance, b: Instance): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	return out
end

-- Count of `tag` in the Workspace (no sort: polled by WaitReady)
local function countTagged(tag: string): number
	local n = 0
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(Workspace) then
			n += 1
		end
	end
	return n
end

local function positionOf(instance: Instance): Vector3
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("PVInstance") then
		return instance:GetPivot().Position
	end
	return Vector3.zero
end

local function nameOf(instance: Instance?): string
	return if instance then instance:GetFullName() else "?"
end

local function stringAttribute(instance: Instance, name: string): string?
	const value = instance:GetAttribute(name)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function ancestorWithTag(instance: Instance, tag: string): Instance?
	local current = instance.Parent
	while current ~= nil and current ~= game do
		if CollectionService:HasTag(current, tag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Owner of an anchor (§18.3): the Station ancestor, else the closest Model ancestor.
local function ownerOf(instance: Instance): Instance?
	const station = ancestorWithTag(instance, "Station")
	if station then
		return station
	end
	local current = instance.Parent
	while current ~= nil and current ~= Workspace do
		if current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function splitLinks(raw: string): { string }
	const out: { string } = {}
	for link in string.gmatch(raw, "[^,]+") do
		const trimmed = string.gsub(link, "%s", "")
		if trimmed ~= "" then
			table.insert(out, trimmed)
		end
	end
	return out
end

-- Node id: PointId when the Part is also a MapPoint, else NodeId (§18.2).
local function nodeId(instance: Instance): string?
	if CollectionService:HasTag(instance, "MapPoint") then
		return stringAttribute(instance, "PointId") or stringAttribute(instance, "NodeId")
	end
	return stringAttribute(instance, "NodeId")
end

local function build(): Cache
	const points: { [string]: CFrame } = {}
	for _, instance in tagged("MapPoint") do
		const id = stringAttribute(instance, "PointId")
		if id ~= nil and points[id] == nil and instance:IsA("BasePart") then
			points[id] = instance.CFrame
		end
	end

	const nodes: { [string]: Graph.Node } = {}
	for _, instance in tagged("NpcNode") do
		const id = nodeId(instance)
		if id ~= nil and nodes[id] == nil then
			const links = stringAttribute(instance, "Links")
			nodes[id] = {
				Id = id,
				Position = positionOf(instance),
				Links = if links then splitLinks(links) else {},
				Crosswalk = stringAttribute(instance, "Crosswalk"),
			}
		end
	end

	const adjacency = Graph.adjacency(nodes)
	return { Points = points, Nodes = nodes, Adjacency = adjacency }
end

local function get(): Cache
	const existing = cache
	if existing ~= nil then
		return existing
	end
	const built = build()
	cache = built
	return built
end

local function inRect(x: number, z: number, rect: Required.Rect): boolean
	const e = 0.01
	return x > rect.X0 + e and x < rect.X1 - e and z > rect.Z0 + e and z < rect.Z1 - e
end

-- Road the XZ segment enters, and whether every sample on the road stays inside `stripes`.
local function crossesRoad(a: Vector3, b: Vector3, roads: { Required.Rect }, stripes: Required.Rect?): (string?, boolean)
	const length = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	const steps = math.max(1, math.ceil(length / 0.25))
	local hit: string? = nil
	local insideStripes = true
	for i = 0, steps do
		const t = i / steps
		const x = a.X + (b.X - a.X) * t
		const z = a.Z + (b.Z - a.Z) * t
		for _, road in roads do
			if inRect(x, z, road) then
				hit = hit or road.Name
				if
					stripes == nil
					or not (x >= stripes.X0 - 0.01 and x <= stripes.X1 + 0.01 and z >= stripes.Z0 - 0.01 and z <= stripes.Z1 + 0.01)
				then
					insideStripes = false
				end
			end
		end
	end
	return hit, insideStripes
end

const MapIndex = {}

MapIndex.Required = Required

-- True when a MapBinding root exists in the Workspace.
function MapIndex.HasBinding(): boolean
	return #tagged(ROOT_TAG) > 0
end

-- Drops the cache; the next read rebuilds it (after streaming, or after the binding changed in Studio).
function MapIndex.Refresh()
	cache = nil
end

-- Client: waits until the root exists and the tagged counts written by the check (§18.7 item 8) have streamed in.
-- Root without counts = the check never wrote them: ready as soon as the root is there. Server: returns at once.
-- Counts that stop growing for SETTLE s with the root there are stale, not streaming: ready, with one warning.
local warnedStale = false
function MapIndex.WaitReady(timeout: number?): boolean
	const deadline = os.clock() + (timeout or DEFAULT_WAIT)
	local seen = ""
	local stillSince = os.clock()
	while true do
		const roots = tagged(ROOT_TAG)
		const root = roots[1]
		if root ~= nil then
			local complete = true
			const parts: { string } = {}
			for _, count in COUNTS do
				const expected = root:GetAttribute(count.Attribute)
				const got = countTagged(count.Tag)
				table.insert(parts, `{count.Tag} {got}/{if typeof(expected) == "number" then expected else "-"}`)
				if typeof(expected) == "number" and got < expected then
					complete = false
				end
			end
			if complete then
				MapIndex.Refresh()
				return true
			end
			const summary = table.concat(parts, ", ")
			if summary ~= seen then
				seen = summary
				stillSince = os.clock()
			elseif os.clock() - stillSince >= SETTLE then
				if not warnedStale then
					warnedStale = true
					warn(`[MapIndex] binding counts not reached and nothing new for {SETTLE} s ({summary}): stale counts, run check_map01 to rewrite them`)
				end
				MapIndex.Refresh()
				return true
			end
		end
		if os.clock() >= deadline then
			return false
		end
		task.wait(POLL)
	end
end

function MapIndex.FindPoint(id: string): CFrame?
	return get().Points[id]
end

-- Error when the point is missing (the binding check makes this a boot failure, §18.7).
function MapIndex.Point(id: string): CFrame
	const point = get().Points[id]
	if point == nil then
		error(`[MapIndex] MapPoint {id} not found`, 2)
	end
	return point
end

-- Every point whose id starts with `prefix` ("PS-", "Q", "REV-").
function MapIndex.Points(prefix: string): { [string]: CFrame }
	const out: { [string]: CFrame } = {}
	for id, point in get().Points do
		if string.sub(id, 1, #prefix) == prefix then
			out[id] = point
		end
	end
	return out
end

-- Links are the symmetric neighbours (one-sided Links in the place count both ways, §18.6).
function MapIndex.Node(id: string): NodeInfo
	const current = get()
	const node = current.Nodes[id]
	if node == nil then
		error(`[MapIndex] NpcNode {id} not found`, 2)
	end
	const info: NodeInfo = {
		Position = node.Position,
		Links = table.clone(current.Adjacency[id] or {}),
		Crosswalk = node.Crosswalk,
	}
	table.freeze(info :: any)
	return info
end

-- Closest NpcNode to `position` on the XZ plane, skipping ids `skip` says no to (queue slots, crosswalk curbs...).
-- nil when the graph is empty. Off-graph walks (Pad tables, TASK-145) hop on and off the graph here.
function MapIndex.NearestNode(position: Vector3, skip: ((id: string) -> boolean)?): string?
	local best: string? = nil
	local bestDistance = math.huge
	for id, node in get().Nodes do
		if skip ~= nil and skip(id) then
			continue
		end
		const offset = node.Position - position
		const distance = offset.X * offset.X + offset.Z * offset.Z
		if distance < bestDistance or (distance == bestDistance and best ~= nil and id < best) then
			best = id
			bestDistance = distance
		end
	end
	return best
end

-- Node ids from `from` to `to` (both included), or nil. AvoidCrossings for the thief (MAP-01 §9.2); AvoidQueue
-- keeps queue slots from being intermediate steps (check_map01 route warning).
function MapIndex.Path(from: string, to: string, options: PathOptions?): { string }?
	const current = get()
	return Graph.path(current.Nodes, current.Adjacency, from, to, options)
end

-- Problems of the binding against `required` (empty = accepted). Items of architecture.md §18.7: 1-6. Item 7
-- (pivot heights) needs tool metadata (MapId), which code does not read (§18.0 item 8): edit-time tool only.
function MapIndex.Validate(required: List): { string }
	const problems: { string } = {}
	local function add(message: string)
		table.insert(problems, message)
	end

	-- 1, 5: tags, single root, nothing tagged outside the Workspace
	for _, tag in required.Tags do
		if #tagged(tag) == 0 then
			add(`1: no instance with tag {tag} in the Workspace`)
		end
		for _, instance in CollectionService:GetTagged(tag) do
			if not instance:IsDescendantOf(Workspace) then
				add(`5: {nameOf(instance)} tagged {tag} outside the Workspace`)
			end
		end
	end
	const roots = tagged(ROOT_TAG)
	if #roots ~= 1 then
		add(`1: {#roots} MapBinding roots in the Workspace (need exactly 1)`)
	end
	const root = roots[1]

	-- 1, 2, 5: points
	const points: { [string]: Instance } = {}
	for _, instance in tagged("MapPoint") do
		const id = stringAttribute(instance, "PointId")
		if id == nil then
			add(`2: MapPoint {nameOf(instance)} without PointId`)
			continue
		end
		if points[id] ~= nil then
			add(`1: PointId {id} duplicated ({nameOf(points[id])}, {nameOf(instance)})`)
		end
		points[id] = instance
		if root ~= nil and not instance:IsDescendantOf(root) then
			add(`5: MapPoint {id} outside the MapBinding root`)
		end
		if not instance:IsA("BasePart") then
			add(`5: MapPoint {id} is a {instance.ClassName} (must be a Part)`)
		elseif math.abs(instance.CFrame.LookVector.Y) > 0.01 then
			add(`5: MapPoint {id} LookVector is not horizontal`)
		end
	end
	for _, id in required.Points do
		if points[id] == nil then
			add(`2: required MapPoint {id} missing`)
		end
	end

	-- 3, 5: Content keys and anchor shape
	local function checkKey(tag: string, attribute: string, keys: { [string]: any }, tableName: string)
		for _, instance in tagged(tag) do
			const value = instance:GetAttribute(attribute)
			if value ~= nil and (typeof(value) ~= "string" or keys[value] == nil) then
				add(`3: {nameOf(instance)}.{attribute} = {tostring(value)} is not a key of Content.{tableName}`)
			end
		end
	end
	checkKey("Station", "StationKind", Content.Stations.ByKey, "Stations")
	checkKey("Station", "Ingredient", Content.Ingredients.ByKey, "Ingredients")
	checkKey("Interactable", "PromptAction", Content.Actions.ByKey, "Actions")
	checkKey("Interactable", "Ingredient", Content.Ingredients.ByKey, "Ingredients")
	checkKey("Interactable", "Package", Content.Packages.ByKey, "Packages")
	checkKey("Vehicle", "Vehicle", Content.Vehicles.ByKey, "Vehicles")
	checkKey("LightZone", "Group", Content.LightGroups.ByKey, "LightGroups")
	checkKey("StreetLight", "Group", Content.LightGroups.ByKey, "LightGroups")

	-- 2: ids that must exist once on tagged instances (light zones, street lights; §19.22)
	for _, rule in required.Tagged do
		const seen: { [string]: number } = {}
		for _, instance in tagged(rule.Tag) do
			const id = stringAttribute(instance, rule.Attribute)
			if id == nil then
				add(`2: {rule.Tag} {nameOf(instance)} without {rule.Attribute}`)
			else
				seen[id] = (seen[id] or 0) + 1
			end
		end
		for _, id in rule.Ids do
			if seen[id] ~= 1 then
				add(`2: {rule.Tag} {rule.Attribute} = {id} found {seen[id] or 0} time(s), need 1`)
			end
		end
	end

	const anchors = tagged("Interactable")
	for _, anchor in anchors do
		const bench = anchor:GetAttribute("BenchSlot")
		if bench ~= nil and (typeof(bench) ~= "string" or required.Bench[bench] == nil) then
			add(`3: {nameOf(anchor)}.BenchSlot = {tostring(bench)} is not a bench spot`)
		end
		if stringAttribute(anchor, "PromptAction") == nil then
			add(`2: Interactable {nameOf(anchor)} without PromptAction`)
		end
		if anchor:IsA("BasePart") then
			if anchor.Transparency < 1 or anchor.CanCollide or anchor.CanQuery or anchor.CanTouch then
				add(`5: Interactable {nameOf(anchor)} must be invisible with CanCollide/CanQuery/CanTouch false`)
			end
		elseif not anchor:IsA("Attachment") then
			add(`5: Interactable {nameOf(anchor)} is a {anchor.ClassName} (Attachment or BasePart only)`)
		end
	end
	for _, station in tagged("Station") do
		if not station:IsA("Model") then
			add(`5: Station {nameOf(station)} is a {station.ClassName} (must be a Model)`)
		end
		if stringAttribute(station, "StationKind") == nil then
			add(`2: Station {nameOf(station)} without StationKind`)
		end
		if ancestorWithTag(station, "Vehicle") == nil then
			add(`5: Station {nameOf(station)} is not a descendant of a Vehicle`)
		end
	end

	-- 2: the vehicles and their stations (one Model per required vehicle; A6: none of them is "current" here)
	const vehicleModels: { [string]: Instance } = {}
	do
		const found: { [string]: { Instance } } = {}
		for _, instance in tagged("Vehicle") do
			const key = stringAttribute(instance, "Vehicle")
			if key == nil then
				add(`2: Vehicle {nameOf(instance)} without attribute Vehicle`)
			else
				const list = found[key] or {}
				found[key] = list
				table.insert(list, instance)
			end
		end
		for key in required.Vehicles do
			const list = found[key] or {}
			if #list ~= 1 then
				add(`2: {#list} Vehicle '{key}' in the Workspace (need 1)`)
			else
				vehicleModels[key] = list[1]
			end
		end
	end

	for vehicleKey, vehicleRule in required.Vehicles do
		const vehicle = vehicleModels[vehicleKey]
		if vehicle == nil then
			continue
		end
		for kind, rule in vehicleRule.Stations do
			const inVehicle: { Instance } = {}
			for _, station in tagged("Station") do
				if station:GetAttribute("StationKind") == kind and station:IsDescendantOf(vehicle) then
					table.insert(inVehicle, station)
				end
			end
			if #inVehicle ~= 1 then
				add(`2: {#inVehicle} Station '{kind}' in the {vehicleKey} (need 1)`)
				continue
			end
			const station = inVehicle[1]

			const actions: { [string]: number } = {}
			const slotAnchors: { [number]: number } = {}
			const perIngredient: { [string]: { [string]: number } } = {}
			for _, anchor in anchors do
				if ownerOf(anchor) ~= station then
					continue
				end
				const action = stringAttribute(anchor, "PromptAction") or "?"
				actions[action] = (actions[action] or 0) + 1
				const slot = anchor:GetAttribute("Slot")
				if typeof(slot) == "number" then
					slotAnchors[slot] = (slotAnchors[slot] or 0) + 1
				end
				const ingredient = stringAttribute(anchor, "Ingredient")
				if ingredient ~= nil then
					const counts = perIngredient[ingredient] or {}
					perIngredient[ingredient] = counts
					counts[action] = (counts[action] or 0) + 1
				end
			end

			if rule.Actions then
				for action, count in rule.Actions do
					if (actions[action] or 0) ~= count then
						add(`2: {vehicleKey}/{kind}: {actions[action] or 0} anchor(s) {action}, need {count}`)
					end
				end
			end
			if rule.SlotAnchors then
				for slot = 1, rule.SlotAnchors do
					if slotAnchors[slot] ~= 1 then
						add(`2: {vehicleKey}/{kind}: anchor with Slot {slot} found {slotAnchors[slot] or 0} time(s), need 1`)
					end
				end
			end
			if rule.Slots then
				const seen: { [number]: number } = {}
				for _, descendant in station:GetDescendants() do
					const slot = descendant:GetAttribute("Slot")
					if typeof(slot) == "number" and not CollectionService:HasTag(descendant, "Interactable") then
						seen[slot] = (seen[slot] or 0) + 1
					end
				end
				for slot = 1, rule.Slots do
					if seen[slot] ~= 1 then
						add(`2: {vehicleKey}/{kind}: slot Attachment with Slot {slot} found {seen[slot] or 0} time(s), need 1`)
					end
				end
			end
			if rule.PerIngredient then
				for _, ingredient in required.Toppings do
					for _, action in rule.PerIngredient do
						const counts = perIngredient[ingredient]
						const found = if counts then counts[action] or 0 else 0
						if found ~= 1 then
							add(`2: {vehicleKey}/{kind}: {action} with Ingredient {ingredient} found {found} time(s), need 1`)
						end
					end
				end
			end
		end

		-- anchors inside the vehicle that belong to no station (phone, switch, buy prompt)
		const loose: { [string]: number } = {}
		for _, anchor in anchors do
			if anchor:IsDescendantOf(vehicle) and ancestorWithTag(anchor, "Station") == nil then
				const action = stringAttribute(anchor, "PromptAction") or "?"
				loose[action] = (loose[action] or 0) + 1
			end
		end
		for action, count in vehicleRule.Actions do
			if (loose[action] or 0) ~= count then
				add(`2: {vehicleKey}: {loose[action] or 0} anchor(s) {action} outside the stations, need {count}`)
			end
		end
	end

	-- 2: anchors on the map (open sign, Mart shelves, bench)
	const mapActions: { [string]: number } = {}
	const shelves: { [string]: { Instance } } = {}
	const benches: { [string]: { Instance } } = {}
	for _, anchor in anchors do
		const action = stringAttribute(anchor, "PromptAction")
		if action == nil then
			continue
		end
		if required.MapActions[action] ~= nil then
			mapActions[action] = (mapActions[action] or 0) + 1
			if ancestorWithTag(anchor, "Vehicle") ~= nil then
				add(`2: {action} {nameOf(anchor)} is inside a Vehicle (it stays on the map)`)
			end
		elseif action == "buy_package" then
			const package = stringAttribute(anchor, "Package")
			if package == nil then
				add(`2: buy_package {nameOf(anchor)} without Package`)
			else
				const list = shelves[package] or {}
				shelves[package] = list
				table.insert(list, anchor)
			end
		elseif action == "bench_buy_upgrade" or action == "bench_buy_item" then
			const spot = stringAttribute(anchor, "BenchSlot")
			if spot == nil then
				add(`2: {action} {nameOf(anchor)} without BenchSlot`)
			else
				const want = required.Bench[spot]
				if want ~= nil and want ~= action then
					add(`2: BenchSlot {spot} has action {action}, need {want}`)
				end
				const list = benches[spot] or {}
				benches[spot] = list
				table.insert(list, anchor)
			end
		end
	end
	for action, count in required.MapActions do
		if (mapActions[action] or 0) ~= count then
			add(`2: {mapActions[action] or 0} {action} anchor(s) on the map, need {count}`)
		end
	end
	for _, package in required.Packages do
		const found = #(shelves[package] or {})
		if found ~= 1 then
			add(`2: buy_package {package} found {found} time(s), need 1`)
		end
	end
	for spot in required.Bench do
		const found = #(benches[spot] or {})
		if found ~= 1 then
			add(`2: bench {spot} found {found} time(s), need 1`)
		end
	end

	-- 4: distances between anchors
	local function spread(groups: { [string]: { Instance } }, gap: number, label: string)
		const flat: { Instance } = {}
		for _, list in groups do
			for _, anchor in list do
				table.insert(flat, anchor)
			end
		end
		for i = 1, #flat do
			for j = i + 1, #flat do
				const distance = (positionOf(flat[i]) - positionOf(flat[j])).Magnitude
				if distance < gap then
					add(`4: {label}: {flat[i].Name} and {flat[j].Name} {string.format("%.2f", distance)} apart (< {gap})`)
				end
			end
		end
	end
	spread(shelves, required.ShelfGap, "Mart shelves")
	spread(benches, required.BenchGap, "bench")
	for _, vehicle in vehicleModels do
		const inVehicle: { Instance } = {}
		for _, anchor in anchors do
			if anchor:IsDescendantOf(vehicle) then
				table.insert(inVehicle, anchor)
			end
		end
		for i = 1, #inVehicle do
			for j = i + 1, #inVehicle do
				const a, b = inVehicle[i], inVehicle[j]
				const ownerA, ownerB = ownerOf(a), ownerOf(b)
				const distance = (positionOf(a) - positionOf(b)).Magnitude
				const text = string.format("%.2f", distance)
				if ownerA ~= ownerB then
					if distance < required.StationGap then
						add(`4: {nameOf(a)} / {nameOf(b)} (different stations) {text} apart (< {required.StationGap})`)
					end
				elseif ownerA ~= nil and ownerA:GetAttribute("StationKind") == "toppings" then
					if a:GetAttribute("Ingredient") ~= b:GetAttribute("Ingredient") and distance < required.ToppingGap then
						add(`4: toppings {a.Name} / {b.Name} {text} apart (< {required.ToppingGap})`)
					end
				end
			end
		end
	end

	-- 5: streaming, every Model holding a gameplay tag is Persistent (T26)
	const transient: { [Model]: boolean } = {}
	for _, tag in required.Tags do
		for _, instance in tagged(tag) do
			local current: Instance? = instance
			while current ~= nil and current ~= Workspace do
				if current:IsA("Model") and current.ModelStreamingMode ~= Enum.ModelStreamingMode.Persistent then
					transient[current] = true
				end
				current = current.Parent
			end
		end
	end
	for model in transient do
		add(`5: Model {nameOf(model)} holds gameplay tags but is not ModelStreamingMode Persistent`)
	end

	-- 1, 5, 6: graph
	const nodes: { [string]: Graph.Node } = {}
	local nodeCount = 0
	for _, instance in tagged("NpcNode") do
		const id = nodeId(instance)
		if id == nil then
			add(`2: NpcNode {nameOf(instance)} without NodeId/PointId`)
			continue
		end
		if nodes[id] ~= nil then
			add(`1: NodeId {id} duplicated`)
		end
		if root ~= nil and not instance:IsDescendantOf(root) then
			add(`5: NpcNode {id} outside the MapBinding root`)
		end
		const raw = stringAttribute(instance, "Links")
		if raw == nil then
			add(`6: NpcNode {id} without Links`)
		elseif string.find(raw, "%s") then
			add(`6: NpcNode {id} Links has spaces: '{raw}'`)
		end
		const crosswalk = stringAttribute(instance, "Crosswalk")
		if crosswalk ~= nil and required.Crosswalks[crosswalk] == nil then
			add(`6: NpcNode {id} Crosswalk = {crosswalk} is not a known crosswalk`)
		end
		nodeCount += 1
		nodes[id] = {
			Id = id,
			Position = positionOf(instance),
			Links = if raw then splitLinks(raw) else {},
			Crosswalk = crosswalk,
		}
	end
	if nodeCount > required.MaxNodes then
		add(`6: {nodeCount} nodes (max {required.MaxNodes})`)
	end
	for _, id in required.Nodes do
		if nodes[id] == nil then
			add(`6: required node {id} missing`)
		end
	end

	const adjacency, linkProblems = Graph.adjacency(nodes)
	for _, problem in linkProblems do
		add(problem)
	end

	const crosswalkNodes: { [string]: { string } } = {}
	for id, node in nodes do
		if node.Crosswalk ~= nil then
			const list = crosswalkNodes[node.Crosswalk] or {}
			crosswalkNodes[node.Crosswalk] = list
			table.insert(list, id)
		end
		for _, otherId in adjacency[id] do
			if id >= otherId then
				continue
			end
			const other = nodes[otherId]
			const length = (node.Position - other.Position).Magnitude
			if length > required.MaxEdge then
				add(`6: edge {id}-{otherId} is {string.format("%.1f", length)} studs (max {required.MaxEdge})`)
			end
			const crossing = Graph.isCrossing(node, other)
			const stripes = if crossing and node.Crosswalk then required.Crosswalks[node.Crosswalk] else nil
			const road, insideStripes = crossesRoad(node.Position, other.Position, required.Roads, stripes)
			if road ~= nil and not crossing then
				add(`6: edge {id}-{otherId} crosses the {road} carriageway outside a crosswalk`)
			elseif road ~= nil and crossing and not insideStripes then
				add(`6: crosswalk edge {id}-{otherId} leaves the stripes while on the road`)
			end
		end
	end
	for crosswalk, ids in crosswalkNodes do
		if #ids ~= 2 then
			add(`6: Crosswalk {crosswalk} on {#ids} node(s) (need exactly the 2 curb nodes)`)
		elseif not table.find(adjacency[ids[1]], ids[2]) then
			add(`6: Crosswalk {crosswalk} curb nodes {ids[1]} and {ids[2]} are not linked`)
		end
	end

	const start = if nodes["SP-A"] ~= nil then "SP-A" else next(nodes)
	if start ~= nil then
		const reached = Graph.reach(adjacency, start)
		for id in nodes do
			if not reached[id] then
				add(`6: node {id} not connected to {start}`)
			end
		end
	end
	for _, route in required.Routes do
		if nodes[route.From] ~= nil and nodes[route.To] ~= nil then
			if Graph.path(nodes, adjacency, route.From, route.To) == nil then
				add(`6: no path {route.From} -> {route.To} ({route.Name})`)
			end
		end
	end

	return problems
end

-- Mart v2 Gear Stand (TASK-135; MAP-01 §18.4): soft checks, returned as notes (PlaceService warns, never errors) so
-- the place keeps running while TASK-138 builds the kiosk. MarketController/OpalController fall back on their own.
--   pedestal: exactly one `PedestalTag` with Slot = each BenchSlot; a `Price_Anchor_<Slot>` (or `Price_Anchor`)
--     inside it; shutter: exactly one `ShutterTag` with Slot = each door key, holding `Slat_*` or `Door_Panel` parts
--     and a `Roll` / `Door_Drum` part; OP-1 facing the store (Q-175 A).
function MapIndex.KioskNotes(required: List): { string }
	const rule = required.Kiosk
	const notes: { string } = {}
	local function note(message: string)
		table.insert(notes, message)
	end

	local function bySlot(tag: string): { [string]: { Instance } }
		const out: { [string]: { Instance } } = {}
		for _, instance in tagged(tag) do
			const slot = stringAttribute(instance, rule.SlotAttribute)
			if slot == nil then
				note(`{tag} {nameOf(instance)} without {rule.SlotAttribute}`)
				continue
			end
			const list = out[slot] or {}
			out[slot] = list
			table.insert(list, instance)
		end
		return out
	end

	const pedestals = bySlot(rule.PedestalTag)
	for _, slot in rule.Pedestals do
		const list = pedestals[slot] or {}
		if #list ~= 1 then
			note(`{rule.PedestalTag} Slot = {slot} found {#list} time(s), need 1`)
		else
			const pedestal = list[1]
			if
				pedestal:FindFirstChild("Price_Anchor_" .. slot, true) == nil
				and pedestal:FindFirstChild("Price_Anchor", true) == nil
			then
				note(`{rule.PedestalTag} {slot}: no Price_Anchor_{slot} (the plate goes on the prompt anchor)`)
			end
		end
	end

	const shutters = bySlot(rule.ShutterTag)
	for _, key in rule.Shutters do
		const list = shutters[key] or {}
		if #list ~= 1 then
			note(`{rule.ShutterTag} Slot = {key} found {#list} time(s), need 1`)
			continue
		end
		local slats, roll = 0, false
		for _, part in list[1]:GetDescendants() do
			if part:IsA("BasePart") then
				if string.sub(part.Name, 1, 5) == "Slat_" or part.Name == "Door_Panel" then
					slats += 1
				elseif part.Name == "Roll" or part.Name == "Door_Drum" then
					roll = true
				end
			end
		end
		if slats == 0 then
			note(`{rule.ShutterTag} {key}: no Slat_* or Door_Panel part (the door will not move)`)
		end
		if not roll then
			note(`{rule.ShutterTag} {key}: no Roll / Door_Drum part (nothing turns)`)
		end
	end

	const point = MapIndex.FindPoint(rule.OpalPoint)
	if point == nil then
		note(`MapPoint {rule.OpalPoint} missing (Opal)`)
	elseif point.LookVector:Dot(rule.OpalFacing) < 0.9 then
		note(`MapPoint {rule.OpalPoint} does not face the store (MAP-01 §18.4: MAP east)`)
	end
	return notes
end

-- Pad tables (TASK-144; FEAT-037): soft checks, returned as notes (PlaceService warns, never errors) until TASK-149
-- binds the tables. Each TableIndex 1..Tables once on a `Tag` Model, with Seat1..SeatN BaseParts; optional anchors
-- (Prompt_BuyTable, Prompt_CleanTable, Tray_Anchor) noted when missing (SeatingService creates a runtime prompt).
function MapIndex.SeatingNotes(required: List): { string }
	const rule = required.Seating
	const notes: { string } = {}
	const byIndex: { [number]: { Instance } } = {}
	for _, instance in tagged(rule.Tag) do
		const index = instance:GetAttribute(rule.IndexAttribute)
		if typeof(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > rule.Tables then
			table.insert(notes, `{rule.Tag} {nameOf(instance)}: {rule.IndexAttribute} must be 1..{rule.Tables}`)
			continue
		end
		const list = byIndex[index] or {}
		byIndex[index] = list
		table.insert(list, instance)
	end
	for index = 1, rule.Tables do
		const list = byIndex[index] or {}
		if #list ~= 1 then
			table.insert(notes, `{rule.Tag} {rule.IndexAttribute} = {index} found {#list} time(s), need 1`)
			continue
		end
		const model = list[1]
		for seat = 1, rule.SeatCount do
			const part = model:FindFirstChild(`{rule.SeatPrefix}{seat}`, true)
			if part == nil or not part:IsA("BasePart") then
				table.insert(notes, `{rule.Tag} {index}: no BasePart {rule.SeatPrefix}{seat}`)
			end
		end
		for _, anchor in rule.Anchors do
			if model:FindFirstChild(anchor, true) == nil then
				table.insert(notes, `{rule.Tag} {index}: no {anchor} (optional)`)
			end
		end
	end
	return notes
end

return table.freeze(MapIndex)
