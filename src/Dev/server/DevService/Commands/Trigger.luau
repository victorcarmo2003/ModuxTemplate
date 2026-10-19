--!strict
-- Anomaly trigger (TASK-106 `anomaly`, rewritten 2026-10-18 on owner request; docs/tech/dev-commands.md). Goes through
-- the AnomalyService API, so the Anomalies set, the AnomalyCue packet, events and Stop behave as in play. Forcing skips
-- the agenda and Scheduler.Admit (dev only). Outside the Night phase it first jumps there (Kit.toNight).
--   trigger                       what is running (modules, rules, tension, occurrences)
--   trigger <anomaly> [example]   starts it now: key, ANM-###, number or name ("blackout", "knock", "red fog");
--                                 example = with Anomalies/_Example (tests the core without the real module)
--   trigger stop [anomaly]        stops every occurrence ("Restore"), or only that anomaly's
--   trigger list                  tonight's agenda + the catalog (restaurant cuts marked)
-- `t` is the short form; `anomaly` stays as an old name (docs and test plans use it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const USAGE = "trigger [list | stop [anomaly] | <anomaly> [example]]"
const EXAMPLE = "example"

type Anomalies = {
	DevForce: (self: any, anomaly: string, example: boolean) -> string,
	DevStop: (self: any) -> string,
	DevStopKey: (self: any, anomaly: string) -> number,
	DevStatus: (self: any) -> string,
	DevAgenda: (self: any) -> string,
}

local function catalog(): string
	const lines: { string } = {}
	for _, row in Content.Anomalies.List do
		const family = row.Family
		const tags = if family == nil then " [off agenda]" else ""
		table.insert(lines, `  {row.Ref} {row.Name} ({row.Key}){if family then `, family {family}` else ""}{tags}`)
	end
	return `catalog:\n{table.concat(lines, "\n")}`
end

const Trigger: Api.Module = function(ctx: Api.Context): { Api.Command }
	const anomalies = ctx.Get("AnomalyService") :: Anomalies
	const round = ctx.Get("RoundService")

	local function run(args: { string }, _caller: Player?): string?
		const first = if args[1] then string.lower(args[1]) else nil
		if first == nil then
			return anomalies:DevStatus()
		elseif first == "list" or first == "agenda" then
			return `{anomalies:DevAgenda()}\n{catalog()}`
		elseif first == "stop" then
			if args[2] == nil then
				return anomalies:DevStop()
			end
			const key = Kit.anomaly(table.concat(args, " ", 2))
			return `{key}: {anomalies:DevStopKey(key)} occurrence(s) stopped`
		end
		const words = table.clone(args)
		const example = #words > 1 and string.lower(words[#words]) == EXAMPLE
		if example then
			table.remove(words)
		end
		const key = Kit.anomaly(table.concat(words, " "))
		const moved = Kit.toNight(round, nil)
		const started = anomalies:DevForce(key, example)
		return if moved ~= "" then `{moved}: {started}` else started
	end

	return {
		{
			Name = "trigger",
			Usage = USAGE,
			Help = "(alias t) starts an anomaly now, jumping to the Night phase; stop; list = agenda + catalog",
			Run = run,
		},
		{ Name = "t", Usage = USAGE, Help = "short for trigger", Hidden = true, Run = run },
		{ Name = "anomaly", Usage = USAGE, Help = "(old name) trigger", Hidden = true, Run = run },
	}
end

return Trigger
