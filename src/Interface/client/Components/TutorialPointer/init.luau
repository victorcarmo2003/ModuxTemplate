--!strict
-- TutorialPointer: screen-edge arrow toward the tutorial target when it is off screen or behind the camera (user
-- request 2026-10-11). Mustard round badge (CartoonPanel) with the AST-091 `Ui/arrow_right` icon turned to `Angle`
-- (0 = right, 90 = down; one rotated image), a Mustard ">" glyph while the sheet is missing. 56 px (touch-sized look,
-- not clickable). Pops in/out (Motion.Pop).
-- Pure: only props. The owner computes the edge position (px in the parent frame) and the angle every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Shown: () -> boolean,
	-- Centre of the badge, px in the parent frame.
	Position: () -> Vector2,
	-- Degrees; 0 = right, 90 = down.
	Angle: () -> number,
	Name: string?,
}

const ICON = "Ui/arrow_right"
const SIZE = 56

return function(props: Props): Frame
	const pop = Motion.Pop(props.Shown)
	const rect = Icons.Rect(ICON)

	return create("Frame")({
		Name = props.Name or "TutorialPointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = function()
			const at = props.Position()
			return UDim2.fromOffset(at.X, at.Y)
		end,
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Visible = function()
			return pop() > 0.02
		end,
		createRaw("UIScale")({ Scale = pop }),

		CartoonPanel({
			Name = "Badge",
			Size = UDim2.fromScale(1, 1),
			Tone = Theme.Tone.Mustard,
			Outline = Theme.Outline.Thick,
			Children = {
				if rect
					then create("ImageLabel")({
						Name = "Arrow",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.85, 0.85),
						BackgroundTransparency = 1,
						Image = Icons.ImageOf(ICON),
						ImageRectOffset = rect.Offset,
						ImageRectSize = rect.Size,
						Rotation = props.Angle,
					})
					else CartoonLabel({
						Name = "Arrow",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Box = UDim2.fromScale(1, 1),
						TextSize = 30,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Text = ">",
						Rotation = props.Angle,
					}),
			},
		}),
	})
end
