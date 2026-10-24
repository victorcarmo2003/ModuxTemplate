--!strict
-- shadow_dash (family D, Weight 0: never drawn on its own; owner 2026-10-21, Provisional): the black cloak dash of
-- cave_sound's whoosh on demand (`dev scare shadow_dash`). With no street point in view it is only the whoosh nearby.
local Cloak = require(script.Parent.Parent.Cloak)
local Context = require(script.Parent.Parent.Context)

const WHOOSH = "shadow_whoosh"
const SIDE = 20 -- studs: the fallback whoosh, to one side of the player
const TIME = 3

const ShadowDash: Context.Effect = {
	Play = function(env: Context.Env, run: Context.Run)
		if Cloak.Dash(env, run) then
			return
		end
		const camera = Context.Camera()
		if camera == nil then
			return
		end
		const side = if env.Random:NextNumber() < 0.5 then -SIDE else SIDE
		env.Sound(WHOOSH, camera.CFrame:PointToWorldSpace(Vector3.new(side, 0, -SIDE * 0.5)), { Scare = true })
		run:Wait(TIME)
	end,
}

return ShadowDash
