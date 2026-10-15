--!strict
-- The ten anomalies, shared side (content-data.md §3.17, §6.10; architecture.md §19.13, T10, T43, T53; FEAT-022;
-- docs/story/anomalies.md; design/npcs.md NPC-009..018; DEC-054, DEC-060, DEC-073, DEC-074, DEC-096, DEC-195,
-- DEC-204). Keys are the Anomalies.Anomaly / AnomalyCue.Anomaly wire enum.
-- Owner: game-designer + narrative-writer (numbers and names); architect (shape).
--
-- T10: this table is replicated, so it holds only what the client may know. NO correct verb, wrong verb, deadline,
-- window, step count or criticality here: those live in src/Anomaly/server/AnomalyService/Rules/ (server only).
-- Validate rejects any of those fields.
--
-- Actor: Customer (takes a counter slot, CustomerService:SpawnActor) · Street (client-only figure on the street) ·
-- Vehicle (client-only car, TrafficService:Hold) · World (map object: clock, windows, posts) · Audio (sound only) ·
-- Item (altered food in the kitchen).
-- NpcCost: 0 or 1 on the night cap of anomaly actors (Flow.MaxActorsNight).
-- Scope: Party (shared target) or PerPlayer (signal for everyone, error per player, DEC-204).
-- SeeMode: Cone (gaze cone Sanity.SeeAngle up to ViewRange, line of sight) or AudioZone (seen = being in the zone
-- of the sound when it starts; ViewRange unused = 0).
-- ExclusiveWith: never active at the same time (symmetric; npcs.md "Exclusões do agendador").
-- Scripted: fixed occurrence outside the schedule window (Night 10, 5:45 AM = 1785 game minutes; FEAT-027).
-- Tension: while an occurrence of this anomaly runs, AnomalyService raises Tension (NPC look pack Night, empty
-- street). Provisional (Q-159, Q-162): the N7..N10 pressure band; customer anomalies stay off so the actor keeps its
-- sign and normal customers never become false positives (Q-147 c).
-- Cues: keys of Cues that this anomaly may send through the AnomalyCue packet.
-- Trailer (user request 2026-10-12, Provisional Q-207): nights start in the cart and the trailer is an optional later
-- unlock, so every anomaly says what the cart can do about it:
--   None   same play in the cart and in the trailer (refuse, serve, discard, do not look, the Mart safe spot)
--   Helps  the trailer has the easy answer (close the service window); in the cart the same occurrence is solved by
--          leaving the cart zone for the Mart (the rule only tests players inside the zone, ANM-008/009)
--   Needs  the only answer is a trailer object (the light switch): without the trailer the scheduler plays the stand-in
--          anomaly (the newest earlier anomaly with Trailer None) in its slots (AnomalyService:BuildAgenda)
-- Validate: the anomalies debuting on a night up to Content.Trailer.OfferAfterNight must be None (those nights are
-- always in the cart).
-- Anomalies V2 (DEC-254 a DEC-257; design/anomalies-v2-proposal.md; TASK-292): Family A (odd customer: refuse),
-- B (hide), C (blackout), D (scare, no verb); nil = legacy V1 row not yet moved to a family. A V2 row has its own
-- Ref (ANM-011+) and may debut on a night that already has one; Nights[k].NewAnomaly stays the one the boss presents.
local Table = require(script.Parent.Table)

export type Actor = "Customer" | "Street" | "Vehicle" | "World" | "Audio" | "Item"
export type Scope = "Party" | "PerPlayer"
export type SeeMode = "Cone" | "AudioZone"
export type TrailerUse = "None" | "Helps" | "Needs"
export type Family = "A" | "B" | "C" | "D"

export type Scripted = {
	Night: number,
	Clock: number, -- game minutes since 0:00 of the shift day
}

export type Anomaly = {
	Key: string, -- anm_###_name
	Ref: string, -- ANM-### (DEC-096: ANM-00k debuts on night k)
	Name: string,
	Night: number, -- debut night
	Actor: Actor,
	NpcCost: number,
	Scope: Scope,
	SeeMode: SeeMode,
	ViewRange: number, -- studs (Cone); 0 for AudioZone
	ExclusiveWith: { string },
	Scripted: Scripted?,
	Tension: boolean,
	Cues: { string },
	Trailer: TrailerUse,
	Family: Family?, -- V2 (DEC-254); nil = legacy row
}

export type CueKind = "Visual" | "Audio" | "Both"

export type Cue = {
	Key: string,
	Kind: CueKind,
	Duration: number, -- seconds the effect lasts on the client; 0 = one shot
}

