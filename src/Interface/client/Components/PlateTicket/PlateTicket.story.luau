--!strict
-- PlateTicket is a BillboardGui, so it is previewed in the 3D viewport: a flat plate 12 studs in front of the Studio camera
-- (removed when the story closes). Pick the order (K = 0..3), what is on the plate, drag the patience (under 0.25 = urgent:
-- Ink ring blinking + "!"), and flip Oldest (tab pulse), Orphan (grey "?") and Empty (ANM-001).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local PlateTicket = require(script.Parent)

const cleanup = Vide.cleanup

type Controls = {
	Number: () -> number,
	Order: () -> string,
	Bun: () -> boolean,
	Sausage: () -> boolean,
	Toppings: () -> boolean,
	Patience: () -> number,
	Oldest: () -> boolean,
	Orphan: () -> boolean,
	Empty: () -> boolean,
	Shown: () -> boolean,
}

const ORDERS: { [string]: { string } } = {
	["K0 plain"] = {},
	["K1 ketchup"] = { "ketchup" },
	["K2 mustard + cheese"] = { "mustard", "cheese" },
	["K3 ketchup + bacon + potato sticks"] = { "ketchup", "bacon", "potato_sticks" },
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Number = UILabs.Slider(12, 1, 99, 1),
		Order = UILabs.Choose({ "K0 plain", "K1 ketchup", "K2 mustard + cheese", "K3 ketchup + bacon + potato sticks" }),
		Bun = true,
		Sausage = false,
		Toppings = false,
		Patience = UILabs.Slider(0.7, -0.1, 1, 0.01),
		Oldest = false,
		Orphan = false,
		Empty = false,
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const camera = workspace.CurrentCamera
	const plate = Instance.new("Part")
	plate.Name = "__PlateTicketStory"
	plate.Anchored = true
	plate.CanCollide = false
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(0.2, 2.4, 2.4)
	plate.Color = Theme.Color.Cream
	plate.Transparency = 0.5
	plate.CFrame = camera.CFrame * CFrame.new(0, -3, -12) * CFrame.Angles(0, 0, math.rad(90))
	plate.Parent = workspace
	cleanup(plate)

	local function toppings(): { string }
		return ORDERS[controls.Order()] or {}
	end

	const ticket = PlateTicket({
		Adornee = plate,
		Visible = controls.Shown,
		Number = function(): number?
			return controls.Number()
		end,
		Toppings = toppings,
		Done = function()
			const done: { [string]: boolean } = { bun = controls.Bun(), sausage = controls.Sausage() }
			if controls.Toppings() then
				for _, key in toppings() do
					done[key] = true
				end
			end
			return done
		end,
		Patience = controls.Patience,
		Oldest = controls.Oldest,
		Orphan = controls.Orphan,
		Empty = controls.Empty,
		StudsOffset = Vector3.new(0, 1.6, 0),
	})
	ticket.Parent = plate
	cleanup(ticket)

	return Vide.create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
end)
