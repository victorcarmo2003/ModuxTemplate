--!strict
-- Lobby analytics (owner request 2026-10-17, Provisional): precise funnels of the lobby and its windows, nothing like
-- "clicked play". Lobby servers only; MetricsService builds one with Lobby.new(log) and feeds it. Server side, from the
-- HumanoidRootPart and the squad record (the client only reports windows it opens and prompts it shows, MetricUi).
--   funnel "lobby"     (session = one lobby visit) 1 join -> 2 moved (MOVED studs from the first position) ->
--                      3 zone (reached any zone) -> 4 pad_or_play (stepped on a squad pad or opened the Play choice) ->
--                      5 start (the countdown ended: the run begins)
--   lobby_zone_enter   first entry in each zone of the visit {zone, t = s since join}
--   lobby_dwell        on leave, s spent per zone (value) {zone}; "street" = no zone: hot / cold spots
--   Zone:lobby.<zone>  each zone change, street included, and the zone at entry {t = s since join} (hot zones card); the
--                      entry zone goes out on the first poll with a HumanoidRootPart after the join delay
--   lobby_leave        on leave {played, seconds, moved, zones}; played = false is "left the lobby without playing"
--   lobby_start        the countdown ended {mode = solo | squad, size, seconds = s since join, first = first of the visit}
--   funnel "squad"     (session = the squad) 1 created -> 2 room (left "Setup") -> 3 joined (a 2nd player:
--                      {how = pad | invite}) -> 4 started (with 2+); squad_abandon when it ends before {stage, members, seconds}
--   funnel "panel_shop" / "panel_classes" / "panel_codes" (session = one opening) 1 open -> 2 pick (a gem pack
--                      prompted / a class looked at / a code typed and sent) -> 3 done (bought / equipped or bought /
--                      redeemed)
-- Joined players that followed a friend into the server are tagged on the join step {followed = true}.
-- POLL / MOVED are Provisional (docs/tasks/playtest-2026-10-17.md).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local Verbose = require(ReplicatedStorage.shared.Verbose)
local RawLog = require(script.Parent.Log)

-- Log with a trace in the Output (Workspace VerboseLogs, Studio checks; 2026-10-17)
const Log = {
	funnel = function(player: Player, funnel: string, session: string?, step: number, name: string?, props: RawLog.Props?)
		Verbose.print(`[MetricsLobby] {player.Name} {funnel} #{step} {name or ""}`)
		RawLog.funnel(player, funnel, session, step, name, props)
	end,
	player = function(player: Player, name: string, value: number?, props: RawLog.Props?)
		Verbose.print(`[MetricsLobby] {player.Name} {name} {value or ""}`)
		RawLog.player(player, name, value, props)
	end,
	server = function(name: string, value: number?, props: RawLog.Props?)
		Verbose.print(`[MetricsLobby] server {name} {value or ""}`)
		RawLog.server(name, value, props)
	end,
}
type Props = RawLog.Props

const JOIN_DELAY = 2 -- s: the SDK opens the player's session on PlayerAdded too; a funnel step before it is dropped
const POLL = 0.5 -- s between two position reads per player
const MOVED = 8 -- studs from the first position = "moved"
const STREET = "street"
const PANEL_TIME = 300 -- s an opened window still owns the next pick / done (a prompt left open, a slow purchase)

const STEP_NAMES: { [number]: string } = { "join", "moved", "zone", "pad_or_play", "start" }

-- LobbyZones keys -> analytics names
const ZONE_NAME: { [string]: string } = {
	Classes = "classes",
	Shop = "gem_shop",
	Codes = "codes",
}

-- MetricUi event -> panel funnel it opens
const PANEL_OF_OPEN: { [string]: string } = {
	lobby_shop_open = "shop",
	lobby_classes_open = "classes",
	lobby_codes_open = "codes",
}

type Visit = {
	Session: string,
	JoinedAt: number,
	From: Vector3?,
	Moved: boolean,
	Steps: { [number]: boolean },
	Zone: string, -- current zone name, STREET when none
	ZoneSince: number,
	Dwell: { [string]: number },
	Seen: { [string]: boolean },
	InZone: { [string]: boolean }, -- LobbyZones key -> inside (hysteresis)
	Started: boolean,
	ZoneLogged: boolean, -- Zone:lobby.<zone> of the first position already sent
}

type Panel = { Name: string, Session: string, At: number, Step: number }

type Squad = { Session: string, CreatedAt: number, Stage: number, Leader: number, Solo: boolean, Fired: boolean }

local function sessionId(): string
	return string.sub(HttpService:GenerateGUID(false), 1, 8)
end

local function playerOf(userId: number): Player?
	const player = Players:GetPlayerByUserId(userId)
	return if player ~= nil and player.Parent ~= nil then player else nil
end

local function zoneName(zone: LobbyZones.Zone): string
	if zone.Platform > 0 then
		return "pad"
	end
	return ZONE_NAME[zone.Key] or string.lower(zone.Key)
end

