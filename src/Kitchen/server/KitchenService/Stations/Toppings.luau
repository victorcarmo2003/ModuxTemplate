--!strict
-- Topping bowls and bottles, station K (FEAT-006 step 6; DEC-071, DEC-072, DEC-156; architecture.md §18.4, §18.12;
-- content-data.md §3.6, §3.18; TASK-028). Station module of KitchenService (StationApi.Module).
-- "Add {item}" (topping_add, hold 0.5 s from Content.Actions; DEC-299) on the anchor Prompt_Use_<Suf>, whose Ingredient
-- attribute says the topping. Hot dog in hand (checked by the core from Requires.Held), topping not on it yet, fewer
-- than OrderRules.MaxToppings, Stock >= 1 and not Blocked: takes 1 unit and adds it to the hot dog.
-- No Stations record (Record = "None"): the state of every bowl is the Stock set (Amount, Blocked), so lid + padlock
-- of a locked bowl (DEC-156) and the hidden "Add X" with 0 left are drawn by the client from Stock. Restock on
-- Prompt_Restock_<Suf> is the core's. Nothing to snapshot: the amounts are "Stk".
-- Refusal toasts (D-04, TASK-080, via Refusal.luau), in this order: topping already on it -> topping_repeat {item};
-- MaxToppings reached -> topping_max; bowl empty -> out_of_stock {item}. Silent: no topping on the anchor, no hot dog
-- in hand (core's Requires.Held) and a Blocked bowl (locked bowl, DEC-156: only a forged request reaches it; read by
-- ctx.IsBlocked, TASK-057).
-- Gift bowls (owner request 2026-10-14, Provisional): "Open" (topping_unwrap) on Prompt_Unwrap_<Suf> opens a closed gift bowl
-- (ctx.IsWrapped) and fills it to capacity (ctx.Unwrap); a closed bowl refuses "Add" with topping_wrapped {item}.
-- World kitchen (kitchen-world.md §1 #9; TASK-569): the condiment table PRODUCTION (Pan_*, tag Station, StationKind toppings).
-- The plate with bun and sausage on it IS the hot_dog Tool (ctx.FillPlate turns it), so "Add {item}" takes the hot dog in
-- hand as before; an empty or half plate never shows it (Requires.Held = hot_dog).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Refusal = require(script.Parent.Parent.Refusal)

const ACTION = "topping_add"
const UNWRAP = "topping_unwrap"
const HOT_DOG = "hot_dog"

-- Topping key of the anchor (a Sauce/Topping of Content.Ingredients), else nil.
local function toppingOf(anchor: Instance): string?
	const key = anchor:GetAttribute("Ingredient")
	if type(key) == "string" and table.find(Content.Ingredients.ToppingKeys, key) then
		return key
	end
	return nil
end

-- Toppings already on a hot dog, read from the Tool attribute ItemService writes (network.md §7.1).
local function toppingsOn(tool: Tool): { string }
	const out: { string } = {}
	const raw = tool:GetAttribute("Toppings")
	if type(raw) ~= "string" or raw == "" then
		return out
	end
	for _, key in string.split(raw, ",") do
		if key ~= "" then
			table.insert(out, key)
		end
	end
	return out
end

-- Hot dog in the player's hand (ctx.Held only returns Tools created by ItemService).
local function heldHotDog(ctx: StationApi.Context, player: Player): Tool?
	const tool = ctx.Held(player)
	if tool ~= nil and tool:GetAttribute("Item") == HOT_DOG then
		return tool
	end
	return nil
end

-- (tool?, ingredient?, notice?). Everything except Blocked, which TakeStock refuses atomically in Run; Blocked only
-- silences the toast.
local function canAdd(
	ctx: StationApi.Context,
	_station: StationApi.Station,
	player: Player,
	anchor: Instance
): (Tool?, string?, string?)
	const ingredient = toppingOf(anchor)
	if ingredient == nil then
		return nil, nil, nil
	end
	const tool = heldHotDog(ctx, player)
	if tool == nil then
		return nil, nil, nil
	end
	if ctx.IsBlocked(ingredient) then
		return nil, ingredient, nil
	end
	if ctx.IsWrapped(ingredient) then
		return nil, ingredient, "topping_wrapped"
	end
	const toppings = toppingsOn(tool)
	if table.find(toppings, ingredient) then
		return nil, ingredient, "topping_repeat"
	end
	if #toppings >= Content.OrderRules.MaxToppings then
		return nil, ingredient, "topping_max"
	end
	if ctx.GetStock(ingredient) < 1 then
		return nil, ingredient, "out_of_stock"
	end
	return tool, ingredient, nil
end

-- Adds the topping to the held Tool (same Tool; ItemService refreshes HotDogVisual).
local function addTopping(ctx: StationApi.Context, _player: Player, tool: Tool, ingredient: string): boolean
	return ctx.AddTopping(tool, ingredient)
end

const Toppings: StationApi.Module = {
	Kinds = { "toppings" },
	Actions = {
		[ACTION] = {
			Validate = function(ctx: StationApi.Context, station: StationApi.Station, player: Player, anchor: Instance)
				const tool, ingredient, notice = canAdd(ctx, station, player, anchor)
				if notice == "topping_max" then
					Refusal.notify(ctx, player, notice, nil)
				elseif notice ~= nil and ingredient ~= nil then
					Refusal.notify(ctx, player, notice, Refusal.ingredient(ingredient))
				end
				return tool ~= nil, nil
			end,
			-- Runs inside the station lock: revalidate, take the unit, then add. TakeStock refuses Blocked and an
			-- emptied bowl (another player took the last unit while this one waited).
			Run = function(ctx: StationApi.Context, station: StationApi.Station, player: Player, anchor: Instance)
				const tool, ingredient = canAdd(ctx, station, player, anchor)
				if tool == nil or ingredient == nil then
					return
				end
				if not ctx.TakeStock(ingredient, 1) then
					return
				end
				if not addTopping(ctx, player, tool, ingredient) then
					warn(`[Toppings] {ingredient} taken from stock but not added to the hot dog of {player.Name}`)
				end
			end,
		},
		[UNWRAP] = {
			Validate = function(ctx: StationApi.Context, _station: StationApi.Station, _player: Player, anchor: Instance)
				const ingredient = toppingOf(anchor)
				return ingredient ~= nil and ctx.IsWrapped(ingredient), nil
			end,
			-- inside the station lock: the first "Open" wins, a second one in the same frame finds it open
			Run = function(ctx: StationApi.Context, _station: StationApi.Station, _player: Player, anchor: Instance)
				const ingredient = toppingOf(anchor)
				if ingredient ~= nil then
					ctx.Unwrap(ingredient)
				end
			end,
		},
	},
	Bind = function(_ctx: StationApi.Context, station: StationApi.Station)
		for _, anchor in station.Anchors do
			if anchor:GetAttribute("PromptAction") == ACTION and toppingOf(anchor) == nil then
				warn(`[Toppings] {anchor:GetFullName()}: topping_add anchor without a topping Ingredient attribute`)
			end
		end
	end,
	Capture = function(_ctx: StationApi.Context, _station: StationApi.Station): any
		return nil
	end,
	Restore = function(_ctx: StationApi.Context, _station: StationApi.Station, _data: any) end,
}

return Toppings
