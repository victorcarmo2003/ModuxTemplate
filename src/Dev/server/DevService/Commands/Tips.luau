--!strict
-- Tip jar and ledger commands (TASK-242; DEC-238, DEC-239; Provisional). Thin wrappers over EconomyService / TipJarService.
--   tips                      jar, Cash and the shift ledger (same as `tips state`)
--   tips add <n>              puts n in the tip jar (needs the shop taking entries: a selling phase or the day Closing)
--   tips collect              the jar goes to Cash and the coins play (same as the "Collect Tips" prompt)
--   economy ledger            pure test of Ledger.settle (day take = Sales + Tips + Catches - Stolen, bonus, deposit);
--                             prints one line per case and ends with "N/N ok"
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)
local Ledger = require(ServerScriptService.server.Economy.EconomyService.Ledger)

type Economy = {
	GetCash: (self: any) -> number,
	GetDrawer: (self: any) -> number,
	IsDrawerOpen: (self: any) -> boolean,
	AddTip: (self: any, amount: number) -> number,
	GetLedger: (self: any) -> Ledger.Ledger,
}

type TipJar = {
	CollectNow: (self: any) -> number,
}

const ADD_MAX = 100000

local function integerOf(text: string?, usage: string, min: number, max: number): number
	const value = if text then tonumber(text) else nil
	if value == nil or value ~= math.floor(value) or value < min or value > max then
		error(`usage: {usage}`, 0)
	end
	return value
end

-- One settle case: counters in, expected take / bonus / deposited out
type Case = {
	Name: string,
	Arrived: number,
	Completed: number,
	Sales: number,
	Tips: number,
	Catches: number,
	Stolen: number,
	Boss: number,
	Grade: Ledger.Grade,
	Take: number,
	Bonus: number,
	Deposited: number,
}

const CASES: { Case } = {
	{ Name = "A: all satisfied", Arrived = 10, Completed = 10, Sales = 50, Tips = 10, Catches = 5, Stolen = 0, Boss = 0, Grade = "A", Take = 65, Bonus = 13, Deposited = 78 },
	{ Name = "B: 8 of 10", Arrived = 10, Completed = 8, Sales = 100, Tips = 0, Catches = 0, Stolen = 0, Boss = 0, Grade = "B", Take = 100, Bonus = 10, Deposited = 110 },
	{ Name = "C: 5 of 10 (no bonus)", Arrived = 10, Completed = 5, Sales = 40, Tips = 4, Catches = 0, Stolen = 0, Boss = 0, Grade = "C", Take = 44, Bonus = 0, Deposited = 44 },
	{ Name = "D: 4 of 10 (no bonus, boss does not help)", Arrived = 10, Completed = 4, Sales = 60, Tips = 0, Catches = 0, Stolen = 0, Boss = 5, Grade = "D", Take = 60, Bonus = 0, Deposited = 60 },
	{ Name = "stolen leaves the base", Arrived = 10, Completed = 10, Sales = 50, Tips = 20, Catches = 0, Stolen = 10, Boss = 0, Grade = "A", Take = 60, Bonus = 12, Deposited = 72 },
	{ Name = "boss points add to B", Arrived = 4, Completed = 3, Sales = 40, Tips = 0, Catches = 0, Stolen = 0, Boss = 5, Grade = "B", Take = 40, Bonus = 6, Deposited = 46 },
	{ Name = "nobody came: C, zero", Arrived = 0, Completed = 0, Sales = 0, Tips = 0, Catches = 0, Stolen = 0, Boss = 0, Grade = "C", Take = 0, Bonus = 0, Deposited = 0 },
	{ Name = "stolen above the take clamps at 0", Arrived = 2, Completed = 2, Sales = 0, Tips = 5, Catches = 0, Stolen = 9, Boss = 0, Grade = "A", Take = 0, Bonus = 0, Deposited = 0 },
}

local function runCase(case: Case): (boolean, string)
	const ledger = Ledger.new()
	ledger.Arrived = case.Arrived
	ledger.Completed = case.Completed
	ledger.Served = case.Completed
	ledger.Sales = case.Sales
	ledger.Tips = case.Tips
	ledger.Catches = case.Catches
	ledger.Stolen = case.Stolen
	const settlement = Ledger.settle(ledger, case.Boss)
	const ok = settlement.Grade == case.Grade
		and settlement.Take == case.Take
		and settlement.Bonus == case.Bonus
		and settlement.Deposited == case.Deposited
	const line = `{if ok then "ok  " else "FAIL"} {case.Name}: grade {settlement.Grade} take {settlement.Take} bonus {settlement.Bonus} deposited {settlement.Deposited}`
	if ok then
		return true, line
	end
	return false, `{line} (expected {case.Grade} / {case.Take} / {case.Bonus} / {case.Deposited})`
end

const Tips: Api.Module = function(ctx: Api.Context): { Api.Command }
	const economy = ctx.Get("EconomyService") :: Economy
	const jar = ctx.Get("TipJarService") :: TipJar

	const function state(): string
		const ledger = economy:GetLedger()
		return `Cash ${economy:GetCash()}, tip jar ${economy:GetDrawer()}, entries {if economy:IsDrawerOpen() then "open" else "closed"}; `
			.. `ledger sales ${ledger.Sales} tips ${ledger.Tips} catches ${ledger.Catches} stolen ${ledger.Stolen} collected ${ledger.Collected}`
	end

	return {
		{
			Name = "tips",
			Usage = "tips [state | add <n> | collect]",
			Help = "tip jar: state; add n (shop taking entries); collect (jar -> Cash)",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = if args[1] then string.lower(args[1]) else "state"
				if sub == "state" then
					return state()
				elseif sub == "add" then
					const amount = integerOf(args[2], "tips add <n>", 1, ADD_MAX)
					if not economy:IsDrawerOpen() then
						error("the shop is not taking entries (open it first: a selling phase or the day Closing)", 0)
					end
					const added = economy:AddTip(amount)
					return `+${added} in the jar. {state()}`
				elseif sub == "collect" then
					const moved = jar:CollectNow()
					return `collected ${moved}. {state()}`
				end
				error("usage: tips [state | add <n> | collect]", 0)
			end,
		},
		{
			Name = "economy",
			Usage = "economy ledger",
			Help = "economy ledger: pure test of the shift settlement (take, bonus, deposit); ends with N/N ok",
			Run = function(args: { string }, _caller: Player?): string?
				if args[1] == nil or string.lower(args[1]) ~= "ledger" then
					error("usage: economy ledger", 0)
				end
				const lines: { string } = {}
				local passed = 0
				for _, case in CASES do
					const ok, line = runCase(case)
					table.insert(lines, line)
					if ok then
						passed += 1
					end
				end
				table.insert(lines, `{passed}/{#CASES} ok`)
				return table.concat(lines, "\n")
			end,
		},
	}
end

return Tips
