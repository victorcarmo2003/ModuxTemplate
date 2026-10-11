--!strict
-- Sounds, music cues and sound rules (content-data.md §3.21; architecture.md §19.21, T55; sound-list.md; Q-168).
-- Owner: art-director + user (ids and license in docs/art/credits.md). Provisional list; every Id is "" until the
-- upload: AudioController plays nothing for "" (no error, no repeated warn). No network: each controller plays on
-- the event it already receives.
-- Music (cues): AudioController plays the highest Priority cue whose When holds; PushMusic overrides (cutscene).
-- When: IsNight (shift kind), Phase (keys of Shift), Window (Nights.Windows name); nil field = any.
-- Shift music (user decision 2026-10-10, sound-list.md §3): no looped day/night theme. At the start of each shift
-- (Rules.ShiftMusicPhase) one track of the shift's pool plays once (Looped = false), never twice in a row when the
-- pool allows; a client that joins after Rules.ShiftMusicFresh seconds of that phase hears nothing. The rest of the
-- shift is only the street ambience (Rules.Ambient, crossfaded loop; Rules.AmbientZones inside the Mart). No credits
-- music.
local Table = require(script.Parent.Table)

export type Group = "Music" | "Ambient" | "Sfx" | "Voice" | "Ui"

export type Sound = {
	Key: string,
	Id: string,
	Group: Group,
	Volume: number, -- 0..1
	Looped: boolean,
	Spatial: boolean,
	MaxDistance: number, -- studs (Spatial only)
	Ref: string, -- AST-### / license line in credits.md
	-- s: Ambient beds loop by crossfading two copies (user request 2026-10-10): fade-in at the start, fade-out over the
	-- last Crossfade s while the next copy fades in from the start; also the fade between two beds. Capped at 1/4 of
	-- the track length by AudioController. 0 = plain Looped (or no fade) for the other groups.
	Crossfade: number,
}

export type When = {
	IsNight: boolean?,
	Phase: { string }?,
	Window: string?,
}

export type Cue = {
	Key: string,
	Sound: string, -- key of Sounds (Group Music)
	When: When,
	FadeIn: number,
	FadeOut: number,
	Priority: number,
}

export type SoundRules = {
	MaxVoices: number, -- pool cap (architecture.md §12.5)
	DuckOnCall: number, -- music volume multiplier while the boss is talking
	SirenMaxVolume: number, -- never above the ambience (DEC-005)
	ScareMaxVolume: number, -- DEC-173
	ShiftMusic: ShiftPool, -- one track per shift start (user decision 2026-10-10)
	ShiftMusicPhase: string, -- key of Shift where the shift starts
	ShiftMusicFresh: number, -- s: joined later than this into ShiftMusicPhase = no shift music
	Ambient: ShiftAmbient, -- street ambience looped through the shift
	AmbientZones: { [string]: string }, -- LightZone ZoneId -> Ambient key that replaces the street inside it
	AmbientOff: { string }, -- keys of Shift without street ambience (cutscenes, end of run)
	-- horror layer on top of the street bed (user request 2026-10-10): the client has no NpcService.Tension, so it
	-- follows the night window (Nights.Windows) instead. Provisional.
	Tension: TensionLayer,
	Stings: Stings,
}

export type TensionLayer = {
	Key: string, -- key of Sounds (Group Ambient, looped, crossfaded like the other beds)
	Window: string, -- key of Nights.Windows where the layer plays
}

-- one-shot stingers keyed by game event (keys of Sounds; user request 2026-10-10)
export type Stings = {
	AnomalyStart: string, -- a fresh anomaly record appears (AnomalyController)
	AnomalyResolved: string, -- an anomaly goes Resolved (AnomalyController)
	AnomalySeen: string, -- own sanity drops by the SeeAnomaly penalty (VitalController)
	NightLost: string, -- phase NightLost starts (AudioController)
	LastWindow: string, -- night window turns Tension.Window (AudioController)
}

