--!strict
-- HudSanity: night sanity meter (FEAT-019, DEC-056, DEC-167; style guide §7.2; ui-text.md §12.1). Top centre, under
-- the clock. No word on it (Q-054): the portrait of the band face on the left + a bar + the number (no "/max": the
-- max changes by class). Bar fill goes from `#FFD45A` (full) to `#6A5ACD` (empty); below 25 it breathes slowly.
-- Never red, no heart, no skull.
-- Portrait until AST-086 (TASK-093): the class icon of the AST-071 sheet (`Class/class_<x>`, Day head render) on the
-- species fur colour; species letter when the icon is missing. The band shows as the ring colour (Day warm, Mid
-- between, Night violet) and a darker portrait on Night.
-- The owner hides it with `Shown` (Max > 0 and own state Active). Status only: nothing clickable (FEAT-032).
-- Cartoon pass (AST-091 "Barra de sanidade"): portrait in a thick band ring with an Ink outline, the bar is an Ink
-- CartoonPanel track with a glossy two-tone fill, the number with a heavy Ink stroke.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UISizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Band = "Day" | "Mid" | "Night"

export type Props = {
	Value: () -> number,
	Max: () -> number,
	Band: () -> Band,
	-- false hides the whole meter (day, Down, Spectator).
	Shown: () -> boolean,
	-- Portrait: AST-071 icon name ("Class/class_fox"); "" or unknown -> the letter on the fur colour (CrewLooks).
	Icon: (() -> string)?,
	Letter: () -> string,
	Fur: () -> Color3,
	-- Bar width as a fraction of the screen width (style guide: 30%). Default 0.3.
	Width: number?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const FULL = Color3.fromHex("#FFD45A")
const EMPTY = Theme.Color.Violet -- #6A5ACD
const MID_RING = FULL:Lerp(EMPTY, 0.5)
const PORTRAIT = 48 -- touch-sized circle (not clickable, but readable at a glance)
const BAR_HEIGHT = 26
const MIN_BAR = 140
const MAX_BAR = 320
const TEXT_SIZE = 20
const GAP = 8
const VALUE_WIDTH = 40 -- "100" at TEXT_SIZE
-- Offset width of everything that is not the bar: portrait, gaps, number
const SIDES = PORTRAIT + GAP * 2 + VALUE_WIDTH
-- style guide §7.2: "abaixo de 25 pulsa devagar"
const PULSE_BELOW = 25
const PULSE_HZ = 0.5
const PULSE_DEPTH = 0.35

const RING: { [Band]: Color3 } = {
	Day = FULL,
	Mid = MID_RING,
	Night = EMPTY,
}

-- Ink or white letter, whichever reads better on the fur.
local function letterColor(fur: Color3): Color3
	const luminance = 0.299 * fur.R + 0.587 * fur.G + 0.114 * fur.B
	return if luminance > 0.6 then Theme.Color.Ink else Theme.Color.Text
end

local function portrait(props: Props): Frame
	const fur = function(): Color3
		const base = props.Fur()
		return if props.Band() == "Night" then base:Lerp(Theme.Color.Ink, 0.35) else base
	end
	const icon = function(): string
		const name = if props.Icon then props.Icon() else ""
		return if Icons.Has(name) then name else ""
	end
	const rect = function(): Icons.Rect
		return Icons.Rect(icon()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	-- Band ring (thick, coloured) inside an Ink outline, the portrait disc inside the ring.
	return create("Frame")({
		Name = "Portrait",
		Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
		BackgroundColor3 = function()
			return RING[props.Band()]
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Outline.Normal }),
		create("Frame")({
			Name = "Disc",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundColor3 = fur,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
			createRaw("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 195)),
			}),
			CartoonLabel({
				Name = "Letter",
				Box = UDim2.fromScale(1, 1),
				TextSize = 24,
				Color = function()
					return letterColor(fur())
				end,
				Stroke = 0,
				Text = props.Letter,
				Visible = function()
					return icon() == ""
				end,
			}),
			create("ImageLabel")({
				Name = "Icon",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = Icons.Image,
				ImageRectOffset = function()
					return rect().Offset
				end,
				ImageRectSize = function()
					return rect().Size
				end,
				ImageColor3 = function()
					return if props.Band() == "Night" then Color3.new(0.65, 0.65, 0.72) else Color3.new(1, 1, 1)
				end,
				Visible = function()
					return icon() ~= ""
				end,
				create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			}),
		}),
	})
end

return function(props: Props): Frame
	const widthScale = props.Width or 0.3

	const ratio = function(): number
		const max = props.Max()
		return if max > 0 then math.clamp(props.Value() / max, 0, 1) else 0
	end
	const fill = spring(ratio, 0.25, 1)

	-- Slow breathing below PULSE_BELOW: a per-frame phase only while low and shown.
	const pulse = source(0)
	effect(function()
		if not (props.Shown() and props.Max() > 0 and props.Value() < PULSE_BELOW) then
			if untrack(pulse) ~= 0 then
				pulse(0)
			end
			return
		end
		const connection = RunService.Heartbeat:Connect(function()
			pulse((math.sin(os.clock() * 2 * math.pi * PULSE_HZ) + 1) / 2)
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	return create("Frame")({
		Name = props.Name or "HudSanity",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position or UDim2.fromScale(0.5, 0),
		-- The bar takes `Width` of the screen; portrait and number are added on its sides.
		Size = UDim2.new(widthScale, SIDES, 0, PORTRAIT),
		BackgroundTransparency = 1,
		Visible = props.Shown,
		createRaw("UISizeConstraint")({
			MinSize = Vector2.new(MIN_BAR + SIDES, PORTRAIT),
			MaxSize = Vector2.new(MAX_BAR + SIDES, PORTRAIT),
		}),

		portrait(props),

		-- Bar: Ink track (style guide §7.2), glossy fill by sanity / max.
		CartoonPanel({
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, PORTRAIT + GAP, 0.5, 0),
			Size = UDim2.new(1, -SIDES, 0, BAR_HEIGHT),
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Normal,
			Lip = 0,
			Gloss = false,
			Padding = 3,
			Children = {
				create("Frame")({
					Name = "Fill",
					Size = function()
						return UDim2.fromScale(math.clamp(fill(), 0, 1), 1)
					end,
					Visible = function()
						return fill() > 0.005
					end,
					BackgroundColor3 = function()
						return EMPTY:Lerp(FULL, math.clamp(fill(), 0, 1))
					end,
					BackgroundTransparency = function()
						return pulse() * PULSE_DEPTH
					end,
					create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					createRaw("UIGradient")({
						Rotation = 90,
						Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
					}),
					create("Frame")({
						Name = "Gloss",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 2),
						Size = UDim2.new(1, -8, 0.32, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.55,
						create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					}),
				}),
			},
		}),

		CartoonLabel({
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Box = UDim2.fromOffset(VALUE_WIDTH, PORTRAIT),
			TextSize = TEXT_SIZE,
			XAlignment = Enum.TextXAlignment.Left,
			Text = function()
				return tostring(math.floor(props.Value()))
			end,
		}),
	})
end
