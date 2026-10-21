--!strict
--[[
	MetricsService (owner request 2026-10-16, Provisional): RoMetrics analytics for the whole game, as precise as the
	server can see it. Single caller of RoMetrics.init (SDK 0.3.1). Priority 50: every service it listens to has built
	its signals before this OnInit.

	Key: HttpService:GetSecret("rometrics_key") (Creator Hub Secret, never in the source). Studio Play cannot read it,
	so in Studio the test key comes from the ServerStorage attribute KEY_ATTRIBUTE, set in the place file only; no key
	= the SDK stays off with one warning and the game runs as usual. Debug Output follows shared/Verbose.

	Automatic in the SDK: servers / CCU, join / leave / country / Premium / platform, Game Pass purchases. Developer
	products: ShopService (the single ProcessReceipt) calls Log.receipt right before PurchaseGranted.

	Logged here from the services' signals:
	  progression  Day k / Night k Start and Complete/Fail per player (RoundService), Run Complete/Fail (RunEnded)
	  onboarding   the Day 1 tutorial: step 1 = began (TutorialService), the client's steps (MetricTutorial), last =
	               completed (TutorialService)
	  anomaly      anomaly_start / anomaly_end (key, phase, failed, party, reason, night, attempt, seconds, t_active) and
	               anomaly_failed per player (key, night, attempt, party, seconds) (AnomalyService). Funnel anomaly_<key>
	               (owner request 2026-10-20, Provisional): one session per occurrence (same id for the whole party), a
	               step once per player: 1 start, 2 signal, 3 active (Content.Metrics.AnomalyFunnel), 4 outcome named
	               resolved | failed | cut with result = resolved | survived | failed | cut. Skipped steps are filled with
	               filled = true. Props: key, night, attempt, party, seconds (since start), t (s to that phase), and on
	               step 4 result, reason, failed, t_active (-1 = never Active). Players: the party at the start still
	               connected; who joined later is only in anomaly_failed.
	               night_result / Night Fail also carry cause_kind, cause_key, cause_anomaly, active: LastCause of the last
	               player to fall (the FINAL blow, not the total drained: a night of slow drain by several anomalies shows
	               only the one that finished it) and the anomalies still alive at that moment
	  customer     customer_take_order / serve / refuse / give_up with the sale result (CustomerService.Acted)
	  life         life_state from -> to (faint, revive, spectator) per player (VitalService)
	  world        window_toggle, light_switch, discard, kitchen events, upgrades, every validated or refused action
	  shop / ui    client UI moments (MetricUi: shop/settings opened, purchase prompts) and prompts closed unbought
	  lobby        lobby servers only (Lobby.luau, owner request 2026-10-17): visit funnel, zones and dwell, squads
	               (PartyService.Tracked), solo / squad starts, window funnels (shop, classes, codes)
	  run zones    run servers only (Zones.luau, owner request 2026-10-21): Zone:run.<zone> per zone change and zone_dwell
	               on leave, from Content.RunZones, the pantry SafeBox and the trailer LightZone
	Economy (Gems per player, crew Cash) is logged where it changes (Log.gems / Log.cash in Class, Codes, Reward,
	Shop and Economy services).
]]
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Modux = require(ServerScriptService.server.Modux)
local Content = require(ReplicatedStorage.shared.Content)
local Verbose = require(ReplicatedStorage.shared.Verbose)
local Log = require(script.Log)
local Lobby = require(script.Lobby)
local Zones = require(script.Zones)
local AnomalyTypes = require(ServerScriptService.server.ModuxTypes.AnomalyService)

const SECRET = "rometrics_key"
const KEY_ATTRIBUTE = "RoMetricsTestKey" -- ServerStorage attribute, Studio only (place file, never in git)

type Props = Log.Props
type Trace = AnomalyTypes.Trace

const CAUSE_ANOMALY = { anomaly = true, see = true, stare = true } -- LastCause kinds that name an anomaly key
const ACTIVE_MAX = 256 -- RoMetrics string prop limit

local function sessionId(): string
	return string.sub(HttpService:GenerateGUID(false), 1, 8)
end

