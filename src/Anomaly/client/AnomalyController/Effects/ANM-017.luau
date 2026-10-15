--!strict
-- ANM-017 The crawler, client effect (V2 family B, verb hide; DEC-254, DEC-256; TASK-272). Comes on all fours, fast, rears up at the window.
-- Warning, pass and jumpscare: Kit/Hide. Presentation only (T10). Pass seconds mirror Rules/ANM-017 (LookFrom = Approach,
-- LookTo = Approach + Look; Provisional).
local Hide = require(script.Parent.Kit.Hide)

return Hide.Effect({
	Ref = "ANM-017",
	Style = "Crawl",
	Signal = "Scratch", -- TASK-339: fast scratching under the trailer
	Asset = "ANM-017_Crawler",
	Approach = 3,
	Look = 3,
	Leave = 3,
})
