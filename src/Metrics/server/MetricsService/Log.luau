--!strict
-- Log: the only door to the RoMetrics SDK (owner request 2026-10-16; SDK 0.3.0 reference). Server only. Plain module,
-- no Modux: services with a higher priority than MetricsService (Economy, Class, Codes, Reward, Shop) require it by
-- path and log right where the change happens. Calls before MetricsService ran RoMetrics.init are ignored by the SDK
-- itself, and no SDK call ever throws, so nothing here needs pcall.
-- Names follow the SDK rule ^[A-Za-z0-9_.:-]{1,64}$ (snake_case); props are flat primitives only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoMetrics = require(ReplicatedStorage.Packages.RoMetrics) :: any

export type Props = { [string]: string | number | boolean }
export type Flow = "Source" | "Sink"
export type Status = "Start" | "Complete" | "Fail"

const Log = {}

Log.SDK = RoMetrics

-- Custom event of a player (value optional)
function Log.player(player: Player, name: string, value: number?, props: Props?)
	RoMetrics:LogCustomEvent(player, name, value, props)
end

-- Server-level custom event (no player), or with a player when known
function Log.server(name: string, value: number?, props: Props?, player: Player?)
	RoMetrics:track(name, { player = player, value = value, props = props })
end

-- Gems of one player (profile currency). balance = after the change
function Log.gems(player: Player, flow: Flow, amount: number, balance: number, transaction: string, sku: string?, props: Props?)
	if amount <= 0 then
		return
	end
	RoMetrics:LogEconomyEvent(
		player,
		if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
		"Gems",
		amount,
		balance,
		transaction,
		sku,
		props
	)
end

-- Crew Cash (one wallet for the party): an economy event on the player who caused it when known, else a server event
function Log.cash(flow: Flow, amount: number, balance: number, transaction: string, player: Player?, sku: string?)
	if amount <= 0 then
		return
	end
	if player ~= nil and player.Parent ~= nil then
		RoMetrics:LogEconomyEvent(
			player,
			if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Cash",
			amount,
			balance,
			transaction,
			sku
		)
	else
		RoMetrics:track("cash_flow", {
			value = amount,
			props = { flow = flow, kind = transaction, balance = balance, sku = sku or "" },
		})
	end
end

function Log.progress(player: Player, path: string, status: Status, level: number, levelName: string?, props: Props?)
	const kind = if status == "Start"
		then Enum.AnalyticsProgressionType.Start
		elseif status == "Complete" then Enum.AnalyticsProgressionType.Complete
		else Enum.AnalyticsProgressionType.Fail
	RoMetrics:LogProgressionEvent(player, path, kind, level, levelName, props)
end

function Log.funnel(player: Player, funnel: string, session: string?, step: number, stepName: string?, props: Props?)
	RoMetrics:LogFunnelStepEvent(player, funnel, session, step, stepName, props)
end

function Log.onboarding(player: Player, step: number, stepName: string?, props: Props?)
	RoMetrics:LogOnboardingFunnelStepEvent(player, step, stepName, props)
end

-- Step of a lobby window funnel (panel_shop / panel_classes / panel_codes; MetricsService/Lobby.luau owns the session
-- of the open window). Services call it where the act happens (equip, buy, code); nothing outside a lobby server.
local panelHook: ((player: Player, panel: string, step: number, name: string, props: Props?) -> ())? = nil

function Log.panel(player: Player, panel: string, step: number, name: string, props: Props?)
	if panelHook ~= nil then
		panelHook(player, panel, step, name, props)
	end
end

-- MetricsService only (lobby servers)
function Log.SetPanelHook(hook: (player: Player, panel: string, step: number, name: string, props: Props?) -> ())
	panelHook = hook
end

-- A granted developer product (ShopService owns ProcessReceipt): right before returning PurchaseGranted
function Log.receipt(receipt: { [string]: any })
	RoMetrics.trackReceipt(receipt)
end

return table.freeze(Log)
