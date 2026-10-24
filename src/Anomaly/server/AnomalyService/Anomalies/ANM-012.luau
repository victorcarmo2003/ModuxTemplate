--!strict
-- ANM-012 The turned neck (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: she arrives with the head forward and a twitch; the talk's tic turns her head round (Content.Tics, Kit/Tic); the
-- security cameras show it turned from the start (actor Variant "neck", Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9, pilot NoLook): no REFUSE any more; her
-- order is taken at the end of the talk and she waits in the delivery queue with her neck broken (the residue made
-- explicit). Condition NoLook ("DON'T LOOK AT HER"): serve her without her head in your gaze; looking = jumpscare + faint
-- of who served (Kit Scare); right = she takes the plate and goes, x2 the price. Rules/ANM-012.luau, body Kit/CustomerActor.
-- The old answers are gone: refusing her (cue neck_snap) and the window shut in her face (she threw it open again, cue
-- window_slam, TASK-336); the cues stay in Content for the client but the server no longer sends them.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-012",
	Scare = true,
})
