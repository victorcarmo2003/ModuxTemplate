--!strict
-- Focused prep mode dev commands (docs/tech/prep-mode.md; TASK P0).
--   prep grade   runs the table of Prep.Grade cases (pure math, no service needed) and prints ok / FAIL per case plus
--                the totals; any failure makes the command error so the Command Bar shows it as a warning
--   prep seats | enter <n> [Grill|Build] | leave | finish [force] [topping...]   PrepService without the UI (TASK-170): seat table,
--                sit / leave as the caller (first player from the Command Bar), perfect summary through the real path
--                ("force" ages the plate past the Perfect floor; without it the server clock answers TooFast)
--   prep ui [n]  opens / closes the focused UI on the caller's client with mock data (PrepController, TASK-173; no seat)
--   prep ray     toggles the PrepRay attribute of the caller: while on, every press in the focused mode prints what the pointer ray
--                hits (target, part, distance, world point, bun uv) in the CLIENT output (World/Aim, TASK-196); works with
--                Rules.ThreeD off too, enter the mode after turning it on
--   prep kitchen runs the KitchenService scenarios of the prep mode (TASK-169): BeginPlate / FinishPlate / RefundPlate /
--                TrashPlate (refusals change nothing), GrillAct Place / Flip / Collect, TakeStock race and the
--                WorldKitchenPrompts flag; prints ok / FAIL per check, restores stock and rail, errors on any failure
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local PrepKitchen = require(script.Parent.Parent.Scenarios.PrepKitchen)
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)

const cfg = Content.Prep

type Case = { Name: string, Got: () -> any, Want: any }

local function tolerance(key: string): Content.PrepTolerance
	return cfg.Tolerances.ByKey[key]
end

-- stages with every score at `score`, `toppings` toppings and a sausage score
local function stages(score: number, toppings: number, sausage: number?): Grade.Stages
	const list: { number } = {}
	for _ = 1, toppings do
		table.insert(list, score)
	end
	return { Cut = score, Place = score, Toppings = list, Sausage = sausage }
end

local function band(result: Grade.PlateResult): string
	return if result.Capped then `{result.Band}+capped` else result.Band
end

local function plausible(toppings: number, elapsed: number, ms: number): string
	const ok, reason = Grade.Plausible(cfg, toppings, elapsed, ms)
	return if ok then "ok" else tostring(reason)
end

-- Same shape as Content.Prep with other numbers: proves the math reads its parameters instead of constants.
const custom = {
	Rules = cfg.Rules,
	Grades = {
		Points = cfg.Grades.Points,
		Bands = { Perfect = 90, Good = 40 },
		Plate = cfg.Grades.Plate,
		Unflipped = 0,
		Effects = cfg.Grades.Effects,
		Labels = cfg.Grades.Labels,
	},
}

