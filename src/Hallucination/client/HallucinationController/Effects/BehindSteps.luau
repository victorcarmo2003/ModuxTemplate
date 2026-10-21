--!strict
-- behind_steps (owner 2026-10-21, Provisional; Content.Nights.Behind): the player cooks with the back to the window;
-- slow steps come from the window side up to right behind them, and stop. Audio only: nothing there when they turn.
local Behind = require(script.Parent.Parent.Behind)
local Context = require(script.Parent.Parent.Context)

const KEY = "behind_step" -- sound, volume and pitch tuned in Studio (Assets.SFX.Behind["Behind Step"])
const FROM = 7 -- studs behind the player where the steps start
const TO = 1.8 -- studs behind the player where they stop
const STEPS = 4
const GAP = 0.6 -- s between two steps (slow, careful)
const VOLUME = 1 -- x the Studio Sound volume
const SPEED = 1 -- x the Studio Sound pitch

const BehindSteps: Context.Effect = {
	CanRun = function(_env: Context.Env): boolean
		return Behind.Spot() ~= nil
	end,

	Play = function(env: Context.Env, run: Context.Run)
		const spot = Behind.Spot()
		if spot == nil then
			return
		end
		for index = 1, STEPS do
			const share = (index - 1) / math.max(STEPS - 1, 1)
			const studs = FROM + (TO - FROM) * share
			-- each step a little louder as it comes close
			env.Sound(KEY, Behind.At(spot, studs, 0), { Volume = VOLUME * (0.7 + 0.3 * share), Speed = SPEED, Vary = 0.08 })
			if not run:Wait(GAP + env.Random:NextNumber(-0.08, 0.12)) then
				return
			end
		end
		-- the silence right behind them
		run:Wait(1.2)
	end,
}

return BehindSteps
