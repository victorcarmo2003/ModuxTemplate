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
	Anomalies: { [string]: AnomalyWindow }, -- Content.Anomalies key -> effect; missing = None
}

const shopWindow: ShopWindow = {
	LeaveMood = "Complaining",
	LeaveResult = "Refused",
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
		-- the window is already their answer (verb "shutter" in their Rules): nothing extra
		anm_008_long_car = "None",
		anm_009_knock = "None",
		-- the hush rolls in with the fog: the window bangs shut on its own (Provisional pick for "Closes"; family C
		-- blackout rows join here once they exist)
		anm_010_hush = "Closes",
	},
}

return Table.record(shopWindow)
