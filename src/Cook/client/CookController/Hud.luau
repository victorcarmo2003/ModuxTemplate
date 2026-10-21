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
	-- the tutorial asks the player to step back (DEC-311): the Back button turns Mustard and pulses; os.clock() drives the pulse
	BackHint: (() -> number?)?,
	-- the live bar of the gesture in progress (owner 2026-10-19: like the old prep's progress), 0..1; nil = hidden
	Progress: (() -> number?)?,
}

const BAR = Vector2.new(280, 22) -- px of the progress bar at UI scale 1

const TONE: { [string]: Color3 } = {
	Perfect = Theme.Color.Mustard,
	Nice = Theme.Color.Green,
	Good = Theme.Color.Teal,
	Messy = Theme.Color.Slate,
}
-- the plate bands' labels plus the gesture-only "Nice" (DEC-311: Perfect / Nice / Good)
const LABELS: { [string]: string } = table.clone((Content.Prep.Grades.Labels :: any) :: { [string]: string })
LABELS.Nice = "Nice!"

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
		-- owner 2026-10-19: over the anomaly scenes' black bars (Scene/Kits Cinema, 40) so Back is never covered while
		-- cooking; still under the whispers (45) and the jumpscare
		DisplayOrder = 41,

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
			BackgroundColor3 = function(): Color3
				return if props.BackHint ~= nil and props.BackHint() ~= nil then Theme.Color.Mustard else Theme.Color.Cream
			end,
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
			createRaw("UIScale")({
				Scale = function(): number
					const clock = if props.BackHint ~= nil then props.BackHint() else nil
					return if clock ~= nil then 1 + 0.12 * (0.5 + 0.5 * math.sin(clock * 6)) else 1
				end,
			}),
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

		-- the gesture's progress, over the hint line: Mustard filling, Green once full
		create("Frame")({
			Name = "Progress",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = function(): UDim2
				return UDim2.new(0.5, 0, 1, -math.floor(64 * props.Scale()))
			end,
			Size = function(): UDim2
				const scale = props.Scale()
				return UDim2.fromOffset(math.floor(BAR.X * scale), math.floor(BAR.Y * scale))
			end,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Visible = function(): boolean
				return props.Progress ~= nil and props.Progress() ~= nil
			end,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3 }),
			create("Frame")({
				Name = "Fill",
				Position = UDim2.fromOffset(3, 3),
				Size = function(): UDim2
					const value = if props.Progress ~= nil then props.Progress() or 0 else 0
					return UDim2.new(math.clamp(value, 0, 1), -6, 1, -6)
				end,
				BackgroundColor3 = function(): Color3
					const value = if props.Progress ~= nil then props.Progress() or 0 else 0
					return if value >= 0.999 then Theme.Color.Green else Theme.Color.Mustard
				end,
				BorderSizePixel = 0,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			}),
		}),

		dot,
	})
	return gui, dot
end

return table.freeze(Hud)
