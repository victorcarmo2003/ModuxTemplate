--!strict
-- Timeline: pure reads of a cutscene segment at a given elapsed time (Content.Cutscenes; architecture.md §19.16).
-- Everything the screen shows is a function of (beats, elapsed), so a client that joins in the middle of a segment
-- (late join, rejoin, stream) shows the same frame as everyone else without replaying what already happened.
-- No instance, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

type Beat = Content.CutsceneBeat
type Scene = Content.Cutscene

const Timeline = {}

-- Beats of a scene for this variant (nil Variant = both), sorted by At (stable on ties: list order)
function Timeline.Beats(scene: Scene, party: boolean): { Beat }
	const variant = if party then "Party" else "Solo"
	type Entry = { Beat: Beat, Order: number }
	const out: { Entry } = {}
	for order, beat in scene.Beats do
		if beat.Variant == nil or beat.Variant == variant then
			table.insert(out, { Beat = beat, Order = order })
		end
	end
	table.sort(out, function(a: Entry, b: Entry): boolean
		if a.Beat.At == b.Beat.At then
			return a.Order < b.Order
		end
		return a.Beat.At < b.Beat.At
	end)
	const beats: { Beat } = {}
	for _, entry in out do
		table.insert(beats, entry.Beat)
	end
	return beats
end

-- Last beat of a kind that already started (and its index), or nil
function Timeline.Last(beats: { Beat }, kind: string, elapsed: number): (Beat?, number)
	local found: Beat? = nil
	local index = 0
	for i, beat in beats do
		if beat.At > elapsed then
			break
		end
		if beat.Kind == kind then
			found = beat
			index = i
		end
	end
	return found, index
end

-- Last beat of any of `kinds` that already started (and its index), or nil
function Timeline.LastOf(beats: { Beat }, kinds: { [string]: boolean }, elapsed: number): (Beat?, number)
	local found: Beat? = nil
	local index = 0
	for i, beat in beats do
		if beat.At > elapsed then
			break
		end
		if kinds[beat.Kind] then
			found = beat
			index = i
		end
	end
	return found, index
end

-- Next beat of a kind after index `from`, or nil
function Timeline.Next(beats: { Beat }, kind: string, from: number): Beat?
	for i = from + 1, #beats do
		if beats[i].Kind == kind then
			return beats[i]
		end
	end
	return nil
end

-- 0 = clear, 1 = black. Before the first Fade beat the screen is black when that beat is a fade in. A beat's own Duration
-- replaces `fadeTime` (a slow fade in of the dark scenes, a hard cut to black).
function Timeline.Fade(beats: { Beat }, elapsed: number, fadeTime: number): number
	const last = Timeline.Last(beats, "Fade", elapsed)
	if last == nil then
		const first = Timeline.Next(beats, "Fade", 0)
		return if first ~= nil and first.Target == "In" then 1 else 0
	end
	const progress = math.clamp((elapsed - last.At) / math.max(last.Duration or fadeTime, 1e-3), 0, 1)
	return if last.Target == "In" then 1 - progress else progress
end

-- Line on screen: the last Line beat, until the next one or `hold` seconds
function Timeline.Line(beats: { Beat }, elapsed: number, hold: number): Beat?
	const last, index = Timeline.Last(beats, "Line", elapsed)
	if last == nil then
		return nil
	end
	const nextLine = Timeline.Next(beats, "Line", index)
	local ends = last.At + hold
	if nextLine ~= nil then
		ends = math.min(ends, nextLine.At)
	end
	return if elapsed < ends then last else nil
end

-- Title on screen: the beat's Hold or `hold` seconds; a "Credits" title stays until the next Fade beat (or the end of the scene)
function Timeline.Title(beats: { Beat }, elapsed: number, hold: number, duration: number): Beat?
	const last, index = Timeline.Last(beats, "Text", elapsed)
	if last == nil then
		return nil
	end
	local ends = last.At + (last.Hold or hold)
	if last.Target == "Credits" then
		const fade = Timeline.Next(beats, "Fade", index)
		ends = if fade ~= nil then fade.At else duration
	end
	return if elapsed < ends then last else nil
end

-- Credits roll (Rules.Credits, TASK-657): 0..1 of the scroll of `scene` at `elapsed` (0 = the roll under the screen,
-- 1 = gone above it), or nil when the roll is not on screen (another scene, before At, after At + Roll)
function Timeline.Roll(scene: Scene, elapsed: number): number?
	const credits = Content.Cutscenes.Rules.Credits
	if scene.Key ~= credits.Scene or elapsed < credits.At then
		return nil
	end
	const progress = (elapsed - credits.At) / math.max(credits.Roll, 1e-3)
	return if progress < 1 then progress else nil
end

-- Prompt beat on screen during [At, At + time)
function Timeline.Prompt(beats: { Beat }, elapsed: number, time: number): Beat?
	const last = Timeline.Last(beats, "Prompt", elapsed)
	if last ~= nil and elapsed < last.At + time then
		return last
	end
	return nil
end

return table.freeze(Timeline)
