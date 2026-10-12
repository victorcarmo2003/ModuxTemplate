--!strict
-- IngredientPanel/Chip: the picture of one ingredient (the AST-071 icon `Ingredient/<key>` of the shared sheet, kept in
-- Icons) with a flat Frame fallback (food colour + three letters, never red as a UI state) for a key without an icon.
-- Used by the ingredient boxes, the ticket and the plate. Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Key: string,
	-- Side in px.
	Size: number,
	-- Drawn at half strength (disabled, locked).
	Dim: (() -> boolean)?,
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

-- Food colours of the fallback (a picture of the food, not a UI state).
const FOOD: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF1D6"),
	cheese = Color3.fromHex("#FFC64D"),
	bacon = Color3.fromHex("#C8553D"),
	potato_sticks = Color3.fromHex("#E8C26A"),
	bun = Color3.fromHex("#E9B872"),
	sausage = Color3.fromHex("#D9826B"),
}

-- Short names of the fallback and of the story.
const SHORT: { [string]: string } = {
	ketchup = "KET",
	mustard = "MUS",
	cream_cheese = "CRM",
	cheese = "CHE",
	bacon = "BAC",
	potato_sticks = "POT",
	bun = "BUN",
	sausage = "SAU",
}

local function shortName(key: string): string
	return SHORT[key] or string.upper(string.sub(key, 1, 3))
end

return function(props: Props): Frame
	const name = `Ingredient/{props.Key}`
	const has = Icons.Has(name)
	const rect = Icons.Rect(name) or { Offset = Vector2.zero, Size = Vector2.zero }
	const dim = props.Dim
	const fade = function(): number
		return if dim ~= nil and dim() then 0.55 else 0
	end
	const children: { any } = {}
	if has then
		table.insert(
			children,
			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = Icons.ImageOf(name),
				ImageRectOffset = rect.Offset,
				ImageRectSize = rect.Size,
				ImageTransparency = fade,
			})
		)
	else
		table.insert(
			children,
			create("Frame")({
				Name = "Fallback",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.86, 0.86),
				BackgroundColor3 = FOOD[props.Key] or Theme.Tone.Slate.Bottom,
				BackgroundTransparency = fade,
				create("UICorner")({ CornerRadius = Theme.Radius.Chip }),
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = 2,
					Transparency = fade,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				CartoonLabel({
					Text = shortName(props.Key),
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = UDim2.fromScale(1, 1),
					XAlignment = Enum.TextXAlignment.Center,
					YAlignment = Enum.TextYAlignment.Center,
					Transparency = fade,
				}),
			})
		)
	end
	return create("Frame")({
		Name = props.Name or "IngredientChip",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(props.Size, props.Size),
		BackgroundTransparency = 1,
		children,
	})
end
