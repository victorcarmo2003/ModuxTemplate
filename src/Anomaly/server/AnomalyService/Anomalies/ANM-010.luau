--!strict
-- ANM-010 The Hush (anomalies.md N10; npcs.md NPC-018; architecture.md §19.6, §19.13, §19.14, §19.17; MAP-01 §10.4;
-- FEAT-020, FEAT-023, FEAT-027; DEC-054, DEC-177, DEC-195, DEC-204; TASK-117). Rule in Rules/ANM-010.luau.
-- Environment anomaly (Actor World, NpcCost 0). The posts going out one by one are LightService + LightController
-- (Lights set: At = start, post Order k out at k x Step); the fog is the client (Effects/ANM-010).
--
--   Start    LightService:BeginHush(start, holdUntil) (posts out from now; trailer LightZones dark from the corner
--            post until the posts come back; the switch has no effect meanwhile in the trailer) + TrafficService:Hold("anm_010"),
--            Phase Active, Step 0.
--   Step     number of posts already out (Order x Step of the juniper_posts group), published while they go out.
--   Corner   the corner post goes out (largest Order x Step, the same moment LightService darkens the trailer; Params
--            PostsOff when no post is bound): every active player outside the safe zone fails (personal target,
--            DEC-204); the others are watched. Safe zone = InZone(player, Point "SS", Radius 6) or inside a LightZone
--            of Params.SafeZones (LZ-4, Mart interior). Any failure -> cue hush_fog (DEC-195 flavour).
--   Hold     corner .. corner + HoldFor: a watched player who leaves the safe zone fails (5 Hz check; first late
--            failure also cues hush_fog).
--   End      the posts come back: EndHush, Phase Failed when anyone failed else Resolved, Finish.
--   Scripted Night 10 at 5:45 AM (Content Scripted, FEAT-027): the posts stay out until 6:00 AM; the hold never ends
--            by itself and the night's end (Stop NightOver) brings them back. Leaving the zone still fails.
--   Seen     1 s in the gaze cone (ViewRange 200) of the last post that went out.
--   Stop     EndHush (only by the occurrence that began it) and the traffic Hold released.
--
-- TASK-490 (restaurant, design/anomalies-v3-restaurant.md, Provisional): no Mart. The posts go out one by one as before
-- but the shop keeps its light and its switch (LightService:BeginHush postsOnly); safe = the shop light switched OFF at
-- the corner post and kept off until the posts come back (on again for OutGrace s = every watched player fails).
-- TASK-592 (owner 2026-10-19, PROVISIONAL Q-398): (a) the shop switch works during the Hush (LightService CanToggle
-- only refuses a full Hush; here it is postsOnly) and the rule reads it (safe = IsSwitchOn false); (b) the window no
-- longer slams shut by itself (Content.ShopWindow anm_010_hush = None); (c) the head: at HeadAt s, with the service
-- window open, it pushes its head in through it and looks (record Anchor HEAD_IN) for HeadFor s, then pulls out
-- (HEAD_OUT; also when someone shuts the window on it). The shop lit at that moment, or switched on while the head is in,
-- = every active player fails at once (jumpscare + faint, no OutGrace). Window shut at HeadAt = it bumps the shutter
-- (HEAD_GLASS), nothing else.
-- TASK-334 (owner 2026-10-15, Provisional): the owner died "with a lot of doors opening and closing": those were the
-- Mart's automatic doors (DoorController AutoDoor, proximity) swinging while he stood in the doorway, half in and half
-- out of the safe zone, so a 5 Hz tick caught him "outside" during the hold. Now: (a) a watched player fails only after
-- OutGrace s outside in a row; (b) the safe radius around SS is wider (Rules Params); (c) the error is the V2 one,
-- jumpscare + faint (cue jumpscare, Entity = UserId % 65536; ScareFaint s later VitalService:Fall), no -RuleBroken;
-- (d) the client warns clearly at the start (Walt on the radio, "RUN TO THE MART" and the guide arrow, Effects/ANM-010).
-- PROVISIONAL (backend-coder, TASK-117): (a) safe zone also = the Mart interior LZ-4 (tests/wave-3.md L3-12, npcs.md
-- N10 proposal); (b) "scripted" = started on Content.Anomalies Scripted.Night at or after Scripted.Clock, read from
-- RoundService looked up by name (the module Context has no clock); (c) the safe zone at the corner post counts
-- players in the zone at that tick (5 Hz, +-0.2 s).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Zones = require(ReplicatedStorage.shared.Light.Zones)
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const REF = "ANM-010"
const HOLD_REASON = "anm_010"
const POST_TAG = "StreetLight"
const MAX_DT = 0.5 -- s; a late tick never counts more than this
const SCRIPTED_SLACK = 1 -- game minutes before Scripted.Clock that still count as the scripted start
-- Defaults when Rules/ANM-010 is missing (same numbers as the rule file)
const DEFAULT_POSTS_OFF = 15
const DEFAULT_HOLD_FOR = 20
const DEFAULT_POINT = "SS"
const DEFAULT_RADIUS = 10
const DEFAULT_OUT_GRACE = 2
const DEFAULT_SCARE_FAINT = 0.7
const DEFAULT_HEAD_AT = 25.5
const DEFAULT_HEAD_FOR = 6
-- record Anchor of the head (Effects/ANM-010; TASK-592)
const HEAD_IN = 1
const HEAD_GLASS = 2
const HEAD_OUT = 3
const SCARE_CUE = "jumpscare"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity is 0..65535