local function round1(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

const MetricsService = Modux.Service("MetricsService", {
	Require = {
		"NetService",
		"RoundService",
		"AnomalyService",
		"CustomerService",
		"VitalService",
		"UpgradeService",
		"VehicleService",
		"LightService",
		"KitchenService",
		"InteractionService",
		"PartyService",
		"PlaceService",
	},
	Priority = 50,
})

function MetricsService:Setup()
	-- the SDK was initialised
	self.Started = false :: boolean
	-- "Run" progression Start already logged on this server
	self.RunStarted = false :: boolean
	-- last MetricUi accepted (rate limit)
	self.UiAt = {} :: { [Player]: number }
	-- tutorial steps already logged
	self.Tutorial = {} :: { [Player]: { [number]: boolean } }
	-- lobby funnels (lobby servers only, WireLobby)
	self.Lobby = nil :: Lobby.Lobby?
	-- run hot zones (run servers only, WireRunZones)
	self.Zones = nil :: Zones.Zones?
	-- anomaly funnels in progress (WireAnomalies): session id and the steps already logged
	self.Live = {} :: { [Trace]: { Session: string, Steps: { [number]: boolean } } }
	-- ProductId -> Content.Shop key
	self.ProductKeys = {} :: { [number]: string }
	for _, list in { Content.Shop.GemPacks.List :: { any }, Content.Shop.Utilities.List :: { any } } do
		for _, row in list do
			if type(row.ProductId) == "number" then
				self.ProductKeys[row.ProductId] = row.Key
			end
		end
	end
end

function MetricsService:Init()
	const okSecret, secret = pcall(function(): any
		return HttpService:GetSecret(SECRET)
	end)
	const studio = RunService:IsStudio()
	local key: any = nil
	if okSecret then
		key = secret
	elseif studio then
		const test = ServerStorage:GetAttribute(KEY_ATTRIBUTE)
		key = if type(test) == "string" and test ~= "" then test else nil
	end
	if key == nil then
		if studio and Verbose.On() then
			print(`[MetricsService] no RoMetrics key (Secret {SECRET} or ServerStorage.{KEY_ATTRIBUTE}): analytics off`)
		end
		return
	end
	Log.SDK.init({
		key = key,
		-- The SDK default (ingest.rometrics.app) does not exist: always point at our ingest.
		endpoint = "https://163-176-111-187.sslip.io",
		enabledInStudio = studio,
		debug = studio and Verbose.On(),
	})
	self.Started = true
	self:DefineFunnels()
end

-- Declared steps of every funnel the game logs (Log.define; each server resends them as it starts). The step names a
-- call logs win over these labels (classes step 3 is "buy" or "equip", anomaly step 4 resolved | failed | cut).
function MetricsService:DefineFunnels()
	Log.define("lobby", { "join", "moved", "zone", "pad_or_play", "start" }) -- Lobby.luau STEP_NAMES
	Log.define("squad", { "created", "room", "joined", "started" })
	Log.define("panel_shop", { "open", "pick", "bought" })
	Log.define("panel_classes", { "open", "pick", "buy" })
	Log.define("panel_codes", { "open", "try", "redeemed" })
	-- onboarding: 1 = began, the milestones, last = completed (TutorialService)
	const onboarding = { "begin" }
	for _, name in Content.Metrics.TutorialFunnel do
		table.insert(onboarding, name)
	end
	table.insert(onboarding, "complete")
	Log.define("Onboarding", onboarding)
	const anomaly = table.clone(Content.Metrics.AnomalyFunnel)
	table.insert(anomaly, "outcome")
	for _, row in Content.Anomalies.List do
		Log.define(`anomaly_{row.Key}`, anomaly)
	end
end

-- Day / Night progression level name ("day_3", "night_2")
local function levelOf(info: { Day: number, Night: number, IsNight: boolean }): (string, number, string)
	if info.IsNight then
		return "Night", info.Night, `night_{info.Night}`
	end
	return "Day", info.Day, `day_{info.Day}`
end

function MetricsService:Members(): { Player }
	return Players:GetPlayers()
end

-- Props of a lost night: the final blow (VitalService LastCause of the last to fall, "kind:key") and the anomalies alive
function MetricsService:LostCause(): Props
	const vital = self.Dependencies.VitalService
	const entry = vital.Entries[vital.LastFallen]
	const cause = if entry ~= nil then entry.LastCause else ""
	const kind, key = string.match(cause, "^(%w+):(.+)$")
	const keys: { string } = {}
	for trace in self.Live do
		table.insert(keys, trace.Key)
	end
	table.sort(keys)
	return {
		cause_kind = kind or cause,
		cause_key = key or "",
		cause_anomaly = if kind ~= nil and key ~= nil and CAUSE_ANOMALY[kind] then key else "",
		active = string.sub(table.concat(keys, ","), 1, ACTIVE_MAX),
	}
end

function MetricsService:WireRound()
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function(info)
		const path, level, name = levelOf(info)
		const props: Props = { attempt = info.Attempt, players = #Players:GetPlayers() }
		for _, player in self:Members() do
			if not self.RunStarted then
				Log.progress(player, "Run", "Start", 1, "run")
			end
			Log.progress(player, path, "Start", level, name, props)
		end
		self.RunStarted = true
		Log.server("shift_start", level, { path = path, day = info.Day, night = info.Night, attempt = info.Attempt })
	end)
	round.ShiftEnded:Connect(function(info)
		if info.IsNight then
			return -- nights end in NightResolved (Won / Lost)
		end
		const _, level, name = levelOf(info)
		for _, player in self:Members() do
			Log.progress(player, "Day", "Complete", level, name)
		end
		Log.server("shift_end", level, { path = "Day", day = info.Day })
	end)
	round.NightResolved:Connect(function(info, result, reason)
		const status: Log.Status = if result == "Won" then "Complete" else "Fail"
		const props: Props = { attempt = info.Attempt, reason = reason or "" }
		const extra: Props = { result = result, reason = reason or "", attempt = info.Attempt }
		if result == "Lost" then
			-- fires before the phase change: the occurrences are still alive and LastCause is intact
			for key, value in self:LostCause() do
				props[key] = value
				extra[key] = value
			end
		end
		for _, player in self:Members() do
			Log.progress(player, "Night", status, info.Night, `night_{info.Night}`, props)
		end
		Log.server("night_result", info.Night, extra)
	end)
	round.RunEnded:Connect(function(result)
		for _, player in self:Members() do
			Log.progress(player, "Run", if result == "Success" then "Complete" else "Fail", 1, "run")
		end
		Log.server("run_end", nil, { result = result })
	end)
end

-- s from the start to Active, -1 when it never got there
local function activeAt(trace: Trace): number
	const at = trace.Marks.Active
	return if at ~= nil then round1(at) else -1
end

-- Connected members of the occurrence's party at its start
function MetricsService:PartyOf(trace: Trace): { Player }
	const list: { Player } = {}
	for _, userId in trace.Party do
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil and player.Parent ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

-- Props every funnel step shares; t = s from the start to that phase
function MetricsService:AnomalyBase(trace: Trace, t: number): Props
	return {
		key = trace.Key,
		night = trace.Night,
		attempt = trace.Attempt,
		party = #trace.Party,
		seconds = round1(workspace:GetServerTimeNow() - trace.StartedAt),
		t = round1(t),
	}
end

-- Funnel anomaly_<key>: step (1 start, 2 signal, 3 active) once per occurrence for each member of the party; an earlier
-- step not seen yet is logged first with filled = true (Lobby.Step pattern). upTo = last step to fill when it is not
-- step itself. Step 4 (the outcome) is per player: AnomalyOutcome
function MetricsService:AnomalyStep(trace: Trace, step: number, upTo: number?)
	const live = self.Live[trace]
	if live == nil then
		return
	end
	const members = self:PartyOf(trace)
	for at = 1, upTo or step do
		if live.Steps[at] then
			continue
		end
		live.Steps[at] = true
		const phase = if at == 2 then "Signal" elseif at == 3 then "Active" else nil
		const props = self:AnomalyBase(trace, if phase ~= nil then trace.Marks[phase] or 0 else 0)
		if at < step then
			props.filled = true
		end
		for _, player in members do
			Log.funnel(player, `anomaly_{trace.Key}`, live.Session, at, Content.Metrics.AnomalyFunnel[at], props)
		end
	end
end

-- Step 4 per player: resolved (Resolved, or survived to the end), failed, or cut (the night ended / was restored in Signal)
function MetricsService:AnomalyOutcome(trace: Trace, phase: string, failed: { Player }, reason: string)
	if self.Live[trace] == nil then
		return
	end
	const live = self.Live[trace]
	const cut = phase == "Signal" and (reason == "Restore" or reason == "NightOver")
	self:AnomalyStep(trace, 3, if cut then 2 else 3)
	const failedSet: { [number]: boolean } = {}
	for _, player in failed do
		failedSet[player.UserId] = true
	end
	const tActive = activeAt(trace)
	const props = self:AnomalyBase(trace, trace.Marks.Active or 0)
	props.reason = reason
	props.failed = #failed
	props.t_active = tActive
	for _, player in self:PartyOf(trace) do
		local result: string
		if failedSet[player.UserId] or phase == "Failed" then
			result = "failed"
		elseif cut then
			result = "cut"
		elseif phase == "Resolved" then
			result = "resolved"
		else
			result = "survived"
		end
		props.result = result
		Log.funnel(player, `anomaly_{trace.Key}`, live.Session, 4, if result == "survived" then "resolved" else result, props)
	end
end

function MetricsService:WireAnomalies()
	const anomaly = self.Dependencies.AnomalyService
	anomaly.Started:Connect(function(key, party, trace)
		self.Live[trace] = { Session = sessionId(), Steps = {} }
		Log.server("anomaly_start", party, {
			key = key,
			night = trace.Night,
			attempt = trace.Attempt,
			party = party,
			seconds = 0,
		})
		self:AnomalyStep(trace, 1)
		if trace.Marks.Signal ~= nil then
			self:AnomalyStep(trace, 2)
		end
		if trace.Marks.Active ~= nil then
			self:AnomalyStep(trace, 3)
		end
	end)
	anomaly.Staged:Connect(function(trace, phase)
		if phase == "Signal" then
			self:AnomalyStep(trace, 2)
		elseif phase == "Active" then
			self:AnomalyStep(trace, 3)
		end
	end)
	anomaly.Outcome:Connect(function(key, phase, failed, party, reason, trace)
		self:AnomalyOutcome(trace, phase, failed, reason)
		const seconds = round1(workspace:GetServerTimeNow() - trace.StartedAt)
		Log.server("anomaly_end", #failed, {
			key = key,
			phase = phase,
			party = party,
			reason = reason,
			night = trace.Night,
			attempt = trace.Attempt,
			seconds = seconds,
			t_active = activeAt(trace),
		})
		for _, player in failed do
			const at = trace.FailedAt[player.UserId]
			Log.player(player, "anomaly_failed", nil, {
				key = key,
				night = trace.Night,
				attempt = trace.Attempt,
				party = party,
				seconds = if at ~= nil then round1(at) else seconds,
			})
		end
		self.Live[trace] = nil
	end)
