--!strict
-- ModuxIntro: minimal "POWERED BY MODUX" sting (owner request 2026-10-20, v2: clean and minimal, no ribbons or glow).
-- Black screen, white wordmark with wide tracking, one hairline in the accent colour. Everything is a pure function
-- of Time (seconds since the start), so the owner decides speed, looping and when to mount it.
--   0.20 s  hairline draws out from the centre
--   0.55 s  letters rise from behind the hairline one by one (masked), tracking slowly tightens the whole time
--   1.30 s  caption fades in above
--   3.00 s  letters sink back behind the hairline, caption fades, hairline retracts to the centre (DURATION = 3.9 s)
-- No push-in and every position on whole pixels (owner 2026-10-21: the sting flickered, worst on phones): a UIScale
-- moving every frame re-rasterises the text at a fractional size and the 1 px hairline flips between 1 and 2 px, and
-- letters sliding by sub-pixels shimmer. The tracking still tightens, in whole-pixel steps.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Vide = require(ReplicatedStorage.Packages.Vide)

const create = Vide.create

export type Props = {
	-- seconds since the sting started
	Time: () -> number,
	-- hairline colour (the only colour on screen)
	Accent: () -> Color3,
	Word: string?,
	Caption: string?,
	Name: string?,
}

const DURATION = 3.9
const TEXT_SIZE = 84
const WORD_FONT = Enum.Font.GothamMedium
const CAPTION_FONT = Enum.Font.Gotham
const CAPTION_SIZE = 15
const TRACK_FROM = 34 -- px between letters at the start
const TRACK_TO = 20 -- px between letters at the end
const MASK = 2 * math.round(TEXT_SIZE * 1.15 / 2) -- height of the window the letters rise through (even, whole px)
const LINE_IN = 0.2
const LINE_TIME = 0.7
const LETTER_IN = 0.55
const LETTER_STAGGER = 0.06
const LETTER_TIME = 0.8
const CAPTION_IN = 1.3
const CAPTION_TIME = 0.6
const EXIT_AT = 3.0
const EXIT_STAGGER = 0.04
const EXIT_TIME = 0.5
const LINE_OUT = 3.3
const LINE_OUT_TIME = 0.5
const WHITE = Color3.new(1, 1, 1)
const GREY = Color3.fromHex("#8A8A94")

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function outQuint(x: number): number
	const v = 1 - clamp01(x)
	return 1 - v * v * v * v * v
end

local function inCubic(x: number): number
	const v = clamp01(x)
	return v * v * v
end

local function inOutCubic(x: number): number
	const v = clamp01(x)
	return if v < 0.5 then 4 * v * v * v else 1 - (-2 * v + 2) ^ 3 / 2
end

-- "POWERED BY" -> "P O W E R E D   B Y" (TextLabel has no tracking)
local function track(text: string): string
	return (string.gsub(string.gsub(text, ".", "%0 "), "%s+$", ""))
end

return function(props: Props): Frame
	const t = props.Time
	const word = string.upper(props.Word or "MODUX")
	const count = #word

	const widths = {}
	local glyphs = 0
	for index = 1, count do
		const char = string.sub(word, index, index)
		const width = TextService:GetTextSize(char, TEXT_SIZE, WORD_FONT, Vector2.new(1000, 1000)).X
		widths[index] = width
		glyphs += width
	end

	const gap = function(): number
		return TRACK_FROM + (TRACK_TO - TRACK_FROM) * outQuint(t() / DURATION)
	end
	const span = function(): number
		return glyphs + gap() * (count - 1)
	end

	const letters = {}
	local before = 0 -- glyph width left of this letter
	for index = 1, count do
		const i = index - 1
		const width = widths[index]
		const left = before
		before += width
		const char = string.sub(word, index, index)
		-- 0 = hidden below the hairline, 1 = fully up
		const rise = function(): number
			const up = outQuint((t() - (LETTER_IN + i * LETTER_STAGGER)) / LETTER_TIME)
			const down = inCubic((t() - (EXIT_AT + i * EXIT_STAGGER)) / EXIT_TIME)
			return up * (1 - down)
		end

		table.insert(
			letters,
			create("TextLabel")({
				Name = char .. index,
				AnchorPoint = Vector2.new(0, 0),
				Position = function(): UDim2
					const x = math.round(-span() / 2 + left + gap() * i)
					return UDim2.new(0.5, x, 0, math.round((1 - rise()) * MASK))
				end,
				Size = UDim2.fromOffset(width, MASK),
				BackgroundTransparency = 1,
				Font = WORD_FONT,
				TextSize = TEXT_SIZE,
				Text = char,
				TextColor3 = WHITE,
				TextTransparency = function(): number
					return 1 - rise()
				end,
			})
		)
	end

	return create("Frame")({
		Name = props.Name or "ModuxIntro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,

		create("Frame")({
			Name = "Logo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,

			create("TextLabel")({
				Name = "Caption",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = function(): UDim2
					const shown = outQuint((t() - CAPTION_IN) / CAPTION_TIME)
					return UDim2.fromOffset(0, math.round(-MASK / 2 - 14 + (1 - shown) * 6))
				end,
				Size = UDim2.fromOffset(400, CAPTION_SIZE + 4),
				BackgroundTransparency = 1,
				Font = CAPTION_FONT,
				TextSize = CAPTION_SIZE,
				TextColor3 = GREY,
				Text = track(props.Caption or "POWERED BY"),
				TextTransparency = function(): number
					const shown = outQuint((t() - CAPTION_IN) / CAPTION_TIME)
					const gone = clamp01((t() - EXIT_AT) / 0.3)
					return 1 - shown * (1 - gone)
				end,
			}),

			-- the letters rise through this window, so they appear from behind the hairline
			create("Frame")({
				Name = "Mask",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(2000, MASK),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				letters,
			}),

			create("Frame")({
				Name = "Hairline",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(0, math.round(MASK / 2 + 1)),
				Size = function(): UDim2
					const open = inOutCubic((t() - LINE_IN) / LINE_TIME)
					const close = inOutCubic((t() - LINE_OUT) / LINE_OUT_TIME)
					-- even width: centred on a whole pixel (AnchorPoint 0.5)
					return UDim2.fromOffset(2 * math.round((span() + 48) * open * (1 - close) / 2), 1)
				end,
				BackgroundColor3 = props.Accent,
				BorderSizePixel = 0,
			}),
		}),
	}) :: Frame
end
