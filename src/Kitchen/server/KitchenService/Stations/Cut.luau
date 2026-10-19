--!strict
-- Restaurant cutting board CUT-n (tech/restaurant-flow.md rev. 2 §2.3, §3.3; design/restaurant-flow.md FEAT-045; TASK-378).
-- StationKind "cut" (Record "None", Ingredient "bun"; the stock is Stock.bun, shared with the trailer's bun crate).
--   bun_slice (hold Content.Actions.bun_slice.Hold "Slice Bun")  1 bun from stock -> one more piece on the bun_sliced stack
--             in hand (Tool Count, cap Content.Restaurant.Stacks.Bun), or a new bun_sliced Tool (ItemService limits:
--             hotbar and CategoryLimits.Ingredient; refusal = hands_full from ItemService).
-- Restock on Prompt_Restock is the core's (KitchenService, row Actions "restock").
-- Everything is behind Content.Restaurant.Rules.Enabled: false = prompt off and the action refused (the published map has no
-- CUT-n anyway). Prompt off while the bun stock is 0 (same rule as the bun crate / "Grill"); a refused hold says why.
-- Conveyor (TASK-496; prep-conveyor.md §1.1; Content.Prep.Rules.Mode = "Conveyor", i.e. the restaurant): CUT-n is scenery and a
-- focus anchor of the belt; "Slice Bun" stays off and bun_slice is refused, so no bun_sliced Tool is ever made. The selector is
-- Prep.Rules.Mode (DT-E1); with the trailer there is no CUT-n on the map.
-- Cadence: the hold is the client's, so the server refuses a second slice by the same player sooner than the hold
-- (Content.Restaurant.Bun.CutHold minus a network slack). No Stations record. Snapshot: nothing kept (the amount is "Stk").
-- Refusal toasts (Refusal.luau): no bun -> out_of_stock {item}; stack full and no room for a new Tool -> hands_full.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

-- Private state of a cutting board: server time of each player's last slice (cadence check).
type CutState = { Last: { [Player]: number } }

const KIND = "cut"
const SLICE = "bun_slice"
const BUN = "bun"
const ITEM = "bun_sliced"
const HOLD_SLACK = 0.2 -- s: a slice this much sooner than the hold still counts (network jitter)
const CONVEYOR = "Conveyor"

-- the F2 world kitchen: restaurant map on and the prep not in the conveyor (never true since TASK-513; TASK-506 cleans up)
local function enabled(): boolean
	return Content.Prep.Rules.Mode ~= CONVEYOR
end

local function ingredientOf(station: Station): string
	return station.Ingredient or BUN
end

local function stateOf(station: Station): CutState
	const state = station.State
	if type(state) == "table" and type(state.Last) == "table" then
		return state :: CutState
	end
	const fresh: CutState = { Last = {} }
	station.State = fresh
	return fresh
end

local function stackCap(): number
	return math.max(math.floor(Content.Restaurant.Stacks.Bun), 1)
end

-- Held bun_sliced stack with room for one more piece, and its Count.
local function heldStack(ctx: Context, player: Player): (Tool?, number)
	const tool = ctx.Held(player)
	if tool == nil or tool:GetAttribute("Item") ~= ITEM then
		return nil, 0
	end
	const raw = tool:GetAttribute("Count")
	const count = if type(raw) == "number" then math.floor(raw) else 1
	if count >= stackCap() then
		return nil, count
	end
	return tool, count
end

-- (ok, notice?): restaurant on, stock first (restocking is what the player can do), then the cadence.
local function canSlice(ctx: Context, station: Station, player: Player?): (boolean, string?)
	if not enabled() or station.Kind ~= KIND then
		return false, nil
	end
	if ctx.GetStock(ingredientOf(station)) < 1 then
		return false, "out_of_stock"
	end
	if player ~= nil then
		const last = stateOf(station).Last[player]
		if last ~= nil and ctx.Now() - last < Content.Restaurant.Bun.CutHold - HOLD_SLACK then
			return false, nil
		end
	end
	return true, nil
end

local function refreshSlice(ctx: Context, station: Station)
	const on = (canSlice(ctx, station, nil))
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") == SLICE and anchor:GetAttribute("PromptEnabled") ~= on then
			ctx.SetPrompt(anchor, on, nil)
		end
	end
end

local function prune(state: CutState)
	for player in state.Last do
		if player.Parent == nil then
			state.Last[player] = nil
		end
	end
end

const slice: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, _anchor: Instance): (boolean, string?)
		const ok, notice = canSlice(ctx, station, player)
		if notice == "out_of_stock" then
			Refusal.notify(ctx, player, notice, Refusal.ingredient(ingredientOf(station)))
		end
		return ok, nil
	end,
	-- Inside the station lock, synchronous: the Tool first (it can be refused by the hand limits), then the stock unit, so
	-- a bun never leaves the stock without reaching a hand.
	Run = function(ctx: Context, station: Station, player: Player, _anchor: Instance)
		const tool, count = heldStack(ctx, player)
		if tool ~= nil then
			-- one more piece on the held stack: the same slot of the hotbar, re-created with Count + 1
			ctx.Consume(player, tool)
			if not ctx.Give(player, ITEM, { Count = count + 1 }) then
				warn(`[Cut] bun_sliced stack of {player.Name} lost on restack ({count})`)
				return
			end
		elseif not ctx.Give(player, ITEM, { Count = 1 }) then
			return -- ItemService already told the player (hands_full)
		end
		if not ctx.TakeStock(ingredientOf(station), 1) then
			warn(`[Cut] bun_sliced given to {player.Name} but Stock.{ingredientOf(station)} refused the unit`)
		end
		const state = stateOf(station)
		prune(state)
		state.Last[player] = ctx.Now()
		refreshSlice(ctx, station)
	end,
}

const Cut: StationApi.Module = {
	Kinds = { KIND },
	Actions = {
		[SLICE] = slice,
	},
	Bind = function(ctx: Context, station: Station)
		station.State = { Last = {} } :: CutState
		refreshSlice(ctx, station)
	end,
	-- 10 Hz, current vehicle only: keep "Slice Bun" in step with the stock and the flag.
	Tick = function(ctx: Context, station: Station, _now: number)
		refreshSlice(ctx, station)
	end,
	Capture = function(_ctx: Context, _station: Station): any
		return nil
	end,
	Restore = function(ctx: Context, station: Station, _data: any)
		table.clear(stateOf(station).Last)
		refreshSlice(ctx, station)
	end,
}

return Cut
