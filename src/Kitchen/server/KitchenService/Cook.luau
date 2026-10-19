--!strict
-- Cooking focus, server side (docs/tech/kitchen-focus.md; owner 2026-10-19). Part of KitchenService (it owns the stations, the
-- stock and the station locks); plain module: `kitchen` is the KitchenService instance.
--   Focus stations (found on Start, no Studio binding needed): Grill = the grill of the vehicle; Toppings = the folder holding the
--   toppings stations (PRODUCTION/Pan_*); Board = the Model with attribute CookStation = "Board", else the one named
--   Content.Restaurant.Binding.CookBoard (TLR-CUTTING_BOARD). Each gets one Prompt_Cook anchor (PromptAction cook_focus,
--   attribute Cook = the station, PromptText per station) unless the map authored one.
--   cook_focus  Validate: active player and what the station needs in hand (Board: a plate without a bun; Toppings: the hot dog
--               of a plate; Grill: nothing). Run: CookOpen to the player (the client moves the camera and takes the gestures).
--   Cook packet one gesture, committed here inside the right station lock:
--     Cut      plate in hand without a bun: 1 bun from the stock -> Bun on the plate, Scores.cut = Score
--     Place    a sausage from the stock onto the free grill slot `Slot`
--     Flip     flips the sausage of `Slot` (the score comes from the server clock, Grill.FlipAt)
--     Dog      the Ready sausage of `Slot` -> the plate (needs its bun; plate_needs_bun), Scores.dog = Score, Scores.flip
--     Topping  `Key` on the hot dog in hand (stock, repeat, MaxToppings, gift bowl, locked), Scores[Key] = Score, the drawn
--              sauce `Points` into the Tool attribute Sauce (HotDogVisual.Sauce)
-- Every gesture also needs the player within REACH studs of the focused station. Refusals = toasts (Refusal). The scores are the
-- client's measure, clamped 0..100 (Provisional, as the old prep: kitchen-focus.md §3).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local Sauce = require(ReplicatedStorage.shared.Item.HotDogVisual.Sauce)
local StationApi = require(script.Parent.StationApi)
local Refusal = require(script.Parent.Refusal)
local Grill = require(script.Parent.Stations.Grill)

export type Station = "Board" | "Grill" | "Toppings"

-- One gesture as the Cook packet carries it
export type Act = { Act: string, Slot: number, Score: number, Key: string?, Points: { number }? }

export type Cook = {
	Start: () -> (),
	Register: () -> (),
	Target: (station: Station) -> Instance?,
	-- the Cook packet's path (reach and rate checked); the dev smoke calls it too
	Act: (player: Player, data: Act) -> (),
}

const ACTION = "cook_focus"
const ANCHOR_TAG = "Interactable"
const ANCHOR_NAME = "Prompt_Cook"
const COOK_ATTRIBUTE = "Cook"
const STATION_ATTRIBUTE = "CookStation"
const REACH = 16 -- studs from the focused station a gesture is accepted (the camera is over it, the body stands by it)
const RATE = 12 -- gestures per second per player
const BUN = "bun"
const PROMPT_TEXT: { [Station]: string } = { Board = "Cut Bun", Grill = "Grill", Toppings = "Toppings" }
const PLATE = PlateTool.Plate
const HOT_DOG = PlateTool.HotDog
const ATTR = PlateTool.Attr

type Bucket = { Tokens: number, At: number }

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	-- a Folder: the middle of its parts
	local sum, count = Vector3.zero, 0
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			sum += part.Position
			count += 1
		end
	end
	return if count > 0 then sum / count else nil
end

const Cook = {}

