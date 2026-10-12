--!strict
-- IngredientPanel: the topping boxes of the Build tab in the focused prep mode (docs/art/prep-ui-spec.md §5.3, §6.3).
-- A grid of boxes (2 x 3 on a phone landscape / desktop, 3 x 2 in portrait; the PrepShell layout gives Cols / Rows / Box)
-- in the order of Content.Ingredients.ToppingKeys (never reordered). Each box: the ingredient picture, a stock chip in the
-- corner and a state read from `Info(key)` (all reactive):
--   normal      Cream, tap = OnPick(key); also grabbable by a drag (attribute `PrepGrab` = key, read by the PrepController)
--   used        already on this plate: a Green check, not pickable again (no repeats)
--   full        the plate has all its toppings: Slate, picture at half strength
--   no stock    Slate, a diagonal bar and the chip "0"
--   locked      Slate and a padlock (a day that has not come)
--   low stock   (1..2 left) a Mustard diamond with "!" next to the number (shape, not red)
--   refused     a short shake (Refused source changes: the owner got a "no" from the server)
-- The legend line in the header shows the name and the stock of the focused box ("Ketchup . 12 left").
-- Placeholder-ready: boxes are flat CartoonPanels; the picture is the Icons sheet or the Frame fallback of Chip.
-- Pure: only props, no network. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Chip = require(script.Chip)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIGridLayout, UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Info = {
	Stock: number,
	Locked: boolean,
	Used: boolean,
}

export type Props = {
	-- Keys in box order. Default Content.Ingredients.ToppingKeys.
	Keys: { string }?,
	-- State of a box, read inside a reactive scope.
	Info: (key: string) -> Info,
	Cols: () -> number,
	Rows: () -> number,
	-- Side of a box in px (64 on a phone, 72 on desktop).
	Box: () -> number,
	-- The plate has all its toppings (Content.OrderRules.MaxToppings).
	Full: () -> boolean,
	-- The whole panel is not usable now (another step).
	Disabled: (() -> boolean)?,
	OnPick: (key: string) -> (),
	-- Box in focus (gamepad selection, last pick), "" = none; its name and stock go to the header.
	Focus: Vide.Source<string>?,
	-- {Key, Id}: a pick the server refused; the box shakes once per new Id.
	Refused: (() -> { Key: string, Id: number }?)?,
	Title: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Name: string?,
}

const HEADER = 22
const LOW_STOCK = 2
const SHAKE = 0.18

local function nameOf(key: string): string
	const row = Content.Ingredients.ByKey[key]
	return if row ~= nil then row.Name else key
end