end

function MetricsService:WireCrew()
	self.Dependencies.CustomerService.Acted:Connect(function(_npc, action, player, result)
		const props: Props = { result = if result ~= nil then result else "" }
		if player ~= nil then
			Log.player(player, `customer_{action}`, nil, props)
		else
			Log.server(`customer_{action}`, nil, props)
		end
	end)
	self.Dependencies.VitalService.MemberStateChanged:Connect(function(userId, from, to)
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			const props: Props = { from = from, to = to }
			if to == "Down" or to == "Spectator" then
				const entry = self.Dependencies.VitalService.Entries[userId]
				props.cause = if entry ~= nil then entry.LastCause else ""
			end
			Log.player(player, "life_state", nil, props)
		end
	end)
end

function MetricsService:WireWorld()
	self.Dependencies.UpgradeService.Changed:Connect(function(key, level, vehicle)
		Log.server("upgrade", level, { key = key, vehicle = vehicle })
	end)
	self.Dependencies.VehicleService.ShutterChanged:Connect(function(closed, player)
		if player ~= nil then
			Log.player(player, "window_toggle", nil, { closed = closed })
		end
	end)
	self.Dependencies.LightService.SwitchChanged:Connect(function(on, player)
		if player ~= nil then
			Log.player(player, "light_switch", nil, { on = on })
		end
	end)
	const kitchen = self.Dependencies.KitchenService
	kitchen.Discarded:Connect(function(player, item, altered, where)
		Log.player(player, "discard", nil, { item = item, altered = altered, where = where })
	end)
	kitchen.Emitted:Connect(function(name, player, data)
		const props: Props = {}
		if data ~= nil then
			for key, value in data do
				const kind = type(value)
				if kind == "string" or kind == "number" or kind == "boolean" then
					props[key] = value
				end
			end
		end
		if player ~= nil then
			Log.player(player, `kitchen_{name}`, nil, props)
		else
			Log.server(`kitchen_{name}`, nil, props)
		end
	end)
	const interaction = self.Dependencies.InteractionService
	interaction.Performed:Connect(function(player, action)
		Log.player(player, "action", nil, { action = action })
	end)
	interaction.Rejected:Connect(function(player, _id, action, reason)
		Log.player(player, "action_refused", nil, { action = action, reason = reason })
	end)
