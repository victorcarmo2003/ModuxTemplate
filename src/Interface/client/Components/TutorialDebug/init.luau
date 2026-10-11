--!strict
-- TutorialDebug: dev-only readout of the first-hot-dog tutorial (user request 2026-10-11, Provisional). A small Ink
-- card on the right edge with monospaced lines (step, call state, Answered / Voiced, target, Beacon / arrow / pointer,
-- voice queue, effective volume). Dev mode only: TutorialController mounts it in Studio and toggles it with F8 or
-- `/dev tutdebug`. Not a player UI: no cartoon kit, no tap target (read only). Text 14 px.
-- Pure: only props. The owner writes the text (a few times per second while shown).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIPadding / UIStroke are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	Text: () -> string,
	Name: string?,
}

const WIDTH = 380 -- px
const TEXT_SIZE = 14 -- px (style guide floor)
const MARGIN = 12 -- px from the right edge
const TOP = 120 -- px from the top (under the HUD's top row and the tutorial panel)

return function(props: Props): Frame
	return create("Frame")({
		Name = props.Name or "TutorialDebug",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGIN, 0, TOP),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.Ink,
		BackgroundTransparency = 0.15,
		Visible = props.Shown,
		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		createRaw("UIStroke")({ Color = Theme.Color.Mustard, Thickness = 2 }),
		createRaw("UIPadding")({
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		create("TextLabel")({
			Name = "Lines",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
			TextSize = TEXT_SIZE,
			TextColor3 = Theme.Color.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = false,
			Text = props.Text,
		}),
	})
end