-- One box. `pickable` = a tap or a drag may take it now.
local function box(props: Props, key: string, order: number): Instance
	const info = function(): Info
		return props.Info(key)
	end
	const pickable = function(): boolean
		const state = info()
		if state.Locked or state.Used or state.Stock <= 0 then
			return false
		end
		if props.Full() or (props.Disabled ~= nil and props.Disabled()) then
			return false
		end
		return true
	end
	-- Used boxes keep the Cream face (and a check); the other unusable ones go Slate through Enabled = false.
	const enabled = function(): boolean
		return pickable() or info().Used
	end
	const size = function(): UDim2
		const side = props.Box()
		return UDim2.fromOffset(side, side)
	end

	-- shake on a refused pick: the offset runs out in SHAKE s
	const shake = source(0)
	local lastRefusal = 0
	effect(function()
		const refused = if props.Refused ~= nil then props.Refused() else nil
		if refused ~= nil and refused.Key == key and refused.Id ~= lastRefusal then
			lastRefusal = refused.Id
			task.spawn(function()
				const start = os.clock()
				while true do
					const t = (os.clock() - start) / SHAKE
					if t >= 1 then
						break
					end
					shake(math.sin(t * math.pi * 6) * 3 * (1 - t))
					task.wait()
				end
				shake(0)
			end)
		end
	end)

	const picture = Chip({
		Key = key,
		Size = 40,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Dim = function()
			return not pickable() and not info().Used
		end,
	})
	-- the picture scales with the box (40 of 64)
	picture.Size = UDim2.fromScale(0.64, 0.64)

	const stock = CartoonPanel({
		Name = "Stock",
		Tone = Theme.Tone.White,
		Radius = Theme.Radius.Small,
		Lip = 2,
		Outline = 2,
		Gloss = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(24, 20),
		Visible = function()
			return not info().Locked
		end,
		Children = {
			CartoonLabel({
				Text = function()
					return tostring(math.max(info().Stock, 0))
				end,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})

	-- low stock: a Mustard diamond with "!" (a shape, not a colour alone)
	const low = create("Frame")({
		Name = "Low",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 14, 0, 14),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Theme.Color.Mustard,
		Visible = function()
			const state = info()
			return not state.Locked and state.Stock > 0 and state.Stock <= LOW_STOCK
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		CartoonLabel({
			Text = "!",
			TextSize = Theme.MinTextSize,
			Color = Theme.Color.Ink,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			XAlignment = Enum.TextXAlignment.Center,
			YAlignment = Enum.TextYAlignment.Center,
			Rotation = -45,
		}),
	})

	-- no stock: a diagonal Ink bar across the box
	const bar = create("Frame")({
		Name = "NoStock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1.1, 0, 0, 4),
		Rotation = -35,
		BackgroundColor3 = Theme.Color.Ink,
		BorderSizePixel = 0,
		Visible = function()
			const state = info()
			return not state.Locked and not state.Used and state.Stock <= 0
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
	})

	-- used: a Green check disc in the lower corner
	const used = create("Frame")({
		Name = "Used",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -7),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Tone.Green.Bottom,
		Visible = function()
			return info().Used
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.36, 0.56),
			Size = UDim2.fromOffset(3, 7),
			Rotation = -45,
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
		}),
		create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.55, 0.46),
			Size = UDim2.fromOffset(3, 12),
			Rotation = 40,
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
		}),
	})

	-- locked: a padlock (the Notice/lock icon when the sheet has it)
	const lockName = "Notice/lock"
	const lockRect = Icons.Rect(lockName) or { Offset = Vector2.zero, Size = Vector2.zero }
	const lock = create("Frame")({
		Name = "Locked",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Visible = function()
			return info().Locked
		end,
		create("ImageLabel")({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Icons.ImageOf(lockName),
			ImageRectOffset = lockRect.Offset,
			ImageRectSize = lockRect.Size,
			Visible = Icons.Has(lockName),
		}),
		create("Frame")({
			Name = "Body",
			Position = UDim2.fromScale(0.15, 0.45),
			Size = UDim2.fromScale(0.7, 0.5),
			BackgroundColor3 = Theme.Color.Ink,
			Visible = not Icons.Has(lockName),
			create("UICorner")({ CornerRadius = UDim.new(0, 4) }),
		}),
		create("Frame")({
			Name = "Shackle",
			Position = UDim2.fromScale(0.28, 0.08),
			Size = UDim2.fromScale(0.44, 0.5),
			BackgroundTransparency = 1,
			Visible = not Icons.Has(lockName),
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	})

	const button = CartoonButton({
		Name = `Box_{key}`,
		LayoutOrder = order,
		Tone = Theme.Tone.Cream,
		Enabled = enabled,
		Size = size,
		Radius = Theme.Radius.Chip,
		Outline = function()
			return if props.Focus ~= nil and props.Focus() == key then Theme.Outline.Thick else Theme.Outline.Normal
		end,
		OutlineColor = Theme.Color.Ink,
		OnActivated = function()
			if pickable() then
				if props.Focus ~= nil then
					props.Focus(key)
				end
				props.OnPick(key)
			end
		end,
		SelectionGained = function()
			if props.Focus ~= nil then
				props.Focus(key)
			end
		end,
		Children = { picture, stock, low, bar, used, lock },
		Padding = 0,
	})
	button.Position = UDim2.fromOffset(0, 0)
	-- the drag of the PrepController picks the grab up from this attribute (only while the box can be taken)
	effect(function()
		button:SetAttribute("PrepGrab", if pickable() then key else nil)
	end)
	-- the shake moves a wrapper: the grid owns the button position
	const wrapper = create("Frame")({
		Name = `Slot_{key}`,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = size,
		button,
	})
	effect(function()
		button.Position = UDim2.fromOffset(shake(), 0)
	end)
	return wrapper
end

return function(props: Props): Frame
	const keys = props.Keys or Content.Ingredients.ToppingKeys
	const title = props.Title or "Toppings"
	const legend = function(): string
		const focus = if props.Focus ~= nil then props.Focus() else ""
		if focus == "" then
			return title
		end
		const state = props.Info(focus)
		const name = nameOf(focus)
		if state.Locked then
			return `{name} . locked`
		end
		return `{name} . {math.max(state.Stock, 0)} left`
	end

	const boxes: { any } = {
		createRaw("UIGridLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			CellSize = function()
				const side = props.Box()
				return UDim2.fromOffset(side, side)
			end,
			CellPadding = UDim2.fromOffset(6, 6),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = props.Cols,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	}
	for index, key in keys do
		table.insert(boxes, box(props, key, index))
	end

	return CartoonPanel({
		Name = props.Name or "IngredientPanel",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Card,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.fromScale(1, 1),
		Padding = 8,
		Children = {
			CartoonLabel({
				Name = "Header",
				Text = legend,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
				Box = UDim2.new(1, 0, 0, HEADER),
				XAlignment = Enum.TextXAlignment.Left,
				YAlignment = Enum.TextYAlignment.Center,
				Truncate = true,
			}),
			create("Frame")({
				Name = "Grid",
				Position = UDim2.fromOffset(0, HEADER),
				Size = UDim2.new(1, 0, 1, -HEADER - Theme.Lip),
				BackgroundTransparency = 1,
				boxes,
			}),
		},
	})
end
