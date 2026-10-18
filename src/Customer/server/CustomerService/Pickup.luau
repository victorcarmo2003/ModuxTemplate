--!strict
-- CustomerService/Pickup: pickup line of the restaurant, pure (tech/restaurant-flow.md rev. 2 §3.1; design FEAT-046;
-- DEC-280; TASK-380). Same shape as Queue.luau: the order in which customers took their order and which spot each one
-- stands on. Spot k is the MapPoint/NpcNode "PU-k" (Content.Restaurant.Binding.PickupPoint; PU-1 = at the counter, next
-- to PICKUP, PU-2..n = the side line). Whoever ordered joins at the back; it leaves when served, out of patience or sent
-- away, and everyone behind moves one spot up. A pair takes one spot (the leader's id). No Service, no network, no
-- Instance: table tests in Pickup.Test (run by /dev pickup test).
-- Conveyor kitchen (TASK-516; tech/prep-conveyor.md §8; Q-383 A): with Content.Prep.Rules.Mode = "Conveyor" choose is
-- strict: the hot dog goes ONLY to the customer of its ticket, and only while that customer is in the line (the
-- "oldest exact", "target" and "PU-1" branches are off). PlateService's gate "PlateTicket" sends the refusal notices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Pickup = {
	Order: { number }, -- customer ids (leaders), oldest first; index = spot
}

-- What ServeAtPickup asks about each candidate (CustomerService answers from the ticket and the hot dog).
export type Fit = "Exact" | "Other" -- Exact = the hot dog is Complete for a pending line; Other = anything else

-- Why Pickup.choose picked its customer (dev / QA readout).
export type Reason = "ticket" | "match" | "owner" | "target" | "front"

const MAX_SPOTS = 12 -- = Net Customers.Pickup wire range 1..12 (Content.Restaurant.Rules.PickupSlotsMax)
const DEFAULT_FORMAT = "PU-%d"

const Pickup = {}

Pickup.MaxSpots = MAX_SPOTS

function Pickup.new(): Pickup
	return { Order = {} }
end

-- Active spots for a wanted size and the number of PU-k points the map has (always 0..MAX_SPOTS; 0 = no pickup line).
function Pickup.size(wanted: number, available: number): number
	if wanted ~= wanted or available ~= available then
		return 0
	end
	return math.clamp(math.floor(math.min(wanted, available)), 0, MAX_SPOTS)
end

-- PointId / NodeId of a spot. `format` = Content.Restaurant.Binding.PickupPoint (default "PU-%d").
function Pickup.point(spot: number, format: string?): string
	return string.format(format or DEFAULT_FORMAT, spot)
end

-- Spot number of a node id ("PU-3" -> 3), or nil when it is not a pickup node.
function Pickup.spotOfNode(node: string): number?
	const digits = string.match(node, "^PU%-(%d+)$")
	return if digits then tonumber(digits) else nil
end

-- Appends `id` at the back. Returns its spot (the current one when it is already in the line).
function Pickup.join(line: Pickup, id: number): number
	const index = table.find(line.Order, id)
	if index ~= nil then
		return index
	end
	table.insert(line.Order, id)
	return #line.Order
end

-- Removes `id`; everyone behind it moves one spot up. false = it was not in the line.
function Pickup.leave(line: Pickup, id: number): boolean
	const index = table.find(line.Order, id)
	if index == nil then
		return false
	end
	table.remove(line.Order, index)
	return true
end

-- Spot of `id` (1 = at the counter), or nil.
function Pickup.spotOf(line: Pickup, id: number): number?
	return table.find(line.Order, id)
end

-- Customer on PU-1, or nil.
function Pickup.front(line: Pickup): number?
	return line.Order[1]
end

function Pickup.count(line: Pickup): number
	return #line.Order
end

-- True when the line already fills `size` spots ("Take Order" refused with pickup_full). size 0 = always full.
function Pickup.isFull(line: Pickup, size: number): boolean
	return #line.Order >= size
end

function Pickup.clear(line: Pickup)
	table.clear(line.Order)
end

