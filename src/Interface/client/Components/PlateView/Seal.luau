--!strict
-- PlateView/Seal: the grade indicator of the focused prep mode (docs/art/prep-ui-spec.md §7). Shape AND colour AND text
-- (colour blind safe, never red):
--   Perfect  12-point-ish star (two squares, one turned 45 degrees), Mustard, "Perfect!"
--   Good     circle, light Teal, a check mark, "Good"
--   Messy    wobbly blot (two rounded rectangles turned apart), Slate, "Messy"
--   nil      empty round pip (the stage is not done yet)
-- Three sizes by use: pip (14), mini seal (32), plate seal (120, with its word). Flat Frames until the sprites exist
-- (AST-113). Pure: only props. Build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Grade = "Perfect" | "Good" | "Messy"

export type Props = {
	Grade: () -> Grade?,
	-- Side in px (14 pip, 32 mini, 120 plate seal).
	Size: number,
	-- The word under / inside the shape (the plate seal); the label text comes from Content.Prep.Grades.Labels.
	Label: ((Grade) -> string)?,
	-- Degrees; each grade has its own tilt when nil (-6 / 0 / +4).
	Rotation: number?,
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

const TILT: { [Grade]: number } = { Perfect = -6, Good = 0, Messy = 4 }

const COLOR: { [Grade]: Color3 } = {
	Perfect = Color3.fromHex("#FFDA5C"),
	Good = Color3.fromHex("#63C8D4"),
	Messy = Color3.fromHex("#A9AEBF"),
}

-- One piece of a silhouette: centred, `Scale` of the box, turned `Turn` degrees, corners `Corner` (0..0.5).
type Piece = { Scale: Vector2, Turn: number, Corner: number }

const SHAPES: { [Grade]: { Piece } } = {
	Perfect = {
		{ Scale = Vector2.new(0.7, 0.7), Turn = 0, Corner = 0.14 },
		{ Scale = Vector2.new(0.7, 0.7), Turn = 45, Corner = 0.14 },
	},
	Good = {
		{ Scale = Vector2.new(0.9, 0.9), Turn = 0, Corner = 0.5 },
	},
	Messy = {
		{ Scale = Vector2.new(0.92, 0.68), Turn = 12, Corner = 0.38 },
		{ Scale = Vector2.new(0.66, 0.9), Turn = -14, Corner = 0.38 },
	},
}

-- The pieces drawn twice: a bigger Ink copy under the colour copy gives one clean outline around the whole union.
local function silhouette(pieces: { Piece }, color: Color3, outline: number, size: number): { any }
	const out: { any } = {}
	for pass = 1, 2 do
		for _, piece in pieces do
			const grow = if pass == 1 then outline * 2 else 0
			table.insert(
				out,
				create("Frame")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(piece.Scale.X * size + grow, piece.Scale.Y * size + grow),
					Rotation = piece.Turn,
					BackgroundColor3 = if pass == 1 then Theme.Color.Ink else color,
					BorderSizePixel = 0,
					ZIndex = pass,
					create("UICorner")({ CornerRadius = UDim.new(piece.Corner, 0) }),
				})
			)
		end
	end
	return out
end

-- A check mark from two bars, in the 0..1 box.
local function check(size: number): { any }
	const thick = math.max(2, math.floor(size * 0.1))
	local function bar(ax: number, ay: number, bx: number, by: number): Instance
		const dx, dy = bx - ax, by - ay
		const length = math.sqrt(dx * dx + dy * dy)
		return create("Frame")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((ax + bx) / 2, (ay + by) / 2),
			Size = UDim2.fromOffset(thick, length * size + thick),
			Rotation = math.deg(math.atan2(-dx, dy)),
			BackgroundColor3 = Theme.Color.Ink,
			BorderSizePixel = 0,
			ZIndex = 4,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		})
	end
	return { bar(0.3, 0.52, 0.44, 0.67), bar(0.44, 0.67, 0.72, 0.33) }
end

return function(props: Props): Frame
	const size = props.Size
	const outline = math.max(2, math.floor(size / 14))
	const grade = props.Grade
	const children: { any } = {}

	-- the empty pip: a Cream disc, Ink outline
	table.insert(
		children,
		create("Frame")({
			Name = "Empty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.8, size * 0.8),
			BackgroundColor3 = Theme.Tone.Cream.Bottom,
			Visible = function()
				return grade() == nil
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = outline,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
	)

	for _, key in { "Perfect", "Good", "Messy" } :: { Grade } do
		const group: { any } = silhouette(SHAPES[key], COLOR[key], outline, size)
		if key == "Perfect" then
			-- a small bright core: the "stars" of the pop read even at 14 px
			table.insert(
				group,
				create("Frame")({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.3, 0.3),
					BackgroundColor3 = Theme.Color.Cream,
					BorderSizePixel = 0,
					ZIndex = 4,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				})
			)
		elseif key == "Good" and size >= 24 then
			for _, piece in check(size) do
				table.insert(group, piece)
			end
		end
		table.insert(
			children,
			create("Frame")({
				Name = key,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Rotation = props.Rotation or TILT[key],
				Visible = function()
					return grade() == key
				end,
				group,
			})
		)
	end

	-- the word, on the big seal only (the small ones are read by their shape)
	if props.Label ~= nil and size >= 64 then
		const label = props.Label
		table.insert(
			children,
			CartoonLabel({
				Name = "Word",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Box = UDim2.fromScale(1, 0.3),
				Text = function()
					const value = grade()
					return if value ~= nil then label(value) else ""
				end,
				TextSize = math.max(Theme.MinTextSize, math.floor(size / 4)),
				Color = Theme.Color.Ink,
				StrokeColor = Theme.Color.Cream,
				Stroke = 3,
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
				ZIndex = 6,
				Visible = function()
					return grade() ~= nil
				end,
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "Seal",
		LayoutOrder = props.LayoutOrder or 0,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		children,
	})
end
