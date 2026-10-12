--!strict
-- KeyChip: the small round "key" badge of the lobby buttons ("C", "1", "Up"), cartoon kit (AST-091).
-- A fixed-size CartoonPanel (a circle for one character, a pill for longer text) whose label fills the whole face with
-- centre / centre alignment, so the text is centred in the badge. The width follows the character count (CartoonPanel
-- auto-size would left-align the text in a wider minimum width: the badge looked off-centre).
-- Hidden while the text is empty (touch devices have no key). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

export type Props = {
	Text: () -> string,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	-- Tone of the badge. Default Ink.
	Tone: Theme.Tone?,
	ZIndex: number?,
}

const HEIGHT = 26 -- px at UI scale 1
const CHAR = 9 -- px per extra character at 14 px Fredoka
const SIDE = 12 -- px of side room around the text

return function(props: Props): Frame
	const width = function(): number
		const length = utf8.len(props.Text()) or #props.Text()
		return math.max(HEIGHT, SIDE + length * CHAR)
	end
	return CartoonPanel({
		Name = props.Name or "Key",
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		ZIndex = props.ZIndex,
		Size = function()
			return UDim2.fromOffset(width(), HEIGHT)
		end,
		Tone = props.Tone or Theme.Tone.Ink,
		Lip = 2,
		Outline = 2,
		Visible = function()
			return props.Text() ~= ""
		end,
		Children = {
			CartoonLabel({
				Name = "Text",
				Box = UDim2.fromScale(1, 1),
				TextSize = Theme.MinTextSize,
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
				Text = props.Text,
			}),
		},
	})
end
