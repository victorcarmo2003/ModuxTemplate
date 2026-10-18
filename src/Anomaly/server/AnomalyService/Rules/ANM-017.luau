--!strict
-- ANM-017 The crawler, server rule (T10: never in shared). V2 family B, verb hide (DEC-254, DEC-255; TASK-272).
-- The warning gives WarnFor s to leave the trailer by the back door and stand in a HideZone; from LookFrom to LookTo s
-- of the pass, every active player outside a HideZone gets the jumpscare and faints (Kit/Hide). Not critical
-- (DEC-255: only everyone down loses the night). All numbers Provisional.
-- TASK-483 (restaurant): the same window, but the safe players are the ones off the floor (counter, table, crate):
-- feet within Lift studs of FloorY for Ground s in a row during the look window = jumpscare + faint.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Hide = require(script.Parent.Parent.Anomalies.Kit.Hide)

const restaurant = Content.Restaurant.Rules.Enabled

return Hide.Rule("ANM-017", {
	-- fast: the shortest warning (DEC-255: 8-10 s); the restaurant gives 10 s to climb (HorrorScenes crawler scene)
	WarnFor = if restaurant then 10 else 8,
	PassFor = 9,
	LookFrom = 3,
	LookTo = 6,
	-- Test "Floor" (restaurant): kitchen floor top, counter tops at 3.0 (tools/assetplace/restaurant_bind.luau)
	FloorY = 0.45,
	Lift = 1.2,
	Ground = 0.4,
})
