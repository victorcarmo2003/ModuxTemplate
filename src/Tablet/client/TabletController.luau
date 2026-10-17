--!strict
--[[
	TabletController (TASK-383, R1-F; design FEAT-043, DEC-270 / DEC-280; tech/restaurant-flow.md rev. 2 §2.4 / §3.2)

	Presents the talk at the tablet; decides nothing (TabletService starts and ends the talk, CustomerService takes the
	order at the end; pressing the prompt again to hurry is the server's).

	  - Tablets set (Net.Restaurant, record 1 = TAB-1, 2 = TAB-2, Rules.DrivePcIndex = DT-PC) -> one Vide source per tablet.
	  - The tablet Model is found by tag Binding.TabletTag + attribute Binding.TabletIndex; Binding.TabletScreen
	    (Att_Screen, optional) is where its balloon sits.
	  - The talk is a fixed script read from the record (Timeline below, pure): the player's greeting, the customer's
	    opening, one line per item (bun, sausage, then the toppings in ToppingKeys order; a pair adds PairExtra and the
	    2nd hot dog), "That's it!". Item i is said at StartedAt + Open + Lead + PerItem x i (Content.Restaurant.Talk). The
	    server never sends steps: every client reads the same record and the same server clock, so all see the same.
	    EndsAt carries the speed-ups (veteran, hurry, UPG-034): the script is stretched onto StartedAt..EndsAt, so a hurry
	    in the middle jumps the rest forward and nothing is ever un-said.
	  - The player taking the order (User = me, Talking): TabletDialog on the screen (lower left, never in the middle) with
	    the line and the items popping in, SFX `ticket_pop` per item. `MyTalk()` exposes the reveal for the HUD note
	    (HudOrder `Reveal`, CustomerController, TASK-384).
	  - Everybody else: the customer's line in a SpeechBalloon over the rig (the greeting is not shown), `dialog_blip`
	    on each new line at the tablet.
	  - Blank customer (ANM-001, rig Variant "blank"): Dialog.Blank, no item, no pop-up.
	  - Full (no free plate or pickup spot): "Kitchen full" balloon over the tablet for everyone (Dialog.KitchenFull).

	Content.Restaurant.Rules.Enabled = false: inert (no listener, no tag watch, no gui). No input of its own: the talk is
	the `tablet_take` prompt (PromptController binds keyboard, touch and gamepad). Listeners in OnInit (before
	Lync.start); tags and the gui in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Restaurant = require(ReplicatedStorage.shared.Libs.Net.Restaurant)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local TabletDialog = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TabletDialog)
local SpeechBalloon = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SpeechBalloon)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)

const RESTAURANT = Content.Restaurant
const BINDING = RESTAURANT.Binding
const TALK = RESTAURANT.Talk
const DIALOG = RESTAURANT.Dialog
const MAX_TOPPINGS = Content.OrderRules.MaxToppings
const BLANK = "blank" -- ANM-001 rig Variant
const BALLOON_DISTANCE = 40
const BALLOON_LIFT = Vector3.new(0, 2.2, 0) -- studs over the head (or the tablet screen)
const FULL_LIFT = Vector3.new(0, 1.2, 0)
const CLOSE_AT = 0.5 -- fraction of Talk.Confirm after the last item where "That's it!" is said
const MIN_SPAN = 0.05 -- s, a talk shorter than this is read as already over
const GUI_NAME = "TabletDialog"
const CLOCK_STEP = 1 / 30 -- s between two clock writes while a talk runs (pop-ups land within a frame or two)
const DIALOG_LIFT = 150 -- px over the bottom edge (UI scale 1): clear of the hotbar and the joystick's thumb

export type Speaker = "Player" | "Customer"

export type Record = {
	State: string, -- "Idle" | "Talking" | "Full"
	Npc: number,
	User: number,
	StartedAt: number,
	EndsAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}

-- One line of the talk at script time `At` (s from StartedAt, before the speed-ups); Reveal = items said once it starts
export type Step = { At: number, Speaker: Speaker, Text: string, Reveal: number }

export type Talk = {
	Steps: { Step },
	Items: { string }, -- ingredient keys in the order they are said
	Base: number, -- s of the script without speed-ups (Open + Lead + PerItem x items + PairExtra + Confirm)
}

