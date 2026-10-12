--!strict
-- SeatingService/Tables: Pad table rules, pure (FEAT-037; Content.Seating; TASK-145). No Service, no network, no
-- Instance: table states from the purchases, the sit chance, the eat time and the table choice. Same Random state
-- in = same result out (the caller passes the shift Random).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type State = "Locked" | "Ghost" | "Free" | "Occupied" | "Dirty"

const SEATING = Content.Seating

const Tables = {}

-- State of table `index` (position inside its group, 1..Count) when it is not in use: bought (Free), for sale / waiting
-- its turn (Ghost), or not visible yet (Locked: before Seating.UnlockDay nobody sees a ghost, FEAT-037; a group with
-- ghostAll = false shows only the next table for sale, the later ones stay Locked until it is bought).
function Tables.Idle(index: number, owned: number, unlocked: boolean, ghostAll: boolean): State
	if index <= owned then
		return "Free"
	end
	if not unlocked or (not ghostAll and index > owned + 1) then
		return "Locked"
	end
	return "Ghost"
end

-- A bought table keeps Occupied / Dirty; anything else follows the purchases.
function Tables.Next(current: State, index: number, owned: number, unlocked: boolean, ghostAll: boolean): State
	if index <= owned and current == "Occupied" then
		return "Occupied"
	elseif index <= owned and current == "Dirty" then
		return "Dirty"
	end
	return Tables.Idle(index, owned, unlocked, ghostAll)
end

-- Sit chance (FEAT-037): SitChance of the leader's type, x NightSitMult at night, + GroupSitBonus for a pair, + the
-- SitBonus effect (Patio Lights), capped at SitChanceCap.
function Tables.Chance(sitChance: number, isNight: boolean, isPair: boolean, bonus: number): number
	local chance = sitChance
	if isNight then
		chance *= SEATING.NightSitMult
	end
	if isPair then
		chance += SEATING.GroupSitBonus
	end
	chance += math.max(bonus, 0)
	if sitChance <= 0 then
		return 0 -- a type that never sits never does (Pickett, pedestrians)
	end
	return math.clamp(chance, 0, SEATING.SitChanceCap)
end

-- Seconds at the table: Day / Night +- Jitter, + GroupExtra for a pair.
function Tables.EatTime(isNight: boolean, isPair: boolean, rng: Random): number
	const eat = SEATING.EatTime
	local base = if isNight then eat.Night else eat.Day
	if isPair then
		base += eat.GroupExtra
	end
	return base + eat.Jitter * (2 * rng:NextNumber() - 1)
end

-- MaxDiners of the shift.
function Tables.MaxDiners(isNight: boolean): number
	return if isNight then SEATING.MaxDiners.Night else SEATING.MaxDiners.Day
end

-- Seat numbers for a party (Solo; pair face to face; couple side by side).
function Tables.Seats(size: number, couple: boolean): { number }
	if size <= 1 then
		return SEATING.Seats.Solo
	end
	return if couple then SEATING.Seats.Couple else SEATING.Seats.Pair
end

-- Lowest index whose state is Free and `usable(index)` says yes (the table nearest to Q1, FEAT-037; `usable` also
-- keeps the party inside one group). nil = none.
function Tables.Pick(states: { State }, usable: (index: number) -> boolean): number?
	for index, state in states do
		if state == "Free" and usable(index) then
			return index
		end
	end
	return nil
end

-- Tip left by `diners` on a table already holding `tip` (wire cap Seating.MaxTip).
function Tables.Tip(tip: number, diners: number): number
	return math.clamp(tip + SEATING.TableTip * diners, 0, SEATING.MaxTip)
end

return table.freeze(Tables)
