--!strict
-- TicketRail: the card (left column) and the strip (portrait). Controls: Strip, State, Patience, Toppings (0 to 3), Queue,
-- Empty (no ticket), Long (a long customer name and line: they must truncate, never overflow).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local TicketRail = require(script.Parent)

const create = Vide.create

type Controls = {
	Strip: () -> boolean,
	State: () -> string,
	Patience: () -> number,
	Toppings: () -> number,
	Queue: () -> number,
	Empty: () -> boolean,
	Long: () -> boolean,
}

const KEYS = { "ketchup", "mustard", "cheese" }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Strip = false,
		State = UILabs.Choose({ "Active", "Urgent", "Served" }),
		Patience = UILabs.Slider(0.7, 0, 1, 0.05),
		Toppings = UILabs.Slider(3, 0, 3, 1),
		Queue = UILabs.Slider(3, 0, 12, 1),
		Empty = false,
		Long = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		create("Frame")({
			Position = UDim2.fromOffset(24, 24),
			Size = function(): UDim2
				return if controls.Strip() then UDim2.fromOffset(334, 82) else UDim2.fromOffset(152, 140)
			end,
			BackgroundTransparency = 1,
			TicketRail({
				Ticket = function(): TicketRail.Ticket?
					if controls.Empty() then
						return nil
					end
					const toppings: { string } = {}
					for index = 1, controls.Toppings() do
						table.insert(toppings, KEYS[index])
					end
					return {
						Id = 12,
						Name = if controls.Long() then "Bartholomew the Sixteenth" else "Rex",
						Say = if controls.Long() then "Mustard, but only on the side facing the window, please." else "The usual, please.",
						Toppings = toppings,
						Patience = controls.Patience(),
						State = controls.State() :: TicketRail.State,
					}
				end,
				Queue = controls.Queue,
				Strip = controls.Strip,
			}),
		}),

		create("TextLabel")({
			Position = UDim2.fromOffset(24, 260),
			Size = UDim2.fromOffset(420, 40),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = Theme.MinTextSize,
			TextColor3 = Theme.Color.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = "Card 152 x 140 (phone / desktop), strip 334 x 82 (portrait). Tap cycles the ticket.",
		}),
	})
end)
