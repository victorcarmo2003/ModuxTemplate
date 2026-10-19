--!strict
-- Plates of the world kitchen (TASK-569; docs/tech/kitchen-world.md §2, §4). Thin wrappers over PlateService (Dev* check IsDev).
--   plate [list]   every live plate: holder, Tool, ticket (Npc/Line, #n), bun, sausage, toppings, flip, altered
--   plate give     a plate for the caller, as from the plate pile (oldest free ticket)
--   plate clear    every plate gone (a hot dog in hand stays, without its ticket)
--   plate test     table tests of Grade.Assembly / PerfectTime / SaleEffect (pure)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Api = require(script.Parent.Parent.Api)

const USAGE = "plate [list | give | clear | test]"

type Plate = {
	DevList: (self: any) -> string,
	DevGive: (self: any, player: Player) -> string,
	DevClear: (self: any) -> string,
}

-- Grade table tests (kitchen-world.md §4): returns passed, total, failed names
local function selfTest(): (number, number, { string })
	const cfg = Content.Prep
	const perfect = Grade.PerfectTime(cfg, 1)
	const cases: { { Name: string, Order: { string }, Toppings: { string }, Seconds: number, Players: number, Flip: boolean, Want: string } } = {
		{ Name = "exact in time", Order = { "ketchup", "mustard" }, Toppings = { "mustard", "ketchup" }, Seconds = 10, Players = 1, Flip = false, Want = "Perfect" },
		{ Name = "exact late", Order = { "ketchup" }, Toppings = { "ketchup" }, Seconds = perfect + 1, Players = 1, Flip = false, Want = "Good" },
		{ Name = "exact late flipped", Order = { "ketchup" }, Toppings = { "ketchup" }, Seconds = perfect + 1, Players = 1, Flip = true, Want = "Perfect" },
		{ Name = "missing", Order = { "ketchup", "cheese" }, Toppings = { "ketchup" }, Seconds = 5, Players = 1, Flip = true, Want = "Messy" },
		{ Name = "extra", Order = { "ketchup" }, Toppings = { "ketchup", "bacon" }, Seconds = 5, Players = 1, Flip = false, Want = "Messy" },
		{ Name = "repeat", Order = { "ketchup", "mustard" }, Toppings = { "ketchup", "ketchup" }, Seconds = 5, Players = 1, Flip = false, Want = "Messy" },
		{ Name = "plain", Order = {}, Toppings = {}, Seconds = 5, Players = 1, Flip = false, Want = "Perfect" },
		{ Name = "untimed", Order = {}, Toppings = {}, Seconds = -1, Players = 1, Flip = false, Want = "Good" },
		{ Name = "4 players tighter", Order = {}, Toppings = {}, Seconds = perfect - 1, Players = 4, Flip = false, Want = if Grade.PerfectTime(cfg, 4) >= perfect - 1 then "Perfect" else "Good" },
	}
	const failed: { string } = {}
	local passed = 0
	for _, case in cases do
		const got = Grade.Assembly(cfg, case.Order, { Toppings = case.Toppings, Flipped = case.Flip }, case.Seconds, case.Players)
		if got == case.Want then
			passed += 1
		else
			table.insert(failed, `{case.Name} ({got} ~= {case.Want})`)
		end
	end
	local total = #cases
	-- PerfectTime floor and the tip effects
	const checks: { { Name: string, Ok: boolean } } = {
		{ Name = "PerfectTime floor", Ok = Grade.PerfectTime(cfg, 99) == cfg.Assembly.PerfectMin },
		{ Name = "Messy no tip", Ok = (Grade.SaleEffect(cfg, "Messy") :: Grade.SaleEffect).Tip == 0 },
		{ Name = "Perfect extra", Ok = (Grade.SaleEffect(cfg, "Perfect") :: Grade.SaleEffect).Extra == (cfg.Grades.Effects.Perfect.TipExtra or 0) },
		{ Name = "no band no effect", Ok = Grade.SaleEffect(cfg, nil) == nil },
	}
	for _, check in checks do
		total += 1
		if check.Ok then
			passed += 1
		else
			table.insert(failed, check.Name)
		end
	end
	return passed, total, failed
end

const Plate: Api.Module = function(ctx: Api.Context): { Api.Command }
	const plates = ctx.Get("PlateService") :: Plate

	return {
		{
			Name = "plate",
			Usage = USAGE,
			Help = "World kitchen plates: list, give one to you, clear, grade table tests",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == nil or verb == "list" then
					return plates:DevList()
				elseif verb == "give" then
					const player = caller or Players:GetPlayers()[1]
					if player == nil then
						error("no player in the server", 0)
					end
					return plates:DevGive(player)
				elseif verb == "clear" then
					return plates:DevClear()
				elseif verb == "test" then
					const passed, total, failures = selfTest()
					if #failures > 0 then
						return `{passed}/{total} ok; failed: {table.concat(failures, ", ")}`
					end
					return `{passed}/{total} ok`
				end
				error(`usage: {USAGE}`, 0)
			end,
		},
	}
end

return Plate
