--!strict
-- Focused prep mode, server side (docs/tech/prep-mode.md §2 to §5; DEC-223; TASK-170, P2). Run place only.
-- Single responder of PrepEnter / PrepLeave / PrepTab / PrepGrill / PrepBegin / PrepFinish / PrepTrash / PrepOrder
-- / PrepPointer / PrepGrab (all in OnInit), single writer of the PrepSeats set (record id = station 1..4) and of the
-- PrepClaims set, and owner of the prep_work action.
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
-- Live drag (DEC-259, TASK-349): PrepPointer of a seated player is checked against the seat's board (Ghost.MaxDistance) and
-- relayed as PrepGhost to the other party members; PrepGrab claims a grill / rail sausage (single writer of the PrepClaims
-- set). A claim lives Ghost.GrabLease s (renewed by Grab On and by every pointer that holds something) and goes away on Off,
-- seat release, the sausage leaving its slot and the shop closing. Grill Flip / Collect, the bin and the plate (the front of
-- the rail) are refused with Reason Held while another seat holds that sausage.
-- Conveyor (TASK-514; tech/prep-conveyor.md §2 to §6, §10; DEC-302..305), only while Content.Prep.Rules.Mode = "Conveyor"
-- (the restaurant): the trailer path above does not change.
--   Seats        3 fixed PrepSeats records (Conveyor.Seats): 1-2 = the belt (assemblers, a plate each), 3 = the grill.
--   Prompts      prep_work (Prompt_Work) -> a free belt seat, needs a plate: the parked one of this player, else the plate of
--                the hand (PlateService:WorkablePlate -> Borrow; no plate is ever made here, DEC-304); NoPlate / PlateDone /
--                BeltFull. prep_grill (Prompt_Grill) -> the grill seat; GrillBusy. PrepEnter asks for a seat by number.
--   Belt         PrepBelt moves only the seat's own plate one stop (Belt.luau: reservation, waiting beside, promotion);
--                PrepStage commits Cut (bun) / Dog (rest table sausage) on the Board stop, PrepFinish grades on Toppings
--                (Grade only; the Cut / Place the server stored, never the summary's) and sends the plate to Out. A plate
--                in Out goes back to the hand (PlateService:Giveback) and the focus ends.
--   Leaving      Leave / Kick* with the plate before Out: it stays PARKED and reserved on the belt (Away = true, P24) and
--                the next prep_work of that player resumes it; Out / KickClosing: back to the hand; KickAway, disconnect,
--                Conveyor.ParkMax: to the central table (PlateService:Shelve).
-- Provisional: GLOBAL_RATE 6, RANGE_SLACK 2, STAND_LIFT 3 (the Att_Stand of the map is not placed yet, TASK-172); POINTER_SLACK,
-- GRAB_RATE (outside GLOBAL_RATE: a 10 Hz pointer and a grab per drag would starve the other acts).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Sauce = require(ReplicatedStorage.shared.Item.HotDogVisual.Sauce)
local PlateMask = require(ReplicatedStorage.shared.Prep.PlateMask)
local WorkSlide = require(ReplicatedStorage.shared.Prep.WorkSlide)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Belt = require(script.Belt)
local Bridge = require(script.Bridge)
local Session = require(script.Session)
local Validate = require(script.Validate)
local Modux = require(ServerScriptService.server.Modux)

export type SeatRecord = {
	User: number,
	Step: string,
	Ticket: number,
	Since: number,
	Plate: number,
	-- conveyor only (network.md §19.1): stop of the seat's plate, waiting side, ticket line, parked
	Stop: number?,
	Wait: number?,
	Line: number?,
	Away: boolean?,
}
-- A held grill / rail sausage (DEC-259). Key of the claims atom = PrepClaims record id
export type Claim = { Station: number, Player: Player }

const STATION_TAG = "Station"
const PREP_KIND = "prep"
const WORK_ACTION = "prep_work"
const STAND_ATTACHMENT = "Att_Stand"
-- DEC-224 (Provisional): seats are logical, only two natural prompts exist (the grill and the cutting board). The prompt used
-- says where the player starts (attribute PromptStep on the Prompt_Work attachment) and which stand the rig takes
-- (Att_Stand = grill, Att_Stand_Build = board); the seat itself is the next free one.
const STEP_ATTRIBUTE = "PromptStep"
const VIEW_STAND: { [string]: string } =
	{ Grill = "Att_Stand", Build = "Att_Stand_Build", Board = "Att_Stand_Build", Toppings = "Att_Stand_Build" }
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
const ghost = rules.World.Ghost
const GRAB_SLOTS = 8 -- PrepGrab.Slot 1..8; PrepClaims record id = (index of From - 1) * GRAB_SLOTS + Slot
const POINTER_SLACK = 1.5 -- the pointer bucket refills at Ghost.Hz * this (jitter of a newest(Hz) packet)
const GRAB_RATE = 6 -- PrepGrab per second per player (own bucket)
const BOARD_KIND = "board"
const GRILL_KIND = "grill"
const HOT_DOG = "hot_dog"
-- Conveyor (TASK-514)
const GRILL_ACTION = "prep_grill"
const conveyor = cfg.Conveyor
const CONVEYOR = rules.Mode == "Conveyor"
const BELT_SEATS = conveyor.Seats.Belt
const GRILL_SEATS = conveyor.Seats.Grill
const ANCHOR_RETRY = 10 -- s between two searches of a named bench anchor the map does not have yet
const FLIP_ATTRIBUTE = "FlipBonus" -- hot_dog Tool attribute the sale reads (TASK-517)

-- Highest seat id of the conveyor: its PrepSeats record count
local function conveyorSeatCount(): number
	local highest = 0
	for _, seat in BELT_SEATS do
		highest = math.max(highest, seat)
	end
	for _, seat in GRILL_SEATS do
		highest = math.max(highest, seat)
	end
	return math.clamp(highest, 1, MAX_STATIONS)
end

-- Content.Prep.Conveyor.Stops as Belt rows
local function beltStops(): { Belt.BeltStop }
	const list: { Belt.BeltStop } = {}
	for _, row in conveyor.Stops.List do
		table.insert(list, { Key = row.Key, Tab = row.Tab, Reserve = row.Reserve })
	end
	return list
end

-- Tab of a stop (PrepSeats.Step), the first stop's when out of range
local function stopTab(stop: number?): string
	const row = if stop ~= nil then conveyor.Stops.List[stop] else nil
	return if row ~= nil then row.Tab else conveyor.Stops.List[1].Tab
end

-- Plate mask of a plate state (bun / sausage bits, toppings once graded)
local function maskOf(state: Bridge.PlateState): number
	return PlateMask.Pack({
		Cut = state.Bun,
		Sausage = state.Dog,
		Toppings = if state.Grade ~= nil then state.Toppings else nil,
	})
end

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

-- A wire tab key as a key of the ACTIVE tab set (prep-3d.md §15: `Tabs.ByKey[k] and k or TabAlias[k]`); nil = unknown
local function resolveTab(key: string): string?
	if cfg.Tabs.ByKey[key] ~= nil then
		return key
	end
	const alias = cfg.TabAlias[key]
	if alias ~= nil and cfg.Tabs.ByKey[alias] ~= nil then
		return alias
	end
	return nil
end

local function isPrepStation(instance: Instance): boolean
	return CollectionService:HasTag(instance, STATION_TAG) and instance:GetAttribute("StationKind") == PREP_KIND
end

local function freeRecord(): SeatRecord
	return { User = 0, Step = "Order", Ticket = 0, Since = 0, Plate = 0 }
end

-- PrepClaims record id of a grill / rail slot, nil = not a GrabFrom key or a slot out of range
local function claimId(from: string, slot: number): number?
	const index = table.find(cfg.GrabFrom, from)
	if index == nil or slot ~= math.floor(slot) or slot < 1 or slot > GRAB_SLOTS then
		return nil
	end
	return (index - 1) * GRAB_SLOTS + slot
end

-- (From, Slot) of a PrepClaims record id
local function claimSlot(id: number): (string, number)
	return cfg.GrabFrom[(id - 1) // GRAB_SLOTS + 1], (id - 1) % GRAB_SLOTS + 1
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
		"TutorialService",
		-- conveyor (prep-conveyor.md §10): the plate of the hand goes on the belt and back; no Require back (no cycle)
		"PlateService",
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
	-- DEC-259: held grill / rail sausages by PrepClaims record id (frozen, replaced on every write); OnStart mirrors it to the set
	self.Claims = self.Libs.Charm.atom({} :: { [number]: Claim }) :: Charm.Atom<{ [number]: Claim }>
	self.ClaimsPublished = {} :: { [number]: number }
	-- os.clock() until which each claim lives (renewals stay off the atom: they never change the set)
	self.Leases = {} :: { [number]: number }
	self.Warned = {} :: { [string]: boolean }
	-- TASK-260 (owner request 2026-10-14): a plate left by Leave / a forced exit stays on the board (kitchen ticket and stock kept)
	-- and comes back on the next Enter of the same player. Refunded when the player leaves the server, the shop closes, or it
	-- outlives Rules.PlateMax (never while the tutorial is pending)
	self.Parked = {} :: { [Player]: { Plate: Session.Plate, Mask: number } }
	-- conveyor (TASK-514): where each belt seat's plate is (Belt.luau), the plates parked on it by players that left the seat
	-- (by player and by seat; the seat stays theirs) and the bench anchors found by name (Seat_Belt_n, Seat_Grill)
	self.Belt = Belt.new(beltStops()) :: Belt.Belt
	self.Away = {} :: { [Player]: Session.Parked }
	self.AwayBySeat = {} :: { [number]: Player }
	self.Anchors = {} :: { [string]: Instance }
	self.AnchorMiss = {} :: { [string]: number }
	-- (player, station) seated / (player, station, reason) left; reason "None" = voluntary
	self.Entered = self.Libs.Signal.new() :: SignalLib.Signal<Player, number>
	self.Left = self.Libs.Signal.new() :: SignalLib.Signal<Player, number, string>
	-- every answer to a prep packet (player, act, ok, reason, grade, value): analytics (MetricsService, owner 2026-10-16)
	self.Replied = self.Libs.Signal.new() :: SignalLib.Signal<Player, string, boolean, string, string?, number?>
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
	-- conveyor: the fixed records of Conveyor.Seats, whatever the party size (prep-conveyor.md §2.1)
	if CONVEYOR then
		return conveyorSeatCount()
	end
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

-- Writes the seat record of `seat` (step, ticket, plate mask) into the seats atom
function PrepService:PublishSeat(seat: Session.Seat)
	if seat.Kind ~= "Trailer" then
		self:RefreshSeat(seat.Station)
		return
	end
	self:WriteSeat(seat.Station, {
		User = seat.Player.UserId,
		Step = seat.Step,
		Ticket = seat.Ticket,
		Since = seat.Since,
		Plate = seat.Mask,
	})
end

-- Zeroes the cosmetic plate mask (Begin, Finish, Trash, plate dropped) and tells the colleagues
function PrepService:ClearMask(seat: Session.Seat)
	if seat.Mask ~= 0 then
		seat.Mask = 0
		if self.BySeat[seat.Station] == seat then
			self:PublishSeat(seat)
		end
	end
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
			Plate = record.Plate,
			Stop = record.Stop,
			Wait = record.Wait,
			Line = record.Line,
			Away = record.Away,
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
	-- conveyor: the foot of the seat on the bench (Conveyor.Binding.Seats[n], MAP-01-r4 §16.5 c), shared by every stop
	if CONVEYOR then
		const name = conveyor.Binding.Seats[station]
		return if name ~= nil then self:NamedAnchor(name) else nil
	end
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
-- InteractionService). nil = the map has no prompt yet. The grill prompt slides along the counter with the player
-- (TASK-354, WorkSlide): its distance is measured from where that player sees it.
function PrepService:WorkDistance(position: Vector3, action: string?): number?
	const wanted = action or WORK_ACTION
	local best: number? = nil
	for _, anchor in CollectionService:GetTagged("Interactable") do
		if anchor:GetAttribute("PromptAction") == wanted and not (CONVEYOR and self:StationOfAnchor(anchor) ~= nil) then
			local at = self.Dependencies.InteractionService:Position(anchor)
			if at ~= nil and not CONVEYOR and WorkSlide.Applies(anchor) then
				at = WorkSlide.Position(anchor, at, position)
			end
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
	-- Build (2D) and Board (3D) are the same prompt: it resolves to the key of the active tab set
	const resolved = if type(value) == "string" and VIEW_STAND[value] ~= nil then resolveTab(value) else nil
	return resolved or DEFAULT_STEP
end

-- Tab the mode opens on for a player at `position` (owner request 2026-10-17, Provisional): the active tab whose view Focus
-- (Content.Prep.Views, in the Station_n model) is nearest on the floor plane. Standing by the board opens on the board, by the
-- toppings on the toppings, by the grill on the grill. nil = no Focus in the map (the prompt's own step applies).
function PrepService:StepNear(station: number, position: Vector3): string?
	const model = self:StationModel(station)
	if model == nil then
		return nil
	end
	local best: string? = nil
	local bestDistance = math.huge
	for _, view in cfg.Views.List do
		if cfg.Tabs.ByKey[view.Tab] ~= nil and VIEW_STAND[view.Tab] ~= nil then
			const focus = model:FindFirstChild(view.Focus, true)
			const at = if focus ~= nil and focus:IsA("Attachment") then focus.WorldPosition else nil
			if at ~= nil then
				const offset = at - position
				const distance = offset.X * offset.X + offset.Z * offset.Z
				if distance < bestDistance then
					best = view.Tab
					bestDistance = distance
				end
			end
		end
	end
	return best
end

-- Only the grill carries the Work prompt (owner decision 2026-10-14): any other Prompt_Work (the cutting board / bun crate one) stays
-- off. The mode itself still opens on the Build tab by the tabs; the other prompts of that corner are the restock ones.
-- With the focused mode off (restaurant: Content.Prep.Rules.Enabled false) every Work prompt is off: a leftover "Work"
-- sat on the cutting board and took the E away from the Slice prompt (owner 2026-10-18: "a mesa de trabalho não funciona").
-- Conveyor (DEC-305, two prompts): the Prompt_Work of the bench stays on; a Work prompt inside an old prep Station_n model
-- (clones of the trailer) is off; prep_grill only lives with the conveyor.
function PrepService:SilenceSpareWork(anchor: Instance)
	const action = anchor:GetAttribute("PromptAction")
	local silence = false
	if action == WORK_ACTION then
		if not rules.Enabled then
			silence = true
		elseif CONVEYOR then
			silence = self:StationOfAnchor(anchor) ~= nil
		else
			silence = self:StepOfAnchor(anchor) ~= DEFAULT_STEP
		end
	elseif action == GRILL_ACTION then
		silence = not rules.Enabled or not CONVEYOR
	end
	if silence then
		self.Dependencies.InteractionService:SetPrompt(anchor, false, nil)
	end
end

-- Conveyor --------------------------------------------------------------------------------------------------------------

-- World CFrame of a bench anchor found by name (Attachment, BasePart or Model), nil = the map does not have it yet (searched
-- again after ANCHOR_RETRY s)
function PrepService:NamedAnchor(name: string): CFrame?
	local found: Instance? = self.Anchors[name]
	if found ~= nil and not found:IsDescendantOf(workspace) then
		found = nil
		self.Anchors[name] = nil
	end
	if found == nil then
		const now = os.clock()
		if (self.AnchorMiss[name] or 0) > now then
			return nil
		end
		found = workspace:FindFirstChild(name, true)
		if found == nil then
			self.AnchorMiss[name] = now + ANCHOR_RETRY
			return nil
		end
		self.Anchors[name] = found
	end
	const instance = found :: Instance
	if instance:IsA("Attachment") then
		return instance.WorldCFrame
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Model") then
		return instance:GetPivot()
	end
	return nil
end

function PrepService:IsBeltSeat(station: number): boolean
	return CONVEYOR and table.find(BELT_SEATS, station) ~= nil
end

function PrepService:IsGrillSeat(station: number): boolean
	return CONVEYOR and table.find(GRILL_SEATS, station) ~= nil
end

-- Nobody sits there and no parked plate keeps it
function PrepService:BeltSeatFree(station: number): boolean
	return self.BySeat[station] == nil and self.AwayBySeat[station] == nil
end

-- Writes the conveyor record of `station` from its session, else its parked plate, else free
function PrepService:RefreshSeat(station: number)
	if station < 1 or station > self.Count then
		return
	end
	const seat = self.BySeat[station]
	const owner = self.AwayBySeat[station]
	const parked = if owner ~= nil then self.Away[owner] else nil
	const stop, side = Belt.at(self.Belt, station)
	if seat ~= nil then
		self:WriteSeat(station, {
			User = seat.Player.UserId,
			Step = seat.Step,
			Ticket = seat.Ticket,
			Since = seat.Since,
			Plate = seat.Mask,
			Stop = stop or 0,
			Wait = side,
			Line = seat.Line,
			Away = nil,
		})
	elseif owner ~= nil and parked ~= nil then
		self:WriteSeat(station, {
			User = owner.UserId,
			Step = stopTab(stop),
			Ticket = parked.Ticket,
			Since = parked.SeatSince,
			Plate = parked.Mask,
			Stop = stop or 0,
			Wait = side,
			Line = parked.Line,
			Away = true,
		})
	else
		self:WriteSeat(station, freeRecord())
	end
end

-- The seat promoted by a Belt call (it now holds the stop it waited beside): its record changes
function PrepService:Promoted(station: number?)
	if station ~= nil then
		self:RefreshSeat(station)
	end
end

-- The plate of `station` leaves the belt (to the hand or the table); the plate waiting for its stop goes in
function PrepService:OffBelt(station: number)
	self:Promoted(Belt.leave(self.Belt, station))
end

-- Belt -> hand. The hot_dog carries the flip stamp and the grade the sale reads (TASK-517: FlipBonus / Quality); PlateService
-- writes them, this only fills a missing one. Not in the hand = the central table.
function PrepService:GiveBack(player: Player, id: number)
	const plates = self.Dependencies.PlateService
	const state = Bridge.PlateOf(plates, id)
	const tool = Bridge.Giveback(plates, player, id)
	if tool == nil then
		Bridge.Shelve(plates, id)
		return
	end
	if state ~= nil and state.Grade ~= nil and tool:GetAttribute("Item") == HOT_DOG then
		if tool:GetAttribute(FLIP_ATTRIBUTE) == nil then
			tool:SetAttribute(FLIP_ATTRIBUTE, state.FlipBonus == true)
		end
		if self.Dependencies.ItemService:QualityOf(tool) == nil then
			self.Dependencies.ItemService:SetQuality(tool, state.Grade)
		end
	end
end

-- A parked plate leaves the belt: "Hand" (back to its owner, else the table), "Shelve" (the central table), "Gone" (the
-- plate no longer exists)
function PrepService:DropParked(player: Player, how: string)
	const parked = self.Away[player]
	if parked == nil then
		return
	end
	self.Away[player] = nil
	if self.AwayBySeat[parked.Station] == player then
		self.AwayBySeat[parked.Station] = nil
	end
	self:OffBelt(parked.Station)
	self:RefreshSeat(parked.Station)
	if how == "Hand" and player.Parent ~= nil then
		self:GiveBack(player, parked.PlateId)
	elseif how ~= "Gone" then
		Bridge.Shelve(self.Dependencies.PlateService, parked.PlateId)
	end
end

-- The seat ends with the plate: parked on the belt (Leave / Kick* before Out), back to the hand (Out, closing) or to the
-- central table (gone, KickAway). prep-conveyor.md §2.3
function PrepService:LeaveBelt(player: Player, seat: Session.Seat, reason: string, silent: boolean?)
	const id = seat.PlateId
	seat.PlateId = nil
	const station = seat.Station
	if id == nil then
		self:OffBelt(station)
		return
	end
	const stop = Belt.at(self.Belt, station)
	const atOut = stop ~= nil and stop == Belt.exit(self.Belt)
	const selling = self.Dependencies.RoundService:IsServing()
	if silent == true or reason == "KickAway" or player.Parent == nil then
		self:OffBelt(station)
		Bridge.Shelve(self.Dependencies.PlateService, id)
	elseif atOut or reason == "KickClosing" or not selling or stop == nil then
		self:OffBelt(station)
		self:GiveBack(player, id)
	else
		self.Away[player] = {
			Station = station,
			PlateId = id,
			Ticket = seat.Ticket,
			Line = seat.Line,
			Mask = seat.Mask,
			Since = os.clock(),
			SeatSince = seat.Since,
		}
		self.AwayBySeat[station] = player
	end
end

-- ("None" | reason, station, plate id, resume). Everything a belt seat checks before committing. requested = PrepEnter.Station
function PrepService:CheckBelt(player: Player, requested: number?, skipReach: boolean?): (string, number?, number?, boolean)
	const common = self:CheckCommon(player)
	if common ~= "None" then
		return common, nil, nil, false
	end
	if requested ~= nil and not self:IsBeltSeat(requested) then
		return "NoStation", nil, nil, false
	end
	if skipReach ~= true and not self:InReach(player, WORK_ACTION) then
		return "NoStation", nil, nil, false
	end
	const plates = self.Dependencies.PlateService
	-- the plate this player left on the belt comes back first, whatever is in the hand (§2.2)
	const parked = self.Away[player]
	if parked ~= nil and Bridge.PlateOf(plates, parked.PlateId) ~= nil then
		return "None", parked.Station, parked.PlateId, true
	end
	local station: number? = nil
	if requested ~= nil then
		station = if self:BeltSeatFree(requested) then requested else nil
	else
		for _, candidate in BELT_SEATS do
			if candidate <= self.Count and self:BeltSeatFree(candidate) then
				station = candidate
				break
			end
		end
	end
	if station == nil then
		return "BeltFull", nil, nil, false
	end
	const state = Bridge.Workable(plates, player)
	if state == nil then
		-- an assembled hot dog of a ticket does not go back on the belt
		const held = self.Dependencies.ItemService:Holding(player, HOT_DOG)
		if held ~= nil and held:GetAttribute("PlateId") ~= nil then
			return "PlateDone", nil, nil, false
		end
		return "NoPlate", nil, nil, false
	end
	if state.Grade ~= nil then
		return "PlateDone", nil, nil, false
	end
	return "None", station, state.Id, false
end

-- ("None" | reason, station) of the grill seat
function PrepService:CheckGrill(player: Player, requested: number?, skipReach: boolean?): (string, number?)
	const common = self:CheckCommon(player)
	if common ~= "None" then
		return common, nil
	end
	if requested ~= nil and not self:IsGrillSeat(requested) then
		return "NoStation", nil
	end
	if skipReach ~= true and not self:InReach(player, GRILL_ACTION) then
		return "NoStation", nil
	end
	for _, candidate in GRILL_SEATS do
		if (requested == nil or candidate == requested) and candidate <= self.Count and self.BySeat[candidate] == nil then
			return "None", candidate
		end
	end
	return "GrillBusy", nil
end

-- Seats the player (Freeze, Working, rig on the seat's foot) and fires Entered
function PrepService:Sit(player: Player, seat: Session.Seat)
	self.Sessions[player] = seat
	self.BySeat[seat.Station] = seat
	self:RefreshSeat(seat.Station)
	const stand = self:StandOf(seat.Station, nil)
	const characters = self.Dependencies.CharacterService
	characters:Freeze(player, FREEZE_REASON, true)
	const character = characters:CharacterOf(player)
	if character ~= nil then
		character:SetAttribute(WORKING_ATTRIBUTE, seat.Station)
		if stand ~= nil then
			character:PivotTo(stand + STAND_LIFT)
		end
	end
	self.Entered:Fire(player, seat.Station)
end

-- (ok, reason, station). prep_work / PrepEnter on a belt seat: the parked plate resumes, else the plate of the hand loads on
-- the entry stop (taken from the hand by PlateService:Borrow; no plate is made)
function PrepService:EnterBelt(player: Player, requested: number?, skipReach: boolean?): (boolean, string, number?)
	const reason, station, id, resume = self:CheckBelt(player, requested, skipReach)
	if reason ~= "None" or station == nil or id == nil then
		return false, if reason == "None" then "Invalid" else reason, nil
	end
	const plates = self.Dependencies.PlateService
	local state: Bridge.PlateState? = nil
	if resume then
		state = Bridge.PlateOf(plates, id)
		self.Away[player] = nil
		self.AwayBySeat[station] = nil
	else
		state = Bridge.Borrow(plates, player, id)
		if state == nil then
			return false, "NoPlate", nil
		end
		Belt.load(self.Belt, station, 1)
	end
	if state == nil then
		self:OffBelt(station)
		self:RefreshSeat(station)
		return false, "NoPlate", nil
	end
	const stop = Belt.at(self.Belt, station)
	const seat = Session.new(player, station, workspace:GetServerTimeNow(), os.clock(), stopTab(stop), "Belt")
	seat.PlateId = state.Id
	seat.Ticket = math.clamp(state.Ticket, 0, MAX_TICKET)
	seat.Line = math.clamp(state.Line, 0, 2)
	seat.Mask = maskOf(state)
	self:Sit(player, seat)
	return true, "None", station
end

-- (ok, reason, station). prep_grill / PrepEnter on the grill seat. A plate in the hand stays in the hand
function PrepService:EnterGrill(player: Player, requested: number?, skipReach: boolean?): (boolean, string, number?)
	const reason, station = self:CheckGrill(player, requested, skipReach)
	if reason ~= "None" or station == nil then
		return false, if reason == "None" then "Invalid" else reason, nil
	end
	self:Sit(player, Session.new(player, station, workspace:GetServerTimeNow(), os.clock(), "Grill", "Grill"))
	return true, "None", station
end

-- The seat's plate state, nil (with the seat's plate dropped) when it is gone
function PrepService:BeltPlate(seat: Session.Seat): Bridge.PlateState?
	const id = seat.PlateId
	if id == nil then
		return nil
	end
	return Bridge.PlateOf(self.Dependencies.PlateService, id)
end

-- The focus ends by itself once the plate sits in Out (after Rules.DoneHold, like the seal of the trailer)
function PrepService:EndAtOut(player: Player, seat: Session.Seat)
	task.delay(rules.DoneHold, function()
		if self.Sessions[player] ~= seat then
			return
		end
		const stop = Belt.at(self.Belt, seat.Station)
		if stop == Belt.exit(self.Belt) then
			self:Release(player, "None", nil)
		end
	end)
end

-- PrepBelt: one stop for the seat's own plate. (ok, reason, stop)
function PrepService:MoveBelt(player: Player, seat: Session.Seat, dir: string): (boolean, string, number)
	if seat.Kind ~= "Belt" or seat.PlateId == nil then
		return false, "WrongStop", 0
	end
	if dir ~= "Left" and dir ~= "Right" then
		return false, "Invalid", 0
	end
	const ok, stop, _wait, promoted = Belt.move(self.Belt, seat.Station, dir)
	if not ok then
		return false, "Invalid", stop
	end
	seat.Step = stopTab(stop)
	self:RefreshSeat(seat.Station)
	self:Promoted(promoted)
	const problem = Belt.problem(self.Belt)
	if problem ~= nil then
		warn(`[PrepService] belt invariant broken: {problem}`)
	end
	if stop == Belt.exit(self.Belt) then
		self:EndAtOut(player, seat)
	end
	return true, "None", stop
end

-- PrepStage: Cut (the bun) / Dog (a rest table sausage) on the Board stop, all or nothing. (ok, reason)
function PrepService:Stage(player: Player, seat: Session.Seat, stage: string, score: number, slot: number): (boolean, string)
	if not self.Dependencies.RoundService:IsServing() then
		return false, "NotSelling"
	end
	if seat.Kind ~= "Belt" or not Belt.canWork(self.Belt, seat.Station, "Board") then
		return false, "WrongStop"
	end
	const state = self:BeltPlate(seat)
	if state == nil then
		return false, "NoSession"
	end
	if state.Grade ~= nil then
		return false, "PlateDone"
	end
	const plates = self.Dependencies.PlateService
	const kitchen = self.Dependencies.KitchenService
	const whole = math.clamp(math.floor(score), 0, 100)
	if stage == "Cut" then
		if state.Bun then
			return false, "Invalid"
		end
		const ok, reason, preCut = Bridge.Cut(kitchen, player)
		if not ok then
			return false, reason
		end
		const patch: Bridge.PlatePatch = { Bun = true, Cut = whole, StartedAt = os.clock() }
		if preCut then
			patch.Altered = true
		end
		if not Bridge.Commit(plates, state.Id, patch) then
			warn(`[PrepService] the bun of plate {state.Id} left the stock but the commit failed`)
			return false, "NoSession"
		end
	elseif stage == "Dog" then
		if not state.Bun or state.Dog then
			return false, "Invalid"
		end
		if slot < 1 or slot > conveyor.Rest.Capacity then
			return false, "Invalid"
		end
		if self:HeldByOther(seat, "Rail", slot) then
			return false, "Held"
		end
		const ok, reason, entry = Bridge.Dog(kitchen, player, slot)
		if not ok or entry == nil then
			return false, reason
		end
		self:SausageLeft("Rail", slot)
		-- the flip stamp of the grill travels with the sausage into the plate (paid once at the sale, TASK-517)
		const patch: Bridge.PlatePatch = { Dog = true, Place = whole, FlipBonus = entry.Flip }
		if entry.Altered then
			patch.Altered = true
		end
		if not Bridge.Commit(plates, state.Id, patch) then
			warn(`[PrepService] the rest table sausage {slot} left for plate {state.Id} but the commit failed`)
			return false, "NoSession"
		end
	else
		return false, "Invalid"
	end
	const after = Bridge.PlateOf(plates, state.Id)
	seat.Mask = if after ~= nil then maskOf(after) else seat.Mask
	self:RefreshSeat(seat.Station)
	return true, "None"
end

-- PrepFinish on the Toppings stop: graded by Grade only, with the Cut / Place the server stored (the summary's are ignored)
-- and without the sausage (P13). The plate goes to Out and the focus ends. (ok, reason, grade, value)
function PrepService:FinishBelt(player: Player, seat: Session.Seat, summary: Validate.Summary): (boolean, string, string, number)
	if not self.Dependencies.RoundService:IsServing() then
		return false, "NotSelling", "None", 0
	end
	if seat.Kind ~= "Belt" or not Belt.canWork(self.Belt, seat.Station, "Toppings") then
		return false, "WrongStop", "None", 0
	end
	const state = self:BeltPlate(seat)
	if state == nil then
		return false, "NoSession", "None", 0
	end
	if state.Grade ~= nil then
		return false, "PlateDone", "None", 0
	end
	if not state.Bun or not state.Dog then
		return false, "Invalid", "None", 0
	end
	if type(summary) ~= "table" then
		return false, "Invalid", "None", 0
	end
	const kitchen = self.Dependencies.KitchenService
	-- the plate never expires (TASK-289): its age is read at most TutorialPlateAge, like a trailer plate kept young
	const elapsed = math.min(os.clock() - (state.StartedAt or 0), rules.TutorialPlateAge)
	const ms = if type(summary.Ms) == "number" then summary.Ms else 0
	const graded: Validate.Summary = {
		Cut = math.clamp(math.floor(state.Cut or 0), 0, 100),
		Place = math.clamp(math.floor(state.Place or 0), 0, 100),
		Toppings = summary.Toppings,
		Ms = math.clamp(math.floor(math.min(ms, elapsed * 1000)), 0, 120000),
		Sauces = summary.Sauces,
	}
	const stock: Validate.Stock = {
		Amount = function(key: string): number
			return (kitchen:GetStock(key))
		end,
		IsBlocked = function(key: string): boolean
			return kitchen:IsBlocked(key)
		end,
	}
	const verdict, reason, value = Validate.Summary(cfg, graded, elapsed, nil, stock)
	if verdict == nil then
		return false, reason, "None", value
	end
	const ok, refusal = Bridge.Toppings(kitchen, player, verdict.Keys)
	if not ok then
		return false, refusal, "None", 0
	end
	const plates = self.Dependencies.PlateService
	if not Bridge.Commit(plates, state.Id, { Toppings = verdict.Keys, Grade = verdict.Band, Sauce = self:SauceOf(summary, verdict.Keys) }) then
		warn(`[PrepService] the toppings of plate {state.Id} left the stock but the commit failed`)
		return false, "NoSession", "None", 0
	end
	seat.Mask = PlateMask.Pack({ Cut = true, Sausage = true, Toppings = verdict.Keys })
	self:Promoted(Belt.finish(self.Belt, seat.Station))
	seat.Step = stopTab(Belt.exit(self.Belt))
	self:RefreshSeat(seat.Station)
	self:EndAtOut(player, seat)
	return true, "None", verdict.Band, Grade.Points(cfg, verdict.Band)
end

-- PrepTrash From = Plate on the belt (§6.6): the content is lost, the plate stays on the belt with its ticket
function PrepService:TrashBelt(seat: Session.Seat): (boolean, string)
	if seat.Kind ~= "Belt" or seat.PlateId == nil then
		return false, "NoSession"
	end
	const plates = self.Dependencies.PlateService
	const state = Bridge.PlateOf(plates, seat.PlateId :: number)
	if state == nil then
		return false, "NoSession"
	end
	if not state.Bun and not state.Dog then
		return false, "NoSession"
	end
	if not Bridge.Empty(plates, state.Id) then
		return false, "Invalid"
	end
	seat.Mask = 0
	self:RefreshSeat(seat.Station)
	return true, "None"
end

-- Conveyor mask of PrepTab: only topping bits that grow, on top of the bun / sausage bits the server wrote, on the Toppings
-- stop. Cosmetic (the Finish grades); a mask that does not fit is ignored.
function PrepService:AcceptBeltMask(seat: Session.Seat, mask: number)
	if mask == seat.Mask or seat.Kind ~= "Belt" or not Belt.canWork(self.Belt, seat.Station, "Toppings") then
		return
	end
	if not PlateMask.Valid(seat.Mask, mask, Content.OrderRules.MaxToppings) then
		return
	end
	const old = PlateMask.Unpack(seat.Mask)
	const new = PlateMask.Unpack(mask)
	if new.Cut ~= old.Cut or new.Sausage ~= old.Sausage or not new.Sausage then
		return
	end
	seat.Mask = mask
	self:RefreshSeat(seat.Station)
end

-- 2 Hz: a belt plate that is gone (an empty orphan, PlateService:Release) ends the seat; a ticket that changed (orphan) is
-- republished; parked plates go to the table past ParkMax, back to the hand when the shop closes
function PrepService:SweepBelt(now: number, selling: boolean)
	for player, seat in table.clone(self.Sessions) do
		if self.Sessions[player] ~= seat or seat.Kind ~= "Belt" or seat.PlateId == nil then
			continue
		end
		const state = self:BeltPlate(seat)
		if state == nil then
			seat.PlateId = nil
			self:OffBelt(seat.Station)
			self:Release(player, "None", nil)
		elseif state.Ticket ~= seat.Ticket or state.Line ~= seat.Line then
			seat.Ticket = math.clamp(state.Ticket, 0, MAX_TICKET)
			seat.Line = math.clamp(state.Line, 0, 2)
			self:RefreshSeat(seat.Station)
		end
	end
	const plates = self.Dependencies.PlateService
	for player, parked in table.clone(self.Away) do
		if self.Away[player] ~= parked then
			continue
		end
		const state = Bridge.PlateOf(plates, parked.PlateId)
		if state == nil then
			self:DropParked(player, "Gone")
		elseif player.Parent == nil or now - parked.Since > conveyor.ParkMax then
			self:DropParked(player, "Shelve")
		elseif not selling then
			self:DropParked(player, "Hand")
		elseif state.Ticket ~= parked.Ticket then
			parked.Ticket = math.clamp(state.Ticket, 0, MAX_TICKET)
			self:RefreshSeat(parked.Station)
		end
	end
end

-- ShiftStarted: PlateService:Clear() wiped every plate, so the belt starts empty
function PrepService:ResetBelt()
	self.Belt = Belt.new(beltStops())
	self.Away = {}
	self.AwayBySeat = {}
	for _, seat in self.Sessions do
		if seat.Kind == "Belt" then
			seat.PlateId = nil
		end
	end
	for station = 1, self.Count do
		self:RefreshSeat(station)
	end
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
	self.Replied:Fire(player, act, ok, reason, grade, value)
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

-- Rate gate of the live drag packets (DEC-259): own bucket, outside GLOBAL_RATE
function PrepService:AllowOwn(player: Player, kind: string, rate: number): boolean
	local buckets = self.Buckets[player]
	if buckets == nil then
		buckets = {}
		self.Buckets[player] = buckets
	end
	return Session.Allow(buckets, kind, rate, os.clock())
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

-- "None" | reason: the checks of every seat (mode on, not seated, selling, a live free character, no re-entry lock)
function PrepService:CheckCommon(player: Player): string
	if not self.Active or not rules.Enabled then
		return "Locked"
	end
	if self.Sessions[player] ~= nil then
		return "Seated"
	end
	if not self.Dependencies.RoundService:IsServing() then
		return "NotSelling"
	end
	const characters = self.Dependencies.CharacterService
	if
		not self.Dependencies.RunStateService:IsActive(player)
		or characters:CharacterOf(player) == nil
		or characters:IsFainted(player)
		or characters:IsKnocked(player)
		or characters:IsFrozen(player)
	then
		return "Locked"
	end
	if (self.LockedUntil[player] or 0) > os.clock() then
		return "Locked"
	end
	return "None"
end

-- The player stands within the radius of a prompt of `action` (the PrepEnter packet path; a map without the prompt passes)
function PrepService:InReach(player: Player, action: string): boolean
	const root = self.Dependencies.InteractionService:RootOf(player)
	if root == nil then
		return false
	end
	const distance = self:WorkDistance(root.Position, action)
	return distance == nil or distance <= Content.Actions.ByKey[action].Radius + RANGE_SLACK
end

-- ("None" | reason, stand). Everything PrepEnter and the prompt check before committing (trailer).
function PrepService:CheckEnter(player: Player, station: number, skipReach: boolean?, step: string?): (string, CFrame?)
	if station < 1 or station > self.Count then
		const common = self:CheckCommon(player)
		return if common ~= "None" then common else "NoStation", nil
	end
	const common = self:CheckCommon(player)
	if common ~= "None" then
		return common, nil
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
	-- conveyor: the station asked for picks the role (prep-conveyor.md §2.2, PrepEnter of dev and old clients)
	if CONVEYOR then
		if self:IsGrillSeat(station) then
			const ok, reason = self:EnterGrill(player, station, skipReach)
			return ok, reason
		elseif self:IsBeltSeat(station) then
			const ok, reason = self:EnterBelt(player, station, skipReach)
			return ok, reason
		end
		const common = self:CheckCommon(player)
		return false, if common ~= "None" then common else "NoStation"
	end
	const reason, stand = self:CheckEnter(player, station, skipReach, step)
	if reason ~= "None" then
		return false, reason
	end
	const now = os.clock()
	const serverTime = workspace:GetServerTimeNow()
	const seat = Session.new(player, station, serverTime, now, step or DEFAULT_STEP)
	-- TASK-260: the plate this player left on the board comes back with the seat
	const parked = self.Parked[player]
	if parked ~= nil then
		self.Parked[player] = nil
		seat.Plate = parked.Plate
		seat.Mask = parked.Mask
	end
	self.Sessions[player] = seat
	self.BySeat[station] = seat
	self:PublishSeat(seat)

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
	self:DropPlayerClaims(player)
	const plate = seat.Plate
	seat.Plate = nil
	-- TASK-260: the plate stays parked on the board unless it can never come back (player gone, shop closed)
	const keep = plate ~= nil and silent ~= true and reason ~= "KickAway" and reason ~= "KickClosing"
		and self.Dependencies.RoundService:IsServing()
	if plate ~= nil and keep then
		self.Parked[player] = { Plate = plate, Mask = seat.Mask }
	elseif plate ~= nil and plate.Reserved then
		const ok, problem = pcall(Bridge.Refund, self.Dependencies.KitchenService, player)
		if not ok then
			warn(`[PrepService] refund of seat {seat.Station} errored: {problem}`)
		end
	end
	if seat.Kind == "Belt" then
		-- conveyor: the plate parks on the belt, goes back to the hand or to the central table (prep-conveyor.md §2.3)
		self:LeaveBelt(player, seat, reason, silent)
		self:RefreshSeat(seat.Station)
	elseif seat.Kind == "Grill" then
		self:RefreshSeat(seat.Station)
	elseif self.Seats()[seat.Station] ~= nil then
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
		-- Delivery = "Prompt": the hot dog just made is in the hand when the mode ends; the customer's `serve` prompt delivers it
		const made = seat.Made
		if reason == "None" and made ~= nil and rules.Delivery == "Prompt" then
			const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid ~= nil and humanoid.Health > 0 and made.Parent ~= nil and made:IsDescendantOf(player) then
				humanoid:EquipTool(made)
			end
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
	if not self.Dependencies.RoundService:IsServing() then
		return false, "NotSelling", 0
	end
	if seat.Plate ~= nil then
		return false, "Invalid", 0
	end
	const ok, reason, preCut = Bridge.Begin(self.Dependencies.KitchenService, player, seat.Station)
	if not ok then
		return false, reason, 0
	end
	seat.Plate = { StartedAt = os.clock(), Reserved = true, PreCut = preCut }
	self:ClearMask(seat)
	-- Value 1 = the bun came already sliced (ANM-002 altered bun): the client skips the cut
	return true, "None", if preCut then 1 else 0
end

-- (ok, reason, grade, value). The summary is checked and the transaction runs; a refusal leaves the plate open and the
-- stock, rail and board untouched (a plate past PlateMax is dropped). The sausage score only exists once the kitchen pops
-- the sausage, so the plate is graded without it for the transaction and graded again with it right after (ItemService
-- SetQuality): the band can only go down, since the sausage adds a stage.
function PrepService:Finish(player: Player, seat: Session.Seat, summary: Validate.Summary): (boolean, string, string, number)
	const plate = seat.Plate
	if plate == nil or not self.Dependencies.RoundService:IsServing() then
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
	-- DEC-259: the plate takes the front of the rail; a colleague dragging that sausage keeps it
	if kitchen:RailCount() >= 1 and self:HeldByOther(seat, "Rail", 1) then
		return false, "Held", "None", 0
	end
	const made, refusal, refusalValue = Bridge.Finish(kitchen, player, verdict.Keys, verdict.Band)
	if made == nil then
		-- Parked: the plate stays; PlateMax counts again from a plausible age (the player already waited the floor)
		plate.StartedAt = os.clock() - math.min(elapsed, rules.PerfectMin + rules.PerTopping * #verdict.Keys)
		return false, refusal, "None", refusalValue
	end
	self:SausageLeft("Rail", 1)
	seat.Plate = nil
	seat.Made = made.Tool
	self:ClearMask(seat)
	-- the sauce line the player drew stays on the hot dog (owner request 2026-10-14): cosmetic, cleaned here
	const sauce = self:SauceOf(summary, verdict.Keys)
	if sauce ~= "" then
		self.Dependencies.ItemService:SetSauce(made.Tool, sauce)
	end
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

-- The drawn sauces of a summary as the Tool attribute (Sauce.Encode), "" = none. Only toppings of this plate made with the
-- trace gesture (Content.Prep.Tolerances), each once, each cleaned (Sauce.Clean: integers in range, bounded, >= 2 points).
function PrepService:SauceOf(summary: Validate.Summary, keys: { string }): string
	const list = summary.Sauces
	if type(list) ~= "table" then
		return ""
	end
	const cleaned: { [string]: { number } } = {}
	for index, entry in list :: { any } do
		if index > Content.OrderRules.MaxToppings or type(entry) ~= "table" then
			break
		end
		const key = entry.Key
		const tolerance = if type(key) == "string" then cfg.Tolerances.ByKey[key] else nil
		if tolerance == nil or tolerance.Gesture ~= "trace" or not table.find(keys, key) or cleaned[key] ~= nil then
			continue
		end
		const points = Sauce.Clean(entry.Points)
		if points ~= nil then
			cleaned[key] = points
		end
	end
	return Sauce.Encode(cleaned)
end

-- Drops the open plate: the reserved bun comes back (PlateMax, Leave) or is lost (bin)
function PrepService:DropPlate(player: Player, seat: Session.Seat)
	const plate = seat.Plate
	seat.Plate = nil
	self:ClearMask(seat)
	if plate ~= nil and plate.Reserved then
		Bridge.Refund(self.Dependencies.KitchenService, player)
	end
	self:Reply(player, "Trash", false, "NoSession", nil, nil)
end

function PrepService:Trash(player: Player, seat: Session.Seat): (boolean, string)
	const plate = seat.Plate
	const kitchen = self.Dependencies.KitchenService
	-- DEC-259: an open plate goes to the bin with the front sausage of the rail; not while a colleague drags that one
	const railBefore = kitchen:RailCount()
	if plate ~= nil and railBefore >= 1 and self:HeldByOther(seat, "Rail", 1) then
		return false, "Held"
	end
	seat.Plate = nil
	self:ClearMask(seat)
	const bridge = Bridge.Trash(kitchen, self.Dependencies.ItemService, player, plate ~= nil)
	if kitchen:RailCount() < railBefore then
		self:SausageLeft("Rail", 1)
	end
	if plate == nil and not bridge then
		return false, "NoSession"
	end
	return true, "None"
end

-- The bin by drag, for a sausage: Grill = the sausage of that grill slot, Rail = the one at that rail position. A rail sausage the
-- open plate still needs (it is taken at Finish) is not thrown: the last one stays while a plate is open.
function PrepService:TrashSausage(player: Player, seat: Session.Seat, from: string, slot: number): (boolean, string)
	if slot < 1 or slot > 8 then
		return false, "Invalid"
	end
	if from == "Rail" and seat.Plate ~= nil and self.Dependencies.KitchenService:RailCount() <= 1 then
		return false, "Busy"
	end
	if self:HeldByOther(seat, from, slot) then
		return false, "Held"
	end
	const ok, reason = Bridge.TrashSausage(self.Dependencies.KitchenService, player, from, slot)
	if ok then
		self:SausageLeft(from, slot)
	end
	return ok, reason
end

-- Live drag (DEC-259) ---------------------------------------------------------------------------------------------------

-- Copies the claims atom into the PrepClaims set; renewals never reach it (only the holder station is on the wire)
function PrepService:PushClaims()
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const set = self.Libs.Net.PrepClaims
	const claims = self.Claims()
	for id, claim in claims do
		const published = self.ClaimsPublished[id]
		if published == nil then
			set:add(id, { Station = claim.Station })
		elseif published ~= claim.Station then
			set:update(id, { Station = claim.Station })
		end
		self.ClaimsPublished[id] = claim.Station
	end
	for id in self.ClaimsPublished do
		if claims[id] == nil then
			set:remove(id)
			self.ClaimsPublished[id] = nil
		end
	end
end

-- Removes every claim `drop` says yes to (one atom write at most)
function PrepService:DropClaims(drop: (id: number, claim: Claim) -> boolean)
	const claims = self.Claims()
	local nextClaims: { [number]: Claim }? = nil
	for id, claim in claims do
		if drop(id, claim) then
			const edited = nextClaims or table.clone(claims)
			edited[id] = nil
			nextClaims = edited
			self.Leases[id] = nil
		end
	end
	if nextClaims ~= nil then
		self.Claims(table.freeze(nextClaims))
	end
end

function PrepService:DropPlayerClaims(player: Player)
	self:DropClaims(function(_id: number, claim: Claim): boolean
		return claim.Player == player
	end)
end

-- The sausage of a grill slot / rail position is gone. Rail positions are a queue (1 = front): the claims behind it move
-- one place forward so each claim keeps following its sausage.
function PrepService:SausageLeft(from: string, slot: number)
	const gone = claimId(from, slot)
	if gone == nil then
		return
	end
	if from ~= "Rail" then
		self:DropClaims(function(id: number, _claim: Claim): boolean
			return id == gone
		end)
		return
	end
	const claims = self.Claims()
	const nextClaims: { [number]: Claim } = {}
	const nextLeases: { [number]: number } = {}
	local changed = false
	for id, claim in claims do
		local target = id
		const kind, position = claimSlot(id)
		if kind == "Rail" and position == slot then
			changed = true
			continue
		elseif kind == "Rail" and position > slot then
			target = id - 1
			changed = true
		end
		nextClaims[target] = claim
		nextLeases[target] = self.Leases[id]
	end
	if changed then
		self.Leases = nextLeases
		self.Claims(table.freeze(nextClaims))
	end
end

-- A sausage sits at that grill slot / rail position right now
function PrepService:HasSausage(from: string, slot: number): boolean
	const kitchen = self.Dependencies.KitchenService
	if from == "Rail" then
		return slot <= kitchen:RailCount()
	end
	const grill = kitchen:CurrentStation(GRILL_KIND)
	const record = if grill ~= nil then grill.Records[slot] else nil
	return record ~= nil and record.State ~= "Empty"
end

-- Another seat holds that sausage (a live claim)
function PrepService:HeldByOther(seat: Session.Seat, from: string, slot: number): boolean
	const id = claimId(from, slot)
	const claim = if id ~= nil then self.Claims()[id] else nil
	return claim ~= nil and claim.Station ~= seat.Station and (self.Leases[id :: number] or 0) > os.clock()
end

-- (ok, reason, claim id). On: free or already ours = claimed (lease renewed, any other claim of the seat dropped: one hand);
-- held by another seat = Held; no sausage there = Invalid. Off: always Ok, drops the claim when it is ours.
function PrepService:Grab(seat: Session.Seat, from: string, slot: number, on: boolean): (boolean, string, number)
	const id = claimId(from, slot)
	if id == nil then
		return false, "Invalid", 0
	end
	const claim = self.Claims()[id]
	if not on then
		if claim ~= nil and claim.Station == seat.Station then
			self:DropClaims(function(other: number, _claim: Claim): boolean
				return other == id
			end)
		end
		return true, "None", id
	end
	if self:HeldByOther(seat, from, slot) then
		return false, "Held", id
	end
	if not self:HasSausage(from, slot) then
		return false, "Invalid", id
	end
	self.Leases[id] = os.clock() + ghost.GrabLease
	if claim ~= nil and claim.Station == seat.Station and claim.Player == seat.Player then
		return true, "None", id
	end
	const nextClaims = table.clone(self.Claims())
	for other, held in nextClaims do
		if held.Station == seat.Station and other ~= id then
			nextClaims[other] = nil
			self.Leases[other] = nil
		end
	end
	const record: Claim = { Station = seat.Station, Player = seat.Player }
	nextClaims[id] = table.freeze(record :: any)
	self.Claims(table.freeze(nextClaims))
	return true, "None", id
end

-- Where the seat's board is (the pointer reach check): its board slot, else the board, else the seat's stand
function PrepService:BoardPoint(station: number): Vector3?
	-- conveyor: no board per seat; the bench is measured from the seat's foot (Ghost.MaxDistance covers the bench)
	if CONVEYOR then
		const stand = self:StandOf(station, nil)
		return if stand ~= nil then stand.Position else nil
	end
	const board = self.Dependencies.KitchenService:CurrentStation(BOARD_KIND)
	if board ~= nil then
		const slot = board.Slots[station]
		if slot ~= nil and slot.Parent ~= nil then
			return slot.WorldPosition
		end
		return board.Instance:GetPivot().Position
	end
	const stand = self:StandOf(station, nil)
	return if stand ~= nil then stand.Position else nil
end

-- Relays a seated player's pointer to the rest of the party. A pointer too far from the seat's board (or without a board to
-- check against) is dropped silently; one that holds something keeps the seat's claims alive.
function PrepService:OnPointer(player: Player, tool: string, topping: string?, pos: Vector3)
	const seat = self.Sessions[player]
	if seat == nil or not rules.World.GhostHand then
		return
	end
	const board = self:BoardPoint(seat.Station)
	-- `not <=` also drops NaN
	if board == nil or not ((pos - board).Magnitude <= ghost.MaxDistance) then
		return
	end
	const now = os.clock()
	Session.Touch(seat, now)
	if tool ~= "None" then
		for id, claim in self.Claims() do
			if claim.Player == player then
				self.Leases[id] = now + ghost.GrabLease
			end
		end
	end
	const others: { Player } = {}
	for userId, member in self.Dependencies.RunStateService.Members() do
		if userId ~= player.UserId and member.State ~= "Away" then
			const other = Players:GetPlayerByUserId(userId)
			if other ~= nil then
				table.insert(others, other)
			end
		end
	end
	if #others == 0 then
		return
	end
	const payload: any = { Station = seat.Station, Tool = tool, Topping = topping, Pos = pos }
	self.Libs.Net.PrepGhost:fireClient(others, payload)
end

-- Claims past their lease, of a player no longer seated, or whose sausage left the slot by a path PrepService does not see
-- (world prompts, anomalies)
function PrepService:SweepClaims(now: number)
	self:DropClaims(function(id: number, claim: Claim): boolean
		const from, slot = claimSlot(id)
		return (self.Leases[id] or 0) <= now or self.Sessions[claim.Player] == nil or not self:HasSausage(from, slot)
	end)
end

-- Packets ---------------------------------------------------------------------------------------------------------------

-- Plate mask of PrepTab (prep-3d.md §7.2 N3). Cosmetic, never authority (PrepFinish revalidates everything), so a mask that
-- does not fit is IGNORED without an answer. It must: come with an open plate, only grow, carry no bit without a key and at
-- most MaxToppings topping bits (PlateMask.Valid), keep the order of the work (a sausage needs the cut unless the bun came
-- sliced, toppings need the sausage) and not outrun the clock (nothing before Rules.MinPlate on the server clock).
function PrepService:AcceptMask(seat: Session.Seat, mask: number)
	if mask == seat.Mask then
		return
	end
	const plate = seat.Plate
	if plate == nil then
		return
	end
	if not PlateMask.Valid(seat.Mask, mask, Content.OrderRules.MaxToppings) then
		return
	end
	const unpacked = PlateMask.Unpack(mask)
	if unpacked.Sausage and not (unpacked.Cut or plate.PreCut == true) then
		return
	end
	if #unpacked.Toppings > 0 and not unpacked.Sausage then
		return
	end
	if not (Grade.Plausible(cfg, 0, os.clock() - plate.StartedAt, 0)) then
		return
	end
	seat.Mask = mask
	self:PublishSeat(seat)
	-- TASK-260: the same mask on the board model, for every player
	self.Dependencies.KitchenService:SetPlateMask(seat.Player, mask)
end

function PrepService:OnTab(player: Player, step: string, ticket: number, plate: number?)
	const seat = self:Seated(player, "Tab")
	if seat == nil then
		return
	end
	const key = resolveTab(step)
	if ticket < 0 or ticket > MAX_TICKET or key == nil then
		self:Reply(player, "Tab", false, "Invalid", nil, nil)
		return
	end
	-- conveyor (network.md §19.2): keep-alive and topping mask only; the tab comes from the stop, the ticket from the plate
	if CONVEYOR then
		if plate ~= nil then
			self:AcceptBeltMask(seat, plate)
		end
		return
	end
	if seat.Step ~= key or seat.Ticket ~= ticket then
		seat.Step = key
		seat.Ticket = ticket
		self:PublishSeat(seat)
	end
	if plate ~= nil then
		self:AcceptMask(seat, plate)
	end
end

function PrepService:OnGrill(player: Player, act: string, slot: number)
	const seat = self:Seated(player, "Grill")
	if seat == nil then
		return
	end
	if not self.Dependencies.RoundService:IsServing() then
		self:Reply(player, "Grill", false, "NotSelling", nil, nil)
		return
	end
	-- conveyor: only the grill seat grills (DEC-305: the assembler leaves the belt and takes the Grill prompt)
	if CONVEYOR and seat.Kind ~= "Grill" then
		self:Reply(player, "Grill", false, "WrongStop", nil, nil)
		return
	end
	-- the tutorial teaches one sausage at a time (owner request 2026-10-14): a second Place is refused until the first one is off the grill
	if act == "Place" and self.Dependencies.TutorialService:IsPending(player) and self.Dependencies.KitchenService:GrillBusy() > 0 then
		self:Reply(player, "Grill", false, "OneSausage", nil, nil)
		return
	end
	-- DEC-259: a sausage a colleague drags is not flipped nor collected by anyone else
	if act ~= "Place" and slot > 0 and self:HeldByOther(seat, "Grill", slot) then
		self:Reply(player, "Grill", false, "Held", nil, slot)
		return
	end
	const outcome = Bridge.Grill(self.Dependencies.KitchenService, player, act, slot)
	if outcome.Ok and act == "Collect" then
		self:SausageLeft("Grill", slot)
	end
	self:Reply(player, "Grill", outcome.Ok, outcome.Reason, outcome.Grade, outcome.Value)
end

function PrepService:OnFinish(player: Player, summary: Validate.Summary)
	const seat = self:Seated(player, "Finish")
	if seat == nil then
		return
	end
	if CONVEYOR then
		const ok, reason, grade, value = self:FinishBelt(player, seat, summary)
		self:Reply(player, "Finish", ok, reason, grade, value)
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
	if not self.Dependencies.RoundService:IsServing() then
		self:Reply(player, "Order", false, "NotSelling", nil, nil)
		return
	end
	-- the hot dog this seat just made, while it is still the player's (the plate dropped on the customer, 2026-10-14)
	const made = seat.Made
	const own = if made ~= nil and made.Parent ~= nil and made:IsDescendantOf(player) then made else nil
	const outcome = Bridge.Order(self.Dependencies.CustomerService, player, act, npc, own)
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
		self:OnTab(player, value.Step, value.Ticket, value.Plate)
	end)
	net.PrepGrill:onServer(function(value, player: Player)
		if not self:Allow(player, "Grill") then
			-- TASK-257: never silent, the client pairs every grill act with its answer
			self:Reply(player, "Grill", false, "Busy", nil, nil)
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
		-- conveyor: the plate comes from the hand and the bun from PrepStage Cut (prep-conveyor.md §6.5)
		if CONVEYOR then
			self:Reply(player, "Begin", false, "Invalid", nil, nil)
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
	net.PrepTrash:onServer(function(value, player: Player)
		if not self:Allow(player, "Trash") then
			return
		end
		const seat = self:Seated(player, "Trash")
		if seat == nil then
			return
		end
		const from: string = value.From
		const index = table.find(cfg.TrashFrom, from) or 1
		if from == "Plate" and CONVEYOR then
			const ok, reason = self:TrashBelt(seat)
			self:Reply(player, "Trash", ok, reason, nil, 0)
		elseif from == "Plate" then
			const ok, reason = self:Trash(player, seat)
			self:Reply(player, "Trash", ok, reason, nil, 0)
		else
			const ok, reason = self:TrashSausage(player, seat, from, value.Slot)
			self:Reply(player, "Trash", ok, reason, nil, index - 1)
		end
	end)
	net.PrepOrder:onServer(function(value, player: Player)
		if not self:Allow(player, "Order") then
			return
		end
		-- conveyor: orders are the tablet's and the PICKUP's (network.md §19.2)
		if CONVEYOR then
			self:Reply(player, "Order", false, "Locked", nil, nil)
			return
		end
		self:OnOrder(player, value.Act, value.Npc)
	end)
	-- Conveyor (TASK-514): own buckets at Conveyor.Rates, outside GLOBAL_RATE; every packet is answered (PrepResult Belt / Stage)
	net.PrepBelt:onServer(function(value, player: Player)
		if not self:AllowOwn(player, "Belt", conveyor.Rates.Belt) then
			self:Reply(player, "Belt", false, "Rate", nil, nil)
			return
		end
		if not CONVEYOR then
			self:Reply(player, "Belt", false, "Locked", nil, nil)
			return
		end
		const seat = self:Seated(player, "Belt")
		if seat == nil then
			return
		end
		const ok, reason, stop = self:MoveBelt(player, seat, value.Dir)
		self:Reply(player, "Belt", ok, reason, nil, stop)
	end)
	net.PrepStage:onServer(function(value, player: Player)
		if not self:AllowOwn(player, "Stage", conveyor.Rates.Stage) then
			self:Reply(player, "Stage", false, "Rate", nil, nil)
			return
		end
		if not CONVEYOR then
			self:Reply(player, "Stage", false, "Locked", nil, nil)
			return
		end
		const seat = self:Seated(player, "Stage")
		if seat == nil then
			return
		end
		const ok, reason = self:Stage(player, seat, value.Stage, value.Score, value.Slot)
		self:Reply(player, "Stage", ok, reason, nil, if ok then value.Score else nil)
	end)
	-- DEC-259: live drag. The pointer never answers (newest at Ghost.Hz); a grab always does (the client pairs it)
	net.PrepPointer:onServer(function(value, player: Player)
		if not self:AllowOwn(player, "Pointer", ghost.Hz * POINTER_SLACK) then
			return
		end
		self:OnPointer(player, value.Tool, value.Topping, value.Pos)
	end)
	net.PrepGrab:onServer(function(value, player: Player)
		if not self:AllowOwn(player, "Grab", GRAB_RATE) then
			self:Reply(player, "Grab", false, "Rate", nil, nil)
			return
		end
		const seat = self:Seated(player, "Grab")
		if seat == nil then
			return
		end
		const ok, reason, id = self:Grab(seat, value.From, value.Slot, value.On)
		self:Reply(player, "Grab", ok, reason, nil, id)
	end)
end

-- Prompt and gate -----------------------------------------------------------------------------------------------------

function PrepService:RegisterWork()
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction(WORK_ACTION, {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			-- conveyor: Prompt_Work of the bench = a belt seat (needs a plate); the Work prompts of old Station_n models are off
			if CONVEYOR then
				if self:StationOfAnchor(anchor) ~= nil then
					return false
				end
				const reason = self:CheckBelt(player, nil, true)
				if reason ~= "None" then
					self:Reply(player, "Enter", false, reason, nil, nil)
					return false
				end
				return true
			end
			if self:StepOfAnchor(anchor) ~= DEFAULT_STEP then
				return false
			end
			-- any Work prompt gives the next free seat (the seats are logical, DEC-224)
			const reason = self:CheckEnter(player, self:NextSeat() or 1, true, self:StepOfAnchor(anchor))
			if reason ~= "None" then
				self:Reply(player, "Enter", false, reason, nil, nil)
				return false
			end
			return true
		end,
		-- TASK-354: the grill prompt follows the player along the counter (client), so the range is measured from there
		Reach = function(_player: Player, anchor: Instance, root: Vector3): Vector3?
			if CONVEYOR then
				return nil
			end
			const at = self.Dependencies.InteractionService:Position(anchor)
			if at == nil or not WorkSlide.Applies(anchor) then
				return nil
			end
			return WorkSlide.Position(anchor, at, root)
		end,
		Run = function(player: Player, anchor: Instance, _id: number)
			if CONVEYOR then
				const ok, reason, seated = self:EnterBelt(player, nil, true)
				self:Reply(player, "Enter", ok, reason, nil, seated)
				return
			end
			const station = self:NextSeat() or 1
			-- the mode opens on the part of the counter the player stands at (the grill prompt slides along all of it)
			const root = self.Dependencies.InteractionService:RootOf(player)
			const near = if root ~= nil then self:StepNear(station, root.Position) else nil
			const ok, reason = self:Enter(player, station, true, near or self:StepOfAnchor(anchor))
			self:Reply(player, "Enter", ok, reason, nil, if ok then station else nil)
		end,
	})
	-- conveyor (DEC-305): Prompt_Grill = the grill seat; off in the trailer (SilenceSpareWork) and refused there
	interaction:RegisterAction(GRILL_ACTION, {
		Validate = function(player: Player, _anchor: Instance, _id: number): boolean
			if not CONVEYOR then
				return false
			end
			const reason = self:CheckGrill(player, nil, true)
			if reason ~= "None" then
				self:Reply(player, "Enter", false, reason, nil, nil)
				return false
			end
			return true
		end,
		Run = function(player: Player, _anchor: Instance, _id: number)
			const ok, reason, seated = self:EnterGrill(player, nil, true)
			self:Reply(player, "Enter", ok, reason, nil, seated)
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

-- Every 0.5 s: disconnected, ragdoll / faint / knock / dead, shift phase over, seat idle; open plates kept young (TASK-289)
function PrepService:Sweep()
	const characters = self.Dependencies.CharacterService
	const selling = self.Dependencies.RoundService:IsServing()
	const now = os.clock()
	-- TASK-260: parked plates (left on the board) refund when the shop closes. TASK-289 (owner request 2026-10-14): a plate never
	-- expires by time (it used to past PlateMax): it stays this young, so its Finish always reads a plausible age
	for player, parked in table.clone(self.Parked) do
		if self.Parked[player] ~= parked then
			continue
		end
		parked.Plate.StartedAt = math.max(parked.Plate.StartedAt, now - rules.TutorialPlateAge)
		if not selling then
			self.Parked[player] = nil
			if parked.Plate.Reserved then
				pcall(Bridge.Refund, self.Dependencies.KitchenService, player)
			end
		end
	end
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
			if plate ~= nil then
				-- TASK-289 (owner request 2026-10-14): the plate never expires (first only for the Day 1 rookie), it stays this young
				plate.StartedAt = math.max(plate.StartedAt, now - rules.TutorialPlateAge)
			end
		end
	end
	if CONVEYOR then
		self:SweepBelt(now, selling)
	end
	self:SweepClaims(now)
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
		-- conveyor: a plate parked by a member that went Away goes to the central table (prep-conveyor.md §2.3)
		self:DropParked(player, "Shelve")
	end)
	runState.LifeChanged:Connect(function(userId, _old, new)
		if new == "Active" then
			return
		end
		const player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			self:Release(player, if new == "Away" then "KickAway" else "KickDown", nil)
			if new == "Away" then
				self:DropParked(player, "Shelve")
			end
		end
	end)
	self.Dependencies.RoundService.ShiftStarted:Connect(function(_info)
		self:Recount()
		if CONVEYOR then
			self:ResetBelt()
		end
	end)
	self.Dependencies.RoundService.PhaseChanged:Connect(function(_phase)
		if not self.Dependencies.RoundService:IsServing() then
			self:ForceExitAll("KickClosing")
			-- conveyor: the plates parked on the belt go back to their owners' hands (else the central table)
			for player in table.clone(self.Away) do
				self:DropParked(player, "Hand")
			end
			-- end of the turn: no sausage stays held
			self:DropClaims(function(_id: number, _claim: Claim): boolean
				return true
			end)
		end
	end)
	self.Dependencies.PlayerService.PlayerRemoving:Connect(function(player)
		self:Release(player, "KickAway", true)
		-- conveyor: the plate parked on the belt goes to the central table with its ticket and content
		self:DropParked(player, "Shelve")
		-- a parked plate goes back to the stock (KitchenService refunds the ticket on the same signal)
		self.Parked[player] = nil
		self.Buckets[player] = nil
		self.LockedUntil[player] = nil
	end)
end)

PrepService:OnStart(function(self)
	if not self.Active then
		return
	end
	for _, anchor in CollectionService:GetTagged("Interactable") do
		self:SilenceSpareWork(anchor)
	end
	CollectionService:GetInstanceAddedSignal("Interactable"):Connect(function(anchor: Instance)
		self:SilenceSpareWork(anchor)
	end)
	-- the set is written by the atom: the first run adds the records of the current count
	self:Grow()
	self.Libs.Charm.effect(function()
		self:PushSeats()
	end)
	self.Libs.Charm.effect(function()
		self:PushClaims()
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
	const lines: { string } = { `prep seats: {self.Count} active, selling {tostring(self.Dependencies.RoundService:IsServing())}` }
	for station = 1, self.Count do
		const seat = self.BySeat[station]
		const stop, side = Belt.at(self.Belt, station)
		const beltText = if stop ~= nil then ` belt stop {stop} wait {side}` else ""
		const owner = self.AwayBySeat[station]
		if seat == nil and owner ~= nil then
			table.insert(lines, `  {station}: parked by {owner.Name}{beltText}`)
		elseif seat == nil then
			table.insert(lines, `  {station}: free`)
		elseif seat.Kind ~= "Trailer" then
			table.insert(lines, `  {station}: {seat.Player.Name} {seat.Kind} ticket {seat.Ticket} plate {seat.PlateId or 0}{beltText}`)
		else
			const plate = seat.Plate
			const plateText = if plate ~= nil then `plate open {string.format("%.1f", os.clock() - plate.StartedAt)}s` else "no plate"
			table.insert(lines, `  {station}: {seat.Player.Name} tab {seat.Step} ticket {seat.Ticket}, {plateText}`)
		end
	end
	const problem = Belt.problem(self.Belt)
	if problem ~= nil then
		table.insert(lines, `  BELT INVARIANT BROKEN: {problem}`)
	end
	return table.concat(lines, "\n")
end

-- `prep belt` (TASK-505 wires the command): the table test of Belt.luau. Errors on any failure
function PrepService:DevBelt(): string
	self:DevGuard()
	const passed, total, failures = Belt.test(beltStops())
	for _, name in failures do
		warn(`[prep belt] FAIL {name}`)
	end
	const summary = `prep belt: {passed}/{total} ok, {total - passed} failed`
	if passed ~= total then
		error(summary, 0)
	end
	return summary
end

-- Sits `player` at `station` (dev: no reach check; every other rule applies)
function PrepService:DevEnter(player: Player, station: number, step: string?): string
	self:DevGuard()
	-- `step` = the tab of the prompt it stands in for (Grill or Build, the PromptStep of the real prompts); none = the part of
	-- the counter the player stands at, like the sliding prompt
	local tab = if step ~= nil and VIEW_STAND[step] ~= nil then step else nil
	if tab == nil then
		const root = self.Dependencies.InteractionService:RootOf(player)
		tab = if root ~= nil then self:StepNear(clampStation(station), root.Position) else nil
	end
	const ok, reason = self:Enter(player, clampStation(station), true, tab)
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

-- `prep plate`: the PrepTab.Plate mask rules through the real OnTab path (TASK-195). Needs a seat, no open plate and a shift
-- that sells; opens one plate, checks, and refunds it. Errors on any failure.
function PrepService:DevPlate(player: Player): string
	self:DevGuard()
	const seat = self.Sessions[player]
	if seat == nil then
		return `{player.Name} is not seated: /dev prep enter <n> first`
	end
	if seat.Plate ~= nil then
		return "a plate is open: finish or leave it first"
	end
	local total = 0
	local failed = 0
	local function check(name: string, ok: boolean)
		total += 1
		if not ok then
			failed += 1
			warn(`[prep plate] FAIL {name}`)
		end
	end
	local function send(mask: number?)
		self:OnTab(player, seat.Step, seat.Ticket, mask)
	end
	local function wire(): number
		const record = self.Seats()[seat.Station]
		return if record ~= nil then record.Plate else -1
	end
	const maxToppings = Content.OrderRules.MaxToppings
	const keys = Content.Ingredients.ToppingKeys
	const cut = PlateMask.Pack({ Cut = true })
	const sausage = PlateMask.Pack({ Cut = true, Sausage = true })
	local topped = 0
	local ok, reason = self:Begin(player, seat)
	check(`begin ({reason})`, ok)
	if ok then
		const opened: any = self.Sessions[player]
		const plate: Session.Plate = opened.Plate
		plate.StartedAt = os.clock()
		send(cut)
		check("a mask before Rules.MinPlate is ignored", seat.Mask == 0 and wire() == 0)
		plate.StartedAt = os.clock() - (rules.MinPlate + 0.5)
		send(nil)
		check("nil keeps the mask", seat.Mask == 0)
		send(PlateMask.Pack({ Cut = true, Toppings = { keys[1] } }))
		check("a topping without the sausage is ignored", seat.Mask == 0)
		send(PlateMask.Pack({ Sausage = true }))
		check("a sausage without the cut is ignored", seat.Mask == 0)
		send(cut)
		check("the cut is accepted and replicated", seat.Mask == cut and wire() == cut)
		send(0)
		check("a mask that shrinks is ignored", seat.Mask == cut)
		send(sausage)
		check("the sausage is accepted", seat.Mask == sausage and wire() == sausage)
		local list: { string } = {}
		for index = 1, math.min(maxToppings, #keys) do
			table.insert(list, keys[index])
			topped = PlateMask.Pack({ Cut = true, Sausage = true, Toppings = list })
			send(topped)
		end
		check("up to MaxToppings toppings are accepted", seat.Mask == topped and PlateMask.Count(seat.Mask) == #list)
		if #keys > maxToppings then
			list = table.clone(list)
			table.insert(list, keys[maxToppings + 1])
			send(PlateMask.Pack({ Cut = true, Sausage = true, Toppings = list }))
			check("a topping past MaxToppings is ignored", seat.Mask == topped)
		end
		send(256)
		check("a value past 8 bits is ignored", seat.Mask == topped)
		send(topped - 1 + 0.5)
		check("a fraction is ignored", seat.Mask == topped)
		self:DropPlate(player, seat)
		check("the plate drop zeroes the mask", seat.Mask == 0 and wire() == 0)
		send(cut)
		check("a mask without an open plate is ignored", seat.Mask == 0)
	end
	const summary = `prep plate: {total - failed}/{total} ok, {failed} failed`
	if failed > 0 then
		error(summary, 0)
	end
	return summary
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
	-- conveyor: the plate must sit on the Toppings stop with bun and sausage (the real FinishBelt path)
	if CONVEYOR then
		const toppings: { { Key: string, Score: number } } = {}
		for _, key in keys do
			table.insert(toppings, { Key = key, Score = 100 })
		end
		const state = self:BeltPlate(seat)
		if force and state ~= nil and seat.PlateId ~= nil then
			Bridge.Commit(self.Dependencies.PlateService, seat.PlateId :: number, {
				StartedAt = os.clock() - (rules.PerfectMin + rules.PerTopping * #keys + 0.5),
			})
		end
		const ok, reason, grade, value = self:FinishBelt(player, seat, { Cut = 100, Place = 100, Toppings = toppings, Ms = 0 })
		self:Reply(player, "Finish", ok, reason, grade, value)
		return if ok then `belt finished: {grade} ({value} pts)` else `belt refused: {reason}`
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
