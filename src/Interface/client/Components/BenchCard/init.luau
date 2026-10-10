--!strict
-- BenchCard: one position of the Mart GEAR WALL (FEAT-015, DEC-015, DEC-106; AST-049; style guide §7.3).
-- Shows in the world, never on screen: miniature of the next level, level name, effect in one line and a tag.
--   Buy     tag Mustard "$60"
--   NoCash  same tag in red (FEAT-008/015: the party cannot pay; the server refuses anyway)
--   Maxed   tag Green "Maxed" (the server hides the prompt)
--   Locked  tag Teal "Trailer only" (B5 while on the cart, DEC-055)
--   Empty   no miniature, no tag: one centred line ("Nothing special today", S1)
-- `Special` draws the Mustard frame of the rare slot (DEC-144). Pure: only props; the caller parents the
-- BillboardGui and decides every text. Sized in studs: the player stands ~4 studs from the wall (MAP-01 §7.4),
-- where the smallest phone shows the effect line at >= 14 px.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UITextSizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Buy" | "NoCash" | "Maxed" | "Locked" | "Empty"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	-- rbxassetid of the next level render (AST-071); "" = placeholder tile with `Badge`.
	Icon: () -> string,
	Badge: () -> string,
	Title: () -> string,
	Detail: () -> string,
	-- "$60", "Maxed", "Trailer only"; the Empty line ("Nothing special today") also comes here.
	Tag: () -> string,
	Special: (() -> boolean)?,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 2.8 -- studs; one GEAR WALL module is 3 wide (AST-049)
const HEIGHT = 3.4
const MAX_TEXT = 64

const TAG_BACKGROUND: { [Mode]: Color3 } = {
	Buy = Theme.Color.Mustard,
	NoCash = Theme.Color.NoCash,
	Maxed = Theme.Color.Green,
	Locked = Theme.Color.Teal,
	Empty = Theme.Color.Ink,
}

const TAG_FOREGROUND: { [Mode]: Color3 } = {
	Buy = Theme.Color.Ink,
	NoCash = Theme.Color.Text,
	Maxed = Theme.Color.Text,
	Locked = Theme.Color.Text,
	Empty = Theme.Color.Text,
}

local function label(props: {
	Name: string,
	Position: UDim2,
	Size: UDim2,
	Text: () -> string,
	Font: Font,
	Wrapped: boolean?,
	Visible: (() -> boolean)?,
}): TextLabel
	return create("TextLabel")({
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		FontFace = props.Font,
		TextScaled = true,
		TextWrapped = props.Wrapped or false,
		TextColor3 = Theme.Color.Text,
		Text = props.Text,
		Visible = props.Visible or true,
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		createRaw("UITextSizeConstraint")({ MaxTextSize = MAX_TEXT }),
	})
end

return function(props: Props): BillboardGui
	local function filled(): boolean
		return props.Mode() ~= "Empty"
	end

	local function empty(): boolean
		return props.Mode() == "Empty"
	end

	local function special(): boolean
		return if props.Special then props.Special() else false
	end

	local function hasIcon(): boolean
		return props.Icon() ~= ""
	end

	return create("BillboardGui")({
		Name = props.Name or "BenchCard",
		Adornee = props.Adornee,
		Size = UDim2.fromScale(WIDTH, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = props.Visible,

		create("Frame")({
			Name = "Panel",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,

			create("UICorner")({ CornerRadius = UDim.new(0.08, 0) }),
			createRaw("UIStroke")({
				Color = function()
					return if special() then Theme.Color.Mustard else Theme.Color.Ink
				end,
				Thickness = function()
					return if special() then Theme.Stroke * 2 else Theme.Stroke
				end,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),

			-- Miniature of the next level (render from AST-071) or a placeholder tile until it exists (Q-152).
			create("Frame")({
				Name = "Miniature",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.05),
				Size = UDim2.fromScale(0.5, 0.36),
				BackgroundColor3 = Theme.Color.Cream,
				Visible = filled,

				create("UIAspectRatioConstraint")({ AspectRatio = 1 }),
				create("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),

				create("ImageLabel")({
					Name = "Icon",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = props.Icon,
					Visible = hasIcon,
				}),

				create("TextLabel")({
					Name = "Badge",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Title,
					TextScaled = true,
					TextColor3 = Theme.Color.Ink,
					Text = props.Badge,
					Visible = function()
						return not hasIcon()
					end,
					createRaw("UIPadding")({
						PaddingTop = UDim.new(0.15, 0),
						PaddingBottom = UDim.new(0.15, 0),
					}),
				}),
			}),

			label({
				Name = "Title",
				Position = UDim2.fromScale(0.5, 0.43),
				Size = UDim2.fromScale(0.92, 0.2),
				Text = props.Title,
				Font = Theme.Font.Title,
				Wrapped = true,
				Visible = filled,
			}),

			label({
				Name = "Detail",
				Position = UDim2.fromScale(0.5, 0.63),
				Size = UDim2.fromScale(0.92, 0.12),
				Text = props.Detail,
				Font = Theme.Font.Body,
				Visible = filled,
			}),

			create("Frame")({
				Name = "Tag",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.78),
				Size = UDim2.fromScale(0.78, 0.17),
				BackgroundColor3 = function()
					return TAG_BACKGROUND[props.Mode()]
				end,
				Visible = filled,

				create("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = Theme.Stroke,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),

				create("TextLabel")({
					Name = "Label",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Title,
					TextScaled = true,
					TextColor3 = function()
						return TAG_FOREGROUND[props.Mode()]
					end,
					Text = props.Tag,
					createRaw("UIPadding")({
						PaddingTop = UDim.new(0.12, 0),
						PaddingBottom = UDim.new(0.12, 0),
						PaddingLeft = UDim.new(0.05, 0),
						PaddingRight = UDim.new(0.05, 0),
					}),
					createRaw("UITextSizeConstraint")({ MaxTextSize = MAX_TEXT }),
				}),
			}),

			label({
				Name = "EmptyLine",
				Position = UDim2.fromScale(0.5, 0.3),
				Size = UDim2.fromScale(0.86, 0.4),
				Text = props.Tag,
				Font = Theme.Font.Title,
				Wrapped = true,
				Visible = empty,
			}),
		}),
	})
end
