--!strict
-- ANM-013 The white eyes (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: all-white eyes (face EyesWhite), ordinary look otherwise (actor Variant "eyes", client modifier Effects/Kit/OddCustomer).
-- Refuse = it leaves. "Take Order" on it = jumpscare + faint of who took it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-013.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-013",
	Scare = true,
})
