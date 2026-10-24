--!strict
-- ANM-023 The one on camera (V2 family A, odd customer; owner request 2026-10-21, Provisional Q-437).
-- Sign: none in person. Through the security cameras its body is broken (limbs bent the wrong way) and its head turns to
-- the lens (actor Variant "oncam", client modifier Effects/Kit/OddCustomer, read on SecurityView).
-- Owner 2026-10-22 (Provisional; anomalies-after-accept-proposal.md §9): no REFUSE; its order is taken at the end of the
-- talk and it waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition "Serve" (interim, no error); planned NoServe +
-- the cameras (proposal §2.9). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-023.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-023",
	Scare = true,
})