const cases: { Case } = {
	-- Score: bun_cut Perfect 6, Good 15, Worst 40; Bands 85 / 55
	{ Name = "score bun_cut 0", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 0) end, Want = 100 },
	{ Name = "score bun_cut = Perfect limit", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 6) end, Want = 85 },
	{ Name = "score bun_cut just over Perfect", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 6.01) end, Want = 84 },
	{ Name = "score bun_cut = Good limit", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 15) end, Want = 55 },
	{ Name = "score bun_cut just over Good", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 15.01) end, Want = 54 },
	{ Name = "score bun_cut = Worst", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 40) end, Want = 0 },
	{ Name = "score bun_cut far past Worst", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 500) end, Want = 0 },
	{ Name = "score negative error", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), -3) end, Want = 100 },
	{ Name = "score NaN", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 0 / 0) end, Want = 0 },
	{ Name = "score halfway Perfect..Good (10.5)", Got = function() return Grade.Score(cfg, tolerance("bun_cut"), 10.5) end, Want = 70 },
	{ Name = "score without assist 7.5 is Good", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("bun_cut"), 7.5)) end, Want = "Good" },
	{ Name = "score with assist 7.5 is Perfect", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("bun_cut"), 7.5, true)) end, Want = "Perfect" },
	{ Name = "score custom bands at the Perfect limit", Got = function() return Grade.Score(custom, tolerance("bun_cut"), 6) end, Want = 90 },
	{ Name = "score custom bands at the Good limit", Got = function() return Grade.Score(custom, tolerance("bun_cut"), 15) end, Want = 40 },

	-- sauces: error = max(100 - coverage, excess x 1.5)
	{ Name = "sauce coverage 85 excess 10 = 15", Got = function() return Grade.CoverageError(tolerance("ketchup"), 85, 10) end, Want = 15 },
	{ Name = "sauce coverage 85 excess 10 is Perfect", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("ketchup"), Grade.CoverageError(tolerance("ketchup"), 85, 10))) end, Want = "Perfect" },
	{ Name = "sauce coverage 60 excess 25 is Good", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("mustard"), Grade.CoverageError(tolerance("mustard"), 60, 25))) end, Want = "Good" },
	{ Name = "sauce coverage 59 is Messy", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("mustard"), Grade.CoverageError(tolerance("mustard"), 59, 0))) end, Want = "Messy" },
	{ Name = "sauce coverage 100 excess 40 is Messy", Got = function() return Grade.Band(cfg, Grade.Score(cfg, tolerance("cream_cheese"), Grade.CoverageError(tolerance("cream_cheese"), 100, 40))) end, Want = "Messy" },
	{ Name = "sauce coverage clamps above 100", Got = function() return Grade.CoverageError(tolerance("ketchup"), 120, 0) end, Want = 0 },

	-- Band edges
	{ Name = "band 100", Got = function() return Grade.Band(cfg, 100) end, Want = "Perfect" },
	{ Name = "band 85", Got = function() return Grade.Band(cfg, 85) end, Want = "Perfect" },
	{ Name = "band 84", Got = function() return Grade.Band(cfg, 84) end, Want = "Good" },
	{ Name = "band 55", Got = function() return Grade.Band(cfg, 55) end, Want = "Good" },
	{ Name = "band 54", Got = function() return Grade.Band(cfg, 54) end, Want = "Messy" },
	{ Name = "band 0", Got = function() return Grade.Band(cfg, 0) end, Want = "Messy" },
	{ Name = "points Perfect", Got = function() return Grade.Points(cfg, "Perfect") end, Want = 100 },
	{ Name = "points Good", Got = function() return Grade.Points(cfg, "Good") end, Want = 70 },
	{ Name = "points Messy", Got = function() return Grade.Points(cfg, "Messy") end, Want = 30 },

	-- Plate (Perfect: mean >= 88 and no Messy; Good: mean >= 60; time cap under 3.0 + 0.8 K s)
	{ Name = "plate all 100, K 2, slow enough", Got = function() return band(Grade.Plate(cfg, stages(100, 2, 100), 10)) end, Want = "Perfect" },
	{ Name = "plate one Good among Perfects (92.5)", Got = function() return band(Grade.Plate(cfg, { Cut = 100, Place = 100, Toppings = { 70 }, Sausage = 100 }, 10)) end, Want = "Perfect" },
	{ Name = "plate mean exactly 88 is Perfect", Got = function() return band(Grade.Plate(cfg, { Cut = 100, Place = 100, Toppings = { 60, 60 }, Sausage = 100 }, 10)) end, Want = "Perfect" },
	{ Name = "plate mean 85 is Good", Got = function() return band(Grade.Plate(cfg, { Cut = 100, Place = 100, Toppings = { 60, 60 }, Sausage = nil }, 10)) end, Want = "Good" },
	{ Name = "plate a Messy stage blocks Perfect (82.5)", Got = function() return band(Grade.Plate(cfg, { Cut = 100, Place = 100, Toppings = { 100, 10 }, Sausage = nil }, 10)) end, Want = "Good" },
	{ Name = "plate mean exactly 60 is Good", Got = function() return band(Grade.Plate(cfg, { Cut = 60, Place = 60, Toppings = { 60, 10 }, Sausage = nil }, 10)) end, Want = "Good" },
	{ Name = "plate mean 56.7 is Messy", Got = function() return band(Grade.Plate(cfg, { Cut = 60, Place = 60, Toppings = { 10 }, Sausage = nil }, 10)) end, Want = "Messy" },
	{ Name = "plate all 0 is Messy", Got = function() return band(Grade.Plate(cfg, stages(0, 3, 0), 10)) end, Want = "Messy" },
	{ Name = "plate no toppings, two stages", Got = function() return band(Grade.Plate(cfg, stages(100, 0, nil), 10)) end, Want = "Perfect" },
	{ Name = "plate counts the sausage stage", Got = function() return Grade.Plate(cfg, stages(100, 1, 0), 10).Stages end, Want = 4 },
	{ Name = "plate time cap K 2 at 4.0 s", Got = function() return band(Grade.Plate(cfg, stages(100, 2, 100), 4.0)) end, Want = "Good+capped" },
	{ Name = "plate time cap K 2 at the Perfect floor", Got = function() return band(Grade.Plate(cfg, stages(100, 2, 100), Grade.PerfectTime(cfg, 2))) end, Want = "Perfect" },
	{ Name = "plate time cap K 0 at 2.99 s", Got = function() return band(Grade.Plate(cfg, stages(100, 0, nil), 2.99)) end, Want = "Good+capped" },
	{ Name = "plate time cap K 0 at 3.0 s", Got = function() return band(Grade.Plate(cfg, stages(100, 0, nil), 3.0)) end, Want = "Perfect" },
	{ Name = "plate time never lowers a Good", Got = function() return band(Grade.Plate(cfg, stages(70, 2, 70), 0)) end, Want = "Good" },
	{ Name = "plate average is the mean of the points", Got = function() return Grade.Plate(cfg, { Cut = 100, Place = 70, Toppings = { 0 }, Sausage = nil }, 10).Average end, Want = (100 + 70 + 30) / 3 },

	-- Plausibility (K 2: floor 3.4 s; K 3: 4.2 s; Ms may exceed the server clock by 1.5 s; PlateMax 90 s)
	{ Name = "plausible just under the floor", Got = function() return plausible(2, 3.3, 3300) end, Want = "TooFast" },
	{ Name = "plausible at the floor (K 2)", Got = function() return plausible(2, Grade.MinTime(cfg, 2), 3400) end, Want = "ok" },
	{ Name = "plausible K 3 floor", Got = function() return plausible(3, 4.1, 4100) end, Want = "TooFast" },
	{ Name = "plausible Ms inside the slack", Got = function() return plausible(2, 10, 11400) end, Want = "ok" },
	{ Name = "plausible Ms beyond the slack", Got = function() return plausible(2, 10, 11600) end, Want = "Invalid" },
	{ Name = "plausible Ms shorter than the server is fine", Got = function() return plausible(2, 10, 5000) end, Want = "ok" },
	{ Name = "plausible past PlateMax", Got = function() return plausible(2, 91, 91000) end, Want = "NoSession" },
	{ Name = "min time K 2", Got = function() return Grade.MinTime(cfg, 2) end, Want = 1.8 + 0.8 * 2 },
	{ Name = "perfect time K 2", Got = function() return Grade.PerfectTime(cfg, 2) end, Want = 3.0 + 0.8 * 2 },

	-- Sausage flip (server clock; Duration 10 s, target 5 s)
	-- TASK-257: the flip is graded by where the swinging cursor is (Grade.SwingAt; Duration 10, first side 8 s, Swing 1.1 s)
	{ Name = "flip at the middle", Got = function() return Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 108.55, 10) >= 99 end, Want = true },
	{ Name = "flip near the middle is Perfect", Got = function() return Grade.Band(cfg, Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 108.59, 10)) end, Want = "Perfect" },
	{ Name = "flip inside the window is Good", Got = function() return Grade.Band(cfg, Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 108.45, 10)) end, Want = "Good" },
	{ Name = "flip too early is Messy", Got = function() return Grade.Band(cfg, Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 107, 10)) end, Want = "Messy" },
	{ Name = "flip at an end is Messy", Got = function() return Grade.Band(cfg, Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 108, 10)) end, Want = "Messy" },
	{ Name = "the swing back through the middle", Got = function() return Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 109.65, 10) >= 99 end, Want = true },
	{ Name = "never flipped is Messy", Got = function() return Grade.Band(cfg, Grade.FlipScore(cfg, tolerance("grill_flip"), 100, nil, 10)) end, Want = "Messy" },
	{ Name = "flip with no duration", Got = function() return Grade.FlipScore(cfg, tolerance("grill_flip"), 100, 105, 0) end, Want = 0 },

	-- Effects (Q-219 B)
	{ Name = "effect Perfect tip", Got = function() return Grade.Effect(cfg, "Perfect").Tip end, Want = 2 },
	{ Name = "effect Perfect window", Got = function() return Grade.Effect(cfg, "Perfect").TipWindow end, Want = 4 },
	{ Name = "effect Good keeps the base tip", Got = function() return Grade.Effect(cfg, "Good").Tip end, Want = nil },
	{ Name = "effect Messy no tip", Got = function() return Grade.Effect(cfg, "Messy").Tip end, Want = 0 },
	{ Name = "effect Messy mood", Got = function() return Grade.Effect(cfg, "Messy").Mood end, Want = -1 },
}