-- Hot zones card (RoMetrics "Zone:<name>", owner 2026-10-21): every zone the player is in, street included, so the last
-- one before leaving is where they left the game
local function logZone(player: Player, name: string, t: number)
	Log.player(player, `Zone:lobby.{name}`, nil, { t = math.floor(t) })
end

const Lobby = {}
Lobby.__index = Lobby

export type Lobby = typeof(setmetatable(
	{} :: {
		Visits: { [Player]: Visit },
		Panels: { [Player]: Panel },
		Squads: { [number]: Squad },
		PollAt: number,
	},
	Lobby
))

function Lobby.new(): Lobby
	return setmetatable({
		Visits = {},
		Panels = {},
		Squads = {},
		PollAt = 0,
	}, Lobby)
end

-- Visit -------------------------------------------------------------------------------------------------------------

function Lobby.Step(self: Lobby, player: Player, step: number, name: string, props: Props?)
	const visit = self.Visits[player]
	if visit == nil or visit.Steps[step] then
		return
	end
	-- a later step implies the earlier ones (a zone without a recorded move: spawned next to it)
	for earlier = 2, step - 1 do
		if not visit.Steps[earlier] then
			visit.Steps[earlier] = true
			Log.funnel(player, "lobby", visit.Session, earlier, STEP_NAMES[earlier])
		end
	end
	visit.Steps[step] = true
	Log.funnel(player, "lobby", visit.Session, step, name, props)
end

function Lobby.Join(self: Lobby, player: Player)
	const now = os.clock()
	self.Visits[player] = {
		Session = sessionId(),
		JoinedAt = now,
		From = nil,
		Moved = false,
		Steps = {},
		Zone = STREET,
		ZoneSince = now,
		Dwell = {},
		Seen = {},
		InZone = {},
		Started = false,
		ZoneLogged = false,
	}
	const visit = self.Visits[player]
	visit.Steps[1] = true
	task.delay(JOIN_DELAY, function()
		if self.Visits[player] == visit then
			Log.funnel(player, "lobby", visit.Session, 1, "join", { followed = player.FollowUserId ~= 0 })
		end
	end)
end

function Lobby.SetZone(self: Lobby, player: Player, visit: Visit, name: string, now: number)
	if visit.Zone == name then
		return
	end
	visit.Dwell[visit.Zone] = (visit.Dwell[visit.Zone] or 0) + (now - visit.ZoneSince)
	visit.Zone = name
	visit.ZoneSince = now
	visit.ZoneLogged = true
	logZone(player, name, now - visit.JoinedAt)
	if name == STREET then
		return
	end
	if not visit.Seen[name] then
		visit.Seen[name] = true
		Log.player(player, "lobby_zone_enter", nil, { zone = name, t = math.floor(now - visit.JoinedAt) })
	end
	self:Step(player, 3, "zone")
	if name == "pad" then
		self:Step(player, 4, "pad_or_play", { via = "pad" })
	end
end

function Lobby.Poll(self: Lobby)
	const now = os.clock()
	if now < self.PollAt then
		return
	end
	self.PollAt = now + POLL
	const zones = LobbyZones.List()
	for player, visit in self.Visits do
		if now - visit.JoinedAt < JOIN_DELAY + POLL then
			continue -- the join step goes first
		end
		const character = player.Character
		const root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root == nil then
			continue
		end
		const position = root.Position
		if visit.From == nil then
			visit.From = position
		elseif not visit.Moved and (position - (visit.From :: Vector3)).Magnitude >= MOVED then
			visit.Moved = true
			self:Step(player, 2, "moved", { t = math.floor(now - visit.JoinedAt) })
		end
		local inside: string? = nil
		for _, zone in zones do
			const was = visit.InZone[zone.Key] == true
			const isIn = LobbyZones.Inside(zone, position, was)
			visit.InZone[zone.Key] = isIn
			if isIn and inside == nil then
				inside = zoneName(zone)
			end
		end
		self:SetZone(player, visit, inside or STREET, now)
		if not visit.ZoneLogged then
			-- the zone at entry: the first read with a character after the join delay (not "street" before it loads)
			visit.ZoneLogged = true
			logZone(player, visit.Zone, now - visit.JoinedAt)
		end
	end
end

function Lobby.Leave(self: Lobby, player: Player)
	const visit = self.Visits[player]
	self.Visits[player] = nil
	self.Panels[player] = nil
	if visit == nil then
		return
	end
	const now = os.clock()
	visit.Dwell[visit.Zone] = (visit.Dwell[visit.Zone] or 0) + (now - visit.ZoneSince)
	for zone, seconds in visit.Dwell do
		if seconds >= 1 then
			Log.player(player, "lobby_dwell", math.floor(seconds), { zone = zone })
		end
	end
	local zones = 0
	for _ in visit.Seen do
		zones += 1
	end
	Log.player(player, "lobby_leave", nil, {
		played = visit.Started,
		seconds = math.floor(now - visit.JoinedAt),
		moved = visit.Moved,
		zones = zones,
	})
end

