--!strict
-- Which audio ids the client loads, and when (playtest 2026-10-12: "NotEnoughQuota" with every id of Content.Sounds
-- preloaded at once). Three tiers, none of them loads at the loading screen except what the intro asks for itself
-- (LoadingController):
--   Core   UI, kitchen, sale, customers, phone, the lobby music, the day shift pool, the day street and the Mart bed.
--          Background job right after the loading screen (LoadQueue.Release).
--   Night  everything else with an id (night street, night pool, tension bed, horror stingers, anomalies, door and
--          shadow sfx...): loaded when the night comes close (phase Closing onwards, or IsNight), not before.
--   Lazy   the finale cue: only at its first Play (AudioController asks LoadQueue.Want).
-- Anything outside its tier still plays: the first Play asks LoadQueue.Want for that one id.
local Tiers = {}

const CORE_KEYS = {
	"music_lobby",
	"grill_sizzle",
	"grill_drop",
	"grill_ready",
	"grill_collect",
	"hotdog_assemble",
	"bun_slice",
	"topping_squirt",
	"topping_sprinkle",
	"restock",
	"coin",
	"drawer",
	"drawer_close",
	"buy",
	"upgrade_done",
	"trash",
	"coffee_brew",
	"coffee_drink",
	"coffee_ready",
	"switch_click",
	"phone_ring",
	"phone_pickup",
	"phone_hangup",
	"pencil_write", -- Walt's notes: written during the night call, ready before it
	"phone_line", -- the line noise under Walt's calls (the tutorial call is the first one)
	"order_take",
	"serve",
	"tip",
	"cust_happy",
	"cust_complain",
	"cust_wrong",
	"cust_leave",
	"refuse",
	"car_engine",
	"car_honk_soft",
	"door_close",
	"walker_step",
}

const LAZY_KEYS = { "music_finale" }

-- Phases (Shift.luau) from which the night sounds start loading: the boss call before the night is the last stretch
const NIGHT_PHASES = {
	Closing = true,
	Summary = true,
	Call = true,
	Night = true,
	NightEnd = true,
	NightLost = true,
}

type Row = { Key: string, Id: string, Group: string }

function Tiers.IsNightPhase(phase: string): boolean
	return NIGHT_PHASES[phase] == true
end

-- Distinct ids of a list of keys, in order (rows without an id or already in `seen` are skipped)
local function idsOf(keys: { string }, byKey: { [string]: Row }, seen: { [string]: boolean }): { string }
	const ids: { string } = {}
	for _, key in keys do
		const row = byKey[key]
		if row ~= nil and row.Id ~= "" and not seen[row.Id] then
			seen[row.Id] = true
			table.insert(ids, row.Id)
		end
	end
	return ids
end

-- Core and night id lists. `dayKeys` = keys of the day pool + street + Mart bed (SoundRules).
function Tiers.Plan(list: { Row }, byKey: { [string]: Row }, dayKeys: { string }): ({ string }, { string })
	const seen: { [string]: boolean } = {}
	const coreKeys: { string } = table.clone(CORE_KEYS)
	for _, key in dayKeys do
		table.insert(coreKeys, key)
	end
	for _, row in list do
		if row.Group == "Ui" then
			table.insert(coreKeys, row.Key)
		end
	end
	const core = idsOf(coreKeys, byKey, seen)
	idsOf(LAZY_KEYS, byKey, seen)
	const rest: { string } = {}
	for _, row in list do
		table.insert(rest, row.Key)
	end
	const night = idsOf(rest, byKey, seen)
	return core, night
end

return table.freeze(Tiers)
