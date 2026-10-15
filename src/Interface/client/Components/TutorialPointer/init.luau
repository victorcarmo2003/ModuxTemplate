--!strict
-- TutorialPointer: screen-edge arrow toward the guide target ONLY when neither the 3D arrow tip nor the target is on screen
-- (off screen or behind the camera; the owners decide with Interface/EdgePointer; owner request 2026-10-14) (user
-- request 2026-10-11). Mustard round badge (CartoonPanel) with the AST-091 `Ui/arrow_right` icon turned to `Angle`
-- (0 = right, 90 = down; one rotated image), a Mustard ">" glyph while the sheet is missing. 56 px (touch-sized look,
-- not clickable). Pops in/out (Motion.Pop).
-- Scale = the owner's global UI scale (Theme.ScaleOf); Strong = no progress for a while: the badge pulses (up to
-- +STRONG_PULSE).
-- Pure: only props. The owner computes the edge position (px in the parent frame) and the angle every frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
	-- Global UI scale of the owner (default 1).
	Scale: (() -> number)?,
	-- Size pulse (default false).
	Strong: (() -> boolean)?,
	Name: string?,
}

const ICON = "Ui/arrow_right"
const SIZE = 56
const STRONG_PULSE = 0.25
const STRONG_SPEED = 4.5 -- rad/s

return function(props: Props): Frame
	const pop = Motion.Pop(props.Shown)
	const rect = Icons.Rect(ICON)
	const pulse = Vide.source(0)
	const connection = RunService.Heartbeat:Connect(function()
		const urged = props.Strong ~= nil and Vide.untrack(props.Strong) and Vide.untrack(pop) > 0.02
		const value = if urged then math.abs(math.sin(os.clock() * STRONG_SPEED)) * STRONG_PULSE else 0
		if value ~= Vide.untrack(pulse) then
			pulse(value)
		end
	end)
	Vide.cleanup(function()
		connection:Disconnect()
	end)

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
		createRaw("UIScale")({
			Scale = function()
				return pop() * (if props.Scale then props.Scale() else 1) * (1 + pulse())
			end,
		}),

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
