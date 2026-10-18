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
	-- Name of the owner's Sound under ReplicatedStorage.Assets.SFX (searched by name in every subfolder, so the folder
	-- can be reorganised, TASK-445). While Id is "" AudioController plays that Sound's SoundId instead (TASK-443).
	Studio: string?,
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
	lights_off = "rbxassetid://85819123510701", -- ReplicatedStorage.Assets.SFX.Horror["lights off"] (owner, 2026-10-17)
	gear_door_open = "rbxassetid://95190972742619", -- ReplicatedStorage.Assets.SFX["Metal Door Open"] (owner, 2026-10-17)
	gear_door_close = "rbxassetid://140635119444127", -- ReplicatedStorage.Assets.SFX["Metal Door Close"]
	phone_pickup = "rbxassetid://9117155406",
	skip_vote = "rbxassetid://127105730240202",
	upgrade_done = "rbxassetid://107354373677586",
	trash = "rbxassetid://7167887983",
	hotdog_assemble = "rbxassetid://9117202122",
	drawer = "rbxassetid://77821440186535",
	drawer_close = "rbxassetid://132866165925970",
	car_engine = "rbxassetid://137048982817372",
	hit_boing = "rbxassetid://7336107955",
	siren_soft = "rbxassetid://99437009615612",
	post_click = "rbxassetid://140494750798924",
	post_tunk = "rbxassetid://140494750798924",
	neon_click = "rbxassetid://114396515637886",
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
	whispers_bed = "rbxassetid://102565494871173", -- owner Studio upload "Whispers" (2026-10-18)
	heartbeat = "rbxassetid://139459003161851", -- owner Studio upload "heartbeat" (2026-10-18)
	horror_chase_stop = "rbxassetid://123355946453444",
	ui_click = "rbxassetid://127105730240202",
	thunder = "rbxassetid://9113169432", -- ATM-5 (TASK-275): "Artillery Distant 2 (SFX)", ProSoundEffects
	locked_door = "rbxassetid://136518625715192", -- SFX-232 ReplicatedStorage.Assets.SFX["Locked door"] (user, ANM-004)
	-- ANM-003 bell (TASK-340): ReplicatedStorage.Assets.SFX["Very scary bell sound/church bell"] (user upload)
	church_bell = "rbxassetid://6891548543",
	-- ANM-012 neck snap (TASK-336): ReplicatedStorage.Assets.SFX["Bone crack"] (user upload, 2026-10-15)
	neck_crack = "rbxassetid://88191175836931",
}

-- Per-row overrides of the sfx() defaults
export type SfxOptions = {
	Volume: number?,
	Spatial: boolean?,
	MaxDistance: number?,
	Id: string?, -- Creator Store audio not in UPLOADED (licence line in Ref)
	Ref: string?,
}

local function sfx(key: string, looped: boolean?, opts: SfxOptions?): Sound
	const spatial = if opts and opts.Spatial ~= nil then opts.Spatial else true
	return {
		Key = key,
		Id = UPLOADED[key] or (if opts and opts.Id then opts.Id else ""),
		Group = "Sfx",
		Volume = if opts and opts.Volume then opts.Volume else 0.6,
		Looped = looped == true,
		Spatial = spatial,
		MaxDistance = if not spatial then 0 elseif opts and opts.MaxDistance then opts.MaxDistance else 60,
		Ref = if opts and opts.Ref then opts.Ref else "",
		Crossfade = 0,
	}
end

