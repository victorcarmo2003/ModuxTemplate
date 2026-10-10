--!strict
-- CrewCard: one card at the grid cell size the "Crew" screen uses on the smallest phone (120 x 115).
-- Every state comes from the controls (owned, selected, gems vs price); "Focused" draws the Mustard border.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local CrewCard = require(script.Parent)
local CardState = require(script.Parent.State)

const create = Vide.create
const source = Vide.source

type Controls = {
	Title: () -> string,
	Animal: () -> string,
	Price: () -> number,
	Gems: () -> number,
	Owned: () -> boolean,
	Selected: () -> boolean,
	Focused: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Title = "Runner",
		Animal = "Rabbit",
		Price = UILabs.Slider(45, 0, 180, 5),
		Gems = UILabs.Slider(30, 0, 400, 5),
		Owned = false,
		Selected = false,
		Focused = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const taps = source(0)

	return create("Frame")({
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 140),
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Cell",
			Size = UDim2.fromOffset(120, 115),
			BackgroundTransparency = 1,

			CrewCard({
				Key = "class_rabbit",
				Title = controls.Title(),
				Animal = controls.Animal(),
				Badge = string.upper(string.sub(controls.Animal(), 1, 1)),
				Price = controls.Price(),
				State = function()
					return CardState.Of(controls.Owned(), controls.Selected(), controls.Gems(), controls.Price())
				end,
				Focused = controls.Focused,
				OnFocus = function()
					taps(taps() + 1)
				end,
			}),
		}),

		create("TextLabel")({
			Position = UDim2.fromOffset(0, 120),
			Size = UDim2.fromOffset(120, 20),
			BackgroundTransparency = 1,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				return `OnFocus x{taps()}`
			end,
		}),
	})
end)
