--!strict
-- CartButton: the shop button of the HUD (TASK-290; owner request 2026-10-14, Provisional), twin of GearButton: an Ink
-- CartoonButton with a Cream shopping cart (Mustard face and Ink cart while the shop is open). The cart is native: a
-- rounded basket with two slats, one diagonal handle stroke on its top left, two round wheels
-- (no image asset; crisp at any UI scale). It hops a little when the shop opens (spring; Motion.Reduced: no hop).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- px at UI scale 1 (square), a value or a source (e.g. bigger on touch). Default Theme.MinTouch.
	Size: (number | () -> number)?,
	-- The shop is open (Mustard face). nil = never.
	Open: (() -> boolean)?,
	-- Glow ring (e.g. the nudge points at it). nil = never.
	Glow: (() -> boolean)?,
	OnActivated: () -> (),
	Name: string?,
	LayoutOrder: number?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Visible: (() -> boolean)?,
}

const HOP = 3 -- px the cart rises when open

local function bar(name: string, position: UDim2, size: UDim2, color: () -> Color3, rotation: number?): Frame
	return create("Frame")({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
end

-- Native cart of `size` px: `color` body, `hole` slats.
local function cart(size: number, color: () -> Color3, hole: () -> Color3, lift: () -> number): Frame
	const stroke = math.max(math.floor(size * 0.12 + 0.5), 2)
	return create("Frame")({
		Name = "Cart",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			return UDim2.new(0.5, 0, 0.5, -lift())
		end,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,

		-- handle: one diagonal stroke from the top left down to the basket
		bar("Handle", UDim2.fromScale(0.2, 0.26), UDim2.fromOffset(math.floor(size * 0.38), stroke), color, 55),

		-- basket
		create("Frame")({
			Name = "Basket",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.58, 0.48),
			Size = UDim2.fromScale(0.7, 0.42),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
			bar("Slat1", UDim2.fromScale(0.36, 0.5), UDim2.new(0, math.max(stroke - 1, 2), 0.55, 0), hole),
			bar("Slat2", UDim2.fromScale(0.64, 0.5), UDim2.new(0, math.max(stroke - 1, 2), 0.55, 0), hole),
		}),

		-- wheels
		bar("WheelL", UDim2.fromScale(0.38, 0.86), UDim2.fromOffset(stroke * 2, stroke * 2), color),
		bar("WheelR", UDim2.fromScale(0.8, 0.86), UDim2.fromOffset(stroke * 2, stroke * 2), color),
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
		return if open() then HOP else 0
	end
	const lift: () -> number = if Motion.Reduced() then function()
		return 0
	end else spring(target, 0.2, 0.5)

	return CartoonButton({
		Name = props.Name or "CartButton",
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
				cart(math.floor(size * 0.66), function()
					return if open() then Theme.Color.Ink else Theme.Color.Cream
				end, function()
					return if open() then Theme.Color.Mustard else Theme.Color.Ink
				end, lift),
				-- glow ring while something points at the shop (the nudge)
				create("Frame")({
					Name = "Glow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 6, 1, 6),
					BackgroundTransparency = 1,
					Visible = function()
						return if props.Glow then props.Glow() else false
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Mustard, Thickness = 3 }),
				}),
			}),
		},
	}) :: TextButton
end
