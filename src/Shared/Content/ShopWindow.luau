--!strict
-- Service window = shop (TASK-284, owner request 2026-10-14; FEAT-023, DEC-221; Provisional, Q-270). The trailer has ONE
-- shop lever now: the service window (shutter_toggle, Prompt_Shutter next to the phone). Open window = shop open, closed
-- window = shop closed (RoundService Paused in the selling phases: no new customer, sign and neon CLOSED). Owners:
-- VehicleService (window, shop sync), CustomerService (the line leaves), AnomalyService (Anomalies below).
--
-- Closing the window while customers wait in line or are being served sends ALL of them away angry: mood LeaveMood, every
-- pending hot dog settled as LeaveResult ($0, same ledger and stats as a refusal). The tutorial customer and anomaly
-- actors stay (their own flow decides).
--
-- Complaining (owner request 2026-10-19, Provisional): a window closed BY A PLAYER does not clear the line at once. It must
-- stay shut ShutGrace s (a quick reopen changes nothing); then each customer shows one of ShutLines over its head
-- (packet CustomerComplain), is Complaining with its patience frozen, and leaves ComplainTime (+ up to LeaveJitter) s
-- later with the outcome above. An automatic closing (anomaly) still clears the line at once.
--
-- Anomalies (game-designer, Provisional Q-270): what the window does to each anomaly. A key missing here = "None".
--   None    the window changes nothing (its own rule may still read IsShutterClosed / IsProtected, ANM-008/009)
--   Blocks  a closed window at the scheduled start avoids it: the occurrence is dropped, nothing happens (a closed shop
--           gets no customer, odd or not; the price is the sales lost while closed)
--   Closes  the anomaly slams the window shut when it starts (the line leaves angry as above)
-- NOTE T10: this table replicates, so a client can read which anomalies the window avoids. Accepted while Provisional:
-- the closed window is visible to everyone anyway, and no verb, deadline or failure rule lives here.
local Table = require(script.Parent.Table)

export type AnomalyWindow = "None" | "Blocks" | "Closes"

export type ShopWindow = {
	LeaveMood: string, -- Content.Moods key of the customers sent away by a closing window
	LeaveResult: string, -- SaleResult of their pending hot dogs (Refused = counts as a refusal)
	ShutGrace: number, -- s the window must stay shut before the line reacts
	WaitShutGrace: number, -- s the window must stay shut before the customers whose order was taken react
	ComplainTime: number, -- s the complaint bubble shows before the customer walks off
	LeaveJitter: number, -- up to this many extra s, random per customer, so they do not leave in lockstep
	ShutLines: { string }, -- short original complaints (bubble text; CustomerComplain.Line is the index)
	Anomalies: { [string]: AnomalyWindow }, -- Content.Anomalies key -> effect; missing = None
}

const shopWindow: ShopWindow = {
	LeaveMood = "Complaining",
	LeaveResult = "Refused",
	ShutGrace = 1.5,
	WaitShutGrace = 5.2, -- 2 x (1.5 + 2.2) - 2.2: they walk off at twice the line's time
	ComplainTime = 2.2,
	LeaveJitter = 0.4,
	ShutLines = {
		"Seriously? I was right here!",
		"Closed? Now?",
		"Unbelievable.",
		"I waited for this?",
		"Rude. Real rude.",
		"Fine. Eating elsewhere.",
		"Hey, I'm standing here!",
		"You're kidding me.",
		"Wow. Okay. Bye.",
		"Not even a sorry?",
		"Right when I got here?",
		"Nope. I'm out.",
	},
	Anomalies = {
		-- family A and the V1 customer actors: they come to the window like any customer
		anm_001_blank_folks = "Blocks",
		anm_004_copies = "Blocks",
		anm_005_raincoat_lady = "Blocks",
		anm_011_shaker = "Blocks",
		anm_012_turned_neck = "Blocks",
		anm_013_white_eyes = "Blocks",
		anm_014_big_head = "Blocks",
		anm_015_floater = "Blocks",
		anm_016_starer = "Blocks",
		anm_023_on_camera = "Blocks", -- Q-437
		anm_022_head_banger = "Blocks", -- TASK-591: it stays, the window does not send it away (lights off does)
		-- the window is already their answer (verb "shutter" in their Rules): nothing extra
		anm_008_long_car = "None",
		anm_009_knock = "None",
		-- the hush rolls in with the fog. TASK-592 (owner 2026-10-19, Provisional Q-398): it no longer bangs the window
		-- shut on its own ("Closes" before); an open window is how its head gets in (Anomalies/ANM-010)
		anm_010_hush = "None",
	},
}

return Table.record(shopWindow)
