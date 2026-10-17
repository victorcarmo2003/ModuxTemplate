--!strict
-- StockMenu.Chip: the supply status chip of the HUD (FEAT-050; TASK-389). Ink pill under the clock with a box icon (the
-- package that is running low, else the first one on the way) and one line: "Low on Buns" or "On the way 0:45".
-- The icon pulses while a product is at or under Content.Restaurant.Supply.LowAt (Motion.Reduced: no pulse, the pill
-- turns Mustard instead so the state still reads). Status only, not touchable (Theme.MinChip height).
-- Pure: only props. px at UI scale 1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Icons = require(script.Parent.Parent.Icons)
local Motion = require(script.Parent.Parent.Motion)
local CartoonPanel = require(script.Parent.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Visible: () -> boolean,
	-- Icons name ("Item/pack_buns")
	Icon: () -> string,
	Text: () -> string,
	-- a product is low: the icon pulses
	Pulse: () -> boolean,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Name: string?,
}

const HEIGHT = Theme.MinChip
const WIDTH = 196
const ICON = 26
const TEXT = 16
-- pulse: scale 1 .. 1 + PULSE_AMOUNT, PULSE_SPEED rad/s
const PULSE_AMOUNT = 0.22
const PULSE_SPEED = 7
const EMPTY_RECT: Icons.Rect = { Offset = Vector2.zero, Size = Vector2.zero }

return function(props: Props): Frame
	const scale = Motion.Pop(props.Visible)
	const pulse = source(1)
	local clock = 0
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if untrack(props.Pulse) and not Motion.Reduced() then
			clock += dt
			pulse(1 + PULSE_AMOUNT * math.abs(math.sin(clock * PULSE_SPEED)))
		elseif untrack(pulse) ~= 1 then
			clock = 0
			pulse(1)
		end
	end)
	cleanup(connection)

	local function rect(): Icons.Rect
		return Icons.Rect(props.Icon()) or EMPTY_RECT
	end

	return CartoonPanel({
		Name = props.Name or "SupplyChip",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position or UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Tone = function()
			return if props.Pulse() and Motion.Reduced() then Theme.Tone.Mustard else Theme.Tone.Ink
		end,
		Transparency = Theme.Transparency.Panel,
		Outline = Theme.Outline.Normal,
		Visible = function()
			return scale() > 0.01
		end,
		Decor = {
			createRaw("UIScale")({ Scale = scale }),
		},
		Children = {
			create("ImageLabel")({
				Name = "Box",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 6 + ICON / 2, 0.5, 0),
				Size = UDim2.fromOffset(ICON, ICON),
				Image = function()
					return Icons.ImageOf(props.Icon())
				end,
				ImageRectOffset = function()
					return rect().Offset
				end,
				ImageRectSize = function()
					return rect().Size
				end,
				createRaw("UIScale")({ Scale = pulse }),
			}),
			CartoonLabel({
				Name = "Label",
				Position = UDim2.fromOffset(ICON + 12, 0),
				Box = UDim2.new(1, -(ICON + 18), 1, 0),
				TextSize = TEXT,
				XAlignment = Enum.TextXAlignment.Left,
				Truncate = true,
				Color = function()
					return if props.Pulse() and Motion.Reduced() then Theme.Color.Dark else Theme.Color.Text
				end,
				Stroke = function()
					return if props.Pulse() and Motion.Reduced() then 0 else Theme.TextStroke(TEXT)
				end,
				Text = props.Text,
			}),
		},
	})
end
