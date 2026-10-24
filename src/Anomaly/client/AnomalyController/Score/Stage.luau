--!strict
-- Pure stage pick of the horror score (TASK-443; Content.Score). No Roblox instance, no time source of its own: the
-- director hands in what it saw of each anomaly record and the clock.
--   Of(score, phase)       stage one record asks for (nil = that phase does not score)
--   Pick(seen) the stage of the moment: highest Priority wins; between two records asking for the same stage
--                          the one seen first in that phase drives the ramp (it is the furthest along)
--   Next(current, ...)     the director's step: up at once, down only after the current stage's Hold, and a fall from
--                          Uneasy / Tension / Climax to Calm passes through Release first
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type StageKey = Content.ScoreStageKey

-- One live record as the director saw it
export type Seen = {
	Ref: string,
	Phase: string,
	Since: number, -- server time this record was first seen in this phase (StartedAt for its first phase)
}

export type Pick = {
	Stage: StageKey,
	Since: number, -- server time the driving record entered the phase (0 = none)
	Ramp: number, -- s of the Tension ramp of the driving record (0 = none)
	Ref: string?, -- Ref of the driving record
}

const STAGES = Content.Score.ByKey
const ANOMALIES = Content.Score.Anomalies :: { [string]: Content.ScoreAnomaly }
const HOT: { [string]: boolean } = { Uneasy = true, Tension = true, Rise = true, Climax = true }

const Stage = {}

function Stage.Priority(key: StageKey): number
	const row = STAGES[key]
	return if row ~= nil then row.Priority else 0
end

function Stage.IsHot(key: StageKey): boolean
	return HOT[key] == true
end

function Stage.Of(score: Content.ScoreAnomaly, phase: string): StageKey?
	if phase == "Signal" then
		return score.Signal
	elseif phase == "Active" then
		return score.Active
	elseif phase == "Queue" then
		return score.Queue -- owner 2026-10-22: a customer anomaly waiting for its order
	elseif phase == "Failed" then
		return score.Failed or "Climax"
	elseif phase == "Resolved" then
		return "Release"
	end
	return nil
end

function Stage.Pick(seen: { Seen }): Pick
	local best: Pick = { Stage = "Calm", Since = 0, Ramp = 0, Ref = nil }
	for _, entry in seen do
		const score = ANOMALIES[entry.Ref]
		if score == nil then
			continue
		end
		const key = Stage.Of(score, entry.Phase)
		if key == nil then
			continue
		end
		const priority = Stage.Priority(key)
		const current = Stage.Priority(best.Stage)
		if priority > current or (priority == current and key == best.Stage and entry.Since < best.Since) then
			const ramp = score.Ramp
			const picked: Pick = { Stage = key, Since = entry.Since, Ramp = ramp, Ref = entry.Ref }
			best = picked
		end
	end
	return best
end

-- The stage to be in now. `current` and `enteredAt` (os.clock) are the director's; `wanted` comes from Pick (or a dev
-- force). A hot stage that loses its records goes to Release; Release goes to Calm after its Hold.
function Stage.Next(current: StageKey, enteredAt: number, wanted: StageKey, clock: number): StageKey
	if wanted == current then
		return current
	end
	if Stage.Priority(wanted) > Stage.Priority(current) then
		return wanted
	end
	const row = STAGES[current]
	const hold = if row ~= nil then row.Hold else 0
	if clock - enteredAt < hold then
		return current
	end
	if wanted == "Calm" and Stage.IsHot(current) then
		return "Release"
	end
	return wanted
end

-- 0..1 position in the ramp, shaped by the stage's Curve
function Stage.Progress(stage: Content.ScoreStage, since: number, ramp: number, now: number): number
	if ramp <= 0 then
		return 1
	end
	const t = math.clamp((now - since) / ramp, 0, 1)
	return t ^ math.max(stage.Curve, 0.01)
end

return table.freeze(Stage)
