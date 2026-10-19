--!strict
-- Order tablet of the restaurant (tech/restaurant-flow.md rev. 2 §2.4, §3.2; design FEAT-043; DEC-270; TASK-381, wave
-- R1-D). Run place only, and only with Content.Restaurant.Rules.Enabled: with the flag off nothing is bound and
-- tablet_take is not registered (the published trailer flow is untouched). Single writer of the Net.Restaurant Tablets set.
--
-- Binding (Content.Restaurant.Binding): an Instance tagged TabletTag with TabletIndex = 1 (TAB-1, the head of the counter
-- queue Q1) and the anchor TabletPrompt under it (PromptAction tablet_take; attributes and the Interactable tag set here
-- when the map did not). MVP: record 1 only; TAB-2 (UPG-027) and DT-PC (Rules.DrivePcIndex, wave R3) are ignored with a log.
--
-- Talk: tablet_take (tap, Actions.tablet_take.Radius) with the customer of Q1 in Ordering, the tablet Idle, room on the
-- plates (PlateService:HasRoomFor) and in the pickup line (not CustomerService:IsPickupFull, TASK-380) -> Talking with
-- StartedAt / EndsAt = StartedAt + TalkTime and the order (CustomerService:PendingToppings) on the record, the patience
-- clock paused (CustomerService:PausePatience, TASK-380). TalkTime = Talk.Open + Talk.Lead + Talk.PerItem x (2 + K) +
-- Talk.Confirm, a pair adds Talk.PairExtra + Talk.PerItem x (2 + K2), floor Talk.MinTotal. The player is not frozen and
-- walking away does not cancel (board TASK-381). A 2 Hz tick ends it: at EndsAt CustomerService:TakeOrderFor(user, npc)
-- (same gate and write as the old prompt; PlateService puts the ticket on a plate from Acted); if the customer left Q1
-- or Ordering before that (anomaly, window closed, shift end) the tablet goes back to Idle with no order. Another
-- tablet_take during the talk = Notice tablet_busy. Idle with no room = Full ("Kitchen full" lamp for everyone).
-- Attendant gone mid-talk (R-8, docs/tests/restaurant-e2e.md; design FEAT-043 "afastar cancela, a paciência volta a
-- correr" / "cancela sem criar pedido nem cobrar"): when the player who started the talk leaves the server or stops being
-- an active member (Down, spectator), the talk is CANCELLED at once (Reset): no order, no charge, the customer keeps Q1 in
-- Ordering with its patience running again, and the next tablet_take (anyone) starts the talk over. Logged with print,
-- not lost behind a warn. Walking away is still not a cancel (board TASK-381; design gap noted in R-5).
-- TASK-380 runs in parallel: the CustomerService methods it adds are called by name and skipped (logged once) while
-- missing.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Lync = require(ReplicatedStorage.Packages.Lync)
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
}

const ACTION = "tablet_take"
const ANCHOR_TAG = "Interactable"
const ORDERING = "Ordering"
const TABLET_BUSY = "tablet_busy"
const PICKUP_FULL = "pickup_full"
const PLATES_FULL = "plates_full"
const HEAD_INDEX = 1 -- TAB-1 = the head of the counter queue (Q1); TAB-2 needs the 2nd queue head (R4)
const TICK_RATE = 2 -- Hz (tech §7: only for the end of the talk)
-- Same notice to the same player at most once per this many seconds (FEAT-005 anti-spam). PROVISIONAL constant, same
-- value as CustomerService NOTICE_GAP: no Content field holds it yet.
const NOTICE_GAP = 2

local function now(): number
	return workspace:GetServerTimeNow()
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

-- Seconds of the talk for a hot dog with k1 toppings (and the 2nd hot dog of a pair with k2)
function TabletService:TalkTime(k1: number, k2: number?): number
	const talk = Content.Restaurant.Talk
	local total = talk.Open + talk.Lead + talk.PerItem * (2 + k1) + talk.Confirm
	if k2 ~= nil then
		total += talk.PairExtra + talk.PerItem * (2 + k2)
	end
	return math.max(total, talk.MinTotal)
end

-- Customer this tablet serves now: Q1 for TAB-1
function TabletService:Head(tablet: Tablet): number?
	if tablet.Index ~= HEAD_INDEX then
		return nil
	end
	return self.Dependencies.CustomerService:Front()
end

-- Kitchen full for the customer at the head (no plate per line or no pickup spot)
function TabletService:IsFull(npc: number?): boolean
	return not self.Dependencies.PlateService:HasRoomFor(npc) or not self:PickupHasRoom()
end

-- Can this player start a talk here? On refusal, the Notice key worth telling them (nil = refuse silently).
function TabletService:Check(player: Player, tablet: Tablet): (boolean, string?)
	if not self.Enabled or tablet.Anchor == nil then
		return false, nil
	end
	if tablet.State == "Talking" then
		return false, TABLET_BUSY
	end
	const npc = self:Head(tablet)
	if npc == nil or not self.Dependencies.CustomerService:CanActOn(player, npc, ORDERING) then
		return false, nil
	end
	if not self.Dependencies.PlateService:HasRoomFor(npc) then
		return false, PLATES_FULL
	end
	if not self:PickupHasRoom() then
		return false, PICKUP_FULL
	end
	return true, nil
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
	tablet.EndsAt = at + self:TalkTime(#first, if second then #second else nil)
	tablet.Order = table.clone(first)
	tablet.Order2 = if second then table.clone(second) else nil
	self:Pause(npc, true)
	self:Publish(tablet)
	return true
end

-- Back to Idle (or Full) with no order: the customer keeps its place and its clock runs again
function TabletService:Reset(tablet: Tablet)
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
	end
	self:UpdateFull(tablet)
	self:Publish(tablet)
end

-- End of the talk: the order is taken by whoever started it (same path as the old "Take Order" prompt)
function TabletService:Finish(tablet: Tablet)
	const npc = tablet.Npc
	const user = tablet.User
	self:Reset(tablet)
	if npc == 0 or user == nil then
		return
	end
	const taken = self.Dependencies.CustomerService:TakeOrderFor(user, npc)
	if not taken then
		warn(`[TabletService] TAB-{tablet.Index}: TakeOrderFor({user.Name}, {npc}) refused at the end of the talk`)
	end
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
	if tablet.State == "Talking" then
		return false
	end
	const state: TabletState = if self:IsFull(self:Head(tablet)) then "Full" else "Idle"
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
	if tablet.State ~= "Talking" then
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
		if tablet.State == "Talking" then
			if not self:StillThere(tablet) then
				self:Reset(tablet)
			elseif self:UserGone(tablet) then
				self:Cancel(tablet, "attendant left")
			elseif t >= tablet.EndsAt then
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
		if type(raw) ~= "number" or raw ~= HEAD_INDEX then
			print(`[TabletService] {model:GetFullName()}: {binding.TabletIndex} {raw} not used yet (MVP binds TAB-1 only)`)
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

-- Ends the running talk now (as if EndsAt was reached)
function TabletService:DevFinish(index: number?): string
	const tablet = self:DevTablet(index)
	if tablet.State ~= "Talking" then
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
	Players.PlayerRemoving:Connect(function(player: Player)
		self.NoticeAt[player] = nil
		for _, tablet in self.Tablets do
			if tablet.State == "Talking" and tablet.User == player then
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
	-- A new shift starts with every tablet idle (the customers are gone)
	self.Dependencies.RoundService.ShiftStarted:Connect(function()
		for _, tablet in self.Tablets do
			if tablet.State == "Talking" then
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
