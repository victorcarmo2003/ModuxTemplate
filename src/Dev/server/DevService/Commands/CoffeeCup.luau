--!strict
-- Coffee cup command (owner request 2026-10-12; Content.CoffeeCup, CoffeeCupController). Named coffeecup because
-- Kitchen.luau owns "coffee". Forces the cup on the trailer counter without brewing: sets `CupDev` on every cup tagged CoffeeCup (replicated attribute, the client tweens).
--   coffeecup              cups found and their forced state
--   coffeecup fill         surface rises (Ready look)
--   coffeecup empty        surface sinks and fades
--   coffeecup sip          visual only: the coffee of the hand cup sinks for a moment and comes back (needs 'give' first), nothing is drunk
--   coffeecup give         puts a full coffee (Sanity.Coffee) in the hand of the caller / first player: click it to drink it (real flow, night only)
--   coffeecup auto         follows the coffee machine again (the real flow: Take Coffee, then click the coffee to drink)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

const USAGE = "coffeecup [fill | empty | sip | give | auto]"
const MODES: { [string]: string? } = { fill = "fill", empty = "empty", auto = nil }

const Coffee: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "coffeecup",
			Usage = USAGE,
			Help = "coffee cup on the counter: 'fill' / 'empty' force the surface tween, 'auto' follows the machine; 'give' puts a coffee in your hand, 'sip' previews the drink on it",
			Run = function(args: { string }, caller: Player?): string?
				const params = Content.CoffeeCup
				const cups = CollectionService:GetTagged(params.Tag)
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					const lines = { `{#cups} cup(s) tagged {params.Tag}` }
					for _, cup in cups do
						table.insert(lines, `{cup:GetFullName()}: dev={cup:GetAttribute(params.DevAttribute) or "auto"}`)
					end
					return table.concat(lines, "\n")
				end
				if sub == "give" then
					const target = caller or Players:GetPlayers()[1]
					if target == nil then
						error("no player", 0)
					end
					const item = ctx.Get("ItemService")
					const tool = item:Give(target, "coffee", { Restore = Content.Sanity.Coffee })
					return if tool then `coffeecup: coffee given to {target.Name}` else "coffeecup: Give refused (hands full / already holds one)"
				end
				if sub ~= "fill" and sub ~= "empty" and sub ~= "auto" and sub ~= "sip" then
					error(`usage: {USAGE}`, 0)
				end
				if #cups == 0 then
					error(`no instance tagged {params.Tag} (run tools/assetplace/coffee_cup.luau)`, 0)
				end
				if sub == "sip" then
					-- visual only: the coffee of the hand cup sinks and comes back (the Tool is not consumed, nothing restored)
					const target = caller or Players:GetPlayers()[1]
					if target == nil then
						error("no player", 0)
					end
					const attribute = params.Sips.DrinkingAttribute
					local shown = 0
					for _, container in { target.Character, target:FindFirstChildOfClass("Backpack") } do
						for _, tool in container:GetChildren() do
							if tool:IsA("Tool") and tool:FindFirstChild("HandCup") then
								tool:SetAttribute(attribute, true)
								shown += 1
								task.delay(params.Sips.EmptySeconds + 1, function()
									tool:SetAttribute(attribute, nil)
								end)
							end
						end
					end
					if shown == 0 then
						error("no coffee in the hand: run 'coffeecup give' first", 0)
					end
					return `coffeecup: sip preview on {shown} hand cup(s)`
				end
				for _, cup in cups do
					cup:SetAttribute(params.DevAttribute, MODES[sub])
				end
				return `coffeecup: {sub} ({#cups})`
			end,
		},
	}
end

return Coffee
