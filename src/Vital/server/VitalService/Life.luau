--!strict
-- Pure life-state rules (architecture.md §6.1, §6.2, §19.7; FEAT-025, FEAT-026, FEAT-034; DEC-085, DEC-094, DEC-115,
-- DEC-129). No Modux, no network, no Instances (testable in lune).
--   onZero(revivesTonight, maxPerNight)   sanity 0 -> "Down" (revivable) or "Spectator" (DEC-129: revives used up)
--   isStanding(state)                     Active or Reviving: counts for the verdict and closes the wipe window
--   isPresent(state)                      connected member (Away never counts, DEC-085 c)
--   count(states)                         present and standing members of a list of states
--   wipe(present, standing, losable)      should the 10 s window be open now

export type State = "Active" | "Down" | "Reviving" | "Spectator" | "Away"

const Life = {}

function Life.onZero(revivesTonight: number, maxPerNight: number): State
	if revivesTonight < maxPerNight then
		return "Down"
	end
	return "Spectator"
end

function Life.isStanding(state: State): boolean
	return state == "Active" or state == "Reviving"
end

function Life.isPresent(state: State): boolean
	return state ~= "Away"
end

function Life.count(states: { State }): (number, number)
	local present, standing = 0, 0
	for _, state in states do
		if Life.isPresent(state) then
			present += 1
			if Life.isStanding(state) then
				standing += 1
			end
		end
	end
	return present, standing
end

-- Window open: someone present, nobody standing, and the phase can still lose the night (Call, Prep, Night).
-- Nobody present (everyone left) is the Resume path of wave 4, never a wipe.
function Life.wipe(present: number, standing: number, losable: boolean): boolean
	return losable and present > 0 and standing == 0
end

return table.freeze(Life)
