--!strict
-- ANM-011 The shaker (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: the whole body shakes fast while it stands in line (actor Variant "shake", client modifier Effects/Kit/OddCustomer).
-- TASK-591: serve him a plain hot dog (his ticket has no topping) = calmed, Resolved. Shut the window on him or serve
-- one with a topping = jumpscare + faint of who did it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-011.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-011",
	Scare = true,
})
