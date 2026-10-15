--!strict
-- GearButton: the round settings button of the HUD (TASK-279; owner request 2026-10-14, Provisional), cartoon kit.
-- An Ink CartoonButton with a Cream gear (Mustard face and Ink gear while the panel is open). The gear is native: four bars
-- at 0/45/90/135 deg make the eight teeth, a round body over them and a hole (no image asset; crisp at any UI scale). It
-- turns an eighth of a turn when the panel opens (spring; Motion.Reduced: it just snaps).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- px at UI scale 1 (square), a value or a source (e.g. bigger on touch). Default Theme.MinTouch.
	Size: (number | () -> number)?,
	-- The panel is open (Mustard face, gear turned). nil = never.
	Open: (() -> boolean)?,
	OnActivated: () -> (),
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Visible: (() -> boolean)?,
}

const TEETH_BARS = 4
const TOOTH = 0.26 -- tooth width, share of the gear size
const BODY = 0.72 -- round body, share of the gear size
const HOLE = 0.3
const TURN = 45 -- degrees the gear turns when open

-- Native gear of `size` px: `color` teeth and body, `hole` centre.
local function gear(size: number, color: () -> Color3, hole: () -> Color3, rotation: () -> number): Frame
	const children: { any } = {}
	for i = 0, TEETH_BARS - 1 do
		table.insert(
			children,
			create("Frame")({
				Name = `Teeth{i}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(size, math.floor(size * TOOTH + 0.5)),
				Rotation = i * (180 / TEETH_BARS),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = UDim.new(0, 2) }),
			})
		)
	end
	table.insert(
		children,
		create("Frame")({
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(BODY, BODY),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	)
	table.insert(
		children,
		create("Frame")({
			Name = "Hole",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(HOLE, HOLE),
			BackgroundColor3 = hole,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	)

	return create("Frame")({
		Name = "Gear",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = rotation,
		children,
	}) :: Frame
end

return function(props: Props): TextButton
	-- the drawing is made at the first size and follows later sizes with a UIScale
	const sizeProp = props.Size
	const current = function(): number
		if type(sizeProp) == "function" then
			return sizeProp()
		end
		return sizeProp or Theme.MinTouch
	end
	const size = Vide.untrack(current)
	const open = function(): boolean
		return if props.Open then props.Open() else false
	end
	const target = function(): number
		return if open() then TURN else 0
	end
	const rotation: () -> number = if Motion.Reduced() then target else spring(target, 0.25, 0.6)

	return CartoonButton({
		Name = props.Name or "GearButton",
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = function()
			const now = current()
			return UDim2.fromOffset(now, now)
		end,
		Visible = props.Visible,
		Tone = function(): Theme.Tone
			return if open() then Theme.Tone.Mustard else Theme.Tone.Ink
		end,
		OnActivated = props.OnActivated,
		Children = {
			create("Frame")({
				Name = "Holder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				createRaw("UIScale")({
					Scale = function()
						return current() / size
					end,
				}),
				gear(math.floor(size * 0.62), function()
					return if open() then Theme.Color.Ink else Theme.Color.Cream
				end, function()
					return if open() then Theme.Color.Mustard else Theme.Color.Ink
				end, rotation),
			}),
		},
	}) :: TextButton
end