type Stage = "Going" | "Holding"
type Head = "Waiting" | "In" | "Done"

type State = {
	Stage: Stage,
	Scripted: boolean,
	Step: number, -- seconds per post
	Posts: { [number]: Vector3 }, -- Order -> lamp head
	MaxOrder: number,
	Count: number, -- posts out (published Step)
	DarkAt: number,
	HoldUntil: number, -- 0 = until the night ends (scripted)
	Point: string,
	Radius: number,
	SafeZones: { Zones.Zone },
	ZoneMargin: number, -- studs of slack around each safe box zone
	Range: number,
	Watched: { [number]: Player },
	OutSince: { [number]: number }, -- watched player outside the safe zone since (server time)
	OutGrace: number,
	ScareFaint: number,
	Failed: { [number]: boolean },
	AnyFailed: boolean,
	Flavoured: boolean,
	Held: boolean,
	LastTick: number,
	-- TASK-592: the head through the window
	Head: Head,
	HeadAt: number,
	HeadFor: number,
	HeadUntil: number,
}

-- The occurrence that began the current Hush (only it ends it) and live traffic Holds of this module
local hushOwner: Api.Occurrence? = nil
local holds = 0

local function param(rule: Api.Rule?, name: string, default: number): number
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then value else default
end

local function text(rule: Api.Rule?, name: string, default: string): string
	if rule == nil then
		return default
	end
	const value = rule.Params[name]
	return if type(value) == "string" and value ~= "" then value else default
end

-- Posts groups the Hush puts out (Content.LightGroups Kind Posts, HushOff): key -> Step
local function postGroups(): { [string]: number }
	const out: { [string]: number } = {}
	for _, group in Content.LightGroups.List do
		if group.Kind == "Posts" and group.HushOff and group.Step > 0 then
			out[group.Key] = group.Step
		end
	end
	return out
end

-- Lamp heads by Order and the corner delay LightService uses (largest Order x Step). nil delay = no post bound.
local function posts(): ({ [number]: Vector3 }, number, number, number?)
	const groups = postGroups()
	const out: { [number]: Vector3 } = {}
	local maxOrder = 0
	local step = 0
	local delay: number? = nil
	for _, instance in CollectionService:GetTagged(POST_TAG) do
		if not instance:IsDescendantOf(workspace) then
			continue
		end
		const groupStep = groups[instance:GetAttribute("Group") :: any]
		const order = instance:GetAttribute("Order")
		if groupStep == nil or type(order) ~= "number" or order < 1 then
			continue
		end
		local head: Vector3? = nil
		if instance:IsA("Model") then
			const box, size = instance:GetBoundingBox()
			head = box.Position + Vector3.new(0, size.Y / 2, 0)
		elseif instance:IsA("BasePart") then
			head = instance.Position + Vector3.new(0, instance.Size.Y / 2, 0)
		end
		if head ~= nil and out[order] == nil then
			out[order] = head
		end
		if order > maxOrder then
			maxOrder = order
			step = groupStep
		end
		delay = math.max(delay or 0, order * groupStep)
	end
	return out, maxOrder, step, delay
end

-- LightZone volumes of the given ZoneIds (Mart interior).
local function safeZones(ids: { string }): { Zones.Zone }
	const out: { Zones.Zone } = {}
	if #ids == 0 then
		return out
	end
	for _, instance in CollectionService:GetTagged(Zones.Tag) do
		if not instance:IsDescendantOf(workspace) or table.find(ids, instance:GetAttribute("ZoneId") :: any) == nil then
			continue
		end
		const zone = Zones.read(instance)
		if zone ~= nil then
			table.insert(out, zone)
		end
	end
	return out
