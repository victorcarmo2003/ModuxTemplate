--!strict
-- Smoke test (2026-10-12, Provisional): walks the main scenarios with no UI, through the same dev commands and service
-- APIs a person would use, and prints one report. Per-step pcall; warnings and errors of the server Output
-- (LogService.MessageOut) are collected while it runs. Client-side errors are not visible here: read the Studio console
-- (get_console_output) or the client's LogService:GetLogHistory (see tools/studio/smoke.md).
--   smoke           starts the run in the background (about 60 s); the report prints in the Output when it ends
--   smoke status    "running" / the last report
-- Report: "SMOKE: N ok, M failures, K warnings" then one line per failed step, error line and warning.
-- Dev mode only (DevService loads Commands/ only then). It changes the run state (day, night, tables, tutorial):
-- run it in a throwaway Play session.
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local Api = require(script.Parent.Parent.Api)

type Step = { Name: string, Run: () -> string? }

type Round = {
	GetPhase: (self: any) -> string,
	GetDay: (self: any) -> number,
	GetNight: (self: any) -> number,
	IsNight: (self: any) -> boolean,
}

type Customers = {
	Customers: { [number]: { State: string } },
	DevSpawn: (self: any) -> (string, number?),
	TakeOrder: (self: any, player: Player, anchor: Instance) -> (),
}

type Npc = {
	Anchors: (self: any, id: number) -> (Instance?, Instance?),
}

type Showcase = {
	Run: (self: any, player: Player, action: string, id: string, arg: string, value: number) -> (boolean, string),
}

type Vehicles = {
	Current: (self: any) -> string,
}

const MAX_LINES = 40
const SETTLE = 0.6

