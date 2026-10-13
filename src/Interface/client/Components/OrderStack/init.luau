--!strict
-- OrderStack: the order as a stack of layers, read like the hot dog itself (docs/art/prep-ui-spec.md §6.2). From the bottom up: the
-- bun, the sausage, then the toppings of the ticket in the order they were asked (up to Content.OrderRules.MaxToppings = 3, so 5 layers
-- at most). The layers are bands that alternate Cream and a light Mustard, Ink lines between them, inside one rounded Ink frame;
-- each band carries the name of the ingredient and its medallion (the AST-071 icon, a sticker a little bigger than the band).
--   Vertical     (the card, left column) bands stacked, the bun at the BOTTOM of the stack; each band: name on the left, medallion right
--   Horizontal   (the strip, portrait) the same layers side by side, the bun on the left; medallions only
-- Layers with no ingredient are not drawn (the stack is as tall as the order). Sprites of the layers (a zig-zag of sauce, bread, the
-- sausage) come from `Sprites` when the art exists; until then the bands are native Frames. Pure: only props. Build inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Chip = require(script.Parent.IngredientPanel.Chip)
local Sprites = require(script.Sprites)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIListLayout children are fine, UIPadding is not.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Direction = "Vertical" | "Horizontal"

export type Props = {
	-- Ingredient keys that leave the default (bun and sausage are implicit); more than MaxToppings are cut.
	Toppings: () -> { string },
	Direction: Direction?,
	-- Px of one band (its height in Vertical, its width in Horizontal).
	Band: number?,
	Name: string?,
	LayoutOrder: number?,
	Position: UDim2?,
	-- Vertical: width fills the parent (Size X = 1). Horizontal: the height fills the parent.
}

const SLOTS = 2 + Content.OrderRules.MaxToppings
const BAND_A = Theme.Tone.Cream.Top
const BAND_B = Color3.fromHex("#FFE08A")

-- Display names of the ingredients (Content.Ingredients is the one source).
const NAMES: { [string]: string } = {}
for _, row in Content.Ingredients.List do
	NAMES[row.Key] = row.Name
end

-- Key of the layer at `slot` (1 = bun, 2 = sausage, 3.. = the toppings in order), "" = none.
local function keyOf(slot: number, toppings: { string }): string
	if slot == 1 then
		return "bun"
	elseif slot == 2 then
		return "sausage"
	end
	return toppings[slot - 2] or ""
end

-- A holder that shows the medallion of the key the getter returns (a Chip is static, so it is swapped when the key changes).
local function medallion(key: () -> string, side: number, ring: number?): Frame
	-- `ring` = px of the medallion sprite (a Teal ring a little bigger than the band); the icon sits in its middle
	const outer = ring or side
	const holder = create("Frame")({
		Name = "Medallion",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(outer, outer),
		BackgroundTransparency = 1,
		ZIndex = 3,
		create("ImageLabel")({
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Sprites.Medallion,
			ScaleType = Enum.ScaleType.Fit,
			Visible = ring ~= nil,
		}),
	}) :: Frame
	const chipHolder = create("Frame")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}) :: Frame
	chipHolder.Parent = holder
	const shown = Vide.source("")
	local destroyChip: (() -> ())? = nil
	Vide.effect(function()
		const wanted = key()
		if wanted == Vide.untrack(shown) then
			return
		end
		Vide.untrack(function()
			shown(wanted)
			if destroyChip ~= nil then
				destroyChip()
				destroyChip = nil
			end
			chipHolder:ClearAllChildren()
			if wanted ~= "" then
				const destroy, view = Vide.root(function(): Frame
					return Chip({ Key = wanted, Size = side })
				end)
				destroyChip = destroy
				view.Parent = chipHolder
			end
			return nil
		end)
	end)
	Vide.cleanup(function()
		if destroyChip ~= nil then
			destroyChip()
		end
	end)
	return holder
end

return function(props: Props): Frame
	const horizontal = props.Direction == "Horizontal"
	const band = props.Band or 22
	const slots: { any } = {}

	if horizontal then
		table.insert(
			slots,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			})
		)
	else
		table.insert(
			slots,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
		)
	end

	for slot = 1, SLOTS do
		const index = slot
		const key = function(): string
			return keyOf(index, props.Toppings())
		end
		const label = function(): string
			const current = key()
			return NAMES[current] or current
		end
		-- the band picture (a 9-slice, Cream or Mustard) over a flat Frame of the same colour: without the image the stack still reads
		const layer: { any } = {
			create("ImageLabel")({
				Name = "Band",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = if index % 2 == 1 then Sprites.BandCream else Sprites.BandMustard,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Sprites.BandSlice,
				SliceScale = 0.5,
				ZIndex = 1,
			}),
		}
		if horizontal then
			table.insert(layer, medallion(key, band - 12, band - 2))
		else
			-- the layer picture (bread, sausage, a tinted zig-zag of sauce...) fills the band left of the medallion
			table.insert(
				layer,
				create("ImageLabel")({
					Name = "Picture",
					Position = UDim2.fromOffset(2, 2),
					Size = UDim2.new(1, -(band + 6), 1, -4),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 2,
					Image = function(): string
						const sprite = Sprites.Layers[key()]
						return if sprite ~= nil then sprite.Id else ""
					end,
					ImageColor3 = function(): Color3
						const sprite = Sprites.Layers[key()]
						return if sprite ~= nil and sprite.Tint ~= nil then sprite.Tint else Color3.new(1, 1, 1)
					end,
				})
			)
			-- no picture for the key: the name in Ink instead
			table.insert(
				layer,
				CartoonLabel({
					Name = "Name",
					Text = function(): string
						return if Sprites.Layers[key()] == nil then label() else ""
					end,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Truncate = true,
					Position = UDim2.fromOffset(6, 0),
					Box = UDim2.new(1, -(band + 8), 1, 0),
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2,
				})
			)
			table.insert(layer, medallion(key, band - 8, band + 4))
		end
		table.insert(
			slots,
			create("Frame")({
				Name = `Layer{index}`,
				-- vertical: the highest layer first (the bun ends at the bottom); horizontal: the bun first
				LayoutOrder = if horizontal then index else SLOTS + 1 - index,
				Size = if horizontal then UDim2.new(0, band, 1, 0) else UDim2.new(1, 0, 0, band),
				BackgroundColor3 = if index % 2 == 1 then BAND_A else BAND_B,
				BorderSizePixel = 0,
				Visible = function(): boolean
					return key() ~= ""
				end,
				layer,
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "OrderStack",
		LayoutOrder = props.LayoutOrder or 0,
		Position = props.Position or UDim2.new(),
		Size = if horizontal then UDim2.new(0, 0, 1, 0) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		BackgroundColor3 = BAND_A,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		slots,
	}) :: Frame
end
