--!strict
-- ANM-014 The big head (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: the head is twice its size (actor Variant "bighead", client modifier Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9, pilot Hurry "BE QUICK"): no REFUSE; its order is
-- taken at the end of the talk and it waits in the delivery queue, the head swelling a step every Seconds / Steps.
-- Served in time = Resolved, x2 the price; Seconds out (or its patience) = jumpscare + faint of the taker (Kit Scare).
-- Verb and numbers: Rules/ANM-014.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-014",
	Scare = true,
})