-- Who gets a hot dog handed over at the pickup (tech §3.1, board TASK-380). `owner` = NpcId on the plate's Ticket
-- (leader id; nil = no ticket), `target` = the rig the player served (serve on a PU-n rig; nil = the PICKUP prompt),
-- `fit(id)` = how the hot dog fits that customer's pending lines. Order:
--   1. the ticket owner, if in the line and the hot dog is Exact for it;
--   2. the oldest customer in the line the hot dog is Exact for (the ticket is a guide, never a lock);
--   3. the ticket owner, if in the line (its plate, judged as it is: Incomplete or Wrong);
--   4. the target, if in the line;
--   5. PU-1 (the verdict decides: usually Wrong, the hot dog stays in the hand).
-- nil = the line is empty.
-- `strict` (nil = Content.Prep.Rules.Mode == "Conveyor"): only 1 and 3 (the ticket owner in the line); nil otherwise.
function Pickup.choose(
	line: Pickup,
	owner: number?,
	target: number?,
	fit: (id: number) -> Fit,
	strict: boolean?
): (number?, Reason?)
	const inLine = function(id: number?): boolean
		return id ~= nil and table.find(line.Order, id) ~= nil
	end
	const ownerOnly = if strict ~= nil then strict else Content.Prep.Rules.Mode == "Conveyor"
	if ownerOnly then
		if owner == nil or not inLine(owner) then
			return nil, nil
		end
		return owner, if fit(owner) == "Exact" then "ticket" else "owner"
	end
	if owner ~= nil and inLine(owner) and fit(owner) == "Exact" then
		return owner, "ticket"
	end
	for _, id in line.Order do
		if fit(id) == "Exact" then
			return id, "match"
		end
	end
	if owner ~= nil and inLine(owner) then
		return owner, "owner"
	end
	if target ~= nil and inLine(target) then
		return target, "target"
	end
	const first = line.Order[1]
	if first == nil then
		return nil, nil
	end
	return first, "front"
end

