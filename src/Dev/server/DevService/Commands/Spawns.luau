--!strict
-- Customer spawn counter per shift (board TASK-045, R5; tests/wave-1.md §0.4 R5, T032-01/02). Listens to
-- CustomerService.SpawnAttempted (TASK-032 v1.1), resets on RoundService.ShiftStarted and prints one line when the
-- Open phase ends (PhaseChanged -> "Closing", same path for the timer, the empty counter and DevSkipPhase):
--   [Dev] Day N: attempts X, spawned Y, skipped (queue) Z, skipped (cap) W      (X = Y + Z + W)
-- "spawns" shows the current shift. DevSpawn attempts are counted too (they fire the same signal).
local Api = require(script.Parent.Parent.Api)

type Connection = { Disconnect: (self: Connection) -> () }

type Outcome = "spawned" | "skipped_queue_full" | "skipped_npc_cap"

type Customer = {
	SpawnAttempted: { Connect: (self: any, callback: (outcome: Outcome) -> ()) -> Connection },
}

type Round = {
	ShiftStarted: { Connect: (self: any, callback: (info: { Day: number }) -> ()) -> Connection },
	PhaseChanged: { Connect: (self: any, callback: (phase: string, day: number, night: number) -> ()) -> Connection },
	GetDay: (self: any) -> number,
	GetPhase: (self: any) -> string,
}

type Counts = { Attempts: number, Spawned: number, Queue: number, Cap: number }

local function zero(): Counts
	return { Attempts = 0, Spawned = 0, Queue = 0, Cap = 0 }
end

const Spawns: Api.Module = function(ctx: Api.Context): { Api.Command }
	const customer = ctx.Get("CustomerService") :: Customer
	const round = ctx.Get("RoundService") :: Round

	local day = round:GetDay()
	local counts = zero()

	local function report(): string
		return `Day {day}: attempts {counts.Attempts}, spawned {counts.Spawned}, skipped (queue) {counts.Queue}, `
			.. `skipped (cap) {counts.Cap}`
	end

	customer.SpawnAttempted:Connect(function(outcome: Outcome)
		counts.Attempts += 1
		if outcome == "spawned" then
			counts.Spawned += 1
		elseif outcome == "skipped_queue_full" then
			counts.Queue += 1
		else
			counts.Cap += 1
		end
	end)

	round.ShiftStarted:Connect(function(info: { Day: number })
		day = info.Day
		counts = zero()
	end)

	-- Open always ends into Closing (RoundService NEXT table)
	round.PhaseChanged:Connect(function(phase: string, _day: number, _night: number)
		if phase == "Closing" then
			ctx.Log(report())
		end
	end)

	return {
		{
			Name = "spawns",
			Usage = "spawns",
			Help = "customer spawn attempts this shift (spawned / skipped by full queue / skipped by NPC cap)",
			Run = function(_args: { string }, _caller: Player?): string?
				return `{report()} ({round:GetPhase()})`
			end,
		},
	}
end

return Spawns
