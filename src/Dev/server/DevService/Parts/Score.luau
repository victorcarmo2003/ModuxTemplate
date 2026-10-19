--!strict
-- Horror score (TASK-443, owner request 2026-10-17; Content.Score, AnomalyController/Score on the client). Presentation
-- only: nothing on the server changes, the caller's client forces its director to a stage until `score auto`.
--   score <calm|uneasy|tension|climax|release>   forces that stage (Tension ramps over 15 s from now)
--   score auto                                    back to the anomalies driving it
-- From the Command Bar (no caller) it goes to the first player. The reply of the client is in its Output.
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

const USAGE = "score <calm|uneasy|tension|climax|release|auto>"
const STAGES: { [string]: boolean } = {
	calm = true,
	uneasy = true,
	tension = true,
	climax = true,
	release = true,
	auto = true,
}

const Score: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "score",
			Usage = USAGE,
			Help = "forces the horror score stage on your client (calm, uneasy, tension, climax, release) or back to auto",
			Run = function(args: { string }, caller: Player?): string?
				const stage = string.lower(args[1] or "")
				if not STAGES[stage] then
					error(`usage: {USAGE}`, 0)
				end
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player in the server", 0)
				end
				const net = (ctx.Get("NetService") :: any).Libs.Net
				net.DevAudio:fireClient(player, { Command = `score:{stage}` })
				return `score {stage} sent to {player.Name} (client Output)`
			end,
		},
	}
end

return Score
