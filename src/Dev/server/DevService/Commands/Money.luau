--!strict
-- Money (2026-10-18, docs/tech/dev-commands.md) over Parts/Economy.luau and Parts/Tips.luau.
--   money cash <n>             adds n to the party Cash (negative removes, never below 0)
--   money gems <n> [player]    adds n gems to a profile (default: you / the only player)
--   money tips [state | add <n>]   tips straight to Cash (the tip jar left, owner 2026-10-22)
--   money ledger               pure test of the shift settlement (take, bonus, deposit); ends with N/N ok
-- `cash` / `gems` stay hidden for the Admin console shortcuts.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Money: Api.Module = function(ctx: Api.Context): { Api.Command }
	const economy = Kit.parts(ctx, "Economy")
	const tips = Kit.parts(ctx, "Tips")

	return {
		Kit.group(
			"money",
			"money cash <n> | gems <n> [player] | tips [state|add <n>] | ledger",
			"add Cash or gems, a tip, the settlement test",
			{
				cash = Kit.forward(economy.cash),
				gems = Kit.forward(economy.gems),
				tips = Kit.forward(tips.tips),
				ledger = Kit.forward(tips.economy, { "ledger" }),
			}
		),
		Kit.alias("cash", economy.cash),
		Kit.alias("gems", economy.gems),
	}
end

return Money
