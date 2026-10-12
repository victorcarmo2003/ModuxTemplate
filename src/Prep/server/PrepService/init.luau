--!strict
-- Focused prep mode, server side (docs/tech/prep-mode.md §2 to §5; DEC-223; TASK-170, P2). Run place only.
-- Single responder of PrepEnter / PrepLeave / PrepTab / PrepGrill / PrepBegin / PrepFinish / PrepTrash / PrepOrder
-- (all in OnInit), single writer of the PrepSeats set (record id = station 1..4) and owner of the prep_work action.
--   Seats        clamp(connected members, 1, Content.Prep.Stations) records, grown on MemberJoined and re-counted on
--                ShiftStarted (never below an occupied seat). Player <-> seat is 1:1; the check and the write are
--                synchronous, so two PrepEnter in the same frame never share a seat.
--   Freeze       CharacterService:Freeze(player, "Prep", true) on entry, released on every exit path (Leave, forced exit,
--                disconnect, Away, Down, ragdoll, faint, knock, phase end). Attribute Working = n on the character.
--   Plate        PrepBegin opens it (KitchenService reserves bun and board slot), PrepFinish validates the summary
--                (Validate.luau: shape, stock, Grade.Plausible on the SERVER clock, Grade.Plate for the band) and runs one
--                atomic transaction through Bridge.Finish; any refusal changes nothing and the plate stays open.
--   Gate         InteractionService gate "Prep": a seated player's world prompts are refused (Prep:Seated).
--   Rates        Content.Prep.Rules.Rates per packet kind plus GLOBAL_RATE per player; excess packets are dropped silently.
--   Forced exit  ForceExit(player, reason) / ForceExitAll(reason), reason = a Content.Prep.Reasons key "Kick*": the
--                AnomalyService (signal), ThiefService, Vital (sanity band) and cutscenes call it; PrepResult Act = Kick.
--                KickSignal also locks re-entry for Rules.CueLock seconds.
-- PrepResult answers failures of Tab (it is also the keep-alive, answered only when refused) and every other act.
-- Provisional: GLOBAL_RATE 6, RANGE_SLACK 2, STAND_LIFT 3 (the Att_Stand of the map is not placed yet, TASK-172).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Bridge = require(script.Bridge)
local Session = require(script.Session)
local Validate = require(script.Validate)
local Modux = require(ServerScriptService.server.Modux)

export type SeatRecord = { User: number, Step: string, Ticket: number, Since: number }

const STATION_TAG = "Station"
const PREP_KIND = "prep"
const WORK_ACTION = "prep_work"
const STAND_ATTACHMENT = "Att_Stand"
-- DEC-224 (Provisional): seats are logical, only two natural prompts exist (the grill and the cutting board). The prompt used
-- says where the player starts (attribute PromptStep on the Prompt_Work attachment) and which stand the rig takes
-- (Att_Stand = grill, Att_Stand_Build = board); the seat itself is the next free one.
const STEP_ATTRIBUTE = "PromptStep"
const VIEW_STAND: { [string]: string } = { Grill = "Att_Stand", Build = "Att_Stand_Build" }
const DEFAULT_STEP = "Grill"
const WORKING_ATTRIBUTE = "Working"
const FREEZE_REASON = "Prep"
const GATE = "Prep"
const GLOBAL_RATE = 6 -- packets per second per player over every Prep packet (TASK-170 acceptance)
const RANGE_SLACK = 2 -- studs added to the prompt radius, like InteractionService
const STAND_LIFT = Vector3.new(0, 3, 0) -- PivotTo above Att_Stand (CharacterService SPAWN_LIFT)
const TICK_RATE = 2 -- Hz: seat timeouts, character state, phase
const MAX_TICKET = 65535
const cfg = Content.Prep
const rules = cfg.Rules
const MAX_STATIONS = cfg.Stations

local function clampStation(value: number): number
	return math.clamp(math.floor(value), 1, MAX_STATIONS)
end

-- Station number of a Station_n Model (attribute Seat, else the name)
local function stationNumber(instance: Instance): number?
	const seat = instance:GetAttribute("Seat")
	if type(seat) == "number" and seat == math.floor(seat) and seat >= 1 and seat <= MAX_STATIONS then
		return seat
	end
	const digits = string.match(instance.Name, "^Station_(%d+)$")
	const number = if digits then tonumber(digits) else nil
	if number ~= nil and number >= 1 and number <= MAX_STATIONS then
		return number
	end
	return nil
