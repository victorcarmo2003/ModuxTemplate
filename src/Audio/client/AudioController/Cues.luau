--!strict
-- Default music cue for the shift state (architecture.md §19.21; content-data.md §3.21). Pure: no instance, no Vide.
-- The cue with the highest Priority whose When holds wins; a nil field in When means "any". Before the first Shift
-- record (Ready = false) only the cues with an empty When qualify (lobby). Ties keep the first in list order.
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

return table.freeze(Cues)
