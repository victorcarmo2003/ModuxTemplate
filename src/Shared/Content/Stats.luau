--!strict
-- Closed list of modifier stats (content-data.md §3.10). Classes and Upgrades may only touch these.
-- Nothing here touches anomaly rules, chances, revive or traffic (DEC-069 pay-to-win guard).

export type Stat =
	"WalkSpeed"
	| "GrillTime"
	| "GrillSlots"
	| "StockCapacityLevel"
	| "QueueSize"
	| "PatienceBonus"
	| "PackageLimit"
	| "TipAmount"
	| "TipWindow"
	| "SanityStart"
	| "SanityMax"
	| "CoffeeBrewTime"
	| "CoffeeRestore"
	| "SeeAnomalyLoss"
	| "BossBonusPP"
	| "DrawerOpenTime"
	| "StealPct"
	| "LightRadius"
	| "DayFlowBonus"
	| "TableCount" -- UPG-008 Patio Tables: tables bought on the Pad (FEAT-037)
	| "TrailerTableCount" -- UPG-011 Trailer Tables: tables bought for the trailer (FEAT-037)
	| "SitBonus" -- UPG-009 Patio Lights: added to every SitChance (FEAT-037)
	| "BreakerHold" -- UPG-014 Breaker Box: hold of the breaker_reset prompt, s (TASK-324)

const LIST: { Stat } = {
	"WalkSpeed",
	"GrillTime",
	"GrillSlots",
	"StockCapacityLevel",
	"QueueSize",
	"PatienceBonus",
	"PackageLimit",
	"TipAmount",
	"TipWindow",
	"SanityStart",
	"SanityMax",
	"CoffeeBrewTime",
	"CoffeeRestore",
	"SeeAnomalyLoss",
	"BossBonusPP",
	"DrawerOpenTime",
	"StealPct",
	"LightRadius",
	"DayFlowBonus",
	"TableCount",
	"TrailerTableCount",
	"SitBonus",
	"BreakerHold",
}

const SET: { [string]: boolean } = {}
for _, stat in LIST do
	SET[stat] = true
end

return table.freeze({
	List = table.freeze(LIST),
	Has = table.freeze(SET),
})