end

local function isPrepStation(instance: Instance): boolean
	return CollectionService:HasTag(instance, STATION_TAG) and instance:GetAttribute("StationKind") == PREP_KIND
end

local function freeRecord(): SeatRecord
	return { User = 0, Step = "Order", Ticket = 0, Since = 0 }
end

const PrepService = Modux.Service("PrepService", {
	Require = {
		"PlaceService",
		"NetService",
		"PlayerService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"CharacterService",
		"ItemService",
		"KitchenService",
		"CustomerService",
	},
	Priority = 645,
})

function PrepService:Setup()
	self.Active = false :: boolean
	-- seat records by station (frozen, replaced on every write); the effect of OnStart copies them to the set
	self.Seats = self.Libs.Charm.atom({} :: { [number]: SeatRecord }) :: Charm.Atom<{ [number]: SeatRecord }>
	self.Count = 0 :: number
	-- seated players: by player and by station
	self.Sessions = {} :: { [Player]: Session.Seat }
	self.BySeat = {} :: { [number]: Session.Seat }
	self.Buckets = {} :: { [Player]: Session.Buckets }
	-- os.clock() until which a player may not sit again (forced exit by signal, Rules.CueLock)
	self.LockedUntil = {} :: { [Player]: number }
	self.Published = {} :: { [number]: boolean }
	self.Warned = {} :: { [string]: boolean }
	-- (player, station) seated / (player, station, reason) left; reason "None" = voluntary
	self.Entered = self.Libs.Signal.new() :: SignalLib.Signal<Player, number>
	self.Left = self.Libs.Signal.new() :: SignalLib.Signal<Player, number, string>
end

-- Reads ---------------------------------------------------------------------------------------------------------------

-- Station the player works at, nil = not seated
function PrepService:SeatOf(player: Player): number?
	const seat = self.Sessions[player]
	return if seat ~= nil then seat.Station else nil
end

function PrepService:IsSeated(player: Player): boolean
	return self.Sessions[player] ~= nil
end

-- Player at a station, nil = free (or not an active station)
function PrepService:UserAt(station: number): Player?
	const seat = self.BySeat[station]
	return if seat ~= nil then seat.Player else nil
end

function PrepService:StationCount(): number
	return self.Count
end

-- Seats ---------------------------------------------------------------------------------------------------------------

-- Connected members (not Away), clamped to 1..Stations
function PrepService:WantedCount(): number
	local connected = 0
	for userId, member in self.Dependencies.RunStateService.Members() do
		if member.State ~= "Away" and Players:GetPlayerByUserId(userId) ~= nil then
			connected += 1
		end
	end
	return clampStation(math.max(connected, 1))
end

function PrepService:WriteSeat(station: number, record: SeatRecord?)
	const nextSeats = table.clone(self.Seats())
	nextSeats[station] = if record ~= nil then table.freeze(record :: any) else nil
	self.Seats(table.freeze(nextSeats))
end

-- Records only grow with the party during a turn (DT-9)
function PrepService:Grow()
	const wanted = self:WantedCount()
	for station = self.Count + 1, wanted do
		self:WriteSeat(station, freeRecord())
	end
	self.Count = math.max(self.Count, wanted)
end

-- ShiftStarted: the count follows the party again, never below an occupied seat
function PrepService:Recount()
	local highest = 0
	for station in self.BySeat do
		highest = math.max(highest, station)
	end
	const wanted = math.max(self:WantedCount(), highest)
	for station = wanted + 1, self.Count do
		self:WriteSeat(station, nil)
	end
	self.Count = wanted
	self:Grow()
end

-- Copies the seats atom into the PrepSeats set (add / update / remove). Lync is running since NetService OnStart.
function PrepService:PushSeats()
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const set = self.Libs.Net.PrepSeats
	const seats = self.Seats()
	for station, record in seats do
		const value: any = {
			User = record.User,
			Step = record.Step,
			Ticket = record.Ticket,
			Since = record.Since,
		}
		if self.Published[station] then
			set:update(station, value)
		else
			set:add(station, value)
			self.Published[station] = true
		end
	end
	for station in self.Published do
		if seats[station] == nil then
			set:remove(station)
			self.Published[station] = nil
		end
	end
