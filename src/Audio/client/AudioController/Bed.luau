--!strict
-- Ambient bed: a looped ambience made of two copies of the same Sound that crossfade (user request 2026-10-10;
-- sound-list.md §4). Never `Looped = true` while the crossfade works:
--   copy A starts at volume 0 and rises to the row Volume over F; F seconds before its end it starts to fall and, at
--   the same instant, copy B starts from the beginning rising over F; then B hands over to A, and so on.
-- F = row.Crossfade capped at TimeLength / 4 (waits for the Sound to load to read TimeLength). Stop(fade) fades the
-- playing copies out over `fade` (the crossfade between two beds: the new bed fades in over its own F).
-- Fallback: TimeLength unknown after LOAD_TIMEOUT or F = 0 -> one copy with Looped = true and a plain fade-in.
local TweenService = game:GetService("TweenService")

const LOAD_TIMEOUT = 15 -- s
const LOAD_STEP = 0.1 -- s
const MIN_TWEEN = 0.01 -- s
const MIN_GAP = 0.1 -- s between two handovers (guards a broken TimeLength)

export type Row = {
	Key: string,
	Id: string,
	Volume: number,
	Crossfade: number,
}

export type Bed = {
	Key: string,
	Stop: (fade: number?) -> (),
}

const Bed = {}

function Bed.start(row: Row, parent: Instance, group: SoundGroup?): Bed
	local alive = true
	local fadeTime = row.Crossfade
	local current = 1
	const copies: { Sound } = {}
	const tweens: { [Sound]: Tween } = {}

	for index = 1, 2 do
		const sound = Instance.new("Sound")
		sound.Name = `Amb_{row.Key}_{index}`
		sound.SoundId = row.Id
		sound.SoundGroup = group
		sound.Looped = false
		sound.Volume = 0
		sound.Parent = parent
		table.insert(copies, sound)
	end

	local function fade(sound: Sound, volume: number, time: number, done: (() -> ())?)
		const previous = tweens[sound]
		if previous then
			previous:Cancel()
		end
		const tween = TweenService:Create(sound, TweenInfo.new(math.max(time, MIN_TWEEN), Enum.EasingStyle.Sine), {
			Volume = volume,
		})
		tweens[sound] = tween
		if done then
			tween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed then
					done()
				end
			end)
		end
		tween:Play()
	end

	local function cycle()
		if not alive then
			return
		end
		const sound = copies[current]
		sound.TimePosition = 0
		sound.Volume = 0
		sound:Play()
		fade(sound, row.Volume, fadeTime)
		const length = sound.TimeLength / math.max(sound.PlaybackSpeed, MIN_TWEEN)
		task.delay(math.max(length - fadeTime, MIN_GAP), function()
			if not alive then
				return
			end
			fade(sound, 0, fadeTime, function()
				if copies[current] ~= sound then
					sound:Stop()
				end
			end)
			current = 3 - current
			cycle()
		end)
	end

	task.spawn(function()
		const first = copies[1]
		local waited = 0
		while alive and not first.IsLoaded and waited < LOAD_TIMEOUT do
			waited += task.wait(LOAD_STEP)
		end
		if not alive then
			return
		end
		const length = first.TimeLength
		if length <= 0 or row.Crossfade <= 0 then
			-- no length to schedule on: plain loop with a fade-in
			first.Looped = true
			first:Play()
			fade(first, row.Volume, row.Crossfade)
			return
		end
		fadeTime = math.min(row.Crossfade, length / 4)
		cycle()
	end)

	return {
		Key = row.Key,
		Stop = function(time: number?)
			if not alive then
				return
			end
			alive = false
			const out = if time ~= nil then time else fadeTime
			for _, sound in copies do
				if sound.IsPlaying and out > 0 then
					fade(sound, 0, out, function()
						sound:Destroy()
					end)
				else
					sound:Destroy()
				end
			end
		end,
	}
end

return table.freeze(Bed)
