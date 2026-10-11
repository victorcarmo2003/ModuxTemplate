--!strict
-- HudScreen: the whole wave-1 HUD (FEAT-032; style guide §7.2, mobile first), status only (DEC-015):
--   top left   money of the party (coin, bumps when it goes up) and, below it, "Day N" / "Night" (sun / moon)
--   top centre clock "8:00 AM" (DEC-048)
--   top right  toasts (DEC-063), below the clock row so they never cover it on a narrow phone
--   centre     end-of-shift summary (FEAT-014), fades out by itself
-- Nothing here is clickable (FEAT-032 acceptance): Frames and TextLabels only. No reputation, boss chances, XP or
-- sanity (sanity is night only, wave 2). The bottom third stays free for the hotbar, joystick and interact button.
-- Cartoon pass (AST-091): Ink pills with big icons; the money rolls up to the new value (Motion.Count) and the pill
-- jumps (Motion.Bump) when it goes up.
-- Pure: only props. Mount it inside a ScreenGui with `ScreenInsets = CoreUISafeInsets` (clear of the Roblox top bar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local HudPill = require(script.Parent.HudPill)
local Motion = require(script.Parent.Motion)
local Money = require(script.Parent.HudPill.Money)
local HudSummary = require(script.Parent.HudSummary)
local ToastStack = require(script.Parent.Toast.Stack)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Clock: () -> string,
	Shift: () -> string, -- "Day 3" / "Night"
	IsNight: () -> boolean,
	Cash: () -> number,
	Toasts: () -> { ToastStack.Entry },
	OnToastDone: (entry: ToastStack.Entry) -> (),
	Report: () -> HudSummary.Shown, -- false = no summary
	-- UI scale (>= 1). 1 = smallest phone (iPhone SE landscape); bigger screens grow everything proportionally.
	Scale: (() -> number)?,
	-- Progressive reveal (first-run tutorial): money pill, and the clock + day pills. nil = always shown.
	ShowCash: (() -> boolean)?,
	ShowClock: (() -> boolean)?,
}

const MARGIN = 12
const TOP = 6
const BIG = 48 -- money and clock: ~5% of a 375 px tall screen at text 24 (style guide §7.1)
const SMALL = 44 -- day pill: touch-sized minimum
const ROW_GAP = 8

return function(props: Props): Frame
	const scale = function(): number
		return if props.Scale then math.max(props.Scale(), 1) else 1
	end

	-- Shown money rolls from the old value to the new one (the bump still reads the real value).
	const rolled = Motion.Count(props.Cash)

	return create("Frame")({
		Name = "HudScreen",
		-- UIScale also scales the frame itself, so the frame is shrunk by the same factor to keep covering the screen.
		Size = function()
			const s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,

		createRaw("UIScale")({ Scale = scale }),

		create("Frame")({
			Name = "Status",
			Position = UDim2.fromOffset(MARGIN, TOP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}),

			HudPill({
				Name = "Cash",
				LayoutOrder = 1,
				Height = BIG,
				TextSize = 24,
				MinWidth = 120,
				Icon = function(): HudPill.Icon
					return "Coin"
				end,
				Text = function()
					return Money(math.floor(rolled() + 0.5))
				end,
				Bump = props.Cash,
				Shown = props.ShowCash,
			}),

			HudPill({
				Name = "Shift",
				LayoutOrder = 2,
				Height = SMALL,
				TextSize = 18,
				MinWidth = 100,
				Icon = function(): HudPill.Icon
					return if props.IsNight() then "Moon" else "Sun"
				end,
				Text = props.Shift,
				Shown = props.ShowClock,
			}),
		}),

		HudPill({
			Name = "Clock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOP),
			Height = BIG,
			TextSize = 24,
			MinWidth = 140,
			Icon = function(): HudPill.Icon
				return "Clock"
			end,
			Text = props.Clock,
			Shown = props.ShowClock,
		}),

		ToastStack({
			Entries = props.Toasts,
			OnDone = props.OnToastDone,
			MaxVisible = 3,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, TOP + BIG + ROW_GAP),
		}),

		HudSummary({
			Report = props.Report,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
		}),
	})
end