end

-- Map ------------------------------------------------------------------------------------------------------------------

function PrepService:StationModel(station: number): Instance?
	for _, instance in CollectionService:GetTagged(STATION_TAG) do
		if instance:IsDescendantOf(workspace) and isPrepStation(instance) and stationNumber(instance) == station then
			return instance
		end
	end
	return nil
end

-- Station_n Model that owns an anchor, and its number
function PrepService:StationOfAnchor(anchor: Instance): (Instance?, number?)
	local current: Instance? = anchor
	while current ~= nil and current ~= workspace do
		if isPrepStation(current) then
			return current, stationNumber(current)
		end
		current = current.Parent
	end
	return nil, nil
end

-- Where the rig stands: Att_Stand of the Station model, else the MapIndex point Station_n. nil = the map has neither yet
-- (TASK-172): the seat still works, the character is not moved and no reach check is possible.
function PrepService:StandOf(station: number, step: string?): CFrame?
	const model = self:StationModel(station)
	if model ~= nil then
		const name = VIEW_STAND[step or DEFAULT_STEP] or STAND_ATTACHMENT
		local attachment = model:FindFirstChild(name, true)
		if attachment == nil then
			attachment = model:FindFirstChild(STAND_ATTACHMENT, true)
		end
		if attachment ~= nil and attachment:IsA("Attachment") then
			return attachment.WorldCFrame
		end
	end
	if MapIndex.HasBinding() then
		return MapIndex.FindPoint(`Station_{station}`)
	end
	return nil
end

-- The Work prompt closest to a position (the reach check of the PrepEnter packet; the prompt path is checked by
-- InteractionService). nil = the map has no prompt yet.
function PrepService:WorkDistance(position: Vector3): number?
	local best: number? = nil
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == WORK_ACTION then
			const at = self.Dependencies.InteractionService:Position(anchor)
			if at ~= nil then
				const distance = (at - position).Magnitude
				if best == nil or distance < best then
					best = distance
				end
			end
		end
	end
	return best
end

-- Lowest free seat among the active ones (any prompt gives the next one), nil = all taken
function PrepService:NextSeat(): number?
	for station = 1, self.Count do
		if self.BySeat[station] == nil then
			return station
		end
	end
	return nil
end

-- Step a Work prompt opens on (attribute PromptStep of the anchor, a Content.Prep.Tabs key)
function PrepService:StepOfAnchor(anchor: Instance): string
	const value = anchor:GetAttribute(STEP_ATTRIBUTE)
	if type(value) == "string" and VIEW_STAND[value] ~= nil then
		return value
	end
	return DEFAULT_STEP
end

-- Network ---------------------------------------------------------------------------------------------------------------

function PrepService:Reply(player: Player, act: string, ok: boolean, reason: string, grade: string?, value: number?)
	if player.Parent == nil then
		return
	end
	const payload: any = {
		Act = act,
		Ok = ok,
		Reason = reason,
		Grade = grade or "None",
		Value = math.clamp(math.floor(value or 0), 0, 255),
	}
	self.Libs.Net.PrepResult:fireClient(player, payload)
	if ok then
		return
	end
	-- the toast of the reason (nil = the UI reacts on its own); an ingredient toast needs the ingredient index as value
	const row = cfg.Reasons.ByKey[reason]
	const notice = if row ~= nil then row.Notice else nil
	const noticeRow = if notice ~= nil then Content.Notices.ByKey[notice] else nil
	if noticeRow == nil then
		return
	end
	if noticeRow.ValueFrom == "None" then
		self.Dependencies.RunStateService:Notify(player, notice :: string, nil)
	elseif value ~= nil and value > 0 then
		self.Dependencies.RunStateService:Notify(player, notice :: string, value)
	end
end

-- Rate gate of every packet: false = dropped without an answer
function PrepService:Allow(player: Player, kind: string): boolean
	local buckets = self.Buckets[player]
	if buckets == nil then
		buckets = {}
		self.Buckets[player] = buckets
	end
	const now = os.clock()
	const rate = (rules.Rates :: any)[kind]
	if type(rate) ~= "number" then
		return false
	end
	if not Session.Allow(buckets, "*", GLOBAL_RATE, now) then
		return false
	end
	return Session.Allow(buckets, kind, rate, now)
