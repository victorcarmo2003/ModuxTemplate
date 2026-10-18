--!strict
-- HudWipe: the 10 s window when nobody is on their feet (FEAT-026, DEC-094; ui-text.md §12.3; style guide §7.2).
-- Clean faint screen (TASK-485, DEC-294): no ring of dots, no seconds. A DrainBar at the top centre (where the clock
-- sits for a standing player; the clock is hidden while not on their feet) that empties with the window, with
-- "Everyone's out!" inside it. Mustard and Ink, never red, no alarming tick (no bump, no shake).
-- The owner gives the share of the window left from `Shift.WipeEndsAt`; `Left < 0` hides it. It pops in once
-- (Motion.Pop) and shrinks away. Status only: nothing clickable (FEAT-032). Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Motion = require(script.Parent.Motion)
local DrainBar = require(script.Parent.DrainBar)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- Share of the window still left (0..1); < 0 = no window.
	Left: () -> number,
	-- Text inside the bar. Default "Everyone's out!".
	Text: (() -> string)?,
	Name: string?,
	AnchorPoint: Vector2?,
	-- Default top centre, 8 px down (the clock's row).
	Position: UDim2?,
}

const WIDTH = 300
const HEIGHT = 34
const TEXT_SIZE = 18
const TEXT = "Everyone's out!"

return function(props: Props): Frame
	const shown = function(): boolean
		return props.Left() >= 0
	end
	-- Last value shown, so the bar shrinks away as it was after the window closes.
	const last = source(math.max(props.Left(), 0))
	effect(function()
		const left = props.Left()
		if left >= 0 then
			last(left)
		end
	end)
	const scale = Motion.Pop(shown)

	return create("Frame")({
		Name = props.Name or "HudWipe",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position or UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return scale() > 0.02
		end,

		createRaw("UIScale")({ Scale = scale }),

		DrainBar({
			Left = last,
			Text = props.Text or function()
				return TEXT
			end,
			Width = WIDTH,
			Height = HEIGHT,
			TextSize = TEXT_SIZE,
		}),
	})
end
