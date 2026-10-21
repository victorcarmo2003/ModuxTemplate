--!strict
-- HudSanity: night sanity meter (FEAT-019, DEC-056, DEC-167; style guide §7.2; ui-text.md §12.1). Top LEFT, just under
-- the Roblox menu / chat bar (owner request 2026-10-12; HudController places it), COMPACT so it is as small as that bar.
-- No word on it (Q-054): the portrait of the class animal on the left + a bar + the number (no "/max": the max changes
-- by class). Bar fill goes from `#FFD45A` (full) to `#6A5ACD` (empty); below 25 it breathes slowly.
-- Never red, no heart, no skull.
-- Sizes (px at UI scale 1): Compact (phone) portrait 34, bar 110 x 10, number 11 px (owner's number; smaller than the
-- 14 px rule on purpose, it only repeats the bar); desktop portrait 44, bar 180 x 14, number 15 px.
-- Reveal (Content.HudReveal): `Revealed` pops it in (Motion.RevealPop); `Intro` = true makes a Mustard ring pulse
-- around it, once, the first time it is shown and revealed (night 1 presentation).
-- Portrait until AST-086 (TASK-093): the class icon of the AST-071 sheet (`Class/class_<x>`, Day head render) on the
-- species fur colour; species letter when the icon is missing. The band shows as the ring colour (Day warm, Mid
-- between, Night violet) and a darker portrait on Night.
-- The owner hides it with `Shown` (Max > 0 and own state Active). Status only: nothing clickable (FEAT-032).
-- Cartoon pass (AST-091 "Barra de sanidade"): portrait in a thick band ring with an Ink outline, the bar is an Ink
-- CartoonPanel track with a glossy two-tone fill, the number with a heavy Ink stroke.
-- Coffee lesson (user request 2026-10-11, Provisional): `Emphasis` makes a Mustard ring breathe around the bar (Night 1,
-- until the first coffee); `Gain` = a coffee gave N: a Green flash over the bar, a Green ring and a floating "+N".
-- TASK-479 (owner feedback 2026-10-18, Provisional): the gain is bigger and shorter (GAIN_TIME): the whole meter pops
-- (GAIN_POP), the "+N" is larger and pops in, the number flashes Green. Reduced motion: no pop, only the fades.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
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

-- A new table (new Id) = a new gain to play
export type Gain = { Amount: number, Id: number }

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
	-- Phone-sized layout (portrait 34, bar 110 x 10). false/nil = desktop (44, 180 x 14).
	Compact: (() -> boolean)?,
	-- Progressive reveal: scales in when true, away when false. nil = always.
	Revealed: (() -> boolean)?,
	-- true = the meter pulses a ring once, the first time it is shown and revealed. nil = never.
	Intro: (() -> boolean)?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: (UDim2 | () -> UDim2)?,
	-- Breathing Mustard ring around the bar while true (Night 1 coffee lesson).
	Emphasis: (() -> boolean)?,
	-- Last coffee gain; each new value flashes the bar green and floats "+Amount".
	Gain: (() -> Gain?)?,
}

const FULL = Color3.fromHex("#FFD45A")
const EMPTY = Theme.Color.Violet -- #6A5ACD
const MID_RING = FULL:Lerp(EMPTY, 0.5)

type Dims = {
	Portrait: number, -- circle (not clickable)
	Bar: number, -- bar track width
	BarHeight: number,
	Text: number, -- number size
	Gap: number,
	ValueWidth: number, -- "100" at Text
	Ring: number, -- band ring thickness around the disc
	Outline: number, -- Ink outline of the portrait and the bar
	Stroke: number, -- Ink stroke of the number
}

const COMPACT: Dims = { Portrait = 34, Bar = 110, BarHeight = 10, Text = 11, Gap = 6, ValueWidth = 24, Ring = 3, Outline = 2, Stroke = 1 }
const LARGE: Dims = { Portrait = 44, Bar = 180, BarHeight = 14, Text = 15, Gap = 8, ValueWidth = 34, Ring = 4, Outline = 3, Stroke = 2 }
const BAR_PAD = 2 -- px between the track outline and the fill
const INTRO_TIME = 2.4 -- s of the presentation pulse (3 beats)
const INTRO_BEATS = 3
const INTRO_GROW = 8 -- px the ring swells at a beat
const REVEAL_FROM = 0.6 -- scale at the start of the reveal
-- style guide §7.2: "abaixo de 25 pulsa devagar"
const PULSE_BELOW = 25
const PULSE_HZ = 0.5
const PULSE_DEPTH = 0.35
const HINT_HZ = 1.2 -- breathing of the emphasis ring
const HINT_RING = 3 -- px the ring sits outside the bar
const GAIN_TIME = 1.2 -- s of the green flash and the floating number
const GAIN_COLOR = Color3.fromHex("#7BE08A")
const GAIN_RISE = 16 -- px the "+N" drifts down while it fades
const GAIN_TEXT = 26
const GAIN_POP = 0.18 -- extra scale of the whole meter at the peak of the gain
const GAIN_POP_TIME = 0.35 -- s of the meter pop (the start of GAIN_TIME)
const GAIN_LABEL_FROM = 0.4 -- scale the "+N" pops in from

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


