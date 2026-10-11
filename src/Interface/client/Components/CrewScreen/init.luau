--!strict
-- CrewScreen: the "Crew" screen (TASK-020; DEC-186, FEAT-001 class part, FEAT-028; style guide §7.1), mobile first.
-- Laid out for the smallest landscape phone (620 x 320 px at Scale 1, inside CoreUISafeInsets); `Scale` grows it.
--   header   "Crew" · gem balance · close button (44 px)
--   left     preview of the focused animal (ViewportFrame with CrewRig) · description · main button
--   right    3 x 2 grid of CrewCard (the 6 MVP classes; panda/lion are not playable, DEC-186)
-- The main button acts on the focused class: Select / Buy · 45 Gems / disabled ("Selected", "Need 45 Gems", "...").
-- Cartoon pass (AST-091): Ink panel with studs that pops in, "Crew" on a Mustard tab with the paw icon, gem balance
-- pill, round Teal close button (X icon), Cream cards, Mustard/Green/Slate main button (CartoonButton).
-- Pure: only props; the caller sends ClassAction and the server decides (Profile packet + Notice).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local CrewCard = require(script.Parent.CrewCard)
local CardState = require(script.Parent.CrewCard.State)
local Preview = require(script.Preview)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Entry = {
	Key: string, -- Content.Classes key
	Title: string, -- class name (placeholder)
	Animal: string, -- species display name
	Species: string, -- Content.Species key (preview rig)
	Badge: string, -- placeholder icon text
	Icon: string?, -- class icon (art-director); nil = Badge
	Price: number,
	Description: string,
}

export type Props = {
	Entries: { Entry },
	Visible: () -> boolean,
	Gems: () -> number,
	-- State of a class; reads the caller's sources (reactive).
	StateOf: (key: string) -> CardState.State,
	Focus: () -> string,
	-- A request is on its way or the profile has not arrived: the main button is disabled.
	Busy: () -> boolean,
	OnFocus: (key: string) -> (),
	OnAction: (key: string) -> (),
	OnClose: () -> (),
	-- Builds the preview rig (CrewRig.Build + Dress); nil = placeholder letter only.
	Rig: ((species: string) -> Model?)?,
	Scale: (() -> number)?,
}

const WIDTH = 620
const HEIGHT = 320
const PAD = 10
const HEADER = 44
const GAP = 8
const LEFT = 210
const BUTTON = 44
const DESCRIPTION = 40 -- two lines of 14 px
const COLUMNS = 3
const CELL_GAP = 10

const PANEL_LIP = 6

const BUTTON_TONE: { [string]: Theme.Tone } = {
	Accent = Theme.Tone.Mustard,
	Done = Theme.Tone.Green,
	Off = Theme.Tone.Slate,
}

-- Sheet icon (AST-071 / AST-091); hidden while its sheet is missing.
local function sheetIcon(name: string, size: number, order: number): Instance
	const rect = Icons.Rect(name)
	return create("ImageLabel")({
		Name = "Icon",
		LayoutOrder = order,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = Icons.ImageOf(name),
		ImageRectOffset = if rect then rect.Offset else Vector2.zero,
		ImageRectSize = if rect then rect.Size else Vector2.zero,
		Visible = rect ~= nil,
	})
end