end

-- Seated player of a packet that needs a seat; replies NoSession otherwise
function PrepService:Seated(player: Player, act: string): Session.Seat?
	const seat = self.Sessions[player]
	if seat == nil then
		self:Reply(player, act, false, "NoSession", nil, nil)
		return nil
	end
	Session.Touch(seat, os.clock())
	return seat
end

-- Enter and leave -------------------------------------------------------------------------------------------------------

-- ("None" | reason, stand). Everything PrepEnter and the prompt check before committing.
function PrepService:CheckEnter(player: Player, station: number, skipReach: boolean?, step: string?): (string, CFrame?)
	if not self.Active or not rules.Enabled then
		return "Locked", nil
	end
	if self.Sessions[player] ~= nil then
		return "Seated", nil
	end
	if not self.Dependencies.RoundService:IsSelling() then
		return "NotSelling", nil
	end
	if station < 1 or station > self.Count then
		return "NoStation", nil
	end
	const characters = self.Dependencies.CharacterService
	if
		not self.Dependencies.RunStateService:IsActive(player)
		or characters:CharacterOf(player) == nil
		or characters:IsFainted(player)
		or characters:IsKnocked(player)
		or characters:IsFrozen(player)
	then
		return "Locked", nil
	end
	if (self.LockedUntil[player] or 0) > os.clock() then
		return "Locked", nil
	end
	if self.BySeat[station] ~= nil then
		return "Busy", nil
	end
	const stand = self:StandOf(station, step)
	if skipReach ~= true then
		const root = self.Dependencies.InteractionService:RootOf(player)
		const distance = if root ~= nil then self:WorkDistance(root.Position) else nil
		if root == nil or (distance ~= nil and distance > Content.Actions.ByKey[WORK_ACTION].Radius + RANGE_SLACK) then
			return "NoStation", nil
		end
	end
	return "None", stand
end

-- (ok, reason). Checks and commits in one synchronous step.
function PrepService:Enter(player: Player, station: number, skipReach: boolean?, step: string?): (boolean, string)
	const reason, stand = self:CheckEnter(player, station, skipReach, step)
	if reason ~= "None" then
		return false, reason
	end
	const now = os.clock()
	const serverTime = workspace:GetServerTimeNow()
	const seat = Session.new(player, station, serverTime, now, step or DEFAULT_STEP)
	self.Sessions[player] = seat
	self.BySeat[station] = seat
	self:WriteSeat(station, { User = player.UserId, Step = seat.Step, Ticket = 0, Since = serverTime })

	const characters = self.Dependencies.CharacterService
	characters:Freeze(player, FREEZE_REASON, true)
	const character = characters:CharacterOf(player)
	if character ~= nil then
		character:SetAttribute(WORKING_ATTRIBUTE, station)
		if stand ~= nil then
			character:PivotTo(stand + STAND_LIFT)
		end
	end
	self.Entered:Fire(player, station)
	return true, "None"
end

-- Frees the seat: refunds an open plate, releases the Freeze, clears Working, writes the set. `reason` "None" = the player
-- left; a Kick* key = forced exit (PrepResult Act = Kick). `silent` = the player is gone, no answer, no Freeze call.
function PrepService:Release(player: Player, reason: string, silent: boolean?): boolean
	const seat = self.Sessions[player]
	if seat == nil then
		return false
	end
	self.Sessions[player] = nil
	self.BySeat[seat.Station] = nil
	const plate = seat.Plate
	seat.Plate = nil
	if plate ~= nil and plate.Reserved then
		const ok, problem = pcall(Bridge.Refund, self.Dependencies.KitchenService, player)
		if not ok then
			warn(`[PrepService] refund of seat {seat.Station} errored: {problem}`)
		end
	end
	if self.Seats()[seat.Station] ~= nil then
		self:WriteSeat(seat.Station, freeRecord())
	end
	if reason == "KickSignal" then
		self.LockedUntil[player] = os.clock() + rules.CueLock
	end
	if silent ~= true then
		self.Dependencies.CharacterService:Freeze(player, FREEZE_REASON, false)
		const character = player.Character
		if character ~= nil then
			character:SetAttribute(WORKING_ATTRIBUTE, nil)
		end
		if reason == "None" then
			self:Reply(player, "Leave", true, "None", nil, seat.Station)
		else
			self:Reply(player, "Kick", false, reason, nil, seat.Station)
		end
	end
	self.Left:Fire(player, seat.Station, reason)
	return true
