--!strict
-- HudOrder: tick the toppings (only the first 3 show, DEC-071), drag the patience (Mustard under 1/3), turn the ring
-- off, or make it Empty (ANM-001 blank folks: card with no icon). Phone = 667 x 375 (iPhone SE landscape); the card
-- sits under the money and day pills like in the HUD. Pair (FEAT-038): tick Pair for the 2-row card (2nd hot dog =
-- bacon + potato sticks).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local HudOrder = require(script.Parent)

const create = Vide.create

type Controls = {
	Phone: () -> boolean,
	Shown: () -> boolean,
	Ketchup: () -> boolean,
	Mustard: () -> boolean,
	Cheese: () -> boolean,
	Bacon: () -> boolean,
	PotatoSticks: () -> boolean,
	CreamCheese: () -> boolean,
	Ring: () -> boolean,
	Empty: () -> boolean,
	Patience: () -> number,
	Pair: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Shown = true,
		Ketchup = true,
		Mustard = false,
		Cheese = true,
		Bacon = false,
		PotatoSticks = false,
		CreamCheese = false,
		Ring = true,
		Empty = false,
		Patience = UILabs.Slider(0.8, 0, 1, 0.01),
		Pair = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	const picked: { [string]: () -> boolean } = {
		ketchup = controls.Ketchup,
		mustard = controls.Mustard,
		cheese = controls.Cheese,
		bacon = controls.Bacon,
		potato_sticks = controls.PotatoSticks,
		cream_cheese = controls.CreamCheese,
	}

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,

		HudOrder({
			Shown = controls.Shown,
			Toppings = function()
				const list: { string } = {}
				for _, key in Content.Ingredients.ToppingKeys do
					const on = picked[key]
					if on and on() then
						table.insert(list, key)
					end
				end
				return list
			end,
			Toppings2 = function(): { string }?
				return if controls.Pair() then { "bacon", "potato_sticks" } else nil
			end,
			Empty = controls.Empty,
			Patience = function()
				return if controls.Ring() then controls.Patience() else -1
			end,
			WarnAt = Content.Moods.Rules.AnnoyedAt,
			Position = UDim2.fromOffset(12, 114),
		}),
	})
end)
