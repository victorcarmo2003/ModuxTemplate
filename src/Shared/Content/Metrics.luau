--!strict
-- Analytics (RoMetrics SDK, owner request 2026-10-16, Provisional). Only the wire lists the client may report live here;
-- every other event is logged by the server (Metrics/server/MetricsService). Both lists become Lync enums
-- (MetricUi.Event, MetricTutorial.Step), so a client can only send names from them.
--   UiEvents       client-only UI moments the server cannot see (menus opened, purchase prompts shown)
--   TutorialSteps  the Day 1 tutorial steps in order (Tutorial/client/TutorialController/Steps.luau keys); the index is
--                  the onboarding funnel step (LogOnboardingFunnelStepEvent, step = index + 1, 0 = the tutorial began)
--   UiRate         s between two MetricUi packets of one player (the server drops faster ones)
local Table = require(script.Parent.Table)

export type Metrics = {
	UiEvents: { string },
	TutorialSteps: { string },
	UiRate: number,
}

const metrics: Metrics = {
	UiEvents = {
		"shop_open",
		"shop_close",
		"settings_open",
		"product_prompt",
		"revive_prompt",
	},
	TutorialSteps = {
		"phone",
		"wait_call",
		"open",
		"wait_customer",
		"order",
		"grill",
		"slice",
		"slicing",
		"cooking",
		"collect",
		"assemble",
		"toppings",
		"discard",
		"deliver",
		"serve",
		"money",
		"mart_go",
		"mart_buy",
		"mart_back",
		"restock",
		"mart",
		"upg_go",
		"upg_buy",
	},
	UiRate = 0.5,
}

return Table.record(metrics)
