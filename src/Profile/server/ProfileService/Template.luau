--!strict
-- Profile Template v1 (docs/tech/data.md §1.1). Replaces the example Template (Coins/Level/Playtime): the game was
-- never published, so no migration is needed for that swap. Later-wave fields already live here (no migration when
-- the wave opens); wave 1 reads and writes only Gems, Classes and SelectedClass.
-- Content keys are stored as keys, never as indexes. Nested fields change by copy (the profile is reactive per
-- top-level field): mutating in place neither fires the effect nor saves.
-- Owner of this file: TASK-004 in wave 1 (board conflict point). Renaming or removing a field = Migrations.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)

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

-- Gift waiting for its receipt (TASK-352): the recipient the giver picked with GiftPrompt. Saved, so a receipt Roblox
-- delivers again in another server still knows where the gift goes.
export type GiftPending = {
	Recipient: number, -- UserId
	At: number, -- os.time() of the GiftPrompt
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
	-- One-time bundles bought (DEC-267; Content.Shop.Bundles key -> os.time() of the receipt, e.g. the Starter Crate).
	-- Writer: ShopService. Reconcile adds it as {} to older profiles, so no migration.
	OneTimeBought: { [string]: number },
	RunRewards: RunRewards,
	Stats: Stats,
	-- Legacy, unused (tutorial: Day 1 of every run, in memory; user request 2026-10-11, Provisional). Kept so saved
	-- profiles and the Profile packet keep their shape; Reconcile adds false to older profiles, so no migration.
	TutorialDone: boolean,
	-- Codes redeemed by this account: normalized code -> os.time() of the redeem (CodesService; user request
	-- 2026-10-11, Provisional, data.md §1.7). Reconcile adds it as {} to older profiles, so no migration.
	RedeemedCodes: { [string]: number },
	-- Player settings (TASK-279; owner request 2026-10-14, Provisional): volumes, prompt mode, prep assist, reduced
	-- motion. Writer: SettingsService (sanitized by SettingsRules). Reconcile adds the defaults to older profiles.
	Settings: SettingsRules.Settings,
	-- Anomaly Tablet pages (TASK-335, TASK-345; owner request 2026-10-15, Provisional): Content.Journal key -> os.time() of the
	-- unlock. Writer: JournalService. Reconcile adds it as {} to older profiles, so no migration.
	Journal: { [string]: number },
	-- Anomaly Tablet rewards claimed (owner request 2026-10-17, Provisional): Content.Journal key -> os.time() of the claim.
	-- The flag that the page's gems (Content.Journal.Rules.Reward) were paid; a page in Journal without it shows "!" on
	-- the tablet until the player opens it. Writer: JournalService. Reconcile adds it as {} to older profiles.
	JournalClaimed: { [string]: number },
	-- Gifts (TASK-352; owner request 2026-10-16, Provisional). Writer: GiftService. GiftPending: Content.Shop.Gifts key
	-- -> the recipient of this player's next receipt of that product. GiftsReceived: ids of the last delivered gift
	-- messages (circular list), so a message sent twice (receipt retried) is granted once. Reconcile adds both as {}.
	GiftPending: { [string]: GiftPending },
	GiftsReceived: { string },
	-- Class skins (owner request 2026-10-17, Provisional; design/skins-proposal.md). Writer: SkinService. Skins:
	-- Content.Skins key -> os.time() of the grant (Robux receipt). EquippedSkins: Content.Classes key -> the Content.Skins
	-- key worn with that class (absent = the crew uniform). Reconcile adds both as {} to older profiles, so no migration.
	Skins: { [string]: number },
	EquippedSkins: { [string]: string },
	-- Lobby floor guides shown (owner request 2026-10-20, Provisional): Content.Lobby.Guide key -> os.time() it was done.
	-- Writer: LobbyService (LobbyGuideDone). Reconcile adds it as {} to older profiles, so no migration.
	LobbyGuides: { [string]: number },
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
	Receipts = {}, -- last 50 processed PurchaseIds (circular list); writer: ShopService (data.md §1.4)
	OneTimeBought = {}, -- one-time bundles (DEC-267); writer: ShopService

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

	-- Legacy (2026-10-11, Provisional): no longer read or written. The tutorial runs on Day 1 of every run and is kept in
	-- memory by TutorialService; the field stays so saved data and the Profile packet keep their shape
	TutorialDone = false,

	-- Codes: one redeem per code per account (CodesService, data.md §1.7)
	RedeemedCodes = {},

	-- Settings: SettingsService (TASK-279); a plain copy, the profile changes by copy
	Settings = table.clone(SettingsRules.Defaults),

	-- Anomaly Tablet: JournalService (TASK-335, TASK-345); unknown keys are ignored on read
	Journal = {},
	JournalClaimed = {},

	-- Gifts: GiftService (TASK-352)
	GiftPending = {},
	GiftsReceived = {},

	-- Class skins: SkinService
	Skins = {},
	EquippedSkins = {},

	-- Lobby floor guides: LobbyService
	LobbyGuides = {},
}

return Template
