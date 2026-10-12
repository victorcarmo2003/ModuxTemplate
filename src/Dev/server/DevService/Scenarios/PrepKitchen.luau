--!strict
-- `/dev prep kitchen` (TASK-169; docs/tech/prep-mode.md §2, §7): scenarios of the KitchenService side of the prep mode,
-- no UI and no PrepService. Called by Commands/Prep.luau. BeginPlate / FinishPlate / RefundPlate / TrashPlate (the three
-- refusals NoSausage, NoStock and HandsFull must change nothing), GrillAct Place / Flip / Collect with the server clock
-- (DevAgeGrill stands in for waiting), the TakeStock race and the WorldKitchenPrompts flag (DevWorldPrompts stands in for
-- editing the data). Needs a running shift (the caller must be an active member). Stock, rail and hotbar are put back.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Api = require(script.Parent.Parent.Api)
local Content = require(ReplicatedStorage.shared.Content)

type Kitchen = {
	BeginPlate: (self: any, player: Player, slot: number?) -> (any?, string?),
	FinishPlate: (self: any, player: Player, spec: any) -> (any?, string?),
	RefundPlate: (self: any, player: Player) -> boolean,
	TrashPlate: (self: any, player: Player, options: any?) -> any,
	GrillAct: (self: any, player: Player, act: string, slot: number?) -> (any?, string?),
	PlateOf: (self: any, player: Player) -> any?,
	DevFeedRail: (self: any, score: number?) -> boolean,
	DevAgeGrill: (self: any, slot: number, seconds: number) -> number,
	DevWorldPrompts: (self: any, on: boolean?) -> (),
	RailCount: (self: any) -> number,
	BoardFree: (self: any) -> number,
	GetStock: (self: any, ingredient: string) -> (number, number),
	SetAmount: (self: any, ingredient: string, amount: number) -> (),
	TakeStock: (self: any, ingredient: string, n: number) -> boolean,
	IsBlocked: (self: any, ingredient: string) -> boolean,
	GetVehicle: (self: any) -> string,
	StationOf: (self: any, instance: Instance) -> any?,
	Wanted: { [Instance]: { Enabled: boolean, Text: string? } },
}

type Items = {
	Give: (self: any, player: Player, key: string, options: any?) -> Tool?,
	Consume: (self: any, player: Player, tool: Tool) -> (),
	Tools: (self: any, player: Player) -> { Tool },
}

const WORLD_ACTIONS = { "grill_place", "grill_collect", "bun_cut", "board_add_sausage", "topping_add", "discard" }

