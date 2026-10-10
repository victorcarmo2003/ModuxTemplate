--!strict
-- DrawerValue is a BillboardGui, so it is previewed in the 3D viewport: a temporary part 8 studs in front of the
-- Studio camera (removed when the story closes). "Sell" adds `Sale` to the value and pops "+$N".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local DrawerValue = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const effect = Vide.effect
const untrack = Vide.untrack

type Controls = {
	Start: () -> number,
	Sale: () -> number,
	Sell: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Start = UILabs.Slider(23, 0, 2000, 1),
		Sale = UILabs.Slider(6, 1, 20, 1),
		Sell = false,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__DrawerValueStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Color = Theme.Color.Ink
	anchor.CFrame = camera.CFrame * CFrame.new(0, -2, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const value = source(untrack(controls.Start))
	const pops = source({} :: { DrawerValue.Pop })

	effect(function()
		value(controls.Start())
	end)

	-- Toggle "Sell" (either way) to make one sale.
	local primed = false
	effect(function()
		controls.Sell()
		if not primed then
			primed = true
			return
		end
		const amount = untrack(controls.Sale)
		value(untrack(value) + amount)
		const list = table.clone(untrack(pops))
		table.insert(list, { Amount = amount })
		pops(list)
	end)

	const billboard = DrawerValue({
		Adornee = anchor,
		Value = value,
		Pops = pops,
		OnPopDone = function(pop)
			const list = table.clone(untrack(pops))
			const index = table.find(list, pop)
			if index then
				table.remove(list, index)
				pops(list)
			end
		end,
		Offset = Vector3.new(0, 0.8, 0),
		MaxDistance = 200,
	})
	billboard.Parent = anchor

	return create("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(460, 28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font.Body,
		TextSize = 16,
		TextColor3 = Theme.Color.Text,
		Text = "DrawerValue: see the 3D viewport; toggle Sell to pop +$N",
	})
end)
