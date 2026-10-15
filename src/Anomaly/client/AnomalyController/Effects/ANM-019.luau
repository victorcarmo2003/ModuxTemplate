--!strict
-- ANM-019 The roof walker, client effect (V2 family B, verb hide; DEC-254, DEC-256; TASK-272). Steps on the trailer roof, drops at the front and looks in.
-- Warning, pass and jumpscare: Kit/Hide. Presentation only (T10). Pass seconds mirror Rules/ANM-019 (LookFrom = Approach,
-- LookTo = Approach + Look; Provisional).
local Hide = require(script.Parent.Kit.Hide)

return Hide.Effect({
	Ref = "ANM-019",
	Style = "Roof",
	Signal = "Roof", -- TASK-339: heavy steps on the trailer roof
	Asset = "ANM-019_RoofWalker",
	Approach = 5,
	Look = 3,
	Leave = 3,
})
