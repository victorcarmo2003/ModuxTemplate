--!strict
-- Order rules (FEAT-010, FEAT-011; DEC-071, DEC-072; architecture.md §18.13; board TASK-033). Pure: numbers from
-- Content.OrderRules / Content.Moods.Rules, no Service, no network, no money moved (CustomerService pays through
-- EconomyService). The draw is OrderRoll.Roll only (R3).
--
--   patience   = two clocks (Q-192, Provisional; replaces the single 40 + 5K s of DEC-072):
--                Queue = QueuePatience x type mult + Counter PatienceBonus, from Q1 until "Take Order" (no order shown)
--                Order = (OrderPatienceBase + OrderPatiencePerK x K) x type mult + PatienceBonus (+ pair bonus), from
--                "Take Order" until served
--   tip window = TipWindowBase + TipWindowPerK x K + class TipWindow offset, from "Take Order" (DEC-072, DEC-069)
--   price      = BasePrice + sum(Ingredients[k].OrderPrice)                                  (DEC-071)
--   Complete   = exactly the ordered toppings: price (+ tip inside the window = Perfect)
--   Incomplete = missing >= 1 ordered topping, nothing extra: floor(price x IncompletePct / 100), no tip
--   Wrong      = any topping not ordered: $0, the hot dog goes back to the server's hand
-- Pairs (TASK-146; FEAT-038): a ticket has 1 or 2 lines (one hot dog each). K = K1 + K2 for patience and the tip
-- window; price, pay and tip per line. Match picks the pending line a served hot dog answers: equal -> Complete;
-- subset -> Incomplete of the line with the fewest missing toppings; anything else -> Wrong (first pending line).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local OrderRoll = require(script.Parent.OrderRoll)

export type Verdict = "Complete" | "Incomplete" | "Wrong"
export type Phase = "None" | "Queue" | "Order"

-- One hot dog of a ticket. Result nil = still pending; else the SaleResult it ended with.
export type Line = {
	Toppings: { string }, -- ordered topping keys (ToppingKeys order)
	K: number,
	Price: number,
	Result: string?,
}

-- Server-only order of one customer or pair (never on the wire before "Take Order", T41)
export type Ticket = {
	Lines: { Line }, -- 1 (customer) or 2 (pair: leader's hot dog, partner's hot dog)
	K: number, -- sum of the lines' K (patience, tip window)
	ArrivedAt: number, -- server time it reached the queue
	-- Patience (Q-192): one clock at a time. Phase None = not running (behind Q1, tutorial customer: PatienceEndsAt huge)
	Phase: Phase,
	PhaseStartedAt: number,
	PatienceEndsAt: number, -- deadline of the running phase (math.huge = none)
	QueueSpan: number, -- s of the Queue phase
	OrderSpan: number, -- s of the Order phase
	Taker: Player?, -- who did "Take Order" ("own order", content-data.md §3.10, Provisional)
	TakenAt: number, -- 0 = not taken
	TipEndsAt: number, -- 0 = not taken
	TipAmount: number, -- taker's TipAmount, kept at "Take Order" (L-04: valid even if the taker leaves)
}

const Orders = {}

-- Draw (R3: the only draw of orders goes through OrderRoll.Roll)
function Orders.Roll(day: number, customerType: string, rng: Random, isNight: boolean?): { string }
	return OrderRoll.Roll(day, customerType, rng, isNight)
end

-- Seconds of the Queue clock (Q1 until "Take Order"). `mult` = the customer type's PatienceMult.Queue (1 if none).
function Orders.QueuePatience(bonus: number, mult: number): number
	return Content.OrderRules.QueuePatience * mult + math.max(bonus, 0)
end

-- Seconds of the Order clock ("Take Order" until served), scaled by the ticket's toppings (K1 + K2 on a pair).
function Orders.OrderPatience(k: number, bonus: number, mult: number): number
	const rules = Content.OrderRules
	return (rules.OrderPatienceBase + rules.OrderPatiencePerK * k) * mult + math.max(bonus, 0)
end

function Orders.TipWindow(k: number, offset: number): number
	const rules = Content.OrderRules
	return math.max(rules.TipWindowBase + rules.TipWindowPerK * k + offset, 0)
end

function Orders.Price(toppings: { string }): number
	local price = Content.OrderRules.BasePrice
	for _, key in toppings do
		const row = Content.Ingredients.ByKey[key]
		if row ~= nil then
			price += row.OrderPrice
		end
	end
	return price
end

