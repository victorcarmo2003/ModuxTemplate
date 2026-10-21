--!strict
-- ANM-020 "The blackout", server rule (T10: never replicated). V2 family C "falha de energia" (DEC-254, DEC-255,
-- DEC-256; design/anomalies-v2-proposal.md §3 C; TASK-273).
-- Verb light: the power goes out; somebody walks to the breaker at the back of the trailer in the dark and holds it
-- (breaker_reset, Content.Actions Hold 3 s) within Window s. Past the window the shape attacks: jumpscare + faint
-- (VitalService:Fall) of every active player in the trailer zone. No -RuleBroken (DEC-255).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Api = require(script.Parent.Parent.Api)

const REF = "ANM-020"
const FALLBACK_KEY = "anm_020_blackout" -- the key TASK-271 is expected to give the row

-- Key of the Content row with this Ref (the row is written by TASK-271; the Validate of Rules/init checks it)
local function keyOf(ref: string): string
	for _, row in Content.Anomalies.List do
		if row.Ref == ref then
			return row.Key
		end
	end
	return FALLBACK_KEY
end

const rule: Api.Rule = {
	Anomaly = keyOf(REF),
	Verb = "light",
	LikelyWrongVerb = "switch_light",
	-- s from the power going out to the attack (proposal §3 C "30 s sem religar")
	Window = 20, -- owner 2026-10-21: 20 s (Q-434 cut it to 12, too short to reach the breaker; was 30)
	IsCritical = false,
	Params = {
		-- who the shape attacks: inside the trailer (VehicleService:IsInside) or within Radius studs (flat) of Point
		Point = "TRL",
		Radius = 24, -- same as the trailer zone of N8/N9 (architecture.md §19.14); Effects/ANM-020 ATTACK_RADIUS
		-- s from the jumpscare cue to the faint (the face is on screen first, DEC-256; Kit/CustomerActor SCARE_FAINT)
		FaintDelay = 0.7,
		-- s after the attack the power comes back by itself (the shape leaves). PROVISIONAL (TASK-273)
		RestoreAfter = 3,
		-- Restaurant only (Content.Restaurant.Rules.Enabled; TASK-444, owner request 2026-10-17). PROVISIONAL
		OmenFor = 2, -- s from the phone glitch to the power cut (owner 2026-10-18: "two seconds after phone_glitch, lights off"; was 2.5)
		-- s of dark before the shape comes = the rising violin (Content.Score LayerCut). Owner 2026-10-21 (Q-434): 60 %
		-- shorter so the weird stuff starts sooner (was 30, the Scary Violin UP cut at 30 s; before that 15)
		-- then 20 s (owner 2026-10-21: no time to reach the breaker in 12 s)
		RestaurantWindow = 20,
		-- Mirrors Content.Score anomalies["ANM-020"].Ramp (the client cuts the music and shows the jumpscare at exactly this second)
		-- s after the attack the occurrence ends (the shape walks away, HorrorScenes Failed steps ~6 s); the power stays
		-- out until the breaker (owner 2026-10-21, Provisional; was MaxDark 20 s, then the power came back by itself)
		LeaveAfter = 6,
		Margin = 1, -- studs around a HideZone (HIDE-P, the pantry) that still count as hidden
	},
}

return rule