const Smoke: Api.Module = function(ctx: Api.Context): { Api.Command }
	local running = false
	local lastReport = "no smoke run yet"

	local function service(name: string): any
		return ctx.Get(name)
	end

	-- Dev command through the DevService bridge (the same entry as "/dev <name> <args>"). Required lazily: DevService
	-- has finished loading by the time a command runs.
	local function dev(name: string, ...: any): string
		const DevService = (require :: any)(script.Parent.Parent)
		return tostring(DevService.Run(name, ...) or "")
	end

	local function player(): Player
		const first = Players:GetPlayers()[1]
		if first == nil then
			error("no player in the server (start Play with a client)", 0)
		end
		return first
	end

	local function where(): string
		const round = service("RoundService") :: Round
		const shift = if round:IsNight() then `N{round:GetNight()}` else `D{round:GetDay()}`
		return `{shift} {round:GetPhase()}`
	end

	local function settle(seconds: number?)
		task.wait(seconds or SETTLE)
	end

	local function waitFor(predicate: () -> boolean, timeout: number): boolean
		const limit = os.clock() + timeout
		while os.clock() < limit do
			if predicate() then
				return true
			end
			task.wait(0.25)
		end
		return predicate()
	end

	local steps: { Step } = {
		{
			Name = "boot",
			Run = function(): string?
				const p = player()
				service("PlaceService")
				service("CutsceneService")
				return `{p.Name} in {where()}, vehicle {(service("VehicleService") :: Vehicles):Current()}`
			end,
		},
		{
			Name = "intro skip",
			Run = function(): string?
				const reply = dev("intro", "skip")
				settle()
				return `{reply}; {where()}`
			end,
		},
		{
			Name = "tutorial reset",
			Run = function(): string?
				const reply = dev("tutorial", "reset")
				settle(1)
				return `{reply}; {where()}`
			end,
		},
		{
			Name = "tutorial steps",
			Run = function(): string?
				-- the client jumps through the main keys (Steps.luau); its errors show in the client Output
				for _, key in { "phone", "order", "grill", "assemble", "serve", "mart", "auto" } do
					dev("tutorial", "step", key)
					settle(0.4)
				end
				return dev("tutorial")
			end,
		},
		{
			Name = "day 2",
			Run = function(): string?
				const reply = dev("day", "2")
				settle(1)
				return reply
			end,
		},
		{
			Name = "customer take order",
			Run = function(): string?
				const customers = service("CustomerService") :: Customers
				if (service("RoundService") :: Round):GetPhase() == "Prep" then
					dev("skip") -- Prep -> Open: customers only walk to the queue while the shop is open
					settle()
				end
				const outcome, id = customers:DevSpawn()
				-- the counter holds ONE customer by default (DEC-241): a full counter means somebody is already there
				if id == nil and outcome ~= "skipped_queue_full" then
					error(`no customer spawned ({outcome}, {where()})`, 0)
				end
				const npc = service("NpcService") :: Npc
				-- the customer walks to Q1 first (Arriving -> Queued -> Ordering). Any customer in the queue will do: the
				-- first one can be the held tutorial customer.
				local target: number? = nil
				local function someoneOrdering(): boolean
					for npcId, customer in customers.Customers do
						if customer.State == "Ordering" then
							target = npcId
							return true
						end
					end
					return false
				end
				if not waitFor(someoneOrdering, 30) then
					error(`customer {id} spawned ({outcome}) but nobody reached Ordering in 30 s ({where()})`, 0)
				end
				const ordering = target :: number
				const anchor = npc:Anchors(ordering)
				if anchor == nil then
					error(`customer {ordering} has no anchor`, 0)
				end
				customers:TakeOrder(player(), anchor)
				settle()
				const taken = customers.Customers[ordering]
				const state = if taken then taken.State else "gone"
				if state ~= "Waiting" then
					error(`customer {ordering} state after Take Order: {state} (expected Waiting)`, 0)
				end
				return `customer {ordering} order taken ({outcome}), {state}`
			end,
		},
		{
			Name = "seating buy + sit",
			Run = function(): string?
				const bought = dev("seating", "buy")
				dev("customer", "sit")
				settle(2)
				return `{bought}; {dev("seating")}`
			end,
		},
		{
			Name = "night 1",
			Run = function(): string?
				const reply = dev("night", "1")
				settle(1)
				return reply
			end,
		},
		{
			Name = "night 1 coffee + sanity",
			Run = function(): string?
				const sanity = dev("sanity")
				dev("sanity", "40")
				const after = dev("sanity")
				return `{sanity} | after set: {after} | {dev("coffee")}`
			end,
		},
		{
			Name = "anomaly trigger/stop",
			Run = function(): string?
				const showcase = service("ShowcaseService") :: Showcase
				const ok, text = showcase:Run(player(), "trigger", "ANM-002", "", 0)
				if not ok then
					error(`trigger ANM-002: {text}`, 0)
				end
				settle(1.5)
				const status = dev("anomaly")
				const stopOk, stopText = showcase:Run(player(), "stop", "ANM-002", "", 0)
				if not stopOk then
					error(`stop ANM-002: {stopText}`, 0)
				end
				dev("anomaly", "stop")
				return `{text} | {status} | {stopText}`
			end,
		},
		{
			Name = "trailer ready",
			Run = function(): string?
				const reply = dev("trailer", "status")
				settle(1)
				const vehicle = (service("VehicleService") :: Vehicles):Current()
				if vehicle ~= "trailer" then
					error(`vehicle is {vehicle}, the trailer is the only vehicle`, 0)
				end
				return `{reply}; {vehicle}`
			end,
		},
		{
			Name = "trailer seating",
			Run = function(): string?
				return `{dev("seating", "trailer", "buy")}; {dev("seating", "trailer")}`
			end,
		},
		{
			Name = "tip jar + ledger",
			Run = function(): string?
				-- pure settlement test (DEC-238, DEC-239) and the jar state line
				const report = dev("economy", "ledger")
				const passed, total = string.match(report, "(%d+)/(%d+) ok")
				if passed == nil or passed ~= total then
					error(`economy ledger: {report}`, 0)
				end
				return `ledger {passed}/{total}; {dev("tips")}`
			end,
		},
		{
			Name = "cleanup",
			Run = function(): string?
				dev("anomaly", "stop")
				dev("trailer", "reset")
				return where()
			end,
		},
	}

	local function execute()
		const warnings: { string } = {}
		const errors: { string } = {}
		const seen: { [string]: boolean } = {}
		const connection = LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
			if string.find(message, "SMOKE:", 1, true) or string.find(message, "[Smoke]", 1, true) then
				return
			end
			if kind ~= Enum.MessageType.MessageWarning and kind ~= Enum.MessageType.MessageError then
				return
			end
			const key = `{kind.Value}{message}`
			if seen[key] then
				return
			end
			seen[key] = true
			table.insert(if kind == Enum.MessageType.MessageError then errors else warnings, message)
		end)

		local ok = 0
		const failed: { string } = {}
		for _, step in steps do
			const started = os.clock()
			const success, result = pcall(step.Run)
			const took = os.clock() - started
			if success then
				ok += 1
				ctx.Log(`[Smoke] ok   {step.Name} ({string.format("%.1f", took)}s): {result or ""}`)
			else
				table.insert(failed, `{step.Name}: {tostring(result)}`)
				ctx.Log(`[Smoke] FAIL {step.Name}: {tostring(result)}`)
			end
		end
		task.wait(1) -- late warnings of the last step
		connection:Disconnect()

		const lines = { `SMOKE: {ok} ok, {#failed + #errors} failures, {#warnings} warnings` }
		for _, line in failed do
			table.insert(lines, `  step FAIL {line}`)
		end
		for _, line in errors do
			if #lines >= MAX_LINES then
				break
			end
			table.insert(lines, `  error {line}`)
		end
		for _, line in warnings do
			if #lines >= MAX_LINES then
				table.insert(lines, "  ... (more warnings, see the Output)")
				break
			end
			table.insert(lines, `  warn  {line}`)
		end
		lastReport = table.concat(lines, "\n")
		running = false
		print(lastReport)
	end

	return {
		{
			Name = "smoke",
			Usage = "smoke [status]",
			Help = "smoke test: boot, intro skip, tutorial, day customer, seating, night 1, anomaly, trailer ready, trailer tables; prints 'SMOKE: N ok, M failures, K warnings'",
			Run = function(args: { string }, _caller: Player?): string?
				if args[1] == "status" then
					return if running then "smoke running" else lastReport
				end
				if running then
					error("smoke is already running", 0)
				end
				running = true
				task.spawn(function()
					const success, err = pcall(execute)
					if not success then
						running = false
						warn(`[Smoke] aborted: {err}`)
					end
				end)
				return "smoke started; the report prints in the Output (smoke status shows it)"
			end,
		},
	}
end

return Smoke
