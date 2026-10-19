--!strict
-- Gift bowl command (owner request 2026-10-14, Provisional; KitchenService gift bowls, Content.Ingredients.GiftKeys). Named gift
-- because Kitchen.luau owns the kitchen words.
--   gift              every gift topping: blocked / closed / open, amount
--   gift <key>        unlocks that bowl for this run and closes it again, full like a real unlock (TASK-288): "Open" can be tried
--   gift all          the same for every gift topping
-- The real flow: the topping unlocks on its UnlockDay (ingredient_unlocked), the bowl shows closed, "Open" fills it to capacity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

const USAGE = "gift [<topping key> | all]"

type Kitchen = {
	IsBlocked: (self: Kitchen, key: string) -> boolean,
	IsWrapped: (self: Kitchen, key: string) -> boolean,
	GetStock: (self: Kitchen, key: string) -> (number, number),
	DevWrap: (self: Kitchen, key: string) -> boolean,
}

const Gift: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "gift",
			Usage = USAGE,
			Help = "gift bowls: list them, or unlock + close one (or all), stock full, so 'Open' can be tested",
			Run = function(args: { string }, _caller: Player?): string?
				const kitchen = ctx.Get("KitchenService") :: Kitchen
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					const lines = { `{#Content.Ingredients.GiftKeys} gift topping(s)` }
					for _, key in Content.Ingredients.GiftKeys do
						const amount, capacity = kitchen:GetStock(key)
						const state = if kitchen:IsBlocked(key) then "blocked" elseif kitchen:IsWrapped(key) then "closed" else "open"
						table.insert(lines, `{key}: {state}, {amount}/{capacity}`)
					end
					return table.concat(lines, "\n")
				end
				const keys: { string } = if sub == "all" then table.clone(Content.Ingredients.GiftKeys) else { sub }
				const done: { string } = {}
				for _, key in keys do
					if not table.find(Content.Ingredients.GiftKeys, key) then
						error(`{key} is not a gift topping ({table.concat(Content.Ingredients.GiftKeys, ", ")})`, 0)
					end
					if kitchen:DevWrap(key) then
						table.insert(done, key)
					end
				end
				return `gift: {table.concat(done, ", ")} unlocked, closed and full (hold "Open" on the bowl)`
			end,
		},
	}
end

return Gift
