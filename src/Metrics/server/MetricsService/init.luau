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
	  anomaly      anomaly_start / anomaly_end (key, phase, failed, party, reason) (AnomalyService)
	  customer     customer_take_order / serve / refuse / give_up with the sale result (CustomerService.Acted)
	  life         life_state from -> to (faint, revive, spectator) per player (VitalService)
	  prep         prep_enter / prep_leave (reason) and every graded or refused prep act (PrepService.Replied)
	  world        window_toggle, light_switch, discard, kitchen events, upgrades, every validated or refused action
	  shop / ui    client UI moments (MetricUi: shop/settings opened, purchase prompts) and prompts closed unbought
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

const SECRET = "rometrics_key"
const KEY_ATTRIBUTE = "RoMetricsTestKey" -- ServerStorage attribute, Studio only (place file, never in git)
const SKIP_PREP_ACTS: { [string]: boolean } = { Tab = true } -- the keep-alive, not a player action

type Props = Log.Props

const MetricsService = Modux.Service("MetricsService", {
	Require = {
		"NetService",
		"RoundService",
		"AnomalyService",
		"CustomerService",
		"VitalService",
		"PrepService",
		"UpgradeService",
		"VehicleService",
		"LightService",
		"KitchenService",
		"InteractionService",
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
		for _, player in self:Members() do
			Log.progress(player, "Night", status, info.Night, `night_{info.Night}`, props)
		end
		Log.server("night_result", info.Night, { result = result, reason = reason or "", attempt = info.Attempt })
	end)
	round.RunEnded:Connect(function(result)
		for _, player in self:Members() do
			Log.progress(player, "Run", if result == "Success" then "Complete" else "Fail", 1, "run")
		end
		Log.server("run_end", nil, { result = result })
	end)
end

function MetricsService:WireAnomalies()
	const anomaly = self.Dependencies.AnomalyService
	anomaly.Started:Connect(function(key, party)
		Log.server("anomaly_start", party, { key = key })
	end)
	anomaly.Outcome:Connect(function(key, phase, failed, party, reason)
		Log.server("anomaly_end", #failed, { key = key, phase = phase, party = party, reason = reason })
		for _, player in failed do
			Log.player(player, "anomaly_failed", nil, { key = key })
		end
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
			Log.player(player, "life_state", nil, { from = from, to = to })
		end
	end)
	const prep = self.Dependencies.PrepService
	prep.Entered:Connect(function(player, station)
		Log.player(player, "prep_enter", station)
	end)
	prep.Left:Connect(function(player, station, reason)
		Log.player(player, "prep_leave", station, { reason = reason })
	end)
	prep.Replied:Connect(function(player, act, ok, reason, grade, value)
		if SKIP_PREP_ACTS[act] then
			return
		end
		Log.player(player, `prep_{string.lower(act)}`, value, { ok = ok, reason = reason, grade = grade or "None" })
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

-- Onboarding funnel: step 1 = began and the last = completed (TutorialService); Content.Metrics.TutorialSteps[i] = i + 1
function MetricsService:OnTutorialStep(player: Player, index: number)
	const name = Content.Metrics.TutorialSteps[index]
	if name == nil then
		return
	end
	local seen = self.Tutorial[player]
	if seen == nil then
		seen = {}
		self.Tutorial[player] = seen
	end
	if seen[index] then
		return
	end
	seen[index] = true
	Log.onboarding(player, index + 1, name)
end

function MetricsService:OnUi(player: Player, event: string, key: string?)
	const now = os.clock()
	const last = self.UiAt[player]
	if last ~= nil and now - last < Content.Metrics.UiRate then
		return
	end
	self.UiAt[player] = now
	Log.player(player, `ui_{event}`, nil, if key ~= nil then { key = key } else nil)
end

function MetricsService:WireNet()
	const net = self.Libs.Net
	net.MetricUi:onServer(function(value, player)
		if type(value) == "table" and type(value.Event) == "string" then
			self:OnUi(player, value.Event, if type(value.Key) == "string" then value.Key else nil)
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
end)

return MetricsService
