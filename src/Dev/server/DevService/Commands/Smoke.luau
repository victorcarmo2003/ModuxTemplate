--!strict
-- Smoke test (2026-10-12, Provisional; trailer steps removed 2026-10-18 with the restaurant on, docs/tech/dev-commands.md):
-- the restaurant loop of one customer (Scenarios/RestaurantSmoke.luau, R-6): tablet -> plate -> cut -> grill -> plate ->
-- condiments -> pickup -> table, PASS / FAIL per step, through the same dev commands and service APIs a person would
-- use. Client-side errors are not visible here: read the Studio console (see tools/studio/smoke.md).
--   smoke           starts the run in the background; the report prints in the Output when it ends
--   smoke status    "running" / the last report
-- Dev mode only. It changes the run state (day, plates, tables): run it in a throwaway Play session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)
local RestaurantSmoke = require(script.Parent.Parent.Scenarios.RestaurantSmoke)

const USAGE = "smoke [status]"

const Smoke: Api.Module = function(ctx: Api.Context): { Api.Command }
	local running = false
	local lastReport = "no smoke run yet"

	-- Dev command through the DevService bridge (the same entry as "/dev <name> <args>"). Required lazily: DevService
	-- has finished loading by the time a command runs.
	local function dev(name: string, ...: any): string
		const DevService = (require :: any)(script.Parent.Parent)
		return tostring(DevService.Run(name, ...) or "")
	end

	return {
		{
			Name = "smoke",
			Usage = USAGE,
			Help = "restaurant smoke test: one customer end to end, PASS/FAIL per step (report in the Output)",
			Run = function(args: { string }, caller: Player?): string?
				if args[1] == "status" then
					return if running then "smoke running" else lastReport
				elseif args[1] ~= nil and args[1] ~= "restaurant" then
					error(`usage: {USAGE}`, 0)
				end
				if running then
					error("smoke is already running", 0)
				end
				running = true
				task.spawn(function()
					const success, report = pcall(RestaurantSmoke.run, ctx, dev, caller)
					lastReport = if success then report else `RESTAURANT SMOKE aborted: {report}`
					running = false
					print(lastReport)
				end)
				return "restaurant smoke started; the report prints in the Output (smoke status shows it)"
			end,
		},
	}
end

return Smoke
