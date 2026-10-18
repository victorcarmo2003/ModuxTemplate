--!strict
-- Horror scenes (TASK-462; tech/horror-scene.md). The scene plays on every client from the anomaly's own record, so
-- the command starts the real anomaly (AnomalyService DevForce, Night phase only) after marking its scene for the
-- clients: ReplicatedStorage attribute DevHorrorScene = key makes the client player run that scene even while its
-- Content row is not Live (the blackout until TASK-467). The anomaly's Effects/ module runs too, so in dev some
-- sounds and lights may come twice until TASK-467 merges them.
--   scene                    the scenes, Live or not, and the one marked for dev
--   scene <key|ANM-###|n>    marks its scene and starts that anomaly now
--   scene stop               stops the marked anomaly and clears the mark
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const USAGE = "scene [stop|<key|ANM-###|n>]"
const DEV_ATTRIBUTE = "DevHorrorScene" -- read by AnomalyController/Scene

type Anomalies = {
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevStopKey: (self: any, anomaly: string) -> number,
}

-- key, ANM-### or night number -> Content.Anomalies key
local function keyOf(word: string): string?
	if Content.Anomalies.ByKey[word] ~= nil then
		return word
	end
	const upper = string.upper(word)
	const number = tonumber(word)
	for index, row in Content.Anomalies.List do
		if row.Ref == upper or index == number then
			return row.Key
		end
	end
	return nil
end

local function status(): string
	const lines: { string } = {}
	for _, scene in Content.HorrorScenes.List do
		table.insert(lines, `  {scene.Key} ({scene.Name}){if scene.Live then " live" else " dev only"}, {#scene.Steps} steps`)
	end
	const marked = ReplicatedStorage:GetAttribute(DEV_ATTRIBUTE)
	return `scenes:\n{table.concat(lines, "\n")}\nmarked for dev: {if type(marked) == "string" then marked else "none"}`
end

const Scene: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies

	return {
		{
			Name = "scene",
			Usage = USAGE,
			Help = "plays an anomaly's horror scene: starts the anomaly with its scene on (Night phase), or stops it",
			Run = function(args: { string }, _caller: Player?): string?
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
				const key = keyOf(sub)
				if key == nil then
					error(`unknown anomaly "{sub}" (key, ANM-### or number); usage: {USAGE}`, 0)
				end
				if Content.HorrorScenes.ByKey[key] == nil then
					error(`{key} has no scene in Content.HorrorScenes`, 0)
				end
				-- the client also re-reads its records when the mark changes, so arrival order does not matter
				ReplicatedStorage:SetAttribute(DEV_ATTRIBUTE, key)
				return `{anomalies:DevForce(key, false)} with its scene`
			end,
		},
	}
end

return Scene
