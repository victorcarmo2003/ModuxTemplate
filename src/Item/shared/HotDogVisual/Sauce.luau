--!strict
--[[
	Sauce (owner request 2026-10-14, Provisional): the sauce line the player DREW in the 3D prep mode, kept on the hot dog.
	Pure shared module (no Modux, Lync, Vide): the client packs the strokes, the server cleans them and writes the Tool
	attribute `Sauce`, HotDogVisual draws it on the held / served hot dog.

	Wire (PrepFinish.Sauces[i].Points): ints 0..BREAK, at most MAX per sauce. A point = X * (GRID + 1) + Y, X and Y the bun-space
	coordinates 0..1 (X along the bun, Y across, Content.Prep.Build space) quantised to 0..GRID; BREAK = the pen went up (a new stroke
	starts at the next point). The client resamples its strokes along their length to fit MAX.
	Attribute (Tool `Sauce`): "ketchup:<code>;mustard:<code>", code = two characters of ALPHABET per value (value = hi * 64 + lo).
	Cheap on purpose: 3 sauces x 24 points = 144 characters at most.
]]

export type Segments = { { Vector2 } }

const GRID = 63
const BREAK = (GRID + 1) * (GRID + 1) - 1 -- 4095: never a point (X = Y = 63 is folded to 62)
const MAX = 24
const ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"

-- The colour of each drawn sauce (food, not a UI state). World/Strokes reads the same table: one source for the prep line and the
-- hot dog it becomes.
const COLORS: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#A82C1C"), -- full-bodied tomato, not a plastic red
	mustard = Color3.fromHex("#C4961A"), -- mustard yellow, a little dark
	cream_cheese = Color3.fromHex("#EDE3D0"), -- off-white
}
const DEFAULT_COLOR = Color3.fromHex("#EDE3D0")

const Sauce = {}

Sauce.Max = MAX
Sauce.Break = BREAK
Sauce.Attribute = "Sauce"

function Sauce.ColorOf(key: string): Color3
	return COLORS[key] or DEFAULT_COLOR
end

local function quantise(value: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(math.floor(value * GRID + 0.5), 0, GRID)
end

local function pointOf(value: number): Vector2
	const x = value // (GRID + 1)
	const y = value % (GRID + 1)
	return Vector2.new(x / GRID, y / GRID)
end

local function lengthOf(points: { Vector2 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

-- `count` points spread evenly along the polyline (first and last kept)
local function resample(points: { Vector2 }, count: number): { Vector2 }
	if #points <= count then
		return points
	end
	const total = lengthOf(points)
	if total <= 1e-6 then
		return { points[1], points[#points] }
	end
	const out: { Vector2 } = { points[1] }
	const step = total / (count - 1)
	local walked = 0
	local nextAt = step
	for index = 2, #points do
		const a, b = points[index - 1], points[index]
		const piece = (b - a).Magnitude
		while piece > 0 and walked + piece >= nextAt and #out < count - 1 do
			table.insert(out, a:Lerp(b, (nextAt - walked) / piece))
			nextAt += step
		end
		walked += piece
	end
	table.insert(out, points[#points])
	return out
end

-- Client: the strokes of one sauce (bun space) -> wire ints, at most MAX (breaks included). Short strokes go first when it is full.
function Sauce.Pack(segments: Segments): { number }
	const kept: { { Vector2 } } = {}
	for _, segment in segments do
		if #segment >= 2 and lengthOf(segment) > 1e-4 then
			table.insert(kept, segment)
		end
	end
	-- every stroke needs 2 points and a break before it: keep the longest ones that fit
	table.sort(kept, function(a: { Vector2 }, b: { Vector2 }): boolean
		return lengthOf(a) > lengthOf(b)
	end)
	while #kept > 0 and #kept * 3 - 1 > MAX do
		table.remove(kept)
	end
	if #kept == 0 then
		return {}
	end
	local total = 0
	for _, segment in kept do
		total += lengthOf(segment)
	end
	const budget = MAX - (#kept - 1)
	const out: { number } = {}
	local left = budget
	for index, segment in kept do
		const share = if index == #kept then left else math.max(2, math.floor(budget * lengthOf(segment) / total))
		const count = math.clamp(share, 2, left - 2 * (#kept - index))
		left -= count
		if index > 1 then
			table.insert(out, BREAK)
		end
		for _, point in resample(segment, count) do
			const x, y = quantise(point.X), quantise(point.Y)
			const value = x * (GRID + 1) + y
			table.insert(out, if value == BREAK then BREAK - 1 else value)
		end
	end
	return out
end

-- Server: the wire ints of one sauce, checked (integers in range, at most MAX, no break at an end or twice, at least 2 points).
-- nil = nothing usable (the hot dog keeps the stacked model of that sauce).
function Sauce.Clean(values: any): { number }?
	if type(values) ~= "table" then
		return nil
	end
	const out: { number } = {}
	local points = 0
	for index, value in values :: { any } do
		if index > MAX then
			return nil
		end
		if type(value) ~= "number" or value ~= value or value ~= math.floor(value) or value < 0 or value > BREAK then
			return nil
		end
		if value == BREAK then
			if #out == 0 or out[#out] == BREAK then
				continue
			end
		else
			points += 1
		end
		table.insert(out, value)
	end
	while #out > 0 and out[#out] == BREAK do
		table.remove(out)
	end
	return if points >= 2 then out else nil
end

-- Server: cleaned sauces by key -> the Tool attribute string ("" = none)
function Sauce.Encode(sauces: { [string]: { number } }): string
	const keys: { string } = {}
	for key in sauces do
		table.insert(keys, key)
	end
	table.sort(keys)
	const parts: { string } = {}
	for _, key in keys do
		const chars: { string } = {}
		for _, value in sauces[key] do
			const hi, lo = value // 64, value % 64
			table.insert(chars, string.sub(ALPHABET, hi + 1, hi + 1) .. string.sub(ALPHABET, lo + 1, lo + 1))
		end
		table.insert(parts, `{key}:{table.concat(chars)}`)
	end
	return table.concat(parts, ";")
end

-- The attribute back to strokes in bun space, by sauce key. Malformed parts are skipped.
function Sauce.Decode(value: any): { [string]: Segments }
	const out: { [string]: Segments } = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	for part in string.gmatch(value, "[^;]+") do
		const key, code = string.match(part, "^([%w_]+):([%w%-_]*)$")
		if key == nil or code == nil or #code % 2 ~= 0 or #code // 2 > MAX then
			continue
		end
		const segments: Segments = {}
		local current: { Vector2 } = {}
		for index = 1, #code, 2 do
			const hi = string.find(ALPHABET, string.sub(code, index, index), 1, true)
			const lo = string.find(ALPHABET, string.sub(code, index + 1, index + 1), 1, true)
			if hi == nil or lo == nil then
				current = {}
				break
			end
			const number = (hi - 1) * 64 + (lo - 1)
			if number == BREAK then
				if #current >= 2 then
					table.insert(segments, current)
				end
				current = {}
			else
				table.insert(current, pointOf(number))
			end
		end
		if #current >= 2 then
			table.insert(segments, current)
		end
		if #segments > 0 then
			out[key] = segments
		end
	end
	return out
end

return table.freeze(Sauce)
