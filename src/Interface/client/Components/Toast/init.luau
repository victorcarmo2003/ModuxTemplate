--!strict
-- Toast: small notification card (style guide §7.2, "Notificação": top right, closes by itself; DEC-063).
-- Slides in, stays `Duration` seconds (clamped to 3..6), fades out, then calls OnDone so the owner
-- can drop it from its list. Pure: only props. Toast/Stack.luau places several in the top-right corner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UISizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Kind = "Info" | "Good" | "Alert"

export type Props = {
	Text: () -> string,
	Kind: (() -> Kind)?,
	-- Seconds on screen, clamped to 3..6. Default 4.
	Duration: number?,
	OnDone: (() -> ())?,
	LayoutOrder: (() -> number)?,
}

const WIDTH = 280
const TEXT_SIZE = 18
const MIN_DURATION = 3
const MAX_DURATION = 6
const OUT_TIME = 0.35
const SLIDE = 48

-- No red in the UI (style guide §7.4): Alert is Mustard.
const ACCENT: { [Kind]: Color3 } = {
	Info = Theme.Color.Teal,
	Good = Theme.Color.Green,
	Alert = Theme.Color.Mustard,
}

local function cancel(thread: thread)
	if coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

return function(props: Props): Frame
	const duration = math.clamp(props.Duration or 4, MIN_DURATION, MAX_DURATION)
	const shown = source(false)

	const enter = task.defer(function()
		shown(true)
	end)
	const leave = task.delay(duration, function()
		shown(false)
	end)
	const done = task.delay(duration + OUT_TIME, function()
		if props.OnDone then
			props.OnDone()
		end
	end)
	cleanup(function()
		cancel(enter)
		cancel(leave)
		cancel(done)
	end)

	const alpha = spring(function()
		return if shown() then 0 else 1
	end, 0.2, 1)
	const offset = spring(function()
		return if shown() then 0 else SLIDE
	end, 0.25, 0.8)

	local function accent(): Color3
		const kind: Kind = if props.Kind then props.Kind() else "Info"
		return ACCENT[kind]
	end

	return create("Frame")({
		Name = "Toast",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,

		create("CanvasGroup")({
			Name = "Card",
			Position = function()
				return UDim2.fromOffset(offset(), 0)
			end,
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,
			GroupTransparency = alpha,

			create("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			createRaw("UISizeConstraint")({ MinSize = Vector2.new(WIDTH, Theme.MinTouch) }),

			create("Frame")({
				Name = "Accent",
				Size = UDim2.new(0, 6, 1, 0),
				BackgroundColor3 = accent,
			}),

			create("TextLabel")({
				Name = "Message",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = Theme.Font.Body,
				TextSize = TEXT_SIZE,
				TextColor3 = Theme.Color.Text,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = props.Text,
				createRaw("UIPadding")({
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 12),
					PaddingBottom = UDim.new(0, 12),
				}),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
			}),
		}),
	})
end
