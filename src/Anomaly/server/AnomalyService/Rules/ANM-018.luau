--!strict
-- ANM-018 The grin, server rule (T10: never in shared). V2 family B, verb hide (DEC-254, DEC-255; TASK-272).
-- The warning gives WarnFor s to leave the trailer by the back door and stand in a HideZone; from LookFrom to LookTo s
-- of the pass, every active player outside a HideZone gets the jumpscare and faints (Kit/Hide). Not critical
-- (DEC-255: only everyone down loses the night). All numbers Provisional.
local Hide = require(script.Parent.Parent.Anomalies.Kit.Hide)

return Hide.Rule("ANM-018", {
	WarnFor = 9,
	PassFor = 9,
	LookFrom = 2, -- the face rises at once in the window
	LookTo = 6,
})
