--!strict
-- ANM-011 The shaker, server rule (T10: never in shared). V2 family A (DEC-254, DEC-255; TASK-292).
-- TASK-591 (owner 2026-10-19, Provisional, Q-399): he is not a monster, he is starving and stressed; his ticket is a plain
-- hot dog with nothing on it (CustomerService.OpenTicket, Variant "shake").
-- Owner 2026-10-22 (Provisional; design/anomalies-after-accept-proposal.md §9, pilot): no ACCEPT / REFUSE; his order is
-- taken at the end of the talk and he waits in the delivery queue. Condition Plain (attention, Kit/CustomerActor): served
-- plain = Resolved, x PayMult + Bonus. A topping = he throws the plate at the wall (§9.9: the hot dog is lost, no sale) and
-- who served it loses ReturnSanity; he keeps waiting, enraged, Returns times. One more = thrown again, -Sanity of who
-- served it, he stomps off. Never a jumpscare. Patience out = no penalty.
-- The two sanity numbers live in Content.PlateThrow.Sanity (owner 2026-10-22: "retira 15 de sanidade e na segunda vez 5").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const rule: Api.Rule = {
	Anomaly = "anm_011_shaker",
	Verb = "serve",
	LikelyWrongVerb = "serve",
	Window = 0,
	IsCritical = false,
	Params = {
		Variant = "shake", -- CustomerService:SpawnActor variant (its ticket is plain)
		-- PROVISIONAL (proposal §2.5, §9.9)
		Condition = {
			Kind = "Plain",
			Returns = 1,
			ReturnSanity = Content.PlateThrow.Sanity.Throw,
			Sanity = Content.PlateThrow.Sanity.Leave,
			PayMult = 1,
			Bonus = 1,
		},
	},
}

return rule