end

local function zoneIds(rule: Api.Rule?): { string }
	const out: { string } = {}
	const value = if rule ~= nil then rule.Params.SafeZones else nil
	if type(value) == "table" then
		for _, id in value :: { any } do
			if type(id) == "string" then
				table.insert(out, id)
			end
		end
	end
	return out
end

-- Live RoundService (looked up by name: the module Context has no clock). nil when absent.
local roundCache: any = nil
local function round(): any
	if roundCache ~= nil then
		return roundCache
	end
	const ok, modules = pcall(function()
		return (require :: any)(ServerScriptService.server.Modux.Modules)
	end)
	if not ok or type(modules) ~= "table" then
		return nil
	end
	for _, module in modules do
		if typeof(module) == "Instance" and module.Name == "RoundService" then
			const found, service = pcall((require :: any), module)
			if found then
				roundCache = service
			end
			break
		end
	end
	return roundCache
end

-- Scripted occurrence (FEAT-027): started on Scripted.Night at or after Scripted.Clock.
local function isScripted(key: string): boolean
	const row = Content.Anomalies.ByKey[key]
	const scripted = if row ~= nil then row.Scripted else nil
	const service = round()
	if scripted == nil or service == nil then
		return false
	end
	const ok, night, minutes = pcall(function()
		return service:GetNight(), service:Minutes()
	end)
	return ok and night == scripted.Night and type(minutes) == "number" and minutes >= scripted.Clock - SCRIPTED_SLACK
end

local function setHold(ctx: Api.Context, state: State, on: boolean)
	if state.Held == on then
		return
	end
	state.Held = on
	holds = math.max(0, holds + (if on then 1 else -1))
	if on and holds == 1 then
		ctx.Traffic.Hold(HOLD_REASON, true)
	elseif not on and holds == 0 then
		ctx.Traffic.Hold(HOLD_REASON, false)
	end
end

local function rootOf(player: Player): BasePart?
	const character = player.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function safe(ctx: Api.Context, state: State, player: Player): boolean
	-- design/anomalies-v3-restaurant.md ANM-010: the answer is the shop dark (LIGHT off) and kept off
	return not ctx.Light.IsSwitchOn()
end

local function fail(ctx: Api.Context, occ: Api.Occurrence, state: State, players: { Player })
	const list: { Player } = {}
	for _, player in players do
		const userId = player.UserId
		state.Watched[userId] = nil
		if not state.Failed[userId] then
			state.Failed[userId] = true
			table.insert(list, player)
		end
	end
	if #list == 0 then
		return
	end
	state.AnyFailed = true
	for _, player in list do
		ctx.Cue(occ, SCARE_CUE, player.UserId % ENTITY_MOD, player.UserId)
	end
	task.delay(state.ScareFaint, function()
		for _, player in list do
			if player.Parent ~= nil then
				Kit.Vital():Fall(player)
			end
		end
	end)
	if not state.Flavoured then
		state.Flavoured = true
		ctx.Cue(occ, "hush_fog", 0)
	end
end

-- TASK-592: the head through the window. The shop lit while it looks in = everyone active fails at once.
local function head(ctx: Api.Context, occ: Api.Occurrence, state: State, now: number)
	if state.Head == "Waiting" then
		if now < state.HeadAt then
			return
		end
		if ctx.Vehicle.IsShutterClosed() then
			state.Head = "Done"
			ctx.Publish(occ, { Anchor = HEAD_GLASS })
			return
		end
		state.Head = "In"
		state.HeadUntil = now + state.HeadFor
		ctx.Publish(occ, { Anchor = HEAD_IN })
	end
	if state.Head ~= "In" then
		return
	end
	if now >= state.HeadUntil or ctx.Vehicle.IsShutterClosed() then
		state.Head = "Done"
		ctx.Publish(occ, { Anchor = HEAD_OUT })
		return
	end
	if ctx.Light.IsSwitchOn() then
		fail(ctx, occ, state, ctx.Active())
	end
end

-- The corner post is out: test every active player.
local function corner(ctx: Api.Context, occ: Api.Occurrence, state: State)
	state.Stage = "Holding"
	const outside: { Player } = {}
	for _, player in ctx.Active() do
		if safe(ctx, state, player) then
			state.Watched[player.UserId] = player
		else
			table.insert(outside, player)
		end
	end
	fail(ctx, occ, state, outside)
