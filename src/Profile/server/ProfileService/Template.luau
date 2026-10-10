--!strict
-- Profile Template v1 (docs/tech/data.md §1.1). Replaces the example Template (Coins/Level/Playtime): the game was
-- never published, so no migration is needed for that swap. Later-wave fields already live here (no migration when
-- the wave opens); wave 1 reads and writes only Gems, Classes and SelectedClass.
-- Content keys are stored as keys, never as indexes. Nested fields change by copy (the profile is reactive per
-- top-level field): mutating in place neither fires the effect nor saves.
-- Owner of this file: TASK-004 in wave 1 (board conflict point). Renaming or removing a field = Migrations.luau.

export type RunRewards = {
	RunId: string,
	Keys: { string },
	-- Gems credited in this run (data.md §1.3 v5.1, T59): RewardService fills RunReport.Gems from it
	Gems: number,
}

export type Stats = {
	RunsStarted: number,
	RunsFinished: number,
	NightsWon: number,
	BestNight: number,
	BestDay: number,
	Revives: number,
}

export type Data = {
	Version: number,
	Gems: number,
	GemsEarned: number,
	Classes: { [string]: boolean },
	SelectedClass: string,
	Achievements: { [string]: number },
	BadgesAwarded: { [string]: boolean },
	EndlessDays: number,
	ReviveCredits: number,
	Receipts: { string },
	RunRewards: RunRewards,
	Stats: Stats,
}

const Template: Data = {
	Version = 1,

	-- Gems (DEC-070, DEC-104)
	Gems = 0, -- balance
	GemsEarned = 0, -- lifetime total

	-- Classes = crew animals (DEC-147, DEC-186). Key = Content.Classes key (class_<species>)
	Classes = { class_dog = true }, -- the Dog is free: a new account owns it
	SelectedClass = "class_dog",

	-- Achievements and Day 100 (DEC-058, DEC-084)
	Achievements = {}, -- key -> os.time() of the unlock
	BadgesAwarded = {}, -- badge confirmed by BadgeService (retry until true)
	EndlessDays = 0, -- endless-mode days finished with anti-AFK, across sessions

	-- Monetization (DEC-092; architecture.md §10)
	ReviveCredits = 0, -- paid revive not used yet (DEC-117); self only (DEC-116)
	Receipts = {}, -- last 50 processed PurchaseIds (circular list)

	-- Gem idempotency per run (architecture.md §10.4)
	-- Gems = sum credited in this run, for RunReport.Gems (v5.1, T59; TASK-074)
	RunRewards = { RunId = "", Keys = {}, Gems = 0 },

	Stats = {
		RunsStarted = 0,
		RunsFinished = 0, -- end of the 10th night (DEC-075)
		NightsWon = 0,
		BestNight = 0,
		BestDay = 0,
		Revives = 0, -- times revived (monetization telemetry)
	},
}

return Template