-- Every Tolerances row (a new topping included) must hit the anchors of the score line exactly.
local function sweepRows(): { Case }
	const out: { Case } = {}
	for _, row in cfg.Tolerances.List do
		table.insert(out, { Name = `anchors {row.Key}`, Got = function(): any
			return table.concat({
				Grade.Score(cfg, row, 0),
				Grade.Score(cfg, row, row.Perfect),
				Grade.Score(cfg, row, row.Good),
				Grade.Score(cfg, row, row.Worst),
			}, "/")
		end, Want = `100/{cfg.Grades.Bands.Perfect}/{cfg.Grades.Bands.Good}/0` })
		table.insert(out, { Name = `assist anchors {row.Key}`, Got = function(): any
			return table.concat({
				Grade.Score(cfg, row, row.Perfect * cfg.Rules.Assist, true),
				Grade.Score(cfg, row, row.Good * cfg.Rules.Assist, true),
			}, "/")
		end, Want = `{cfg.Grades.Bands.Perfect}/{cfg.Grades.Bands.Good}` })
		table.insert(out, { Name = `monotonic {row.Key}`, Got = function(): any
			local previous = 101
			for step = 0, 100 do
				const score = Grade.Score(cfg, row, row.Worst * 1.2 * step / 100)
				if score > previous then
					return `rose at step {step}`
				end
				previous = score
			end
			return "ok"
		end, Want = "ok" })
	end
	return out
