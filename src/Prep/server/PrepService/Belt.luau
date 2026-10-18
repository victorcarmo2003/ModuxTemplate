--!strict
-- The restaurant conveyor (docs/tech/prep-conveyor.md §3, §4; DEC-302, DEC-303 Q-379 A / Q-380 A; TASK-514). Pure: no Modux,
-- Lync, Charm, Instance nor services. Where each belt seat's plate is and who holds each stop:
--   stops        Content.Prep.Conveyor.Stops (Grill, Board, Toppings, Out); Reserve = one plate at a time (Out holds both)
--   position     (stop, wait) per seat: wait 0 = on the stop, 1 = waiting beside it on the left (WaitL_n), 2 = on the right
--                (WaitR_n). Only a seat with wait 0 on a Reserve stop holds that stop
--   arrows       one stop per press, only the seat's own plate (the packet has no target). A free target takes the plate;
--                a held one leaves it waiting on the side it came from, and it goes in by itself when the stop frees up
--   promotion    freeing a stop (arrow, finish, leave) moves the plate waiting there onto it in the same call
-- Every call is synchronous: the caller (PrepService) runs the check and the write without a yield, so two packets of the
-- same frame are served in arrival order (prep-conveyor.md §4 "Desempate").

export type BeltStop = { Key: string, Tab: string, Reserve: boolean }
export type Dir = "Left" | "Right"
export type Position = { Stop: number, Wait: number }
export type Belt = {
	Stops: { BeltStop },
	Seats: { [number]: Position },
}

const WAIT_LEFT = 1
const WAIT_RIGHT = 2

const Belt = {}

function Belt.new(stops: { BeltStop }): Belt
	return { Stops = stops, Seats = {} }
end

local function reserves(belt: Belt, stop: number): boolean
	const row = belt.Stops[stop]
	return row ~= nil and row.Reserve
end

-- Seat holding `stop` (wait 0 on a Reserve stop), nil = free. `except` is skipped (the mover itself)
function Belt.holder(belt: Belt, stop: number, except: number?): number?
	if not reserves(belt, stop) then
		return nil
	end
	for seat, position in belt.Seats do
		if seat ~= except and position.Stop == stop and position.Wait == 0 then
			return seat
		end
	end
	return nil
end

-- Promotes the plate waiting beside `stop` once nobody holds it. Returns the promoted seat
local function promote(belt: Belt, stop: number): number?
	if not reserves(belt, stop) or Belt.holder(belt, stop, nil) ~= nil then
		return nil
	end
	-- the lowest seat first, so the result never depends on the iteration order (with 2 plates there is at most one)
	local best: number? = nil
	for seat, position in belt.Seats do
		if position.Stop == stop and position.Wait ~= 0 and (best == nil or seat < best) then
			best = seat
		end
	end
	if best ~= nil then
		belt.Seats[best] = { Stop = stop, Wait = 0 }
	end
	return best
end

-- Index of the stop with this key, nil = none
function Belt.indexOf(belt: Belt, key: string): number?
	for index, row in belt.Stops do
		if row.Key == key then
			return index
		end
	end
	return nil
end

-- Last stop (Out): where an accepted Finish sends the plate
function Belt.exit(belt: Belt): number
	return Belt.indexOf(belt, "Out") or #belt.Stops
end

