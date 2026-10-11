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

local function sfx(key: string, looped: boolean?): Sound
	return {
		Key = key,
		Id = "",
		Group = "Sfx",
		Volume = 0.6,
		Looped = looped == true,
		Spatial = true,
		MaxDistance = 60,
		Ref = "",
		Crossfade = 0,
	}
end

local function ui(key: string): Sound
	return {
		Key = key,
		Id = "",
		Group = "Ui",
		Volume = 0.5,
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
	ambient("amb_clock_tick", true), -- C-01
	ambient("amb_fog", false), -- N10
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
	-- Ui
	ui("toast"),
	ui("summary"),
	ui("prompt_done"),
	ui("skip_vote"),
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
}

return Table.with(base, {
	Music = cues,
	Rules = Table.record(rules),
})
