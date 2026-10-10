--!strict
-- ANM-007 The Walker, the critical rule (anomalies.md N7; npcs.md NPC-015; architecture.md §19.13; MAP-01 §5.6;
-- FEAT-019, FEAT-023; DEC-074, DEC-094, DEC-123, DEC-204; TASK-115). Rule in Rules/ANM-007.luau.
--
-- The Walker is a client-only actor (TASK-116) standing under the post of its Step; the server only keeps Step in the
-- Anomalies record and tests the gaze against the same spot:
--   step 0..9  StreetLight posts of the Juniper, Order = step + 1 (JL-09 = 1 ... P-01 = 10; MAP-01 §18 binding)
--   step 10    MapPoint WALKER-10 (28, 29), fixed: the edge of the trailer light, with or without the switch or
--              Trailer Lights (npcs.md N7, resolves N3 x N7)
--
--   Start   every position bound -> Phase Signal, Step 0, cue "post_buzz" on post Order 1 (DEC-123, ~2 s, heard by
--           the whole party). Missing posts or WALKER-10 = Start false (retried) and one warning.
--   Active  after SignalFor s. Party time (DEC-204 "any gaze counts"): every tick in which ANY active player has the
--           Walker in the cone (ViewRange 300, line of sight, hidden = not looking) adds dt to one shared counter;
--           each StepEvery s of it = one step forward (at most one per tick, so 1..4 players looking = 1 step/s),
--           cues "post_flicker" (entity = post Order of the new step, 0 at WALKER-10) and "walker_step" (entity =
--           step). A tick with nobody looking adds to the back counter instead (reset by any gaze); each BackEvery
--           s = one step back, no cue. "Seen" (-5) through ctx.SeenTick on the current position.
--   Step 10 ctx.Fail(occ, "active") -> critical: RoundService:LoseNight("critical") at once, no 10 s window
--           (DEC-094; the core sends it once and Phase Failed for the party). The Walker stays at the light.
--   End     Duration s after the start: Phase Resolved and Finish; the client backs it into the dark. Steps never
--           carry over: the next occurrence starts at 0.
--
-- Dev (tests/wave-3.md R18, Commands/Walker.luau): Walker.DevStep(step) writes Step through setStep, the same path
-- as a gaze step (cues, Fail at 10).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-007"
const POST_TAG = "StreetLight"
const POST_GROUP = "juniper_posts"
const LAST_POINT = "WALKER-10"
const FIGURE_HEIGHT = 4.5 -- studs above the ground: upper body of a tall figure (target of the gaze cone)
const MAX_DT = 0.5 -- s; a late tick never counts more than this
const EPSILON = 1e-3 -- s; float slack of 5 x 0.2 s against 1 s
-- Defaults when Rules/ANM-007 is missing (same numbers as the rule file)
const DEFAULT_STEPS = 10
const DEFAULT_STEP_EVERY = 1
const DEFAULT_BACK_EVERY = 10
const DEFAULT_DURATION = 45
const DEFAULT_SIGNAL_FOR = 2

type State = {
	Positions: { [number]: Vector3 }, -- step 0..Steps -> gaze target
	Steps: number,
	StepEvery: number,
	BackEvery: number,
	Range: number,
	Step: number,
	LookAcc: number,
	BackAcc: number,
	ActiveAt: number,
	EndsAt: number,
	Active: boolean,
	Lost: boolean,
	LastTick: number,
}

type Live = { Ctx: Api.Context, Occ: Api.Occurrence }

export type Walker = Api.Module & {
	DevStep: (step: number) -> string,
}

-- The running occurrence (at most one Walker at a time: NpcCost 1, one per night by age; dev path)
local live: Live? = nil
local warnedMissing = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 then value else default
end

-- Ground position of a post (bottom centre of its box) or of a part.
local function groundOf(instance: Instance): Vector3?
	local box: CFrame
	local size: Vector3
	if instance:IsA("Model") then
		box, size = instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		box, size = instance.CFrame, instance.Size
	else
		return nil
	end
	return Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
end

-- Gaze targets of every step, or (nil, what is missing).
local function positions(steps: number): ({ [number]: Vector3 }?, string?)
	const out: { [number]: Vector3 } = {}
	for _, instance in CollectionService:GetTagged(POST_TAG) do
		if not instance:IsDescendantOf(workspace) or instance:GetAttribute("Group") ~= POST_GROUP then
			continue
		end
		const order = instance:GetAttribute("Order")
		if type(order) ~= "number" then
			continue
		end
		const step = order - 1
		if step < 0 or step >= steps or step ~= math.floor(step) or out[step] ~= nil then
			continue
		end
		const ground = groundOf(instance)
		if ground ~= nil then
			out[step] = ground + Vector3.new(0, FIGURE_HEIGHT, 0)
		end
	end
	const last = MapIndex.FindPoint(LAST_POINT)
	if last ~= nil then
		out[steps] = last.Position + Vector3.new(0, FIGURE_HEIGHT, 0)
	end
	const missing: { string } = {}
	for step = 0, steps do
		if out[step] == nil then
			table.insert(missing, if step == steps then LAST_POINT else `post Order {step + 1}`)
		end
	end
	if #missing > 0 then
		return nil, table.concat(missing, ", ")
	end
	return out, nil
