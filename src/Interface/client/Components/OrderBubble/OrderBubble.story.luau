--!strict
-- OrderBubble is a BillboardGui, so it is previewed in the 3D viewport: a temporary "head" part 8 studs in front of
-- the Studio camera (removed when the story closes). Tick the toppings (only the first 3 show, DEC-071), drag the
-- patience, turn the ring off (patience unknown, T41), or make it Empty (ANM-001 blank folks: no icon at all).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local OrderBubble = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

type Controls = {
	Ketchup: () -> boolean,
	Mustard: () -> boolean,
	Cheese: () -> boolean,
	Bacon: () -> boolean,
	PotatoSticks: () -> boolean,
	CreamCheese: () -> boolean,
	Ring: () -> boolean,
	Empty: () -> boolean,
	Patience: () -> number,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Ketchup = true,
		Mustard = false,
		Cheese = true,
		Bacon = false,
		PotatoSticks = false,
		CreamCheese = false,
		Ring = true,
		Empty = false,
		Patience = UILabs.Slider(0.8, 0, 1, 0.01),
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

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__OrderBubbleStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Shape = Enum.PartType.Ball
	anchor.Size = Vector3.new(1.4, 1.4, 1.4)
	anchor.Color = Theme.Color.Cream
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const billboard = OrderBubble({
		Adornee = anchor,
		Visible = function()
			return true
		end,
		Toppings = function()
			const list: { OrderBubble.Topping } = {}
			for _, key in Content.Ingredients.ToppingKeys do
				const on = picked[key]
				if on and on() then
					table.insert(list, { Key = key, Icon = Content.Ingredients.ByKey[key].Icon })
				end
			end
			return list
		end,
		Empty = controls.Empty,
		Patience = function()
			return if controls.Ring() then controls.Patience() else -1
		end,
		WarnAt = Content.Moods.Rules.AnnoyedAt,
		Offset = Vector3.new(0, 1.2, 0),
		MaxDistance = 200,
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "OrderBubble: look at the ball in front of the camera",
	})
end)