export type ShiftPool = {
	Day: { string }, -- keys of Sounds (Group Music, Looped = false)
	Night: { string },
}

export type ShiftAmbient = {
	Day: string, -- key of Sounds (Group Ambient)
	Night: string,
}

local function music(key: string, id: string?, ref: string?, looped: boolean?): Sound
	return {
		Key = key,
		Id = id or "",
		Group = "Music",
		Volume = 0.5,
		Looped = looped ~= false,
		Spatial = false,
		MaxDistance = 0,
		Ref = ref or "",
		Crossfade = 0,
	}
end

const AMBIENT_CROSSFADE = 4 -- s, default (user request 2026-10-10)

local function ambient(key: string, spatial: boolean, id: string?, ref: string?): Sound
	return {
		Key = key,
		Id = id or "",
		Group = "Ambient",
		Volume = 0.4,
		Looped = true,
		Spatial = spatial,
		MaxDistance = if spatial then 80 else 0,
		Ref = ref or "",
		Crossfade = AMBIENT_CROSSFADE,
	}
end

-- SFX uploaded by the user (ReplicatedStorage.Assets.SFX, 2026-10-10; the Sound in Studio is named after the key,
-- a Sound shared by two keys carries the attribute `Keys`); key -> rbxassetid
const UPLOADED: { [string]: string } = {
	grill_sizzle = "rbxassetid://6383276435",
	grill_drop = "rbxassetid://126425746730419",
	grill_ready = "rbxassetid://131845870598154",
	grill_collect = "rbxassetid://137054034685704",
	restock = "rbxassetid://137054034685704",
	bun_slice = "rbxassetid://120927697011937",
	topping_squirt = "rbxassetid://90416226721742",
	topping_sprinkle = "rbxassetid://9117851142",
	coin = "rbxassetid://134810204798705",
	buy = "rbxassetid://135428907715078",
	phone_ring = "rbxassetid://94426589952590",
	toast = "rbxassetid://82845990304289",
	-- second batch (2026-10-10)
	coffee_drink = "rbxassetid://9119956292",
	coffee_brew = "rbxassetid://365956378",
	coffee_ready = "rbxassetid://9113797219",
	serve = "rbxassetid://9120360136",
	tip = "rbxassetid://136997066809686",
	cust_complain = "rbxassetid://117138471132867",
	cust_wrong = "rbxassetid://117138471132867",
	cust_happy = "rbxassetid://78566355879660",
	order_take = "rbxassetid://5646714647",
	cust_leave = "rbxassetid://136969027013552",
	thief_open = "rbxassetid://9098369357",
	thief_caught = "rbxassetid://9066673412",
	walker_step = "rbxassetid://132709106261511",
	refuse = "rbxassetid://87519554692663",
	error = "rbxassetid://87519554692663",
	prompt_hold = "rbxassetid://130114397986399",
	prompt_done = "rbxassetid://6586979979",
	summary = "rbxassetid://85797456007679",
	switch_click = "rbxassetid://139658322785649",
	door_knock = "rbxassetid://9114141961",
	curtain = "rbxassetid://320662396",
	roof_step = "rbxassetid://73343053773763",
	shadow_whoosh = "rbxassetid://112608566235074",
	smoke_poof = "rbxassetid://18319185077",
	whisper = "rbxassetid://1228230799",
	splash = "rbxassetid://18816874251",
	revive = "rbxassetid://78076438768803",
	faint = "rbxassetid://1604497989",
	door_creak = "rbxassetid://125209584906878",
	door_close = "rbxassetid://140470748655921",
	car_honk_soft = "rbxassetid://81569612419754",
	car_honk_goofy = "rbxassetid://132205340213071",
	phone_hangup = "rbxassetid://18979737221",
	post_buzz = "rbxassetid://9043345732",
	anomaly_see = "rbxassetid://139376960218145",
	jumpscare = "rbxassetid://127224418529132",
	horror_sting = "rbxassetid://1014740409",
	horror_dramatic = "rbxassetid://72200450832308",
	scary_violins = "rbxassetid://6080419021",
	phone_glitch = "rbxassetid://140367728848843",
	horror_chase_stop = "rbxassetid://123355946453444",
	ui_click = "rbxassetid://127105730240202",
}

