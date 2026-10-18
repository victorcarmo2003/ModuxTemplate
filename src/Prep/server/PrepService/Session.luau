--!strict
-- Seat session of the focused prep mode (docs/tech/prep-mode.md §3, §4; TASK-170). Pure data and helpers: no Modux, Lync,
-- Charm nor Roblox services. One Seat per seated player; the plate (PrepBegin .. PrepFinish) lives inside it and its clock
-- is the SERVER's os.clock, never a number sent by the client.

export type Plate = {
	StartedAt: number, -- os.clock() at PrepBegin (re-based after a refusal that keeps the plate, see PrepService)
	Reserved: boolean, -- KitchenService reserved a bun and the board slot (BeginPlate); false = nothing to refund
	PreCut: boolean?, -- the bun came already sliced (altered bun): the mask may carry the sausage without the cut bit
}

-- What the seat is (prep-conveyor.md §2.1): Trailer = a board per seat (tabs / pan); Belt = a conveyor assembler with one
-- plate on the belt; Grill = the conveyor griller (no plate)
export type Kind = "Trailer" | "Belt" | "Grill"

export type Seat = {
	Player: Player,
	Station: number, -- 1..Content.Prep.Stations
	Kind: Kind,
	Step: string, -- Content.Prep.Tabs key (wire enum value); conveyor: the Tab of the plate's stop
	Ticket: number, -- pinned NpcId, 0 = none; conveyor: the ticket OF THE PLATE on the belt
	Since: number, -- workspace:GetServerTimeNow() of the seat
	LastSeen: number, -- os.clock() of the last accepted packet (keep-alive, Rules.SeatIdle)
	Plate: Plate?, -- trailer only
	Made: Tool?, -- the hot dog of the last accepted Finish: put in the hand when the seat ends (Rules.Delivery = "Prompt")
	Mask: number, -- accepted cosmetic plate mask (PlateMask, prep-3d.md §7.2 N3); 0 = none; zeroed with the plate
	-- conveyor (TASK-514): PlateService id of the plate on the belt (prep-conveyor.md §10.3), nil = none (grill seat, trailer)
	PlateId: number?,
	Line: number, -- ticket line of that plate (1 leader, 2 pair partner), 0 = none
}

-- A belt plate whose owner left the seat while still in the server (prep-conveyor.md §2.3, P24): it stays parked and
-- reserved on the belt, the seat stays theirs, and the next prep_work of that player resumes it
export type Parked = {
	Station: number,
	PlateId: number,
	Ticket: number,
	Line: number,
	Mask: number,
	Since: number, -- os.clock() of the leave (Conveyor.ParkMax)
	SeatSince: number, -- server time of the seat (PrepSeats.Since)
}

-- Token bucket per packet kind (capacity = rate, refill = rate per second)
export type Bucket = { Tokens: number, At: number }
export type Buckets = { [string]: Bucket }

const Session = {}

function Session.new(player: Player, station: number, serverTime: number, now: number, step: string, kind: Kind?): Seat
	return {
		Player = player,
		Station = station,
		Kind = kind or "Trailer",
		Step = step,
		Ticket = 0,
		Since = serverTime,
		LastSeen = now,
		Plate = nil,
		Made = nil,
		Mask = 0,
		PlateId = nil,
		Line = 0,
	}
end

function Session.Touch(seat: Seat, now: number)
	seat.LastSeen = now
end

-- true = the packet may go on. rate <= 0 refuses everything.
function Session.Allow(buckets: Buckets, key: string, rate: number, now: number): boolean
	if rate <= 0 then
		return false
	end
	local bucket = buckets[key]
	if bucket == nil then
		bucket = { Tokens = math.max(rate, 1), At = now }
		buckets[key] = bucket
	end
	const capacity = math.max(rate, 1)
	bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.At) * rate)
	bucket.At = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

return table.freeze(Session)
