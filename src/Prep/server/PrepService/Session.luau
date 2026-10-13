--!strict
-- Seat session of the focused prep mode (docs/tech/prep-mode.md §3, §4; TASK-170). Pure data and helpers: no Modux, Lync,
-- Charm nor Roblox services. One Seat per seated player; the plate (PrepBegin .. PrepFinish) lives inside it and its clock
-- is the SERVER's os.clock, never a number sent by the client.

export type Plate = {
	StartedAt: number, -- os.clock() at PrepBegin (re-based after a refusal that keeps the plate, see PrepService)
	Reserved: boolean, -- KitchenService reserved a bun and the board slot (BeginPlate); false = nothing to refund
	PreCut: boolean?, -- the bun came already sliced (altered bun): the mask may carry the sausage without the cut bit
}

export type Seat = {
	Player: Player,
	Station: number, -- 1..Content.Prep.Stations
	Step: string, -- Content.Prep.Tabs key (wire enum value)
	Ticket: number, -- pinned NpcId, 0 = none
	Since: number, -- workspace:GetServerTimeNow() of the seat
	LastSeen: number, -- os.clock() of the last accepted packet (keep-alive, Rules.SeatIdle)
	Plate: Plate?,
	Made: Tool?, -- the hot dog of the last accepted Finish: put in the hand when the seat ends (Rules.Delivery = "Prompt")
	Mask: number, -- accepted cosmetic plate mask (PlateMask, prep-3d.md §7.2 N3); 0 = none; zeroed with the plate
}

-- Token bucket per packet kind (capacity = rate, refill = rate per second)
export type Bucket = { Tokens: number, At: number }
export type Buckets = { [string]: Bucket }

const Session = {}

function Session.new(player: Player, station: number, serverTime: number, now: number, step: string): Seat
	return {
		Player = player,
		Station = station,
		Step = step,
		Ticket = 0,
		Since = serverTime,
		LastSeen = now,
		Plate = nil,
		Made = nil,
		Mask = 0,
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