-- Per-row overrides of the sfx() defaults
export type SfxOptions = {
	Volume: number?,
	Spatial: boolean?,
	MaxDistance: number?,
}

local function sfx(key: string, looped: boolean?, opts: SfxOptions?): Sound
	const spatial = if opts and opts.Spatial ~= nil then opts.Spatial else true
	return {
		Key = key,
		Id = UPLOADED[key] or "",
		Group = "Sfx",
		Volume = if opts and opts.Volume then opts.Volume else 0.6,
		Looped = looped == true,
		Spatial = spatial,
		MaxDistance = if not spatial then 0 elseif opts and opts.MaxDistance then opts.MaxDistance else 60,
		Ref = "",
		Crossfade = 0,
	}
end

local function ui(key: string, volume: number?): Sound
	return {
		Key = key,
		Id = UPLOADED[key] or "",
		Group = "Ui",
		Volume = volume or 0.5,
		Looped = false,
		Spatial = false,
		MaxDistance = 0,
		Ref = "",
		Crossfade = 0,
	}
end

const base = Table.new({
	-- Music
	music("music_lobby", "rbxassetid://133495425923316", "Lobby (Axiom Project Studio upload)"),
	music("music_finale", "rbxassetid://86360851369933", "Melancolic City (Axiom Project Studio upload)"),
	-- shift start pools (once, no loop)
	music("music_day_sunny", "rbxassetid://88103069634103", "Sunny Town (Axiom Project Studio upload)", false),
	music("music_day_small", "rbxassetid://104601257905379", "Small Town (Axiom Project Studio upload)", false),
	music("music_night_town", "rbxassetid://73501320034226", "Night Town (Axiom Project Studio upload)", false),
	music("music_night_fall", "rbxassetid://135232738690923", "Night Fall (Axiom Project Studio upload)", false),
	-- Ambient
	ambient("amb_day_street", false, "rbxassetid://108990827199430", "CityAmbient (Axiom Project Studio upload)"),
	ambient("amb_night_street", false, "rbxassetid://98652860867664", "NightCrickets (Axiom Project Studio upload)"),
	-- inside the Mart (LZ-4), replaces the street bed (Rules.AmbientZones)
	ambient("amb_mart_hum", false, "rbxassetid://121312424334285", "SuperMarket Ambient (Axiom Project Studio upload)"),
	ambient("amb_clock_tick", true, "rbxassetid://9043366464", "Clock(Looped) (user upload)"), -- C-01
	ambient("amb_fog", false, "rbxassetid://9118748093", "Ambient Fog (user upload)"), -- N10
	-- horror layer over the street bed in the tense window (Rules.Tension)
	ambient("amb_horror", false, "rbxassetid://88784462446827", "HorrorAmbient (user upload)"),
	-- Sfx
	sfx("grill_sizzle", true),
	sfx("bun_slice"),
	sfx("topping_squirt"),
	sfx("topping_sprinkle"),
	sfx("restock"),
	sfx("coin"),
	sfx("drawer"),
	sfx("buy"),
	sfx("upgrade_done"),
	sfx("trash"),
	sfx("coffee_brew", true),
	sfx("coffee_drink"),
	sfx("switch_click"),
	sfx("phone_ring", true),
	sfx("phone_pickup"),
	sfx("car_engine", true),
	sfx("car_honk_soft"),
	sfx("hit_boing"),
	sfx("siren_soft", true),
	sfx("door_knock"),
	sfx("door_creak"),
	sfx("curtain"),
	sfx("post_buzz"), -- Walker start, DEC-123
	sfx("post_tunk"),
	sfx("walker_step"),
	sfx("smoke_poof"),
	sfx("splash"),
	sfx("whisper"),
	sfx("thief_open"),
	sfx("thief_caught"),
	sfx("faint"),
	sfx("revive"),
	-- TASK-079 / TASK-119 event keys (ids empty until upload, Q-168)
	sfx("grill_drop"),
	sfx("grill_ready"),
	sfx("grill_collect"),
	sfx("hotdog_assemble"),
	sfx("coffee_ready"),
	sfx("order_take"),
	sfx("serve"),
	sfx("tip"),
	sfx("cust_happy"),
	sfx("cust_complain"),
	sfx("cust_wrong"),
	sfx("cust_leave"),
	sfx("refuse"),
	sfx("roof_step"),
	sfx("post_click"),
	sfx("neon_click"),
	sfx("shadow_whoosh"),
	-- second batch (user request 2026-10-10)
	sfx("door_close"),
	sfx("car_honk_goofy", false, { Volume = 1, MaxDistance = 160 }), -- comic scare on the N8 SUV, outside the scare cap
	sfx("phone_hangup"),
	-- horror stingers: on screen (not spatial)
	sfx("anomaly_see", false, { Spatial = false, Volume = 0.5 }),
	sfx("jumpscare", false, { Spatial = false, Volume = 0.5 }),
	sfx("horror_sting", false, { Spatial = false, Volume = 0.4 }),
	sfx("horror_dramatic", false, { Spatial = false, Volume = 0.5 }),
	sfx("scary_violins", false, { Spatial = false, Volume = 0.4 }),
	sfx("phone_glitch"),
	sfx("horror_chase_stop", false, { Spatial = false, Volume = 0.4 }),
	-- Ui
	ui("toast"),
	ui("summary"),
	ui("prompt_done"),
	ui("skip_vote"),
	ui("error"),
	ui("prompt_hold", 0.35),
	ui("ui_click", 0.4),
	-- Voice: empty in the MVP (subtitles without voice)
} :: { Sound })

