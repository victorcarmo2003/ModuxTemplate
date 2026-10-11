--!strict
-- One "+$N" over the drawer (style guide §10 "Pagamento": "+$7" rising). Rises from just above the value pill,
-- fades out over the last part of the flight, then calls OnDone so the owner drops it from its list.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local UseTween = require(script.Parent.Parent.UseTween)
local Motion = require(script.Parent.Parent.Motion)
local CartoonLabel = require(script.Parent.Parent.CartoonLabel)

const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Entry = {
	Amount: number,
}

export type Options = {
	-- Pixel y (from the gui top) where the pop starts: the top edge of the value pill.
	Bottom: number,
	OnDone: () -> (),
}

const DURATION = 1.2
const FADE_AT = 0.7
const RISE = 70
const TEXT_SIZE = 28
const HEIGHT = 34

local function cancel(thread: thread)
	if coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

const Pop = {}

function Pop.Render(entry: Entry, options: Options): TextLabel
	const flying = source(false)
	const fading = source(false)

	const start = task.defer(function()
		flying(true)
	end)
	const fade = task.delay(FADE_AT, function()
		fading(true)
	end)
	const done = task.delay(DURATION, options.OnDone)
	cleanup(function()
		cancel(start)
		cancel(fade)
		cancel(done)
	end)

	const position = UseTween(function()
		const y = options.Bottom - (if flying() then RISE else 0)
		return UDim2.new(0.5, 0, 0, y)
	end, DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	const alpha = spring(function()
		return if fading() then 1 else 0
	end, 0.15, 1)

	-- Cartoon pass: fat Mustard "+$N" with a heavy Ink stroke that pops in with overshoot while it rises.
	const scale = Motion.Pop(flying)

	return CartoonLabel({
		Name = "Pop",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Box = UDim2.fromOffset(160, HEIGHT),
		TextSize = TEXT_SIZE,
		Color = Theme.Color.Mustard,
		Stroke = 3,
		Transparency = alpha,
		Rotation = -6,
		Text = "+$" .. tostring(math.floor(entry.Amount)),
		ZIndex = 2,
		Children = {
			createRaw("UIScale")({ Scale = scale }),
		},
	})
end

return table.freeze(Pop)