local function run(api: Api.Context, caller: Player?): string
	const player = caller or Players:GetPlayers()[1]
	if player == nil then
		error("needs a player in the server", 0)
	end
	const kitchen = api.Get("KitchenService") :: Kitchen
	const items = api.Get("ItemService") :: Items
	local total = 0
	local failed = 0
	local function check(name: string, ok: boolean, detail: string?)
		total += 1
		if ok then
			api.Log(`prep kitchen ok   {name}`)
		else
			failed += 1
			api.Log(`prep kitchen FAIL {name}{if detail then ": " .. detail else ""}`)
		end
	end
	local function stock(key: string): number
		return (kitchen:GetStock(key))
	end

	-- a topping that is open today, and the stock to run on (restored at the end)
	local topping: string? = nil
	for _, key in Content.Ingredients.ToppingKeys do
		if not kitchen:IsBlocked(key) then
			topping = key
			break
		end
	end
	if topping == nil then
		error("no topping is unlocked today (use `day` first)", 0)
	end
	const top: string = topping
	const keys = { "bun", "sausage", top }
	const saved: { [string]: number } = {}
	for _, key in keys do
		saved[key] = stock(key)
		kitchen:SetAmount(key, math.max(saved[key], 4))
	end

	local function throwTools()
		for _, tool in items:Tools(player) do
			if tool:GetAttribute("Item") == "hot_dog" then
				items:Consume(player, tool)
			end
		end
	end
	local function drain()
		kitchen:RefundPlate(player)
		for _ = 1, 40 do
			const before = kitchen:RailCount()
			if before == 0 then
				break
			end
			kitchen:TrashPlate(player, { Sausage = true })
			if kitchen:RailCount() == before then
				break
			end
		end
	end

	const ok, err = pcall(function()
		throwTools()
		drain()
		const free0 = kitchen:BoardFree()

		-- 1. Begin / Refund
		const bun0 = stock("bun")
		const ticket, reason = kitchen:BeginPlate(player, 1)
		check("begin gives a ticket", ticket ~= nil, tostring(reason))
		check("begin takes 1 bun", stock("bun") == bun0 - 1, `{stock("bun")} vs {bun0 - 1}`)
		check("begin holds a board slot", kitchen:BoardFree() == free0 - 1)
		const again, againReason = kitchen:BeginPlate(player, 1)
		check("second begin is Busy", again == nil and againReason == "Busy", tostring(againReason))
		check("second begin changes nothing", stock("bun") == bun0 - 1 and kitchen:BoardFree() == free0 - 1)
		check("refund gives the plate back", kitchen:RefundPlate(player) == true)
		check("refund returns the bun", stock("bun") == bun0, `{stock("bun")} vs {bun0}`)
		check("refund frees the slot", kitchen:BoardFree() == free0)
		check("refund twice is false", kitchen:RefundPlate(player) == false)

		-- 2. refusal: no sausage on the rail (nothing changes)
		kitchen:BeginPlate(player, 1)
		const bun1 = stock("bun")
		const topStock = stock(top)
		const none, noneReason = kitchen:FinishPlate(player, { Toppings = { top } })
		check("finish without a sausage = NoSausage", none == nil and noneReason == "NoSausage", tostring(noneReason))
		check(
			"NoSausage changes nothing",
			stock("bun") == bun1
				and stock(top) == topStock
				and kitchen:BoardFree() == free0 - 1
				and kitchen:PlateOf(player) ~= nil
		)

		-- 3. refusal: topping out of stock (nothing changes)
		kitchen:DevFeedRail(nil)
		kitchen:SetAmount(top, 0)
		const dry, dryReason = kitchen:FinishPlate(player, { Toppings = { top } })
		check("finish with an empty topping = NoStock", dry == nil and dryReason == "NoStock", tostring(dryReason))
		check(
			"NoStock changes nothing",
			kitchen:RailCount() == 1 and stock("bun") == bun1 and kitchen:BoardFree() == free0 - 1
		)
		kitchen:SetAmount(top, topStock)

		-- 4. refusal: hotbar full (nothing changes)
		for _ = 1, 12 do
			if items:Give(player, "hot_dog", { Silent = true, Equip = false }) == nil then
				break
			end
		end
		const full, fullReason = kitchen:FinishPlate(player, { Toppings = { top } })
		check("finish with the hotbar full = HandsFull", full == nil and fullReason == "HandsFull", tostring(fullReason))
		check(
			"HandsFull changes nothing",
			kitchen:RailCount() == 1
				and stock(top) == topStock
				and stock("bun") == bun1
				and kitchen:BoardFree() == free0 - 1
		)
		throwTools()

		-- 5. a valid summary makes the hot dog
		const made, madeReason = kitchen:FinishPlate(player, { Toppings = { top }, Quality = "Perfect" })
		check("finish makes the hot dog", made ~= nil, tostring(madeReason))
		if made ~= nil then
			const tool = made.Tool :: Tool
			check("hot dog carries the topping", tool:GetAttribute("Toppings") == top, tostring(tool:GetAttribute("Toppings")))
			check("hot dog carries the quality", tool:GetAttribute("Quality") == "Perfect")
			check("an ungraded sausage gives no score", made.SausageScore == nil)
		end
		check("finish took the sausage", kitchen:RailCount() == 0)
		check("finish took 1 topping", stock(top) == topStock - 1, `{stock(top)} vs {topStock - 1}`)
		check("finish freed the slot and closed the plate", kitchen:BoardFree() == free0 and kitchen:PlateOf(player) == nil)
		check("finish used the bun", stock("bun") == bun1)
		throwTools()
		const noPlate, noPlateReason = kitchen:FinishPlate(player, { Toppings = {} })
		check("finish with no plate = NoSession", noPlate == nil and noPlateReason == "NoSession", tostring(noPlateReason))

		-- 6. bad summaries are refused before anything moves
		kitchen:BeginPlate(player, 1)
		kitchen:DevFeedRail(nil)
		const dupe, dupeReason = kitchen:FinishPlate(player, { Toppings = { top, top } })
		check("repeated topping = Invalid", dupe == nil and dupeReason == "Invalid", tostring(dupeReason))
		const unknown, unknownReason = kitchen:FinishPlate(player, { Toppings = { "not_a_topping" } })
		check("unknown topping = Invalid", unknown == nil and unknownReason == "Invalid", tostring(unknownReason))
		const noQuality, qualityReason = kitchen:FinishPlate(player, { Toppings = {}, Quality = "Great" })
		check("unknown quality = Invalid", noQuality == nil and qualityReason == "Invalid", tostring(qualityReason))
		check("bad summaries change nothing", kitchen:RailCount() == 1 and kitchen:PlateOf(player) ~= nil)

		-- 7. the bin loses the bun (and the sausage on request), no refund
		const bun2 = stock("bun")
		const lost = kitchen:TrashPlate(player, { Sausage = true })
		check("trash loses the bun and the sausage", lost.Bun == true and lost.Sausage == true and kitchen:RailCount() == 0)
		check("trash does not refund", stock("bun") == bun2 and kitchen:BoardFree() == free0 and kitchen:PlateOf(player) == nil)

		-- 8. TakeStock never gives the same unit twice
		kitchen:SetAmount(top, 1)
		local gotA = false
		local gotB = false
		task.spawn(function()
			gotA = kitchen:TakeStock(top, 1)
		end)
		task.spawn(function()
			gotB = kitchen:TakeStock(top, 1)
		end)
		check("two TakeStock of the last unit: exactly one wins", gotA ~= gotB and stock(top) == 0, `{gotA} {gotB} {stock(top)}`)
		kitchen:SetAmount(top, topStock)

		-- 9. grill: Place, Flip (server clock, once), Collect (graded), FIFO score reaches the plate
		drain()
		const sausage0 = stock("sausage")
		const placeA = kitchen:GrillAct(player, "Place")
		check("grill place gives a slot", placeA ~= nil)
		check("grill place took 1 sausage", stock("sausage") == sausage0 - 1)
		if placeA ~= nil then
			const slotA = placeA.Slot :: number
			const flipA = kitchen:GrillAct(player, "Flip", slotA)
			check("flip right away is Messy", flipA ~= nil and flipA.Band == "Messy", if flipA then tostring(flipA.Score) else "nil")
			const again2, again2Reason = kitchen:GrillAct(player, "Flip", slotA)
			check("second flip is refused", again2 == nil and again2Reason == "Invalid", tostring(again2Reason))
			const early = kitchen:GrillAct(player, "Collect", slotA)
			check("collect before it is ready is refused", early == nil)
			kitchen:DevAgeGrill(slotA, 1000)
			const collectA = kitchen:GrillAct(player, "Collect", slotA)
			check("collect keeps the flip score", collectA ~= nil and flipA ~= nil and collectA.Score == flipA.Score)
			check("collect puts it on the rail", kitchen:RailCount() == 1)

			const placeB = kitchen:GrillAct(player, "Place")
			if placeB ~= nil then
				const slotB = placeB.Slot :: number
				const duration = kitchen:DevAgeGrill(slotB, 0)
				kitchen:DevAgeGrill(slotB, duration * 0.5)
				const flipB = kitchen:GrillAct(player, "Flip", slotB)
				check(
					"flip at half the Duration is Perfect",
					flipB ~= nil and flipB.Band == "Perfect",
					if flipB then tostring(flipB.Score) else "nil"
				)
				kitchen:DevAgeGrill(slotB, 1000)
				kitchen:GrillAct(player, "Collect", slotB)
				check("two sausages on the rail", kitchen:RailCount() == 2)

				kitchen:BeginPlate(player, 1)
				const madeA = kitchen:FinishPlate(player, { Toppings = {} })
				check(
					"front sausage first (FIFO), score travels",
					madeA ~= nil and flipA ~= nil and madeA.SausageScore == flipA.Score
				)
				throwTools()
				kitchen:BeginPlate(player, 1)
				const madeB = kitchen:FinishPlate(player, { Toppings = {} })
				check(
					"second sausage carries the Perfect score",
					madeB ~= nil and flipB ~= nil and madeB.SausageScore == flipB.Score
				)
				throwTools()
			else
				check("second grill place", false, "no free slot")
			end

			const placeC = kitchen:GrillAct(player, "Place")
			if placeC ~= nil then
				kitchen:DevAgeGrill(placeC.Slot :: number, 1000)
				const collectC = kitchen:GrillAct(player, "Collect", placeC.Slot :: number)
				check(
					"never flipped is Messy",
					collectC ~= nil and collectC.Band == "Messy" and collectC.Score == Content.Prep.Grades.Unflipped
				)
			end
		end
		drain()

		-- 10. flag WorldKitchenPrompts: false hides the six world prompts, true gives the flow back
		const vehicle = kitchen:GetVehicle()
		const anchors: { Instance } = {}
		for _, anchor in CollectionService:GetTagged("Interactable") do
			const action = anchor:GetAttribute("PromptAction")
			const station = kitchen:StationOf(anchor)
			if
				type(action) == "string"
				and table.find(WORLD_ACTIONS, action)
				and station ~= nil
				and station.Vehicle == vehicle
			then
				table.insert(anchors, anchor)
			end
		end
		check("world kitchen prompts found on the vehicle", #anchors > 0, "map has none")
		local function enabledCount(): number
			local count = 0
			for _, anchor in anchors do
				if anchor:GetAttribute("PromptEnabled") == true then
					count += 1
				end
			end
			return count
		end
		kitchen:DevWorldPrompts(false)
		check("flag false: every world kitchen prompt is off", enabledCount() == 0, `{enabledCount()} on`)
		kitchen:DevWorldPrompts(true)
		local restored = true
		for _, anchor in anchors do
			const wanted = kitchen.Wanted[anchor]
			const want = if wanted then wanted.Enabled else true
			if anchor:GetAttribute("PromptEnabled") ~= want then
				restored = false
			end
		end
		check("flag true: prompts go back to what their stations asked", restored)
		kitchen:DevWorldPrompts(nil)
		check(
			"flag from Content",
			Content.Prep.Rules.WorldKitchenPrompts or enabledCount() == 0,
			`WorldKitchenPrompts false but {enabledCount()} prompts on`
		)
	end)
	if not ok then
		check("scenarios ran to the end", false, tostring(err))
	end

	-- always leave the kitchen as found
	kitchen:DevWorldPrompts(nil)
	pcall(function()
		throwTools()
		drain()
		for _, key in keys do
			kitchen:SetAmount(key, saved[key])
		end
	end)
	const summary = `prep kitchen: {total - failed}/{total} ok, {failed} failed`
	if failed > 0 then
		error(summary, 0)
	end
	return summary
end

return run
