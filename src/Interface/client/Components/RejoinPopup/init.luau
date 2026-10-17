--!strict
-- RejoinPopup: "your shift is still running" card of the lobby (owner request 2026-10-17: prompt "em cima na direita"
-- asking to reconnect; DEC-063 notification top right; TASK-360, Provisional), cartoon kit (AST-091), mobile first.
-- A Cream card at the top right (300 x 136 at Scale 1, inside DeviceSafeInsets, under the Roblox top bar: its corners
-- hold Roblox buttons): sun / moon badge of the run's shift, "Your shift is still running!", "Day 3 - Night shift",
-- Rejoin (Green) and Dismiss (Slate), 44 px buttons. While `Busy` (teleport on its way) Rejoin reads "Joining..."
-- and both buttons are off. Pops in when `Offer` returns one, shrinks away when it returns nil. Pure: only props; the
-- caller answers ReconnectReply.
-- Resume offer (DEC-080, Q-291: nobody is in the run, it waits 15 min): "Your shift is on hold!", "Resume Day 7 - 12:40
-- left" counting down to `EndsAt` (on the `Now` clock), Resume button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UiScale = require(script.Parent.UiScale)
local Motion = require(script.Parent.Motion)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Offer = {
	Day: number, -- 0 = not known (run still starting)
	IsNight: boolean,
	Resume: boolean?, -- true = Resume offer (the run waits for its first member back)
	EndsAt: number?, -- Resume: when the window closes, on the `Now` clock
}

export type Props = {
	Offer: () -> Offer?,
	Busy: () -> boolean,
	OnRejoin: () -> (),
	OnDismiss: () -> (),
	Scale: (() -> number)?,
	-- clock of EndsAt (default os.clock, read once per change of the offer: pass a ticking source for the countdown)
	Now: (() -> number)?,
}

const WIDTH = 300
const HEIGHT = 136
const BADGE = 48
const BUTTON = 44
const EDGE = 8 -- px from the right edge
const TOP = 64 -- px from the top: under the Roblox top bar (same rule as LobbyHud TOPBAR_FREE)

local function clock(seconds: number): string
	const whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function shiftLine(offer: Offer, now: number): string
	if offer.Resume then
		const left = clock((offer.EndsAt or now) - now)
		if offer.Day <= 0 then
			return `Resume your shift - {left} left`
		end
		return `Resume Day {offer.Day} - {left} left`
	end
	if offer.Day <= 0 then
		return "Your squad is waiting for you."
	end
	return `Day {offer.Day} - {if offer.IsNight then "Night" else "Day"} shift`
end

return function(props: Props): Frame
	const shown = function(): boolean
		return props.Offer() ~= nil
	end
	-- keeps the last offer on screen while the card shrinks away
	const last = source({ Day = 0, IsNight = false } :: Offer)
	effect(function()
		const offer = props.Offer()
		if offer then
			last(offer)
		end
	end)
	const pop = Motion.Pop(shown)
	const scale = function(): number
		return (if props.Scale then math.max(math.min(props.Scale(), UiScale.Current()), Theme.Scale.Min) else 1) * pop()
	end
	const icon = function(): string
		return if last().IsNight then "Hud/moon" else "Hud/sun"
	end
	const enabled = function(): boolean
		return shown() and not props.Busy()
	end

	return create("Frame")({
		Name = "RejoinPopup",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -EDGE, 0, TOP),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Visible = function()
			return pop() > 0.01
		end,
		-- the card grows from its top right corner, where it is anchored
		createRaw("UIScale")({ Scale = scale }),

		CartoonPanel({
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			Tone = Theme.Tone.Cream,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Padding = 10,
			Children = {
				create("Frame")({
					Name = "Badge",
					Size = UDim2.fromOffset(BADGE, BADGE),
					BackgroundColor3 = function()
						return if last().IsNight then Theme.Tone.Violet.Top else Theme.Color.Mustard
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					createRaw("UIStroke")({ Color = Theme.Color.Dark, Thickness = 2 }),
					create("ImageLabel")({
						Name = "Icon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.78, 0.78),
						BackgroundTransparency = 1,
						Image = function()
							return Icons.ImageOf(icon())
						end,
						ImageRectOffset = function()
							const rect = Icons.Rect(icon())
							return if rect then rect.Offset else Vector2.zero
						end,
						ImageRectSize = function()
							const rect = Icons.Rect(icon())
							return if rect then rect.Size else Vector2.zero
						end,
					}),
				}),
				CartoonLabel({
					Name = "Title",
					Position = UDim2.fromOffset(BADGE + 10, 0),
					Box = UDim2.new(1, -(BADGE + 10), 0, 26),
					TextSize = 17,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = function()
						return if last().Resume then "Your shift is on hold!" else "Your shift is still on!"
					end,
				}),
				CartoonLabel({
					Name = "Shift",
					Position = UDim2.fromOffset(BADGE + 10, 26),
					Box = UDim2.new(1, -(BADGE + 10), 0, 22),
					TextSize = 15,
					XAlignment = Enum.TextXAlignment.Left,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Text = function()
						return shiftLine(last(), if props.Now then props.Now() else os.clock())
					end,
				}),
				CartoonButton({
					Name = "Rejoin",
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(0.5, -5, 0, BUTTON),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Green,
					Enabled = enabled,
					Text = function()
						if props.Busy() then
							return "Joining..."
						end
						return if last().Resume then "Resume" else "Rejoin"
					end,
					OnActivated = props.OnRejoin,
				}),
				CartoonButton({
					Name = "Dismiss",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.fromScale(1, 1),
					Size = UDim2.new(0.5, -5, 0, BUTTON),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Slate,
					Enabled = enabled,
					Text = "Dismiss",
					OnActivated = props.OnDismiss,
				}),
			},
		}),
	}) :: Frame
end
