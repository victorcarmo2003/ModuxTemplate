--!strict
-- PlateView and its grade seals. The board of the Build / Serve tabs at 492 x 256 (the phone board of the spec): the bun, the
-- sausage, up to three toppings, the plate seal and the empty state. Below it the three seals at their three sizes (pip 18,
-- mini 32, plate 120) so the shapes can be checked in grayscale (star / circle with check / blot).
-- Controls: Bun, Cut, Guide, Sausage, Toppings (0 to 3), Seal, Message (shown with Bun = None).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local PlateView = require(script.Parent)
local Seal = require(script.Parent.Seal)

const create = Vide.create

type Controls = {
	Bun: () -> string,
	Cut: () -> number,
	Guide: () -> boolean,
	Sausage: () -> string,
	Toppings: () -> number,
	Seal: () -> string,
	Message: () -> string,
}

const KEYS = { "ketchup", "cheese", "bacon" }

local function seal(grade: Seal.Grade?, size: number, label: ((Seal.Grade) -> string)?): Frame
	return Seal({
		Grade = function(): Seal.Grade?
			return grade
		end,
		Size = size,
		Label = label,
		LayoutOrder = size,
	})
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Bun = UILabs.Choose({ "Closed", "Cut", "Open", "None" }),
		Cut = UILabs.Slider(0.5, 0, 1, 0.05),
		Guide = true,
		Sausage = UILabs.Choose({ "None", "Ghost", "Raw", "Half", "Ready" }),
		Toppings = UILabs.Slider(2, 0, 3, 1),
		Seal = UILabs.Choose({ "None", "Perfect", "Good", "Messy" }),
		Message = "Waiting for the grill",
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const seals: { any } = {
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	}
	for _, grade in { "Perfect", "Good", "Messy" } :: { Seal.Grade } do
		table.insert(seals, seal(grade, 18, nil))
		table.insert(seals, seal(grade, 32, nil))
		table.insert(
			seals,
			seal(grade, 120, function(value: Seal.Grade): string
				return value
			end)
		)
	end
	table.insert(seals, seal(nil, 18, nil))

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),

		CartoonPanel({
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.fromOffset(492, 256),
			Tone = Theme.Tone.Cream,
			Radius = Theme.Radius.Card,
			Children = {
				PlateView({
					Bun = function(): PlateView.BunState
						return controls.Bun() :: PlateView.BunState
					end,
					Cut = controls.Cut,
					Guide = controls.Guide,
					Sausage = function(): PlateView.Sausage?
						const state = controls.Sausage()
						return if state == "None" then nil else { X = 0.5, Y = 0.5, State = state :: PlateView.SausageState }
					end,
					Toppings = function(): { PlateView.Topping }
						const list: { PlateView.Topping } = {}
						for index = 1, controls.Toppings() do
							table.insert(list, { Key = KEYS[index], Amount = 0.8 })
						end
						return list
					end,
					Seal = function(): PlateView.Grade?
						const value = controls.Seal()
						return if value == "None" then nil else value :: PlateView.Grade
					end,
					SealLabel = function(grade: PlateView.Grade): string
						return if grade == "Perfect" then "Perfect!" else grade
					end,
					Message = controls.Message,
				}),
			},
		}),

		create("Frame")({
			Position = UDim2.fromOffset(24, 300),
			Size = UDim2.fromOffset(0, 130),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			seals,
		}),
	})
end)
