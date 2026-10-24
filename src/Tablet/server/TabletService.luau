--!strict
-- Order tablet of the restaurant (tech/restaurant-flow.md rev. 2 §2.4, §3.2; design FEAT-043; DEC-270; TASK-381, wave
-- R1-D). Run place only, and only with Content.Restaurant.Rules.Enabled: with the flag off nothing is bound and
-- tablet_take is not registered (the published trailer flow is untouched). Single writer of the Net.Restaurant Tablets set.
--
-- Binding (Content.Restaurant.Binding): an Instance tagged TabletTag with TabletIndex = 1 (TAB-1, the head of the counter
-- queue Q1) and the anchor TabletPrompt under it (PromptAction tablet_take; attributes and the Interactable tag set here
-- when the map did not). Records: 1 (TAB-1) and, with Content.Restaurant.Drive.Enabled, Rules.DrivePcIndex = DT-PC (the
-- drive-thru computer, TASK-574: DriveThruService makes the Model when the map has none; its head is the car at the
-- window, CustomerService:DriveFront, and the pickup line is not checked: the car waits at the window). TAB-2 (UPG-027) is
-- ignored with a log.
--
-- Talk (owner 2026-10-22: "tira o botão de refuse... quando ele clicar em take order, ele vai dar aquele close na câmera,
-- vai fazer a animação dele surgindo a anomalia, daí ele vai de fila"; DEC-353's ACCEPT / REFUSE is history): tablet_take
-- (tap, Actions.tablet_take.Radius) with the customer of Q1 in Ordering, the tablet Idle, room on the plates
-- (PlateService:HasRoomFor) and in the pickup line (not CustomerService:IsPickupFull, TASK-380) -> Talking with StartedAt,
-- the order (CustomerService:PendingToppings) on the record and EndsAt = StartedAt + the speech's Duration
-- (Content.OrderSpeech: the customer's hi and order, or its odd line / its tic, typed letter by letter at
-- Tics.Rules.TypeRate with the punctuation pauses, + OrderTalk.Speech.Hold; the client types it on the same clock), the
-- patience clock paused (CustomerService:PausePatience, TASK-380). At EndsAt (a delayed Step, and the 2 Hz tick)
-- CustomerService:TakeOrderFor(user, npc) for EVERY customer, ordinary or anomaly (same gate and write as the old prompt;
-- PlateService puts the ticket on a plate from Acted; what an anomaly does once its order is taken is its module's). If
-- the customer left Q1 or Ordering before that (anomaly, window closed, shift end) the tablet goes back to Idle with no
-- order. Walking away skips the talk through the taker's client (TabletLeave, see Leave below; the server keeps no radius of its
-- own). Another tablet_take during the talk = Notice tablet_busy. Idle with no room = Full ("Kitchen full" lamp for
-- everyone).
-- Attendant gone mid-talk (R-8, docs/tests/restaurant-e2e.md; design FEAT-043 "afastar cancela, a paciência volta a
-- correr" / "cancela sem criar pedido nem cobrar"): when the player who started the talk leaves the server or stops being
-- an active member (Down, spectator), the talk is CANCELLED at once (Reset): no order, no charge, the customer keeps Q1 in
-- Ordering with its patience running again, and the next tablet_take (anyone) starts the talk over. Logged with print,
-- not lost behind a warn. Walking off / Back on the talk screen skips the talk instead (Leave below).
-- TASK-380 runs in parallel: the CustomerService methods it adds are called by name and skipped (logged once) while
-- missing.
-- Leave (owner 2026-10-21, 2026-10-22): the user walking off or pressing Back on the talk screen sends TabletLeave = skip
-- (the talk ends at once and the order is taken, the same Finish as at EndsAt).
-- Tics (design/anomaly-tics-proposal.md, pilot ANM-012, Provisional Q-459..Q-461): an odd customer with a Content.Tics row
-- (by its Variant) whose rig has not done its tic yet plays it in this talk: the rig gets TicAt (server time of LineStart =
-- StartedAt + OrderTalk.Speech.Start) and TicUser (the taker's UserId); every client turns the head on that clock
-- (OddCustomer), the taker alone gets the silence / camera / card layer. The talk lasts the tic's line (Tics.Timing End)
-- + Speech.Hold. Leaving the talk before Timing.Peak takes the attributes off (cancelled: she is as before and the next
-- talk plays it in full);
-- at or past it the rig keeps them and gets Tic = "Done" (the residue, for everyone; the next talk is the short "..."), and
-- the user leaving it then also writes TicFollow = their UserId (her turned head follows them). NpcService's pool clears
-- the attributes when the rig is reused. Leaving never solves, fails or costs sanity (it takes the order, Leave).
-- Owner 2026-10-22 (the next tics, ANM-013 / ANM-004 / ANM-014, Provisional): the same hook for every Content.Tics row.
-- Past the peak, leaving before the last beat also writes TicEnd (server time: the big head keeps the step it reached);
-- TicFollow only for OnLeave "Follow". A row with Residue "None" (the copy's echo) never gets Tic = "Done": its attributes
-- go when the talk is over, so every talk plays it again. The echo: the rig gets TicEcho = the NpcId of the last ordinary
-- customer whose talk this taker opened (the original, ANM-004: the copy comes right after it; none = the copy's own id),
-- and the line is Tics.Said(row, TicEcho, the taker's DisplayName) on the server and on every client.
-- Owner 2026-10-22 (the tension in the talk, Provisional): the line freezes on "..." for the row's Hold (1-2 s) while the
-- taker's tension builds up to the apex (= Timing.Peak, the same cut for Leave); EndsAt covers it (Timing.End + Hold).
-- The tension itself is the taker's client's (Effects/Kit/Tic, Content.Tics Layers); no packet, no new attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(ServerScriptService.server.Modux)

export type TabletState = "Idle" | "Talking" | "Full"

export type Tablet = {
	Index: number,
	Anchor: Instance?,
	State: TabletState,
	Npc: number, -- customer at this tablet, 0 = none
	User: Player?, -- who is taking the order
	StartedAt: number,
	EndsAt: number,
	Order: { string }, -- topping keys of the 1st hot dog
	Order2: { string }?, -- pair (FEAT-038)
	PromptOn: boolean?, -- last state written to the prompt (owner 2026-10-18: it showed with nobody at the counter)
	Tic: TicTalk?, -- the tic playing in this talk (Content.Tics), nil = none
}

-- A tic playing in a talk: the rig carrying its attributes, its row and the server times of its peak and its last beat
export type TicTalk = { Rig: Model, Npc: number, Row: Content.Tic, PeakAt: number, EndAt: number }

const ACTION = "tablet_take"
const ANCHOR_TAG = "Interactable"
const ORDERING = "Ordering"
const TABLET_BUSY = "tablet_busy"
const PICKUP_FULL = "pickup_full"
const PLATES_FULL = "plates_full"
const HEAD_INDEX = 1 -- TAB-1 = the head of the counter queue (Q1); TAB-2 needs the 2nd queue head (R4)
const TICK_RATE = 2 -- Hz (tech §7: only for the end of the talk; a delayed Step lands it on EndsAt)
const END_SLACK = 0.05 -- s: the delayed Step may wake a hair before EndsAt on the server clock
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant, same
-- value as CustomerService NOTICE_GAP: no Content field holds it yet.
const NOTICE_GAP = 2
-- Rig attributes of the anomaly tics (read by Effects/Kit/OddCustomer, Effects/Kit/Tic and TabletController)
const TIC_AT = "TicAt" -- server time of LineStart of the talk with the tic
const TIC_USER = "TicUser" -- UserId of the taker (the screen layer is theirs)
const TIC_STATE = "Tic" -- "Done" once past the peak (the residue)
const TIC_FOLLOW = "TicFollow" -- UserId of who left the talk after the peak
const TIC_END = "TicEnd" -- server time the talk was left between the peak and the last beat (the body stops there)
const TIC_ECHO = "TicEcho" -- the copy's echo (ANM-004): NpcId of the original whose hi it repeats
const TIC_DONE = "Done"

-- The last ordinary customer whose talk each player opened (the copy's echo, ANM-004). Module state, not a Setup field:
-- no generated type change (ModuxTypes)
const lastHeard: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- A talk is on (owner 2026-10-22: one step, the customer talks and the order is taken at its end)
local function busy(tablet: Tablet): boolean
	return tablet.State == "Talking"
end

local function toppingSet(list: { string }): { [string]: boolean }
	const out: { [string]: boolean } = {}
	for _, key in list do
		out[key] = true
	end
	return out
end

const TabletService = Modux.Service("TabletService", {
	Require = {
		"PlaceService",
		"NetService",
		"RunStateService",
		"RoundService",
		"InteractionService",
		"CustomerService",
		"PlateService",
	},
	Priority = 564,
})

function TabletService:Setup()
	self.Enabled = false :: boolean
	-- Bound tablets by TabletIndex
	self.Tablets = {} :: { [number]: Tablet }
	self.AnchorTablet = {} :: { [Instance]: number }
	-- Indices with a record on the Tablets set
	self.Published = {} :: { [number]: boolean }
	-- Last time each notice went to each player (FEAT-005 anti-spam)
	self.NoticeAt = {} :: { [Player]: { [string]: number } }
	self.Warned = {} :: { [string]: boolean }
end

function TabletService:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(message)
end

-- Optional CustomerService method (TASK-380, parallel): the function when present; missing = logged once, nil.
-- Typed any on purpose (a vararg signature here kept the Modux Build type from reducing)
function TabletService:CustomerMethod(name: string): any
	const method = (self.Dependencies.CustomerService :: any)[name]
	if type(method) ~= "function" then
		self:WarnOnce(name, `[TabletService] CustomerService:{name} is missing (TASK-380): skipped`)
		return nil
	end
	return method
end

-- Patience clock of the customer paused during the talk (no-op until TASK-380 lands)
function TabletService:Pause(npc: number, on: boolean)
	const customers = self.Dependencies.CustomerService
	if customers:Get(npc) == nil then
		return
	end
	const method = self:CustomerMethod("PausePatience")
	if method ~= nil then
		(method :: (any, number, boolean) -> ())(customers, npc, on)
	end
end

-- Room in the pickup line PU-1..n for one more order (TASK-380); missing method = room
function TabletService:PickupHasRoom(): boolean
	const method = self:CustomerMethod("IsPickupFull")
	if method == nil then
		return true
	end
	return (method :: (any) -> boolean?)(self.Dependencies.CustomerService) ~= true
end

-- Talk -------------------------------------------------------------------------------------------------------------

-- Seconds of an ordinary customer's talk (Content.OrderSpeech, NpcId 0's lines) for a hot dog with the first k1
-- toppings of ToppingKeys (and the 2nd hot dog of a pair with k2). The real talk's length depends on its words (/dev)
function TabletService:TalkTime(k1: number, k2: number?): number
	local function order(k: number): { [string]: boolean }
		const out: { [string]: boolean } = {}
		for index, key in Content.Ingredients.ToppingKeys do
			if index > k then
				break
			end
			out[key] = true
		end
		return out
	end
	return Content.OrderSpeech.Build({
		Npc = 0,
		Night = 1,
		Order = order(k1),
		Order2 = if k2 ~= nil then order(k2) else nil,
	}).Duration
end

-- The drive-thru computer (DT-PC, TASK-574)
local function isDrive(tablet: Tablet): boolean
	return tablet.Index == Content.Restaurant.Rules.DrivePcIndex
end

-- Customer this tablet serves now: Q1 for TAB-1, the car at the window for DT-PC
function TabletService:Head(tablet: Tablet): number?
	if isDrive(tablet) then
		return self.Dependencies.CustomerService:DriveFront()
	end
	if tablet.Index ~= HEAD_INDEX then
		return nil
	end
	return self.Dependencies.CustomerService:Front()
end

-- Kitchen full for the customer at the head (no plate per line or no pickup spot; a car needs no pickup spot)
function TabletService:IsFull(npc: number?, drive: boolean?): boolean
	return not self.Dependencies.PlateService:HasRoomFor(npc) or (drive ~= true and not self:PickupHasRoom())
end

-- Can this player start a talk here? On refusal, the Notice key worth telling them (nil = refuse silently).
function TabletService:Check(player: Player, tablet: Tablet): (boolean, string?)
	if not self.Enabled or (tablet.Anchor == nil and not isDrive(tablet)) then
		return false, nil
	end
	if busy(tablet) then
		return false, TABLET_BUSY
	end
	const npc = self:Head(tablet)
	if npc == nil or not self.Dependencies.CustomerService:CanActOn(player, npc, ORDERING) then
		return false, nil
	end
	if not self.Dependencies.PlateService:HasRoomFor(npc) then
		return false, PLATES_FULL
	end
	if not isDrive(tablet) and not self:PickupHasRoom() then
		return false, PICKUP_FULL
	end
	return true, nil
end

-- Customer rig by NpcId (CrewRig tag, the same lookup as the clients)
local function rigOf(npc: number): Model?
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			return instance
		end
	end
	return nil
end

-- The tic this customer (rig Variant `variant`) plays in a talk started now (nil = none: an ordinary customer, no row, or
-- already done; `done` = the row's tic is done: its residue line). Plain functions, not methods: no generated type change
local function ticOf(npc: number, variant: string?): (Content.Tic?, Model?, boolean)
	const row = if variant ~= nil then Content.Tics.ByVariant[variant] else nil
	if row == nil then
		return nil, nil, false
	end
	const rig = rigOf(npc)
	if rig == nil then
		return nil, nil, false
	end
	if rig:GetAttribute(TIC_STATE) == TIC_DONE then
		return nil, rig, true
	end
	return row, rig, false
end

-- The tic of this talk, if one plays (the rig's attributes on the speech's clock: LineStart = at + Speech.Start). Returns
-- the row, its line in this talk and whether the residue line is said instead (Content.OrderSpeech.Build's inputs)
local function startTic(tablet: Tablet, player: Player, npc: number, variant: string?, at: number): (Content.Tic?, Content.TicSaid?, boolean)
	const row, rig, done = ticOf(npc, variant)
	if row == nil or rig == nil then
		return nil, nil, done
	end
	-- the copy's echo repeats the original this taker heard last (none: its own hi)
	const original = if row.Line.Echo == true then lastHeard[player] or npc else nil
	const said = Content.Tics.Said(row, original, player.DisplayName)
	const timing = Content.Tics.Timing(row, said)
	const lineStart = at + Content.OrderTalk.Speech.Start
	rig:SetAttribute(TIC_FOLLOW, nil)
	rig:SetAttribute(TIC_END, nil)
	rig:SetAttribute(TIC_ECHO, original)
	rig:SetAttribute(TIC_USER, player.UserId)
	rig:SetAttribute(TIC_AT, lineStart)
	tablet.Tic = {
		Rig = rig,
		Npc = npc,
		Row = row,
		PeakAt = lineStart + timing.Peak,
		EndAt = lineStart + timing.BeatsEnd,
	}
	return row, said, false
end

-- The talk with a tic ends (final = the talk is over). Before the peak: cancelled, the attributes go
-- (she is as before). At or past it: the residue stays (Tic = "Done"); `leaver` = who walked off / pressed Back then
-- (TicFollow for OnLeave "Follow"; before the last beat, TicEnd = now: the body stops where it was). Residue "None" (the
-- echo): nothing stays, the attributes go when the talk is over.
local function clearTic(rig: Model)
	for _, name in { TIC_AT, TIC_USER, TIC_ECHO, TIC_END } do
		rig:SetAttribute(name, nil)
	end
end

local function settleTic(tablet: Tablet, leaver: Player?, final: boolean)
	const tic = tablet.Tic
	if tic == nil then
		return
	end
	if final then
		tablet.Tic = nil
	end
	const rig = tic.Rig
	if rig.Parent == nil or rig:GetAttribute("NpcId") ~= tic.Npc then
		return -- the rig went back to the pool (its attributes are cleared there)
	end
	const at = now()
	if tic.Row.Residue == "None" then
		if final then
			clearTic(rig)
		end
	elseif at >= tic.PeakAt then
		rig:SetAttribute(TIC_STATE, TIC_DONE)
		if leaver ~= nil and tic.Row.OnLeave == "Follow" then
			rig:SetAttribute(TIC_FOLLOW, leaver.UserId)
		end
		if leaver ~= nil and at < tic.EndAt and rig:GetAttribute(TIC_END) == nil then
			rig:SetAttribute(TIC_END, at)
		end
	elseif final then
		clearTic(rig)
	end
end

function TabletService:Start(player: Player, tablet: Tablet): boolean
	if not (self:Check(player, tablet)) then
		return false
	end
	const npc = self:Head(tablet) :: number
	const lines = self.Dependencies.CustomerService:PendingToppings(npc)
	const first = lines[1] or {}
	const second = lines[2]
	const at = now()
	tablet.State = "Talking"
	tablet.Npc = npc
	tablet.User = player
	tablet.StartedAt = at
	tablet.Order = table.clone(first)
	tablet.Order2 = if second then table.clone(second) else nil
	const customer = self.Dependencies.CustomerService:Get(npc)
	const variant: string? = if customer ~= nil then customer.Variant else nil
	if customer ~= nil and variant == nil then
		lastHeard[player] = npc -- the copy's echo (ANM-004) repeats this one's hi
	end
	-- owner 2026-10-22: the customer says its hi and its order (an odd one its line / its tic) letter by letter, the talk
	-- ends with the line (+ Speech.Hold) and the order is taken then (Finish); the client types the same speech
	const row, said, residue = startTic(tablet, player, npc, variant, at)
	const speech = Content.OrderSpeech.Build({
		Npc = npc,
		Variant = variant,
		Night = self.Dependencies.RoundService:GetNight(),
		Order = toppingSet(tablet.Order),
		Order2 = if tablet.Order2 then toppingSet(tablet.Order2) else nil,
		Tic = row,
		Said = said,
		Residue = residue,
	})
	tablet.EndsAt = at + speech.Duration
	self:Pause(npc, true)
	self:Publish(tablet)
	-- the talk ends on EndsAt, not on the next 2 Hz tick
	task.delay(speech.Duration, function()
		if self.Enabled and busy(tablet) and tablet.StartedAt == at then
			self:Step()
		end
	end)
	return true
end

-- Back to Idle (or Full) with no order: the customer keeps its place and its clock runs again
function TabletService:Reset(tablet: Tablet)
	settleTic(tablet, nil, true)
	const npc = tablet.Npc
	tablet.State = "Idle"
	tablet.Npc = 0
	tablet.User = nil
	tablet.StartedAt = 0
	tablet.EndsAt = 0
	tablet.Order = {}
	tablet.Order2 = nil
	if npc ~= 0 then
		self:Pause(npc, false)
		-- the car's own "Take Order" went off for the talk (StartDrive); back on while it still waits to order
		const customer = if isDrive(tablet) then self.Dependencies.CustomerService:Get(npc) else nil
		if customer ~= nil and customer.State == ORDERING then
			self.Dependencies.CustomerService:SetPrompts(npc, true)
		end
	end
	self:UpdateFull(tablet)
	self:Publish(tablet)
end

-- The car at the window took "Take Order" (owner 2026-10-20: the prompt is on the car, no DT-PC Model): the same talk as
-- TAB-1 on the DT-PC record, so the taker gets the TabletDialog and everyone the lines and sounds. false = not started
-- (the caller takes the order at once, as before).
function TabletService:StartDrive(player: Player, npc: number): boolean
	const tablet = self.Tablets[Content.Restaurant.Rules.DrivePcIndex]
	if tablet == nil or self:Head(tablet) ~= npc or not self:Start(player, tablet) then
		return false
	end
	self.Dependencies.CustomerService:SetPrompts(npc, false)
	return true
end

function TabletService:DriveTalking(npc: number): boolean
	const tablet = self.Tablets[Content.Restaurant.Rules.DrivePcIndex]
	return tablet ~= nil and busy(tablet) and tablet.Npc == npc
end

-- End of the order talk: the order is taken by whoever started it (same path as the old "Take Order" prompt), for every
-- customer, ordinary or anomaly (owner 2026-10-22; what an anomaly does once its order is taken is its module's)
function TabletService:Finish(tablet: Tablet)
	if tablet.State ~= "Talking" then
		return
	end
	const npc = tablet.Npc
	const user = tablet.User
	self:Reset(tablet)
	if npc == 0 or user == nil then
		return
	end
	if not self.Dependencies.CustomerService:TakeOrderFor(user, npc) then
		warn(`[TabletService] TAB-{tablet.Index}: TakeOrderFor({user.Name}, {npc}) refused at the end of the talk`)
	end
end

-- The user left the talk screen (TabletLeave: walked off / Back). Owner 2026-10-22 ("ao clicar sair, ele meio que skip a
-- conversa... e já prossegue com o pedido"): leaving skips the talk, the order is taken now (Finish), as at EndsAt.
-- Anyone else, or a tablet not busy = ignored; the customer gone from Q1 / Ordering = Reset (no order, as in Step)
function TabletService:Leave(tablet: Tablet, player: Player)
	if not busy(tablet) or tablet.User ~= player then
		return
	end
	if not self:StillThere(tablet) then
		self:Reset(tablet)
		return
	end
	-- past the tic's peak her turned head stays and follows who left (before it: the attributes go in Reset)
	settleTic(tablet, player, false)
	self:Finish(tablet)
end

-- The player who started the talk left the server or is no longer an active member (R-8)
function TabletService:UserGone(tablet: Tablet): boolean
	const user = tablet.User
	return user == nil or user.Parent == nil or not self.Dependencies.RunStateService:IsActive(user)
end

-- Talk cancelled (R-8): back to Idle with no order, the customer stays in Q1 (Reset keeps its place and its clock)
function TabletService:Cancel(tablet: Tablet, why: string)
	const npc = tablet.Npc
	self:Reset(tablet)
	print(`[TabletService] TAB-{tablet.Index}: talk with {npc} cancelled ({why}); the customer waits at Q1`)
end

-- The customer is still the one at the head, in Ordering
function TabletService:StillThere(tablet: Tablet): boolean
	const customer = self.Dependencies.CustomerService:Get(tablet.Npc)
	return customer ~= nil and customer.State == ORDERING and self:Head(tablet) == tablet.Npc
end

-- Idle <-> Full by the room for the customer at the head (true when the state changed; the caller publishes)
function TabletService:UpdateFull(tablet: Tablet): boolean
	if busy(tablet) then
		return false
	end
	const state: TabletState = if self:IsFull(self:Head(tablet), isDrive(tablet)) then "Full" else "Idle"
	if state == tablet.State then
		return false
	end
	tablet.State = state
	return true
end

-- The Take Order prompt shows only while the customer at the head of the queue is Ordering and the tablet is free.
function TabletService:SyncPrompt(tablet: Tablet)
	const anchor = tablet.Anchor
	if anchor == nil then
		return
	end
	local on = false
	if not busy(tablet) then
		const npc = self:Head(tablet)
		const customer = if npc ~= nil then self.Dependencies.CustomerService:Get(npc) else nil
		on = customer ~= nil and customer.State == ORDERING
	end
	-- compared with the attribute too, not only the last write: an anchor switched off from elsewhere (a phase skip, a
	-- run restore) came back on only after the head changed, so the first customer of a run was refused "state"
	if tablet.PromptOn ~= on or anchor:GetAttribute("PromptEnabled") ~= on then
		tablet.PromptOn = on
		self.Dependencies.InteractionService:SetPrompt(anchor, on)
	end
end

function TabletService:Step()
	const t = now()
	for _, tablet in self.Tablets do
		self:SyncPrompt(tablet)
		if busy(tablet) then
			if not self:StillThere(tablet) then
				self:Reset(tablet)
			elseif self:UserGone(tablet) then
				self:Cancel(tablet, "attendant left")
			elseif t >= tablet.EndsAt - END_SLACK then
				self:Finish(tablet)
			end
		elseif self:UpdateFull(tablet) then
			self:Publish(tablet)
		end
	end
end

-- Wire ----------------------------------------------------------------------------------------------------------------

function TabletService:Record(tablet: Tablet): any
	return {
		State = tablet.State,
		Npc = math.clamp(tablet.Npc, 0, 65535),
		User = if tablet.User then tablet.User.UserId else 0,
		StartedAt = tablet.StartedAt,
		EndsAt = tablet.EndsAt,
		Order = toppingSet(tablet.Order),
		-- A nil field is skipped by Lync's update: clearing an optional needs Lync.none
		Order2 = if tablet.Order2 then toppingSet(tablet.Order2) else Lync.none,
	}
end

function TabletService:Publish(tablet: Tablet)
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const record = self:Record(tablet)
	if self.Published[tablet.Index] then
		Restaurant.Tablets:update(tablet.Index, record)
	else
		if record.Order2 == Lync.none then
			record.Order2 = nil
		end
		Restaurant.Tablets:add(tablet.Index, record)
		self.Published[tablet.Index] = true
	end
end

-- Sends `key` to `player` unless the same key went to them less than NOTICE_GAP s ago.
function TabletService:NotifyThrottled(player: Player, key: string)
	const t = os.clock()
	local sent = self.NoticeAt[player]
	if sent == nil then
		sent = {}
		self.NoticeAt[player] = sent
	end
	const last = sent[key]
	if last ~= nil and t - last < NOTICE_GAP then
		return
	end
	sent[key] = t
	self.Dependencies.RunStateService:Notify(player, key)
end

-- Binding -------------------------------------------------------------------------------------------------------------

function TabletService:Bind()
	const binding = Content.Restaurant.Binding
	for _, model in CollectionService:GetTagged(binding.TabletTag) do
		if not model:IsDescendantOf(workspace) then
			continue
		end
		const raw = model:GetAttribute(binding.TabletIndex)
		const drivePc = Content.Restaurant.Drive.Enabled and raw == Content.Restaurant.Rules.DrivePcIndex
		if type(raw) ~= "number" or (raw ~= HEAD_INDEX and not drivePc) then
			print(`[TabletService] {model:GetFullName()}: {binding.TabletIndex} {raw} not used yet (TAB-1 and DT-PC only)`)
			continue
		end
		const index: number = raw
		if self.Tablets[index] ~= nil then
			warn(`[TabletService] {binding.TabletIndex} {index} bound twice ({model:GetFullName()} ignored)`)
			continue
		end
		const anchor = if model.Name == binding.TabletPrompt then model else model:FindFirstChild(binding.TabletPrompt, true)
		if anchor == nil then
			warn(`[TabletService] TAB-{index}: missing {binding.TabletPrompt}`)
		else
			-- Attributes before the tag: InteractionService reads them when the anchor is tagged
			anchor:SetAttribute("PromptAction", ACTION)
			anchor:SetAttribute("PromptEnabled", true)
			if not CollectionService:HasTag(anchor, ANCHOR_TAG) then
				CollectionService:AddTag(anchor, ANCHOR_TAG)
			end
			self.AnchorTablet[anchor] = index
		end
		self.Tablets[index] = {
			Index = index,
			Anchor = anchor,
			State = "Idle",
			Npc = 0,
			User = nil,
			StartedAt = 0,
			EndsAt = 0,
			Order = {},
			Order2 = nil,
		}
	end
	-- No DT-PC Model (Drive.WindowAnchors off): a DT-PC record with no anchor, started by the car's prompt (StartDrive)
	const pcIndex = Content.Restaurant.Rules.DrivePcIndex
	const drive = Content.Restaurant.Drive
	if drive.Enabled and not drive.WindowAnchors and self.Tablets[pcIndex] == nil then
		self.Tablets[pcIndex] = {
			Index = pcIndex,
			Anchor = nil,
			State = "Idle",
			Npc = 0,
			User = nil,
			StartedAt = 0,
			EndsAt = 0,
			Order = {},
			Order2 = nil,
		}
	end
	if self.Tablets[HEAD_INDEX] == nil then
		warn(`[TabletService] restaurant on but no {binding.TabletTag} with {binding.TabletIndex} = 1 in the map: no tablet`)
	end
end

function TabletService:TabletAt(anchor: Instance): Tablet?
	const index = self.AnchorTablet[anchor]
	return if index ~= nil then self.Tablets[index] else nil
end

-- Dev (PlaceService:IsDev; /dev tablet) -------------------------------------------------------------------------------

function TabletService:DevTablet(index: number?): Tablet
	if not self.Dependencies.PlaceService:IsDev() then
		error("[TabletService] dev mode only", 3)
	end
	if not self.Enabled then
		error("tablet off (no TAB-1 bound)", 0)
	end
	const tablet = self.Tablets[index or HEAD_INDEX]
	if tablet == nil then
		error(`TAB-{index or HEAD_INDEX} not bound`, 0)
	end
	return tablet
end

function TabletService:DevState(index: number?): string
	const tablet = self:DevTablet(index)
	const t = now()
	const head = self:Head(tablet)
	return string.format(
		"TAB-%d %s npc %d user %s started %.1f s ago, ends in %.1f s, order [%s]%s | head %s, plates room %s, pickup room %s",
		tablet.Index,
		tablet.State,
		tablet.Npc,
		if tablet.User then tablet.User.Name else "-",
		if tablet.StartedAt > 0 then t - tablet.StartedAt else 0,
		if tablet.EndsAt > 0 then tablet.EndsAt - t else 0,
		table.concat(tablet.Order, ","),
		if tablet.Order2 then ` + [{table.concat(tablet.Order2, ",")}]` else "",
		if head then tostring(head) else "-",
		tostring(self.Dependencies.PlateService:HasRoomFor(head)),
		tostring(self:PickupHasRoom())
	)
end

-- Starts the talk as `player` without the range check (every other rule applies). Returns the reply.
function TabletService:DevTalk(player: Player, index: number?): string
	const tablet = self:DevTablet(index)
	const ok, notice = self:Check(player, tablet)
	if not ok then
		return `refused: {notice or "no customer in Ordering at Q1 / not an active member / drawer closed"}`
	end
	self:Start(player, tablet)
	return string.format("TAB-%d talking with %d for %.2f s", tablet.Index, tablet.Npc, tablet.EndsAt - tablet.StartedAt)
end

-- Ends the running talk now (as if EndsAt was reached): the order is taken, as at the end of any talk
function TabletService:DevFinish(index: number?): string
	const tablet = self:DevTablet(index)
	if not busy(tablet) then
		return `TAB-{tablet.Index} is {tablet.State}`
	end
	const npc = tablet.Npc
	self:Finish(tablet)
	const customer = self.Dependencies.CustomerService:Get(npc)
	return `TAB-{tablet.Index} done; customer {npc} is {if customer then customer.State else "gone"}`
end

TabletService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Priority 564 < 730: InteractionService already built its handler table. The "Plates" gate (PlateService) runs
	-- before Validate and answers plates_full itself
	self.Dependencies.InteractionService:RegisterAction(ACTION, {
		Validate = function(player: Player, anchor: Instance): boolean
			const tablet = self:TabletAt(anchor)
			if tablet == nil then
				return false
			end
			const ok, notice = self:Check(player, tablet)
			if not ok and notice ~= nil then
				self:NotifyThrottled(player, notice)
			end
			return ok
		end,
		Run = function(player: Player, anchor: Instance)
			const tablet = self:TabletAt(anchor)
			if tablet ~= nil then
				self:Start(player, tablet)
			end
		end,
	})
	Restaurant.TabletLeave:onServer(function(index: number, player: Player)
		const tablet = self.Tablets[index]
		if tablet ~= nil then
			self:Leave(tablet, player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self.NoticeAt[player] = nil
		lastHeard[player] = nil
		for _, tablet in self.Tablets do
			if busy(tablet) and tablet.User == player then
				self:Cancel(tablet, "attendant left the server")
			end
		end
	end)
end)

TabletService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	-- The map is loaded (StreamingEnabled off, T57)
	self:Bind()
	for _, tablet in self.Tablets do
		self:UpdateFull(tablet)
		self:Publish(tablet)
	end
	-- The car's "Take Order" (CustomerService take_order) runs the talk here
	self.Dependencies.CustomerService:SetTalker({
		Start = function(player: Player, npc: number): boolean
			return self:StartDrive(player, npc)
		end,
		Talking = function(npc: number): boolean
			return self:DriveTalking(npc)
		end,
	})
	-- The Take Order prompt turns on the moment the head customer reaches Q1, not on the next tick (up to 1 / TICK_RATE s)
	self.Dependencies.CustomerService.Fronted:Connect(function()
		if self.Enabled then
			for _, tablet in self.Tablets do
				self:SyncPrompt(tablet)
			end
		end
	end)
	-- A new shift starts with every tablet idle (the customers are gone)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		for _, tablet in self.Tablets do
			if busy(tablet) then
				self:Reset(tablet)
			end
		end
	end)
end)

TabletService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return TabletService
