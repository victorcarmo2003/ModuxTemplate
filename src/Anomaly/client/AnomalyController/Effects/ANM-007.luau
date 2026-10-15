--!strict
-- ANM-007 The Walker, client effect (V2 family B, verb hide; DEC-254, DEC-256; TASK-272). Tall dark figure that walks to the window.
-- Warning, pass and jumpscare: Kit/Hide. Presentation only (T10). Pass seconds mirror Rules/ANM-007 (LookFrom = Approach,
-- LookTo = Approach + Look; Provisional).
local Hide = require(script.Parent.Kit.Hide)

return Hide.Effect({
	Ref = "ANM-007",
	Style = "Walk",
	Signal = "Buzz", -- TASK-339: lights flicker and buzz, heavy steps
	Asset = "AST-064_Walker",
	Approach = 4,
	Look = 3,
	Leave = 3,
})