-- Table tests (join / leave / the line moves / full / choose). Returns the failures; empty = all passed.
function Pickup.Test(): { string }
	const failures: { string } = {}
	local function check(name: string, got: any, want: any)
		if got ~= want then
			table.insert(failures, `{name}: got {tostring(got)}, want {tostring(want)}`)
		end
	end
	local function order(line: Pickup): string
		const parts: { string } = {}
		for _, id in line.Order do
			table.insert(parts, tostring(id))
		end
		return table.concat(parts, ",")
	end

	-- join: back of the line, idempotent
	do
		const line = Pickup.new()
		check("join first", Pickup.join(line, 10), 1)
		check("join second", Pickup.join(line, 20), 2)
		check("join third", Pickup.join(line, 30), 3)
		check("join again keeps spot", Pickup.join(line, 20), 2)
		check("join order", order(line), "10,20,30")
		check("front", Pickup.front(line), 10)
		check("count", Pickup.count(line), 3)
	end

	-- leave + the line moves: whoever is behind moves one spot up, the ones ahead stay
	const leaveCases: { { Name: string, Start: { number }, Leave: number, Ok: boolean, Want: string } } = {
		{ Name = "leave front", Start = { 1, 2, 3 }, Leave = 1, Ok = true, Want = "2,3" },
		{ Name = "leave middle", Start = { 1, 2, 3 }, Leave = 2, Ok = true, Want = "1,3" },
		{ Name = "leave back", Start = { 1, 2, 3 }, Leave = 3, Ok = true, Want = "1,2" },
		{ Name = "leave absent", Start = { 1, 2 }, Leave = 9, Ok = false, Want = "1,2" },
		{ Name = "leave last one", Start = { 5 }, Leave = 5, Ok = true, Want = "" },
	}
	for _, case in leaveCases do
		const line = Pickup.new()
		for _, id in case.Start do
			Pickup.join(line, id)
		end
		check(`{case.Name} result`, Pickup.leave(line, case.Leave), case.Ok)
		check(`{case.Name} order`, order(line), case.Want)
	end
	do
		const line = Pickup.new()
		for _, id in { 7, 8, 9 } do
			Pickup.join(line, id)
		end
		Pickup.leave(line, 7)
		check("moves: 8 now on PU-1", Pickup.spotOf(line, 8), 1)
		check("moves: 9 now on PU-2", Pickup.spotOf(line, 9), 2)
		check("moves: 7 gone", Pickup.spotOf(line, 7), nil)
		check("rejoin goes to the back", Pickup.join(line, 7), 3)
	end

	-- full
	const fullCases: { { Name: string, Count: number, Size: number, Want: boolean } } = {
		{ Name = "empty of 4", Count = 0, Size = 4, Want = false },
		{ Name = "3 of 4", Count = 3, Size = 4, Want = false },
		{ Name = "4 of 4", Count = 4, Size = 4, Want = true },
		{ Name = "size 0", Count = 0, Size = 0, Want = true },
	}
	for _, case in fullCases do
		const line = Pickup.new()
		for id = 1, case.Count do
			Pickup.join(line, id)
		end
		check(`full {case.Name}`, Pickup.isFull(line, case.Size), case.Want)
	end

	-- size / points
	check("size min(wanted, map)", Pickup.size(4, 3), 3)
	check("size wanted", Pickup.size(4, 8), 4)
	check("size cap", Pickup.size(40, 40), MAX_SPOTS)
	check("size no map", Pickup.size(4, 0), 0)
	check("size nan", Pickup.size(0 / 0, 4), 0)
	check("point", Pickup.point(3), "PU-3")
	check("point format", Pickup.point(2, "P%d"), "P2")
	check("spotOfNode", Pickup.spotOfNode("PU-11"), 11)
	check("spotOfNode not pickup", Pickup.spotOfNode("Q1"), nil)

	-- choose: line 1, 2, 3 (1 = PU-1); exact = which ids the hot dog is Complete for
	const chooseCases: {
		{ Name: string, Exact: { number }, Owner: number?, Target: number?, Want: number?, Why: Reason? }
	} =
		{
			{ Name = "ticket exact", Exact = { 1, 3 }, Owner = 3, Target = nil, Want = 3, Why = "ticket" },
			{ Name = "oldest exact over ticket", Exact = { 2 }, Owner = 3, Target = nil, Want = 2, Why = "match" },
			{ Name = "oldest exact, no ticket", Exact = { 2, 3 }, Owner = nil, Target = nil, Want = 2, Why = "match" },
			{ Name = "ticket owner, no exact", Exact = {}, Owner = 3, Target = 2, Want = 3, Why = "owner" },
			{ Name = "ticket owner gone", Exact = {}, Owner = 9, Target = nil, Want = 1, Why = "front" },
			{ Name = "target, no exact", Exact = {}, Owner = nil, Target = 2, Want = 2, Why = "target" },
			{ Name = "front = wrong", Exact = {}, Owner = nil, Target = nil, Want = 1, Why = "front" },
		}
	for _, case in chooseCases do
		const line = Pickup.new()
		for id = 1, 3 do
			Pickup.join(line, id)
		end
		const id, why = Pickup.choose(line, case.Owner, case.Target, function(candidate: number): Fit
			return if table.find(case.Exact, candidate) then "Exact" else "Other"
		end, false)
		check(`choose {case.Name}`, id, case.Want)
		check(`choose {case.Name} reason`, why, case.Why)
	end
	do
		const id, why = Pickup.choose(Pickup.new(), 1, 1, function(): Fit
			return "Exact"
		end, false)
		check("choose empty line", id, nil)
		check("choose empty line reason", why, nil)
	end

	-- strict (conveyor, Q-383 A): only the ticket owner in the line, never another exact customer, the target or PU-1
	const strictCases: {
		{ Name: string, Exact: { number }, Owner: number?, Target: number?, Want: number?, Why: Reason? }
	} =
		{
			{ Name = "owner exact", Exact = { 1, 3 }, Owner = 3, Target = nil, Want = 3, Why = "ticket" },
			{ Name = "owner not exact", Exact = { 2 }, Owner = 3, Target = 2, Want = 3, Why = "owner" },
			{ Name = "owner not in line", Exact = { 1, 2 }, Owner = 9, Target = 2, Want = nil, Why = nil },
			{ Name = "no ticket", Exact = { 1 }, Owner = nil, Target = 1, Want = nil, Why = nil },
		}
	for _, case in strictCases do
		const line = Pickup.new()
		for id = 1, 3 do
			Pickup.join(line, id)
		end
		const id, why = Pickup.choose(line, case.Owner, case.Target, function(candidate: number): Fit
			return if table.find(case.Exact, candidate) then "Exact" else "Other"
		end, true)
		check(`strict {case.Name}`, id, case.Want)
		check(`strict {case.Name} reason`, why, case.Why)
	end

	return failures
end

return Pickup