-- Puts the seat's plate on `stop` (1 = the entry, prep-conveyor.md §3.2): held by another plate = it waits on the left of
-- it (WaitL_1, in front of the grill). A seat already on the belt is moved there first (its old stop frees).
function Belt.load(belt: Belt, seat: number, stop: number): (number, number)
	const target = math.clamp(math.floor(stop), 1, math.max(#belt.Stops, 1))
	if belt.Seats[seat] ~= nil then
		Belt.leave(belt, seat)
	end
	const side = if Belt.holder(belt, target, seat) ~= nil then WAIT_LEFT else 0
	belt.Seats[seat] = { Stop = target, Wait = side }
	return target, side
end

-- One stop toward the grill (Left) or toward Out (Right). (ok, stop, side, promoted): ok false = no plate or the end of
-- the belt (nothing changes); promoted = the seat that took the stop this plate left.
function Belt.move(belt: Belt, seat: number, dir: Dir): (boolean, number, number, number?)
	const position = belt.Seats[seat]
	if position == nil then
		return false, 0, 0, nil
	end
	const step = if dir == "Left" then -1 elseif dir == "Right" then 1 else 0
	const target = position.Stop + step
	if step == 0 or target < 1 or target > #belt.Stops then
		return false, position.Stop, position.Wait, nil
	end
	const left = position.Stop
	const held = position.Wait == 0
	-- coming from the left (Right arrow) it waits on the left side of the target, and the other way round
	const side = if Belt.holder(belt, target, seat) ~= nil then (if dir == "Right" then WAIT_LEFT else WAIT_RIGHT) else 0
	belt.Seats[seat] = { Stop = target, Wait = side }
	const promoted = if held then promote(belt, left) else nil
	return true, target, side, promoted
end

-- Takes the seat's plate off the belt (to the hand or the table). Returns the seat promoted onto the stop it held.
function Belt.leave(belt: Belt, seat: number): number?
	const position = belt.Seats[seat]
	if position == nil then
		return nil
	end
	belt.Seats[seat] = nil
	if position.Wait ~= 0 then
		return nil
	end
	return promote(belt, position.Stop)
end

-- An accepted Finish: the plate goes to Out by itself (P8), freeing its stop. Returns the promoted seat.
function Belt.finish(belt: Belt, seat: number): number?
	const position = belt.Seats[seat]
	if position == nil then
		return nil
	end
	const out = Belt.exit(belt)
	belt.Seats[seat] = { Stop = out, Wait = 0 }
	if position.Wait ~= 0 or position.Stop == out then
		return nil
	end
	return promote(belt, position.Stop)
end

-- (stop, side) of the seat's plate; stop nil = not on the belt
function Belt.at(belt: Belt, seat: number): (number?, number)
	const position = belt.Seats[seat]
	if position == nil then
		return nil, 0
	end
	return position.Stop, position.Wait
end

-- The plate sits ON the stop with this key (not waiting beside it): the work of that stop is allowed
function Belt.canWork(belt: Belt, seat: number, stopKey: string): boolean
	const position = belt.Seats[seat]
	if position == nil or position.Wait ~= 0 then
		return false
	end
	const row = belt.Stops[position.Stop]
	return row ~= nil and row.Key == stopKey
end

-- The invariant the QA reads in the set log: never two plates with wait 0 on the same Reserve stop. nil = ok, else a line
function Belt.problem(belt: Belt): string?
	const seen: { [number]: number } = {}
	for seat, position in belt.Seats do
		if position.Wait == 0 and reserves(belt, position.Stop) then
			const other = seen[position.Stop]
			if other ~= nil then
				return `stop {position.Stop} held by seats {other} and {seat}`
			end
			seen[position.Stop] = seat
		end
		if position.Wait ~= 0 and Belt.holder(belt, position.Stop, seat) == nil then
			return `seat {seat} waits beside stop {position.Stop}, which is free`
		end
	end
	return nil
end

-- Table test of the rules above (dev: PrepService:DevBelt). (passed, total, failures)
function Belt.test(stops: { BeltStop }): (number, number, { string })
	const failures: { string } = {}
	local total = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			table.insert(failures, name)
		end
	end
	local belt = Belt.new(stops)
	local stop, side = Belt.load(belt, 1, 1)
	check("load on a free entry", stop == 1 and side == 0)
	stop, side = Belt.load(belt, 2, 1)
	check("load on a held entry waits on the left", stop == 1 and side == WAIT_LEFT)
	check("waiting seat cannot work", not Belt.canWork(belt, 2, stops[1].Key))
	local ok, _, _, promoted = Belt.move(belt, 1, "Right")
	check("move right frees the entry and promotes the waiting plate", ok and promoted == 2)
	check("promoted plate works", Belt.canWork(belt, 2, stops[1].Key))
	ok, stop, side = Belt.move(belt, 2, "Right")
	check("move onto a held stop waits on the left", ok and stop == 2 and side == WAIT_LEFT)
	ok, stop, side = Belt.move(belt, 2, "Right")
	check("a waiting plate passes beside the held stop", ok and stop == 3 and side == 0)
	ok, stop, side = Belt.move(belt, 1, "Right")
	check("coming from the left onto a held stop", ok and stop == 3 and side == WAIT_LEFT)
	ok, stop, side = Belt.move(belt, 1, "Left")
	check("waiting plate goes back left to a free stop", ok and stop == 2 and side == 0)
	ok = Belt.move(belt, 2, "Right")
	check("Out holds both", ok and Belt.holder(belt, #stops, nil) == nil)
	ok = Belt.move(belt, 2, "Right")
	check("no stop past Out", not ok)
	belt = Belt.new(stops)
	Belt.load(belt, 1, 1)
	ok = Belt.move(belt, 1, "Left")
	check("no stop before the entry", not ok)
	Belt.move(belt, 1, "Right")
	Belt.load(belt, 2, 1)
	Belt.move(belt, 2, "Right")
	local _, waitingAt = Belt.at(belt, 2)
	check("waiting at Board", waitingAt == WAIT_LEFT)
	check("finish promotes the waiting plate", Belt.finish(belt, 1) == 2 and Belt.canWork(belt, 2, stops[2].Key))
	check("finish goes to Out", (Belt.at(belt, 1)) == Belt.exit(belt))
	check("leave of a held stop frees it", Belt.leave(belt, 2) == nil and Belt.holder(belt, 2, nil) == nil)
	check("invariant holds", Belt.problem(belt) == nil)
	belt = Belt.new(stops)
	Belt.load(belt, 1, 1)
	Belt.load(belt, 2, 1)
	check("leave of the holder promotes", Belt.leave(belt, 1) == 2)
	check("leave of a waiting plate promotes nobody", Belt.leave(belt, 2) == nil)
	return total - #failures, total, failures
end

return table.freeze(Belt)
