--!strict
-- UI tokens from docs/art/style-guide.md §2 and §7 and the AST-091 UI kit (DEC-217), cartoon pass (user request
-- 2026-10-10: "mais cartunizada"). Components read colors, fonts, outlines, radii and timings from here, never from
-- literals, so a palette change is one edit.
-- The cartoon look (CartoonPanel / CartoonButton / CartoonLabel):
--   thick Ink outline, round corners, a darker "lip" under every surface (offset 0,4), two-tone vertical gradient
--   with a thin white inner rim, optional studs texture, one round fat font (Fredoka One) with Ink stroke on all text.

local UserInputService = game:GetService("UserInputService")

-- Two-tone surface: Top (light) -> Bottom (base) gradient, Lip = the darker band under it (the "drop").
export type Tone = { Top: Color3, Bottom: Color3, Lip: Color3, Text: Color3, Stroke: boolean }

const INK = Color3.fromHex("#2B2233")

local function tone(top: string, bottom: string, lip: string, text: Color3?, stroke: boolean?): Tone
	const value: Tone = {
		Top = Color3.fromHex(top),
		Bottom = Color3.fromHex(bottom),
		Lip = Color3.fromHex(lip),
		Text = text or Color3.new(1, 1, 1),
		Stroke = if stroke == nil then true else stroke,
	}
	return value
end

