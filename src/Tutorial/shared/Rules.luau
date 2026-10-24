--!strict
-- Tutorial customer (user request 2026-10-11, Provisional): numbers and names shared by CustomerService (server, who
-- spawns and judges it) and TutorialController (client, who guides the rookie through its order).
-- One tutorial customer per server: TutorialService asks it once the rookie answered Walt's call (TutorialBegin).
-- No time limit (patience never runs out, no ring), never counts on the shift grade, never an anomaly;
-- the regular flow waits while it is at the counter. Its rig carries the attribute ATTRIBUTE = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

-- Restaurant tutorial (TASK-393; design/tutorial-restaurant.md, Provisional): the only tutorial (DEC-307).
const RESTAURANT = true

return table.freeze({
	-- DEC-311 (owner 2026-10-19): two tutorial customers, one after the other. The first one wants a plain hot dog (fry, cut,
	-- plate, serve), the second one ketchup and mustard (the same, then the condiment table). Content.Ingredients keys.
	Orders = table.freeze({ table.freeze({}) :: { string }, table.freeze({ "ketchup", "mustard" }) }),
	-- rig attribute (Model) of the tutorial customer, read by the client
	Attribute = "TutorialCustomer",
	-- s between two spawn tries while the counter is full or the NPC pool is busy
	Retry = 2,
	-- Shopping lesson (user request 2026-10-11, Provisional): a tutorial run starts with this many buns (TutorialService
	-- caps the bun stock when the call is answered and every player in the server is a rookie), so the first sale
	-- empties the crate and Walt sends the rookie to buy Package (Content.Packages key) and restock it.
	Buns = 1,
	Package = "pack_buns",
	-- Day 1 cut (owner decision 2026-10-17, Provisional, docs/tasks/playtest-2026-10-17.md): the tutorial ends on the
	-- first sale. Shopping = the bun cap + the Mart trip on Day 1 (false: normal stock; the Mart is a hint on any day
	-- when the buns run low, MarketController, Content.Mart.LowBuns). The upgrade lesson below is off too: the Gear
	-- Stand is open from Day 1 and the closing-time Gear Stand hint (MarketController) teaches it from then on.
	Shopping = false,
	-- Day 1 upgrade lesson (owner request 2026-10-14, Provisional): when the first shift ends (the day Closing, 6 PM) the
	-- clock stays held, Walt calls (BossCalls row Call, Trigger UpgradeLesson) and the rookie is guided to the Gear Stand to
	-- buy the first level of Key (Bun Box, UPG-035; was Storage before DEC-331). The Gear Stand is closed before that (Content.Mart.FirstShiftClosed). Short on
	-- money when the call rings: Cash is topped up to Cash (EconomyService:TopUp, like the bun package), never below the
	-- price. Over once any Gear Stand line is bought, the run leaves Day 1, or Content.Shift.TutorialHoldMax s of holding.
	Upgrade = table.freeze({
		-- 2026-10-17 cut (above): no call, no Closing hold, no Day 1 lesson steps. Back on in the restaurant only (TASK-393,
		-- design/tutorial-restaurant.md §3): the Gear Stand step at the end of Day 1
		Enabled = RESTAURANT,
		Key = "bun_box",
		Call = "call_tutorial_upgrade",
		Cash = 100,
		-- s into the Summary before Walt's lesson call (owner 2026-10-21, Provisional): the night's report shows first
		-- (HudController SUMMARY_SHOWN = 3 s), then the lesson; after the purchase the rookie is guided back to open the
		-- window (TutorialController step upg_open)
		AfterReport = 3,
	}),
	-- Restaurant tutorial (TASK-393): the steps of the restaurant loop (tablet -> cut -> plate -> grill -> plate -> take
	-- -> toppings -> pickup) replace the trailer kitchen steps; Restock = after the first sale, a box from a product bay
	-- (StockShelf) of the infinite stock room -> Restock at its station (needs Content.Restaurant.Supply.Enabled too; no
	-- phone order, no cash top-up: owner 2026-10-17).
	Restaurant = RESTAURANT,
	Restock = RESTAURANT and Content.Restaurant.Supply.Enabled,
})