-- The Play choice opened (the button outside a squad): step 4 without a pad
function Lobby.PlayOpened(self: Lobby, player: Player)
	self:Step(player, 4, "pad_or_play", { via = "play" })
end

-- Panels --------------------------------------------------------------------------------------------------------------

-- MetricUi events of the lobby windows (already rate limited)
function Lobby.Ui(self: Lobby, player: Player, event: string)
	if event == "lobby_play_open" then
		self:PlayOpened(player)
		return
	end
	const panel = PANEL_OF_OPEN[event]
	if panel ~= nil then
		const session = sessionId()
		self.Panels[player] = { Name = panel, Session = session, At = os.clock(), Step = 1 }
		Log.funnel(player, `panel_{panel}`, session, 1, "open")
	elseif event == "lobby_gem_prompt" then
		self:Panel(player, "shop", 2, "pick")
	elseif event == "lobby_class_pick" then
		self:Panel(player, "classes", 2, "pick")
	end
end

-- Step of the open panel funnel (server acts too: bought, equipped, code tried / redeemed). Out of order steps are
-- filled in (a class equipped without browsing = pick + done).
function Lobby.Panel(self: Lobby, player: Player, panel: string, step: number, name: string, props: Props?)
	const open = self.Panels[player]
	if open == nil or open.Name ~= panel or os.clock() - open.At > PANEL_TIME or step <= open.Step then
		return
	end
	if step == 3 and open.Step < 2 then
		Log.funnel(player, `panel_{panel}`, open.Session, 2, "pick")
	end
	open.Step = step
	Log.funnel(player, `panel_{panel}`, open.Session, step, name, props)
end

-- Squads --------------------------------------------------------------------------------------------------------------

function Lobby.SquadLog(_self: Lobby, squad: Squad, step: number, name: string, props: Props?)
	const player = playerOf(squad.Leader)
	if player ~= nil then
		Log.funnel(player, "squad", squad.Session, step, name, props)
	else
		Log.server(`squad_{name}`, step, props)
	end
end

-- PartyService.Tracked (kind, party, userId, detail)
function Lobby.Squad(self: Lobby, kind: string, party: any, userId: number, detail: string)
	const id = party.Id :: number
	if kind == "Created" then
		const squad: Squad = {
			Session = sessionId(),
			CreatedAt = os.clock(),
			Stage = 0,
			Leader = userId,
			Solo = false,
			Fired = false,
		}
		self.Squads[id] = squad
		-- a solo quick play is flagged right after Create (same thread): wait one step before counting it as a squad
		task.defer(function()
			if party.Solo then
				squad.Solo = true
				return
			end
			if self.Squads[id] == squad then
				squad.Stage = 1
				self:SquadLog(squad, 1, "created", { platform = party.Platform > 0 })
			end
		end)
		return
	end
	const squad = self.Squads[id]
	if kind == "Fired" then
		const solo = detail == "solo" or #party.Members <= 1
		for _, member in party.Members do
			const player = playerOf(member)
			const visit = if player then self.Visits[player] else nil
			if player ~= nil and visit ~= nil then
				const first = not visit.Started
				visit.Started = true
				self:Step(player, 5, "start", { mode = if solo then "solo" else "squad" })
				Log.player(player, "lobby_start", nil, {
					mode = if solo then "solo" else "squad",
					size = #party.Members,
					seconds = math.floor(os.clock() - visit.JoinedAt),
					first = first,
				})
			end
		end
		if squad ~= nil then
			squad.Fired = true -- off to the run: never an abandon
		end
		if squad ~= nil and not squad.Solo and #party.Members >= 2 and squad.Stage >= 1 and squad.Stage < 4 then
			squad.Stage = 4
			self:SquadLog(squad, 4, "started", { size = #party.Members })
		end
		return
	end
	if squad == nil or squad.Solo then
		if kind == "Disbanded" then
			self.Squads[id] = nil
		end
		return
	end
	if kind == "Configured" and squad.Stage == 1 then
		squad.Stage = 2
		self:SquadLog(squad, 2, "room", { access = detail })
	elseif kind == "Joined" and squad.Stage >= 1 and squad.Stage < 3 and #party.Members >= 2 then
		if squad.Stage < 2 then
			self:SquadLog(squad, 2, "room", { access = party.Access })
		end
		squad.Stage = 3
		self:SquadLog(squad, 3, "joined", { how = detail })
	elseif kind == "Left" and party.Leader == userId then
		squad.Leader = party.Members[1] or userId -- the next leader carries the funnel
	elseif kind == "Disbanded" then
		self.Squads[id] = nil
		if squad.Stage >= 1 and not squad.Fired then
			const player = playerOf(squad.Leader)
			const props = {
				stage = squad.Stage,
				members = #party.Members,
				seconds = math.floor(os.clock() - squad.CreatedAt),
			}
			if player ~= nil then
				Log.player(player, "squad_abandon", nil, props)
			else
				Log.server("squad_abandon", nil, props)
			end
		end
	end
end

return Lobby
