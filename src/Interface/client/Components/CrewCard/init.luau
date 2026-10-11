--!strict
-- CrewCard: one animal of the "Crew" screen (TASK-020; DEC-186, FEAT-028; style guide §7.1; AST-091 "Cartão de
-- classe"). A CartoonButton the size of its grid cell: Cream card with an icon tile (the class icon `Icon`, else the
-- AST-071 `Class/<Key>` head render, else the animal letter), class name, species, and a tag with the state
-- (State.luau):
--   Selected Green "Selected" · Owned Teal "Owned" · Buy Mustard "45 Gems" (gem icon) · NoGems red "45 Gems"
-- The focused card (the one in the preview) gets a thick Mustard outline.
-- Tapping, clicking or moving the gamepad selection onto the card calls OnFocus; buying/selecting is the screen's
-- main button, never the card. The root is the TextButton named `Key` (the controller selects it for the gamepad).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local CardState = require(script.State)

const create = Vide.create

export type State = CardState.State

export type Props = {
	Key: string, -- instance name (the controller finds the card for gamepad selection)
	Title: string, -- class name (placeholder, narrative-writer)
	Animal: string, -- species name, small line under the title
	Badge: string, -- placeholder icon text (first letter of the animal)
	Icon: string?, -- rbxassetid of the class icon; nil/"" = AST-071 sheet, else Badge tile
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
const TAG_HEIGHT = 28
const GEM = 20

const TAG_TONE: { [State]: Theme.Tone } = {
	Selected = Theme.Tone.Green,
	Owned = Theme.Tone.Teal,
	Buy = Theme.Tone.Mustard,
	NoGems = Theme.ToneOf(Theme.Color.NoCash),
}

return function(props: Props): TextButton
	const icon = props.Icon or ""
	const sheetName = `Class/{props.Key}`
	const sheet = if icon == "" then Icons.Rect(sheetName) else nil
	const gem = Icons.Rect("Hud/gem")

	local function priced(): boolean
		const state = props.State()
		return state == "Buy" or state == "NoGems"
	end

	return CartoonButton({
		Name = props.Key,
		LayoutOrder = props.LayoutOrder or 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Tone = Theme.Tone.Cream,
		Outline = function()
			return if props.Focused() then Theme.Outline.Thick + 1 else Theme.Outline.Normal
		end,
		OutlineColor = function()
			return if props.Focused() then Theme.Color.Mustard else Theme.Color.Ink
		end,
		Radius = Theme.Radius.Card,
		OnActivated = props.OnFocus,
		SelectionGained = props.OnFocus,
		Padding = 6,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),

			-- Icon tile: class icon, sheet render, or the animal's first letter (placeholder, art-director).
			CartoonPanel({
				Name = "Tile",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 1, -(NAME_SIZE + 2 + ANIMAL_SIZE + TAG_HEIGHT + 10)),
				Tone = Theme.Tone.White,
				Outline = 2,
				Lip = 3,
				Radius = Theme.Radius.Chip,
				Gloss = false,
				Decor = {
					create("UIAspectRatioConstraint")({ AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
				},
				Children = {
					create("ImageLabel")({
						Name = "Icon",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Image = if icon ~= "" then icon else Icons.ImageOf(sheetName),
						ImageRectOffset = if sheet then sheet.Offset else Vector2.zero,
						ImageRectSize = if sheet then sheet.Size else Vector2.zero,
						Visible = icon ~= "" or sheet ~= nil,
					}),
					CartoonLabel({
						Name = "Badge",
						Box = UDim2.fromScale(1, 1),
						TextSize = 30,
						Scaled = true,
						MaxTextSize = 48,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Text = props.Badge,
						Visible = icon == "" and sheet == nil,
					}),
				},
			}),

			CartoonLabel({
				Name = "Title",
				LayoutOrder = 2,
				Box = UDim2.new(1, 0, 0, NAME_SIZE + 2),
				TextSize = NAME_SIZE,
				Color = Theme.Color.Dark,
				Stroke = 0,
				Truncate = true,
				Text = props.Title,
			}),

			CartoonLabel({
				Name = "Animal",
				LayoutOrder = 3,
				Box = UDim2.new(1, 0, 0, ANIMAL_SIZE),
				TextSize = ANIMAL_SIZE,
				Color = Theme.Color.Slate,
				Stroke = 0,
				Truncate = true,
				Text = props.Animal,
			}),

			CartoonPanel({
				Name = "Tag",
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, TAG_HEIGHT),
				Tone = function()
					return TAG_TONE[props.State()]
				end,
				Outline = 2,
				Lip = 3,
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),
					create("ImageLabel")({
						Name = "Gem",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(GEM, GEM),
						BackgroundTransparency = 1,
						Image = Icons.ImageOf("Hud/gem"),
						ImageRectOffset = if gem then gem.Offset else Vector2.zero,
						ImageRectSize = if gem then gem.Size else Vector2.zero,
						Visible = function()
							return gem ~= nil and priced()
						end,
					}),
					CartoonLabel({
						Name = "Label",
						LayoutOrder = 2,
						TextSize = TAG_SIZE,
						Color = function()
							return TAG_TONE[props.State()].Text
						end,
						Stroke = function()
							return if TAG_TONE[props.State()].Stroke then 2 else 0
						end,
						Text = function()
							return CardState.Tag(props.State(), props.Price)
						end,
					}),
				},
			}),
		},
	})
end
