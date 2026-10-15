--!strict
-- ANM-004 The copies, server rule (T10: never in shared). anomalies.md N4; npcs.md NPC-012; DEC-051, DEC-054.
-- Refuse the mirrored copy resolves; "Take Order" on the copy is the error (Fail of who took it); refusing the
-- original or leaving the copy waiting is no error. Window 0: the deadline is the copy's patience.
-- Door flow after the error (DEC-247): Params.Door*/Knock*; see Anomalies/ANM-004.luau.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_004_copies",
	Verb = "refuse",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "mirror", -- CustomerService:SpawnActor variant (CopyOf = the original)
		Wrong = "take_order", -- customer action on the copy that fails the rule
		OmissionFails = false, -- copy left waiting until patience runs out: no penalty
		FreeSlots = 2, -- free counter slots (and NPC cap room) needed to start: original + copy (npcs.md N4)
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