local function portrait(props: Props, dims: () -> Dims): Frame
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
		Size = function()
			const size = dims().Portrait
			return UDim2.fromOffset(size, size)
		end,
		BackgroundColor3 = function()
			return RING[props.Band()]
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		createRaw("UIStroke")({
			Color = Theme.Color.Ink,
			Thickness = function()
				return dims().Outline
			end,
		}),
		create("Frame")({
			Name = "Disc",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				const inset = dims().Ring * 2
				return UDim2.new(1, -inset, 1, -inset)
			end,
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
				TextSize = 16,
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
	const dims = function(): Dims
		return if props.Compact ~= nil and props.Compact() then COMPACT else LARGE
	end
	-- Offset x of the bar track (portrait + gap)
	const barX = function(): number
		const d = dims()
		return d.Portrait + d.Gap
	end

	const ratio = function(): number
		const max = props.Max()
		return if max > 0 then math.clamp(props.Value() / max, 0, 1) else 0
	end
	const fill = spring(ratio, 0.25, 1)

	-- Progressive reveal: pops in (Motion.RevealPop; instant with reduced motion)
	const reveal = Motion.RevealPop(function()
		return props.Revealed == nil or props.Revealed()
	end)

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

	-- Emphasis ring: breathes while the owner says so and the meter is shown.
	const hint = source(0)
	effect(function()
		const on = props.Emphasis ~= nil and props.Emphasis() and props.Shown() and props.Max() > 0
		if not on then
			if untrack(hint) ~= 0 then
				hint(0)
			end
			return
		end
		const connection = RunService.Heartbeat:Connect(function()
			hint((math.sin(os.clock() * 2 * math.pi * HINT_HZ) + 1) / 2)
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	-- Gain flash: progress 0..1 of the last gain (1 = idle), the amount shown by the label.
	const gain = source(1)
	const gainAmount = source(0)
	effect(function()
		const event = if props.Gain then props.Gain() else nil
		if event == nil then
			return
		end
		const started = os.clock()
		untrack(function()
			gainAmount(event.Amount)
			gain(0)
		end)
		const connection = RunService.Heartbeat:Connect(function()
			gain(math.clamp((os.clock() - started) / GAIN_TIME, 0, 1))
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	-- 0..1 bump of the meter at the start of a gain (one overshooting beat); 0 with reduced motion
	const gainPop = function(): number
		const t = gain() * GAIN_TIME / GAIN_POP_TIME
		if t >= 1 or Motion.Reduced() then
			return 0
		end
		return math.sin(t * math.pi) * (1 - t * 0.4)
	end
	-- scale of the "+N": pops from GAIN_LABEL_FROM with a small overshoot, then holds
	const gainLabelScale = function(): number
		if Motion.Reduced() then
			return 1
		end
		const t = math.clamp(gain() * GAIN_TIME / 0.25, 0, 1)
		const back = 1.7
		const eased = 1 + (back + 1) * (t - 1) ^ 3 + back * (t - 1) ^ 2 -- Back Out
		return GAIN_LABEL_FROM + (1 - GAIN_LABEL_FROM) * eased
	end

	-- Presentation pulse (Intro): once per meter, the first moment it is shown AND revealed. Progress 0..1 (1 = idle).
	-- The Heartbeat connection lives outside the effect (the effect re-runs on every Max / Shown change).
	const intro = source(1)
	local introLive: RBXScriptConnection? = nil
	local introWasVisible = false
	local introDone = false
	effect(function()
		const visible = props.Shown() and props.Max() > 0 and (props.Revealed == nil or props.Revealed())
		const wanted = props.Intro ~= nil and props.Intro()
		if visible and not introWasVisible and wanted and not introDone then
			introDone = true
			untrack(function()
				const started = os.clock()
				intro(0)
				introLive = RunService.Heartbeat:Connect(function()
					const progress = math.clamp((os.clock() - started) / INTRO_TIME, 0, 1)
					intro(progress)
					if progress >= 1 and introLive ~= nil then
						introLive:Disconnect()
						introLive = nil
					end
				end)
			end)
		end
		introWasVisible = visible
	end)
	cleanup(function()
		if introLive ~= nil then
			introLive:Disconnect()
			introLive = nil
		end
	end)
	-- 0..1 strength of the pulse ring: 3 beats (a steady fade with reduced motion)
	const introAlpha = function(): number
		const t = intro()
		if t >= 1 then
			return 0
		end
		if Motion.Reduced() then
			return 1 - t
		end
		return math.abs(math.sin(t * math.pi * INTRO_BEATS)) * (1 - t * 0.3)
	end

	return create("Frame")({
		Name = props.Name or "HudSanity",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.fromOffset(8, 8),
		-- portrait + gap + bar + gap + number
		Size = function()
			const d = dims()
			return UDim2.fromOffset(d.Portrait + d.Gap * 2 + d.Bar + d.ValueWidth, d.Portrait)
		end,
		BackgroundTransparency = 1,
		Visible = function()
			return props.Shown() and reveal() > 0.02
		end,
		createRaw("UIScale")({
			Scale = function()
				return (REVEAL_FROM + (1 - REVEAL_FROM) * reveal()) * (1 + GAIN_POP * gainPop())
			end,
		}),

		portrait(props, dims),

		-- Bar: Ink track (style guide §7.2), glossy fill by sanity / max.
		CartoonPanel({
			Name = "Bar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				return UDim2.new(0, barX(), 0.5, 0)
			end,
			Size = function()
				const d = dims()
				return UDim2.fromOffset(d.Bar, d.BarHeight)
			end,
			Tone = Theme.Tone.Ink,
			Outline = function()
				return dims().Outline
			end,
			Lip = 0,
			Gloss = false,
			Padding = BAR_PAD,
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
						Position = UDim2.new(0.5, 0, 0, 1),
						Size = UDim2.new(1, -6, 0.32, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.55,
						-- too thin to carry a highlight on the phone bar
						Visible = function()
							return dims().BarHeight > COMPACT.BarHeight
						end,
						create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
					}),
				}),
			},
		}),

		-- Ring of the coffee lesson (Mustard, breathing) and of the gain (Green, fading)
		create("Frame")({
			Name = "HintRing",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				return UDim2.new(0, barX() - HINT_RING, 0.5, 0)
			end,
			Size = function()
				const d = dims()
				return UDim2.fromOffset(d.Bar + HINT_RING * 2, d.BarHeight + HINT_RING * 2)
			end,
			BackgroundTransparency = 1,
			Visible = function()
				return hint() > 0
			end,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({
				Color = Theme.Color.Mustard,
				Thickness = 3,
				Transparency = function()
					return 0.55 - 0.55 * hint()
				end,
			}),
		}),
		create("Frame")({
			Name = "GainFlash",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				return UDim2.new(0, barX() - HINT_RING, 0.5, 0)
			end,
			Size = function()
				const d = dims()
				return UDim2.fromOffset(d.Bar + HINT_RING * 2, d.BarHeight + HINT_RING * 2)
			end,
			BackgroundColor3 = GAIN_COLOR,
			BackgroundTransparency = function()
				return 0.45 + 0.55 * gain()
			end,
			Visible = function()
				return gain() < 1
			end,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({
				Color = GAIN_COLOR,
				Thickness = 3,
				Transparency = function()
					return gain() * gain()
				end,
			}),
		}),
		CartoonLabel({
			Name = "GainNumber",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = function()
				return UDim2.new(0.5, 0, 1, 4 + GAIN_RISE * gain())
			end,
			TextSize = GAIN_TEXT,
			Color = GAIN_COLOR,
			Text = function()
				return `+{gainAmount()}`
			end,
			Transparency = function()
				return math.clamp((gain() - 0.6) / 0.4, 0, 1)
			end,
			Visible = function()
				return gain() < 1
			end,
			ZIndex = 5,
			Children = {
				createRaw("UIScale")({
					Scale = gainLabelScale,
				}),
			},
		}),

		-- Presentation pulse: a Mustard ring around the whole meter (night 1)
		create("Frame")({
			Name = "IntroRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				const grow = 10 + INTRO_GROW * introAlpha()
				return UDim2.new(1, grow, 1, grow)
			end,
			BackgroundTransparency = 1,
			Visible = function()
				return introAlpha() > 0.01
			end,
			create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
			createRaw("UIStroke")({
				Color = Theme.Color.Mustard,
				Thickness = 3,
				Transparency = function()
					return 1 - 0.95 * introAlpha()
				end,
			}),
		}),

		-- Number (no "/max"). Plain TextLabel: CartoonLabel never goes under 14 px and the phone meter asks for 11.
		create("TextLabel")({
			Name = "Value",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				const d = dims()
				return UDim2.new(0, d.Portrait + d.Gap * 2 + d.Bar, 0.5, 0)
			end,
			Size = function()
				const d = dims()
				return UDim2.fromOffset(d.ValueWidth, d.Portrait)
			end,
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextSize = function()
				return dims().Text
			end,
			TextColor3 = function()
				-- Green while the gain plays, back to white as it fades
				return GAIN_COLOR:Lerp(Theme.Color.Text, math.clamp(gain() * 1.5, 0, 1))
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = function()
				return tostring(math.floor(props.Value()))
			end,
			createRaw("UIStroke")({
				Color = Theme.Color.Ink,
				LineJoinMode = Enum.LineJoinMode.Round,
				Thickness = function()
					return dims().Stroke
				end,
			}),
		}),
	})
end
