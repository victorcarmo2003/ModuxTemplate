--!strict
-- HudSpectate: what a player who is not on their feet sees (FEAT-025, DEC-091, DEC-093, DEC-115, DEC-129;
-- ui-text.md §12.3; style guide §7.2).
--   centre      Down, while `Focus` (the first seconds after the fall, TASK-485 / DEC-294): big "You fainted!" and one
--               Cream tag of context (`Line`), sitting right over the centre of the screen; the big revive offer
--               (ReviveKitController, its own ScreenGui) starts right under the centre. The pill waits until it ends.
--   top centre  Out (Spectator) card, for a while after the change: "You're out for now." · "Watch your crew. Cheer
--               them on!" · "Your gems are safe."
--   bottom      pill "Watching: {name}" (or "Watching the trailer" with nobody standing) + the switch hint of the
--               current device ("Tap to switch" / "Press E to switch" / "Press X to switch")
-- No ambulance, no lobby button; the revive offer is ReviveKitController's (its own ScreenGui). Status only: the switch
-- itself is the camera's bind (CameraController); nothing here is clickable (FEAT-032). Pure: only props.
-- Cartoon pass (AST-091): the card is a Cream CartoonPanel that pops in (Motion.Pop); the "Watching" pill is an Ink
-- panel with the binoculars icon between two arrow icons (decoration only: they show the switch, they are not buttons).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

-- None = on their feet (nothing shown); Down = fainted tonight; Out = spectator until the next night.
export type Mode = "None" | "Down" | "Out"

export type Props = {
	Mode: () -> Mode,
	-- Show the top card of Out (the owner turns it off after a few seconds).
	Card: () -> boolean,
	-- Down: the focus window (centred title + line, no pill yet). nil = never.
	Focus: (() -> boolean)?,
	-- Down: the context line under the title. Default "Your crew's still on shift."
	Line: (() -> string)?,
	-- Name of the watched crewmate; "" = nobody standing (fixed trailer view).
	Target: () -> string,
	-- Switch hint for the current device; "" hides it.
	Hint: () -> string,
	-- Top of the card in px (under the clock). Default 50.
	CardTop: number?,
	-- Distance of the pill from the bottom in px (above the hotbar). Default 84.
	Bottom: number?,
	Name: string?,
}

const CARD_WIDTH = 260
const TITLE_SIZE = 22
const LINE_SIZE = 15
const HINT_SIZE = 14
const PILL = 40
const ARROW = 28
const FOCUS_TITLE = 44
const FOCUS_LINE = 18
const FOCUS_GAP = 10 -- px over the screen centre (the revive offer starts under it)
const DOWN_LINE = "Your crew's still on shift."

const LINES: { [Mode]: { string } } = {
	None = {},
	Down = {},
	Out = { "You're out for now.", "Watch your crew. Cheer them on!", "Your gems are safe." },
}

-- Sheet icon, or a drawn text glyph while the sheet is not uploaded.
local function glyph(order: number, name: string, fallback: string, size: number): Frame
	const rect = Icons.Rect(name)
	return create("Frame")({
		Name = "Glyph",
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		if rect
			then create("ImageLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = Icons.ImageOf(name),
				ImageRectOffset = rect.Offset,
				ImageRectSize = rect.Size,
			})
			else CartoonLabel({
				Box = UDim2.fromScale(1, 1),
				Text = fallback,
				TextSize = math.floor(size * 0.8),
				Color = Theme.Color.Mustard,
				Visible = fallback ~= "",
			}),
	})
end

