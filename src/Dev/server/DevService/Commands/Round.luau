--!strict
-- Shift commands (board TASK-042 R1, TASK-054; tests/wave-1.md §0.4 R1, L-10; architecture.md §19.4; rewritten
-- 2026-10-18, docs/tech/dev-commands.md). Thin wrappers over the RoundService hooks: every one goes through the natural
-- path (Advance / StartShift / LoseNight), so Closing, Summary, deposit, ShiftStarted, NightResolved and the capture run
-- exactly as on a timeout. RoundService validates and errors. Calendar: Day 1 is the only day shift (Prep, Open,
-- Closing, Summary); Night k is played on Day k + 1 (Call, Prep, Night).
--   night [n] [prep]   straight into the Night phase of night n (default: this night shift, or the evening of the day);
--                      prep = stop at the start of the shift (Call / Prep) as before
--   day [n]            the shift of Day n from its first phase (default 1 = the day shift, skipped to Open)
--   skip               ends the current phase now, same path as its timer
--   time <h:mm>        moves the clock of the current phase (24 h; small hours roll past midnight: 3:30 = 27:30)
--   win | lose [wipe|critical]   resolves the current night now
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Parent.Kit)

const DAY_MINUTES = 1440

type Round = {
	DevSetDay: (self: any, day: number) -> (),
	DevSetNight: (self: any, night: number) -> (),
	DevSkipPhase: (self: any) -> (),
	DevSetPhaseElapsed: (self: any, seconds: number) -> (),
	Timing: (self: any, phase: string) -> { Duration: number, ClockFrom: number, ClockTo: number },
	Minutes: (self: any) -> number,
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

	local function clock(minutes: number): string
		const m = math.floor(minutes) % DAY_MINUTES
		return string.format("%d:%02d", m // 60, m % 60)
	end

	-- "3:30", "21", "9:05pm" -> game minutes inside [from, to] of the phase (rolled past midnight when needed)
	local function minutesOf(text: string, from: number, to: number): number
		const lower = string.lower(text)
		const h, m, suffix = string.match(lower, "^(%d+):?(%d*)%s*([ap]?m?)$")
		local hours = tonumber(h)
		if hours == nil then
			error("usage: time <h:mm> (e.g. time 3:30, time 21)", 0)
		end
		if suffix == "pm" and hours < 12 then
			hours += 12
		elseif suffix == "am" and hours == 12 then
			hours = 0
		end
		local value = hours * 60 + (tonumber(m) or 0)
		while value < from and value + DAY_MINUTES <= to do
			value += DAY_MINUTES
		end
		if value < from or value > to then
			error(`{text} is outside this phase's clock ({clock(from)} -> {clock(to)})`, 0)
		end
		return value
	end

	return {
		{
			Name = "day",
			Usage = "day [n]",
			Help = "the shift of Day n (default Day 1, the day shift, straight to Open; Day n >= 2 is Night n - 1)",
			Run = function(args: { string }, _caller: Player?): string?
				const day = if args[1] then tonumber(args[1]) else 1
				if day == nil then
					error("usage: day [n]", 0)
				end
				const before = where()
				round:DevSetDay(day)
				if not round:IsNight() and round:GetPhase() == "Prep" then
					round:DevSkipPhase()
				end
				return `{before} -> {where()}`
			end,
		},
		{
			Name = "night",
			Usage = "night [n] [prep]",
			Help = "straight into the Night phase of night n (default: this one); prep = stop at the shift start",
			Run = function(args: { string }, _caller: Player?): string?
				local night: number? = nil
				local prep = false
				for _, word in args do
					if string.lower(word) == "prep" then
						prep = true
					elseif tonumber(word) ~= nil then
						night = tonumber(word)
					else
						error("usage: night [n] [prep]", 0)
					end
				end
				const before = where()
				if prep then
					round:DevSetNight(night or (if round:IsNight() then round:GetNight() else 1))
				elseif Kit.toNight(round, night) == "" then
					return `already in {where()} ("night {round:GetNight()}" restarts it)`
				end
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
			Name = "time",
			Usage = "time <h:mm>",
			Help = "moves the clock of the current phase (24 h; 3:30 in the Night = 3:30 AM)",
			Run = function(args: { string }, _caller: Player?): string?
				if args[1] == nil then
					return `{where()} at {clock(round:Minutes())}`
				end
				const timing = round:Timing(round:GetPhase())
				const span = timing.ClockTo - timing.ClockFrom
				if span <= 0 or timing.Duration <= 0 then
					error(`the {round:GetPhase()} clock does not run`, 0)
				end
				const minutes = minutesOf(table.concat(args, ""), timing.ClockFrom, timing.ClockTo)
				const alpha = math.clamp((minutes - timing.ClockFrom) / span, 0, 0.995)
				round:DevSetPhaseElapsed(alpha * timing.Duration)
				return `{where()} at {clock(round:Minutes())}`
			end,
		},
		{
			Name = "lose",
			Usage = "lose [wipe|critical]",
			Help = "lose the current night (Call, Prep or Night): NightLost, then repeat or end of run",
			Run = function(args: { string }, _caller: Player?): string?
				const reason = args[1] or "wipe"
				if reason ~= "wipe" and reason ~= "critical" then
					error("usage: lose [wipe|critical]", 0)
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
