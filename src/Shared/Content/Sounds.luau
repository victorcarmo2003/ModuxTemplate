--!strict
-- Sounds, music cues and sound rules (content-data.md §3.21; architecture.md §19.21, T55; sound-list.md; Q-168).
-- Owner: art-director + user (ids and license in docs/art/credits.md). Provisional list; every Id is "" until the
-- upload: AudioController plays nothing for "" (no error, no repeated warn). No network: each controller plays on
-- the event it already receives.
-- Music (cues): AudioController plays the highest Priority cue whose When holds; PushMusic overrides (cutscene).
-- When: IsNight (shift kind), Phase (keys of Shift), Window (Nights.Windows name); nil field = any.
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
}

local function music(key: string, id: string?, ref: string?): Sound
	return { Key = key, Id = id or "", Group = "Music", Volume = 0.5, Looped = true, Spatial = false, MaxDistance = 0, Ref = ref or "" }
end

local function ambient(key: string, spatial: boolean): Sound
	return {
		Key = key,
		Id = "",
		Group = "Ambient",
		Volume = 0.4,
		Looped = true,
		Spatial = spatial,
		MaxDistance = if spatial then 80 else 0,
		Ref = "",
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
	}
end

local function ui(key: string): Sound
	return { Key = key, Id = "", Group = "Ui", Volume = 0.5, Looped = false, Spatial = false, MaxDistance = 0, Ref = "" }
end

const base = Table.new({
	-- Music
	music("music_lobby", "rbxassetid://133495425923316", "Lobby (Axiom Project Studio upload)"),
	music("music_day", "rbxassetid://88103069634103", "Sunny Town (Axiom Project Studio upload)"),
	music("music_night_calm", "rbxassetid://73501320034226", "Night Town (Axiom Project Studio upload)"),
	music("music_night", "rbxassetid://135232738690923", "Night Fall (Axiom Project Studio upload)"),
	music("music_finale", "rbxassetid://86360851369933", "Melancolic City (Axiom Project Studio upload)"),
	music("music_credits", "rbxassetid://104601257905379", "Small Town (Axiom Project Studio upload)"),
	-- Ambient
	ambient("amb_day_street", false),
	ambient("amb_night_street", false),
	ambient("amb_mart_hum", true),
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
	{ Key = "lobby", Sound = "music_lobby", When = {}, FadeIn = 1, FadeOut = 1, Priority = 0 },
	{ Key = "day", Sound = "music_day", When = { IsNight = false }, FadeIn = 2, FadeOut = 2, Priority = 1 },
	{
		Key = "night_calm",
		Sound = "music_night_calm",
		When = { IsNight = true, Phase = { "Night" }, Window = "Calm" },
		FadeIn = 3,
		FadeOut = 3,
		Priority = 3,
	},
	{ Key = "night", Sound = "music_night", When = { IsNight = true }, FadeIn = 3, FadeOut = 3, Priority = 2 },
	{ Key = "finale", Sound = "music_finale", When = { Phase = { "Finale" } }, FadeIn = 2, FadeOut = 2, Priority = 5 },
	{ Key = "credits", Sound = "music_credits", When = { Phase = { "RunEnd" } }, FadeIn = 2, FadeOut = 2, Priority = 4 },
} :: { Cue })

const rules: SoundRules = {
	MaxVoices = 12, -- architecture.md §12.5
	DuckOnCall = 0.3,
	SirenMaxVolume = 0.5, -- DEC-005 (below the ambience peak; tune in play)
	ScareMaxVolume = 0.5, -- DEC-173
}

return Table.with(base, {
	Music = cues,
	Rules = Table.record(rules),
})
