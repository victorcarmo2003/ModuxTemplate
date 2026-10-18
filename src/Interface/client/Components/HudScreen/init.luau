--!strict
-- HudScreen: the whole wave-1 HUD (FEAT-032; style guide §7.2, mobile first), status only (DEC-015):
--   top right  "Day N" / "Night" (sun / moon) on the LEFT and the money of the party (coin, bumps when it goes up) on
--              the RIGHT, side by side, same height as the centred clock (one line). NOTHING else lives up there: the top is
--              the clock, the day and the money only (owner request 2026-10-12). The top LEFT is free for the Roblox menu /
--              chat buttons and, under them, the sanity meter and the order card (HudController).
--              Narrow screens (under 560 px at UI scale 1, portrait) stack the two pills in a column.
--              Right of them, a column of round buttons (owner request 2026-10-14), always on screen (no progressive
--              reveal): the settings gear (GearButton, TASK-279) and under it the shop cart (CartButton, TASK-290), each
--              with its key under it (KeyHint: "M" / "B", the pad button on a controller, nothing on touch). A button
--              only shows when its callback (`OnSettings`, `OnShop`) is given.
--              Under the column, the quick note (HudNudge, TASK-290): `Nudge` text, "" = hidden; click = `OnNudge`
--   top centre clock "8:00 AM" (DEC-048)
--   bottom     toasts (DEC-063): bottom centre, above the hotbar and the call subtitle, stacking up, with side margins that
--              keep them off the joystick (left) and the jump button (right)
--   centre     end-of-shift summary (FEAT-014), fades out by itself
-- Down / out (TASK-485, DEC-294): `Calm()` true = the clean faint screen: clock, day, money, the shop cart and the
-- quick note go away (the settings gear and the toasts stay). The owner also hides the nudge text.
-- Progressive reveal (Content.HudReveal): `Reveal(key)` says whether the element of that row is on screen yet; the pills
-- scale in (0.25 s) when it turns true. nil = everything shown.
-- Nothing here is clickable (FEAT-032 acceptance) except the settings gear (TASK-279): Frames and TextLabels only. No reputation, boss chances, XP or
-- sanity (sanity is night only, wave 2). The bottom third stays free for the hotbar, joystick and interact button.
-- Cartoon pass (AST-091): Ink pills with big icons; the money rolls up to the new value (Motion.Count) and the pill
-- jumps (Motion.Bump) when it goes up.
-- Pure: only props. Mount it inside a ScreenGui with `ScreenInsets = DeviceSafeInsets` (notch / rounded corners only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local HudPill = require(script.Parent.HudPill)
local Motion = require(script.Parent.Motion)
local Money = require(script.Parent.HudPill.Money)
local HudSummary = require(script.Parent.HudSummary)
local GearButton = require(script.Parent.GearButton)
local CartButton = require(script.Parent.CartButton)
local KeyHint = require(script.Parent.KeyHint)
local HudNudge = require(script.Parent.HudNudge)
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
	-- Progressive reveal (Content.HudReveal): keys "clock", "shift", "money", "toasts". nil = always shown.
	Reveal: ((key: string) -> boolean)?,
	-- Clean faint screen: hides clock, day, money and the shop cart (nil = never).
	Calm: (() -> boolean)?,
	-- Settings gear (TASK-279): pressed -> toggle the settings panel; nil = no gear. SettingsOpen turns it Mustard.
	OnSettings: (() -> ())?,
	SettingsOpen: (() -> boolean)?,
	-- Shop cart (TASK-290): pressed -> toggle the shop; nil = no cart. ShopOpen turns it Mustard, ShopGlow rings it.
	OnShop: (() -> ())?,
	ShopOpen: (() -> boolean)?,
	ShopGlow: (() -> boolean)?,
	-- Input device for the key labels (InputController.Device); nil = keyboard
	Device: (() -> KeyHint.Device)?,
	-- Quick note under the buttons ("" = hidden) and its click
	Nudge: (() -> string)?,
	OnNudge: (() -> ())?,
	-- Icons name left of the note (contextual offers, TASK-363); "" = none
	NudgeIcon: (() -> string)?,
	-- controller button image of the note while it is an offer (TASK-363); "" = the shop button image
	NudgePad: (() -> string)?,
}