end

-- Writes Step; forward steps cue the flicker of the post and the footstep; reaching Steps fails the party.
local function setStep(ctx: Api.Context, occ: Api.Occurrence, state: State, step: number)
	const target = math.clamp(math.floor(step), 0, state.Steps)
	if target == state.Step or state.Lost then
		return
	end
	const forward = target > state.Step
	state.Step = target
	ctx.Publish(occ, { Step = target })
	if forward then
		ctx.Cue(occ, "post_flicker", if target < state.Steps then target + 1 else 0)
		ctx.Cue(occ, "walker_step", target)
	end
	if target >= state.Steps then
		state.Lost = true
		-- critical (Rules.IsCritical, DEC-074): the core calls LoseNight("critical") once and publishes Failed
		ctx.Fail(occ, "active")
	end
end

local function anyLooking(ctx: Api.Context, state: State): boolean
	const target = state.Positions[state.Step]
	for _, player in ctx.Active() do
		if ctx.Looking(player, target, state.Range) then
			return true
		end
	end
	return false
end

const Walker: Walker = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const steps = math.max(1, math.floor(param(rule, "Steps", DEFAULT_STEPS)))
		const found, missing = positions(steps)
		if found == nil then
			if not warnedMissing then
				warnedMissing = true
				ctx.Log(occ, `Walker positions not bound ({missing}); not started (MAP-01 §5.6)`)
			end
			return false
		end
		const row = Content.Anomalies.ByKey[occ.Key]
		const signalFor = param(rule, "SignalFor", DEFAULT_SIGNAL_FOR)
		const state: State = {
			Positions = found,
			Steps = steps,
			StepEvery = math.max(0.1, param(rule, "StepEvery", DEFAULT_STEP_EVERY)),
			BackEvery = math.max(0.1, param(rule, "BackEvery", DEFAULT_BACK_EVERY)),
			Range = row.ViewRange,
			Step = 0,
			LookAcc = 0,
			BackAcc = 0,
			ActiveAt = occ.StartedAt + signalFor,
			EndsAt = occ.StartedAt + math.max(param(rule, "Duration", DEFAULT_DURATION), signalFor),
			Active = false,
			Lost = false,
			LastTick = occ.StartedAt,
		}
		occ.State = state
		live = { Ctx = ctx, Occ = occ }
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = 0 })
		ctx.Cue(occ, "post_buzz", 1)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if now >= state.EndsAt and not state.Lost then
			ctx.Succeed(occ)
			ctx.Finish(occ)
			return
		end
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now
		if state.Lost then
			-- the night is being lost: the Walker stays at the light until the core stops it
			return
		end
		if not state.Active then
			if now < state.ActiveAt then
				return
			end
			state.Active = true
			ctx.Publish(occ, { Phase = "Active" })
		end
		ctx.SeenTick(occ, state.Positions[state.Step], state.Range, dt)

		if anyLooking(ctx, state) then
			state.BackAcc = 0
			-- capped: a late tick or a crowd of players never buys more than one step at once
			state.LookAcc = math.min(state.LookAcc + dt, state.StepEvery)
			if state.LookAcc >= state.StepEvery - EPSILON then
				state.LookAcc = math.max(0, state.LookAcc - state.StepEvery)
				setStep(ctx, occ, state, state.Step + 1)
			end
		else
			state.BackAcc += dt
			if state.BackAcc >= state.BackEvery - EPSILON then
				state.BackAcc = math.max(0, state.BackAcc - state.BackEvery)
				if state.Step > 0 then
					setStep(ctx, occ, state, state.Step - 1)
				end
			end
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		const current = live
		if current ~= nil and current.Occ == occ then
			live = nil
		end
		occ.State = nil
	end,

	-- Dev only (Commands/Walker.luau): same path as a gaze step. Errors when no Walker is running.
	DevStep = function(step: number): string
		const current = live
		if current == nil or current.Occ.State == nil then
			error("no Walker running: /dev anomaly ANM-007 first (Night phase)", 0)
		end
		const state = current.Occ.State :: State
		if type(step) ~= "number" or step ~= step or step < 0 or step > state.Steps then
			error(`step must be 0..{state.Steps}`, 0)
		end
		if state.Lost then
			error("the Walker already reached the light (night being lost)", 0)
		end
		if not state.Active then
			state.Active = true
			current.Ctx.Publish(current.Occ, { Phase = "Active" })
		end
		state.LookAcc = 0
		state.BackAcc = 0
		setStep(current.Ctx, current.Occ, state, step)
		return `Walker step {state.Step}{if state.Lost then " (critical: LoseNight sent)" else ""}`
	end,
}

return Walker
