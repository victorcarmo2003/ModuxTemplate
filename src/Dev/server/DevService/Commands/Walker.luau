--!strict
-- Walker command (TASK-115; tests/wave-3.md R18). Writes the Step of the running ANM-007 occurrence through the same
-- path as a gaze step (Anomalies set, cues post_flicker/walker_step, Fail -> LoseNight("critical") at the last step).
-- Dev only: needs the Walker running (/dev anomaly ANM-007 during the Night phase).
--   walker <0..10>   sets the step
local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(script.Parent.Parent.Api)

const USAGE = "walker <0..10>"

type WalkerModule = { DevStep: (step: number) -> string }

const Walker: Api.Module = function(_ctx: Api.Context): { Api.Command }
	-- same ModuleScript the AnomalyService discovered (require is cached: one shared state)
	const module = (ServerScriptService :: any).server.Anomaly.AnomalyService.Anomalies:FindFirstChild("ANM-007")

	return {
		{
			Name = "walker",
			Usage = USAGE,
			Help = "sets the step of the running Walker (ANM-007) through the module path (10 = critical)",
			Run = function(args: { string }, _caller: Player?): string?
				if module == nil or not module:IsA("ModuleScript") then
					error("Anomalies/ANM-007 is not in this build", 0)
				end
				const step = tonumber(args[1])
				if step == nil or step ~= math.floor(step) then
					error(`usage: {USAGE}`, 0)
				end
				const walker = (require :: any)(module) :: WalkerModule
				return walker.DevStep(step)
			end,
		},
	}
end

return Walker
