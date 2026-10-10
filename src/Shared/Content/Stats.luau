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
}

const SET: { [string]: boolean } = {}
for _, stat in LIST do
	SET[stat] = true
end

return table.freeze({
	List = table.freeze(LIST),
	Has = table.freeze(SET),
})
