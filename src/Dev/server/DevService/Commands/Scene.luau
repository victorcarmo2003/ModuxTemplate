--!strict
-- Horror scenes (TASK-462; tech/horror-scene.md). The scene plays on every client from the anomaly's own record, so
-- the command starts the real anomaly (AnomalyService DevForce, Night phase only) after marking its scene for the
-- clients: ReplicatedStorage attribute DevHorrorScene = key makes the client player run that scene even while its
-- Content row is not Live (the blackout until TASK-467). The anomaly's Effects/ module runs too, so in dev some
-- sounds and lights may come twice until TASK-467 merges them.
-- Outside the Night phase it first jumps there (Kit.toNight). Anomaly = key, ANM-###, number or name (Kit.anomaly).
--   scene                    the scenes, Live or not, and the one marked for dev
--   scene <anomaly>          marks its scene and starts that anomaly now
--   scene stop               stops the marked anomaly and clears the mark
--   scene score <stage|auto> forces the horror score stage on your client (Parts/Score.luau, was `score`)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "scene [stop | score <stage|auto> | <anomaly>]"
const DEV_ATTRIBUTE = "DevHorrorScene" -- read by AnomalyController/Scene

type Anomalies = {
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevStopKey: (self: any, anomaly: string) -> number,
}

local function status(): string
	const lines: { string } = {}
	for _, scene in Content.HorrorScenes.List do
		table.insert(
			lines,
			`  {scene.Key} ({scene.Name}){if scene.Live then " live" else " dev only"}, {#scene.Steps} steps`
		)
	end
	const marked = ReplicatedStorage:GetAttribute(DEV_ATTRIBUTE)
	return `scenes:\n{table.concat(lines, "\n")}\nmarked for dev: {if type(marked) == "string" then marked else "none"}`
end

const Scene: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies
	const round = ctx.Get("RoundService")
	const score = Kit.parts(ctx, "Score").score

	return {
		{
			Name = "scene",
			Usage = USAGE,
			Help = "plays an anomaly's horror scene (jumps to the Night phase), stops it; score = force the score stage",
			Run = function(args: { string }, caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return status()
				elseif sub == "stop" then
					const marked = ReplicatedStorage:GetAttribute(DEV_ATTRIBUTE)
					ReplicatedStorage:SetAttribute(DEV_ATTRIBUTE, nil)
					if type(marked) ~= "string" then
						return "no scene marked"
					end
					return `{marked}: {anomalies:DevStopKey(marked)} occurrence(s) stopped, mark cleared`
				end
				if string.lower(sub) == "score" then
					return Kit.forward(score)({ table.unpack(args, 2) }, caller)
				end
				const key = Kit.anomaly(table.concat(args, " "))
				if Content.HorrorScenes.ByKey[key] == nil then
					error(`{key} has no scene in Content.HorrorScenes`, 0)
				end
				-- the client also re-reads its records when the mark changes, so arrival order does not matter
				const moved = Kit.toNight(round, nil)
				ReplicatedStorage:SetAttribute(DEV_ATTRIBUTE, key)
				const started = `{anomalies:DevForce(key, false)} with its scene`
				return if moved ~= "" then `{moved}: {started}` else started
			end,
		},
	}
end

return Scene
