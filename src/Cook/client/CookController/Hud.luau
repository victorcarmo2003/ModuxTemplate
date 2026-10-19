--!strict
-- The 2D that the cooking focus keeps (kitchen-focus.md §2): one hint line at the bottom, a Back button (bottom left; B / Backspace
-- / Q on the keyboard do the same), the grade of the last gesture popping over the work ("Perfect!" Mustard, "Good" Teal, "Messy"
-- Slate; never red) and the dot of the gamepad cursor. Vide, mounted by the controller while the focus is up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

const create = Vide.create
-- Vide 0.4.1 types `create` for some classes only (UIStroke, UIPadding are not among them)
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Hint: () -> string,
	Grade: () -> string | false, -- band of the last gesture, false = none shown
	Scale: () -> number,
	OnBack: () -> (),
}

const TONE: { [string]: Color3 } = {
	Perfect = Theme.Color.Mustard,
	Good = Theme.Color.Teal,
	Messy = Theme.Color.Slate,
}
const LABELS = (Content.Prep.Grades.Labels :: any) :: { [string]: string }

const Hud = {}

function Hud.Screen(props: Props): (ScreenGui, Frame)
	const dot = create("Frame")({
		Name = "PadCursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Color.Mustard,
		Visible = false,
		ZIndex = 10,
		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
	})
	const gui = create("ScreenGui")({
		Name = "CookFocus",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 4,

		create("TextLabel")({
			Name = "Hint",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -18),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.15,
			FontFace = Theme.Font.Body,
			TextSize = function()
				return math.floor(18 * props.Scale())
			end,
			TextColor3 = Theme.Color.Text,
			Text = props.Hint,
			Visible = function()
				return props.Hint() ~= ""
			end,
			createRaw("UIPadding")({
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		}),

		create("TextButton")({
			Name = "Back",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 18, 1, -18),
			Size = function()
				const scale = props.Scale()
				return UDim2.fromOffset(math.floor(96 * scale), math.floor(Theme.MinTouch * scale))
			end,
			BackgroundColor3 = Theme.Color.Cream,
			AutoButtonColor = true,
			FontFace = Theme.Font.Title,
			Text = "Back",
			TextColor3 = Theme.Color.Ink,
			TextSize = function()
				return math.floor(20 * props.Scale())
			end,
			Activated = function()
				props.OnBack()
			end,
			create("UICorner")({ CornerRadius = Theme.Radius.Card }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),

		create("TextLabel")({
			Name = "Grade",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 24),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = function()
				return math.floor(34 * props.Scale())
			end,
			TextColor3 = function()
				const band = props.Grade()
				return if band ~= false then TONE[band] or Theme.Color.Text else Theme.Color.Text
			end,
			TextStrokeColor3 = Theme.Color.Ink,
			TextStrokeTransparency = 0,
			Text = function()
				const band = props.Grade()
				return if band ~= false then LABELS[band] or band else ""
			end,
			Visible = function()
				return props.Grade() ~= false
			end,
		}),

		dot,
	})
	return gui, dot
end

return table.freeze(Hud)
