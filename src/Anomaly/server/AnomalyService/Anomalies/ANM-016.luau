--!strict
-- ANM-016 The starer (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: its head always turns to the nearest player and never looks away (actor Variant "stare", client modifier Effects/Kit/OddCustomer).
-- Refuse = it leaves. "Take Order" on it = jumpscare + faint of who took it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-016.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-016",
	Scare = true,
	-- TASK-591 (owner 2026-10-19): when it reaches the window every camera is dragged to it, then a flash blackout
	-- (Effects/ANM-016)
	CounterCue = "stare_front",
})
