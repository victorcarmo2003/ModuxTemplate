--!strict
-- One volume row of the SettingsPanel: label · track (Ink well, Mustard fill, Cream knob) · "80%".
-- Mouse / touch: press anywhere on the track and drag; the value follows live (OnChange per change, whole percents).
-- Gamepad: the track is Selectable; A (Activated from a gamepad) steps +STEP and wraps to 0 after 100.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Name: string,
	LayoutOrder: number,
	Label: string,
	Value: () -> number, -- 0..100
	OnChange: (value: number) -> (),
	-- Row height px at UI scale 1 (the touch box of the track). Default Theme.MinTouch.
	Height: number?,
	LabelWidth: number?,
}

const STEP = 10 -- gamepad step
const BAR = 12 -- visible track thickness
const KNOB = 24
const PERCENT_WIDTH = 50
const GAP = 8

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

return function(props: Props): Frame
	const height = props.Height or Theme.MinTouch
	const labelWidth = props.LabelWidth or 104
	const dragging = source(false)
	const share = function(): number
		return math.clamp(props.Value(), 0, 100) / 100
	end

	local track: TextButton? = nil
	local function setFrom(x: number)
		const box = track
		if box == nil or box.AbsoluteSize.X <= 0 then
			return
		end
		const ratio = math.clamp((x - box.AbsolutePosition.X) / box.AbsoluteSize.X, 0, 1)
		const value = math.floor(ratio * 100 + 0.5)
		if value ~= untrack(props.Value) then
			props.OnChange(value)
		end
	end

	track = create("TextButton")({
		Name = "Track",
		LayoutOrder = 2,
		Size = UDim2.new(1, -(labelWidth + PERCENT_WIDTH + GAP * 2), 1, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
		InputBegan = function(input: InputObject)
			if isPointer(input) then
				dragging(true)
				setFrom(input.Position.X)
			end
		end,
		Activated = function(input: InputObject)
			if string.sub(input.UserInputType.Name, 1, 7) == "Gamepad" then
				const now = untrack(props.Value)
				props.OnChange(if now >= 100 then 0 else math.min(now + STEP, 100))
			end
		end,

		-- the well
		create("Frame")({
			Name = "Well",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, BAR),
			BackgroundColor3 = Theme.Tone.Ink.Lip,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),

			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(share(), 1)
				end,
				BackgroundColor3 = Theme.Color.Mustard,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			}),
		}),

		create("Frame")({
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.fromScale(share(), 0.5)
			end,
			Size = function()
				const grow = if dragging() then 4 else 0
				return UDim2.fromOffset(KNOB + grow, KNOB + grow)
			end,
			BackgroundColor3 = Theme.Color.Cream,
			BorderSizePixel = 0,
			ZIndex = 2,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		}),
	}) :: TextButton

	const moved = UserInputService.InputChanged:Connect(function(input: InputObject)
		if untrack(dragging) and isMove(input) then
			setFrom(input.Position.X)
		end
	end)
	const ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		if isPointer(input) then
			dragging(false)
		end
	end)
	cleanup(function()
		moved:Disconnect()
		ended:Disconnect()
	end)

	return create("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),

		CartoonLabel({
			Name = "Label",
			LayoutOrder = 1,
			TextSize = 18,
			Text = props.Label,
			XAlignment = Enum.TextXAlignment.Left,
			Box = UDim2.fromOffset(labelWidth, height),
		}),

		track,

		CartoonLabel({
			Name = "Percent",
			LayoutOrder = 3,
			TextSize = 18,
			Text = function()
				return `{math.floor(props.Value() + 0.5)}%`
			end,
			XAlignment = Enum.TextXAlignment.Right,
			Box = UDim2.fromOffset(PERCENT_WIDTH, height),
		}),
	}) :: Frame
end
