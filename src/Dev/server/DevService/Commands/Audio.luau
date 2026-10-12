--!strict
-- Audio counters (user request 2026-10-11, Provisional): `audio` asks the caller's client to print, in its Output,
-- how many Sound / AudioPlayer / AudioTextToSpeech... are alive, the pool, plays and new Sounds in the last minute and
-- the LoadQueue (size, requests per minute, timeouts, failures). From the Command Bar (no caller) it goes to the
-- first player.
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

const Audio: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "audio",
			Usage = "audio",
			Help = "the client prints its audio instance counts, plays/min and LoadQueue requests/min (client Output)",
			Run = function(_args: { string }, caller: Player?): string?
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player in the server", 0)
				end
				const net = (ctx.Get("NetService") :: any).Libs.Net
				net.DevAudio:fireClient(player, { Command = "report" })
				return `audio report sent to {player.Name} (client Output)`
			end,
		},
	}
end

return Audio
