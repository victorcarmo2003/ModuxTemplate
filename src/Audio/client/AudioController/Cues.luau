--!strict
-- Default music cue for the shift state (architecture.md §19.21; content-data.md §3.21). Pure: no instance, no Vide.
-- The cue with the highest Priority whose When holds wins; a nil field in When means "any". Before the first Shift
-- record (Ready = false) only the cues with an empty When qualify (lobby). Ties keep the first in list order.
-- Also the pure picks of the shift track (once per shift, user decision 2026-10-10) and of the street ambience.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type State = {
	Ready: boolean,
	IsNight: boolean,
	Phase: string,
	Window: string?, -- RoundController.NightWindow (nil outside the Night phase)
}

const Cues = {}

function Cues.Matches(when: { IsNight: boolean?, Phase: { string }?, Window: string? }, state: State): boolean
	const empty = when.IsNight == nil and when.Phase == nil and when.Window == nil
	if not state.Ready then
		return empty
	end
	if when.IsNight ~= nil and when.IsNight ~= state.IsNight then
		return false
	end
	const phases = when.Phase
	if phases ~= nil and table.find(phases, state.Phase) == nil then
		return false
	end
	if when.Window ~= nil and when.Window ~= state.Window then
		return false
	end
	return true
end

-- Key of Content.Music, or nil when no cue holds (silence)
function Cues.Pick(cues: { Content.MusicCue }, state: State): string?
	local best: Content.MusicCue? = nil
	for _, cue in cues do
		if Cues.Matches(cue.When, state) and (best == nil or cue.Priority > best.Priority) then
			best = cue
		end
	end
	return if best then best.Key else nil
end

-- Identity of one shift (a retried night is a new shift): the shift track plays once per identity
function Cues.ShiftId(day: number, night: number, attempt: number, isNight: boolean): string
	return `{if isNight then "N" else "D"}:{day}:{night}:{attempt}`
end

-- One key of the pool, not `last` when the pool has another option; nil = empty pool
function Cues.PickTrack(pool: { string }, last: string?, rng: Random): string?
	if #pool == 0 then
		return nil
	end
	const options: { string } = {}
	for _, key in pool do
		if key ~= last then
			table.insert(options, key)
		end
	end
	const from = if #options > 0 then options else pool
	return from[rng:NextInteger(1, #from)]
end

-- Ambience key for the shift state: the zone's bed when the player is inside one (Mart), else the street of the
-- shift kind; nil = none (lobby, cutscene, phases in AmbientOff)
function Cues.Ambient(
	state: State,
	ambient: { Day: string, Night: string },
	off: { string },
	cutscene: boolean,
	zone: string?
): string?
	if not state.Ready or cutscene or table.find(off, state.Phase) ~= nil then
		return nil
	end
	if zone ~= nil then
		return zone
	end
	return if state.IsNight then ambient.Night else ambient.Day
end

return table.freeze(Cues)
