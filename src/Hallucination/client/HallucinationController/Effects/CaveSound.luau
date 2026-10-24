--!strict
-- cave_sound (< 60, family D; owner 2026-10-21, Provisional): cave-style ambience like Minecraft's - one low boom, wail,
-- metal whine, eerie texture or whoosh, played 3D from a point around the player so it has a direction. Nothing to do,
-- no cost. Silent keys (Id "") just skip.
-- The black cloak with the whoosh is no longer here: it dashes only in the talk close-up (Rules.TalkDash, owner 2026-10-21).
-- A key with a GAIN skips the scare volume cap (the owner set cave_low louder on purpose).
local Context = require(script.Parent.Parent.Context)

const KEYS = { "cave_low", "cave_wail", "cave_metal", "cave_eerie", "shadow_whoosh" }
-- gain over the Content row (rows stop at 1): the owner raised cave_low to 2 in Studio
const GAIN: { [string]: number } = { cave_low = 2 }
const DISTANCE = { 18, 40 } -- studs from the player (min, max)
const HEIGHT = { -2, 8 } -- studs over the player's head (some come from above)
const TIME = 6 -- s the effect holds its slot (the longest sound tails off)

const CaveSound: Context.Effect = {
	Play = function(env: Context.Env, run: Context.Run)
		const camera = Context.Camera()
		if camera == nil then
			return
		end
		const random = env.Random
		const key = KEYS[random:NextInteger(1, #KEYS)]
		const angle = random:NextNumber() * math.pi * 2
		const distance = random:NextNumber(DISTANCE[1], DISTANCE[2])
		const height = random:NextNumber(HEIGHT[1], HEIGHT[2])
		const origin = camera.CFrame.Position
		const at = origin + Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
		if env.Sound(key, at, { Volume = GAIN[key], Vary = 0.08, Scare = GAIN[key] == nil }) == nil then
			return
		end
		run:Wait(TIME)
	end,
}

return CaveSound
