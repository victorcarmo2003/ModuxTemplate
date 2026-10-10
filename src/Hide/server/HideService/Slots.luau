--!strict
-- Who sits in which hide spot (architecture.md §19.14; DEC-176: one player per spot, one spot per player).
-- Pure: no Modux, Lync or Charm. The HideService owns one table and is its only writer.

export type Spot = { Slot: number, Anchor: Instance }

export type Slots = {
	ByPlayer: { [Player]: Spot },
	BySlot: { [number]: Player },
}

const Slots = {}

function Slots.new(): Slots
	return { ByPlayer = {}, BySlot = {} }
end

function Slots.spotOf(slots: Slots, player: Player): Spot?
	return slots.ByPlayer[player]
end

function Slots.holder(slots: Slots, slot: number): Player?
	return slots.BySlot[slot]
end

-- false when the slot is taken or the player already holds a spot
function Slots.claim(slots: Slots, player: Player, slot: number, anchor: Instance): boolean
	if slots.BySlot[slot] ~= nil or slots.ByPlayer[player] ~= nil then
		return false
	end
	slots.BySlot[slot] = player
	slots.ByPlayer[player] = { Slot = slot, Anchor = anchor }
	return true
end

-- Frees the player's spot; returns it (nil when the player held none)
function Slots.release(slots: Slots, player: Player): Spot?
	const spot = slots.ByPlayer[player]
	if spot == nil then
		return nil
	end
	slots.ByPlayer[player] = nil
	if slots.BySlot[spot.Slot] == player then
		slots.BySlot[spot.Slot] = nil
	end
	return spot
end

function Slots.players(slots: Slots): { Player }
	const out: { Player } = {}
	for player in slots.ByPlayer do
		table.insert(out, player)
	end
	return out
end

return table.freeze(Slots)
