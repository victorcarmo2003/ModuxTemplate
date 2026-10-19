--!strict
-- ANM-017 The crawler (V2 family B "something is coming", verb hide; DEC-254, DEC-255, DEC-256; TASK-272;
-- anomalies-v2-proposal.md §3 B). Comes on all fours along the ground, fast, and rises at the window.
-- Warning, pass and the hiding test: Kit/Hide. Numbers: Rules/ANM-017.luau. Look: Effects/ANM-017 on the client.
-- TASK-483 (DEC-294, owner 2026-10-18 "get on the counter"): in the restaurant (Content.Restaurant.Rules.Enabled) it
-- scratches under the floor and runs through the kitchen; the test is "off the floor" (Kit/Hide Test "Floor"), not a
-- HideZone. The trailer keeps the HideZone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Hide = require(script.Parent.Kit.Hide)

return Hide.Module({
	Ref = "ANM-017",
	Test = function(): Hide.Test
		return "Floor"
	end,
})