function Cook.new(kitchen: any): Cook
	const targets: { [Station]: Instance } = {}
	const buckets: { [Player]: Bucket } = {}

	local function items(): any
		return kitchen.Dependencies.ItemService
	end

	local function notify(player: Player, notice: string, value: number?)
		Refusal.notify(kitchen.Context, player, notice, value)
	end

	local function held(player: Player, item: string): Tool?
		const tool = items():GetHeld(player)
		return if tool ~= nil and items():ItemOf(tool) == item then tool else nil
	end

	local function near(player: Player, station: Station): boolean
		const target = targets[station]
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		const at = if target then positionOf(target) else nil
		return root ~= nil and root:IsA("BasePart") and at ~= nil and (root.Position - at).Magnitude <= REACH
	end

	local function allow(player: Player): boolean
		const t = os.clock()
		local bucket = buckets[player]
		if bucket == nil then
			bucket = { Tokens = RATE, At = t }
			buckets[player] = bucket
		end
		bucket.Tokens = math.min(RATE, bucket.Tokens + (t - bucket.At) * RATE)
		bucket.At = t
		if bucket.Tokens < 1 then
			return false
		end
		bucket.Tokens -= 1
		return true
	end

	-- The anchor of a focus station: an authored one (PromptAction cook_focus inside it), else one made over its middle
	local function ensureAnchor(station: Station, target: Instance)
		for _, child in target:GetDescendants() do
			if child:GetAttribute("PromptAction") == ACTION then
				child:SetAttribute(COOK_ATTRIBUTE, station)
				return
			end
		end
		local host: BasePart? = nil
		local best = math.huge
		const middle = positionOf(target)
		for _, part in target:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 and middle ~= nil then
				const distance = (part.Position - middle).Magnitude
				if distance < best then
					host = part
					best = distance
				end
			end
		end
		if host == nil or middle == nil then
			warn(`[KitchenService] cook focus {station}: {target:GetFullName()} has no visible part to hang Prompt_Cook on`)
			return
		end
		const anchor = Instance.new("Attachment")
		anchor.Name = ANCHOR_NAME
		anchor:SetAttribute("PromptAction", ACTION)
		anchor:SetAttribute(COOK_ATTRIBUTE, station)
		anchor:SetAttribute("PromptText", PROMPT_TEXT[station])
		anchor.Parent = host
		anchor.WorldPosition = middle + Vector3.new(0, 0.9, 0)
		CollectionService:AddTag(anchor, ANCHOR_TAG)
	end

	local function find()
		const vehicle = kitchen:GetVehicle()
		const grill = Grill.Find(vehicle)
		if grill ~= nil then
			targets.Grill = grill.Instance
		end
		for _, station in kitchen.Stations do
			if station.Kind == "toppings" and station.Vehicle == vehicle and station.Instance.Parent ~= nil then
				const parent = station.Instance.Parent :: Instance
				-- the pans share a folder (PRODUCTION): the folder is the focus; a lone toppings station is its own focus
				targets.Toppings = if parent:IsA("Folder") then parent else station.Instance
				break
			end
		end
		const binding = Content.Restaurant.Binding
		for _, instance in workspace:GetDescendants() do
			if instance:IsA("Model") and instance:GetAttribute(STATION_ATTRIBUTE) == "Board" then
				targets.Board = instance
				break
			end
		end
		if targets.Board == nil then
			const named = workspace:FindFirstChild(binding.CookBoard, true)
			if named ~= nil and named:IsA("Model") then
				targets.Board = named
			end
		end
		for station, target in targets do
			ensureAnchor(station, target)
		end
		for _, station in { "Board", "Grill", "Toppings" } :: { Station } do
			if targets[station] == nil then
				warn(`[KitchenService] cook focus: no {station} station in the map`)
			end
		end
	end

	local function stationOf(anchor: Instance): Station?
		const value = anchor:GetAttribute(COOK_ATTRIBUTE)
		if value == "Board" or value == "Grill" or value == "Toppings" then
			return value
		end
		return nil
	end

	-- What the station needs in the hand before it opens (the toast says it)
	local function canOpen(player: Player, station: Station): boolean
		if station == "Board" then
			const plate = held(player, PLATE)
			if plate == nil then
				notify(player, "need_plate")
				return false
			elseif plate:GetAttribute(ATTR.Bun) == true then
				notify(player, "plate_full")
				return false
			end
		elseif station == "Toppings" then
			const hotDog = held(player, HOT_DOG)
			if hotDog == nil or PlateTool.Id(hotDog) <= 0 then
				notify(player, "need_hot_dog")
				return false
			end
		end
		return true
	end

	-- Gestures -------------------------------------------------------------------------------------------------------

	local function cut(player: Player, score: number)
		const plate = held(player, PLATE)
		if plate == nil then
			notify(player, "need_plate")
			return
		elseif plate:GetAttribute(ATTR.Bun) == true then
			notify(player, "plate_full")
			return
		end
		const crate = kitchen:CurrentStation("bun_crate")
		const run = function()
			if kitchen:IsBlocked(BUN) or not kitchen:TakeStock(BUN, 1) then
				notify(player, "out_of_stock", Refusal.ingredient(BUN))
				return
			end
			if kitchen:FillPlate(player, plate, "Bun", {}) then
				PlateTool.SetScore(plate, "cut", score)
			end
		end
		if crate ~= nil then
			kitchen:Serialize(crate, run)
		else
			run()
		end
	end

	local function grillCall(player: Player, act: string, slot: number, score: number)
		const grill = Grill.Find(kitchen:GetVehicle())
		if grill == nil then
			return
		end
		kitchen:Serialize(grill, function()
			const ctx = kitchen.Context
			if act == "Place" then
				const stock = kitchen:CurrentStation("sausage_stock")
				if stock == nil then
					return
				end
				const ok, notice = Grill.PlaceAt(ctx, grill, stock, player, slot)
				if not ok and notice == "out_of_stock" then
					notify(player, notice, Refusal.ingredient("sausage"))
				elseif not ok and notice ~= nil then
					notify(player, notice)
				end
			elseif act == "Flip" then
				Grill.FlipAt(ctx, grill, slot, player:GetNetworkPing())
			elseif act == "Dog" then
				const plate = held(player, PLATE)
				if plate == nil then
					notify(player, "need_plate")
					return
				elseif plate:GetAttribute(ATTR.Bun) ~= true then
					notify(player, "plate_needs_bun")
					return
				elseif plate:GetAttribute(ATTR.Sausage) == true then
					notify(player, "plate_full")
					return
				end
				const record = grill.Records[slot]
				if record == nil or record.State ~= "Ready" then
					return
				end
				-- the scores first: FillPlate turns the plate into the hot dog, which carries Scores over
				PlateTool.SetScore(plate, "dog", score)
				PlateTool.SetScore(plate, "flip", Content.Prep.Grades.Unflipped)
				const taken, flip = Grill.TakeReady(ctx, grill, slot)
				if not taken then
					return
				end
				if flip ~= nil then
					PlateTool.SetScore(plate, "flip", flip)
				end
				const bonus = flip ~= nil and flip >= Content.Prep.Grades.Bands.Good
				if not kitchen:FillPlate(player, plate, "Sausage", { Flipped = bonus }) then
					warn(`[KitchenService] {player.Name}: a sausage left the grill but the plate refused it`)
				end
			end
		end)
	end

	local function topping(player: Player, key: string, score: number, points: { number }?)
		const hotDog = held(player, HOT_DOG)
		if hotDog == nil or PlateTool.Id(hotDog) <= 0 then
			notify(player, "need_hot_dog")
			return
		end
		local pan: StationApi.Station? = nil
		const vehicle = kitchen:GetVehicle()
		for _, station in kitchen.Stations do
			if station.Kind == "toppings" and station.Vehicle == vehicle then
				pan = station
				break
			end
		end
		const run = function()
			const item = Refusal.ingredient(key)
			if kitchen:IsBlocked(key) then
				return
			elseif kitchen:IsWrapped(key) then
				notify(player, "topping_wrapped", item)
				return
			end
			const toppings = items():Toppings(hotDog)
			if table.find(toppings, key) then
				notify(player, "topping_repeat", item)
				return
			elseif #toppings >= Content.OrderRules.MaxToppings then
				notify(player, "topping_max")
				return
			elseif not kitchen:TakeStock(key, 1) then
				notify(player, "out_of_stock", item)
				return
			end
			if not items():AddTopping(hotDog, key) then
				return
			end
			PlateTool.SetScore(hotDog, key, score)
			const clean = if points ~= nil then Sauce.Clean(points) else nil
			if clean ~= nil then
				const sauces: { [string]: { number } } = {}
				for name, segments in Sauce.Decode(hotDog:GetAttribute(Sauce.Attribute)) do
					sauces[name] = Sauce.Pack(segments)
				end
				sauces[key] = clean
				items():SetSauce(hotDog, Sauce.Encode(sauces))
			end
		end
		if pan ~= nil then
			kitchen:Serialize(pan, run)
		else
			run()
		end
	end

	local function act(player: Player, data: Act)
		if not kitchen.Active or not kitchen.Dependencies.RunStateService:IsActive(player) or not allow(player) then
			return
		end
		const kind = data.Act
		const station: Station = if kind == "Cut" then "Board" elseif kind == "Topping" then "Toppings" else "Grill"
		if not near(player, station) then
			return
		end
		const score = math.clamp(math.floor(data.Score), 0, 100)
		if kind == "Cut" then
			cut(player, score)
		elseif kind == "Topping" then
			if data.Key ~= nil then
				topping(player, data.Key, score, data.Points)
			end
		elseif data.Slot >= 1 then
			grillCall(player, kind, data.Slot, score)
		end
	end

	-- API ------------------------------------------------------------------------------------------------------------

	const self: Cook = {
		Start = function()
			find()
		end,
		Register = function()
			const interaction = kitchen.Dependencies.InteractionService
			interaction:RegisterAction(ACTION, {
				Validate = function(player: Player, anchor: Instance, _id: number): boolean
					const station = stationOf(anchor)
					if not kitchen.Active or station == nil or targets[station] == nil then
						return false
					end
					if not kitchen.Dependencies.RunStateService:IsActive(player) then
						return false
					end
					return canOpen(player, station)
				end,
				Run = function(player: Player, anchor: Instance, _id: number)
					const station = stationOf(anchor)
					const target = if station then targets[station] else nil
					if station == nil or target == nil then
						return
					end
					Restaurant.CookOpen:fireClient(player, { Station = station, Target = target })
				end,
			})
			Restaurant.Cook:onServer(function(data, player: Player)
				act(player, data :: any)
			end)
			Players.PlayerRemoving:Connect(function(player: Player)
				buckets[player] = nil
			end)
		end,
		Target = function(station: Station): Instance?
			return targets[station]
		end,
		Act = act,
	}
	return self
end

return table.freeze(Cook)