end

-- Forced exit (anomaly signal, night, thief, sanity band, cutscene, boss call...). reason = "Kick*" key of
-- Content.Prep.Reasons. false = the player was not seated or the reason is not a kick.
function PrepService:ForceExit(player: Player, reason: string): boolean
	if string.sub(reason, 1, 4) ~= "Kick" or cfg.Reasons.ByKey[reason] == nil then
		warn(`[PrepService] ForceExit: "{reason}" is not a Kick* reason of Content.Prep.Reasons`)
		return false
	end
	return self:Release(player, reason, nil)
end

function PrepService:ForceExitAll(reason: string): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if self.Sessions[player] ~= nil and self:ForceExit(player, reason) then
			count += 1
		end
	end
	return count
end

-- Plate ---------------------------------------------------------------------------------------------------------------

-- (ok, reason, value)
function PrepService:Begin(player: Player, seat: Session.Seat): (boolean, string, number)
	if not self.Dependencies.RoundService:IsSelling() then
		return false, "NotSelling", 0
	end
	if seat.Plate ~= nil then
		return false, "Invalid", 0
	end
	const ok, reason, preCut = Bridge.Begin(self.Dependencies.KitchenService, player, seat.Station)
	if not ok then
		return false, reason, 0
	end
	seat.Plate = { StartedAt = os.clock(), Reserved = true }
	-- Value 1 = the bun came already sliced (ANM-002 altered bun): the client skips the cut
	return true, "None", if preCut then 1 else 0
end