return function(props: Props): Frame
	const byKey: { [string]: Entry } = {}
	for _, entry in props.Entries do
		byKey[entry.Key] = entry
	end
	const first = props.Entries[1]

	local function focused(): Entry
		return byKey[props.Focus()] or first
	end

	local function button(): CardState.Button
		const entry = focused()
		return CardState.Button(props.StateOf(entry.Key), entry.Price, props.Busy())
	end

	const scale = function(): number
		return if props.Scale then props.Scale() else 1
	end

	const bodyHeight = HEIGHT - PAD * 2 - HEADER - GAP - PANEL_LIP
	const rightWidth = WIDTH - PAD * 2 - LEFT - GAP
	const rows = math.max(1, math.ceil(#props.Entries / COLUMNS))
	const cellWidth = (rightWidth - CELL_GAP * (COLUMNS - 1)) / COLUMNS
	const cellHeight = (bodyHeight - CELL_GAP * (rows - 1)) / rows

	const cards: { Instance } = {}
	for index, row in props.Entries do
		table.insert(
			cards,
			CrewCard({
				Key = row.Key,
				Title = row.Title,
				Animal = row.Animal,
				Badge = row.Badge,
				Icon = row.Icon,
				Price = row.Price,
				LayoutOrder = index,
				State = function()
					return props.StateOf(row.Key)
				end,
				Focused = function()
					return focused().Key == row.Key
				end,
				OnFocus = function()
					props.OnFocus(row.Key)
				end,
			})
		)
	end

	const pop = Motion.Pop(props.Visible)

	return create("Frame")({
		Name = "CrewScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.5,
		Active = true, -- a tap outside the panel does not reach the world
		Visible = props.Visible,

		CartoonPanel({
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WIDTH, HEIGHT),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Lip = PANEL_LIP,
			Studs = true,
			Gloss = false,
			Padding = PAD,
			Decor = {
				createRaw("UIScale")({
					Scale = function()
						return scale() * pop()
					end,
				}),
			},
			Children = {
				-- Header: title tab with the paw icon
				CartoonPanel({
					Name = "Title",
					Size = UDim2.fromOffset(0, HEADER),
					AutomaticSize = Enum.AutomaticSize.X,
					Rotation = -2,
					Tone = Theme.Tone.Mustard,
					Padding = { Left = 8, Right = 16 },
					Children = {
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
						sheetIcon("Ui/paw", HEADER - 12, 1),
						CartoonLabel({
							LayoutOrder = 2,
							TextSize = 26,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = "Crew",
						}),
					},
				}),

				-- Gem balance
				CartoonPanel({
					Name = "Gems",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -(HEADER + GAP), 0, 0),
					Size = UDim2.fromOffset(0, HEADER),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Ink,
					Padding = { Left = 4, Right = 14 },
					Decor = {
						createRaw("UISizeConstraint")({ MinSize = Vector2.new(110, HEADER) }),
					},
					Children = {
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
						sheetIcon("Hud/gem", HEADER - 6, 1),
						CartoonLabel({
							Name = "Amount",
							LayoutOrder = 2,
							TextSize = 22,
							Text = function()
								return tostring(props.Gems())
							end,
						}),
					},
				}),

				CartoonButton({
					Name = "Close",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(HEADER, HEADER),
					Tone = Theme.Tone.Teal,
					OnActivated = props.OnClose,
					Children = {
						create("UIListLayout")({
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						sheetIcon("Ui/close", HEADER - 16, 1),
						CartoonLabel({
							LayoutOrder = 2,
							TextSize = 22,
							Text = "X",
							Visible = not Icons.Has("Ui/close"),
						}),
					},
				}),

				-- Left column: preview, description, main button
				create("Frame")({
					Name = "Detail",
					Position = UDim2.fromOffset(0, HEADER + GAP),
					Size = UDim2.fromOffset(LEFT, bodyHeight),
					BackgroundTransparency = 1,

					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GAP),
					}),

					Preview({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, bodyHeight - DESCRIPTION - BUTTON - GAP * 2),
						Species = function()
							return focused().Species
						end,
						Badge = function()
							return focused().Badge
						end,
						Visible = props.Visible,
						Rig = props.Rig,
					}),

					CartoonLabel({
						Name = "Description",
						LayoutOrder = 2,
						Box = UDim2.new(1, 0, 0, DESCRIPTION),
						TextSize = Theme.MinTextSize,
						Wrapped = true,
						XAlignment = Enum.TextXAlignment.Left,
						YAlignment = Enum.TextYAlignment.Top,
						Text = function()
							return focused().Description
						end,
					}),

					-- "Selected" stays Green (not pressable: OnActivated checks Enabled); "..." and "Need" are Slate.
					CartoonButton({
						Name = "Action",
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, BUTTON),
						TextSize = 18,
						Outline = Theme.Outline.Thick,
						Icon = function()
							return if button().Kind == "Accent" and string.find(button().Text, "Gems", 1, true) ~= nil
								then "Hud/gem"
								else ""
						end,
						IconSize = 26,
						Tone = function()
							return BUTTON_TONE[button().Kind]
						end,
						Enabled = function()
							return button().Kind ~= "Off"
						end,
						Text = function()
							return button().Text
						end,
						OnActivated = function()
							if button().Enabled then
								props.OnAction(focused().Key)
							end
						end,
					}),
				}),

				-- Right: the cards
				create("Frame")({
					Name = "Cards",
					Position = UDim2.fromOffset(LEFT + GAP, HEADER + GAP),
					Size = UDim2.fromOffset(rightWidth, bodyHeight),
					BackgroundTransparency = 1,

					create("UIGridLayout")({
						CellSize = UDim2.fromOffset(cellWidth, cellHeight),
						CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					cards,
				}),
			},
		}),
	})
end
