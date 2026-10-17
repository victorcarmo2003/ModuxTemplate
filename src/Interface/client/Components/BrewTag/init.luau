--!strict
-- BrewTag: the compact plate over the trailer coffee machine (FEAT-021, TASK-328; owner request 2026-10-17, Provisional).
-- Same family as StockCounter (the "4/20" pill on the machine): an Ink pill with a round coffee badge on its left end,
-- a fat bar and the seconds left. It replaces the small brew bar and the big "Brewing" word.
--   Brewing   Mustard badge and bar, seconds of the brew
--   Cooldown  Teal badge and bar, time until the machine can brew again (0:42)
--   Ready     Green badge, "Ready!" in place of the bar
-- Fixed pixel size (not studs), like StockCounter: readable on a phone at any distance. Every outline stays inside the
-- BillboardGui (insets), so no stroke is clipped at the edges. Not AlwaysOnTop. Pure: only props; build it inside a
-- Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Cinematic = require(script.Parent.Parent.Cinematic)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIGradient are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Mode = "Brewing" | "Cooldown" | "Ready"

export type Props = {
	Adornee: Instance?,
	Visible: () -> boolean,
	Mode: () -> Mode,
	-- 0..1 of the current wait (Brewing / Cooldown).
	Progress: () -> number,
	-- Seconds left of the current wait.
	Seconds: () -> number,
	StudsOffset: Vector3?,
	MaxDistance: number?,
	Name: string?,
}

const WIDTH = 140 -- px, the whole plate (badge + pill)
const HEIGHT = 34
const BADGE = 30 -- round badge, left end
const PILL_HEIGHT = 24
const INSET = 3 -- room for the outlines inside the BillboardGui
const BAR_HEIGHT = 10
const TIME_WIDTH = 28
const TEXT_SIZE = 15
const ICON = "Item/coffee"

local function toneOf(mode: Mode): Theme.Tone
	if mode == "Brewing" then
		return Theme.Tone.Mustard
	elseif mode == "Cooldown" then
		return Theme.Tone.Teal
	end
	return Theme.Tone.Green
end

-- 7 -> "7s", 75 -> "1:15"
local function clockText(seconds: number): string
	const whole = math.max(0, math.ceil(seconds))
	if whole < 60 then
		return `{whole}s`
	end
	return string.format("%d:%02d", whole // 60, whole % 60)
end

return function(props: Props): BillboardGui
	const waiting = function(): boolean
		return props.Mode() ~= "Ready"
	end
	const icon = Icons.Rect(ICON)
	return create("BillboardGui")({
		Name = props.Name or "BrewTag",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		StudsOffset = props.StudsOffset or Vector3.zero,
		MaxDistance = props.MaxDistance or 40,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		-- Off while a cinematic owns the screen (Interface/Cinematic).
		Enabled = function()
			return props.Visible() and not Cinematic.Active()
		end,

		create("Frame")({
			Name = "Root",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			-- Ink pill: starts under the badge centre, the badge overlaps its left end
			CartoonPanel({
				Name = "Pill",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, INSET + BADGE / 2, 0.5, 0),
				Size = UDim2.new(1, -(INSET * 2 + BADGE / 2), 0, PILL_HEIGHT),
				Tone = Theme.Tone.Ink,
				Transparency = Theme.Transparency.Panel,
				Lip = 3,
				Padding = { Left = BADGE / 2 + 5, Right = 7 },
				Children = {
					-- track + fill (Brewing / Cooldown)
					create("Frame")({
						Name = "Track",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.new(1, -(TIME_WIDTH + 4), 0, BAR_HEIGHT),
						BackgroundColor3 = Theme.Tone.Ink.Top, -- a step lighter than the pill: the empty part reads
						Visible = waiting,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						create("Frame")({
							Name = "Fill",
							Size = function()
								return UDim2.fromScale(math.clamp(props.Progress(), 0, 1), 1)
							end,
							-- white: the gradient multiplies it into the mode's two tones
							BackgroundColor3 = Color3.new(1, 1, 1),
							create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							createRaw("UIGradient")({
								Rotation = 90,
								Color = function()
									const tone = toneOf(props.Mode())
									return ColorSequence.new(tone.Top, tone.Bottom)
								end,
							}),
						}),
					}),
					CartoonLabel({
						Name = "Time",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Box = UDim2.new(0, TIME_WIDTH, 1, 0),
						TextSize = TEXT_SIZE,
						XAlignment = Enum.TextXAlignment.Right,
						Text = function()
							return clockText(props.Seconds())
						end,
						Visible = waiting,
					}),
					CartoonLabel({
						Name = "Ready",
						Box = UDim2.fromScale(1, 1),
						TextSize = TEXT_SIZE,
						Text = "Ready!",
						Visible = function()
							return not waiting()
						end,
					}),
				},
			}),

			-- round coffee badge, coloured by the mode
			create("Frame")({
				Name = "Badge",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, INSET, 0.5, 0),
				Size = UDim2.fromOffset(BADGE - INSET, BADGE - INSET),
				BackgroundColor3 = function()
					return toneOf(props.Mode()).Bottom
				end,
				ZIndex = 2,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({
					Color = Theme.Color.Ink,
					Thickness = 2.5,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				create("ImageLabel")({
					Name = "Cup",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.82, 0.82),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Fit,
					Image = Icons.ImageOf(ICON),
					ImageRectOffset = if icon then icon.Offset else Vector2.zero,
					ImageRectSize = if icon then icon.Size else Vector2.zero,
					Visible = icon ~= nil,
					ZIndex = 3,
				}),
			}),
		}),
	})
end
