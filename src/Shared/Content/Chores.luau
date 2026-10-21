--!strict
-- Night chores (owner request 2026-10-21, Q-436; PROVISIONAL numbers, texts and spots). Small troubles of the shop that
-- pull a player away from the counter, with no anomaly behind them. ChoreService (server) draws and owns them; the
-- clients only show them (ChoreController: fire, rats, lines; SecurityController: the static of a camera).
--
--   grill_fire     the grill catches fire: flames and smoke on the grill, the grill prompts refuse until somebody
--                  holds Put Out at it. Not out in Deadline s: every Active player pays Penalty sanity (once).
--   back_door      the back door (Restaurant.ManualDoors) unlocks and swings open by itself, creaking. Somebody has to
--                  close it. Still open after Deadline s: a family D scare for everyone and Penalty sanity.
--   rats           Count rats run onto the prep counters (Spots): the prompts of the station a rat sits on refuse until
--                  somebody shoos it (tap). Rats left after Deadline s: Penalty sanity.
--   camera_static  one security camera (Content.Security.Cams) loses its picture: the monitor shows only static on it.
--                  Fixed by holding Fix Camera from below (Radius studs, the anchor sits at the camera, high on the
--                  wall), never through a wall (server line of sight). No deadline: the cost is a blind camera.
--
-- Draw: from Nights FromNight on, at most PerNight[night] chores a night, one every Every {min, max} s of the Night
-- phase; each chore at most once at a time and never while an anomaly runs (it waits Retry s). Not under the tutorial
-- hold or the grace. Chores already on stay on while anomalies come. A new shift clears everything.
local Table = require(script.Parent.Table)

export type Chore = {
	Key: string,
	FromNight: number, -- first night it can be drawn
	Weight: number, -- draw weight among the chores allowed tonight
	Deadline: number, -- s before the penalty (0 = no penalty)
	Penalty: number, -- sanity taken from every Active player at the deadline
	Action: string, -- Content.Actions key of its prompt
	Title: string, -- Announce title when it starts
	Line: string, -- Announce line when it starts
	Sound: string, -- Content.Sounds key when it starts ("" = none)
	Loop: string, -- Content.Sounds key looped at the spot while it is on ("" = none)
	Done: string, -- Content.Sounds key when it is fixed ("" = none)
}

export type Rules = {
	PerNight: { number }, -- chores at most by night (index = night; past the end = the last value)
	Every: { number }, -- {min, max} s between two chores
	Retry: number, -- s to wait when the moment is busy
	Hold: number, -- s the Announce stays up
	Fresh: number, -- s after a record's At in which a client still plays its start (late joiners: only the state)
	Gate: string, -- InteractionService gate name
	Grill: string, -- MapId of the grill model (grill_fire)
	Spots: { string }, -- MapIds of the prep stations the rats run onto
	RatCount: number, -- rats per rats chore (one per spot at most)
	CameraRadius: number, -- informative: Actions.camera_fix.Radius (the prompt reaches the high camera)
}

export type Chores = {
	Rules: Rules,
	List: { Chore },
	Keys: { string },
	ByKey: { [string]: Chore },
	IndexOf: { [string]: number },
}

const list = Table.new({
	{
		Key = "grill_fire",
		FromNight = 2,
		Weight = 3,
		Deadline = 25,
		Penalty = 15,
		Action = "fire_out",
		Title = "GRILL ON FIRE",
		Line = "Put it out!",
		Sound = "",
		Loop = "fire_loop",
		Done = "fire_spray",
	},
	{
		Key = "back_door",
		FromNight = 3,
		Weight = 2,
		Deadline = 20,
		Penalty = 10,
		Action = "door_toggle",
		Title = "THE BACK DOOR IS OPEN",
		Line = "Close it.",
		Sound = "door_creak",
		Loop = "",
		Done = "",
	},
	{
		Key = "rats",
		FromNight = 2,
		Weight = 3,
		Deadline = 30,
		Penalty = 10,
		Action = "rat_shoo",
		Title = "RATS!",
		Line = "Shoo them off the counter.",
		Sound = "rat_squeak",
		Loop = "",
		Done = "rat_squeak",
	},
	{
		Key = "camera_static",
		FromNight = 1,
		Weight = 2,
		Deadline = 0,
		Penalty = 0,
		Action = "camera_fix",
		Title = "",
		Line = "",
		Sound = "",
		Loop = "",
		Done = "camera_fixed",
	},
} :: { Chore })

return table.freeze({
	Rules = table.freeze({
		PerNight = table.freeze({ 1, 2, 2, 3, 3, 3, 4, 4, 5, 5 }), -- PROVISIONAL
		Every = table.freeze({ 60, 120 }), -- PROVISIONAL
		Retry = 10,
		Hold = 2.5,
		Fresh = 2,
		Gate = "Chore",
		Grill = "TRL-G",
		Spots = table.freeze({ "TRL-T", "TRL-BC", "TRL-R", "TRL-S" }),
		RatCount = 3,
		CameraRadius = 22,
	}),
	List = list.List,
	Keys = list.Keys,
	ByKey = list.ByKey,
	IndexOf = list.IndexOf,
} :: Chores)
