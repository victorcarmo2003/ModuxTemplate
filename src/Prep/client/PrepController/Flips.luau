--!strict
-- Flips: whether the sausage of a grill record has REALLY been flipped, read on the client (playtest 2026-10-14, bug "after a
-- wrong order the new sausage showed no flip, looked ready and the rail said Not ready yet").
-- Root cause: the Stations set is a Lync replicate set and `set:update(id, value)` only writes the fields PRESENT in `value`;
-- a field set to nil is skipped, not cleared (Lync 4 Sync.update; clearing needs `Lync.none`). The grill writes `Flip = nil`
-- on Collect / Discard / Place, so the client keeps the PREVIOUS sausage's flip stamp on that slot: the next sausage there reads
-- as flipped from the start (no flip window, the cooking bar runs past the pause, the check shows) while the server waits for a
-- flip. The writer is KitchenService (fix there: publish `Lync.none` for a nil Flip / Altered); this guard makes the prep mode
-- right whatever the wire does, from one invariant of the server: a flip re-bases StartedAt to `now - FirstSide`, so a record
-- that is really flipped always has `now - StartedAt >= FirstSide`. A record with a Flip stamp that is still on its first side is
-- a leftover: its StartedAt is remembered, and the stamp only counts again once StartedAt moves (the re-base of a real flip).
-- Module state keyed by Stations record id (StationId * 100 + slot). Pure reads, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)

const SLACK = 0.25 -- s: the clock of the client and the re-base of the server never line up to the frame

const Flips = {}

-- record id -> StartedAt of the sausage that carries a leftover stamp (false = seen empty, the next sausage is not known yet)
local leftover: { [number]: number | false } = {}

-- true when the record (a grill slot of the Stations set) carries a flip of ITS OWN sausage. `now` = server clock.
function Flips.Live(id: number, record: any?, now: number): boolean
	if record == nil then
		leftover[id] = nil
		return false
	end
	const stamp = record.Flip or 0
	if stamp <= 0 then
		leftover[id] = nil
		return false
	end
	if record.State == "Empty" then
		leftover[id] = false
		return false
	end
	if record.State == "Ready" then
		-- the server only makes a FLIPPED sausage Ready
		leftover[id] = nil
		return true
	end
	const startedAt: number = record.StartedAt or 0
	const first = Grade.FirstSide(Content.Prep, record.Duration or 0)
	const firstSide = now - startedAt < first - SLACK
	const known = leftover[id]
	if known ~= nil then
		if known == false then
			if firstSide then
				-- the new sausage of the slot: the stamp is the old one's
				leftover[id] = startedAt
				return false
			end
			-- placed and re-based while nobody looked: trust the stamp
			leftover[id] = nil
			return true
		elseif known == startedAt then
			return false
		end
		-- StartedAt moved: the real flip re-based it
		leftover[id] = nil
		return not firstSide
	end
	if firstSide then
		-- a flipped sausage is never on its first side: a leftover stamp
		leftover[id] = startedAt
		return false
	end
	return true
end

-- The flip stamp as the prep mode should read it (0 = not flipped).
function Flips.Stamp(id: number, record: any?, now: number): number
	return if Flips.Live(id, record, now) then (record :: any).Flip else 0
end

return Flips
