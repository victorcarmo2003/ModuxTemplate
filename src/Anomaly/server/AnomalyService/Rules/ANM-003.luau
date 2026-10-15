--!strict
-- ANM-003 "The stopped clock", server rule (T10: never replicated). docs/story/anomalies.md N3; design/npcs.md
-- NPC-011; architecture.md §19.13; DEC-054, DEC-204, DEC-255; TASK-113, TASK-340.
-- Verb light: a church bell tolls three times; the street posts die on the first stroke. The trailer light (switch)
-- must be OFF by the third stroke (ThirdAt s after the first). Still on = a swarm of moths and bats comes for the light
-- and EVERY active player faints (V2, DEC-255). Off = resolved, the posts come back.
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_003_stopped_clock",
	Verb = "light",
	LikelyWrongVerb = "ignore",
	Window = 8,
	IsCritical = false,
	Params = {
		-- s after the first stroke the second one tolls (owner: "1 s depois")
		SecondAt = 1,
		-- s after the first stroke the third one tolls: the deadline to switch the trailer light off; PROVISIONAL
		ThirdAt = 8,
		-- s of the swarm before everyone faints; PROVISIONAL
		SwarmFor = 1.8,
		-- s after the outcome the posts come back; PROVISIONAL
		RestoreAfter = 2.5,
	},
}

return rule
