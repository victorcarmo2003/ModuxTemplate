--!strict
-- CrewCard: one animal of the "Crew" screen (TASK-020; DEC-186, FEAT-028; style guide §7.1).
-- A button the size of its grid cell: icon tile (placeholder letter until the class icons exist, art-director),
-- class name, and a tag with the state (State.luau):
--   Selected Green "Selected" · Owned Teal "Owned" · Buy Mustard "45 Gems" · NoGems red "45 Gems"
-- The focused card (the one in the preview) gets a thick Mustard border. Tapping, clicking or moving the gamepad
-- selection onto the card calls OnFocus; buying/selecting is the screen's main button, never the card.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CardState = require(script.State)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = CardState.State

export type Props = {
	Key: string, -- instance name (the controller finds the card for gamepad selection)
	Title: string, -- class name (placeholder, narrative-writer)
	Animal: string, -- species name, small line under the title
	Badge: string, -- placeholder icon text (first letter of the animal)
	Icon: string?, -- rbxassetid of the class icon; nil/"" = Badge tile
	Price: number,
	State: () -> State,
	Focused: () -> boolean,
	OnFocus: () -> (),
	LayoutOrder: number?,
	Size: UDim2?, -- default: the whole parent (a UIGridLayout cell overrides it)
}

const NAME_SIZE = 16
const ANIMAL_SIZE = 14
const TAG_SIZE = 15
const TAG_HEIGHT = 26

const TAG_BACKGROUND: { [State]: Color3 } = {
	Selected = Theme.Color.Green,
	Owned = Theme.Color.Teal,
	Buy = Theme.Color.Mustard,
	NoGems = Theme.Color.NoCash,
}

const TAG_FOREGROUND: { [State]: Color3 } = {
	Selected = Theme.Color.Text,
	Owned = Theme.Color.Text,
	Buy = Theme.Color.Ink,
	NoGems = Theme.Color.Text,
}

return function(props: Props): TextButton
	const icon = props.Icon or ""

	return create("TextButton")({
		Name = props.Key,
		LayoutOrder = props.LayoutOrder or 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = function()
			return if props.Focused() then 0.1 else Theme.Transparency.Panel
		end,
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
		Activated = function()
			props.OnFocus()
		end,
		SelectionGained = function()
			props.OnFocus()
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 14) }),
		createRaw("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if props.Focused() then Theme.Color.Mustard else Theme.Color.Ink
			end,
			Thickness = function()
				return if props.Focused() then Theme.Stroke * 2 else Theme.Stroke
			end,
		}),
		createRaw("UIPadding")({
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),

		-- Icon tile: class icon when it exists, otherwise the animal's first letter (placeholder, art-director).
		create("Frame")({
			Name = "Tile",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 1, -(NAME_SIZE + 2 + ANIMAL_SIZE + TAG_HEIGHT + 8)),
			BackgroundColor3 = Theme.Color.Cream,

			create("UIAspectRatioConstraint")({ AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
			create("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),

			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Image = icon,
				Visible = icon ~= "",
			}),
			create("TextLabel")({
				Name = "Badge",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextScaled = true,
				TextColor3 = Theme.Color.Ink,
				Text = props.Badge,
				Visible = icon == "",
				createRaw("UIPadding")({
					PaddingTop = UDim.new(0.18, 0),
					PaddingBottom = UDim.new(0.18, 0),
				}),
			}),
		}),

		create("TextLabel")({
			Name = "Title",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, NAME_SIZE + 2),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = NAME_SIZE,
			TextColor3 = Theme.Color.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = props.Title,
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		}),

		create("TextLabel")({
			Name = "Animal",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, ANIMAL_SIZE),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Body,
			TextSize = ANIMAL_SIZE,
			TextColor3 = Theme.Color.Cream,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = props.Animal,
		}),

		create("Frame")({
			Name = "Tag",
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, TAG_HEIGHT),
			BackgroundColor3 = function()
				return TAG_BACKGROUND[props.State()]
			end,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("TextLabel")({
				Name = "Label",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = TAG_SIZE,
				TextColor3 = function()
					return TAG_FOREGROUND[props.State()]
				end,
				Text = function()
					return CardState.Tag(props.State(), props.Price)
				end,
			}),
		}),
	})
end
