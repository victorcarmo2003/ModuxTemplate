--!strict
-- SpeechBalloon: short line in a white rounded balloon above a head (style guide §7, "Falas em balão": Opal,
-- Quentin, Raincoat Lady -> smaller white balloon, no icon, 3 s). World element, never on the screen HUD.
-- Sized in pixels (not studs) so the text stays >= 14 px on the smallest phone at any distance; lines are at most
-- 70 characters (content-data.md §3.19), three lines at most at this width. Pops in with a bouncy spring.
-- Cartoon pass (AST-091 "balão de fala menor"): white CartoonPanel (gradient, lip, thick Ink outline) with the tail
-- behind it, Ink text.
-- Pure: only props. The caller parents the BillboardGui, decides the text and how long it stays visible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Text: () -> string,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 210 -- px of the balloon body
const HEIGHT = 104 -- px of the billboard: up to 3 lines of TEXT_SIZE plus padding, lip and the tail
const TEXT_SIZE = 16 -- >= Theme.MinTextSize on the smallest phone
const PADDING = 8
const TAIL = 12
const OUTLINE = Theme.Outline.Normal

return function(props: Props): BillboardGui
	const scale = spring(function()
		return if props.Visible() then 1 else 0.6
	end, 0.2, 0.5)

	return create("BillboardGui")({
		Name = props.Name or "SpeechBalloon",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH + 2 * OUTLINE, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Enabled = props.Visible,

		create("Frame")({
			Name = "Balloon",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -TAIL / 2 - OUTLINE),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			createRaw("UIScale")({ Scale = scale }),

			-- Tail: a small rotated square behind the body, pointing at the speaker.
			create("Frame")({
				Name = "Tail",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 1, -2),
				Size = UDim2.fromOffset(TAIL, TAIL),
				Rotation = 45,
				BackgroundColor3 = Theme.Tone.White.Lip,
				ZIndex = 0,
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = OUTLINE,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),

			CartoonPanel({
				Name = "Body",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Tone = Theme.Tone.White,
				Outline = OUTLINE,
				Radius = Theme.Radius.Card,
				ZIndex = 1,
				Padding = { Top = PADDING, Bottom = PADDING, Left = PADDING + 2, Right = PADDING + 2 },
				Children = {
					CartoonLabel({
						Name = "Line",
						Box = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextSize = TEXT_SIZE,
						Wrapped = true,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Text = props.Text,
					}),
				},
			}),
		}),
	})
end
