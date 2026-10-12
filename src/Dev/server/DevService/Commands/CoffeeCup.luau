--!strict
-- Coffee cup command (owner request 2026-10-12; Content.CoffeeCup, CoffeeCupController). Named coffeecup because
-- Kitchen.luau owns "coffee". Forces the cup on the trailer counter without brewing: sets `CupDev` on every cup tagged CoffeeCup (replicated attribute, the client tweens).
--   coffeecup              cups found and their forced state
--   coffeecup fill         surface rises (Ready look)
--   coffeecup empty        surface sinks and fades
--   coffeecup auto         follows the coffee machine again
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

const USAGE = "coffeecup [fill | empty | auto]"
const MODES: { [string]: string? } = { fill = "fill", empty = "empty", auto = nil }

const Coffee: Api.Module = function(_ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "coffeecup",
			Usage = USAGE,
			Help = "coffee cup on the counter: 'fill' / 'empty' force the surface tween, 'auto' follows the machine",
			Run = function(args: { string }, _caller: Player?): string?
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
				if sub ~= "fill" and sub ~= "empty" and sub ~= "auto" then
					error(`usage: {USAGE}`, 0)
				end
				if #cups == 0 then
					error(`no instance tagged {params.Tag} (run tools/assetplace/coffee_cup.luau)`, 0)
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
