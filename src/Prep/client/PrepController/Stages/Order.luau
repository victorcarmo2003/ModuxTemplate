--!strict
-- Stage Order (tab Order): placeholder of TASK-173. The real ticket line, Take and pinning come with P7b (TASK-177).
-- Today: the notice of the tab, and the corner button waits for a ticket in the view-model (the dev preview brings one).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Parts = require(script.Parent.Parent.Parts)
local Stage = require(script.Parent.Parent.Stage)

const prep = Content.Prep

const Order: Stage.Stage = {
	Tab = "Order",
	HasPanel = false,
	Board = function(controller: any): any
		return Parts.Notice(function(): string
			return if controller.View.Ticket() ~= false then "Ticket pinned. Next: the grill." else prep.Tabs.ByKey.Order.Hint
		end)
	end,
	Hint = function(_controller: any): string
		return prep.Tabs.ByKey.Order.Hint
	end,
	Next = function(controller: any): Stage.Next
		return { Label = prep.Texts.Next, Enabled = controller.Needs().TicketPicked == true, Pulse = controller.Needs().TicketPicked == true }
	end,
	OnNext = function(controller: any)
		controller:SetTab("Grill")
		controller:SetStage("grill")
	end,
}

return Order
