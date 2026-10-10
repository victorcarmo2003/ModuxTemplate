--!strict
-- Cutscenes (content-data.md §3.19, §6.11; architecture.md §19.16; network.md §6.2; FEAT-004, FEAT-027;
-- script.md §1; ending.md §2.2, §2.4; MAP-01 §11; DEC-021, DEC-075, DEC-078, DEC-088, DEC-097, DEC-194, DEC-205).
-- Keys are the Cutscene.Scene wire enum (sentinel "none" first). Owner: narrative-writer (lines) + level-designer
-- (marks, targets); architect (shape). Texts are placeholders until ui-text.md.
--
-- Only intro and finale/credits are cutscenes (FEAT-004). Vehicle swap and lost night are world transitions.
-- Duration: real seconds of the scene (beats end by then); Cap: hard cap the server enforces.
-- Skippable: by vote, >= ceil(0.5 x connected) per segment (DEC-194). Participants: connected at the start; a late
-- member waits and spawns at the end (DEC-205).
-- Next: scene that plays right after this one, as a new segment with 0 votes (finale -> credits).
-- Marks: start slots of the party, in order (slot 1 = the player that made the party; visual only, DEC-067).
-- Beats (sorted by At, seconds since StartedAt):
--   Fade     Target "In" | "Out"
--   Text     on-screen title, Text
--   MoveTo   every avatar walks to Target (MapPoint name; "{slot}" = the avatar's slot 1..4)
--   LookAt   every POV turns to Target (MapPoint/anchor name)
--   Prompt   world prompt that completes by itself on Target, label Text (script.md §1: input locked)
--   Line     subtitle Text said by Speaker ("walt", "crew" = a balloon over each avatar); Variant Solo/Party
--   Actor    client-only actor or prop Target appears/acts (Walt, Raincoat Lady, toy cars, flip phone, flyer)
-- The camera is always the avatar's head, free look +-60 degrees (DEC-088, DEC-097).
local Table = require(script.Parent.Table)

export type BeatKind = "Fade" | "Text" | "MoveTo" | "LookAt" | "Prompt" | "Line" | "Actor"
export type Variant = "Solo" | "Party"

export type Beat = {
	At: number,
	Kind: BeatKind,
	Target: string,
	Text: string?,
	Speaker: string?,
	Variant: Variant?, -- nil = both
}

export type Cutscene = {
	Key: string,
	Duration: number,
	Cap: number,
	Skippable: boolean,
	Participants: "ConnectedAtStart",
	Next: string?,
	Marks: { string },
	Beats: { Beat },
}

local function walt(at: number, text: string, variant: Variant?): Beat
	return { At = at, Kind = "Line", Target = "walt", Speaker = "walt", Text = text, Variant = variant }
end

return Table.new({
	{
		Key = "none",
		Duration = 0,
		Cap = 0,
		Skippable = false,
		Participants = "ConnectedAtStart",
		Marks = {},
		Beats = {},
	},
	-- Opening, 35-45 s target, cap 50 (FEAT-004); script.md §1 shots 1-10; MAP-01 §11.1 CS-1..CS-7
	{
		Key = "intro",
		Duration = 45,
		Cap = 50,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Marks = { "CutsceneMark1", "CutsceneMark2", "CutsceneMark3", "CutsceneMark4" },
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In" },
			{ At = 0, Kind = "Text", Target = "Title", Text = "Bellmoor" },
			{ At = 2, Kind = "MoveTo", Target = "CS-2" },
			{ At = 4, Kind = "Line", Target = "crew", Speaker = "crew", Text = "Empty. Again." },
			-- Walks cross a carriageway only inside the stripes (MAP-01 P46); ~16 studs/s, each walk ends before the
			-- next MoveTo (SNAP_DISTANCE). The party waits on the CS-3 curb while the car passes, then crosses CW-2.
			{ At = 8, Kind = "MoveTo", Target = "CS-3" },
			{ At = 13, Kind = "Actor", Target = "ToyCarNinth" }, -- passes without stopping (DEC-130, DEC-133)
			{ At = 13.5, Kind = "Line", Target = "crew", Speaker = "crew", Text = "Whoa!" },
			{ At = 15, Kind = "MoveTo", Target = "CS-4" }, -- CW-2, after the car
			{ At = 18.5, Kind = "MoveTo", Target = "CS-5W" }, -- west curb of CW-1, along the Juniper South sidewalk
			{ At = 20.5, Kind = "MoveTo", Target = "CS-5E" }, -- across CW-1 (no car in the scene)
			{ At = 22.5, Kind = "MoveTo", Target = "CS-P{slot}" },
			{ At = 23.5, Kind = "LookAt", Target = "P-01" },
			{ At = 24.5, Kind = "Prompt", Target = "P-01", Text = "Call" },
			{ At = 25.5, Kind = "Actor", Target = "FlipPhone" }, -- slot 1 only, already open (AST-038)
			walt(26, "Bramble's Corner Dogs! Walt speaking."),
			walt(28.5, "The flyer? Huh. Nobody's called about that one in years.", "Solo"),
			walt(28.5, "The flyer? All of you? Huh. Nobody's called in years.", "Party"),
			walt(31, "But you noticed it. That counts for a lot.", "Solo"),
			walt(31, "You all noticed it. That counts for a lot. Heh.", "Party"),
			walt(33.5, "Can you start today? Great. Wonderful."),
			walt(36, "The cart's right on the corner. Ninth and Juniper."),
			walt(38.5, "Keys are under the mustard. See you around, Rookie."),
			{ At = 41, Kind = "LookAt", Target = "CART" }, -- CS-7
			{ At = 41.5, Kind = "Actor", Target = "ToyCarJuniper" },
			{ At = 44, Kind = "Fade", Target = "Out" },
		},
	},
	-- Dawn of Night 10, variant A1 (DEC-075, DEC-076); <= 60 s; MAP-01 §11.3 SS-1..4, WALT-1, RL-1 -> RL-END
	{
		Key = "finale",
		Duration = 60,
		Cap = 60,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Next = "credits",
		Marks = { "SS-1", "SS-2", "SS-3", "SS-4" },
		Beats = {
			{ At = 0, Kind = "Fade", Target = "In" },
			{ At = 1, Kind = "Actor", Target = "MartDoor" },
			{ At = 1.5, Kind = "Actor", Target = "Walt" }, -- MKT-DOOR -> WALT-1, two coffees
			{ At = 3, Kind = "LookAt", Target = "WALT-1" },
			walt(6, "Ten nights. You kept the light on."),
			walt(9, "I watched every one. From in here. Best seat in town."),
			walt(12, "I worked that corner forty years. Since '79."),
			walt(15, "The corner's a crossing, Rookie. At night, the late crowd comes through."),
			walt(18, "They like the light. And the smell of food. Heh."),
			walt(21, "Keep the rules, and they stay polite. That's the deal."),
			walt(24, "Somebody has to keep the light on. Every night."),
			walt(27, "My knees are done. But you... you notice things."),
			{ At = 30, Kind = "Actor", Target = "WaltCoffee" }, -- held out to each POV
			walt(30, "The night shift is yours. If you want it."),
			{ At = 36, Kind = "Actor", Target = "RaincoatLady" }, -- RL-1 -> RL-END, vanishes in a puddle
			{ At = 37, Kind = "LookAt", Target = "RL-END" },
			walt(46, "Morning, Marigold."),
			{ At = 57, Kind = "Fade", Target = "Out" },
		},
	},
	-- Credits + post-credits flyer (ending.md §2.4); <= 75 s
	{
		Key = "credits",
		Duration = 75,
		Cap = 75,
		Skippable = true,
		Participants = "ConnectedAtStart",
		Marks = { "SS-1", "SS-2", "SS-3", "SS-4" },
		Beats = {
			{ At = 0, Kind = "Text", Target = "Credits", Text = "Credits" }, -- roll from docs/art/credits.md
			{ At = 60, Kind = "Fade", Target = "In" },
			{ At = 60, Kind = "LookAt", Target = "P-01" },
			{ At = 61, Kind = "Actor", Target = "Flyer" }, -- "NIGHT SHIFT — NOW HIRING" (AN-03)
			{ At = 72, Kind = "Fade", Target = "Out" },
		},
	},
} :: { Cutscene })