end

const Hush: Api.Module = {
	Ref = REF,

	Start = function(ctx: Api.Context, occ: Api.Occurrence): boolean
		const rule = ctx.Rule(REF)
		const row = Content.Anomalies.ByKey[occ.Key]
		const found, maxOrder, step, delay = posts()
		const darkAt = occ.StartedAt + (delay or param(rule, "PostsOff", DEFAULT_POSTS_OFF))
		const scripted = isScripted(occ.Key)
		const holdUntil = if scripted then 0 else darkAt + param(rule, "HoldFor", DEFAULT_HOLD_FOR)
		const state: State = {
			Stage = "Going",
			Scripted = scripted,
			Step = step,
			Posts = found,
			MaxOrder = maxOrder,
			Count = 0,
			DarkAt = darkAt,
			HoldUntil = holdUntil,
			Point = text(rule, "Point", DEFAULT_POINT),
			Radius = param(rule, "Radius", DEFAULT_RADIUS),
			SafeZones = safeZones(zoneIds(rule)),
			ZoneMargin = if rule ~= nil and type(rule.Params.ZoneMargin) == "number" then rule.Params.ZoneMargin else 0,
			Range = if row ~= nil then row.ViewRange else 0,
			Watched = {},
			OutSince = {},
			OutGrace = param(rule, "OutGrace", DEFAULT_OUT_GRACE),
			ScareFaint = param(rule, "ScareFaint", DEFAULT_SCARE_FAINT),
			Failed = {},
			AnyFailed = false,
			Flavoured = false,
			Held = false,
			LastTick = occ.StartedAt,
			Head = "Waiting",
			HeadAt = occ.StartedAt + param(rule, "HeadAt", DEFAULT_HEAD_AT),
			HeadFor = param(rule, "HeadFor", DEFAULT_HEAD_FOR),
			HeadUntil = 0,
		}
		occ.State = state
		if delay == nil then
			ctx.Log(occ, "no juniper_posts StreetLight bound: corner post at PostsOff s, no Step")
		end
		ctx.Light.BeginHush(occ.StartedAt, holdUntil, true)
		hushOwner = occ
		setHold(ctx, state, true)
		ctx.Publish(occ, { Phase = "Active", Step = 0, Anchor = 0 })
		return true
	end,

	Tick = function(ctx: Api.Context, occ: Api.Occurrence, now: number)
		const state = occ.State :: State
		const dt = math.clamp(now - state.LastTick, 0, MAX_DT)
		state.LastTick = now

		if state.Step > 0 and state.Count < state.MaxOrder then
			const count = math.clamp(math.floor((now - occ.StartedAt) / state.Step), 0, state.MaxOrder)
			if count ~= state.Count then
				state.Count = count
				ctx.Publish(occ, { Step = count })
			end
		end
		const target = state.Posts[math.max(1, state.Count)]
		if target ~= nil and state.Range > 0 then
			ctx.SeenTick(occ, target, state.Range, dt)
		end

		head(ctx, occ, state, now)

		if state.Stage == "Going" then
			if now >= state.DarkAt then
				corner(ctx, occ, state)
			end
			return
		end

		-- Holding: a watched player who stays out of the safe zone OutGrace s in a row (or is no longer active) fails
		const left: { Player } = {}
		for userId, player in state.Watched do
			if player.Parent ~= Players then
				state.Watched[userId] = nil
			elseif safe(ctx, state, player) then
				state.OutSince[userId] = nil
			else
				const since = state.OutSince[userId] or now
				state.OutSince[userId] = since
				if now - since >= state.OutGrace then
					table.insert(left, player)
				end
			end
		end
		fail(ctx, occ, state, left)

		if state.HoldUntil > 0 and now >= state.HoldUntil then
			if hushOwner == occ then
				hushOwner = nil
				ctx.Light.EndHush()
			end
			ctx.Publish(occ, { Phase = if state.AnyFailed then "Failed" else "Resolved" })
			ctx.Finish(occ)
		end
	end,

	Stop = function(ctx: Api.Context, occ: Api.Occurrence, _reason: Api.StopReason)
		if hushOwner == occ then
			hushOwner = nil
			ctx.Light.EndHush()
		end
		const state = occ.State :: State?
		if state ~= nil then
			setHold(ctx, state, false)
		end
		occ.State = nil
	end,
}

return Hush
