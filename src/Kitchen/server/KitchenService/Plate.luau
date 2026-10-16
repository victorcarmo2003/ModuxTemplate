--!strict
-- Prep mode plate and grill moves (TASK-169; docs/tech/prep-mode.md §2 "Finish", §6, §7; FEAT-039; DEC-223; DEC-072).
-- Plain module (no Modux, Lync or atoms): KitchenService builds one with Plate.new(deps) in OnInit and exposes it as
-- BeginPlate / FinishPlate / RefundPlate / TrashPlate / GrillAct / PlateOf. PrepService (TASK-170) is the caller; it owns
-- seats, sessions, the phase and the plausibility checks, this module owns what the kitchen holds:
--   BeginPlate    reserves 1 bun (TakeStock) and one board slot (the seat's, else the lowest free one). One plate per
--                 player. A sliced altered bun (ANM-002) already on the board is adopted instead: no stock, PreCut.
--   FinishPlate   all or nothing: refuses without touching anything when a topping is blocked/out of stock, the rail has
--                 no sausage or the hotbar is full. Then (all synchronous, no yield) Give the hot dog first, Pop the
--                 front sausage of the rail (its flip score comes back), take 1 use of every topping, free the slot,
--                 emit "assembled". Never leaves a half-made plate.
--   RefundPlate   Leave / disconnect / timeout: the reserved bun goes back to the stock (an adopted altered bun goes back
--                 to the board as it was) and the slot frees up.
--   TrashPlate    the bin: bun (and, on request, the front sausage) are lost like Trash.luau; a hot dog in hand goes
--                 through the BIN-C "discard" path so the Discarded signal of ANM-002 still fires. TASK-346 (DEC-254:
--                 ANM-002 is family A, discarding resolves it): an adopted altered bun is thrown away too and fires
--                 Discarded (bun, Altered). The altered sausage of the rail is still never popped from here.
--   GrillAct      Place / Flip / Collect, the grill moves without a prompt (Stations/Grill.luau).
--   TrashSausage  the bin by drag: a sausage of a grill slot or of the rail is thrown away (2026-10-12).
-- Results are (value?, reason?): reason is a Content.Prep.Reasons key (NoSession, NoStock, NoSausage, HandsFull, Busy,
-- NoStation, Invalid). The plate band travels in ItemService:Give options (Quality, TASK-171).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local StationApi = require(script.Parent.StationApi)
local Refusal = require(script.Parent.Refusal)
local Board = require(script.Parent.Stations.Board)
local Grill = require(script.Parent.Stations.Grill)
local Rail = require(script.Parent.Stations.Rail)

type Context = StationApi.Context
type Station = StationApi.Station

-- What an open plate holds (readable copy through Plate.of).
export type Ticket = {
	Slot: number, -- board slot held
	Altered: boolean, -- adopted the altered bun (ANM-002)
	PreCut: boolean, -- the bun is already sliced (altered): the client skips the cut
	Stocked: boolean, -- a bun unit left the stock for this plate (refunded by RefundPlate)
	Since: number, -- server time of BeginPlate
}

export type Spec = {
	Toppings: { string }, -- toppings keys, unique, <= OrderRules.MaxToppings
	Quality: string?, -- "Perfect" | "Good" | "Messy" (Content.Prep.Grades.Labels keys); nil = not graded
}

export type Result = {
	Tool: Tool, -- the hot dog, already in the hotbar
	Altered: boolean, -- made with an altered bun or sausage
	SausageScore: number?, -- grill flip score stamped by the server (nil = ungraded, feed Grade.Plate as-is)
	Slot: number,
}

export type TrashOptions = {
	Sausage: boolean?, -- also lose the front sausage of the rail
	Hand: boolean?, -- also throw away the hot dog in hand (BIN-C path)
}

export type TrashResult = { Bun: boolean, Sausage: boolean, Hand: boolean }

export type GrillAction = "Place" | "Flip" | "Collect"

export type GrillResult = {
	Slot: number, -- slot placed / flipped / collected
	Score: number?, -- Flip: flip score now; Collect: the score the sausage carries (nil = ungraded)
	Band: string?, -- band of Score
}

export type Deps = {
	Context: Context,
	Vehicle: () -> string, -- current vehicle
	IsMember: (player: Player) -> boolean,
	Station: (kind: string) -> Station?, -- station of the current vehicle by kind
	Refund: (ingredient: string, n: number) -> (), -- unit(s) back to the stock (may read above capacity, Q-169)
	CanGive: (player: Player) -> boolean, -- room in the hotbar for a hot dog
	Give: (player: Player, toppings: string, altered: boolean, quality: string?) -> Tool?,
	Discard: (player: Player) -> boolean, -- BIN-C "discard" of the hot dog in hand
	Discarded: (player: Player, item: string) -> (), -- an altered item thrown away by the prep bin (Discarded, Altered = true)
}

export type TrashFrom = "Grill" | "Rail"

export type PlateApi = {
	TrashSausage: (player: Player, from: TrashFrom, slot: number) -> (boolean, string?),
	Begin: (player: Player, slot: number?) -> (Ticket?, string?),
	Finish: (player: Player, spec: Spec) -> (Result?, string?),
	Refund: (player: Player) -> boolean,
	Trash: (player: Player, options: TrashOptions?) -> TrashResult,
	Grill: (player: Player, act: GrillAction, slot: number?) -> (GrillResult?, string?),
	Of: (player: Player) -> Ticket?,
}

const BUN = "bun"
const MAX_SLOT = 99

const Plate = {}

local function isSlot(value: any): boolean
	return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= MAX_SLOT
end

-- Spec check that touches nothing: false = the summary is not a plate this module can make.
local function validSpec(spec: any): boolean
	if type(spec) ~= "table" or type(spec.Toppings) ~= "table" then
		return false
	end
	const toppings = spec.Toppings :: { any }
	if #toppings > Content.OrderRules.MaxToppings then
		return false
	end
	const seen: { [string]: boolean } = {}
	for _, key in toppings do
		if type(key) ~= "string" or seen[key] or not table.find(Content.Ingredients.ToppingKeys, key) then
			return false
		end
		seen[key] = true
	end
	const quality = spec.Quality
	return quality == nil or (type(quality) == "string" and Content.Prep.Grades.Labels[quality :: Grade.Band] ~= nil)
end

function Plate.new(deps: Deps): PlateApi
	const ctx = deps.Context
	-- Open plate by player (one each)
	const plates: { [Player]: Ticket } = {}

	local function copy(ticket: Ticket): Ticket
		return table.clone(ticket)
	end

	-- Frees the board slot of a plate; keep = an altered bun stays on the board as it was.
	local function release(ticket: Ticket, keep: boolean)
		Board.Release(ctx, deps.Vehicle(), ticket.Slot, keep)
	end

	local function begin(player: Player, slot: number?): (Ticket?, string?)
		if not deps.IsMember(player) or (slot ~= nil and not isSlot(slot)) then
			return nil, "Invalid"
		end
		if plates[player] ~= nil then
			return nil, "Busy"
		end
		const vehicle = deps.Vehicle()
		if Board.Find(vehicle) == nil or Rail.Find(vehicle) == nil then
			return nil, "NoStation"
		end
		const now = ctx.Now()
		const altered = Board.ClaimAltered(ctx, vehicle, slot)
		if altered ~= nil then
			const ticket: Ticket = { Slot = altered, Altered = true, PreCut = true, Stocked = false, Since = now }
			plates[player] = ticket
			return copy(ticket), nil
		end
		if ctx.IsBlocked(BUN) or ctx.GetStock(BUN) < 1 then
			return nil, "NoStock"
		end
		const held = Board.Reserve(ctx, vehicle, slot, Content.Prep.Rules.PlateMax)
		if held == nil then
			return nil, "Busy"
		end
		if not ctx.TakeStock(BUN, 1) then
			Board.Release(ctx, vehicle, held, false)
			return nil, "NoStock"
		end
		const ticket: Ticket = { Slot = held, Altered = false, PreCut = false, Stocked = true, Since = now }
		plates[player] = ticket
		return copy(ticket), nil
	end

	local function finish(player: Player, spec: Spec): (Result?, string?)
		const ticket = plates[player]
		if ticket == nil or not deps.IsMember(player) then
			return nil, "NoSession"
		end
		const vehicle = deps.Vehicle()
		if not Board.Holds(vehicle, ticket.Slot) then
			-- the altered bun was cleared at 6:00 AM, or the board is gone: the plate is dead
			plates[player] = nil
			return nil, "NoSession"
		end
		if not validSpec(spec) then
			return nil, "Invalid"
		end
		-- 1. everything that can refuse, without changing anything
		for _, key in spec.Toppings do
			if ctx.IsBlocked(key) then
				return nil, "Invalid"
			end
			if ctx.GetStock(key) < 1 then
				return nil, "NoStock"
			end
		end
		const has, frontAltered = Rail.Front(vehicle)
		if not has then
			return nil, "NoSausage"
		end
		if not deps.CanGive(player) then
			return nil, "HandsFull"
		end
		-- 2. commit. Give first (the only step that can still fail), then the moves that were just checked.
		const altered = ticket.Altered or frontAltered
		const tool = deps.Give(player, table.concat(spec.Toppings, ","), altered, spec.Quality)
		if tool == nil then
			return nil, "HandsFull"
		end
		const _, _, score = Rail.Pop(ctx, vehicle)
		for _, key in spec.Toppings do
			if not ctx.TakeStock(key, 1) then
				warn(`[Plate] {key} was checked but could not be taken for {player.Name}`)
			end
		end
		release(ticket, false)
		plates[player] = nil
		ctx.Emit("assembled", player, { Altered = altered })
		return { Tool = tool, Altered = altered, SausageScore = score, Slot = ticket.Slot }, nil
	end

	local function refund(player: Player): boolean
		const ticket = plates[player]
		if ticket == nil then
			return false
		end
		plates[player] = nil
		-- an altered bun goes back to the board (only a discarded hot dog resolves ANM-002); a stocked one is returned
		release(ticket, ticket.Altered)
		if ticket.Stocked then
			deps.Refund(BUN, 1)
		end
		return true
	end

	local function trash(player: Player, options: TrashOptions?): TrashResult
		const out: TrashResult = { Bun = false, Sausage = false, Hand = false }
		const ticket = plates[player]
		if ticket ~= nil then
			plates[player] = nil
			-- TASK-346: the altered bun is thrown away like a normal one and resolves ANM-002 (it may be gone at 6:00 AM already)
			const held = ticket.Altered and Board.Holds(deps.Vehicle(), ticket.Slot)
			release(ticket, false)
			out.Bun = not ticket.Altered or held
			if held then
				deps.Discarded(player, BUN)
			end
		end
		if options ~= nil and options.Sausage == true then
			const vehicle = deps.Vehicle()
			const has, frontAltered = Rail.Front(vehicle)
			if has and not frontAltered then
				out.Sausage = (Rail.Pop(ctx, vehicle))
			end
		end
		if options ~= nil and options.Hand == true then
			out.Hand = deps.Discard(player)
		end
		return out
	end

	-- The bin by drag: a sausage of the grill slot or of the rail position (1 = front). (ok, reason): Invalid, NoSausage.
	local function trashSausage(player: Player, from: TrashFrom, slot: number): (boolean, string?)
		if not deps.IsMember(player) or not isSlot(slot) then
			return false, "Invalid"
		end
		const vehicle = deps.Vehicle()
		if from == "Grill" then
			const ok = Grill.Discard(ctx, vehicle, slot)
			return ok, if ok then nil else "NoSausage"
		elseif from == "Rail" then
			const ok = Rail.DiscardAt(ctx, vehicle, slot)
			return ok, if ok then nil else "NoSausage"
		end
		return false, "Invalid"
	end

	local function grill(player: Player, act: GrillAction, slot: number?): (GrillResult?, string?)
		if not deps.IsMember(player) then
			return nil, "Invalid"
		end
		const vehicle = deps.Vehicle()
		if act == "Place" then
			const stock = deps.Station("sausage_stock")
			if stock == nil then
				return nil, "NoStation"
			end
			-- slot = the preference of PrepGrill.Slot (prep-3d.md §7.2 N1); isSlot guards the range
			const placed, reason = Grill.PlaceFor(ctx, stock, player, if slot ~= nil and isSlot(slot) then slot else nil)
			if placed == nil then
				if reason == "NoStock" then
					return nil, "NoStock"
				end
				Refusal.notify(ctx, player, "grill_full", nil)
				return nil, "Invalid"
			end
			return { Slot = placed }, nil
		end
		if slot == nil or not isSlot(slot) then
			return nil, "Invalid"
		end
		if act == "Flip" then
			-- TASK-257: the swing is graded where the player saw it (one-way latency)
			const okPing, ping = pcall(function(): number
				return player:GetNetworkPing()
			end)
			const latency = if okPing and type(ping) == "number" then ping else 0
			const score = Grill.Flip(ctx, vehicle, slot, latency)
			if score == nil then
				return nil, "Invalid"
			end
			return { Slot = slot, Score = score, Band = Grade.Band(Content.Prep, score) }, nil
		elseif act == "Collect" then
			const score = Grill.FlipScoreOf(vehicle, slot)
			const ok, reason = Grill.CollectSlot(ctx, vehicle, slot)
			if not ok then
				if reason == "RailFull" then
					Refusal.notify(ctx, player, "rail_full", nil)
				end
				return nil, "Invalid"
			end
			const graded = if score ~= nil then score else Content.Prep.Grades.Unflipped
			return { Slot = slot, Score = graded, Band = Grade.Band(Content.Prep, graded) }, nil
		end
		return nil, "Invalid"
	end

	return {
		Begin = begin,
		Finish = finish,
		Refund = refund,
		Trash = trash,
		Grill = grill,
		TrashSausage = trashSausage,
		Of = function(player: Player): Ticket?
			const ticket = plates[player]
			return if ticket then copy(ticket) else nil
		end,
	}
end

return table.freeze(Plate)
