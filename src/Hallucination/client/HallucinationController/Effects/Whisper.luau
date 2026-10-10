--!strict
-- whisper (< 20; script.md §8, sound-list.md SFX-132): a low, distant "Rookie..." on this client only. While the
-- sound is silent (Id "", Q-168) or missing, the fallback of sound-list.md §7 applies: a faint line on screen only
-- (WhisperLine), no speaker, no prompt.
local Context = require(script.Parent.Parent.Context)

const KEY = "whisper"
const TEXT = "Rookie..." -- script.md §8
const TIME = 1.8 -- s on screen
const VOLUME = 0.6 -- low and distant; under the scare cap (DEC-173)
const SIDE = 6 -- studs: from behind one shoulder

const Whisper: Context.Effect = {
	Play = function(env: Context.Env, run: Context.Run)
		local at: Vector3? = nil
		const camera = Context.Camera()
		if camera then
			const side = if env.Random:NextNumber() < 0.5 then -SIDE else SIDE
			at = camera.CFrame:PointToWorldSpace(Vector3.new(side, 0, SIDE * 0.5))
		end
		const sound = env.Sound(KEY, at, { Volume = VOLUME, Scare = true })
		if sound ~= nil then
			run:Wait(TIME)
			return
		end
		run:Cleanup(function()
			env.Whisper("")
		end)
		env.Whisper(TEXT)
		run:Wait(TIME)
	end,
}

return Whisper
