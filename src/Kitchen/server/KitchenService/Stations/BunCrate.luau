--!strict
-- Bun crate (FEAT-006 step 4; DEC-190, DEC-215; architecture.md §18.4, §18.12; TASK-027). StationKind "bun_crate".
--   bun_cut (Prompt_Take, hold 0.5 s "Slice Bun")  1 bun from stock -> lowest free slot of the vehicle's board
--           (Board.luau), sliced in Content.Stations.bun_crate.Params.CutTime (1.5 s). The unit leaves the stock only
--           together with a free slot (never one without the other).
-- Restock on Prompt_Restock is the core's (KitchenService). No Stations record: the board slot carries the state.
-- Prompts (Provisional, TASK-027, same rule as "Grill"): "Slice Bun" off while the board has no free slot or the bun
-- stock is 0. Snapshot: nothing kept (the amount is "Stk").
-- Refusal toasts (D-04, TASK-080, via Refusal.luau): no bun in stock -> out_of_stock {item}; board without a free slot
-- -> board_full. A vehicle without a board stays silent (map problem, not the player's).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local StationApi = require(script.Parent.Parent.StationApi)
local Board = require(script.Parent.Board)
local Refusal = require(script.Parent.Parent.Refusal)

type Context = StationApi.Context
type Station = StationApi.Station

const KIND = "bun_crate"
const CUT = "bun_cut"
const BUN = "bun"
const DURATION_STEP = 0.1 -- Stations.Duration is quant(0, 120, 0.1)
const DURATION_MAX = 120

local function ingredientOf(station: Station): string
	return station.Ingredient or BUN
end

local function cutTime(): number
	const row = Content.Stations.ByKey[KIND]
	const seconds = if row then row.Params.CutTime or 0 else 0
	const rounded = math.floor(seconds / DURATION_STEP + 0.5) * DURATION_STEP
	return math.clamp(rounded, DURATION_STEP, DURATION_MAX)
end

-- (ok, notice?): stock first (restocking is what the player can do), then a free board slot.
local function canCut(ctx: Context, station: Station): (boolean, string?)
	if station.Kind ~= KIND or Board.Find(station.Vehicle) == nil then
		return false, nil
	end
	if ctx.GetStock(ingredientOf(station)) < 1 then
		return false, "out_of_stock"
	end
	if Board.Free(station.Vehicle) == nil then
		return false, "board_full"
	end
	return true, nil
end

local function refreshCut(ctx: Context, station: Station)
	const enabled = (canCut(ctx, station))
	for _, anchor in station.Anchors do
		if anchor:GetAttribute("PromptAction") == CUT and anchor:GetAttribute("PromptEnabled") ~= enabled then
			ctx.SetPrompt(anchor, enabled, nil)
		end
	end
end

const cut: StationApi.Action = {
	Validate = function(ctx: Context, station: Station, player: Player, _anchor: Instance): (boolean, string?)
		const ok, notice = canCut(ctx, station)
		if notice == "out_of_stock" then
			Refusal.notify(ctx, player, notice, Refusal.ingredient(ingredientOf(station)))
		elseif notice ~= nil then
			Refusal.notify(ctx, player, notice, nil)
		end
		return ok, nil
	end,
	-- Inside the crate lock; Board.Free/Place and TakeStock are synchronous, so no other bun_cut takes the same slot.
	Run = function(ctx: Context, station: Station, _player: Player, _anchor: Instance)
		const slot = Board.Free(station.Vehicle)
		if slot == nil then
			return
		end
		if not ctx.TakeStock(ingredientOf(station), 1) then
			return
		end
		if not Board.Place(ctx, station.Vehicle, slot, cutTime()) then
			warn(`[BunCrate] bun taken from stock but board slot {slot} of {station.Vehicle} refused it`)
		end
		refreshCut(ctx, station)
	end,
}

const BunCrate: StationApi.Module = {
	Kinds = { KIND },
	Actions = {
		[CUT] = cut,
	},
	Bind = function(ctx: Context, station: Station)
		station.State = nil
		refreshCut(ctx, station)
	end,
	-- 10 Hz, current vehicle only: keep "Slice Bun" in step with the stock and the board.
	Tick = function(ctx: Context, station: Station, _now: number)
		refreshCut(ctx, station)
	end,
	Capture = function(_ctx: Context, _station: Station): any
		return nil
	end,
	Restore = function(ctx: Context, station: Station, _data: any)
		refreshCut(ctx, station)
	end,
}

return BunCrate
