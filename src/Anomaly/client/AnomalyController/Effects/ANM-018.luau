--!strict
-- ANM-018 The grin, client effect (V2 family B, verb hide; DEC-254, DEC-256; TASK-272). A huge grinning face rises in the service window.
-- Warning, pass and jumpscare: Kit/Hide. Presentation only (T10). Pass seconds mirror Rules/ANM-018 (LookFrom = Approach,
-- LookTo = Approach + Look; Provisional).
local Hide = require(script.Parent.Kit.Hide)

return Hide.Effect({
	Ref = "ANM-018",
	Style = "Grin",
	Asset = "ANM-018_Grin",
	Approach = 2,
	Look = 4,
	Leave = 3,
})