-- (ok, reason, grade, value). The summary is checked and the transaction runs; a refusal leaves the plate open and the
-- stock, rail and board untouched (a plate past PlateMax is dropped). The sausage score only exists once the kitchen pops
-- the sausage, so the plate is graded without it for the transaction and graded again with it right after (ItemService
-- SetQuality): the band can only go down, since the sausage adds a stage.
function PrepService:Finish(player: Player, seat: Session.Seat, summary: Validate.Summary): (boolean, string, string, number)
	const plate = seat.Plate
	if plate == nil or not self.Dependencies.RoundService:IsSelling() then
		return false, if plate == nil then "NoSession" else "NotSelling", "None", 0
	end
	const kitchen = self.Dependencies.KitchenService
	const elapsed = os.clock() - plate.StartedAt
	const stock: Validate.Stock = {
		Amount = function(key: string): number
			return (kitchen:GetStock(key))
		end,
		IsBlocked = function(key: string): boolean
			return kitchen:IsBlocked(key)
		end,
	}
	const verdict, reason, value = Validate.Summary(cfg, summary, elapsed, nil, stock)
	if verdict == nil then
		if reason == "NoSession" then
			-- open for longer than PlateMax
			self:DropPlate(player, seat)
		end
		return false, reason, "None", value
	end
	const made, refusal, refusalValue = Bridge.Finish(kitchen, player, verdict.Keys, verdict.Band)
	if made == nil then
		-- Parked: the plate stays; PlateMax counts again from a plausible age (the player already waited the floor)
		plate.StartedAt = os.clock() - math.min(elapsed, rules.PerfectMin + rules.PerTopping * #verdict.Keys)
		return false, refusal, "None", refusalValue
	end
	seat.Plate = nil
	local band = verdict.Band
	const sausage = made.SausageScore
	if sausage ~= nil then
		const stages = table.clone(verdict.Stages)
		stages.Sausage = sausage
		const final = Grade.Plate(cfg, stages, elapsed).Band
		if final ~= band then
			band = final
			self.Dependencies.ItemService:SetQuality(made.Tool, band)
		end
	end
	return true, "None", band, Grade.Points(cfg, band)
end

-- Drops the open plate: the reserved bun comes back (PlateMax, Leave) or is lost (bin)
function PrepService:DropPlate(player: Player, seat: Session.Seat)
	const plate = seat.Plate
	seat.Plate = nil
	if plate ~= nil and plate.Reserved then
		Bridge.Refund(self.Dependencies.KitchenService, player)
	end
	self:Reply(player, "Trash", false, "NoSession", nil, nil)
end

function PrepService:Trash(player: Player, seat: Session.Seat): (boolean, string)
	const plate = seat.Plate
	seat.Plate = nil
	const bridge = Bridge.Trash(self.Dependencies.KitchenService, self.Dependencies.ItemService, player, plate ~= nil)
	if plate == nil and not bridge then
		return false, "NoSession"
	end
	return true, "None"
end

-- Packets ---------------------------------------------------------------------------------------------------------------

function PrepService:OnTab(player: Player, step: string, ticket: number)
	const seat = self:Seated(player, "Tab")
	if seat == nil then
		return
	end
	if ticket < 0 or ticket > MAX_TICKET or cfg.Tabs.ByKey[step] == nil then
		self:Reply(player, "Tab", false, "Invalid", nil, nil)
		return
	end
	if seat.Step ~= step or seat.Ticket ~= ticket then
		seat.Step = step
		seat.Ticket = ticket
		self:WriteSeat(seat.Station, { User = player.UserId, Step = step, Ticket = ticket, Since = seat.Since })
	end
end

function PrepService:OnGrill(player: Player, act: string, slot: number)
	const seat = self:Seated(player, "Grill")
	if seat == nil then
		return
	end
	if not self.Dependencies.RoundService:IsSelling() then
		self:Reply(player, "Grill", false, "NotSelling", nil, nil)
		return
	end
	const outcome = Bridge.Grill(self.Dependencies.KitchenService, player, act, slot)
	self:Reply(player, "Grill", outcome.Ok, outcome.Reason, outcome.Grade, outcome.Value)
end

function PrepService:OnFinish(player: Player, summary: Validate.Summary)
	const seat = self:Seated(player, "Finish")
	if seat == nil then
		return
	end
	const ok, reason, grade, value = self:Finish(player, seat, summary)
	self:Reply(player, "Finish", ok, reason, grade, value)
end

function PrepService:OnOrder(player: Player, act: string, npc: number)
	const seat = self:Seated(player, "Order")
	if seat == nil then
		return
	end
	if not self.Dependencies.RoundService:IsSelling() then
		self:Reply(player, "Order", false, "NotSelling", nil, nil)
		return
	end
	const outcome = Bridge.Order(self.Dependencies.CustomerService, player, act, npc)
	self:Reply(player, "Order", outcome.Ok, outcome.Reason, outcome.Grade, outcome.Value)
end

function PrepService:ConnectPackets()
	const net = self.Libs.Net
	net.PrepEnter:onServer(function(value, player: Player)
		if not self:Allow(player, "Enter") then
			return
		end
		const ok, reason = self:Enter(player, value.Station, nil)
		self:Reply(player, "Enter", ok, reason, nil, if ok then value.Station else nil)
	end)
	net.PrepLeave:onServer(function(_value, player: Player)
		if not self:Allow(player, "Leave") then
			return
		end
		if self.Sessions[player] == nil then
			self:Reply(player, "Leave", false, "NoSession", nil, nil)
			return
		end
		self:Release(player, "None", nil)
	end)
	net.PrepTab:onServer(function(value, player: Player)
		if not self:Allow(player, "Tab") then
			return
		end
		self:OnTab(player, value.Step, value.Ticket)
	end)
	net.PrepGrill:onServer(function(value, player: Player)
		if not self:Allow(player, "Grill") then
			return
		end
		self:OnGrill(player, value.Act, value.Slot)
	end)
	net.PrepBegin:onServer(function(_value, player: Player)
		if not self:Allow(player, "Begin") then
			return
		end
		const seat = self:Seated(player, "Begin")
		if seat == nil then
			return
		end
		const ok, reason, value = self:Begin(player, seat)
		self:Reply(player, "Begin", ok, reason, nil, value)
	end)
	net.PrepFinish:onServer(function(value, player: Player)
		if not self:Allow(player, "Finish") then
			return
		end
		self:OnFinish(player, value :: any)
	end)
	net.PrepTrash:onServer(function(_value, player: Player)
		if not self:Allow(player, "Trash") then
			return
		end
		const seat = self:Seated(player, "Trash")
		if seat == nil then
			return
		end
		const ok, reason = self:Trash(player, seat)
		self:Reply(player, "Trash", ok, reason, nil, nil)
	end)
	net.PrepOrder:onServer(function(value, player: Player)
		if not self:Allow(player, "Order") then
			return
		end
		self:OnOrder(player, value.Act, value.Npc)
	end)
end

-- Prompt and gate -----------------------------------------------------------------------------------------------------

function PrepService:RegisterWork()
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(WORK_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			-- any Work prompt gives the next free seat (the seats are logical, DEC-224)
			const reason = self:CheckEnter(player, self:NextSeat() or 1, true, self:StepOfAnchor(anchor))
			if reason ~= "None" then
				self:Reply(player, "Enter", false, reason, nil, nil)
				return false
			end
			return true
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			const station = self:NextSeat() or 1
			const ok, reason = self:Enter(player, station, true, self:StepOfAnchor(anchor))
			self:Reply(player, "Enter", ok, reason, nil, if ok then station else nil)
		end,
	})
	-- a seated player's world prompts stay quiet; the tabs reach the same services through PrepOrder
	interaction:AddGate(GATE, function(player: Player, _action: string, _anchor: Instance): (boolean, string?)
		if self.Sessions[player] ~= nil then
			return false, "Seated"
		end
		return true, nil
	end)
