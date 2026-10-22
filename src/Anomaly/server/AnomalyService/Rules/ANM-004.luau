--!strict
-- ANM-004 The copies, server rule (T10: never in shared). anomalies.md N4; npcs.md NPC-012; DEC-051, DEC-054.
-- Until 2026-10-22: refusing the mirrored copy resolved, "Take Order" on the copy was the error; refusing the
-- original or leaving the copy waiting is no error. Window 0: the deadline is the copy's patience.
-- Door flow after the error (DEC-247): Params.Door*/Knock*; see Anomalies/ANM-004.luau.
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9): no ACCEPT / REFUSE; the order is taken
-- at the end of the talk and the actor waits in the delivery queue (Kit/CustomerActor). Not migrated yet: condition
-- "Serve" (interim: any served order = Resolved, no error, no jumpscare); planned: NoServe (the twin ticket: don't cook it, proposal §2.4).
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_004_copies",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "mirror", -- CustomerService:SpawnActor variant (CopyOf = the original)
		Condition = { Kind = "Serve" },
		-- owner 2026-10-22 (Provisional): NoServe actor, its patience runs OrderRules.UnservablePatienceScale (x0.5)
		Unservable = true,
		CopyDelay = 2, -- s after the original left the counter, its copy comes alone (TASK-347, Provisional: one NPC at
		-- the night counter, so the original and the copy never stand together)
		-- "The copy knocks" (DEC-247, Provisional): after the copy is served the back door locks; DoorDelayMin..Max s
		-- later (uniform, no new customer meanwhile) the copy knocks KnockCount times, KnockGapMin..Max s apart
		DoorDelayMin = 8,
		DoorDelayMax = 12,
		KnockCount = 3,
		KnockGapMin = 2,
		KnockGapMax = 3,
		DoorGrace = 2, -- s after the last knock the door still answers; then the copy fades and the door unlocks
	},
}

return rule
