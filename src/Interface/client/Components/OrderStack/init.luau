--!strict
-- OrderStack: the order as a small hot dog built layer by layer (docs/art/prep-ui-spec.md §6.2). From the bottom up: the bun (base), the
-- sausage, the toppings of the ticket in the order they were asked (Content.OrderRules.MaxToppings = 3) and the lid of the bun when
-- there is room (with 0 to 2 toppings): with no topping the lid is pulled over the sausage, in front of it, so the bun hugs it.
--   Vertical     (the card) the layers are pictures (Sprites) a little bigger than their band and overlapping the neighbours; behind them
--                alternate Cream and a clear Mustard bands inside one rounded Ink frame, an Ink line of 2 px between them; a column of
--                small medallions on the right (the AST-071 icon on a Teal ring), each joined to its layer by a short line
--   Horizontal   (the strip, portrait) the same layers side by side, the medallion as a small chip on the corner of each
-- Layers with no ingredient are not drawn; a layer that appears pops in with a spring. Top anchored: the stack is as tall as the order.
-- Sprites (docs/art/ticket-sprites.md) have a native fallback: without the image the bands and the medallions still read.
-- Pure: only props. Build inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local Motion = require(script.Parent.Motion)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Chip = require(script.Parent.IngredientPanel.Chip)
local Sprites = require(script.Sprites)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Direction = "Vertical" | "Horizontal"

export type Props = {
	-- Ingredient keys that leave the default (bun and sausage are implicit); more than MaxToppings are cut.
	Toppings: () -> { string },
	Direction: Direction?,
	-- Vertical: px between two layers (the height of a band). Horizontal: the width of a layer. Default 18.
	Pitch: number?,
	-- Px of a layer picture (its height, vertical; the square it fits, horizontal). Default 26.
	Sprite: number?,
	-- Px of a medallion (vertical). Default 22.
	Medallion: number?,
	Name: string?,
	LayoutOrder: number?,
}

type Item = { Kind: string, Key: string }

const SLOTS = 3 + Content.OrderRules.MaxToppings
const CREAM = Color3.fromHex("#FFFBF0")
const MUSTARD = Color3.fromHex("#FFDF70")

-- Display names of the ingredients, for a layer with no picture (Content.Ingredients is the one source).
const NAMES: { [string]: string } = {}
for _, row in Content.Ingredients.List do
	NAMES[row.Key] = row.Name
end