const Theme = {
	Color = {
		-- §7.1: Ink is the outline of everything and the HUD pill colour; white text with an Ink outline.
		Ink = INK,
		Text = Color3.fromHex("#FFFFFF"),
		Mustard = Color3.fromHex("#F6C12B"), -- interactive accent
		Teal = Color3.fromHex("#3FA7B5"),
		Green = Color3.fromHex("#5FA36A"),
		Cream = Color3.fromHex("#FFF1D6"),
		Violet = Color3.fromHex("#6A5ACD"), -- accent (§7.3)
		Slate = Color3.fromHex("#8A8FA3"), -- grade D on the shift summary (§7.4, never red)
		Gold = Color3.fromHex("#FFD86B"), -- sanity full (§7.2 #FFD45A family)
		Pink = Color3.fromHex("#F4A7B9"), -- the paw's pads and toe beans (TASK-265; soft, never the alert red)
		-- Price the party cannot pay (FEAT-008 "preço em vermelho"); same Ketchup red as Low. Grades/sanity never red.
		NoCash = Color3.fromHex("#E2402E"),
		-- CookInterface colors from AnimalPlane (DEC-029): orange while cooking, green when ready.
		Cooking = Color3.fromRGB(252, 172, 1),
		Ready = Color3.fromRGB(0, 255, 115),
		-- FEAT-007: stock counter turns red at <= 2 (Ketchup of §2.1).
		Low = Color3.fromHex("#E2402E"),
		-- Text on light surfaces (Cream cards, white bubbles): Ink, no stroke.
		Dark = INK,
	},

	-- Surfaces of the kit (AST-091): HUD pill Ink, card Cream, primary button Mustard, secondary Cream, off Slate.
	-- Every Tone is used with CartoonPanel (Top -> Bottom gradient, Lip under it, Ink outline).
	Tone = table.freeze({
		Ink = tone("#4A3D57", "#2B2233", "#17111C"),
		Cream = tone("#FFF8EA", "#FBE3B8", "#D9B57A", INK, false),
		White = tone("#FFFFFF", "#F1ECE4", "#C9C0B4", INK, false),
		Mustard = tone("#FFDA5C", "#F6B71B", "#B97F0A", INK, false),
		Teal = tone("#63C8D4", "#3FA7B5", "#256E7A"),
		Green = tone("#86CF8F", "#5FA36A", "#3B6E44"),
		Violet = tone("#8F82E6", "#6A5ACD", "#433693"),
		Slate = tone("#A9AEBF", "#8A8FA3", "#5D6173"),
		Ketchup = tone("#F2705F", "#E2402E", "#A8261B"),
	}),

	Transparency = {
		-- Cartoon surfaces are solid; a hint of the world shows through the HUD pills only.
		Panel = 0.06,
		Track = 0.5,
		Studs = 0.9, -- studs texture over a surface
	},

	-- One font everywhere (user request: one round, fat cartoon font). Whisper keeps a thin italic on purpose: the
	-- hallucination line must not read as UI (WhisperLine).
	Font = {
		Title = Font.fromEnum(Enum.Font.FredokaOne),
		Body = Font.fromEnum(Enum.Font.FredokaOne),
		Whisper = Font.new(
			"rbxasset://fonts/families/BuilderSans.json",
			Enum.FontWeight.Regular,
			Enum.FontStyle.Italic
		),
	},

	-- Smallest readable size on a phone (frontend rule: text >= 14 px on the smallest screen). Never below 12 real px:
	-- the global scale only goes under 1 without touch (Scale.Min 0.86 x 14 = 12).
	MinTextSize = 14,
	-- Smallest touch target (44 px at scale 1; touch screens scale down to Scale.MinTouch, 35 real px).
	MinTouch = 44,
	-- Height of a status chip / pill that is NOT touchable (money, clock, day, toast): smaller than a touch target
	-- (user request 2026-10-11: "as interfaces no geral, todas estão muito grandes").
	MinChip = 32,

	-- Global UI scale (user request 2026-10-11). Every ScreenGui scales its px layout (drawn at scale 1 for the
	-- smallest landscape phone, 667 x 375) by ScaleOf(viewport):
	--   scale = clamp(viewportY / Reference * Factor, Min (MinTouch on touch screens), Max)
	-- 1080p -> 1.4 (was 2; with the trimmed component sizes about 35-40% smaller on desktop). THE KNOB: Factor
	-- (bigger = bigger UI everywhere, e.g. 1.6 = +15%, 1.2 = -15%);
	-- Min / Max bound it on small windows and 1440p+ monitors.
	Scale = {
		Reference = 1080, -- viewport height (px) where the scale is Factor
		Factor = 1.4,
		Min = 0.86, -- mouse / gamepad: 14 px text x 0.86 = 12 real px
		MinTouch = 0.8, -- touch: 44 px targets -> 35 real px, 14 px text -> 11 (owner 2026-10-17: phone UI covered the counter; was 1)
		-- touch phone in landscape (viewport up to PhoneHeight): the PC proportions, owner 2026-10-20 "1:1 with the PC,
		-- everything still too big" (390 px tall -> 0.51 by the rule; 14 px text x 0.6 = 8.4 real px)
		MinPhone = 0.6,
		PhoneHeight = 500,
		Max = 1.6,
	},
	-- Text stroke for small text (kept for callers outside the kit). Bigger text: Theme.TextStroke(size).
	Stroke = 2,

	-- Outline of surfaces (UIStroke on frames), px at UI scale 1.
	Outline = {
		Thin = 2, -- world tags sized in studs (stay light from far away)
		Normal = 3, -- pills, chips, bubbles
		Thick = 4, -- cards, buttons, focused card
	},
	-- Darker band under a surface ("drop" offset 0,4).
	Lip = 4,
	-- White inner rim (BorderStrokePosition Inner) on every surface: the "toy plastic" shine.
	Rim = { Thickness = 2, Transparency = 0.55 },

	Radius = {
		Pill = UDim.new(0.5, 0),
		Card = UDim.new(0, 14),
		Chip = UDim.new(0, 10),
		Small = UDim.new(0, 6),
	},

	-- Px of one stud tile on screen.
	StudsTile = 28,

	Motion = {
		Pop = 0.32, -- spring period of a pop-in (with overshoot)
		PopDamping = 0.55,
		Reveal = 0.25, -- progressive HUD reveal (Content.HudReveal), seconds, no overshoot
		Press = 0.12, -- squash on press
		PressScale = 0.92,
		HoverScale = 1.05,
		Bump = 0.2, -- money / value bump time
		BumpScale = 1.18,
		Count = 0.45, -- money count-up
		Fade = 0.2,
		-- Toast "tags" lean a little, alternating (degrees).
		TagTilt = 2.5,
	},
}

-- Ink stroke of text by size: 2 px for small text, 3 px from 22 px, 4 px for big titles.
local function textStroke(size: number): number
	return if size >= 40 then 4 elseif size >= 22 then 3 else 2
end

-- Smallest UI scale for a viewport: MinPhone on a touch phone, MinTouch on another touch screen, Min elsewhere.
local function floorOf(viewport: Vector2): number
	const rule = Theme.Scale
	if UserInputService.TouchEnabled then
		return if viewport.Y > 0 and viewport.Y <= rule.PhoneHeight then rule.MinPhone else rule.MinTouch
	end
	return rule.Min
end

-- Global UI scale for a viewport (Theme.Scale). `fit` = px size of a fixed layout that must stay on screen (a panel
-- drawn at scale 1): the scale never makes it overflow, but never goes under the floor (touch targets, text).
local function scaleOf(viewport: Vector2, fit: Vector2?): number
	const rule = Theme.Scale
	local value = viewport.Y / rule.Reference * rule.Factor
	if fit ~= nil then
		value = math.min(value, viewport.X / fit.X, viewport.Y / fit.Y)
	end
	return math.clamp(value, floorOf(viewport), rule.Max)
end

-- Two-tone vertical gradient of a Tone (UIGradient.Color, Rotation 90).
local function gradient(value: Tone): ColorSequence
	return ColorSequence.new(value.Top, value.Bottom)
end

-- A Tone for any colour (light top, darker lip); text white with stroke unless the colour is light.
local function toneOf(color: Color3): Tone
	const h, s, v = color:ToHSV()
	const luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	const light = luminance > 0.7
	const value: Tone = {
		Top = Color3.fromHSV(h, s * 0.75, math.min(v * 1.12, 1)),
		Bottom = color,
		Lip = Color3.fromHSV(h, math.min(s * 1.1, 1), v * 0.62),
		Text = if light then INK else Color3.new(1, 1, 1),
		Stroke = not light,
	}
	return value
end

return table.freeze({
	Color = table.freeze(Theme.Color),
	Tone = Theme.Tone,
	Transparency = table.freeze(Theme.Transparency),
	Font = table.freeze(Theme.Font),
	MinTextSize = Theme.MinTextSize,
	MinTouch = Theme.MinTouch,
	MinChip = Theme.MinChip,
	Scale = table.freeze(Theme.Scale),
	ScaleOf = scaleOf,
	FloorOf = floorOf,
	Stroke = Theme.Stroke,
	Outline = table.freeze(Theme.Outline),
	Lip = Theme.Lip,
	Rim = table.freeze(Theme.Rim),
	Radius = table.freeze(Theme.Radius),
	StudsTile = Theme.StudsTile,
	Motion = table.freeze(Theme.Motion),
	TextStroke = textStroke,
	Gradient = gradient,
	ToneOf = toneOf,
})
