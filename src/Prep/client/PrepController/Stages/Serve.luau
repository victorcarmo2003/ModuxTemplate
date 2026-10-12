--!strict
-- Stage Serve (tab Serve): placeholder of TASK-173. The customer cards, the match highlight and PrepOrder Serve come with
-- P7d (TASK-179). Today: the finished plate with its seal (or "Nothing to serve") and a corner button that starts over.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)

const prep = Content.Prep

const Serve: Stage.Stage = {
	Tab = "Serve",
	HasPanel = false,
	Board = function(controller: any): any
		return Parts.Plate(controller, nil, nil)
	end,
	Hint = function(_controller: any): string
		return prep.Steps.ByKey.serve.Hint
	end,
	Next = function(controller: any): Stage.Next
		const ready = controller.View.Seal() ~= false
		return { Label = prep.Texts.Serve, Enabled = ready, Pulse = ready }
	end,
	OnEnter = function(controller: any)
		if controller.View.Bun() == "None" then
			controller.View.Message("Nothing to serve")
		end
	end,
	OnNext = function(controller: any)
		controller:ResetPlate()
		controller:SetTab("Order")
		controller:SetStage("grill")
		controller:Toast("Served!", "Good")
	end,
}

return Serve