-- Instant effects (packet AnomalyCue). Flavor effects only from DEC-195 (no frozen clock, no +$1).
const cues = Table.new({
	{ Key = "blank_coin", Kind = "Visual", Duration = 0 }, -- N1 flavor: coin with no design in the drawer
	{ Key = "smoke", Kind = "Both", Duration = 2 }, -- N2 flavor: the hot dog turns to smoke on the bite
	{ Key = "clock_stop", Kind = "Both", Duration = 0 }, -- N3 sign: bank clock hands stop, ticking stops
	{ Key = "clock_resume", Kind = "Both", Duration = 0 }, -- N3: ticking comes back
	{ Key = "mirror_smile", Kind = "Visual", Duration = 2 }, -- N4 flavor: the copy's frozen smile
	-- N4 door flow (DEC-247, Provisional). Entity = knock number 1..3; the 1st one also makes the copy appear (only for who is inside the trailer)
	{ Key = "copy_knock", Kind = "Both", Duration = 0 }, -- N4: the copy stands at the back door and knocks
	{ Key = "copy_grab", Kind = "Visual", Duration = 2 }, -- N4: the door was opened: the copy comes in and grabs
	{ Key = "copy_vanish", Kind = "Visual", Duration = 2 }, -- N4: the copy fades out (Kit/Fade, 2 s), nobody opened
	{ Key = "raincoat_drip", Kind = "Both", Duration = 0 }, -- N5 sign: drip and puddle (Actor anchor)
	{ Key = "curtain", Kind = "Audio", Duration = 0 }, -- N6 start sound before the silhouette (FEAT-022 rule 2)
	{ Key = "waver_more", Kind = "Visual", Duration = 5 }, -- N6 flavor: two hands, +2 windows lit
	{ Key = "post_buzz", Kind = "Audio", Duration = 2 }, -- N7 start sign: last Juniper post buzzes (DEC-123)
	{ Key = "post_flicker", Kind = "Visual", Duration = 0.5 }, -- N7: the post of the current step flickers
	{ Key = "walker_step", Kind = "Both", Duration = 0 }, -- N7: one muffled step
	{ Key = "car_highbeam", Kind = "Visual", Duration = 0 }, -- N8 sign: high beam on the trailer
	{ Key = "car_flash", Kind = "Visual", Duration = 1 }, -- N8: high beam flashes twice
	{ Key = "car_honk", Kind = "Audio", Duration = 0 }, -- N8 flavor: low honk
	{ Key = "trailer_blackout", Kind = "Visual", Duration = 3 }, -- N8 flavor: trailer light off 3 s (no drain)
	{ Key = "knock", Kind = "Audio", Duration = 0 }, -- N9 sign: a series of three knocks with "???" subtitle
	{ Key = "door_crack", Kind = "Both", Duration = 3 }, -- N9 flavor: back door opens a finger, napkins fly
	{ Key = "hush_fog", Kind = "Visual", Duration = 0 }, -- N10 flavor: low fog through the trailer
	-- V2 (DEC-255, DEC-256): the wrong verb on a family A actor. Entity = actor NpcId; players near it see the cartoon
	-- monster face full screen (~0.6 s, Scare cap) and the one who erred faints right after (server)
	{ Key = "jumpscare", Kind = "Both", Duration = 1 },
} :: { Cue })

local function anomaly(
	night: number,
	key: string,
	name: string,
	actor: Actor,
	npcCost: number,
	scope: Scope,
	viewRange: number,
	tension: boolean,
	exclusiveWith: { string },
	cueKeys: { string }
): Anomaly
	return {
		Key = key,
		Ref = string.format("ANM-%03d", night),
		Name = name,
		Night = night,
		Actor = actor,
		NpcCost = npcCost,
		Scope = scope,
		SeeMode = "Cone",
		ViewRange = viewRange,
		ExclusiveWith = exclusiveWith,
		Tension = tension,
		Cues = cueKeys,
		Trailer = "None",
	}
end

-- V2 family A (DEC-254, TASK-292): an odd customer with ONE deformation (actor Variant, client modifier on the rig,
-- Effects/Kit/OddCustomer). Refuse = it leaves; Take Order = jumpscare + faint (DEC-255). Debut nights from
-- anomalies-v2-proposal.md §5 (game-designer tunes; TASK-271 brings the V2 night table).
local function odd(night: number, number: number, key: string, name: string): Anomaly
	const row = anomaly(night, key, name, "Customer", 1, "Party", 60, false, {}, { "jumpscare" })
	row.Ref = string.format("ANM-%03d", number)
	row.Family = "A"
	return row