-- The layers of an order, bottom first.
local function itemsOf(toppings: { string }): { Item }
	const list: { Item } = { { Kind = "base", Key = "bun" }, { Kind = "sausage", Key = "sausage" } }
	for index = 1, math.min(#toppings, Content.OrderRules.MaxToppings) do
		table.insert(list, { Kind = "topping", Key = toppings[index] })
	end
	-- the lid closes the stack while there is room for it (0 to 2 toppings)
	if #list <= 4 then
		table.insert(list, { Kind = "lid", Key = "bun_lid" })
	end
	return list
end

-- A Teal ring with the icon of an ingredient inside; the icon is swapped when the key changes (a Chip is static).
local function medallion(key: () -> string, side: number, position: () -> UDim2, popScale: () -> number, order: number): Frame
	const holder = create("Frame")({
		Name = "Medallion",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(side, side),
		BackgroundTransparency = 1,
		ZIndex = order,
		Visible = function(): boolean
			return key() ~= ""
		end,
		create("ImageLabel")({
			Name = "Ring",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Sprites.Medallion,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = order,
		}),
		createRaw("UIScale")({
			Scale = function(): number
				return math.max(popScale(), 0.01)
			end,
		}),
	}) :: Frame
	const icon = math.floor(side * 0.64)
	const chipHolder = create("Frame")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(icon, icon),
		BackgroundTransparency = 1,
		ZIndex = order + 1,
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
					return Chip({ Key = wanted, Size = icon })
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
	const pitch = props.Pitch or 18
	const sprite = props.Sprite or 26
	const medal = props.Medallion or 22
	-- the room a picture takes over its band, split above and below
	const inset = math.max(sprite - pitch, 0) / 2

	const items = function(): { Item }
		return itemsOf(props.Toppings())
	end
	const count = function(): number
		return #items()
	end

	-- the bands: behind the pictures, clipped by one rounded Ink frame
	const bands: { any } = {}
	-- the pictures and medallions: over the bands, free to overlap the edge of their band
	const pictures: { any } = {}

	for slot = 1, SLOTS do
		const index = slot
		const item = function(): Item?
			return items()[index]
		end
		const key = function(): string
			const current = item()
			return if current ~= nil then current.Key else ""
		end
		const kind = function(): string
			const current = item()
			return if current ~= nil then current.Kind else ""
		end
		-- 0 at the top; the layer at the top of the stack is the last of the list
		const fromTop = function(): number
			return count() - index
		end
		const present = function(): boolean
			return key() ~= ""
		end
		const pop = Motion.Pop(present)
		const visible = function(): boolean
			return present() or pop() > 0.02
		end
		const spriteOf = function(): Sprites.Layer?
			return Sprites.Layers[key()]
		end

		-- the band
		table.insert(
			bands,
			create("Frame")({
				Name = `Band{index}`,
				Position = function(): UDim2
					return if horizontal then UDim2.new(0, (index - 1) * pitch, 0, 0) else UDim2.new(0, 0, 0, fromTop() * pitch)
				end,
				Size = if horizontal then UDim2.new(0, pitch, 1, 0) else UDim2.new(1, 0, 0, pitch),
				BackgroundColor3 = if index % 2 == 1 then CREAM else MUSTARD,
				BorderSizePixel = 0,
				Visible = present,
				-- the 2 px Ink line between two layers (not over the outer edge)
				create("Frame")({
					Name = "Divider",
					Size = if horizontal then UDim2.new(0, 2, 1, 0) else UDim2.new(1, 0, 0, 2),
					BackgroundColor3 = Theme.Color.Ink,
					BorderSizePixel = 0,
					Visible = index > 1,
				}),
			})
		)

		-- the picture: centred on its band; a lid is pulled down over the layer below
		const lift = function(): number
			if kind() ~= "lid" then
				return 0
			end
			return if count() <= 3 then -math.floor(sprite * 0.34) else -math.floor(sprite * 0.12)
		end
		const bandCenter = function(): number
			return inset + fromTop() * pitch + pitch / 2
		end
		table.insert(
			pictures,
			create("ImageLabel")({
				Name = `Layer{index}`,
				-- centred in its box (left edge 6 px in the vertical stack): the pop grows from the middle
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = function(): UDim2
					if horizontal then
						return UDim2.new(0, (index - 1) * pitch + pitch / 2, 0.5, 0)
					end
					return UDim2.new(0.5, 6 - (medal + 18) / 2, 0, bandCenter() + lift())
				end,
				Size = if horizontal then UDim2.fromOffset(pitch - 2, sprite) else UDim2.new(1, -(medal + 18), 0, sprite),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2 + index,
				Visible = visible,
				Image = function(): string
					const found = spriteOf()
					return if found ~= nil then found.Id else ""
				end,
				ImageColor3 = function(): Color3
					const found = spriteOf()
					return if found ~= nil and found.Tint ~= nil then found.Tint else Color3.new(1, 1, 1)
				end,
				createRaw("UIScale")({
					Scale = function(): number
						return math.max(pop(), 0.01)
					end,
				}),
			})
		)
		-- no picture for the key: the name in Ink on the band
		if not horizontal then
			table.insert(
				pictures,
				CartoonLabel({
					Name = `Name{index}`,
					Text = function(): string
						return if present() and spriteOf() == nil then (NAMES[key()] or key()) else ""
					end,
					TextSize = Theme.MinTextSize,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Truncate = true,
					Position = function(): UDim2
						return UDim2.fromOffset(8, inset + fromTop() * pitch)
					end,
					Box = UDim2.new(1, -(medal + 20), 0, pitch),
					XAlignment = Enum.TextXAlignment.Left,
					YAlignment = Enum.TextYAlignment.Center,
					ZIndex = 2 + index,
				})
			)
		end

		-- the medallion (not for the lid: the bun is already said by its base)
		const medalKey = function(): string
			return if kind() == "lid" then "" else key()
		end
		if horizontal then
			table.insert(
				pictures,
				medallion(medalKey, 16, function(): UDim2
					return UDim2.new(0, (index - 1) * pitch + pitch - 9, 1, -6)
				end, pop, 20 + index * 2)
			)
		else
			-- the short line that joins the layer to its medallion
			table.insert(
				pictures,
				create("Frame")({
					Name = `Guide{index}`,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = function(): UDim2
						return UDim2.new(1, -(5 + medal), 0, bandCenter())
					end,
					Size = UDim2.fromOffset(6, 2),
					BackgroundColor3 = Theme.Color.Ink,
					BorderSizePixel = 0,
					ZIndex = 2,
					Visible = function(): boolean
						return present() and kind() ~= "lid"
					end,
				})
			)
			table.insert(
				pictures,
				medallion(medalKey, medal, function(): UDim2
					return UDim2.new(1, -(5 + medal / 2), 0, bandCenter())
				end, pop, 20 + index * 2)
			)
		end
	end

	return create("Frame")({
		Name = props.Name or "OrderStack",
		LayoutOrder = props.LayoutOrder or 0,
		Size = if horizontal
			then function(): UDim2
				return UDim2.fromOffset(count() * pitch, sprite + 8)
			end
			else function(): UDim2
				return UDim2.new(1, 0, 0, count() * pitch + inset * 2)
			end,
		BackgroundTransparency = 1,
		-- the bands: one rounded Ink frame
		create("Frame")({
			Name = "Bands",
			Position = UDim2.fromOffset(0, if horizontal then 4 else inset),
			Size = if horizontal
				then function(): UDim2
					return UDim2.fromOffset(count() * pitch, sprite)
				end
				else function(): UDim2
					return UDim2.new(1, 0, 0, count() * pitch)
				end,
			BackgroundColor3 = CREAM,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			bands,
		}),
		pictures,
	}) :: Frame
end
