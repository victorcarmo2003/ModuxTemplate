--!strict
-- Stage Build (tab Build, steps `bun` and `build`): placeholder of TASK-173 that exercises the kit and the gesture module,
-- with NO scoring and NO packets (P7c, TASK-178, replaces it):
--   bun     a tap on the bun opens it (the knife drag and its score come with the Slice gesture)
--   build   the sausage ghost sits in the bun; tapping a topping box puts it on the plate (up to MaxToppings, no repeats)
-- Next closes the plate (a Good seal, no real grade) and goes to Serve.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)

const prep = Content.Prep
const MAX = Content.OrderRules.MaxToppings

const Build: Stage.Stage = {
	Tab = "Build",
	HasPanel = true,
	Board = function(controller: any): any
		return Parts.Plate(controller, function(_mat: Frame, bun: Frame)
			const arm = controller.Gestures:Arm("Tap", bun, nil, function(event: any)
				controller:OnGesture(event)
			end)
			Vide.cleanup(function()
				arm:Cancel()
			end)
		end, nil)
	end,
	Panel = function(controller: any, layout: () -> any): any
		return Parts.Ingredients(controller, layout)
	end,
	Hint = function(controller: any): string
		const step = prep.Steps.ByKey[controller.Step()]
		return if step ~= nil then step.Hint else prep.Tabs.ByKey.Build.Hint
	end,
	Next = function(controller: any): Stage.Next
		const needs = controller.Needs()
		const ready = if controller.Step() == "bun" then needs.BunCut == true else needs.PlateBuilt == true
		return { Label = prep.Texts.Next, Enabled = ready, Pulse = ready }
	end,
	OnEnter = function(controller: any)
		const view: any = controller.View
		if view.Bun() == "None" then
			view.Bun("Closed")
			view.Guide(true)
			view.Message("")
		end
	end,
	OnGesture = function(controller: any, event: any)
		const view: any = controller.View
		if event.Kind == "Tap" and controller.Step() == "bun" then
			view.Bun("Open")
			view.Guide(false)
			controller:Need("BunCut", true)
			controller:SetPip(1, "Good")
		elseif event.Kind == "Pick" and controller.Step() == "build" then
			const current: { any } = view.Toppings()
			const list = table.clone(current)
			if #list < MAX and not view.Used()[event.Key] then
				table.insert(list, { Key = event.Key, Amount = 0.8 })
				view.Toppings(list)
				const marks: { [string]: boolean } = view.Used()
				const used = table.clone(marks)
				used[event.Key] = true
				view.Used(used)
				controller:Need("PlateBuilt", true)
				controller:SetPip(3, "Good")
			end
		end
	end,
	OnNext = function(controller: any)
		if controller.Step() == "bun" then
			controller:SetStage("build")
			controller.View.Sausage({ X = 0.5, Y = 0.5, State = "Ghost" })
			controller:SetPip(2, "Good")
		else
			controller.View.Sausage({ X = 0.5, Y = 0.5, State = "Ready" })
			controller.View.Seal("Good")
			controller:SetTab("Serve")
			controller:SetStage("serve")
		end
	end,
}

return Build