end

-- Lifecycle -------------------------------------------------------------------------------------------------------------

-- Every 0.5 s: disconnected, ragdoll / faint / knock / dead, shift phase over, seat idle, plate older than PlateMax
function PrepService:Sweep()
	const characters = self.Dependencies.CharacterService
	const selling = self.Dependencies.RoundService:IsSelling()
	const now = os.clock()
	for player, seat in table.clone(self.Sessions) do
		if self.Sessions[player] ~= seat then
			continue
		end
		if player.Parent == nil then
			self:Release(player, "KickAway", true)
		elseif not selling then
			self:Release(player, "KickClosing", nil)
		elseif
			characters:CharacterOf(player) == nil
			or characters:IsFainted(player)
			or characters:IsKnocked(player)
			or not self.Dependencies.RunStateService:IsActive(player)
		then
			self:Release(player, "KickDown", nil)
		elseif now - seat.LastSeen > rules.SeatIdle then
			self:Release(player, "KickIdle", nil)
		else
			const plate = seat.Plate
			if plate ~= nil and now - plate.StartedAt > rules.PlateMax then
				self:DropPlate(player, seat)
			end
		end
	end
end

PrepService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Active = true

	-- InteractionService (730) built its handler table in its own OnInit
	self:RegisterWork()
	self:ConnectPackets()

	-- the signals below exist since their owners' OnInit (priority above 645)
	const runState = self.Dependencies.RunStateService
	runState.MemberJoined:Connect(function(_player)
		self:Grow()
	end)
	runState.MemberAway:Connect(function(player)
		self:Release(player, "KickAway", nil)
	end)
	runState.LifeChanged:Connect(function(userId, _old, new)
		if new == "Active" then
			return
		end
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			self:Release(player, if new == "Away" then "KickAway" else "KickDown", nil)
		end
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function(_info)
		self:Recount()
	end)
	self.Dependencies.RoundService.PhaseChanged:Connect(function(_phase)
		if not self.Dependencies.RoundService:IsSelling() then
			self:ForceExitAll("KickClosing")
		end
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Release(player, "KickAway", true)
		self.Buckets[player] = nil
		self.LockedUntil[player] = nil
	end)
end)

PrepService:OnStart(function(self)
	if not self.Active then
		return
	end
	-- the set is written by the atom: the first run adds the records of the current count
	self:Grow()
	self.Libs.Charm.effect(function()
		self:PushSeats()
	end)
end)

PrepService:OnTick(function(self)
	if self.Active then
		self:Sweep()
	end
end, TICK_RATE)

-- Dev (/dev prep seats | enter | leave | finish; guarded by IsDev) --------------------------------

function PrepService:DevGuard()
	if not self.Dependencies.PlaceService:IsDev() then
		error("dev only", 0)
	end
end

function PrepService:DevSeats(): string
	self:DevGuard()
	const lines: { string } = { `prep seats: {self.Count} active, selling {tostring(self.Dependencies.RoundService:IsSelling())}` }
	for station = 1, self.Count do
		const seat = self.BySeat[station]
		if seat == nil then
			table.insert(lines, `  {station}: free`)
		else
			const plate = seat.Plate
			const plateText = if plate ~= nil then `plate open {string.format("%.1f", os.clock() - plate.StartedAt)}s` else "no plate"
			table.insert(lines, `  {station}: {seat.Player.Name} tab {seat.Step} ticket {seat.Ticket}, {plateText}`)
		end
	end
	return table.concat(lines, "\n")
