--!strict
-- Reference anomaly module (TASK-106). NOT discovered: the leading "_" keeps it out of the schedule. The dev command
-- "anomaly <key> example" runs it on any anomaly key to exercise the core (set Anomalies, AnomalyCue, events, Stop).
-- Real modules live next to it as Anomalies/<Ref>.luau (ANM-001..ANM-010; TASK-111/113/115/117) with the rule in
-- Rules/<Ref>.luau. Contract and life cycle: ../Api.luau.
--
-- What it does: Start publishes Phase Active and sends the anomaly's first cue; while it runs, any Customer "serve"
-- or "take_order" is treated as the wrong verb (Fail of who acted) and the light switch turned off as the right one
-- (Succeed); after DURATION seconds with nobody failing it resolves on its own. It always ends with Finish.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const DURATION = 20 -- seconds; example only (real numbers live in Rules/<Ref>.luau Params)

type State = { EndsAt: number }

const Example: Api.Module = {
	-- The dev command swaps this for the forced key; a real module has its own fixed Ref
	Ref = "ANM-001",

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const state: State = { EndsAt = occ.StartedAt + DURATION }
		occ.State = state
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		const row = Content.Anomalies.ByKey[occ.Key]
		if row ~= nil and #row.Cues > 0 then
			ctx.Cue(occ, row.Cues[1], 0)
		end
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		if now >= state.EndsAt then
			ctx.Succeed(occ)
			ctx.Finish(occ)
		end
	end,

	OnEvent = function(ctx: Api.Context, occ: Api.Occurrence, event: Api.Event)
		if event.Kind == "Customer" then
			const player = event.Player
			if player ~= nil and (event.Action == "serve" or event.Action == "take_order") then
				ctx.Fail(occ, { player })
				ctx.Finish(occ)
			end
		elseif event.Kind == "Switch" then
			if not event.On then
				ctx.Succeed(occ)
				ctx.Finish(occ)
			end
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, reason: Api.StopReason)
		ctx.Log(occ, `example stopped ({reason})`)
	end,
}

return Example
