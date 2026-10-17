--!strict
-- InteractionMenu on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport. Controls: device
-- (Touch = action circle + fan above the jump button, KeyboardMouse / Gamepad = compact column right of the crosshair),
-- number of options (1..4, the real menu caps at 4), selected option, an option out of reach (dimmed), hold on the
-- selected option (ring / row fill), the refuse hint (desktop footer) and a "Done" counter to see the pop. With Tappable
-- on (always on Touch), click the circle or an option (hold = ring) to see OnSelect / OnPress / OnRelease move the selection.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local InteractionMenu = require(script.Parent)

const create = Vide.create
const source = Vide.source
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

type Controls = {
	PhoneFrame: () -> boolean,
	Count: () -> number,
	Device: () -> string,
	Selected: () -> number,
	DimmedRow: () -> number,
	Holding: () -> boolean,
	HoldDuration: () -> number,
	Done: () -> number,
	Tappable: () -> boolean,
	Visible: () -> boolean,
}

const SAMPLES = {
	{ "Take Order", "Ui/megaphone", "Order" },
	{ "Collect Cash", "Ui/cash", "Collect" },
	{ "Add Ketchup", "Ingredient/ketchup", "Ketchup" },
	{ "Buy Hot Dog Buns — $4", "Item/pack_buns", "Buy $4" },
	{ "Open Window", "Ui/bell", "Window" },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		PhoneFrame = true,
		Count = UILabs.Slider(3, 1, 4, 1),
		Device = UILabs.Choose({ "Touch", "KeyboardMouse", "Gamepad" }),
		Selected = UILabs.Slider(1, 1, 4, 1),
		DimmedRow = UILabs.Slider(0, 0, 4, 1), -- 0 = none
		Holding = false,
		HoldDuration = UILabs.Slider(1, 0.2, 3, 0.1),
		Done = UILabs.Slider(0, 0, 50, 1),
		Tappable = true,
		Visible = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)
	-- Selection moved by the rows themselves (tap): wins until the slider moves again
	const picked = source(0)
	const pressedRow = source(0)
	Vide.effect(function()
		controls.Selected()
		picked(0)
	end)

	-- One stable table per sample, like PromptController keeps one per prompt
	const pool: { InteractionMenu.Item } = {}
	for index, sample in SAMPLES do
		const text, icon, short = sample[1], sample[2], sample[3]
		table.insert(pool, {
			Text = function()
				return text
			end,
			Short = function()
				return short
			end,
			Icon = function()
				return icon
			end,
			Holding = function()
				return pressedRow() == index or (controls.Holding() and controls.Selected() == index)
			end,
			HoldDuration = controls.HoldDuration,
			Done = controls.Done,
			Enabled = function()
				return controls.DimmedRow() ~= index
			end,
			Hint = function()
				return ""
			end,
		})
	end

	const items = function(): { InteractionMenu.Item }
		const list: { InteractionMenu.Item } = {}
		for index = 1, math.min(controls.Count(), #pool) do
			table.insert(list, pool[index])
		end
		return list
	end
	const selected = function(): InteractionMenu.Item?
		const index = if picked() > 0 then picked() else controls.Selected()
		return pool[math.min(index, controls.Count())]
	end
	const indexOf = function(item: InteractionMenu.Item): number
		return table.find(pool, item) or 0
	end

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		create("Frame")({
			Name = "Screen",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				return if controls.PhoneFrame() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
			end,
			BackgroundColor3 = Color3.fromHex("#1B2440"),
			ClipsDescendants = true,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),

			-- Crosshair: the column sits to its right, the circle and fan stay far from it
			create("Frame")({
				Name = "Crosshair",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = Theme.Color.Text,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),

			InteractionMenu({
				Items = items,
				Selected = selected,
				Visible = controls.Visible,
				Device = function()
					return controls.Device() :: any
				end,
				Tappable = function()
					return controls.Tappable() or controls.Device() == "Touch"
				end,
				Scale = function()
					return 1
				end,
				OnSelect = function(item)
					picked(indexOf(item))
				end,
				OnPress = function(item)
					pressedRow(indexOf(item))
				end,
				OnRelease = function(_item)
					pressedRow(0)
				end,
			}),
		}),
	})
end)
