--!strict
-- Anomaly tics in the order talk (design/anomaly-tics-proposal.md, Rascunho; owner 2026-10-21: "quebrar o pescoço dela
-- quando ele falar com ela"). A tic = a short scripted oddity an anomaly customer does up close, in the Take Order close-up,
-- while it says its line (owner 2026-10-22: no ACCEPT / REFUSE any more, the talk ends by itself and the order is taken):
-- a clue and a small scare, never the jumpscare (that is the anomaly module's, once the order is taken).
-- Presentation only (T10): the answer of each anomaly is its server rule; nothing here says what solves or fails.
-- Pilot: ANM-012 the turned neck (Provisional, Q-459 a / Q-460 a / Q-462 a). Owner 2026-10-22 ("implementa os próximos
-- tiques"): ANM-013 the white eyes, ANM-004 the copy's echo, ANM-014 the big head (Provisional, Q-461 / Q-465). Owner
-- 2026-10-22 (the blank folks arrived faceless): ANM-001 the face that fades (Provisional).
--
-- Typing (owner 2026-10-22, every line of the order talk, Content.OrderSpeech): Rules.TypeRate chars/s, and a pause after
-- punctuation (Rules.PauseStop after . ! ?, Rules.PauseComma after , ; :, only at the end of a run of them and never after
-- the last char). TypeTime(text, from, to) = s to type chars from + 1 .. to; TypedAt(text, from, t) = chars shown t s
-- after typing (re)started at char `from`.
--
-- Clock of a talk with a tic (s from LineStart = the tablet's StartedAt + OrderTalk.Speech.Start; Timing below, pure, read
-- by the server and every client so they agree without a packet):
--   Freeze   the customer's line types (TypeTime) and stops mid word; owner 2026-10-22 ("coloca 3 pontinhos no texto, trava
--            a geração dos textos por 1 segundo, 2 segundos"): Rules.Trail ("...") enters the line there, typed with it
--            (Said.Chars counts it)
--   Beats    Hold s of stillness (the build-up, see Tension), then Beats.Count beats Beats.Time s each, Beats.Gap s apart
--            (a crack, the eyes opening white, a step of the head growing); no Beats = the pause alone
--   Peak     the apex: the first beat (no beats: the end of the pause). Leaving the talk before it cancels the tic (the
--            actor is as before, it plays again next time, no tension starts); after it the residue stays for everyone
--            and the taker's tension goes on with them
--   Resume   After s after the last beat the rest of the line types (disfigured, the style's Break)
--   End      the line is over; the talk ends OrderTalk.Speech.Hold s later (Content.OrderSpeech) and the order is taken
-- The taker's tension (owner 2026-10-22: "antes da animação acontecer começa a aparecer as barras, aí quebra o pescoço, e na
-- hora que quebra - bum - começa os sussurros na mesma hora, junto com o heartbeat"; Provisional). Layers[key] = the
-- Content.HorrorScenes steps of that layer, At = s from the Peak (negative = the build-up), built below from
-- Rules.Tension (+ the row's Tension) and the row's Steps; Effects/Kit/Tic plays them on the taker's screen only:
--   Peak - Hold    the "..." froze the line: the black bars come in, the room ducks, a slow heart starts and speeds up,
--                  the edges creep in
--   Peak - Pause   the "paradinha": the room and the heart go quiet
--   Peak           the apex (the beat on the body): the whisper and the hint's words (Content.AnomalyHints: its own when
--                  Live, else the generic list), the hint's title (Live only), the jolt / field of view / blur, the colour;
--                  the heart at its normal pace from here to the delivery
--   Peak + Back    the room comes back
--   + WhisperFor   the whispers go on, low, until the delivery
--   + BarsFor      the bars leave; the colour and the edges settle to Linger and stay until the delivery
-- Past the apex the layer is CARRIED (Kit/Tic, Scene/Carry): it outlives the close-up and the talk and ends when her record
-- is Resolved / Failed / gone (or Tension.Max). While it is carried that client skips the Queue steps of her scene whose
-- kind is in Rules.Carry (and the screen sounds of Rules.CarrySounds) and the queue caption (Score): the tension does not
-- start over in the queue. Everyone else sees the body and hears the beats in the talk (no bars, no whispers) and gets the
-- Queue scene as before when the order is taken (they need the hint too, co-op).
-- Rows:
--   Key      Content.Anomalies key (an odd customer, Actor "Customer")
--   Variant  the rig Variant of that actor (CustomerService:SpawnActor), how the tablet finds the row
--   Kind     "Clue" | "Scare" (always the debut's kind for now; the 45 s cooldown and the later-night chance are not in)
--   Body     what the actor's body does, seen by everyone (Effects/Kit/Tic):
--              Neck  the head turns Turn degrees at each beat (ANM-012)
--              Eyes  a blink over Hold, the eyes open all white at the peak and cast Light forward (ANM-013)
--              Head  the head grows to Scales[i] at beat i, the taker's close-up rising and backing off with it (ANM-014)
--              Echo  the line is the original's hi, letter by letter, then the taker's own hi with their name; the head
--                    tilts Tilt degrees while it says the taker's line (ANM-004)
--              Face  its own face (the species', its mood) until the talk; from the freeze the face fades out over the
--                    build-up and is gone at the apex (the beat): Face = the CrewExpressions face shown from then on (ANM-001,
--                    owner 2026-10-22: it arrives normal; the cameras already show it blank). Only the face shell goes:
--                    the head keeps its skin, its markings and its nose
--   Pre      the sign before the talk: Twitch = every Every[1]..Every[2] s the head jerks Value degrees aside and back in
--            Time s, a crack at Volume heard within Range studs
--   Glint    Eyes: a small cold light on the face before the talk that does not follow the room's light
--   Cameras  Head: the head's scale through a security camera before the tic (the cameras keep the sign, Q-461)
--   Line     Text = what it says (English UI), Freeze = share of it typed before it stops, Residue = its line when the
--            talk is opened again after the tic (no tic then), Echo = the text is Echo(original, taker) (Body Echo)
--   Steps    the taker's screen layer, on top of the tension (the body's own punctuation: a shake per crack, the hum
--            cutting): Content.HorrorScenes steps, At = s from the Peak (negative = in the build-up); Phase is not read
--   Tension  (optional) the row's own numbers over Rules.Tension (a Clue: a Step shake, no blur)
--   Caption  sound caption on the talk card from the peak until the line resumes
--   Residue  the actor's state after the peak, seen by everyone: "Reversed" (the head stays turned), "White" (white eyes
--            and their light), "Big" (the last step the head reached), "Blank" (no face), "None" (nothing stays: every
--            talk plays it again)
--   OnLeave  "Follow": left after the peak, the turned head follows who left while they stand in front of it;
--            "Residue": the residue stays as it is; "Cancel": nothing stays (Residue "None")
--   Queue    (owner 2026-10-22, Provisional; anomalies-after-accept-proposal.md §9) the sign made explicit on the body while
--            the actor waits in the delivery queue (rig AnomalyQueue, Anomaly Kit/CustomerActor), seen by everyone:
--              Neck  Roll / Pitch degrees on top of the turned head: the neck broken, the head on a shoulder, hanging
--                    (the head is turned round even when no tic played)
--              Head  Scale: the head swells to it on entering the queue; PerStep: + per Hurry step (rig AnomalyStep);
--                    a creak (Beats.Sound) at each step; back to the residue when she is served right
--              Eyes  Light: the brightness of the white eyes' light while it waits
--              Face  (no field) no face while it waits, even when no tic played
--            nil = the residue alone
-- Rules: TicMax (s from LineStart the last beat must end by), TypeRate (chars/s), PauseStop / PauseComma (s after
-- punctuation), HearRange (studs the beats are heard; the body is seen by all), NameMax (the echo's longest name), Trail
-- (what enters the line at the freeze), Tension (the taker's tension, see above), Carry / CarrySounds (the Queue steps a
-- carrier skips). ChoiceMin / ChoiceAfter (the ACCEPT / REFUSE gate, Q-462) went with the choice (owner 2026-10-22).
local Table = require(script.Parent.Table)
local AnomalyHints = require(script.Parent.AnomalyHints)
local HorrorScenes = require(script.Parent.HorrorScenes)
local OrderTalk = require(script.Parent.OrderTalk)
local Restaurant = require(script.Parent.Restaurant)

export type Kind = "Clue" | "Scare"

export type Body = "Neck" | "Eyes" | "Head" | "Echo" | "Face"

export type Residue = "Reversed" | "White" | "Big" | "Blank" | "None"

export type Pre = { Kind: "Twitch", Every: { number }, Value: number, Time: number, Volume: number, Range: number }

export type Glint = { Brightness: number, Range: number }

export type Light = { Brightness: number, Residue: number, Range: number, Angle: number }

export type Line = { Text: string, Freeze: number, Residue: string, Echo: boolean? }

export type Beats = { Count: number, Time: number, Gap: number, Volume: number, Sound: string }

-- the body in the delivery queue (header, Queue)
export type Queue = { Roll: number?, Pitch: number?, Scale: number?, PerStep: number?, Light: number? }

-- The taker's tension (header; owner 2026-10-22, Provisional). Times in s, BPM for the heart
export type Tension = {
	Bars: number, -- height of each black bar (Cinema, share of the screen), in from the freeze over BarsIn
	BarsIn: number,
	BarsFor: number, -- s after the apex the bars leave (over 1.5 s) and the colour and the edges settle to Linger
	Duck: number, -- the room (music, ambience, kitchen) during the build-up, 0..1
	HeartFrom: number, -- the heart that starts with the bars
	HeartTo: number, -- what it speeds up to by the pause
	HeartNormal: number, -- its pace from the apex to the delivery
	Pause: number, -- s before the apex the room and the heart go quiet (the "paradinha")
	Back: number, -- s after the apex the room comes back (over 0.8 s)
	Shake: string, -- the "bum": HorrorScenes.Rules.Shakes profile
	Fov: number, -- the "bum": degrees, back over 0.8 s
	Blur: number, -- the "bum": gone in 0.4 s (0 = none)
	Tint: string, -- the screen's colour (HorrorScenes Grade Target: Cold, Sick)
	Grade: number, -- its strength at the apex
	Vignette: number, -- the edges at the apex (half of it creeps in over the build-up)
	Linger: number, -- share of Grade and Vignette left from BarsFor to the delivery
	Whisper: number, -- rate of the whispers from the end of the hint's burst to the delivery (1 = the Kit's)
	Max: number, -- s after the apex a carried tension ends by itself (the heart and the whispers)
}

-- A row's own Tension numbers (the rest from Rules.Tension)
export type TensionPatch = {
	Bars: number?,
	BarsIn: number?,
	BarsFor: number?,
	Duck: number?,
	HeartFrom: number?,
	HeartTo: number?,
	HeartNormal: number?,
	Pause: number?,
	Back: number?,
	Shake: string?,
	Fov: number?,
	Blur: number?,
	Tint: string?,
	Grade: number?,
	Vignette: number?,
	Linger: number?,
	Whisper: number?,
	Max: number?,
}

export type Tic = {
	Key: string,
	Variant: string,
	Kind: Kind,
	Body: Body,
	Pre: Pre?,
	Glint: Glint?,
	Cameras: number?,
	Line: Line,
	Hold: number,
	Beats: Beats?,
	After: number,
	Turn: number?, -- Neck: degrees per beat
	Light: Light?, -- Eyes: the light the white eyes cast forward (Brightness at the peak, Residue after it)
	Scales: { number }?, -- Head: scale reached at each beat (the head arrives at 1)
	Tilt: number?, -- Echo: degrees the head tilts while it says the taker's line
	Face: string?, -- Face: the CrewExpressions face from the apex on (the residue, the queue, the cameras)
	Steps: { HorrorScenes.Step },
	Tension: TensionPatch?,
	Caption: string?,
	Residue: Residue,
	OnLeave: "Cancel" | "Residue" | "Follow",
	Queue: Queue?,
}

export type Rules = {
	TicMax: number,
	TypeRate: number,
	PauseStop: number,
	PauseComma: number,
	HearRange: number,
	NameMax: number,
	Trail: string,
	Tension: Tension,
	Carry: { string },
	CarrySounds: { string },
}

-- The line of one talk: its text and how many chars type before the freeze
export type Said = { Text: string, Chars: number }

-- Times of a tic, s from LineStart (see the header)
export type Timing = {
	Chars: number, -- chars typed before the freeze
	Freeze: number,
	Beats: { number }, -- start of each beat
	Peak: number,
	BeatsEnd: number,
	Resume: number,
	End: number,
}

const rules: Rules = {
	-- owner 2026-10-22: the 1-2 s build-up on "..." made the tics longer (was 2.4; the worst is the neck, last crack ~3.3 s)
	TicMax = 4,
	-- owner 2026-10-22 ("letra por letra"; he guessed 0.3 s a letter, ~9 s a line): 28 chars/s, Provisional, tune here
	TypeRate = 28,
	PauseStop = 0.22, -- Provisional
	PauseComma = 0.1, -- Provisional
	HearRange = 25,
	NameMax = 20, -- Roblox display names: the longest name the echo can say (Validate keeps its peak inside TicMax)
	Trail = "...", -- owner 2026-10-22: "coloca 3 pontinhos no texto"
	-- owner 2026-10-22 (Provisional): bars, a heart 86 -> 170 (three beats ~0 / 0.7 / 1.15 s into a 1.5 s hold), the
	-- "paradinha" 0.25 s, then the "bum"; the heart at 96 until the delivery, the bars gone 8 s after the apex
	Tension = {
		Bars = 0.09,
		BarsIn = 0.6,
		BarsFor = 8,
		Duck = 0.55,
		HeartFrom = 86,
		HeartTo = 170,
		HeartNormal = 96,
		Pause = 0.25,
		Back = 0.4,
		Shake = "Jolt",
		Fov = -2.5,
		Blur = 2.5,
		Tint = "Cold",
		Grade = 0.4,
		Vignette = 0.25,
		Linger = 0.4,
		Whisper = 0.12,
		Max = 180, -- > the longest wait in the queue (patience 75 + 5K s; Hurry 40 s) plus the talk
	},
	-- the Queue scene steps a carrier skips (screen tension: it already has its own); Sound only without a Point (on screen)
	Carry = { "Cinema", "Whispers", "Heartbeat", "Vignette", "Grade", "Silence", "Blur", "Fov", "Shake", "Nudge", "Text" },
	CarrySounds = { "horror_sting", "suspense_drop", "hum_die", AnomalyHints.Rules.Sound },
}

-- ANM-012 (proposal §3.1): she arrives normal, the line freezes mid word on "...", the tension builds, three cracks turn
-- her head round (the first one is the apex: the "bum"), and she ends the line with her back to the camera
const turnedNeck: Tic = {
	Key = "anm_012_turned_neck",
	Variant = "neck",
	Kind = "Scare",
	Body = "Neck",
	Pre = { Kind = "Twitch", Every = { 5, 8 }, Value = 6, Time = 0.12, Volume = 0.15, Range = 8 },
	Line = { Text = "Evening. One hot dog, please.", Freeze = 0.65, Residue = "..." },
	Hold = 1.5, -- owner 2026-10-22: the build-up, 1-2 s (was 0.5)
	Beats = { Count = 3, Time = 0.1, Gap = 0.25, Volume = 0.8, Sound = "neck_crack" },
	After = 0.3,
	Turn = 60,
	-- the 2nd and 3rd cracks (the 1st is the apex: the tension's jolt)
	Steps = {
		{ At = 0.35, Phase = "Active", Kind = "Shake", Target = "Step" },
		{ At = 0.7, Phase = "Active", Kind = "Shake", Target = "Step" },
	},
	Caption = "[neck cracks]",
	Residue = "Reversed",
	OnLeave = "Follow",
	Queue = { Roll = 38, Pitch = 16 }, -- the broken neck while she waits (Provisional)
}

-- ANM-013 (proposal §3.3): normal eyes with a cold glint that ignores the room's light (the cameras already show them
-- white); mid line it closes its eyes on "..." while the tension builds and opens them all white at the apex, a cold
-- light from them on the taker's face, a low hum that rises and cuts
const whiteEyes: Tic = {
	Key = "anm_013_white_eyes",
	Variant = "eyes",
	Kind = "Scare",
	Body = "Eyes",
	Glint = { Brightness = 1.2, Range = 1.4 },
	Line = { Text = "Hi. One hot dog, please. Extra warm.", Freeze = 0.5, Residue = "..." },
	Hold = 1.5, -- the eyes closed (the eyelid down) through the build-up (owner 2026-10-22; was a 0.15 s blink)
	Beats = { Count = 1, Time = 0.6, Gap = 0, Volume = 0.5, Sound = "hum_rise" },
	After = 0.35,
	Light = { Brightness = 3, Residue = 0.8, Range = 6, Angle = 70 },
	-- the hum cuts after the beat (the vignette at the apex stands for the counter light at 40 %)
	Steps = {
		{ At = 0.6, Phase = "Active", Kind = "Sound", Target = "hum_die", Value = 0.5 },
	},
	Tension = { Fov = -2, Blur = 2, Grade = 0.45, Vignette = 0.3 },
	Caption = "[low hum]",
	Residue = "White",
	OnLeave = "Residue",
	Queue = { Light = 2 }, -- the white eyes burn brighter while she waits (Provisional)
}

-- ANM-004 (proposal §3.7): the copy says, letter by letter, the hi its original said to this same taker, a pause, then
-- the taker's own hi with their name; its head tilts while it says it. A clue, nothing stays on the body
const copyEcho: Tic = {
	Key = "anm_004_copies",
	Variant = "mirror",
	Kind = "Clue",
	Body = "Echo",
	Line = { Text = "Hi! Hi! What can I get you?", Freeze = 0.15, Residue = "...", Echo = true },
	Hold = 1.5, -- the pause on "..." before it says your line (owner 2026-10-22: the build-up; was 0.6)
	After = 0,
	Tilt = 14,
	Steps = {
		{ At = 0, Phase = "Active", Kind = "Sound", Target = "breath_held", Value = 0.5 },
	},
	-- a Clue: a Step for a jolt, no blur
	Tension = { Shake = "Step", Fov = -1.5, Blur = 0, Grade = 0.3, Vignette = 0.2 },
	Residue = "None",
	OnLeave = "Cancel",
}

-- ANM-014 (proposal §3.4, Q-461): the head arrives normal (the cameras show it huge); mid line it stops and the head grows
-- in two steps with a creak of leather, the close-up rising and backing off to keep the face in frame. A clue with a
-- minimal scare (one step shake on the second growth)
const bigHead: Tic = {
	Key = "anm_014_big_head",
	Variant = "bighead",
	Kind = "Clue",
	Body = "Head",
	Cameras = 2.6,
	Line = { Text = "Evening. I'd like a hot dog. Please.", Freeze = 0.4, Residue = "..." },
	Hold = 1.5, -- owner 2026-10-22: the build-up (was 0.1)
	Beats = { Count = 2, Time = 0.25, Gap = 0.45, Volume = 0.6, Sound = "door_creak" }, -- door_creak stands in for stretch_creak
	After = 0.25,
	Scales = { 1.45, 1.9 },
	-- the 2nd step of the head (the 1st is the apex)
	Steps = {
		{ At = 0.7, Phase = "Active", Kind = "Shake", Target = "Step" },
	},
	-- a Clue: a Step for a jolt, no blur; the colour goes sick
	Tension = { Shake = "Step", Fov = -1.5, Blur = 0, Tint = "Sick", Grade = 0.3, Vignette = 0.2 },
	Caption = "[leather creaks]",
	Residue = "Big",
	OnLeave = "Residue",
	-- swollen while it waits: x2.2, + 0.2 a Hurry step (2.4 / 2.6 / 2.8, 3.0 against the glass) (Provisional)
	Queue = { Scale = 2.2, PerStep = 0.2 },
}

-- ANM-001 (proposal §3.2 "the face that fades", owner 2026-10-22: "quando o cliente anomalia chega, ele já tá chegando sem
-- rosto... preciso que seja feita a correção"; Provisional): it arrives with its own face and mood (the cameras already
-- show it blank); mid line it stops on "...", and over the build-up its eyes, mouth and cheeks fade out while the typed
-- letters drop out one by one (OrderTalk style Blank); at the apex the face is gone, a soft hiss, and the rest of the line
-- comes out with letters missing. Its skin, markings and nose stay (only the face shell goes). It stays faceless in the
-- queue. A light Scare: it is the first anomaly of the run (Night 1)
const blankFace: Tic = {
	Key = "anm_001_blank_folks",
	Variant = "blank",
	Kind = "Scare",
	Body = "Face",
	Line = { Text = "Hi. Can I get a hot dog, please?", Freeze = 0.36, Residue = "..." },
	Hold = 1.5, -- the face fades over the whole build-up (the heart speeding up) and is gone at the apex
	Beats = { Count = 1, Time = 0.4, Gap = 0, Volume = 0.5, Sound = "suspense_hiss" },
	After = 0.35,
	Face = "Blank", -- CrewExpressions.Blank (AST-060, fully transparent): the face shell shows nothing
	Steps = {},
	-- lighter than the turned neck: a smaller punch for Night 1
	Tension = { Fov = -2, Blur = 1.5, Grade = 0.35, Vignette = 0.25 },
	Caption = "[soft hiss]",
	Residue = "Blank",
	OnLeave = "Residue",
}

const base = Table.new({ turnedNeck, whiteEyes, copyEcho, bigHead, blankFace })

const byVariant: { [string]: Tic } = {}
for _, row in base.List do
	byVariant[row.Variant] = row
end

-- The deterministic line pick of the talk (same formula as TabletController's pick): every client and the server choose
-- the same line of a list for the same customer
local function pick(list: { string }, npc: number, salt: number): string
	if #list == 0 then
		return ""
	end
	return list[(npc + salt) % #list + 1]
end

-- The taker's own hi (Restaurant.Dialog.Greeting) with their name
local function greeting(name: string): string
	const line = Restaurant.Dialog.Greeting[1] or "Hi!"
	if name == "" then
		return line
	end
	if string.sub(line, -1) == "?" then
		return `{string.sub(line, 1, -2)}, {name}?`
	end
	return `{line} {name}.`
end

-- The line with Rules.Trail put in after its first `chars` chars (the freeze); Chars then counts the trail too
local function trailed(text: string, chars: number): Said
	const trail = rules.Trail
	if trail == "" then
		return { Text = text, Chars = chars }
	end
	return { Text = string.sub(text, 1, chars) .. trail .. string.sub(text, chars + 1), Chars = chars + #trail }
end

-- Pure: the echo of the copy (Body Echo): the hi the original customer `original` opened its talk with (OrderTalk.Hello,
-- salt 1, as the tablet picks it), the trail, then the taker's own hi with `name`; Chars = the original's part + the trail
local function echo(original: number, name: string): Said
	const hello = pick(OrderTalk.Hello, original, 1)
	const tail = greeting(string.sub(name, 1, rules.NameMax))
	if hello == "" then
		return trailed(tail, 0)
	end
	return trailed(`{hello} {tail}`, #hello)
end

-- Pure: the line of a talk with this tic. `original` / `name` only for Line.Echo (nil = the row's own Text)
local function said(row: Tic, original: number?, name: string?): Said
	if row.Line.Echo == true and original ~= nil then
		return echo(original, name or "")
	end
	const length = #row.Line.Text
	return trailed(row.Line.Text, math.clamp(math.floor(length * row.Line.Freeze + 0.5), 0, length))
end

-- The taker's tension of a row: Rules.Tension with the row's own numbers over it
local function tensionOf(row: Tic): Tension
	const out = table.clone(rules.Tension)
	const patch = row.Tension
	if patch ~= nil then
		for field, value in patch :: any do
			(out :: any)[field] = value
		end
	end
	return out
end

-- The whispers of the apex and of the wait (Content.AnomalyHints: the hint's own words when it is Live, as the Queue
-- scene says them; else the generic list) and the hint itself (nil = not Live: no title)
const GENERIC_WORDS = "queue_generic"
local function wordsOf(key: string): (string, string, AnomalyHints.Hint?)
	const hint = AnomalyHints.ByKey[key]
	const burst = `hint_{key}`
	const wait = `queue_{key}`
	if hint ~= nil and hint.Live and HorrorScenes.Words[burst] ~= nil and HorrorScenes.Words[wait] ~= nil then
		return burst, wait, hint
	end
	return GENERIC_WORDS, GENERIC_WORDS, nil
end

-- The taker's layer of a row (header, "The taker's tension"): HorrorScenes steps, At = s from the Peak, sorted
local function layerOf(row: Tic): { HorrorScenes.Step }
	const t = tensionOf(row)
	const hold = row.Hold
	const build = math.max(hold - t.Pause, 0.05)
	const burst, wait, hint = wordsOf(row.Key)
	const hints = AnomalyHints.Rules
	const steps: { HorrorScenes.Step } = {
		-- the build-up (the line frozen on the trail): the bars, the room ducking, a slow heart speeding up, the edges
		{ At = -hold, Phase = "Active", Kind = "Cinema", Value = t.Bars, Duration = t.BarsIn },
		{ At = -hold, Phase = "Active", Kind = "Silence", Value = 1, To = t.Duck, Duration = t.BarsIn },
		{ At = -hold, Phase = "Active", Kind = "Heartbeat", Value = t.HeartFrom, To = t.HeartTo, Duration = build },
		{ At = -hold, Phase = "Active", Kind = "Vignette", Value = 0, To = t.Vignette * 0.5, Duration = build },
		-- the "paradinha": the room and the heart go quiet
		{ At = -t.Pause, Phase = "Active", Kind = "Silence", Value = t.Duck, To = 0, Duration = 0.1 },
		{ At = -t.Pause, Phase = "Active", Kind = "Heartbeat", Value = 0, To = 0 },
		-- the apex, the "bum": the whisper and the hint's words, the punch, the colour; the heart at its normal pace
		{ At = 0, Phase = "Active", Kind = "Sound", Target = hints.Sound, Value = hints.SoundVolume },
		{
			At = 0,
			Phase = "Active",
			Kind = "Whispers",
			Target = burst,
			Value = hints.WhisperRate,
			To = hints.WhisperRate,
			Duration = hints.WhisperFor,
		},
		{ At = 0, Phase = "Active", Kind = "Shake", Target = t.Shake },
		{ At = 0, Phase = "Active", Kind = "Fov", Value = t.Fov, To = 0, Duration = 0.8 },
		{ At = 0, Phase = "Active", Kind = "Grade", Target = t.Tint, Value = 0, To = t.Grade, Duration = 0.15 },
		{ At = 0, Phase = "Active", Kind = "Vignette", Value = t.Vignette * 0.5, To = t.Vignette, Duration = 0.15 },
		{ At = 0, Phase = "Active", Kind = "Heartbeat", Value = t.HeartNormal, To = t.HeartNormal, Duration = t.Max },
		{ At = t.Back, Phase = "Active", Kind = "Silence", Value = 0, To = 1, Duration = 0.8 },
		-- after: the whispers go on, low, until the delivery; the bars leave, the colour and the edges settle and stay
		{ At = hints.WhisperFor, Phase = "Active", Kind = "Whispers", Target = wait, Value = t.Whisper, To = t.Whisper, Duration = t.Max },
		{ At = t.BarsFor, Phase = "Active", Kind = "Cinema", Value = 0, Duration = 1.5 },
		{ At = t.BarsFor, Phase = "Active", Kind = "Vignette", Value = t.Vignette, To = t.Vignette * t.Linger, Duration = 3 },
		{ At = t.BarsFor, Phase = "Active", Kind = "Grade", Target = t.Tint, Value = t.Grade, To = t.Grade * t.Linger, Duration = 3 },
	}
	if t.Blur > 0 then
		const blur: HorrorScenes.Step = { At = 0, Phase = "Active", Kind = "Blur", Value = t.Blur, To = 0, Duration = 0.4 }
		table.insert(steps, blur)
	end
	if hint ~= nil then
		-- the title of the hint ("DON'T LOOK" over "EYES DOWN WHEN YOU HAND IT OVER"; Scene/Steps splits it at ". ")
		const title: HorrorScenes.Step = {
			At = 0,
			Phase = "Active",
			Kind = "Text",
			Text = `{hint.Title or hint.Hint}. {hint.Line}`,
			Duration = hints.CaptionTime,
		}
		table.insert(steps, title)
	end
	for _, step in row.Steps do
		table.insert(steps, step)
	end
	-- by At, ties in the order above (the layer runs them in this order)
	const order: { [HorrorScenes.Step]: number } = {}
	for index, step in steps do
		order[step] = index
	end
	table.sort(steps, function(a: HorrorScenes.Step, b: HorrorScenes.Step): boolean
		if a.At ~= b.At then
			return a.At < b.At
		end
		return order[a] < order[b]
	end)
	return steps
end

-- Typing (owner 2026-10-22): the pause after char k of `text`, before char k + 1 shows. Only at the end of a run of
-- punctuation ("..." pauses once) and never after the last char
const STOPS: { [string]: boolean } = { ["."] = true, ["!"] = true, ["?"] = true }
const COMMAS: { [string]: boolean } = { [","] = true, [";"] = true, [":"] = true }

local function pauseAfter(text: string, k: number): number
	const following = string.sub(text, k + 1, k + 1)
	if following == "" or STOPS[following] or COMMAS[following] then
		return 0
	end
	const char = string.sub(text, k, k)
	if STOPS[char] then
		return rules.PauseStop
	elseif COMMAS[char] then
		return rules.PauseComma
	end
	return 0
end

-- Pure: s to type chars from + 1 .. to of `text` (char `to` shows at the end of it)
local function typeTime(text: string, from: number, to: number): number
	if to <= from then
		return 0
	end
	local total = (to - from) / rules.TypeRate
	for k = from + 1, to - 1 do
		total += pauseAfter(text, k)
	end
	return total
end

-- Pure: chars of `text` shown `elapsed` s after typing (re)started with `from` chars already shown
local function typedAt(text: string, from: number, elapsed: number): number
	const length = #text
	local typed = math.clamp(from, 0, length)
	local time = 0
	while typed < length do
		const nextTime = time + 1 / rules.TypeRate + (if typed > from then pauseAfter(text, typed) else 0)
		if nextTime > elapsed + 1e-9 then
			break
		end
		time = nextTime
		typed += 1
	end
	return typed
end

-- Pure: the clock of a tic (s from LineStart); `line` = the talk's Said (nil = the row's own)
local function timing(row: Tic, line: Said?): Timing
	const say = line or said(row)
	const length = #say.Text
	const chars = math.clamp(say.Chars, 0, length)
	const freeze = typeTime(say.Text, 0, chars)
	const beats: { number } = {}
	const spec = row.Beats
	const count = if spec ~= nil then spec.Count else 0
	for index = 1, count do
		const beat = spec :: Beats
		table.insert(beats, freeze + row.Hold + (index - 1) * (beat.Time + beat.Gap))
	end
	const last = beats[#beats]
	const beatsEnd = if last ~= nil and spec ~= nil then last + spec.Time else freeze + row.Hold
	const resume = beatsEnd + row.After
	return {
		Chars = chars,
		Freeze = freeze,
		Beats = beats,
		Peak = beats[1] or (freeze + row.Hold),
		BeatsEnd = beatsEnd,
		Resume = resume,
		End = resume + typeTime(say.Text, chars, length),
	}
end

-- Pure: what the card shows `elapsed` s after LineStart (typed part, the freeze, the caption from the peak on)
local function lineAt(row: Tic, elapsed: number, line: Said?): string
	const say = line or said(row)
	const t = timing(row, say)
	const text = say.Text
	if elapsed < 0 then
		return ""
	end
	if elapsed < t.Freeze then
		return string.sub(text, 1, typedAt(text, 0, elapsed))
	end
	const head = string.sub(text, 1, t.Chars)
	if elapsed < t.Resume then
		const caption = row.Caption
		if caption ~= nil and elapsed >= t.Peak then
			return `{head}\n{caption}`
		end
		return head
	end
	return string.sub(text, 1, typedAt(text, t.Chars, elapsed - t.Resume))
end

-- the taker's layer of every row, by Key (built once: pure data)
const layers: { [string]: { HorrorScenes.Step } } = {}
for _, row in base.List do
	layers[row.Key] = layerOf(row)
end

return Table.with(base, {
	Rules = rules,
	ByVariant = byVariant,
	Layers = layers,
	Said = said,
	Echo = echo,
	Timing = timing,
	LineAt = lineAt,
	TypeTime = typeTime,
	TypedAt = typedAt,
	TensionOf = tensionOf,
})
