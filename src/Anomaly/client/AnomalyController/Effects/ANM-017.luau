--!strict
-- ANM-017 The crawler, client effect (V2 family B, verb hide; DEC-254, DEC-256; TASK-272). Comes on all fours, fast, rears up at the window.
-- Warning, pass and jumpscare: Kit/Hide. Presentation only (T10). Pass seconds mirror Rules/ANM-017 (LookFrom = Approach,
-- LookTo = Approach + Look; Provisional).
-- TASK-483 (restaurant): it runs down the kitchen aisle between the counters (REV-4 to REV-1: X -48 to -33, 7 studs past each end),
-- rears up in the middle facing the work counter (TRL) where the players climbed. The directed layer (whispers, heart,
-- bars) is Content.HorrorScenes anm_017_crawler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Hide = require(script.Parent.Kit.Hide)

const restaurant = Content.Restaurant.Rules.Enabled

return Hide.Effect({
	Ref = "ANM-017",
	Style = "Crawl",
	Signal = "Scratch", -- TASK-339: fast scratching under the trailer
	Asset = "ANM-017_Crawler",
	Approach = 3,
	Look = 3,
	Leave = 3,
	Path = if restaurant then { "REV-4", "REV-1" } else nil,
	Extend = 7,
	Face = "TRL",
})