end

const blankFolks = anomaly(1, "anm_001_blank_folks", "The blank folks", "Customer", 1, "Party", 60, false, {}, {
	"blank_coin",
	"jumpscare",
})
blankFolks.Family = "A" -- V2 family A (DEC-254)

const knock = anomaly(9, "anm_009_knock", "The knock", "Audio", 0, "PerPlayer", 0, true, {
	"anm_005_raincoat_lady",
	"anm_010_hush",
}, { "knock", "door_crack" })
knock.SeeMode = "AudioZone" -- FEAT-019: seen = in the trailer zone when the first knock sounds
knock.Trailer = "Helps" -- window in the trailer; in the cart: leave the zone

const walker = anomaly(7, "anm_007_walker", "The Walker", "Street", 1, "Party", 300, true, {}, {
	"post_buzz",
	"post_flicker",
	"walker_step",
})
walker.Scripted = { Night = 10, Clock = 1785 } -- FEAT-027: stands under the last post during the scripted Hush

const hush = anomaly(10, "anm_010_hush", "The Hush", "World", 0, "PerPlayer", 200, true, {
	"anm_003_stopped_clock",
	"anm_005_raincoat_lady",
	"anm_008_long_car",
	"anm_009_knock",
}, { "hush_fog" })
hush.Scripted = { Night = 10, Clock = 1785 } -- FEAT-027: 3rd occurrence of Night 10 at 5:45 AM, leads to the Final

const stoppedClock = anomaly(3, "anm_003_stopped_clock", "The stopped clock", "World", 0, "Party", 100, false, {
	"anm_010_hush",
}, { "clock_stop", "clock_resume" })
stoppedClock.Trailer = "Needs" -- the verb is the trailer's light switch

const longCar = anomaly(8, "anm_008_long_car", "The long car", "Vehicle", 1, "PerPlayer", 100, true, {
	"anm_005_raincoat_lady",
	"anm_010_hush",
}, { "car_highbeam", "car_flash", "car_honk", "trailer_blackout" })
longCar.Trailer = "Helps" -- window in the trailer; in the cart: leave the zone

const base = Table.new({
	-- ViewRange: 60 default, 80 N6, 300 N7 (FEAT-019); 100 N3/N8 and 200 N10 Provisional (C-01 ~73 studs,
	-- AN-12 ~63, Juniper posts 82-135 from the counter; MAP-01 §6, §10.3)
	blankFolks,
	anomaly(2, "anm_002_wrong_food", "The wrong food", "Item", 0, "Party", 60, false, {}, { "smoke" }),
	stoppedClock,
	anomaly(4, "anm_004_copies", "The copies", "Customer", 1, "Party", 60, false, {}, { "mirror_smile", "copy_knock", "copy_grab", "copy_vanish" }),
	anomaly(5, "anm_005_raincoat_lady", "The Raincoat Lady", "Customer", 1, "Party", 60, false, {
		"anm_008_long_car",
		"anm_009_knock",
		"anm_010_hush",
	}, { "raincoat_drip" }),
	anomaly(6, "anm_006_wavers", "The wavers", "World", 0, "PerPlayer", 80, false, {}, { "curtain", "waver_more" }),
	walker,
	longCar,
	knock,
	hush,
	odd(2, 11, "anm_011_shaker", "The shaker"),
	odd(3, 12, "anm_012_turned_neck", "The turned neck"),
	odd(5, 13, "anm_013_white_eyes", "The white eyes"),
	odd(6, 14, "anm_014_big_head", "The big head"),
	odd(7, 15, "anm_015_floater", "The floater"),
	odd(8, 16, "anm_016_starer", "The starer"),
} :: { Anomaly })

-- Anomaly that plays in the slots of a "Needs" anomaly when the vehicle has no switch: the newest anomaly debuting
-- before it with Trailer None (nil if there is none, which Validate forbids)
local function standIn(row: Anomaly): Anomaly?
	local found: Anomaly? = nil
	for _, other in base.List do
		if other.Night < row.Night and other.Trailer == "None" and (found == nil or other.Night > found.Night) then
			found = other
		end
	end
	return found
end

-- Active anomalies of night k, in list order (DEC-025: N1..Nk). Used by the scheduler and by dev tools.
local function activeOn(night: number): { Anomaly }
	const out: { Anomaly } = {}
	for _, row in base.List do
		if row.Night <= night then
			table.insert(out, row)
		end
	end
	return out
end

return Table.with(base, {
	Cues = cues,
	ActiveOn = activeOn,
	StandIn = standIn,
})
