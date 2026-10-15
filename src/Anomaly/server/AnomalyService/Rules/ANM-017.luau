--!strict
-- ANM-017 The crawler, server rule (T10: never in shared). V2 family B, verb hide (DEC-254, DEC-255; TASK-272).
-- The warning gives WarnFor s to leave the trailer by the back door and stand in a HideZone; from LookFrom to LookTo s
-- of the pass, every active player outside a HideZone gets the jumpscare and faints (Kit/Hide). Not critical
-- (DEC-255: only everyone down loses the night). All numbers Provisional.
local Hide = require(script.Parent.Parent.Anomalies.Kit.Hide)

return Hide.Rule("ANM-017", {
	WarnFor = 8, -- fast: the shortest warning (DEC-255: 8-10 s)
	PassFor = 9,
	LookFrom = 3,
	LookTo = 6,
})
