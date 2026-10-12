--!strict
-- Shift commands (board TASK-042 R1, TASK-054; tests/wave-1.md §0.4 R1, L-10; architecture.md §19.4). Thin wrappers
-- over the RoundService hooks: every one goes through the natural path (Advance / StartShift / LoseNight), so
-- Closing, Summary, deposit, ShiftStarted, NightResolved and the capture run exactly as on a timeout.
-- RoundService validates and errors.
local Api = require(script.Parent.Parent.Api)

type Round = {
	DevSetDay: (self: any, day: number) -> (),
	DevSetNight: (self: any, night: number) -> (),
	DevSkipPhase: (self: any) -> (),
	DevWinNight: (self: any) -> (),
	LoseNight: (self: any, reason: "wipe" | "critical") -> boolean,
	GetDay: (self: any) -> number,
	GetNight: (self: any) -> number,
	IsNight: (self: any) -> boolean,
	GetPhase: (self: any) -> string,
	Info: (self: any) -> { Attempt: number },
}

const Round: Api.Module = function(ctx: Api.Context): { Api.Command }
	const round = ctx.Get("RoundService") :: Round

	local function where(): string
		const shift = if round:IsNight() then `Night {round:GetNight()}` else `Day {round:GetDay()}`
		const attempt = round:Info().Attempt
		const suffix = if attempt > 0 then ` (attempt {attempt + 1})` else ""
		return `{shift} {round:GetPhase()}{suffix}`
	end

	return {
		{
			Name = "day",
			Usage = "day <n>",
			Help = "go to the Prep of Day n; nights played = those before it in the flow D1, D2, N1, D3, N2 ... (Day 3 follows Night 1); ShiftStarted fires as on a natural rollover and places the free packages of every unlocked day not given yet",
			Run = function(args: { string }, _caller: Player?): string?
				const day = tonumber(args[1])
				if day == nil then
					error("usage: day <n>", 0)
				end
				const before = where()
				round:DevSetDay(day)
				const packs = workspace:FindFirstChild("FreePacks")
				const waiting = if packs then #packs:GetChildren() else 0
				return `{before} -> {where()} (free packages waiting: {waiting})`
			end,
		},
		{
			Name = "night",
			Usage = "night <k>",
			Help = "start Night k on its own day (Night k is on Day k + 1: the evening of the day shift before it), any vehicle: Call, skipped without a boss, then Prep. Gives the unlocked free packages. Night 1: sanity 50, coffee stock 10, Walt's coffee call",
			Run = function(args: { string }, _caller: Player?): string?
				const night = tonumber(args[1])
				if night == nil then
					error("usage: night <k>", 0)
				end
				const before = where()
				round:DevSetNight(night)
				return `{before} -> {where()}`
			end,
		},
		{
			Name = "skip",
			Usage = "skip",
			Help = "end the current phase now, same path as its timer (the Night goes through the verdict)",
			Run = function(_args: { string }, _caller: Player?): string?
				const before = where()
				round:DevSkipPhase()
				return `{before} -> {where()}`
			end,
		},
		{
			Name = "lose",
			Usage = "lose wipe|critical",
			Help = "lose the current night (Call, Prep or Night): NightLost, then repeat or end of run",
			Run = function(args: { string }, _caller: Player?): string?
				const reason = args[1]
				if reason ~= "wipe" and reason ~= "critical" then
					error("usage: lose wipe|critical", 0)
				end
				const before = where()
				if not round:LoseNight(reason :: any) then
					error(`{before}: a night can only be lost in Call, Prep or Night of a night shift`, 0)
				end
				return `{before} -> {where()}`
			end,
		},
		{
			Name = "win",
			Usage = "win",
			Help = "win the current night now (NightEnd; Night 10 goes to the finale)",
			Run = function(_args: { string }, _caller: Player?): string?
				const before = where()
				round:DevWinNight()
				return `{before} -> {where()}`
			end,
		},
	}
end

return Round
