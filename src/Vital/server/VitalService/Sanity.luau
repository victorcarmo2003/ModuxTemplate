--!strict
-- Pure sanity rules (architecture.md §19.7; FEAT-019, FEAT-020, FEAT-021; DEC-056, DEC-167). No Modux, no network,
-- no Instances: every number comes from Content.Sanity passed in, so lune can test it.
--   band(value, max, rows)          look pack of a value: "Day" (>= High), "Mid" (>= Mid), "Night"; max 0 (day) = Day
--   clamp(value, max)               whole value in [0, max]
--   darkLoss(entry, now, rows)      what one dark tick takes (0 while within DarkDelay or protected)
--   passiveLoss(...)                what one tick takes in all: the higher of the dark rate and the Night idle rate
--   start(startValue, maxValue)     night start: whole, max >= start, both inside the wire range
--   restore(value, max, amount)     coffee: never above max (FEAT-021)

export type Band = "Day" | "Mid" | "Night"

export type Rows = {
	Bands: { High: number, Mid: number },
	DarkDelay: number,
	DarkPerSecond: number,
	DreadAfter: number,
	DreadPerSecond: number,
	Idle: { PerSecond: number, NightScale: { [number]: number } },
}

-- Sanity packet wire range (network.md §13.1: Lync.int(0, 200)).
const WIRE_MAX = 200

const Sanity = {}

Sanity.WIRE_MAX = WIRE_MAX

function Sanity.clamp(value: number, max: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(math.floor(value + 0.5), 0, math.max(0, max))
end

-- Absolute points, not a share of the max (DEC-167). No sanity (max 0: day) is always the day look.
function Sanity.band(value: number, max: number, rows: Rows): Band
	if max <= 0 then
		return "Day"
	elseif value >= rows.Bands.High then
		return "Day"
	elseif value >= rows.Bands.Mid then
		return "Mid"
	end
	return "Night"
end

-- Night start values of a class (SanityStart / SanityMax modifiers over Sanity.Start). Runner 90 of 100, Night Owl
-- 120 of 120 (FEAT-019).
function Sanity.start(startValue: number, maxValue: number): (number, number)
	const max = math.clamp(math.floor(math.max(startValue, maxValue) + 0.5), 1, WIRE_MAX)
	return Sanity.clamp(startValue, max), max
end

-- Seconds in the dark so far -> loss of this tick (FEAT-020: -DarkPerSecond after DarkDelay continuous seconds).
-- darkSince = nil: lit. protectUntil: no loss before it (wave 4 revive protection).
function Sanity.darkLoss(darkSince: number?, protectUntil: number, now: number, rows: Rows): number
	if darkSince == nil or now < protectUntil then
		return 0
	end
	if now - darkSince < rows.DarkDelay then
		return 0
	end
	-- the dread: the lights left off too long
	if now - darkSince >= rows.DreadAfter then
		return rows.DreadPerSecond
	end
	return rows.DarkPerSecond
end

-- Idle drain (owner 2026-10-22, Q-477): per second, only in the exact phase "Night", scaled by the night number.
function Sanity.idleRate(phase: string, night: number, rows: Rows): number
	if phase ~= "Night" then
		return 0
	end
	return rows.Idle.PerSecond * (rows.Idle.NightScale[night] or 1)
end

-- Loss of one tick in all: the dark and the idle drain do not add up, the higher rate applies. darkSince nil = lit (or the
-- dark does not count in this phase). protectUntil covers both. Returns (loss, darkLoss): the second one is what the dark
-- alone took, for the client's dark look.
function Sanity.passiveLoss(
	darkSince: number?,
	protectUntil: number,
	now: number,
	phase: string,
	night: number,
	rows: Rows
): (number, number)
	if now < protectUntil then
		return 0, 0
	end
	const dark = Sanity.darkLoss(darkSince, protectUntil, now, rows)
	return math.max(dark, Sanity.idleRate(phase, night, rows)), dark
end

-- Coffee (FEAT-021): +amount, never above max.
function Sanity.restore(value: number, max: number, amount: number): number
	return Sanity.clamp(math.min(max, value + math.max(0, amount)), max)
end

return table.freeze(Sanity)
