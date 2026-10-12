--!strict
-- HudScreen: the whole wave-1 HUD (FEAT-032; style guide §7.2, mobile first), status only (DEC-015):
--   top right  money of the party (coin, bumps when it goes up) and "Day N" / "Night" (sun / moon), then the toasts
--              (DEC-063) under them, one right-aligned column. The top LEFT is free for the Roblox menu / chat buttons
--              (user request 2026-10-12, phone playtest). Short wide screens (under 440 px tall, 520 px or wider at UI
--              scale 1) put money and day side by side, so the column stays low and clear of the jump button
--   top centre clock "8:00 AM" (DEC-048)
--   centre     end-of-shift summary (FEAT-014), fades out by itself
-- Nothing here is clickable (FEAT-032 acceptance): Frames and TextLabels only. No reputation, boss chances, XP or
-- sanity (sanity is night only, wave 2). The bottom third stays free for the hotbar, joystick and interact button.
-- Cartoon pass (AST-091): Ink pills with big icons; the money rolls up to the new value (Motion.Count) and the pill
-- jumps (Motion.Bump) when it goes up.
-- Pure: only props. Mount it inside a ScreenGui with `ScreenInsets = DeviceSafeInsets` (notch / rounded corners only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local HudPill = require(script.Parent.HudPill)
local Motion = require(script.Parent.Motion)
local Money = require(script.Parent.HudPill.Money)
local HudSummary = require(script.Parent.HudSummary)
local ToastStack = require(script.Parent.Toast.Stack)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup
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
	-- UI scale (Theme.ScaleOf). 1 = smallest phone (iPhone SE landscape); 1.4 at 1080p.
	Scale: (() -> number)?,
	-- Progressive reveal (first-run tutorial): money pill, and the clock + day pills. nil = always shown.
	ShowCash: (() -> boolean)?,
	ShowClock: (() -> boolean)?,
}

const MARGIN = 10
const TOP = 6
-- Status pills are not touchable, so they go under the 44 px touch size (user request 2026-10-11: UI too big)
const BIG = 38 -- money and clock, text 20
const SMALL = Theme.MinChip -- day pill, text 16
const ROW_GAP = 6
const SHORT = 440 -- real px tall: money and day side by side
const ROW_MIN_WIDTH = 520 -- px at UI scale 1: the row (182 px) must clear the centred clock (112 px) on both sides

return function(props: Props): Frame
	const scale = function(): number
		return if props.Scale then props.Scale() else 1
	end

	-- Shown money rolls from the old value to the new one (the bump still reads the real value).
	const rolled = Motion.Count(props.Cash)

	-- Real px size of the screen (this root fills it): decides row or column of the pills.
	const area = source(Vector2.new(1000, 700))
	const sideBySide = function(): boolean
		const real = area()
		return real.Y < SHORT and real.X / scale() >= ROW_MIN_WIDTH
	end

	const root = create("Frame")({
		Name = "HudScreen",
		-- UIScale also scales the frame itself, so the frame is shrunk by the same factor to keep covering the screen.
		Size = function()
			const s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,

		createRaw("UIScale")({ Scale = scale }),

		-- Right column: money and day on top, toasts under them (one list, never overlapping)
		create("Frame")({
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, TOP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}),

			create("Frame")({
				Name = "Status",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				create("UIListLayout")({
					FillDirection = function()
						return if sideBySide() then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
					end,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, ROW_GAP),
				}),

				HudPill({
					Name = "Cash",
					LayoutOrder = 1,
					Height = BIG,
					TextSize = 20,
					MinWidth = 96,
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
					TextSize = 16,
					MinWidth = 80,
					Icon = function(): HudPill.Icon
						return if props.IsNight() then "Moon" else "Sun"
					end,
					Text = props.Shift,
					Shown = props.ShowClock,
				}),
			}),

			ToastStack({
				Entries = props.Toasts,
				OnDone = props.OnToastDone,
				MaxVisible = 3,
			}),
		}),

		HudPill({
			Name = "Clock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOP),
			Height = BIG,
			TextSize = 20,
			MinWidth = 112,
			Icon = function(): HudPill.Icon
				return "Clock"
			end,
			Text = props.Clock,
			Shown = props.ShowClock,
		}),

		HudSummary({
			Report = props.Report,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
		}),
	}) :: Frame

	const measure = function()
		if root.AbsoluteSize.X > 0 then
			area(root.AbsoluteSize)
		end
	end
	measure()
	const connection = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		connection:Disconnect()
	end)
	return root
end
