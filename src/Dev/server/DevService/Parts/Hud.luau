--!strict
-- HUD commands (owner request 2026-10-12, Provisional). The HUD lives on the client, so the command goes to the caller
-- through TutorialService:DevSend (dev-only `DevClient` packet, command "hud_reveal") and HudController prints the result
-- in the client Output.
--   hud reveal all       every HUD element on screen at once (Content.HudReveal bypassed)
--   hud reveal reset     back to the essentials only (clock); the tutorial steps release the rest again
--                        (run "tutorial reset" afterwards to play the steps)
--   hud reveal status    prints which rows are on screen
-- From the Command Bar (no caller) the command goes to the first player.
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Tutorials = {
	DevSend: (self: any, player: Player, command: string, text: string?) -> (),
}

const USAGE = "hud reveal all | reset | status"
const MODES: { [string]: boolean } = { all = true, reset = true, status = true }

const Hud: Api.Module = function(ctx: Api.Context): { Api.Command }
	const tutorials = ctx.Get("TutorialService") :: Tutorials

	return {
		{
			Name = "hud",
			Usage = USAGE,
			Help = "progressive HUD: reveal all = everything on screen; reset = essentials only again; status = what is on",
			Run = function(args: { string }, caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				const mode = if args[2] then string.lower(args[2]) else "status"
				if sub ~= "reveal" or not MODES[mode] then
					error(`usage: {USAGE}`, 0)
				end
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player in the server", 0)
				end
				tutorials:DevSend(player, "hud_reveal", mode)
				return `hud reveal {mode} sent to {player.Name} (result in the client Output)`
			end,
		},
	}
end

return Hud
