--!strict
-- Animations of the user's IK rig, exported as R6 Animation (content-data.md §3.20; architecture.md §19.20, T47;
-- Q-167). Owner: user (ids) + art-director (list). Provisional list; every Id is "" until the upload.
-- Id "" = fallback: R6 default locomotion of Roblox for Locomotion roles; one-shots do not play.
-- Rig: Crew (player character; Animate script written by CharacterService, one-shots by the owner client) ·
-- Npc (server rigs, animated by each client) · Actor (client-only actors: Opal, Walt, medics, Walker...).
-- Priority = name of an Enum.AnimationPriority item.
-- Locomotion: set -> role -> key of a row of this table with the set's rig (crew: Crew; npc: Npc; others: Actor).
local Table = require(script.Parent.Table)

export type Rig = "Crew" | "Npc" | "Actor"
export type Priority = "Core" | "Idle" | "Movement" | "Action" | "Action2" | "Action3" | "Action4"
export type Role = "idle" | "walk" | "run" | "jump" | "fall" | "climb" | "sit"

export type Animation = {
	Key: string,
	Id: string,
	Rig: Rig,
	Looped: boolean,
	Priority: Priority,
	FadeTime: number, -- seconds
	Speed: number, -- multiplier
	Ref: string, -- AST-### / DEC
}

export type LocomotionSet = { [Role]: string }

export type Locomotion = {
	crew: LocomotionSet,
	npc: LocomotionSet,
	walt: LocomotionSet,
	medic: LocomotionSet,
	walker: LocomotionSet,
}

local function anim(key: string, rig: Rig, looped: boolean, priority: Priority): Animation
	return {
		Key = key,
		Id = "",
		Rig = rig,
		Looped = looped,
		Priority = priority,
		FadeTime = 0.15,
		Speed = 1,
		Ref = "AST-069",
	}
end

const base = Table.new({
	-- Crew
	anim("crew_idle", "Crew", true, "Idle"),
	anim("crew_walk", "Crew", true, "Movement"),
	anim("crew_jump", "Crew", false, "Movement"),
	anim("crew_fall", "Crew", true, "Movement"),
	anim("get_up", "Crew", false, "Action"), -- hit by a car, gets up (0.5 s)
	anim("drink", "Crew", false, "Action"), -- coffee, 1.5 s (Sanity.CoffeeDrinkTime)
	anim("give", "Crew", false, "Action"),
	anim("answer_phone", "Crew", true, "Action"),
	anim("wave_skip", "Crew", false, "Action"), -- cutscene skip vote (optional)
	anim("work", "Crew", true, "Action"), -- standing at a prep station (prep-mode.md §4; falls back to the idle, DEC-220)

	-- Npc
	anim("npc_idle", "Npc", true, "Idle"),
	anim("npc_walk", "Npc", true, "Movement"),
	anim("npc_wait", "Npc", true, "Idle"), -- impatient
	anim("npc_happy", "Npc", false, "Action"),
	anim("npc_complain", "Npc", false, "Action"),
	anim("npc_refuse_leave", "Npc", false, "Action"),
	anim("thief_sneak", "Npc", true, "Movement"),
	anim("thief_open", "Npc", true, "Action"),
	anim("thief_flee", "Npc", true, "Movement"),
	-- Pad tables (TASK-144; FEAT-037; TASK-151 asks the clips): while `npc_sit` has no Id the server poses the hips of
	-- the seated rig itself (SeatingService/Diner.luau); with an Id the client plays it on rigs with the `Seated`
	-- attribute and the server only anchors the rig.
	anim("npc_sit", "Npc", true, "Idle"),
	anim("npc_eat_seated", "Npc", false, "Action"),

	-- Actor
	anim("opal_idle", "Actor", true, "Idle"), -- today a fixed id in OpalController (A8, TASK-077)
	anim("walt_walk", "Actor", true, "Movement"), -- hunched, with a cane (DEC-202)
	anim("walt_offer_coffee", "Actor", false, "Action"),
	anim("medic_walk", "Actor", true, "Movement"),
	anim("medic_carry", "Actor", true, "Movement"),
	anim("medic_lift", "Actor", false, "Action"),
	anim("walker_step", "Actor", false, "Movement"),
	anim("waver_wave", "Actor", true, "Action"), -- window silhouette, N6
	anim("copy_backwalk", "Actor", true, "Movement"), -- N4
	anim("raincoat_idle", "Actor", true, "Idle"),
} :: { Animation })

const locomotion: Locomotion = {
	crew = { idle = "crew_idle", walk = "crew_walk", run = "crew_walk", jump = "crew_jump", fall = "crew_fall" },
	npc = { idle = "npc_idle", walk = "npc_walk" },
	walt = { walk = "walt_walk" },
	medic = { walk = "medic_walk" },
	walker = { walk = "walker_step" },
}

-- rig each Locomotion set must use (Validate)
const SET_RIG: { [string]: Rig } = {
	crew = "Crew",
	npc = "Npc",
	walt = "Actor",
	medic = "Actor",
	walker = "Actor",
}

return Table.with(base, {
	Locomotion = Table.record(locomotion),
	SetRig = Table.record(SET_RIG),
})