const MARGIN = 10
const TOP = 6
-- Status pills are not touchable, so they go under the 44 px touch size (user request 2026-10-11: UI too big)
const BIG = 32 -- money, day and clock: ONE height, text size and outline so they sit on the same line (2026-10-12; 38 -> 32 owner 2026-10-17)
const BIG_TEXT = 17
-- round buttons on touch (gear, cart): a bit under the 44 px target, the pair sits in the corner (owner 2026-10-17: too big)
const TOUCH_BUTTON = 38
const ROW_GAP = 6
const ROW_MIN_WIDTH = 520 -- px at UI scale 1: the row (day 84 + money 84 + gaps + buttons) must clear the centred clock (96 px)
-- Toasts (owner request 2026-10-12): bottom centre, stacking up. The bottom edge sits above the Roblox hotbar (84 px, as
-- the call subtitle) and the subtitle strip itself; the side margin keeps the column off the joystick and the jump button.
const TOAST_BOTTOM = 140
const TOAST_SIDE = 180 -- px at UI scale 1 kept free on each side (>= 180)
const TOAST_WIDTH = 220
const TOAST_MIN_WIDTH = 140 -- portrait phones cannot keep 180 px on both sides: the card shrinks to this
const SHOP_PAD = Enum.KeyCode.DPadRight -- the controller button of the shop (ShopController)
const NUDGE_TOP = 128 -- px under TOP: below the gear / cart column (2 x 38 + 2 key labels + gaps)
const SHORT_SCREEN = 480 -- px at UI scale 1: under this height 2 toasts show at a time, not 3

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
		return real.X / scale() >= ROW_MIN_WIDTH
	end
	const shopPad = (function(): string
		const ok, image = pcall(function()
			return UserInputService:GetImageForKeyCode(SHOP_PAD)
		end)
		return if ok and type(image) == "string" then image else ""
	end)()
	const device = function(): KeyHint.Device
		return if props.Device then props.Device() else "KeyboardMouse"
	end
	-- round buttons: pill height with a mouse / controller, a full touch target on a touch screen
	const buttonSize = function(): number
		return if device() == "Touch" then TOUCH_BUTTON else BIG
	end
	const calm = function(): boolean
		return props.Calm ~= nil and props.Calm()
	end
	const revealed = function(key: string): boolean
		return not calm() and (props.Reveal == nil or props.Reveal(key))
	end
	const toastWidth = function(): number
		return math.clamp(area().X / scale() - TOAST_SIDE * 2, TOAST_MIN_WIDTH, TOAST_WIDTH)
	end
	const toastCount = function(): number
		return if area().Y / scale() < SHORT_SCREEN then 2 else 3
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

		-- Right column: day and money, then the settings gear on their right; nothing under them
		create("Frame")({
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -MARGIN, 0, TOP),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}),

			create("Frame")({
				Name = "Buttons",
				LayoutOrder = 2,
				Size = function()
					return UDim2.fromOffset(buttonSize(), 0)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = props.OnSettings ~= nil or props.OnShop ~= nil,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),

				if props.OnSettings
					then GearButton({
						Name = "Settings",
						LayoutOrder = 1,
						Size = buttonSize,
						Open = props.SettingsOpen,
						OnActivated = props.OnSettings,
					})
					else nil,
				if props.OnSettings
					then KeyHint({
						Name = "SettingsKey",
						LayoutOrder = 2,
						Width = BIG,
						Device = device,
						Key = Enum.KeyCode.M,
						Pad = Enum.KeyCode.ButtonSelect,
						PadText = "Select",
					})
					else nil,
				if props.OnShop
					then CartButton({
						Name = "Shop",
						LayoutOrder = 3,
						Size = buttonSize,
						Open = props.ShopOpen,
						Glow = props.ShopGlow,
						OnActivated = props.OnShop,
						Visible = function()
							return not calm()
						end,
					})
					else nil,
				if props.OnShop
					then KeyHint({
						Name = "ShopKey",
						LayoutOrder = 4,
						Width = BIG,
						Device = device,
						Key = Enum.KeyCode.B,
						Pad = SHOP_PAD,
						PadText = "Right",
						Visible = function()
							return not calm()
						end,
					})
					else nil,
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
					LayoutOrder = 2,
					Height = BIG,
					TextSize = BIG_TEXT,
					MinWidth = 84,
					Icon = function(): HudPill.Icon
						return "Coin"
					end,
					Text = function()
						return Money(math.floor(rolled() + 0.5))
					end,
					Bump = props.Cash,
					Shown = function()
						return revealed("money")
					end,
				}),

				HudPill({
					Name = "Shift",
					LayoutOrder = 1,
					Height = BIG,
					TextSize = BIG_TEXT,
					MinWidth = 84,
					Icon = function(): HudPill.Icon
						return if props.IsNight() then "Moon" else "Sun"
					end,
					Text = props.Shift,
					Shown = function()
						return revealed("shift")
					end,
				}),
			}),
		}),

		HudNudge({
			Name = "Nudge",
			AnchorPoint = Vector2.new(1, 0),
			Position = function()
				-- under the button column (taller on touch: no key labels, bigger buttons)
				return UDim2.new(1, -MARGIN, 0, TOP + (if device() == "Touch" then TOUCH_BUTTON * 2 + 12 else NUDGE_TOP))
			end,
			Text = function()
				return if props.Nudge and not calm() then props.Nudge() else ""
			end,
			Icon = function()
				return if props.NudgeIcon then props.NudgeIcon() else ""
			end,
			Pad = function()
				if device() ~= "Gamepad" then
					return ""
				end
				const offerPad = if props.NudgePad then props.NudgePad() else ""
				return if offerPad ~= "" then offerPad else shopPad
			end,
			PadText = "Right",
			Touch = function()
				return device() == "Touch"
			end,
			OnActivated = function()
				if props.OnNudge then
					props.OnNudge()
				end
			end,
		}),

		ToastStack({
			Entries = props.Toasts,
			OnDone = props.OnToastDone,
			MaxVisible = toastCount,
			Width = toastWidth,
			Direction = "Up",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -TOAST_BOTTOM),
			Visible = function()
				return props.Reveal == nil or props.Reveal("toasts") -- toasts stay on the faint screen (crew news)
			end,
		}),

		HudPill({
			Name = "Clock",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOP),
			Height = BIG,
			TextSize = BIG_TEXT,
			MinWidth = 96,
			Icon = function(): HudPill.Icon
				return "Clock"
			end,
			Text = props.Clock,
			Shown = function()
				return revealed("clock")
			end,
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
