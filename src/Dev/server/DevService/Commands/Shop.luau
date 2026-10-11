--!strict
-- Shop and codes commands (TASK-160, TASK-161). Same paths as play: the receipt goes through ShopService:Fulfil (grant
-- once per PurchaseId, confirmed save), the code through CodesService:Redeem (no network rate limit here).
--   receipt <shop key> [purchaseId]   fake receipt for a Content.Shop key (gems_50, class_rabbit...); same id = no grant
--   code <text>                       redeems a code for the caller (Command Bar: the first player)
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Shop = {
	DevReceipt: (self: any, player: Player, key: string, purchaseId: string) -> string,
}
type Codes = {
	Redeem: (self: any, player: Player, raw: string) -> (string, { Gems: number, Class: string? }),
}

local function target(caller: Player?): Player
	const player = caller or Players:GetPlayers()[1]
	if player == nil then
		error("no player in the server", 0)
	end
	return player
end

const Shop: Api.Module = function(ctx: Api.Context): { Api.Command }
	const shop = ctx.Get("ShopService") :: Shop
	const codes = ctx.Get("CodesService") :: Codes
	local count = 0

	return {
		{
			Name = "receipt",
			Usage = "receipt <gems_50|class_rabbit|...> [purchaseId]",
			Help = "fakes a Developer Product receipt for a Content.Shop key (repeat the id to test idempotency)",
			Run = function(args: { string }, caller: Player?): string?
				const key = args[1]
				if key == nil then
					error("usage: receipt <shop key> [purchaseId]", 0)
				end
				count += 1
				const purchaseId = args[2] or `dev-{os.time()}-{count}`
				const player = target(caller)
				return `{purchaseId}: {shop:DevReceipt(player, key, purchaseId)}`
			end,
		},
		{
			Name = "code",
			Usage = "code <text>",
			Help = "redeems a code for the caller (Ok / Invalid / Expired / Already / Busy)",
			Run = function(args: { string }, caller: Player?): string?
				if #args == 0 then
					error("usage: code <text>", 0)
				end
				const reason, reward = codes:Redeem(target(caller), table.concat(args, " "))
				return `{reason}: +{reward.Gems} gems{if reward.Class then `, {reward.Class}` else ""}`
			end,
		},
	}
end

return Shop