-- What the screen of the player taking the order reads (reactive through MyTalk)
export type MyTalk = { Index: number, Npc: number, Items: { string }, Reveal: number, Step: Step }

type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Blank: Vide.Source<boolean>,
	Rig: Model?, -- the customer talking at it
	Model: Model?,
	BalloonUnmount: (() -> ())?,
	BalloonGui: Instance?,
	FullUnmount: (() -> ())?,
	FullGui: Instance?,
	LastStep: number, -- index of the last step heard (blip), 0 = none
	LastReveal: number, -- items popped for me (ticket_pop)
	Talk: Talk?, -- script of the running talk (built once per talk)
	TalkKey: string,
}

-- Deterministic pick: every client chooses the same line of a list for the same customer
local function pick(list: { string }?, npc: number, salt: number): string
	if list == nil or #list == 0 then
		return ""
	end
	return list[(npc + salt) % #list + 1]
end

local function items(order: { [string]: boolean }?): { string }
	const list: { string } = { "bun", "sausage" }
	if order == nil then
		return list
	end
	local toppings = 0
	for _, key in Content.Ingredients.ToppingKeys do
		if order[key] then
			table.insert(list, key)
			toppings += 1
			if toppings >= MAX_TOPPINGS then
				break
			end
		end
	end
	return list
end

local function line(at: number, speaker: Speaker, text: string, reveal: number): Step
	return { At = at, Speaker = speaker, Text = text, Reveal = reveal }
end

-- The talk script of a record (pure). `blank` = ANM-001 customer: nothing to read, no item.
local function timeline(record: Record, blank: boolean): Talk
	const npc = record.Npc
	const steps: { Step } = { line(0, "Player", pick(DIALOG.Greeting, npc, 0), 0) }
	if blank then
		table.insert(steps, line(TALK.Open, "Customer", pick(DIALOG.Blank, npc, 1), 0))
		return { Steps = steps, Items = {}, Base = TALK.Open + TALK.Lead + TALK.Confirm }
	end
	table.insert(steps, line(TALK.Open, "Customer", pick(DIALOG.Opening, npc, 1), 0))

	const said: { string } = {}
	local at = TALK.Open + TALK.Lead
	local function say(list: { string })
		for _, key in list do
			at += TALK.PerItem
			table.insert(said, key)
			table.insert(steps, line(at, "Customer", pick(DIALOG.Ask[key], npc, #said), #said))
		end
	end
	say(items(record.Order))
	if record.Order2 ~= nil then
		at += TALK.PairExtra
		say(items(record.Order2))
	end
	table.insert(steps, line(at + TALK.Confirm * CLOSE_AT, "Customer", pick(DIALOG.Close, npc, 2), #said))
	return { Steps = steps, Items = said, Base = at + TALK.Confirm }
end

-- Index of the step being said at server time `now` (0 = before the talk), stretched onto StartedAt..EndsAt (pure)
local function stepAt(record: Record, talk: Talk, now: number): number
	const span = record.EndsAt - record.StartedAt
	local scripted: number
	if span <= MIN_SPAN then
		scripted = talk.Base
	else
		scripted = math.clamp((now - record.StartedAt) / span, 0, 1) * talk.Base
	end
	if now < record.StartedAt then
		return 0
	end
	local current = 0
	for index, step in talk.Steps do
		if step.At <= scripted + 1e-6 then
			current = index
		else
			break
		end
	end
	return current
end

local function rigOf(npc: number): Model?
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			return instance
		end
	end
	return nil
end

const TabletController = Modux.Controller("TabletController", { Require = { "AudioController" }, Priority = 658 })


function TabletController:Setup()
	self.Spots = {} :: { [number]: Spot }
	-- tablet Model -> its watcher connections
	self.Tracked = {} :: { [Instance]: { RBXScriptConnection } }
	self.Now = Vide.source(Workspace:GetServerTimeNow()) :: Vide.Source<number>
	-- index of the tablet where I am taking an order; 0 = none
	self.Mine = Vide.source(0) :: Vide.Source<number>
	self.Gui = nil :: Instance?
	self.Holder = nil :: Folder?
	self.DialogUnmount = nil :: (() -> ())?
	self.Clock = nil :: RBXScriptConnection?
end

-- Pure helpers, for the HUD note (TASK-384) and the tests: the script of a record and the step said at `now`.
function TabletController:Timeline(record: Record, blank: boolean): Talk
	return timeline(record, blank)
end

function TabletController:StepAt(record: Record, talk: Talk, now: number): number
	return stepAt(record, talk, now)
end

function TabletController:Enabled(): boolean
	return RESTAURANT.Rules.Enabled
end

-- Reactive read of a tablet record (nil = no such tablet). For other controllers and debugging.
function TabletController:RecordOf(index: number): Record?
	const spot = self.Spots[index]
	if spot == nil then
		return nil
	end
	const record = spot.Record()
	return if record == false then nil else record
end

-- Reactive: the talk I am taking right now (nil = none). Reveal = items said so far (0..#Items), on the server clock.
function TabletController:MyTalk(): MyTalk?
	const index = self.Mine()
	const spot = if index ~= 0 then self.Spots[index] else nil
	if spot == nil then
		return nil
	end
	const record = spot.Record()
	const talk = spot.Talk
	if record == false or record.State ~= "Talking" or talk == nil then
		return nil
	end
	const current = stepAt(record, talk, self.Now())
	const step = talk.Steps[math.max(current, 1)]
	return {
		Index = index,
		Npc = record.Npc,
		Items = talk.Items,
		Reveal = if current == 0 then 0 else step.Reveal,
		Step = step,
	}
end

function TabletController:SpotOf(index: number): Spot
	const existing = self.Spots[index]
	if existing ~= nil then
		return existing
	end
	const spot: Spot = {
		Index = index,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Blank = Vide.source(false) :: Vide.Source<boolean>,
		Rig = nil,
		Model = nil,
		BalloonUnmount = nil,
		BalloonGui = nil,
		FullUnmount = nil,
		FullGui = nil,
		LastStep = 0,
		LastReveal = 0,
		Talk = nil,
		TalkKey = "",
	}
	self.Spots[index] = spot
	return spot
end

local function isMine(record: Record | false): boolean
	return record ~= false and record.State == "Talking" and record.User == Players.LocalPlayer.UserId
end

-- Copies: the set may reuse its record table between frames, and Vide needs a new value to notice a change.
function TabletController:WriteRecord(index: number, record: Record?)
	const spot = self:SpotOf(index)
	local copy: Record | false = false
	if record ~= nil then
		copy = {
			State = record.State,
			Npc = record.Npc,
			User = record.User,
			StartedAt = record.StartedAt,
			EndsAt = record.EndsAt,
			Order = table.clone(record.Order),
			Order2 = if record.Order2 then table.clone(record.Order2) else nil,
		}
	end
	-- a new talk (another customer or another start): rig, blank flag and the heard steps start over
	const key = if copy ~= false and copy.State == "Talking" then `{copy.Npc}@{copy.StartedAt}` else ""
	if key ~= spot.TalkKey then
		spot.TalkKey = key
		spot.LastStep = 0
		spot.LastReveal = 0
		spot.Rig = if copy ~= false and copy.Npc ~= 0 then rigOf(copy.Npc) else nil
		const rig = spot.Rig
		spot.Blank(rig ~= nil and rig:GetAttribute("Variant") == BLANK)
	end
	-- the script first: the readers of Record (balloon, MyTalk) use it in the same update
	spot.Talk = if copy ~= false and copy.State == "Talking" then timeline(copy, Vide.untrack(spot.Blank)) else nil
	spot.Record(copy)

	-- my talk: the tablet I am at (one at a time; the last one written wins)
	if isMine(copy) then
		self.Mine(index)
	elseif Vide.untrack(self.Mine) == index then
		self.Mine(0)
	end
	self:Present(spot)
	self:RunClock()
end

function TabletController:Anchor(spot: Spot): Instance?
	const model = spot.Model
	if model == nil then
		return nil
	end
	const screen = model:FindFirstChild(BINDING.TabletScreen, true)
	if screen ~= nil and (screen:IsA("Attachment") or screen:IsA("BasePart")) then
		return screen
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- Balloon over the customer (others) and the "Kitchen full" balloon (everyone)
function TabletController:Present(spot: Spot)
	const holder = self.Holder
	if holder == nil then
		return
	end
	const record = Vide.untrack(spot.Record)

	-- customer balloon: mounted per talk, adorned on the rig's head (else the tablet)
	const talking = record ~= false and record.State == "Talking"
	if spot.BalloonUnmount ~= nil and (not talking or spot.BalloonGui == nil or spot.BalloonGui:GetAttribute("Talk") ~= spot.TalkKey) then
		spot.BalloonUnmount()
		spot.BalloonUnmount = nil
		if spot.BalloonGui ~= nil then
			spot.BalloonGui:Destroy()
			spot.BalloonGui = nil
		end
	end
	if talking and spot.BalloonUnmount == nil then
		const rig = spot.Rig
		const head = if rig ~= nil then rig:FindFirstChild("Head") else nil
		const adornee = head or self:Anchor(spot)
		if adornee ~= nil then
			const unmount, gui = Vide.root(function()
				local function current(): Step?
					const now = spot.Record()
					const talk = spot.Talk
					if now == false or now.State ~= "Talking" or talk == nil then
						return nil
					end
					const index = stepAt(now, talk, self.Now())
					return if index > 0 then talk.Steps[index] else nil
				end
				return SpeechBalloon({
					Name = `TabletBalloon_{spot.Index}`,
					Adornee = adornee,
					StudsOffset = BALLOON_LIFT,
					MaxDistance = BALLOON_DISTANCE,
					Visible = function()
						const step = current()
						return step ~= nil
							and step.Speaker == "Customer"
							and not isMine(spot.Record())
							and not Cinematic.Active()
					end,
					Text = function()
						const step = current()
						return if step then step.Text else ""
					end,
				})
			end)
			gui:SetAttribute("Talk", spot.TalkKey)
			gui.Parent = holder
			spot.BalloonUnmount = unmount
			spot.BalloonGui = gui
		end
	end

	-- "Kitchen full": one balloon per tablet, shown while State = Full
	if spot.FullUnmount == nil then
		const adornee = self:Anchor(spot)
		if adornee ~= nil then
			const unmount, gui = Vide.root(function()
				return SpeechBalloon({
					Name = `TabletFull_{spot.Index}`,
					Adornee = adornee,
					StudsOffset = FULL_LIFT,
					MaxDistance = BALLOON_DISTANCE,
					Visible = function()
						const now = spot.Record()
						return now ~= false and now.State == "Full" and not Cinematic.Active()
					end,
					Text = function()
						return DIALOG.KitchenFull
					end,
				})
			end)
			gui.Parent = holder
			spot.FullUnmount = unmount
			spot.FullGui = gui
		end
	end
end

function TabletController:DropBalloons(spot: Spot)
	if spot.BalloonUnmount ~= nil then
		spot.BalloonUnmount()
		spot.BalloonUnmount = nil
	end
	if spot.BalloonGui ~= nil then
		spot.BalloonGui:Destroy()
		spot.BalloonGui = nil
	end
	if spot.FullUnmount ~= nil then
		spot.FullUnmount()
		spot.FullUnmount = nil
	end
	if spot.FullGui ~= nil then
		spot.FullGui:Destroy()
		spot.FullGui = nil
	end
end

-- Sounds of the running talks: dialog_blip on each new line (everyone, at the tablet), ticket_pop per item (me)
function TabletController:Cue(spot: Spot, now: number)
	const record = Vide.untrack(spot.Record)
	const talk = spot.Talk
	if record == false or record.State ~= "Talking" or talk == nil then
		return
	end
	const index = stepAt(record, talk, now)
	if index <= spot.LastStep then
		return
	end
	spot.LastStep = index
	const step = talk.Steps[index]
	const audio = self.Dependencies.AudioController
	const at = spot.Rig or self:Anchor(spot)
	if at ~= nil then
		audio:Play("dialog_blip", at)
	end
	if isMine(record) and step.Reveal > spot.LastReveal then
		spot.LastReveal = step.Reveal
		audio:Play("ticket_pop")
	end
end

-- Server clock while a talk runs (Heartbeat, CLOCK_STEP); stops when every tablet is idle
function TabletController:RunClock()
	local any = false
	for _, spot in self.Spots do
		const record = Vide.untrack(spot.Record)
		if record ~= false and record.State == "Talking" then
			any = true
			break
		end
	end
	if not any then
		if self.Clock ~= nil then
			self.Clock:Disconnect()
			self.Clock = nil
		end
		return
	end
	if self.Clock ~= nil then
		return
	end
	local last = 0
	self.Clock = RunService.Heartbeat:Connect(function()
		const now = Workspace:GetServerTimeNow()
		if now - last < CLOCK_STEP then
			return
		end
		last = now
		self.Now(now)
		for _, spot in self.Spots do
			self:Cue(spot, now)
		end
	end)
end

function TabletController:MountDialog(gui: Instance)
	if self.DialogUnmount ~= nil then
		return
	end
	const unmount, screen = Vide.root(function()
		const talk = Vide.derive(function()
			return self:MyTalk()
		end)
		return Vide.create("ScreenGui")({
			Name = GUI_NAME,
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 5,
			TabletDialog({
				Shown = function()
					return talk() ~= nil and not Cinematic.Active()
				end,
				Speaker = function(): TabletDialog.Speaker
					const now = talk()
					return if now then now.Step.Speaker else "Player"
				end,
				Text = function()
					const now = talk()
					return if now then now.Step.Text else ""
				end,
				Items = function()
					const now = talk()
					return if now then now.Items else {}
				end,
				Reveal = function()
					const now = talk()
					return if now then now.Reveal else 0
				end,
				Scale = UiScale.Current,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -DIALOG_LIFT),
			}),
		})
	end)
	screen.Parent = gui
	self.DialogUnmount = unmount
end

-- Tablet Model bound by tag + TabletIndex
function TabletController:Bind(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const value = instance:GetAttribute(BINDING.TabletIndex)
	const index = if typeof(value) == "number" and instance:IsDescendantOf(Workspace) then value else nil
	for _, spot in self.Spots do
		if spot.Model == instance and spot.Index ~= index then
			spot.Model = nil
			self:DropBalloons(spot)
		end
	end
	if index == nil then
		return
	end
	const spot = self:SpotOf(index)
	if spot.Model == instance then
		return
	end
	spot.Model = instance
	self:DropBalloons(spot)
	self:Present(spot)
end

function TabletController:Track(instance: Instance)
	if self.Tracked[instance] ~= nil then
		return
	end
	local function bind()
		self:Bind(instance)
	end
	self.Tracked[instance] = {
		instance:GetAttributeChangedSignal(BINDING.TabletIndex):Connect(bind),
		instance.AncestryChanged:Connect(bind),
	}
	bind()
end

function TabletController:Untrack(instance: Instance)
	const connections = self.Tracked[instance]
	if connections == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, spot in self.Spots do
		if spot.Model == instance then
			spot.Model = nil
			self:DropBalloons(spot)
		end
	end
end

function TabletController:Watch(gui: Instance)
	self.Gui = gui
	const holder = Instance.new("Folder")
	holder.Name = "TabletBalloons"
	holder.Parent = gui
	self.Holder = holder
	self:MountDialog(gui)

	CollectionService:GetInstanceAddedSignal(BINDING.TabletTag):Connect(function(instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(BINDING.TabletTag):Connect(function(instance)
		self:Untrack(instance)
	end)
	for _, instance in CollectionService:GetTagged(BINDING.TabletTag) do
		self:Track(instance)
	end
	for _, spot in self.Spots do
		self:Present(spot)
	end
end

TabletController:OnInit(function(self)
	self:Setup()
	if not self:Enabled() then
		return -- trailer flow: inert
	end

	const tablets = Restaurant.Tablets
	tablets:onAdded(function(index, record)
		self:WriteRecord(index, record)
	end)
	tablets:onChanged(function(index, record)
		self:WriteRecord(index, record)
	end)
	tablets:onRemoved(function(index)
		self:WriteRecord(index, nil)
	end)
end)

TabletController:OnStart(function(self)
	if not self:Enabled() then
		return
	end
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return TabletController
