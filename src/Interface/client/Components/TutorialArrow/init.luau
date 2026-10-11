--!strict
-- TutorialArrow: the bouncing arrow over the station the tutorial points at (user request 2026-10-11). World
-- BillboardGui, always on top (seen through the counter and the awning), pointing down at the adornee.
-- Art: AST-091 `Ui/arrow_right` turned 90 degrees (one rotated image, not a drawn shape); a Mustard "V" glyph with an
-- Ink stroke while the sheet is missing. Fixed pixel size: the arrow stays a readable 64 px at any distance.
-- Scale = the owner's global UI scale (Theme.ScaleOf); Strong = the player made no progress for a while: faster bob and
-- a size pulse (up to +STRONG_PULSE).
-- Pure: only props. TutorialController picks the adornee (anchor of the prompt to use) and when it shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Adornee: () -> Instance?,
	Shown: () -> boolean,
	-- Studs over the adornee (world up). Default 1.6.
	Offset: Vector3?,
	MaxDistance: number?,
	-- Global UI scale of the owner (default 1).
	Scale: (() -> number)?,
	-- Stronger bob + size pulse (default false).
	Strong: (() -> boolean)?,
	Name: string?,
}

const ICON = "Ui/arrow_right"
const SIZE = 52
const BOB = 8 -- px
const BOB_SPEED = 5 -- rad/s
const STRONG_BOB_SPEED = 9 -- rad/s
const STRONG_PULSE = 0.3 -- extra size at the peak of the strong pulse
const ROOM = 1 + STRONG_PULSE -- the billboard leaves room for the pulse

return function(props: Props): BillboardGui
	const pop = Motion.Pop(function()
		return props.Shown() and props.Adornee() ~= nil
	end)
	const phase = source(0)
	const pulse = source(0)
	local function scale(): number
		return if props.Scale then props.Scale() else 1
	end
	local function strong(): boolean
		return if props.Strong then props.Strong() else false
	end
	const connection = RunService.Heartbeat:Connect(function()
		if pop() > 0.01 then
			const urged = Vide.untrack(strong)
			const clock = os.clock()
			phase(clock * (if urged then STRONG_BOB_SPEED else BOB_SPEED))
			pulse(if urged then math.abs(math.sin(clock * STRONG_BOB_SPEED / 2)) * STRONG_PULSE else 0)
		end
	end)
	cleanup(function()
		connection:Disconnect()
	end)

	const rect = Icons.Rect(ICON)
	const hasArt = rect ~= nil

	const gui = create("BillboardGui")({
		Name = props.Name or "TutorialArrow",
		Size = function()
			const s = scale()
			return UDim2.fromOffset((SIZE * ROOM + 16) * s, (SIZE * ROOM + BOB * 2 + 8) * s)
		end,
		-- bottom of the gui on the point
		SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = props.Offset or Vector3.new(0, 1.6, 0),
		MaxDistance = props.MaxDistance or 250,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = function()
			return pop() > 0.01
		end,

		create("Frame")({
			Name = "Bob",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = function()
				return UDim2.new(0.5, 0, 1, (-BOB - math.sin(phase()) * BOB) * scale())
			end,
			Size = UDim2.fromOffset(SIZE, SIZE),
			BackgroundTransparency = 1,
			createRaw("UIScale")({
				Scale = function()
					return pop() * scale() * (1 + pulse())
				end,
			}),

			if hasArt and rect
				then create("ImageLabel")({
					Name = "Arrow",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = Icons.ImageOf(ICON),
					ImageRectOffset = rect.Offset,
					ImageRectSize = rect.Size,
					Rotation = 90,
				})
				else CartoonLabel({
					Name = "Arrow",
					Box = UDim2.fromScale(1, 1),
					TextSize = 40,
					Color = Theme.Color.Mustard,
					Stroke = Theme.Outline.Thick,
					Text = "V",
				}),
		}),
	})
	-- the adornee follows the step (an optional Instance is set by an effect, not as a bound property). The engine
	-- types Adornee as Instance though nil clears it.
	effect(function()
		gui.Adornee = (props.Adornee() :: any) :: Instance
	end)
	return gui
end
