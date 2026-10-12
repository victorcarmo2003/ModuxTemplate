--!strict
-- Cosmetic plate mask (docs/tech/prep-3d.md §7.2 N3, TASK-194). ReplicatedStorage.shared.Prep.PlateMask. Pure: the client packs
-- the open plate into PrepTab.Plate, the server unpacks and checks it before it writes PrepSeats.Plate, the colleague's puppet
-- reads it. Layout from Content.Prep.PlateMask: bit 0 the bun is cut, bit 1 the sausage is placed, bits 2..7 the toppings in the
-- order of Ingredients.ToppingKeys. It is NOT authority (PrepFinish revalidates everything); it only has to be plausible:
--   Valid(old, new, maxToppings)   the mask only grows, has at most maxToppings topping bits and no bit past ToppingKeys
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrepContent = require(ReplicatedStorage.shared.Content.Prep)
local Ingredients = require(ReplicatedStorage.shared.Content.Ingredients)

export type Plate = {
	Cut: boolean,
	Sausage: boolean,
	Toppings: { string }, -- Ingredients keys, in ToppingKeys order (the wire has no order of addition)
}

const layout = PrepContent.PlateMask
const toppingKeys = Ingredients.ToppingKeys
const toppingBit: { [string]: number } = {}
for index, key in toppingKeys do
	toppingBit[key] = bit32.lshift(1, layout.FirstTopping + index - 1)
end
const FULL = bit32.lshift(1, layout.Bits) - 1
const CUT = bit32.lshift(1, layout.Cut)
const SAUSAGE = bit32.lshift(1, layout.Sausage)
const TOPPINGS = bit32.band(FULL, bit32.bnot(CUT + SAUSAGE))
-- every bit that has no key behind it
const UNKNOWN = bit32.band(TOPPINGS, bit32.bnot(bit32.lshift(bit32.lshift(1, #toppingKeys) - 1, layout.FirstTopping)))

const PlateMask = {}

PlateMask.Empty = 0

-- Mask of a plate. Unknown topping keys are skipped.
function PlateMask.Pack(plate: { Cut: boolean?, Sausage: boolean?, Toppings: { string }? }): number
	local mask = 0
	if plate.Cut then
		mask = bit32.bor(mask, CUT)
	end
	if plate.Sausage then
		mask = bit32.bor(mask, SAUSAGE)
	end
	for _, key in plate.Toppings or {} do
		mask = bit32.bor(mask, toppingBit[key] or 0)
	end
	return mask
end

-- The plate behind a mask (bits without a key are ignored).
function PlateMask.Unpack(mask: number): Plate
	const toppings: { string } = {}
	for _, key in toppingKeys do
		if bit32.btest(mask, toppingBit[key]) then
			table.insert(toppings, key)
		end
	end
	return { Cut = bit32.btest(mask, CUT), Sausage = bit32.btest(mask, SAUSAGE), Toppings = toppings }
end

-- Bit of one topping key (0 = unknown key).
function PlateMask.ToppingBit(key: string): number
	return toppingBit[key] or 0
end

-- How many toppings the mask carries.
function PlateMask.Count(mask: number): number
	local count = 0
	for _, key in toppingKeys do
		if bit32.btest(mask, toppingBit[key]) then
			count += 1
		end
	end
	return count
end

-- Server check of a PrepTab.Plate against the stored one: integer in 0..255, only grows, no bit without a key, at most
-- `maxToppings` topping bits (Content.OrderRules.MaxToppings).
function PlateMask.Valid(old: number, new: number, maxToppings: number): boolean
	if new ~= new or new < 0 or new > FULL or new % 1 ~= 0 then
		return false
	end
	if bit32.btest(new, UNKNOWN) then
		return false
	end
	if bit32.band(old, new) ~= old then
		return false
	end
	return PlateMask.Count(new) <= maxToppings
end

return table.freeze(PlateMask)
