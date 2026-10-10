--!strict
-- SpeechBalloon: short line in a white rounded balloon above a head (style guide §7, "Falas em balão": Opal,
-- Quentin, Raincoat Lady -> smaller white balloon, no icon, 3 s). World element, never on the screen HUD.
-- Sized in pixels (not studs) so the text stays >= 14 px on the smallest phone at any distance; lines are at most
-- 70 characters (content-data.md §3.19), three lines at most at this width. Pops in with a short spring.
-- Pure: only props. The caller parents the BillboardGui, decides the text and how long it stays visible.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const spring = Vide.spring
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Text: () -> string,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 240 -- px of the balloon body
const HEIGHT = 112 -- px of the billboard: up to 3 lines of TEXT_SIZE plus padding and the tail
const TEXT_SIZE = 18 -- >= Theme.MinTextSize on the smallest phone
const PADDING = 10
const TAIL = 14

return function(props: Props): BillboardGui
	const scale = spring(function()
		return if props.Visible() then 1 else 0.6
	end, 0.18, 0.6)

	return create("BillboardGui")({
		Name = props.Name or "SpeechBalloon",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH + 2 * Theme.Stroke, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		LightInfluence = 0,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Enabled = props.Visible,

		create("Frame")({
			Name = "Balloon",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -TAIL / 2),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.Text,

			createRaw("UIScale")({ Scale = scale }),
			create("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				Thickness = Theme.Stroke,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			createRaw("UIPadding")({
				PaddingTop = UDim.new(0, PADDING),
				PaddingBottom = UDim.new(0, PADDING),
				PaddingLeft = UDim.new(0, PADDING + 2),
				PaddingRight = UDim.new(0, PADDING + 2),
			}),

			create("TextLabel")({
				Name = "Line",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Body,
				TextSize = TEXT_SIZE,
				TextWrapped = true,
				TextColor3 = Theme.Color.Ink,
				Text = props.Text,
				ZIndex = 2,
			}),

			-- Tail: a small rotated square under the body, pointing at the speaker.
			create("Frame")({
				Name = "Tail",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 1, PADDING),
				Size = UDim2.fromOffset(TAIL, TAIL),
				Rotation = 45,
				BackgroundColor3 = Theme.Color.Text,
				BorderSizePixel = 0,
				ZIndex = 0,
			}),
		}),
	})
end
