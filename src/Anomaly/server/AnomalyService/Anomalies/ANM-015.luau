--!strict
-- ANM-015 The floater (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: it hovers a hand above the ground, no footsteps (actor Variant "float", client modifier Effects/Kit/OddCustomer).
-- Refuse = it leaves. "Take Order" on it = jumpscare + faint of who took it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-015.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-015",
	Scare = true,
})
