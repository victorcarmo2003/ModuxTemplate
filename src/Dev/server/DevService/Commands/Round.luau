--!strict
-- Shift commands (board TASK-042, R1; tests/wave-1.md §0.4 R1, L-10). Thin wrappers over the RoundService dev
-- hooks (TASK-012 v1.1): both go through the natural path (EndPhase / StartShift), so Closing, Summary, deposit,
-- ShiftStarted and the capture run exactly as on a timeout or a day rollover. RoundService validates and errors.
local Api = require(script.Parent.Parent.Api)

type Round = {
	DevSetDay: (self: any, day: number) -> (),
	DevSkipPhase: (self: any) -> (),
	GetDay: (self: any) -> number,
	GetPhase: (self: any) -> string,
}

const Round: Api.Module = function(ctx: Api.Context): { Api.Command }
	const round = ctx.Get("RoundService") :: Round

	local function where(): string
		return `Day {round:GetDay()} {round:GetPhase()}`
	end

	return {
		{
			Name = "day",
			Usage = "day <n>",
			Help = "go to the Prep of Day n (ShiftStarted fires as on a natural rollover)",
			Run = function(args: { string }, _caller: Player?): string?
				const day = tonumber(args[1])
				if day == nil then
					error("usage: day <n>", 0)
				end
				const before = where()
				round:DevSetDay(day)
				return `{before} -> {where()}`
			end,
		},
		{
			Name = "skip",
			Usage = "skip",
			Help = "end the current phase now, same path as its timer (Open -> Closing -> Summary -> next Day)",
			Run = function(_args: { string }, _caller: Player?): string?
				const before = where()
				round:DevSkipPhase()
				return `{before} -> {where()}`
			end,
		},
	}
end

return Round
