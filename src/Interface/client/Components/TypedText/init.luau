--!strict
-- TypedText: a line typed letter by letter, one TextLabel per letter, with the per-letter effects of a text style
-- (Content.OrderTalk.Styles; owner 2026-10-22, the order talk card: "as letras ficam sacudindo e balançando, embaralhando
-- as letras (letras, não palavras)", "sai tudo desfigurado"). The caller gives the whole text and, every frame, how many
-- chars show and the phase of the speech (Clock); the letters of a word never jump lines while they type (the wrap is laid
-- out once per text, at the width given). Effects (Fx, OrderTalk header): Fx on every letter, Tic on the typed letters while
-- Phase = "Tic", Break on the letters past Break() once Phase is not "Line"; their numbers add up (Swap / Garble / Rate /
-- Drop: the largest; DropTime: the shortest). Drop (owner 2026-10-22, ANM-001: the line loses letters as the face fades):
-- a letter (never the punctuation) a layer with Drop acts on is gone for good once hash(letter) < Drop x the share of
-- DropTime passed since that layer first acted on it: the letters fall out one by one, in a fixed random order, and stay
-- out when the phase moves on. Reduced motion (Motion.Reduced) keeps REDUCED of the movement (tremble, sway, tilt,
-- size); the swaps, glitch letters, drops and fades stay (they are the text, not motion).
-- Cost: one TextLabel (+ its UITextSizeConstraint, the player's Text Size setting would grow each letter out of its box)
-- per letter of the line, rebuilt only when the text, the style or the break changes; a Heartbeat only while Active(),
-- writing only the properties that changed (a Normal line writes nothing once typed).
-- Single mode (owner 2026-10-22: the spacing of separate letter labels looked off): a style with no Fx, Tic or Break
-- (an ordinary customer: Normal, Stressed) is ONE wrapped TextLabel typed with MaxVisibleGraphemes, the font's own
-- spacing; the per-letter labels are kept for the anomaly styles, whose letters move on their own.
-- Pure: only props (no game state); build it inside a Vide root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Motion = require(script.Parent.Motion)

const create = Vide.create
const effect = Vide.effect
const cleanup = Vide.cleanup

export type Clock = { Typed: number, Phase: Content.SpeechPhase }

export type Props = {
	-- The whole line (the untyped part too: the wrap is laid out on it)
	Text: () -> string,
	-- Read every frame: chars shown (bytes of Text) and the speech's phase
	Clock: () -> Clock,
	Style: () -> Content.TalkStyle?,
	-- Chars before the break (Style.Break applies past it); nil = no break
	Break: () -> number?,
	-- The per-frame work runs only while this is true (the card is shown)
	Active: () -> boolean,
	-- px at UI scale 1
	Width: number,
	TextSize: number,
	Color: Color3,
	Font: Enum.Font?, -- default FredokaOne (Theme.Font)
	Glitch: string?, -- chars a garbled letter may show; default Content.OrderTalk.Glitch
	Name: string?,
	LayoutOrder: number?,
	ZIndex: number?,
}

type Glyph = {
	Char: string,
	Last: number, -- byte of Text where the letter ends (it shows once Typed reaches it)
	Ordinal: number, -- letter number (seeds its tremble)
	Word: number,
	X: number,
	Y: number,
	H: number, -- its line's height
	Size: number,
	Past: boolean, -- after the break
	Droppable: boolean, -- a letter or digit (punctuation never drops out)
	DropAt: number?, -- os.clock() a Drop layer first acted on it
	Gone: boolean, -- dropped out of the line (for good, until the text is laid out again)
	Label: TextLabel,
	Cap: UITextSizeConstraint,
	-- last written
	Shown: boolean,
	Text: string,
	Dx: number,
	Dy: number,
	Rot: number,
	TextSize: number,
	Trans: number,
}

-- Merged effect numbers of the layers acting on a letter
type Fx = {
	Jitter: number,
	Wave: number,
	Tilt: number,
	Size: number,
	Swap: number,
	SwapTime: number,
	Garble: number,
	Fade: number,
	Flicker: number,
	Rate: number,
	Drop: number,
	DropTime: number,
}

const LINE = 1.2 -- line height x the letter size
const DROP_TIME = 0.5 -- s when a layer with Drop gives no DropTime
const WAVE_SPEED = 6 -- rad/s of the sway
const WAVE_STEP = 0.55 -- rad between two neighbours of the sway
const REDUCED = 0.25 -- share of the movement kept with reduced motion on
const RATE = 12 -- 1/s when a layer gives none
const SWAP_TIME = 0.15 -- s when a layer gives none
const MOVE_EPSILON = 0.05 -- px / degrees not worth a write
const MAX_TRANSPARENCY = 0.95
const MEASURE = Vector2.new(1000, 1000)

const widths: { [string]: number } = {}

local function widthOf(char: string, size: number, font: Enum.Font): number
	const key = `{font.Name}|{size}|{char}`
	local width = widths[key]
	if width == nil then
		width = TextService:GetTextSize(char, size, font, MEASURE).X
		widths[key] = width
	end
	return width :: number
end

local function spaceOf(size: number, font: Enum.Font): number
	return math.max(widthOf("x x", size, font) - widthOf("xx", size, font), size * 0.25)
end

-- Deterministic 0..1 of (letter, time slot, salt): the same letter glitches the same way within a slot
local function hash(a: number, b: number, salt: number): number
	const x = math.sin(a * 12.9898 + b * 78.233 + salt * 37.719) * 43758.5453
	return x - math.floor(x)
end

local function merge(layers: { Content.TalkFx }): Fx?
	if #layers == 0 then
		return nil
	end
	const fx: Fx = {
		Jitter = 0,
		Wave = 0,
		Tilt = 0,
		Size = 0,
		Swap = 0,
		SwapTime = math.huge,
		Garble = 0,
		Fade = 0,
		Flicker = 0,
		Rate = 0,
		Drop = 0,
		DropTime = math.huge,
	}
	for _, layer in layers do
		fx.Jitter += layer.Jitter or 0
		fx.Wave += layer.Wave or 0
		fx.Tilt += layer.Tilt or 0
		fx.Size += layer.Size or 0
		fx.Fade += layer.Fade or 0
		fx.Flicker += layer.Flicker or 0
		fx.Garble = math.max(fx.Garble, layer.Garble or 0)
		fx.Rate = math.max(fx.Rate, layer.Rate or 0)
		if (layer.Swap or 0) > 0 then
			fx.Swap = math.max(fx.Swap, layer.Swap :: number)
			fx.SwapTime = math.min(fx.SwapTime, layer.SwapTime or SWAP_TIME)
		end
		if (layer.Drop or 0) > 0 then
			fx.Drop = math.max(fx.Drop, layer.Drop :: number)
			fx.DropTime = math.min(fx.DropTime, layer.DropTime or DROP_TIME)
		end
	end
	if fx.Rate <= 0 then
		fx.Rate = RATE
	end
	if fx.SwapTime == math.huge then
		fx.SwapTime = SWAP_TIME
	end
	if fx.DropTime == math.huge then
		fx.DropTime = DROP_TIME
	end
	return fx
end

-- The letters of `text` with the byte where each ends (UTF-8: a display name may carry non-ASCII letters)
local function charsOf(text: string): { { Char: string, Last: number } }
	const out: { { Char: string, Last: number } } = {}
	-- a letter starts on every byte that is not a UTF-8 continuation byte (0x80..0xBF)
	local start = 1
	for index = 2, #text + 1 do
		const byte = string.byte(text, index)
		if byte == nil or byte < 0x80 or byte >= 0xC0 then
			table.insert(out, { Char = string.sub(text, start, index - 1), Last = index - 1 })
			start = index
		end
	end
	return out
end

return function(props: Props): Frame
	const font = props.Font or Enum.Font.FredokaOne
	const face = Font.fromEnum(font)
	const glitch = props.Glitch or Content.OrderTalk.Glitch
	const baseLine = math.ceil(props.TextSize * LINE)

	const holder = create("Frame")({
		Name = props.Name or "TypedText",
		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.fromOffset(props.Width, baseLine),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	})

	local glyphs: { Glyph } = {}
	local bottoms: { number } = {} -- bottom px of each line
	local lineOf: { number } = {} -- glyph -> line
	local style: Content.TalkStyle? = nil
	local cache: { [string]: Fx | false } = {}
	local motion = 1
	local height = baseLine

	local function fxOf(past: boolean, phase: Content.SpeechPhase): Fx?
		const key = `{past}|{phase}`
		const cached = cache[key]
		if cached ~= nil then
			return if cached == false then nil else cached
		end
		const layers: { Content.TalkFx } = {}
		const current = style
		if current ~= nil then
			if current.Fx ~= nil then
				table.insert(layers, current.Fx)
			end
			if current.Tic ~= nil and phase == "Tic" then
				table.insert(layers, current.Tic)
			end
			if current.Break ~= nil and past and phase ~= "Line" then
				table.insert(layers, current.Break)
			end
		end
		const fx = merge(layers)
		cache[key] = if fx == nil then false else fx
		return fx
	end

	-- single mode: the one label, its text, and the typed count / height last written
	local single: TextLabel? = nil
	local singleText = ""
	local singleTyped = -1

	local function clear()
		for _, glyph in glyphs do
			glyph.Label:Destroy()
		end
		glyphs = {}
		bottoms = {}
		lineOf = {}
		if single ~= nil then
			single:Destroy()
			single = nil
		end
		singleText = ""
		singleTyped = -1
	end

	-- An ordinary line: one wrapped label, typed by MaxVisibleGraphemes
	local function buildSingle(text: string, caps: boolean)
		singleText = if caps then string.upper(text) else text
		const label = Instance.new("TextLabel")
		label.Name = "Line"
		label.AutoLocalize = false
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.FontFace = face
		label.TextSize = props.TextSize
		label.TextColor3 = props.Color
		label.Text = singleText
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Size = UDim2.new(1, 0, 1, 0)
		label.ZIndex = props.ZIndex or 1
		label.MaxVisibleGraphemes = 0
		const cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = math.clamp(props.TextSize, 1, 100)
		cap.Parent = label
		label.Parent = holder
		single = label
	end

	local function stepSingle(label: TextLabel, typed: number)
		if typed == singleTyped then
			return
		end
		singleTyped = typed
		const shown = string.sub(singleText, 1, math.max(0, typed))
		label.MaxVisibleGraphemes = utf8.len(shown) or #shown
		-- the card grows a line at a time as the text reaches it (one line from the start)
		const bounds = TextService:GetTextSize(shown, props.TextSize, font, Vector2.new(props.Width, math.huge))
		const tall = math.max(baseLine, math.ceil(bounds.Y))
		if tall ~= height then
			height = tall
			holder.Size = UDim2.fromOffset(props.Width, tall)
		end
	end

	local function build(text: string, nextStyle: Content.TalkStyle?, breakAt: number?)
		clear()
		if nextStyle == nil or (nextStyle.Fx == nil and nextStyle.Tic == nil and nextStyle.Break == nil) then
			style = nextStyle
			buildSingle(text, nextStyle ~= nil and nextStyle.Caps == true)
			return
		end
		style = nextStyle
		cache = {}
		motion = if Motion.Reduced() then REDUCED else 1
		const caps = nextStyle ~= nil and nextStyle.Caps == true
		const broken = if nextStyle ~= nil then nextStyle.Break else nil
		const grow = if broken ~= nil and breakAt ~= nil then broken.Grow or 0 else 0
		const room = (if nextStyle and nextStyle.Fx then nextStyle.Fx.Size or 0 else 0)
			+ (if nextStyle and nextStyle.Tic then nextStyle.Tic.Size or 0 else 0)
			+ (if broken then broken.Size or 0 else 0)
		const chars = charsOf(if caps then string.upper(text) else text)
		-- the wrap: words never split across lines unless one is wider than the line
		type Placed = { Char: string, Last: number, X: number, Line: number, Size: number, Word: number, Past: boolean }
		const placed: { Placed } = {}
		const heights: { number } = { 0 }
		local x = 0
		local line = 1
		local word = 0
		local function sizeOf(last: number): number
			return props.TextSize + (if breakAt ~= nil and last > breakAt then grow else 0)
		end
		local function newLine()
			x = 0
			line += 1
			heights[line] = 0
		end
		local index = 1
		while index <= #chars do
			const char = chars[index].Char
			if char == "\n" then
				newLine()
				index += 1
			elseif char == " " then
				if x > 0 then
					x += spaceOf(sizeOf(chars[index].Last), font)
				end
				index += 1
			else
				local stop = index
				local span = 0
				while stop <= #chars and chars[stop].Char ~= " " and chars[stop].Char ~= "\n" do
					span += widthOf(chars[stop].Char, sizeOf(chars[stop].Last), font)
					stop += 1
				end
				if x > 0 and x + span > props.Width then
					newLine()
				end
				word += 1
				for k = index, stop - 1 do
					const entry = chars[k]
					const size = sizeOf(entry.Last)
					const w = widthOf(entry.Char, size, font)
					if x > 0 and x + w > props.Width then
						newLine()
					end
					table.insert(placed, {
						Char = entry.Char,
						Last = entry.Last,
						X = x,
						Line = line,
						Size = size,
						Word = word,
						Past = breakAt ~= nil and entry.Last > breakAt,
					})
					heights[line] = math.max(heights[line] or 0, math.ceil(size * LINE))
					x += w
				end
				index = stop
			end
		end
		const tops: { number } = {}
		local y = 0
		for at = 1, line do
			const tall = if (heights[at] or 0) > 0 then heights[at] else baseLine
			tops[at] = y
			y += tall
			bottoms[at] = y
		end
		for ordinal, entry in placed do
			const tall = bottoms[entry.Line] - tops[entry.Line]
			const w = widthOf(entry.Char, entry.Size, font)
			const label = Instance.new("TextLabel")
			label.Name = `L{ordinal}`
			label.AutoLocalize = false
			label.BackgroundTransparency = 1
			label.BorderSizePixel = 0
			label.FontFace = face
			label.TextSize = entry.Size
			label.TextColor3 = props.Color
			label.Text = entry.Char
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Bottom
			label.Size = UDim2.fromOffset(w, tall)
			label.Position = UDim2.fromOffset(entry.X, tops[entry.Line])
			label.ZIndex = props.ZIndex or 1
			label.Visible = false
			const cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = math.clamp(entry.Size + math.ceil(room), 1, 100)
			cap.Parent = label
			label.Parent = holder
			table.insert(glyphs, {
				Char = entry.Char,
				Last = entry.Last,
				Ordinal = ordinal,
				Word = entry.Word,
				X = entry.X,
				Y = tops[entry.Line],
				H = tall,
				Size = entry.Size,
				Past = entry.Past,
				Droppable = string.match(entry.Char, "^[%p%s]$") == nil,
				DropAt = nil,
				Gone = false,
				Label = label,
				Cap = cap,
				Shown = false,
				Text = entry.Char,
				Dx = 0,
				Dy = 0,
				Rot = 0,
				TextSize = entry.Size,
				Trans = 0,
			})
			table.insert(lineOf, entry.Line)
		end
		height = -1 -- the next frame sizes the holder
	end

	local function step()
		const clock = props.Clock()
		const label = single
		if label ~= nil then
			stepSingle(label, clock.Typed)
			return
		end
		const t = os.clock()
		const typed = clock.Typed
		const n = #glyphs
		-- pass 1: what each shown letter shows ("" = not typed yet) and the effects on it
		const shows: { string } = table.create(n, "")
		const fxs: { [number]: Fx } = {}
		local lastLine = 1
		for k, glyph in glyphs do
			if glyph.Last > typed then
				continue
			end
			lastLine = math.max(lastLine, lineOf[k])
			const fx = fxOf(glyph.Past, clock.Phase)
			if fx ~= nil and fx.Drop > 0 and glyph.Droppable and not glyph.Gone then
				-- the letter falls out once its turn comes (a fixed random order over DropTime), and stays out
				if glyph.DropAt == nil then
					glyph.DropAt = t
				end
				const since: number = glyph.DropAt or t
				const share = if fx.DropTime > 0 then math.clamp((t - since) / fx.DropTime, 0, 1) else 1
				if hash(glyph.Ordinal, 0, 29) < fx.Drop * share then
					glyph.Gone = true
				end
			end
			if glyph.Gone then
				continue
			end
			if fx ~= nil then
				fxs[k] = fx
			end
			local char = glyph.Char
			if fx ~= nil and fx.Garble > 0 then
				const slot = math.floor(t * fx.Rate)
				if hash(glyph.Ordinal, slot, 11) < fx.Garble then
					const at = 1 + math.floor(hash(glyph.Ordinal, slot, 17) * #glitch)
					char = string.sub(glitch, at, at)
				end
			end
			shows[k] = char
		end
		-- pass 2: neighbours inside a word trade places (pairs alternate by time slot so they never overlap)
		for k = 1, n - 1 do
			const fx = fxs[k]
			if fx == nil or fx.Swap <= 0 or shows[k] == "" or shows[k + 1] == "" then
				continue
			end
			if glyphs[k].Word ~= glyphs[k + 1].Word then
				continue
			end
			const slot = math.floor(t / fx.SwapTime)
			if (k + slot) % 2 == 0 and hash(glyphs[k].Ordinal, slot, 23) < fx.Swap then
				shows[k], shows[k + 1] = shows[k + 1], shows[k]
			end
		end
		-- pass 3: write what changed
		for k, glyph in glyphs do
			const label = glyph.Label
			if shows[k] == "" then
				if glyph.Shown then
					glyph.Shown = false
					label.Visible = false
				end
				continue
			end
			if not glyph.Shown then
				glyph.Shown = true
				label.Visible = true
			end
			local dx, dy, rot, size, trans = 0, 0, 0, glyph.Size, 0
			const fx = fxs[k]
			if fx ~= nil then
				const seed = glyph.Ordinal * 1.618
				const tt = t * fx.Rate
				if fx.Jitter > 0 then
					dx = math.noise(seed, tt, 0.5) * 2 * fx.Jitter * motion
					dy = math.noise(seed, tt, 7.3) * 2 * fx.Jitter * motion
				end
				if fx.Wave > 0 then
					dy += math.sin(t * WAVE_SPEED + glyph.Ordinal * WAVE_STEP) * fx.Wave * motion
				end
				if fx.Tilt > 0 then
					rot = math.noise(seed, tt, 13.1) * 2 * fx.Tilt * motion
				end
				if fx.Size > 0 then
					size = math.max(1, glyph.Size + math.floor(math.noise(seed, tt, 19.7) * 2 * fx.Size * motion + 0.5))
				end
				trans = fx.Fade
				if fx.Flicker > 0 then
					const slot = math.floor(tt)
					if hash(glyph.Ordinal, slot, 3) < 0.5 then
						trans += fx.Flicker * hash(glyph.Ordinal, slot, 5)
					end
				end
				trans = math.clamp(trans, 0, MAX_TRANSPARENCY)
			end
			if shows[k] ~= glyph.Text then
				glyph.Text = shows[k]
				label.Text = shows[k]
			end
			if math.abs(dx - glyph.Dx) > MOVE_EPSILON or math.abs(dy - glyph.Dy) > MOVE_EPSILON then
				glyph.Dx = dx
				glyph.Dy = dy
				label.Position = UDim2.fromOffset(glyph.X + dx, glyph.Y + dy)
			end
			if math.abs(rot - glyph.Rot) > MOVE_EPSILON then
				glyph.Rot = rot
				label.Rotation = rot
			end
			if size ~= glyph.TextSize then
				glyph.TextSize = size
				glyph.Cap.MaxTextSize = math.clamp(size, 1, 100)
				label.TextSize = size
			end
			if math.abs(trans - glyph.Trans) > 0.01 then
				glyph.Trans = trans
				label.TextTransparency = trans
			end
		end
		-- the card grows a line at a time as the letters reach it (one line from the start)
		const tall = bottoms[lastLine] or baseLine
		if tall ~= height then
			height = tall
			holder.Size = UDim2.fromOffset(props.Width, tall)
		end
	end

	local laidText: string? = nil
	local laidStyle: Content.TalkStyle? = nil
	local laidBreak: number? = nil
	effect(function()
		const text = props.Text()
		const nextStyle = props.Style()
		const breakAt = props.Break()
		if text == laidText and nextStyle == laidStyle and breakAt == laidBreak then
			return
		end
		laidText = text
		laidStyle = nextStyle
		laidBreak = breakAt
		build(text, nextStyle, breakAt)
		step()
	end)

	local connection: RBXScriptConnection? = nil
	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end
	effect(function()
		if props.Active() then
			if connection == nil then
				connection = RunService.Heartbeat:Connect(step)
			end
		else
			stop()
		end
	end)
	cleanup(function()
		stop()
		clear()
	end)

	return holder
end
