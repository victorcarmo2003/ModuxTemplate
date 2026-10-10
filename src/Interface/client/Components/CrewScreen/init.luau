--!strict
-- CrewScreen: the "Crew" screen (TASK-020; DEC-186, FEAT-001 class part, FEAT-028; style guide §7.1), mobile first.
-- Laid out for the smallest landscape phone (620 x 320 px at Scale 1, inside CoreUISafeInsets); `Scale` grows it.
--   header   "Crew" · gem balance · close button (44 px)
--   left     preview of the focused animal (ViewportFrame with CrewRig) · description · main button
--   right    3 x 2 grid of CrewCard (the 6 MVP classes; panda/lion are not playable, DEC-186)
-- The main button acts on the focused class: Select / Buy · 45 Gems / disabled ("Selected", "Need 45 Gems", "...").
-- Pure: only props; the caller sends ClassAction and the server decides (Profile packet + Notice).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
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

const BUTTON_COLOR: { [string]: Color3 } = {
	Accent = Theme.Color.Mustard,
	Done = Theme.Color.Green,
	Off = Theme.Color.Slate,
}

const BUTTON_TEXT: { [string]: Color3 } = {
	Accent = Theme.Color.Ink,
	Done = Theme.Color.Text,
	Off = Theme.Color.Text,
}

local function stroke(): Instance
	return createRaw("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.Color.Ink,
		Thickness = Theme.Stroke,
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
		return if props.Scale then math.max(props.Scale(), 1) else 1
	end

	const bodyHeight = HEIGHT - PAD * 2 - HEADER - GAP
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

	return create("Frame")({
		Name = "CrewScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.5,
		Active = true, -- a tap outside the panel does not reach the world
		Visible = props.Visible,

		create("Frame")({
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WIDTH, HEIGHT),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.1,

			createRaw("UIScale")({ Scale = scale }),
			create("UICorner")({ CornerRadius = UDim.new(0, 18) }),
			stroke(),
			createRaw("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, PAD),
				PaddingRight = UDim.new(0, PAD),
			}),

			-- Header
			create("TextLabel")({
				Name = "Title",
				Size = UDim2.fromOffset(200, HEADER),
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Title,
				TextSize = 28,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Color.Text,
				Text = "Crew",
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),

			create("Frame")({
				Name = "Gems",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -(HEADER + GAP), 0, 0),
				Size = UDim2.fromOffset(150, HEADER),
				BackgroundColor3 = Theme.Color.Ink,
				BackgroundTransparency = Theme.Transparency.Panel,

				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				stroke(),
				-- drawn gem until the icon sheet exists (AST-071)
				create("Frame")({
					Name = "Gem",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(24, HEADER / 2),
					Size = UDim2.fromOffset(16, 16),
					Rotation = 45,
					BackgroundColor3 = Theme.Color.Teal,
					stroke(),
				}),
				create("TextLabel")({
					Name = "Amount",
					Position = UDim2.fromOffset(42, 0),
					Size = UDim2.new(1, -52, 1, 0),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Title,
					TextSize = 22,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Theme.Color.Text,
					Text = function()
						return tostring(props.Gems())
					end,
				}),
			}),

			create("TextButton")({
				Name = "Close",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(HEADER, HEADER),
				BackgroundColor3 = Theme.Color.Cream,
				AutoButtonColor = true,
				FontFace = Theme.Font.Title,
				TextSize = 22,
				TextColor3 = Theme.Color.Ink,
				Text = "X",
				Activated = function()
					props.OnClose()
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				stroke(),
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

				create("TextLabel")({
					Name = "Description",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, DESCRIPTION),
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Body,
					TextSize = Theme.MinTextSize,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = Theme.Color.Text,
					Text = function()
						return focused().Description
					end,
				}),

				create("TextButton")({
					Name = "Action",
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, BUTTON),
					AutoButtonColor = function()
						return button().Enabled
					end,
					Active = function()
						return button().Enabled
					end,
					BackgroundColor3 = function()
						return BUTTON_COLOR[button().Kind]
					end,
					FontFace = Theme.Font.Title,
					TextSize = 18,
					TextColor3 = function()
						return BUTTON_TEXT[button().Kind]
					end,
					Text = function()
						return button().Text
					end,
					Activated = function()
						if button().Enabled then
							props.OnAction(focused().Key)
						end
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					stroke(),
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
		}),
	})
end
