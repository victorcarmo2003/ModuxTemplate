--!strict
-- ANM-019 The roof walker, server rule (T10: never in shared). V2 family B, verb hide (DEC-254, DEC-255; TASK-272).
-- The warning gives WarnFor s to leave the trailer by the back door and stand in a HideZone; from LookFrom to LookTo s
-- of the pass, every active player outside a HideZone gets the jumpscare and faints (Kit/Hide). Not critical
-- (DEC-255: only everyone down loses the night). All numbers Provisional.
local Hide = require(script.Parent.Parent.Anomalies.Kit.Hide)

return Hide.Rule("ANM-019", {
	WarnFor = 10, -- the steps on the roof are part of the warning
	PassFor = 11,
	LookFrom = 5, -- after it climbs down at the front
	LookTo = 8,
})
