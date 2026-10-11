--!strict
-- LobbyWindow: the modal window of the lobby screens (Shop, Codes, Squad), cartoon kit (AST-091), mobile first.
--   backdrop  full-screen Ink at 50% (Active: a tap outside never reaches the world)
--   panel     Ink CartoonPanel with studs that pops in (Motion.Pop), `Size` px at UI scale 1, times `Scale`
--   header    Mustard title tab (icon + title) · optional gem balance pill · round Teal close button (44 px)
--   body      `Children`, under the header (Body frame, full width)
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Icon = require(script.Icon)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale and UISizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Name: string?,
	Title: string,
	-- Icons name of the title tab ("Ui/paw"); hidden while the sheet is missing.
	Icon: string?,
	-- Panel size in px at UI scale 1 (fit the smallest landscape phone: <= 620 x 320).
	Size: Vector2,
	Visible: () -> boolean,
	Scale: (() -> number)?,
	-- Gem balance pill in the header; nil = none.
	Gems: (() -> number)?,
	OnClose: () -> (),
	Children: { any }?,
}

const PAD = 10
const HEADER = 44
const GAP = 8
const PANEL_LIP = 6

return function(props: Props): Frame
	const pop = Motion.Pop(props.Visible)
	const scale = function(): number
		return if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1
	end
	const bodyHeight = props.Size.Y - PAD * 2 - HEADER - GAP - PANEL_LIP

	const header: { any } = {
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
				Icon(props.Icon or "", HEADER - 12, 1),
				CartoonLabel({
					LayoutOrder = 2,
					TextSize = 26,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = props.Title,
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
				Icon("Ui/close", HEADER - 16, 1),
				CartoonLabel({
					LayoutOrder = 2,
					TextSize = 22,
					Text = "X",
					Visible = not Icons.Has("Ui/close"),
				}),
			},
		}),
	}

	const gems = props.Gems
	if gems then
		table.insert(
			header,
			CartoonPanel({
				Name = "Gems",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -(HEADER + GAP), 0, 0),
				Size = UDim2.fromOffset(0, HEADER),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Padding = { Left = 4, Right = 14 },
				Decor = {
					createRaw("UISizeConstraint")({ MinSize = Vector2.new(96, HEADER) }),
				},
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					Icon("Hud/gem", HEADER - 6, 1),
					CartoonLabel({
						Name = "Amount",
						LayoutOrder = 2,
						TextSize = 22,
						Text = function()
							return tostring(gems())
						end,
					}),
				},
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "LobbyWindow",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.5,
		Active = true,
		Visible = props.Visible,

		CartoonPanel({
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(props.Size.X, props.Size.Y),
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
				header,
				create("Frame")({
					Name = "Body",
					Position = UDim2.fromOffset(0, HEADER + GAP),
					Size = UDim2.new(1, 0, 0, bodyHeight),
					BackgroundTransparency = 1,
					props.Children or {},
				}),
			},
		}),
	}) :: Frame
end
