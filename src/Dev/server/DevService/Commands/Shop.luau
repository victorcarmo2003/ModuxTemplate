--!strict
-- Shop and rewards (2026-10-18, docs/tech/dev-commands.md) over Parts/Shop.luau, Parts/Reward.luau, Parts/Market.luau
-- and Parts/Gear.luau. Upgrades keep their own verb (`upgrade`, Commands/Upgrade.luau).
--   shop receipt <key> [purchaseId]   fakes a Developer Product receipt (repeat the id to test idempotency)
--   shop code <text>                  redeems a code for the caller
--   shop reward endless <n> [player] | forget [player] | status [player]   gem rewards
--   shop market [reset]               Gear Stand pedestals and cooldowns; reset = every line back on sale
--   shop gear [open | close | state]  Gear Stand hours
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const Shop: Api.Module = function(ctx: Api.Context): { Api.Command }
	const shop = Kit.parts(ctx, "Shop")

	return {
		Kit.group(
			"shop",
			"shop receipt <key> [id] | code <text> | reward ... | market [reset] | gear [open|close]",
			"fake receipt, redeem a code, gem rewards, Gear Stand stock and hours",
			{
				receipt = Kit.forward(shop.receipt),
				code = Kit.forward(shop.code),
				reward = Kit.forward(Kit.parts(ctx, "Reward").reward),
				market = Kit.forward(Kit.parts(ctx, "Market").market),
				gear = Kit.forward(Kit.parts(ctx, "Gear").gear),
			}
		),
	}
end

return Shop
