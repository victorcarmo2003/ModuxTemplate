--!strict
-- Analytics (RoMetrics SDK, owner request 2026-10-16, Provisional). Only the wire lists the client may report live here;
-- every other event is logged by the server (Metrics/server/MetricsService). Both lists become Lync enums
-- (MetricUi.Event, MetricTutorial.Step), so a client can only send names from them.
--   UiEvents       client-only UI moments the server cannot see (menus opened, purchase prompts shown). offer_*:
--                  contextual offers (TASK-361, Provisional): shown / clicked (= the prompt or the shop opened) /
--                  expired unclicked / muted by fatigue; offers_off / offers_on = the Shop tips setting
--   TutorialSteps  every Day 1 tutorial step key (Tutorial/client/TutorialController/Steps.luau keys): the wire enum of
--                  MetricTutorial.Step, never the funnel itself
--   TutorialFunnel the onboarding funnel milestones in order (2026-10-17): several steps map to one milestone
--                  (TutorialMilestone), so a waiting row, a branch (deliver / serve, discard) or a step a mate did never
--                  breaks it (wait_call was a waiting row seen only when the phone was late: 1 player in 7 days).
--                  Funnel step = index + 1 (1 = began, TutorialService; last = complete {how = done | skip | over})
--   TutorialMilestone  step key -> TutorialFunnel index; keys not listed (waiting rows) are not logged
--   AnomalyFunnel  the per-anomaly funnel anomaly_<key> (owner request 2026-10-20, Provisional): step i = index i, one
--                  session per occurrence. Step 4 is the per-player outcome and is named by the result instead
--                  (resolved / failed / cut; MetricsService.AnomalyStep)
--   UiRate         s between two MetricUi packets of one player (the server drops faster ones)
--   FpsWindow      s of one server frame-rate sample (owner request 2026-10-22, Provisional): server_fps (MetricsService)
local Table = require(script.Parent.Table)

export type Metrics = {
	UiEvents: { string },
	TutorialSteps: { string },
	TutorialFunnel: { string },
	TutorialMilestone: { [string]: number },
	AnomalyFunnel: { string },
	UiRate: number,
	FpsWindow: number,
}

const metrics: Metrics = {
	UiEvents = {
		"shop_open",
		"shop_close",
		"settings_open",
		"product_prompt",
		"revive_prompt",
		"offer_shown",
		"offer_click",
		"offer_expired",
		"offer_muted",
		"offers_off",
		"offers_on",
		-- lobby windows (owner request 2026-10-17; MetricsService/Lobby.luau funnels): opened, the Play choice, a gem
		-- pack prompted, a class looked at
		"lobby_shop_open",
		"lobby_classes_open",
		"lobby_codes_open",
		"lobby_squad_open",
		"lobby_play_open",
		"lobby_gem_prompt",
		"lobby_class_pick",
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
		"cook", -- 2026-10-17: the kitchen steps of Day 1 merged into one (append only: the index is the wire value)
	},
	TutorialFunnel = { "phone", "open", "order", "cook", "plate", "serve", "first_sale" },
	TutorialMilestone = {
		phone = 1,
		open = 2,
		order = 3,
		grill = 4,
		slice = 4,
		slicing = 4,
		cooking = 4,
		collect = 4,
		cook = 4,
		assemble = 5,
		toppings = 5,
		discard = 5,
		deliver = 6,
		serve = 6,
		money = 7,
	},
	AnomalyFunnel = { "start", "signal", "active" },
	UiRate = 0.5,
	FpsWindow = 60,
}

return Table.record(metrics)
