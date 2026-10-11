--!strict
-- Tutorial customer (user request 2026-10-11, Provisional): numbers and names shared by CustomerService (server, who
-- spawns and judges it) and TutorialController (client, who guides the rookie through its order).
-- One tutorial customer per server: TutorialService asks it once the rookie answered Walt's call (TutorialBegin).
-- No time limit (patience never runs out, no ring), never counts on the shift grade, never an anomaly or a thief;
-- the regular flow waits while it is at the counter. Its rig carries the attribute ATTRIBUTE = true.

return table.freeze({
	-- fixed order of the tutorial customer (Content.Ingredients topping keys; Walt's lines name it, Steps.luau)
	Order = table.freeze({ "ketchup" }),
	-- rig attribute (Model) of the tutorial customer, read by the client
	Attribute = "TutorialCustomer",
	-- s between two spawn tries while the counter is full or the NPC pool is busy
	Retry = 2,
})
