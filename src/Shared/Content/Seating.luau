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
-- Order at the table (2026-10-12, user request, Provisional, Q-209): the customer sits RIGHT AFTER "Take Order" (same
-- 5 conditions; a free table seats it, SitChanceApplies = false), the queue slot is freed, and the player carries the
-- hot dog to the table: action serve_table on the table's ServeAnchor (PromptText "Serve Table n: Ketchup + Cheese";
-- one row per table in the interaction menu). Served well = it eats EatTime and leaves the tray; wrong item, patience
-- out or a shift end stand it up with no meal and no tray. The Order patience clock runs while it waits.
--
-- Groups (2026-10-12, user request, Provisional, Q-209): the tables are split in groups, each with its own upgrade.
-- "Pad" = TBL-1..5, the picnic tables behind the cart (UPG-008, Pad scope: they stay when the trailer comes).
-- "Trailer" = TBL-6..9, the tables the owner placed for the trailer (UPG-011, trailer only). A group shows and sells
-- only on its Vehicles: before the trailer is bought the Trailer tables are Locked (hidden, no collision); on the
-- trailer the next one is a Ghost with price (GhostAll = false: the later ones stay hidden until it is bought). A
-- party never mixes groups: once a Trailer table is bought, only the Trailer group seats (Pad tables stay as they are).
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
	GroupAttribute: string, -- optional: "Pad" | "Trailer" (checked against TableIndex)
	Folder: { string }, -- path under Workspace of the fallback search
	ModelName: string,
	SeatPrefix: string,
	SeatCount: number,
	BuyAnchor: string,
	CleanAnchor: string,
	RuntimeAnchor: string,
	ServeAnchor: string, -- optional anchor of serve_table; else RuntimeServeAnchor is created over the top of the table
	RuntimeServeAnchor: string,
	TrayAnchor: string,
	NodePrefix: string,
	LightsAnchor: string, -- UPG-009 sign (Interactable buy_in_place with attribute Upgrade = LightsKey)
}

export type Group = {
	Key: string, -- "Pad" | "Trailer" (attribute TableGroup of the bound Model, optional: derived from TableIndex)
	First: number, -- first global TableIndex of the group
	Count: number, -- tables of the group
	UpgradeKey: string, -- Content.Upgrades key sold on these tables (Stat = tables bought)
	Stat: string, -- Content.Stats key holding the tables bought of this group
	Vehicles: { string }, -- vehicles on which the group is visible and sold
	Label: string, -- {item} of buy_in_place and the plate title
	GhostAll: boolean, -- true: every table not bought is a visible ghost; false: only the next one for sale
}

export type Seats = {
	Solo: { number }, -- seat numbers used by a lone diner
	Pair: { number }, -- a pair of friends: face to face
	Couple: { number }, -- a couple: side by side
}

export type Seating = {
	UnlockDay: number, -- ghosts and sitting from this day (Day 1 = tutorial)
	Tables: number, -- table records 1..Tables (TBL-1..TBL-9), sum of the Groups
	Groups: { Group },
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
	SitChanceApplies: boolean, -- false: a free table always seats a customer that took its order (Q-209); true: the old chance
	SitPhases: { string }, -- Shift phases where someone may sit
	TensionAnomalies: { string }, -- Anomalies keys: nobody sits and diners leave while one runs
	GhostTransparency: number, -- client: table not bought yet
	GhostDimTransparency: number, -- client: ghost the party cannot pay yet (fainter, like the bench)
	StandTimeout: number, -- seconds: a diner whose walk to the table fails is sent away after this
	WalkTimeout: number, -- seconds for the last straight walk (approach point / seat)
	Approach: number, -- studs behind the seat (opposite of its LookVector) where the diner stands before sitting
	States: { string }, -- Tables.State enum (network.md §14.1)
	Seats: Seats,
	Binding: Binding,
}

const seating: Seating = {
	UnlockDay = 2,
	Tables = 9,
	Groups = {
		{
			Key = "Pad",
			First = 1,
			Count = 5,
			UpgradeKey = "patio_tables",
			Stat = "TableCount",
			Vehicles = { "cart" }, -- user 2026-10-12 (Q-216): the Pad is an empty lot once the trailer is the vehicle
			Label = "Table",
			GhostAll = true,
		},
		{
			Key = "Trailer",
			First = 6,
			Count = 4,
			UpgradeKey = "trailer_tables",
			Stat = "TrailerTableCount",
			Vehicles = { "trailer" },
			Label = "Trailer Table",
			GhostAll = false,
		},
	},
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
	SitChanceApplies = false,
	SitPhases = { "Open", "Night" },
	TensionAnomalies = { "anm_007_walker", "anm_008_long_car", "anm_009_knock", "anm_010_hush" },
	GhostTransparency = 0.7,
	GhostDimTransparency = 0.88,
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
		GroupAttribute = "TableGroup",
		Folder = { "MAP01_Assets", "PadDecor" },
		ModelName = "AST-100_PicnicTable",
		SeatPrefix = "Seat",
		SeatCount = 4,
		BuyAnchor = "Prompt_BuyTable",
		CleanAnchor = "Prompt_CleanTable",
		RuntimeAnchor = "Prompt_Table",
		ServeAnchor = "Prompt_ServeTable",
		RuntimeServeAnchor = "Prompt_Serve",
		TrayAnchor = "Tray_Anchor",
		NodePrefix = "TBL-",
		LightsAnchor = "Prompt_PatioLights",
	},
}

return Table.record(seating)
