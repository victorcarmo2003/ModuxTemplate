--!strict
-- Stage Grill (tab Grill): placeholder of TASK-173. The slots (+ Sausage, the flip window, Collect) come with P7b (TASK-177).
-- Today: the eight empty slots of the layout and a corner button that goes on to the bun.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)

const prep = Content.Prep

const Grill: Stage.Stage = {
	Tab = "Grill",
	HasPanel = false,
	Board = function(controller: any): any
		return Parts.GrillSlots(controller)
	end,
	Hint = function(_controller: any): string
		return prep.Steps.ByKey.grill.Hint
	end,
	Next = function(_controller: any): Stage.Next
		return { Label = prep.Steps.ByKey.grill.NextLabel, Enabled = true }
	end,
	OnNext = function(controller: any)
		controller:SetTab("Build")
		controller:SetStage("bun")
	end,
}

return Grill
