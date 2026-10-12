--!strict
-- PatienceBar: the customer's patience over its head, one bar per clock (Q-192, Provisional).
--   Queue  (from Q1 until "Take Order")      bar blue -> yellow, clock icon
--   Order  ("Take Order" until it is served) bar green -> red, hot dog (bun) icon
-- When the phase changes (the player attends the customer) the badge bumps and the bar restarts full. Pure: only
-- props; CustomerController owns the data and places it above the order bubble through `Lift`.
-- Fixed pixel size like OrderBubble (BillboardGui: the global ScreenGui UI scale does not reach it); big enough to
-- read from MaxDistance and well above the 14 px text floor (no text here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local Motion = require(script.Parent.Motion)
local Bar = require(script.Parent.ProgressBar.Bar)

const create = Vide.create
const effect = Vide.effect
const source = Vide.source
const untrack = Vide.untrack
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Phase = "Queue" | "Order"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- Which clock runs.
	Phase: () -> Phase,
	-- Patience left in the running phase, 0..1.
	Fraction: () -> number,
	-- Empty pixels under the bar (clears the order bubble / prompt pill under it). Re-read when it changes.
	Lift: (() -> number)?,
	-- Below this fraction the Queue bar turns yellow. Default 1/3.
	WarnAt: number?,
	Offset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const BADGE = 32 -- icon badge side (px)
const BAR_W = 96
const BAR_H = 18
const GAP = 4
const WIDTH = BADGE + GAP + BAR_W

const QUEUE_ICON = "Ui/clock"
const ORDER_ICON = "Item/hot_dog"
const QUEUE_BLUE = Theme.Color.Teal
const QUEUE_YELLOW = Theme.Color.Mustard
const ORDER_GREEN = Theme.Color.Green
const ORDER_MID = Theme.Color.Mustard
const ORDER_RED = Theme.Color.Low

-- Bar color by phase and what is left (pure; also used by the story).
local function colorOf(phase: Phase, fraction: number, warnAt: number): Color3
	if phase == "Queue" then
		return if fraction > warnAt then QUEUE_BLUE else QUEUE_YELLOW
	end
	if fraction > 0.5 then
		return ORDER_MID:Lerp(ORDER_GREEN, (fraction - 0.5) * 2)
	end
	return ORDER_RED:Lerp(ORDER_MID, math.clamp(fraction * 2, 0, 1))
end

local function badgeIcon(phase: () -> Phase): GuiObject
	local function name(): string
		return if phase() == "Queue" then QUEUE_ICON else ORDER_ICON
	end
	local function rect(): Icons.Rect
		return Icons.Rect(name()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	return create("ImageLabel")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = function()
			return Icons.ImageOf(name())
		end,
		ImageRectOffset = function()
			return rect().Offset
		end,
		ImageRectSize = function()
			return rect().Size
		end,
		ZIndex = 3,
	})
end

local PatienceBar = function(props: Props): BillboardGui
	const warnAt = props.WarnAt or 1 / 3
	const liftOf = props.Lift or function(): number
		return 0
	end

	-- counts up on every phase change: the badge bumps (Motion.Bump springs on a rising number)
	const swaps = source(0)
	local lastPhase = untrack(props.Phase)
	effect(function()
		const phase = props.Phase()
		if phase ~= lastPhase then
			lastPhase = phase
			swaps(untrack(swaps) + 1)
		end
	end)
	const bump = Motion.Bump(swaps, 1.4, 0.25)

	return create("BillboardGui")({
		Name = props.Name or "PatienceBar",
		Adornee = props.Adornee,
		Size = function()
			return UDim2.fromOffset(WIDTH, BADGE + math.max(liftOf(), 0))
		end,
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = true,
		StudsOffsetWorldSpace = props.Offset or Vector3.new(0, 1.5, 0),
		MaxDistance = props.MaxDistance or 60,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		create("Frame")({
			Name = "Row",
			Size = UDim2.fromOffset(WIDTH, BADGE),
			BackgroundTransparency = 1,

			CartoonPanel({
				Name = "Badge",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(BADGE, BADGE),
				Tone = function()
					return if props.Phase() == "Queue" then Theme.Tone.Teal else Theme.Tone.Green
				end,
				Outline = Theme.Outline.Normal,
				Radius = UDim.new(0.5, 0),
				Lip = 2,
				ZIndex = 2,
				Children = {
					createRaw("UIScale")({ Scale = bump }),
					badgeIcon(props.Phase),
				},
			}),

			create("Frame")({
				Name = "Bar",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(BAR_W, BAR_H),
				BackgroundTransparency = 1,
				Bar({
					Progress = function()
						return math.clamp(props.Fraction(), 0, 1)
					end,
					FillColor = function()
						return colorOf(props.Phase(), props.Fraction(), warnAt)
					end,
				}),
			}),
		}),
	})
end

return PatienceBar