const cues = Table.new({
	-- lobby only before the first Shift record (empty When, see AudioController Cues)
	{ Key = "lobby", Sound = "music_lobby", When = {}, FadeIn = 1, FadeOut = 1, Priority = 0 },
	-- finale (FEAT-027) and through the credits scene of the same phase; RunEnd has no music
	{ Key = "finale", Sound = "music_finale", When = { Phase = { "Finale" } }, FadeIn = 2, FadeOut = 2, Priority = 5 },
} :: { Cue })

const rules: SoundRules = {
	MaxVoices = 12, -- architecture.md §12.5
	DuckOnCall = 0.3,
	SirenMaxVolume = 0.5, -- DEC-005 (below the ambience peak; tune in play)
	ScareMaxVolume = 0.5, -- DEC-173
	ShiftMusic = {
		Day = { "music_day_sunny", "music_day_small" },
		Night = { "music_night_town", "music_night_fall" },
	},
	ShiftMusicPhase = "Prep", -- 7 AM / 7 PM: start of every shift (Shift.luau)
	ShiftMusicFresh = 5, -- Provisional (frontend-coder)
	Ambient = { Day = "amb_day_street", Night = "amb_night_street" },
	AmbientZones = { ["LZ-4"] = "amb_mart_hum" }, -- MAP-01 §10.2: LZ-4 = Mart interior
	AmbientOff = { "Intro", "Finale", "RunEnd" },
	Tension = { Key = "amb_horror", Window = "Last" }, -- 5-6 AM (Provisional: no Tension on the client)
	Stings = {
		AnomalyStart = "horror_sting",
		AnomalyResolved = "horror_chase_stop",
		AnomalySeen = "anomaly_see",
		NightLost = "horror_dramatic",
		LastWindow = "scary_violins",
	},
}

return Table.with(base, {
	Music = cues,
	Rules = Table.record(rules),
})