return function(props: Props): Frame
	const shown = function(): boolean
		return props.Mode() ~= "None"
	end
	-- Keep the last mode so the card shrinks away with its text.
	const initial: Mode = if props.Mode() == "None" then "Down" else props.Mode()
	const lastMode = source(initial)
	effect(function()
		const mode = props.Mode()
		if mode ~= "None" then
			lastMode(mode)
		end
	end)
	const focused = function(): boolean
		return props.Mode() == "Down" and props.Focus ~= nil and props.Focus()
	end
	const cardScale = Motion.Pop(function()
		return props.Mode() == "Out" and props.Card()
	end)
	const focusScale = Motion.Pop(focused)
	const pillScale = Motion.Pop(function()
		return shown() and not focused()
	end)

	const textAt = function(index: number): () -> string
		return function()
			return LINES[lastMode()][index] or ""
		end
	end

	return create("Frame")({
		Name = props.Name or "HudSpectate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = function()
			return shown() or cardScale() > 0.02 or focusScale() > 0.02 or pillScale() > 0.02
		end,

		create("Frame")({
			Name = "Focus",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, -FOCUS_GAP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = function()
				return focusScale() > 0.02
			end,
			createRaw("UIScale")({ Scale = focusScale }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			CartoonLabel({
				Name = "Title",
				LayoutOrder = 1,
				Text = "You fainted!",
				TextSize = FOCUS_TITLE,
				Stroke = 4,
			}),
			CartoonPanel({
				Name = "Line",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, FOCUS_LINE + 18),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -1.5,
				Tone = Theme.Tone.Cream,
				Lip = 3,
				Padding = { Left = 16, Right = 16 },
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = function()
							return if props.Line then props.Line() else DOWN_LINE
						end,
						TextSize = FOCUS_LINE,
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),
		}),

		CartoonPanel({
			Name = "Card",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, props.CardTop or 50),
			Size = UDim2.fromOffset(CARD_WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Studs = true,
			Gloss = false,
			Padding = { Left = 14, Right = 14, Top = 8, Bottom = 10 },
			Visible = function()
				return cardScale() > 0.02
			end,
			Decor = { createRaw("UIScale")({ Scale = cardScale }) },
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				CartoonLabel({
					Name = "Line1",
					LayoutOrder = 1,
					Box = UDim2.new(1, 0, 0, TITLE_SIZE + 8),
					Text = textAt(1),
					TextSize = TITLE_SIZE,
					Color = Theme.Color.Violet,
					Stroke = 0,
				}),
				CartoonLabel({
					Name = "Line2",
					LayoutOrder = 2,
					Box = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Wrapped = true,
					Text = textAt(2),
					TextSize = LINE_SIZE,
					Color = Theme.Color.Dark,
					Stroke = 0,
				}),
				CartoonLabel({
					Name = "Line3",
					LayoutOrder = 3,
					Box = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Wrapped = true,
					Text = textAt(3),
					TextSize = LINE_SIZE,
					Color = Theme.Color.Slate,
					Stroke = 0,
					Visible = function()
						return textAt(3)() ~= ""
					end,
				}),
			},
		}),

		create("Frame")({
			Name = "Watching",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -(props.Bottom or 84)),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = function()
				return pillScale() > 0.02
			end,
			createRaw("UIScale")({ Scale = pillScale }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			create("Frame")({
				Name = "Row",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, PILL),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				glyph(1, "Ui/arrow_left", "<", ARROW),
				CartoonPanel({
					Name = "Target",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, PILL),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Ink,
					Transparency = Theme.Transparency.Panel,
					Padding = { Left = 6, Right = 18 },
					Children = {
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 6),
						}),
						glyph(1, "Ui/spectate", "", PILL - 8),
						CartoonLabel({
							LayoutOrder = 2,
							TextSize = 17,
							Text = function()
								const target = props.Target()
								return if target == "" then "Watching the trailer" else `Watching: {target}`
							end,
						}),
					},
				}),
				glyph(3, "Ui/arrow_right", ">", ARROW),
			}),

			CartoonLabel({
				Name = "Hint",
				LayoutOrder = 2,
				Text = props.Hint,
				TextSize = HINT_SIZE,
				Color = Theme.Color.Cream,
				Visible = function()
					return props.Hint() ~= ""
				end,
			}),
		}),
	})
end
