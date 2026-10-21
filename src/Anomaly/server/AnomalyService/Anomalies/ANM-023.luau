--!strict
-- ANM-023 The one on camera (V2 family A, odd customer; owner request 2026-10-21, Provisional Q-437).
-- Sign: none in person. Through the security cameras its body is broken (limbs bent the wrong way) and its head turns to
-- the lens (actor Variant "oncam", client modifier Effects/Kit/OddCustomer, read on SecurityView).
-- Refuse = it leaves. "Take Order" on it = jumpscare + faint of who took it (Kit Scare). Left waiting = nothing.
-- Verb and numbers: Rules/ANM-023.luau. Body: Kit/CustomerActor.
local Kit = require(script.Parent.Kit.CustomerActor)

return Kit.Module({
	Ref = "ANM-023",
	Scare = true,
})
