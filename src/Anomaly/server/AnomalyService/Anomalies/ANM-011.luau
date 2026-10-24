--!strict
-- ANM-011 The shaker (V2 family A, odd customer; DEC-254, DEC-255; TASK-292; anomalies-v2-proposal.md §3 A).
-- Sign: the whole body shakes fast while it stands in line (actor Variant "shake", client modifier Effects/Kit/OddCustomer).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9, pilot Plain "JUST BREAD", attention): no REFUSE;
-- his order (plain, CustomerService) is taken at the end of the talk and he waits in the delivery queue shaking hard.
-- Served plain = calmed, Resolved, x1 + Bonus. A topping = the plate banged back (Returns times, he keeps waiting),
-- then he walks off shaking: -Sanity of who served, never a jumpscare. The window no longer reaches him. Left waiting = nothing.
-- Verb and numbers: Rules/ANM-011.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-011",
	Scare = true,
})