end

-- Onboarding funnel: step 1 = began and the last = completed (TutorialService); milestone i of
-- Content.Metrics.TutorialFunnel = step i + 1. A step key maps to its milestone (TutorialMilestone); a later milestone
-- fills in the earlier ones not seen (passed without the step showing: a mate opened the window, a squad veteran)
function MetricsService:OnTutorialStep(player: Player, index: number)
	const key = Content.Metrics.TutorialSteps[index]
	const milestone = if key then Content.Metrics.TutorialMilestone[key] else nil
	if milestone == nil then
		return
	end
	local seen = self.Tutorial[player]
	if seen == nil then
		seen = {}
		self.Tutorial[player] = seen
	end
	for step = 1, milestone do
		if not seen[step] then
			seen[step] = true
			Log.onboarding(player, step + 1, Content.Metrics.TutorialFunnel[step], { filled = step < milestone })
		end
	end
end

function MetricsService:OnUi(player: Player, event: string, key: string?, offer: string?)
	const now = os.clock()
	const last = self.UiAt[player]
	if last ~= nil and now - last < Content.Metrics.UiRate then
		return
	end
	self.UiAt[player] = now
	local props: { [string]: string }? = nil
	if key ~= nil or offer ~= nil then
		props = { key = key, offer = offer } :: any
	end
	Log.player(player, `ui_{event}`, nil, props)
	const lobby = self.Lobby
	if lobby ~= nil then
		lobby:Ui(player, event)
	end
