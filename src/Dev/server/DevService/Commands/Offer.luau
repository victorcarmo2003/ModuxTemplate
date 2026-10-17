--!strict
-- Contextual offers (TASK-366; owner request 2026-10-17, Provisional; Content.Shop.Offers, OfferController). The
-- offers live on the client, so the command goes to the caller through TutorialService:DevSend (dev-only `DevClient`
-- packet, command "offer") and OfferController prints the result in the client Output.
--   offer list           the offer keys
--   offer status         budget, fatigue, control / A-B group, what blocks offers now
--   offer reset          clears every counter (gap, per shift, muted, paused, memories)
--   offer <key>          forces that offer on the HUD note now (budget off), e.g. offer offer_restock
-- From the Command Bar (no caller) the command goes to the first player.
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Tutorials = {
	DevSend: (self: any, player: Player, command: string, text: string?) -> (),
}

const USAGE = "offer list | status | reset | <offer key>"

const Offer: Api.Module = function(ctx: Api.Context): { Api.Command }
	const tutorials = ctx.Get("TutorialService") :: Tutorials

	return {
		{
			Name = "offer",
			Usage = USAGE,
			Help = "contextual shop offers: list / status / reset, or force one on the HUD note (e.g. offer offer_coffee)",
			Run = function(args: { string }, caller: Player?): string?
				const word = if args[1] then string.lower(args[1]) else "status"
				const player = caller or Players:GetPlayers()[1]
				if player == nil then
					error("no player in the server", 0)
				end
				tutorials:DevSend(player, "offer", word)
				return `offer {word} sent to {player.Name} (result in the client Output)`
			end,
		},
	}
end

return Offer
