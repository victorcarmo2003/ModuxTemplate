--!strict
-- Coffee (2026-10-18, docs/tech/dev-commands.md): the machine doses, the cup and a coffee in the hand, over
-- Parts/Kitchen.luau (`coffee [n]`), Parts/Tester.luau (`mycoffee`), Parts/CoffeeMachine.luau and Parts/CoffeeCup.luau.
--   coffee [n]                         doses in the machine: show, or set n (clamped to the capacity)
--   coffee give [player]               a full coffee in the hand (click it to drink; night only)
--   coffee take                        the caller takes the waiting coffee, the machine starts its clean wait
--   coffee cup fill|empty|sip|give|auto   the counter cup (surface tween, sip preview, back to the machine)
-- `mycoffee` stays hidden for the settings panel dev row (Net.DevTool).
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Coffee: Api.Module = function(ctx: Api.Context): { Api.Command }
	const doses = Kit.parts(ctx, "Kitchen").coffee
	const mine = Kit.parts(ctx, "Tester").mycoffee
	const machine = Kit.parts(ctx, "CoffeeMachine").coffeemachine
	const cup = Kit.parts(ctx, "CoffeeCup").coffeecup

	return {
		Kit.group(
			"coffee",
			"coffee [n | give [player] | take | cup fill|empty|sip|give|auto]",
			"machine doses (show / set), a coffee in your hand, take the waiting one, the counter cup",
			{
				give = Kit.forward(mine),
				take = Kit.forward(machine, { "take" }),
				cup = Kit.forward(cup),
			},
			Kit.forward(doses)
		),
		Kit.alias("mycoffee", mine),
	}
end

return Coffee