-- New ticket for a customer (1 line) or a pair (2 lines) that reached the queue at `arrivedAt`.
-- `patienceBonus` (Counter) adds to both clocks; `pairBonus` only to the Order clock. `mult` = type PatienceMult.
function Orders.Ticket(
	lines: { { string } },
	arrivedAt: number,
	patienceBonus: number,
	pairBonus: number,
	mult: { Queue: number, Order: number }?
): Ticket
	local k = 0
	const out: { Line } = {}
	for _, toppings in lines do
		k += #toppings
		table.insert(out, { Toppings = table.clone(toppings), K = #toppings, Price = Orders.Price(toppings), Result = nil })
	end
	return {
		Lines = out,
		K = k,
		ArrivedAt = arrivedAt,
		Phase = "None",
		PhaseStartedAt = 0,
		PatienceEndsAt = math.huge,
		QueueSpan = Orders.QueuePatience(patienceBonus, if mult then mult.Queue else 1),
		OrderSpan = Orders.OrderPatience(k, patienceBonus + pairBonus, if mult then mult.Order else 1),
		Taker = nil,
		TakenAt = 0,
		TipEndsAt = 0,
		TipAmount = 0,
	}
end

-- Customers.Order bitfield of a topping list.
function Orders.Set(toppings: { string }): { [string]: boolean }
	const set: { [string]: boolean } = {}
	for _, key in toppings do
		set[key] = true
	end
	return set
end

-- Served hot dog (`served` = its toppings) against the order. Bun + sausage are always on a wave 1 hot dog.
function Orders.Evaluate(order: { string }, served: { string }): Verdict
	const wanted = Orders.Set(order)
	local matched = 0
	for _, key in served do
		if not wanted[key] then
			return "Wrong"
		end
		matched += 1
	end
	return if matched >= #order then "Complete" else "Incomplete"
end

-- Indexes of the lines still pending, in order.
function Orders.Pending(ticket: Ticket): { number }
	const out: { number } = {}
	for index, line in ticket.Lines do
		if line.Result == nil then
			table.insert(out, index)
		end
	end
	return out
end

-- Pending line a served hot dog answers, and its verdict (TASK-146; FEAT-038 "Serve"). nil = nothing pending.
function Orders.Match(ticket: Ticket, served: { string }): (number?, Verdict)
	const pending = Orders.Pending(ticket)
	if #pending == 0 then
		return nil, "Wrong"
	end
	local best: number? = nil
	local bestMissing = math.huge
	for _, index in pending do
		const line = ticket.Lines[index]
		const verdict = Orders.Evaluate(line.Toppings, served)
		if verdict == "Complete" then
			return index, "Complete"
		elseif verdict == "Incomplete" then
			const missing = #line.Toppings - #served
			if missing < bestMissing then
				best = index
				bestMissing = missing
			end
		end
	end
	if best ~= nil then
		return best, "Incomplete"
	end
	return pending[1], "Wrong"
end

-- Money for a verdict (tip apart). Integer (DEC-072).
function Orders.Pay(verdict: Verdict, price: number): number
	if verdict == "Complete" then
		return price
	elseif verdict == "Incomplete" then
		return math.floor(price * Content.OrderRules.IncompletePct / 100)
	end
	return 0
end

-- Tip for a Complete sale served at `at`: the taker's amount inside the window, else 0.
function Orders.Tip(ticket: Ticket, at: number): number
	if ticket.TakenAt <= 0 or at > ticket.TipEndsAt then
		return 0
	end
	return math.max(math.floor(ticket.TipAmount), 0)
end

-- Starts the Queue clock (the customer is at Q1, nobody attended it yet).
function Orders.BeginQueue(ticket: Ticket, at: number)
	ticket.Phase = "Queue"
	ticket.PhaseStartedAt = at
	ticket.PatienceEndsAt = at + ticket.QueueSpan
end

-- Starts the Order clock ("Take Order"); the Queue clock is over.
function Orders.BeginOrder(ticket: Ticket, at: number)
	ticket.Phase = "Order"
	ticket.PhaseStartedAt = at
	ticket.PatienceEndsAt = at + ticket.OrderSpan
end

-- Whole seconds of the running phase for the wire (Net.Customers.PatienceSpan, 0..WireSpanMax).
function Orders.WireSpan(ticket: Ticket): number
	if ticket.Phase == "None" then
		return 0
	end
	return math.clamp(math.ceil(ticket.PatienceEndsAt - ticket.PhaseStartedAt), 1, Content.OrderRules.WireSpanMax)
end

-- Patience left at or below MoodRules.AnnoyedAt (Provisional, Q-164: visual only). Per running phase.
function Orders.IsAnnoyed(ticket: Ticket, at: number): boolean
	if ticket.Phase == "None" then
		return false
	end
	const total = ticket.PatienceEndsAt - ticket.PhaseStartedAt
	if total <= 0 then
		return true
	end
	return (ticket.PatienceEndsAt - at) / total <= Content.MoodRules.AnnoyedAt
end

return table.freeze(Orders)
