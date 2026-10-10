--!strict
-- Thief commands (board TASK-072; FEAT-013). Thin wrappers over ThiefService (DevNow checks IsDev and the phase).
--   thief                 state, today's plan and the drawer
--   thief now [L1|L2|L3]  spawns Quick Quentin now (ignores chance, window and MaxPerDay; shop open by day only)
--   thief sim <day> [n]   share of n run seeds (default 1000) with a thief on <day> (FEAT-013 acceptance: 0 / 50 / 70%)
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Draw = require(ServerScriptService.server.Thief.ThiefService.Draw)

type Thief = {
	GetState: (self: any) -> string,
	GetPlan: (self: any) -> Draw.Plan?,
	DevNow: (self: any, lurk: string?) -> number,
}

type Economy = {
	GetDrawer: (self: any) -> number,
}

const SIM_DEFAULT = 1000
const SIM_MAX = 100000

local function clock(minutes: number): string
	const total = math.floor(minutes)
	return string.format("%02d:%02d", (total // 60) % 24, total % 60)
end

local function integerOf(text: string?, usage: string, min: number, max: number): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= math.floor(value) or value < min or value > max then
		error(`usage: {usage}`, 0)
	end
	return value
end

const Thief: Api.Module = function(ctx: Api.Context): { Api.Command }
	const thief = ctx.Get("ThiefService") :: Thief
	const economy = ctx.Get("EconomyService") :: Economy

	return {
		{
			Name = "thief",
			Usage = "thief [now [L1|L2|L3] | sim <day> [n]]",
			Help = "thief state and today's plan; 'now' spawns Quick Quentin; 'sim' checks the daily chance",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else nil
				if sub == nil then
					const plan = thief:GetPlan()
					const planText = if plan then `planned {clock(plan.At)} at {plan.Lurk}` else "no plan left today"
					return `Thief {thief:GetState()}; {planText}; drawer ${economy:GetDrawer()}`
				elseif sub == "now" then
					const lurk = if args[2] then string.upper(args[2]) else nil
					const id = thief:DevNow(lurk)
					return `Quick Quentin spawned (NpcId {id})`
				elseif sub == "sim" then
					const usage = "thief sim <day> [n]"
					const day = integerOf(args[2], usage, 1, 10000)
					const count = if args[3] then integerOf(args[3], usage, 1, SIM_MAX) else SIM_DEFAULT
					const seeds = Random.new()
					local hits = 0
					for _ = 1, count do
						if Draw.roll(seeds:NextInteger(1, 2147483647), day) ~= nil then
							hits += 1
						end
					end
					const share = string.format("%.1f", hits * 100 / count)
					const chance = math.floor(Draw.chance(day) * 100 + 0.5)
					return `Day {day}: thief on {hits} of {count} runs ({share}%, chance {chance}%)`
				end
				error("usage: thief [now [L1|L2|L3] | sim <day> [n]]", 0)
			end,
		},
	}
end

return Thief
