--!strict
-- Pad tables, single record (content-data.md §3.25; FEAT-037; UPG-008, UPG-009; TASK-144). Owner: game-designer
-- (numbers) + architect (binding names). Every number Provisional (Q-178, Q-180, Q-181).
--
-- A customer with a Complete order (FEAT-038: a pair with >= 1 Complete and no Wrong/gave up) may sit at a bought,
-- clean and free table instead of leaving. Sitting needs ALL of: a table Free; diners alive < MaxDiners[shift];
-- customers alive (the diner included) <= max customers of the shift - SitHeadroom; phase in SitPhases; no tension
-- (TensionAnomalies running or a customer anomaly alive). Chance = CustomerTypes[leader].SitChance x NightSitMult at
-- night + GroupSitBonus for a pair + the SitBonus effect (UPG-009), capped at SitChanceCap. The table nearest to Q1
-- (lowest index) wins. After EatTime the diners leave a tray and TableTip per person on the table (Dirty); the
-- "Clean Table" prompt (action clean_table) moves the tip into the drawer. At Summary every table is cleaned and the
-- tip on it is lost (TipLostAtSummary, Q-181 A). Diners count as customers (SeatedOutsideCap = false, Q-180 A).
--
-- Binding (MAP-01, TASK-149; architecture.md §18.4): table Models tagged `Tag` with attribute `IndexAttribute` =
-- 1..Tables (fixed order, closest to Q1 first). Fallback while the tag is missing: Models named `ModelName` inside
-- Workspace.<Folder...>, ordered by distance to MapPoint Q1. Seats = BaseParts `SeatPrefix`1..`SeatCount` inside the
-- table (CFrame = torso of the seated NPC, LookVector towards the table). Prompt anchors (optional): `BuyAnchor` and
-- `CleanAnchor`; without them one anchor `RuntimeAnchor` is created at runtime over the top of the table. Optional
-- `TrayAnchor` (client: tray + coin). Optional NpcNode `NodePrefix`n next to table n (graph route Q1 -> table).
local Table = require(script.Parent.Table)

export type ShiftPair = { Day: number, Night: number }

export type Binding = {
	Tag: string,
	IndexAttribute: string,
	Folder: { string }, -- path under Workspace of the fallback search
	ModelName: string,
	SeatPrefix: string,
	SeatCount: number,
	BuyAnchor: string,
	CleanAnchor: string,
	RuntimeAnchor: string,
	TrayAnchor: string,
	NodePrefix: string,
	LightsAnchor: string, -- UPG-009 sign (Interactable buy_in_place with attribute Upgrade = LightsKey)
}

export type Seats = {
	Solo: { number }, -- seat numbers used by a lone diner
	Pair: { number }, -- a pair of friends: face to face
	Couple: { number }, -- a couple: side by side
}

export type Seating = {
	UnlockDay: number, -- ghosts and sitting from this day (Day 1 = tutorial)
	Tables: number, -- table records 1..Tables (TBL-1..TBL-5)
	UpgradeKey: string, -- Content.Upgrades key whose TableCount effect = tables bought
	LightsKey: string, -- Content.Upgrades key of Patio Lights (SitBonus)
	TableLabel: string, -- {item} of buy_in_place on a table ("Buy Table — $30"); placeholder until TASK-150
	EatTime: { Day: number, Night: number, Jitter: number, GroupExtra: number }, -- seconds
	TableTip: number, -- $ per diner, left on the table
	MaxTip: number, -- Tables.Tip wire cap
	MaxDiners: ShiftPair, -- NPCs seated or walking to a table
	SitHeadroom: number, -- customers alive must stay <= max customers - this
	NightSitMult: number,
	GroupSitBonus: number,
	SitChanceCap: number,
	CleanHold: number, -- = Actions.clean_table.Hold (Validate)
	BuyHold: number, -- = Actions.buy_in_place.Hold (Validate)
	PromptRadius: number, -- = Radius of both actions (Validate)
	TipLostAtSummary: boolean, -- Q-181 A (only true is implemented)
	SeatedOutsideCap: boolean, -- Q-180 B (only false is implemented)
	SitPhases: { string }, -- Shift phases where someone may sit
	TensionAnomalies: { string }, -- Anomalies keys: nobody sits and diners leave while one runs
	GhostTransparency: number, -- client: table not bought yet
	StandTimeout: number, -- seconds: a diner whose walk to the table fails is sent away after this
	WalkTimeout: number, -- seconds for the last straight walk (approach point / seat)
	Approach: number, -- studs behind the seat (opposite of its LookVector) where the diner stands before sitting
	States: { string }, -- Tables.State enum (network.md §14.1)
	Seats: Seats,
	Binding: Binding,
}

const seating: Seating = {
	UnlockDay = 2,
	Tables = 5,
	UpgradeKey = "patio_tables",
	LightsKey = "patio_lights",
	TableLabel = "Table",
	EatTime = { Day = 20, Night = 24, Jitter = 3, GroupExtra = 4 },
	TableTip = 2,
	MaxTip = 1000,
	MaxDiners = { Day = 4, Night = 2 },
	SitHeadroom = 2,
	NightSitMult = 0.75,
	GroupSitBonus = 0.20,
	SitChanceCap = 0.95,
	CleanHold = 1,
	BuyHold = 1.5,
	PromptRadius = 7,
	TipLostAtSummary = true,
	SeatedOutsideCap = false,
	SitPhases = { "Open", "Night" },
	TensionAnomalies = { "anm_007_walker", "anm_008_long_car", "anm_009_knock", "anm_010_hush" },
	GhostTransparency = 0.7,
	StandTimeout = 30,
	WalkTimeout = 6,
	Approach = 2.5,
	States = { "Locked", "Ghost", "Free", "Occupied", "Dirty" },
	Seats = {
		Solo = { 1 },
		Pair = { 1, 3 },
		Couple = { 1, 2 },
	},
	Binding = {
		Tag = "SeatTable",
		IndexAttribute = "TableIndex",
		Folder = { "MAP01_Assets", "PadDecor" },
		ModelName = "AST-100_PicnicTable",
		SeatPrefix = "Seat",
		SeatCount = 4,
		BuyAnchor = "Prompt_BuyTable",
		CleanAnchor = "Prompt_CleanTable",
		RuntimeAnchor = "Prompt_Table",
		TrayAnchor = "Tray_Anchor",
		NodePrefix = "TBL-",
		LightsAnchor = "Prompt_PatioLights",
	},
}

return Table.record(seating)
