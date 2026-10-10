--!strict
-- ANM-006 The wavers (anomalies.md N6; npcs.md NPC-014; architecture.md §19.13; FEAT-019, FEAT-023; DEC-195, DEC-204;
-- TASK-115). Rule in Rules/ANM-006.luau. Environment anomaly, no actor (NpcCost 0).
--
--   Start   draws one apartment window (tag AnomalyAnchor, AnchorId WV-1..3) -> record Phase Signal, Anchor = n,
--           cue "curtain" (the sound comes before the silhouette). No window bound = Start false (retried).
--   Active  after CurtainLead s: Phase Active, the silhouette waves (client, TASK-116).
--   Tick    per active player: gaze cone on the window (ViewRange 80, line of sight, hidden = not looking).
--           "Seen" (-5) through ctx.SeenTick. LookLimit s in a row in the cone -> Fail of that player only
--           (personal target, DEC-204) + cue "waver_more" (two hands, +2 windows for 5 s: DEC-195 flavour).
--           Looking away resets the count. Each player fails at most once per occurrence.
--   End     AutoOff s after the start the window goes dark: Resolved when nobody failed, then Finish.
--
-- Continuous time is measured at 5 Hz: the start of a look is the midpoint between the last sample out of the cone
-- and the first one inside it (error about +-0.1 s against the 2.9 s / 3.0 s criterion of npcs.md).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-006"
const ANCHOR_TAG = "AnomalyAnchor"
const ANCHOR_ATTRIBUTE = "AnchorId"
const WINDOW_PREFIX = "WV-"
const WINDOWS = 3 -- WV-1..3 (MAP-01 §10.3)
const MAX_DT = 0.5 -- s; a late tick never counts more than this
const EPSILON = 1e-3 -- s; float slack of the sampled time
-- Defaults when Rules/ANM-006 is missing (same numbers as the rule file)
const DEFAULT_LOOK_LIMIT = 3
const DEFAULT_AUTO_OFF = 20
const DEFAULT_CURTAIN_LEAD = 1

type State = {
	Window: number,
	Target: Vector3,
	Range: number,
	LookLimit: number,
	ActiveAt: number,
	EndsAt: number,
	Active: boolean,
	LastTick: number,
	-- userId -> estimated server time the current continuous look began
	Since: { [number]: number },
	Failed: { [number]: boolean },
	AnyFailed: boolean,
}

local warnedNoWindow = false

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 then value else default
end

-- World position of an anchor: part position, model box centre or attachment world position.
local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		const box = instance:GetBoundingBox()
		return box.Position
	elseif instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	return nil
end

-- Bound windows: index n (WV-n) -> position. Only n in 1..WINDOWS.
local function windows(): { [number]: Vector3 }
	const out: { [number]: Vector3 } = {}
	for _, instance in CollectionService:GetTagged(ANCHOR_TAG) do
		if not instance:IsDescendantOf(workspace) then
			continue
		end
		const id = instance:GetAttribute(ANCHOR_ATTRIBUTE)
		if type(id) ~= "string" or string.sub(id, 1, #WINDOW_PREFIX) ~= WINDOW_PREFIX then
			continue
		end
		const index = tonumber(string.sub(id, #WINDOW_PREFIX + 1))
		if index == nil or index ~= math.floor(index) or index < 1 or index > WINDOWS or out[index] ~= nil then
			continue
		end
		const position = positionOf(instance)
		if position ~= nil then
			out[index] = position
		end
	end
	return out
end

local function fail(ctx: Api.Context, occ: Api.Occurrence, state: State, player: Player)
	const userId = player.UserId
	if state.Failed[userId] then
		return
	end
	state.Failed[userId] = true
	state.AnyFailed = true
	state.Since[userId] = nil
	ctx.Fail(occ, { player })
	ctx.Cue(occ, "waver_more", state.Window)
end

const Wavers: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const bound = windows()
		const choices: { number } = {}
		for index = 1, WINDOWS do
			if bound[index] ~= nil then
				table.insert(choices, index)
			end
		end
		if #choices == 0 then
			if not warnedNoWindow then
				warnedNoWindow = true
				ctx.Log(occ, "no AnomalyAnchor WV-1..3 bound in the Workspace (MAP-01 §10.3); not started")
			end
			return false
		end
		const window = choices[occ.Rng:NextInteger(1, #choices)]
		const rule = ctx.Rule(REF)
		const row = Content.Anomalies.ByKey[occ.Key]
		const lead = param(rule, "CurtainLead", DEFAULT_CURTAIN_LEAD)
		const state: State = {
			Window = window,
			Target = bound[window],
			Range = row.ViewRange,
			LookLimit = param(rule, "LookLimit", DEFAULT_LOOK_LIMIT),
			ActiveAt = occ.StartedAt + lead,
			EndsAt = occ.StartedAt + math.max(param(rule, "AutoOff", DEFAULT_AUTO_OFF), lead),
			Active = false,
			LastTick = occ.StartedAt,
			Since = {},
			Failed = {},
			AnyFailed = false,
		}
		occ.State = state
		ctx.Publish(occ, { Phase = "Signal", Step = 0, Anchor = window })
		ctx.Cue(occ, "curtain", window)
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if now >= state.EndsAt then
			if not state.AnyFailed then
				ctx.Succeed(occ)
			end
			ctx.Finish(occ)
			return
		end
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now
		if not state.Active then
			if now < state.ActiveAt then
				-- lit window behind the curtain: seeing it already counts as "seen", not as staring
				ctx.SeenTick(occ, state.Target, state.Range, dt)
				return
			end
			state.Active = true
			ctx.Publish(occ, { Phase = "Active" })
		end
		ctx.SeenTick(occ, state.Target, state.Range, dt)

		const present: { [number]: boolean } = {}
		for _, player in ctx.Active() do
			const userId = player.UserId
			present[userId] = true
			if state.Failed[userId] then
				continue
			end
			if not ctx.Looking(player, state.Target, state.Range) then
				state.Since[userId] = nil
				continue
			end
			local since = state.Since[userId]
			if since == nil then
				since = math.max(now - dt / 2, state.ActiveAt)
				state.Since[userId] = since
			end
			if now - since >= state.LookLimit - EPSILON then
				fail(ctx, occ, state, player)
			end
		end
		-- left, inactive or without a character: the continuous look is broken
		for userId in state.Since do
			if not present[userId] then
				state.Since[userId] = nil
			end
		end
	end,

	Stop = function(_ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		-- nothing outside the record: the window and the silhouette are client-only (TASK-116)
		occ.State = nil
	end,
}

return Wavers
