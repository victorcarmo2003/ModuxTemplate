--!strict
-- Interface (2026-10-18, docs/tech/dev-commands.md) over Parts/Hud.luau, Offer, Journal, Rejoin and Showcase.
--   ui hud reveal all | reset | status     progressive HUD
--   ui offer list | status | reset | <key> contextual shop offers (force one on the HUD note)
--   ui journal [all | reset | open | <ANM-###>]   Anomaly Tablet pages of the caller
--   ui rejoin [resume | hide | status]     the rejoin card
--   ui showcase                            the dev showcase panel (F9 toggles it)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Ui: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		Kit.group(
			"ui",
			"ui hud reveal all|reset|status | offer ... | journal ... | rejoin ... | showcase",
			"HUD reveal, shop offers, journal pages, rejoin card, the showcase panel",
			{
				hud = Kit.forward(Kit.parts(ctx, "Hud").hud),
				offer = Kit.forward(Kit.parts(ctx, "Offer").offer),
				journal = Kit.forward(Kit.parts(ctx, "Journal").journal),
				rejoin = Kit.forward(Kit.parts(ctx, "Rejoin").rejoin),
				showcase = Kit.forward(Kit.parts(ctx, "Showcase").showcase),
			}
		),
	}
end

return Ui
