--!strict
-- OrderBoard: flat preview of the board plus the real SurfaceGui on a temporary strip 9 studs in front of the Studio
-- camera (removed when the story closes). Drag Orders past what fits to see the cards shrink and the "+k" card;
-- Plates = the restaurant flow (missing items faded), off = the trailer flow (no plate, icons full).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local OrderBoard = require(script.Parent)

const create = Vide.create
const cleanup = Vide.cleanup

const PIXELS_PER_STUD = 100
const TOPPINGS = { "ketchup", "mustard", "cheese", "bacon", "potato_sticks", "cream_cheese" }
const STATES: { OrderBoard.CardState } = { "Ready", "Preparing", "Preparing", "Queued" }

type Controls = {
	Orders: () -> number,
	Pair: () -> boolean,
	Plates: () -> boolean,
	Patience: () -> number,
	Width: () -> number,
	Height: () -> number,
}

-- A fake order i: 0..3 toppings, the state and plate progress follow the age (oldest = most done).
local function cardOf(index: number, pair: boolean, plates: boolean, patience: number): OrderBoard.Card
	const state = STATES[math.min(index, #STATES)]
	local function row(seed: number): { OrderBoard.Item }
		const list: { OrderBoard.Item } = {
			{ Key = "bun", Done = if plates then state ~= "Queued" else nil },
			{ Key = "sausage", Done = if plates then state == "Ready" or seed % 2 == 0 else nil },
		}
		for k = 1, seed % 4 do
			table.insert(list, {
				Key = TOPPINGS[(seed + k) % #TOPPINGS + 1],
				Done = if plates then state == "Ready" else nil,
			})
		end
		return list
	end
	const rows = { row(index) }
	if pair and index == 2 then
		table.insert(rows, row(index + 1))
	end
	-- the oldest has the least patience left
	const left = math.clamp(patience - (5 - math.min(index, 5)) * 0.12, 0, 1)
	return {
		Id = index,
		Number = 10 + index,
		Rows = rows,
		State = state,
		Patience = left,
		Urgent = left <= 0.25,
	}
end

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Orders = UILabs.Slider(4, 0, 14, 1),
		Pair = true,
		Plates = true,
		Patience = UILabs.Slider(0.9, 0, 1, 0.05),
		Width = UILabs.Slider(8, 3, 14, 0.5),
		Height = UILabs.Slider(1.6, 0.8, 3, 0.1),
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	local function cards(): { OrderBoard.Card }
		const list: { OrderBoard.Card } = {}
		for index = 1, controls.Orders() do
			table.insert(list, cardOf(index, controls.Pair(), controls.Plates(), controls.Patience()))
		end
		return list
	end
	local function canvas(): Vector2
		return Vector2.new(controls.Width(), controls.Height()) * PIXELS_PER_STUD
	end

	const camera = workspace.CurrentCamera
	const strip = Instance.new("Part")
	strip.Name = "__OrderBoardStory"
	strip.Anchored = true
	strip.CanCollide = false
	strip.Size = Vector3.new(8, 1.6, 0.1)
	strip.Color = Color3.fromHex("#2B2233")
	-- Same orientation as the camera: the strip's Back face (+Z) looks at it.
	strip.CFrame = camera.CFrame * CFrame.new(0, 0, -9)
	strip.Parent = workspace
	cleanup(strip)

	Vide.effect(function()
		strip.Size = Vector3.new(controls.Width(), controls.Height(), 0.1)
	end)

	const world = OrderBoard({
		Adornee = strip,
		Face = Enum.NormalId.Back,
		PixelsPerStud = PIXELS_PER_STUD,
		Cards = cards,
		CanvasSize = canvas,
	})
	world.Parent = strip

	-- flat copy for the 2D canvas: the Board frame, sized like the canvas
	const flat = OrderBoard({ Cards = cards, CanvasSize = canvas })
	const body = flat:FindFirstChild("Board") :: Frame
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	Vide.effect(function()
		const size = canvas()
		body.Size = UDim2.fromOffset(size.X, size.Y)
	end)
	cleanup(flat)

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		body,
	})
end)