end

-- Sits `player` at `station` (dev: no reach check; every other rule applies)
function PrepService:DevEnter(player: Player, station: number, step: string?): string
	self:DevGuard()
	-- `step` = the tab of the prompt it stands in for (Grill or Build, the PromptStep of the real prompts)
	const ok, reason = self:Enter(player, clampStation(station), true, if step ~= nil and VIEW_STAND[step] ~= nil then step else nil)
	self:Reply(player, "Enter", ok, reason, nil, if ok then station else nil)
	if ok then
		return `{player.Name} sits at station {station}`
	end
	return `refused: {reason} - {self:DevWhy(player, clampStation(station), reason)}`
end

-- Plain words for a refusal of CheckEnter, with the state that caused it (dev commands only)
function PrepService:DevWhy(player: Player, station: number, reason: string): string
	const round = self.Dependencies.RoundService
	const characters = self.Dependencies.CharacterService
	if reason == "NotSelling" then
		return `phase is {round.Phase()}: the shop must be open (Open or Night: press the red switch on the trailer wall first)`
	elseif reason == "NoStation" then
		return `only {self.Count} station(s) active (party size), asked for {station}`
	elseif reason == "Busy" then
		const seat = self.BySeat[station]
		return `station {station} is taken by {if seat ~= nil then seat.Player.Name else "someone"}`
	elseif reason == "Seated" then
		return `already seated at station {self:SeatOf(player) or 0}: /dev prep leave`
	elseif reason == "Locked" then
		if not self.Active or not rules.Enabled then
			return "Content.Prep.Rules.Enabled is false (or not the Run place)"
		elseif not self.Dependencies.RunStateService:IsActive(player) then
			return "the player is not an Active member of the run"
		elseif characters:CharacterOf(player) == nil then
			return "no character yet"
		elseif characters:IsFainted(player) or characters:IsKnocked(player) then
			return "the character is fainted or knocked"
		elseif characters:IsFrozen(player) then
			return "the character is frozen by another system (a cutscene, the trailer door)"
		end
		return "re-entry lock after a forced exit (Rules.CueLock)"
	end
	return "see Content.Prep.Reasons"
end

function PrepService:DevLeave(player: Player): string
	self:DevGuard()
	if not self:Release(player, "None", nil) then
		return `{player.Name} is not seated`
	end
	return `{player.Name} left the seat`
end

-- Opens a plate when none is open, then sends a perfect summary through the real path. `force` ages the plate past the
-- Perfect floor first (otherwise the server clock answers TooFast, like it should). toppings = keys of Content.Ingredients.
function PrepService:DevFinish(player: Player, keys: { string }, force: boolean): string
	self:DevGuard()
	const seat = self.Sessions[player]
	if seat == nil then
		return `{player.Name} is not seated: /dev prep enter <n> first`
	end
	local note = ""
	if seat.Plate == nil then
		const ok, reason = self:Begin(player, seat)
		if not ok then
			return `begin refused: {reason}`
		end
		note = "plate opened; "
	end
	const plate = seat.Plate :: Session.Plate
	if force then
		plate.StartedAt = math.min(plate.StartedAt, os.clock() - (rules.PerfectMin + rules.PerTopping * #keys + 0.5))
	end
	const elapsed = os.clock() - plate.StartedAt
	const toppings: { { Key: string, Score: number } } = {}
	for _, key in keys do
		table.insert(toppings, { Key = key, Score = 100 })
	end
	const summary: Validate.Summary = {
		Cut = 100,
		Place = 100,
		Toppings = toppings,
		Ms = math.clamp(math.floor(elapsed * 1000), 0, 120000),
	}
	const ok, reason, grade, value = self:Finish(player, seat, summary)
	self:Reply(player, "Finish", ok, reason, grade, value)
	if ok then
		return `{note}finished: {grade} ({value} pts) after {string.format("%.1f", elapsed)}s`
	end
	return `{note}refused: {reason} (value {value}) after {string.format("%.1f", elapsed)}s; the plate stays open (try "finish force")`
end

return PrepService
