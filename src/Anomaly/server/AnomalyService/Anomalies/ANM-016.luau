--!strict
-- ANM-016 The starer (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: its head always turns to the nearest player and never looks away (actor Variant "stare", client modifier Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition "Serve" (interim, no error; proposal §2.11).
-- Left waiting = nothing.
-- Verb and numbers: Rules/ANM-016.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-016",
	Scare = true,
	-- TASK-591 (owner 2026-10-19): when it reaches the window every camera is dragged to it, then a flash blackout
	-- (Effects/ANM-016)
	CounterCue = "stare_front",
})