end

const Prep: Api.Module = function(ctx: Api.Context): { Api.Command }
	return {
		{
			Name = "prep",
			Usage = "prep grade | ray | kitchen | plate | seats | ui [n] [tab] | enter <n> [Grill|Build] | leave | finish [force] [topping...]",
			Help = "prep grade: Prep.Grade cases; ray: print the target under every click of the focused mode (client Output); kitchen: KitchenService plate/grill/flag scenarios (TASK-169); seats / enter / leave / finish: PrepService without the UI (TASK-170)",
			Run = function(args: { string }, caller: Player?): string?
				const verb = args[1]
				if verb == "kitchen" then
					return PrepKitchen(ctx, caller)
				end
				if verb == "seats" or verb == "enter" or verb == "leave" or verb == "finish" or verb == "plate" then
					const service = ctx.Get("PrepService") :: any
					if verb == "seats" then
						return service:DevSeats()
					end
					const player = caller or game:GetService("Players"):GetPlayers()[1]
					if player == nil then
						error("no player to act as", 0)
					end
					if verb == "enter" then
						return service:DevEnter(player, tonumber(args[2]) or 1, args[3])
					elseif verb == "leave" then
						return service:DevLeave(player)
					elseif verb == "plate" then
						-- the PrepTab.Plate mask rules (TASK-195); seated, no open plate
						return service:DevPlate(player)
					end
					const keys: { string } = {}
					local force = false
					for index = 2, #args do
						if args[index] == "force" then
							force = true
						else
							table.insert(keys, args[index])
						end
					end
					return service:DevFinish(player, keys, force)
				end
				if verb == "ui" then
					-- the client preview of the focused UI (PrepController, TASK-173): mock data, no seat, no packet back
					const player = caller or game:GetService("Players"):GetPlayers()[1]
					if player == nil then
						error("no player to act as", 0)
					end
					const tutorials = ctx.Get("TutorialService") :: any
					-- text = "<station> <tab>": `prep ui 1 Grill` opens on the grill with the mock line and grill (Feed.luau),
					-- `prep ui 1 Serve` on the Serve tab with a finished plate; the tabs are Order, Grill, Build, Serve
					tutorials:DevSend(player, "prep_ui", `{args[2] or "1"} {args[3] or ""}`)
					return `prep ui sent to {player.Name} (run it again to leave)`
				end
				if verb ~= "grade" then
					error("usage: prep grade | kitchen | plate | seats | enter <n> [Grill|Build] | leave | finish [force] [topping...]", 0)
				end
				const all: { Case } = table.clone(cases)
				for _, case in sweepRows() do
					table.insert(all, case)
				end
				local failed = 0
				for _, case in all do
					const ok, got = pcall(case.Got)
					if ok and got == case.Want then
						ctx.Log(`prep grade ok   {case.Name}`)
					else
						failed += 1
						ctx.Log(`prep grade FAIL {case.Name}: got {tostring(got)}, want {tostring(case.Want)}`)
					end
				end
				const summary = `prep grade: {#all - failed}/{#all} ok, {failed} failed`
				if failed > 0 then
					error(summary, 0)
				end
				return summary
			end,
		},
	}
end

return Prep