end

-- Lobby servers: the visit funnel (position polled), the squads and the window funnels
function MetricsService:WireLobby()
	if not self.Dependencies.PlaceService:Is("Lobby") then
		return
	end
	const lobby = Lobby.new()
	self.Lobby = lobby
	Log.SetPanelHook(function(player, panel, step, name, props)
		lobby:Panel(player, panel, step, name, props)
	end)
	Players.PlayerAdded:Connect(function(player)
		lobby:Join(player)
	end)
	for _, player in Players:GetPlayers() do
		lobby:Join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lobby:Leave(player)
	end)
	RunService.Heartbeat:Connect(function()
		lobby:Poll()
	end)
	self.Dependencies.PartyService.Tracked:Connect(function(kind, party, userId, detail)
		lobby:Squad(kind, party, userId, detail)
	end)
end

-- Run servers: hot zones of the restaurant (position polled, only while Active)
function MetricsService:WireRunZones()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	const vehicle = self.Dependencies.VehicleService
	const round = self.Dependencies.RoundService
	const vital = self.Dependencies.VitalService
	const zones = Zones.new({
		InKitchen = function(position)
			return vehicle:IsInsidePoint(position)
		end,
		IsActive = function(player)
			return vital:IsActive(player)
		end,
		Shift = function()
			const _, _, name = levelOf(round:Info())
			return round:GetPhase(), name
		end,
	})
	self.Zones = zones
	Players.PlayerAdded:Connect(function(player)
		zones:Join(player)
	end)
	for _, player in Players:GetPlayers() do
		zones:Join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		zones:Leave(player)
	end)
	vital.MemberStateChanged:Connect(function(userId, _from, to)
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil and to ~= "Active" then
			zones:Rest(player, true)
		end
	end)
	RunService.Heartbeat:Connect(function()
		zones:Poll()
	end)
end

function MetricsService:WireNet()
	const net = self.Libs.Net
	net.MetricUi:onServer(function(value, player)
		if type(value) == "table" and type(value.Event) == "string" then
			self:OnUi(
				player,
				value.Event,
				if type(value.Key) == "string" then value.Key else nil,
				if type(value.Offer) == "string" then value.Offer else nil
			)
		end
	end)
	net.MetricTutorial:onServer(function(value, player)
		if type(value) == "table" and type(value.Step) == "number" then
			self:OnTutorialStep(player, value.Step)
		end
	end)
	-- a product prompt closed without buying (bought ones are counted by the receipt)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, bought: boolean)
		if bought then
			return
		end
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			Log.player(player, "product_prompt_closed", nil, { key = self.ProductKeys[productId] or tostring(productId) })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.UiAt[player] = nil
		self.Tutorial[player] = nil
	end)
end

MetricsService:OnInit(function(self)
	self:Setup()
	self:Init()
	self:WireRound()
	self:WireAnomalies()
	self:WireCrew()
	self:WireWorld()
	self:WireNet()
	self:WireLobby()
	self:WireRunZones()
end)

return MetricsService
