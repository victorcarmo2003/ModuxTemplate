--!strict
-- Boss call commands (board TASK-070; FEAT-018). Thin wrappers over BossService (Dev* methods check IsDev).
--   call                 phone state, current call and line, queue
--   call <key>           rings <key> now, ahead of the queue, even if already heard (not in Finale/NightLost/
--                        RunEnd/Resume)
--   call answer          answers the ringing phone (same as Prompt_Answer)
--   call stop            hangs up and empties the queue
--   call list [filter]   keys of Content.BossCalls that ring (containing filter)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

type Boss = {
	DevStatus: (self: any) -> string,
	DevCall: (self: any, key: string) -> (),
	DevAnswer: (self: any) -> (),
	DevStop: (self: any) -> (),
}

const USAGE = "call [<key> | answer | stop | list [filter]]"

local function ringable(): { string }
	const out: { string } = {}
	for _, row in Content.BossCalls.List do
		const kind = row.Trigger.Kind
		if kind ~= "None" and kind ~= "RunOver" then
			table.insert(out, row.Key)
		end
	end
	return out
end

const Boss: Api.Module = function(ctx: Api.Context): { Api.Command }
	const boss = ctx.Get("BossService") :: Boss

	return {
		{
			Name = "call",
			Usage = USAGE,
			Help = "boss phone: state; ring a call by key; answer; hang up; list keys",
			Run = function(args: { string }, _caller: Player?): string?
				const sub = args[1]
				if sub == nil then
					return boss:DevStatus()
				end
				const lower = string.lower(sub)
				if lower == "answer" then
					boss:DevAnswer()
					return boss:DevStatus()
				elseif lower == "stop" then
					boss:DevStop()
					return "Hung up, queue empty"
				elseif lower == "list" then
					const filter = if args[2] then string.lower(args[2]) else nil
					const keys: { string } = {}
					for _, key in ringable() do
						if filter == nil or string.find(key, filter, 1, true) then
							table.insert(keys, key)
						end
					end
					return `{#keys} calls: {table.concat(keys, ", ")}`
				end
				if Content.BossCalls.ByKey[lower] == nil then
					error(`unknown call '{sub}' (call list); usage: {USAGE}`, 0)
				end
				boss:DevCall(lower)
				return boss:DevStatus()
			end,
		},
	}
end

return Boss