-- Row whose audio is the owner's Studio Sound (Assets.SFX, by name) until its rbxassetid is copied into UPLOADED
local function studio(row: Sound, name: string): Sound
	row.Studio = name
	if row.Ref == "" then
		row.Ref = `{name} (owner Studio upload)`
	end
	return row
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
	-- horror score themes (TASK-443, Content.Score): the owner's Studio Sounds, looped by the director
	studio(music("score_violins", "rbxassetid://6080419021", "Scary Violins Sound Effect (owner Studio upload)"), "Scary Violin Notes"), -- Tension (speed and volume ramp); the blackout loops it (Rise). Studio name renamed by the owner 2026-10-18
	-- the blackout's rising single violin note, 35 s file played ONCE and cut at 30 s (owner 2026-10-18; Content.Score stage Rise, Layer)
	studio(music("score_violin_up", "rbxassetid://123948659352085", "Scary Violin UP (owner Studio upload)", false), "Scary Violin UP"),
	studio(music("score_coral", "rbxassetid://1846886137", "Horror Coral (owner Studio upload)"), "Horror Coral"), -- Climax
	-- Ambient
	ambient("amb_day_street", false, "rbxassetid://108990827199430", "CityAmbient (Axiom Project Studio upload)"),
	ambient("amb_night_street", false, "rbxassetid://98652860867664", "NightCrickets (Axiom Project Studio upload)"),
	-- inside the Mart (LZ-4), replaces the street bed (Rules.AmbientZones)
	ambient("amb_mart_hum", false, "rbxassetid://121312424334285", "SuperMarket Ambient (Axiom Project Studio upload)"),
	ambient("amb_clock_tick", true, "rbxassetid://9043366464", "Clock(Looped) (user upload)"), -- C-01
	ambient("amb_fog", false, "rbxassetid://9118748093", "Ambient Fog (user upload)"), -- N10
	-- horror layer over the street bed in the tense window (Rules.Tension)
	ambient("amb_horror", false, "rbxassetid://88784462446827", "HorrorAmbient (user upload)"),
	-- atmospheres ATM-4 / ATM-5 (TASK-275; AtmosphereController plays it on screen, fades it with the look)
	ambient("amb_rain", false, "rbxassetid://9112853286", "Rain Heavy 2 (SFX), ProSoundEffects"),
	-- Sfx
	sfx("grill_sizzle", true),
	sfx("bun_slice"),
	sfx("topping_squirt"),
	sfx("topping_sprinkle"),
	sfx("restock"),
	sfx("coin"),
	sfx("drawer"),
	sfx("drawer_close"),
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
	sfx("locked_door"), -- ANM-004: back door locked by the anomaly (DEC-247)
	-- Gear Stand business hours (owner request 2026-10-17; Content.Mart.Hours): the owner's ReplicatedStorage.Assets.SFX
	-- ["Metal Door Open"] / ["Metal Door Close"]. Id still "" (rbxassetid not copied out of Studio yet): MarketController
	-- plays the Studio Sound itself until the Id is filled in UPLOADED, then AudioController takes over.
	sfx("gear_door_open", false, { MaxDistance = 80 }),
	sfx("gear_door_close", false, { MaxDistance = 80 }),
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
	-- owner 2026-10-18: a whisper bed under the on-screen whispers (Kit/Whispers) and a single heartbeat (HorrorScenes Heartbeat)
	studio(sfx("whispers_bed", true, { Spatial = false, Volume = 0.45 }), "Whispers"),
	studio(sfx("heartbeat", false, { Spatial = false, Volume = 0.9 }), "heartbeat"),
	sfx("horror_chase_stop", false, { Spatial = false, Volume = 0.4 }),
	sfx("thunder", false, { Spatial = false, Volume = 0.6 }), -- ATM-5 storm (TASK-275)
	-- anomalies, owner requests 2026-10-15 (TASK-331..340). Id "" = silence until the owner sends the file
	sfx("church_bell", false, { Spatial = false, Volume = 0.9 }), -- ANM-003: the three strokes
	sfx("neck_crack", false, { Volume = 0.9, MaxDistance = 50 }), -- ANM-012: the neck turns for good (owner's SFX)
	sfx("window_slam", false, { Volume = 1, MaxDistance = 80 }), -- ANM-012: the window thrown open (door_close fallback)
	sfx("car_screech", false, { Volume = 0.9, MaxDistance = 140 }), -- ANM-008: brakes in front of the trailer
	sfx("swarm_flutter", false, { Volume = 0.8, MaxDistance = 90 }), -- ANM-003: moths and bats (shadow_whoosh fallback)
	-- ANM-020 blackout (TASK-444): the owner's "lights off" snap when the power goes out (post_tunk while unresolved)
	studio(sfx("lights_off", false, { Spatial = false, Volume = 0.8 }), "lights off"),
	-- blackout scene bank (TASK-466; design/horror-cinematic.md §4.6; sound-list.md §5.19). Creator Store audio of the
	-- Pro Sound Effects library (free inside Roblox experiences, credits.md); every pick Provisional until the owner's Play.
	-- Id "" = no safe candidate yet (silence; the scene keeps the old key).
	sfx("power_cut", false, { Spatial = false, Volume = 0.8, Id = "rbxassetid://9113808115", Ref = "SFX-233 Circuit Breaker 1 (SFX), ProSoundEffects" }),
	sfx("hum_rise", false, { Spatial = false, Volume = 0.4, Id = "rbxassetid://9116266188", Ref = "SFX-234 Light Bulb Buzz 4 (SFX), ProSoundEffects" }),
	sfx("hum_die", false, { Spatial = false, Volume = 0.4, Id = "rbxassetid://9117871125", Ref = "SFX-235 Power Down 1 (SFX), ProSoundEffects" }),
	sfx("heavy_steps", false, { Volume = 0.7, MaxDistance = 80, Ref = "SFX-236 no safe candidate (walker_step stands in)" }),
	sfx("steps_stop", false, { Volume = 0.6, MaxDistance = 60, Id = "rbxassetid://9114523345", Ref = "SFX-237 Foot Stomp 3 (SFX), ProSoundEffects" }),
	sfx("handle_rattle", false, { Volume = 0.6, MaxDistance = 40, Id = "rbxassetid://9114138011", Ref = "SFX-238 Door Knob Jiggle 1 (SFX), ProSoundEffects" }),
	sfx("door_force", false, { Volume = 0.6, MaxDistance = 40, Id = "rbxassetid://9114152574", Ref = "SFX-239 Door Shake 1 (SFX), ProSoundEffects" }),
	sfx("latch_hold", false, { Volume = 0.6, MaxDistance = 40, Id = "rbxassetid://9114881875", Ref = "SFX-240 Iron Door Latch 3 (SFX), ProSoundEffects" }),
	sfx("breath_held", false, { Spatial = false, Volume = 0.25, Id = "rbxassetid://9125572450", Ref = "SFX-241 Gasps Male Deep Breaths Fast Pants Frightened (SFX), ProSoundEffects" }),
	sfx("power_up", false, { Spatial = false, Volume = 0.7, Id = "rbxassetid://9117885256", Ref = "SFX-242 Power Up Sweeteners 10 (SFX), ProSoundEffects" }),
	sfx("lamps_cascade", false, { Spatial = false, Volume = 0.5, Id = "rbxassetid://9116266327", Ref = "SFX-243 Light Bulb Buzz 6 (SFX), ProSoundEffects" }),
	-- suspense events (TASK-481, TASK-486; DEC-294; design/horror-cinematic.md §7; sound-list.md §5.20). Same library
	-- and licence as the blackout bank; Provisional until the owner's Play
	sfx("suspense_drop", false, { Spatial = false, Volume = 0.8, Id = "rbxassetid://9125484700", Ref = "SFX-244 Deep Hits Big Reverberant Booms Rumbling Tail 1 (SFX), ProSoundEffects" }),
	sfx("suspense_hiss", false, { Volume = 0.6, MaxDistance = 90, Id = "rbxassetid://9113989919", Ref = "SFX-245 Creature Vocal Spider Hiss Exhale 1 (SFX), ProSoundEffects" }),
	sfx("floor_scratch", false, { Volume = 0.7, MaxDistance = 50, Id = "rbxassetid://9126170038", Ref = "SFX-246 Wallpaper Rip Slowed Crunchy Tears Off Wall 4 (SFX), ProSoundEffects" }),
	-- TASK-483: the boards giving under the crawler (restaurant, Signal of its scene)
	sfx("floor_creak", false, { Volume = 0.6, MaxDistance = 50, Id = "rbxassetid://9120832269", Ref = "SFX-247 Wood Creak Intense Cracking Splintering 1 (SFX), ProSoundEffects" }),
	-- restaurant (tech/restaurant-flow.md rev. 2 §4.2; wave R0 rows, Id "" = silence until the audio list uploads them)
	sfx("plate_put", false, { Volume = 0.5, MaxDistance = 40 }),
	sfx("ticket_pop", false, { Spatial = false, Volume = 0.4 }), -- HUD note pop-up per item at the tablet
	sfx("dialog_blip", false, { Volume = 0.4, MaxDistance = 30 }),
	sfx("grill_burnt", false, { Volume = 0.6, MaxDistance = 50 }),
	sfx("car_horn", false, { Volume = 0.8, MaxDistance = 120 }),
	sfx("car_horn_long", false, { Volume = 0.9, MaxDistance = 120 }),
	sfx("car_arrive", false, { Volume = 0.6, MaxDistance = 100 }),
	sfx("van_arrive", false, { Volume = 0.6, MaxDistance = 100 }), -- FEAT-050 delivery at the hatch
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
		-- owner 2026-10-18: no soundtrack at night (the street ambience stays; the horror score still plays its stages)
		Night = {},
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
