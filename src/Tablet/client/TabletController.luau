--!strict
--[[
	TabletController (TASK-383, R1-F; design FEAT-043, DEC-270 / DEC-280; tech/restaurant-flow.md rev. 2 §2.4 / §3.2)

	Presents the talk at the tablet; decides nothing (TabletService starts and ends the talk, CustomerService takes the
	order at the end).

	  - Tablets set (Net.Restaurant, record 1 = TAB-1, 2 = TAB-2, Rules.DrivePcIndex = DT-PC) -> one Vide source per tablet.
	  - The tablet Model is found by tag Binding.TabletTag + attribute Binding.TabletIndex; Binding.TabletScreen
	    (Att_Screen, optional) is where its balloon sits.
	  - Owner 2026-10-22 ("tira o botão de refuse... quando ele clicar em take order, ele vai dar aquele close na câmera...
	    daí ele vai de fila"; DEC-353's ACCEPT / REFUSE is history): one step. Take Order opens the close-up, the customer
	    says its line letter by letter and the talk ends by itself (the server takes the order at EndsAt, for every
	    customer). The line is Content.OrderSpeech (pure, the same the server times): an ordinary customer's hi, its order
	    and a thanks that fits it; an odd one's odd line (Content.OrderTalk: Silent / Garbled / Almost by night,
	    ByVariant for the Raincoat Lady); a tic's line on the tic's clock. The server never sends steps: every client
	    reads the same record, the same rig attributes and the same server clock, so all see the same.
	  - The player taking the order (User = me, Talking): TabletDialog on the screen (left, mid-height, never in the middle):
	    the line typed letter by letter in its text style (TypedText; Content.OrderTalk.Styles by the rig's Variant, or
	    Stressed for a share of the ordinary customers), the items popping in under it as the words naming them are typed
	    (plain whatever the style), SFX `ticket_pop` per item. `MyTalk()` exposes the reveal for the HUD note (HudOrder
	    `Reveal`, CustomerController, TASK-384); `MyClock()` is what the card reads every frame.
	  - Everybody else: the customer's line typing in a SpeechBalloon over the rig (OrderSpeech.Plain). For everyone at the
	    tablet: the customer's murmur (`order_take`) when it starts, a `dialog_blip` every OrderTalk.Speech.BlipWords words.
	  - Full (no free plate or pickup spot): "Kitchen full" balloon over the tablet for everyone (Dialog.KitchenFull).
	  - Leaving (owner 2026-10-21, like the cooking focus): the Back button (Components/BackButton, bottom left) and walking
	    (FocusExit: W A S D / arrows / Space, Backspace, gamepad B or left stick, the touch stick or jump) close my talk at
	    once on this screen and send TabletLeave { Index }; the server skips the rest of the talk and takes the order
	    at once (owner 2026-10-22: no waiting for the line every time). Leave(reason) is the one way out: "Button" (Back, Backspace, gamepad B), "Move"
	    (walking, the stick, touch), "Forced" (code: later talk screens / anomaly tics). It fires `Leaving` { Index, Npc,
	    Reason } - the hook for the anomaly tics (docs/design/anomaly-tics-proposal.md): leaving never solves, fails or
	    costs sanity here.
	  - Anomaly tics (design/anomaly-tics-proposal.md, pilot ANM-012, Provisional Q-459..Q-461): an odd customer whose
	    Variant has a Content.Tics row says the row's line: in the talk where its rig plays the tic (rig TicAt = this
	    talk's LineStart = StartedAt + OrderTalk.Speech.Start) it types on the server clock, freezes mid word, shows the
	    caption under the line while the neck cracks and finishes it (OrderSpeech.At; the style's Tic / Break layers
	    shake and disfigure the letters). After the tic (rig Tic = "Done") a new talk gets the short residue line. The
	    rig's attributes may arrive after the record: the speech is rebuilt when they do (speechOf). The body and the
	    screen layer are Effects/Kit/Tic's.
	    Owner 2026-10-22 (ANM-013 / ANM-004 / ANM-014, Provisional): the copy's echo line is Tics.Said(row, rig TicEcho,
	    the taker's DisplayName) (the original's hi, then the taker's own); a head that grows (rig local TicScale) makes my
	    close-up rise and back off with it (closeGoal, retargeted on the talk clock).
	    Owner 2026-10-22 (the tension in the talk, Provisional): the line freezes on "..." (Tics.Rules.Trail, in the line
	    itself) for the tic's Hold while the taker's tension builds (Effects/Kit/Tic: the bars come in over the card's
	    screen, so the card sits over them, DIALOG_ORDER; the close-up takes the horror jolt, CameraController).

	Content.Restaurant.Rules.Enabled = false: inert (no listener, no tag watch, no gui). No input of its own: the talk is
	the `tablet_take` prompt (PromptController binds keyboard, touch and gamepad). Listeners in OnInit (before
	Lync.start); tags and the gui in OnStart.
]]
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
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
local BackButton = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.BackButton)
local FocusExit = require(StarterPlayer.StarterPlayerScripts.client.Interface.FocusExit)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

const RESTAURANT = Content.Restaurant
const BINDING = RESTAURANT.Binding
const DIALOG = RESTAURANT.Dialog
const TALK_LINES = Content.OrderTalk
const SPEECH = TALK_LINES.Speech
const ORDER_SPEECH = Content.OrderSpeech
-- one sound per typed letter (owner 2026-10-22): Content.Sounds keys, and the pitch spread so a run of letters is not robotic
const TYPE_KEY = "talk_key"
const TYPE_ANOMALY = "talk_anomaly"
const TYPE_VARY = 0.08
const EXIT_PRIORITY = 2999 -- the talk's way out (and the close-up's held walk) over the interact key
const BALLOON_DISTANCE = 40
const BALLOON_LIFT = Vector3.new(0, 2.2, 0) -- studs over the head (or the tablet screen)
const FULL_LIFT = Vector3.new(0, 1.2, 0)
const GUI_NAME = "TabletDialog"
const CLOCK_STEP = 1 / 30 -- s between two clock writes while a talk runs (pop-ups land within a frame or two)
const DIALOG_LEFT = 24 -- px from the left edge (DEC-353 2nd pass: the card sits on the left, mid-height)
const DIALOG_ORDER = 42 -- over the horror bars (Scene/Kits Cinema, 40), under the whispers' old layer (45) and the jumpscare
const TICS = Content.Tics
const TIC_MATCH = 0.1 -- s: a rig TicAt this close to the talk's LineStart is this talk's tic

export type Speaker = "Player" | "Customer"

-- Why I left my talk (Leaving): Back / a leave key, walking, or code
export type LeaveReason = "Button" | "Move" | "Forced"
export type Leaving = { Index: number, Npc: number, Reason: LeaveReason }

export type Record = {
	State: string, -- "Idle" | "Talking" | "Full"
	Npc: number,
	User: number,
	StartedAt: number,
	EndsAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}

-- What the screen of the player taking the order reads (reactive through MyTalk, on the 30 Hz clock): the whole line,
-- how much of it is typed, its style and break, the caption, the items and how many popped
export type MyTalk = {
	Index: number,
	Npc: number,
	Items: { string },
	Reveal: number,
	Text: string,
	Typed: number,
	Caption: string?,
	Style: string,
	Break: number?,
	Speaker: Speaker,
}

-- What my card reads every frame (TypedText.Clock): chars typed and the speech's phase
export type Clock = { Typed: number, Phase: Content.SpeechPhase }

type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Odd: Vide.Source<string>, -- rig Variant of an odd customer (DEC-353), "" = ordinary
	Rig: Model?, -- the customer talking at it
	Model: Model?,
	BalloonUnmount: (() -> ())?,
	BalloonGui: Instance?,
	FullUnmount: (() -> ())?,
	FullGui: Instance?,
	LastTyped: number, -- letters typed at the last cue (one talk_key / talk_anomaly each)
	LastReveal: number, -- items popped for me (ticket_pop)
	Spoke: boolean, -- the murmur of this talk played
	Speech: Content.Speech?, -- the running talk's speech (Content.OrderSpeech), nil = not built yet
	SpeechKey: string, -- what it was built from (the talk and the rig's tic attributes)
	TalkKey: string,
}

-- A talk is on (owner 2026-10-22: one step, the customer talks, the order is taken at its end)
local function talking(record: Record): boolean
	return record.State == "Talking"
end

local function rigOf(npc: number): Model?
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == npc then
			return instance
		end
	end
	return nil
end

-- The speech of a talk (Content.OrderSpeech, the same the server timed). Built once per talk, and again when the rig's
-- tic attributes arrive or change (they may come after the record): TicAt on this talk's LineStart = its tic plays (the
-- echo's line from TicEcho and the taker's name), Tic = "Done" = the residue line. A speech built with its tic keeps it
-- to the end (the echo's attributes go as the talk ends). A plain function, not a method: no generated type change
local function speechOf(spot: Spot, record: Record, night: number): Content.Speech
	const odd = Vide.untrack(spot.Odd)
	const rig = spot.Rig
	const row = if odd ~= "" then TICS.ByVariant[odd] else nil
	local tic: Content.Tic? = nil
	local said: Content.TicSaid? = nil
	local residue = false
	local key = spot.TalkKey
	if row ~= nil and rig ~= nil then
		const ticAt = rig:GetAttribute("TicAt")
		if type(ticAt) == "number" and math.abs(ticAt - (record.StartedAt + SPEECH.Start)) < TIC_MATCH then
			const echo = rig:GetAttribute("TicEcho")
			const user = rig:GetAttribute("TicUser")
			const taker = if type(user) == "number" then Players:GetPlayerByUserId(user) else nil
			const name = if taker ~= nil then taker.DisplayName else ""
			tic = row
			said = TICS.Said(row, if type(echo) == "number" then echo else nil, name)
			key = `{key}|tic|{tostring(echo)}|{name}`
		elseif rig:GetAttribute("Tic") == "Done" then
			residue = true
			key = `{key}|done`
		end
	end
	const cached = spot.Speech
	if cached ~= nil and (spot.SpeechKey == key or (cached.Tic ~= nil and tic == nil)) then
		return cached
	end
	const speech = ORDER_SPEECH.Build({
		Npc = record.Npc,
		Variant = odd,
		Night = night,
		Order = record.Order,
		Order2 = record.Order2,
		Tic = tic,
		Said = said,
		Residue = residue,
	})
	spot.Speech = speech
	spot.SpeechKey = key
	return speech
end

-- Who the card's tab names: the customer, or "You" from the resume of a style with Voice = "You" (the copy says your line)
local function speakerOf(speech: Content.Speech, phase: Content.SpeechPhase): Speaker
	const style = TALK_LINES.Styles[speech.Style]
	return if style ~= nil and style.Voice == "You" and phase == "After" then "Player" else "Customer"
end

const TabletController = Modux.Controller("TabletController", {
	Require = { "AudioController", "RoundController", "CameraController" },
	Priority = 658,
})


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
	-- DEC-353 2nd pass: the close-up on the customer's face (my talk): the tablet whose parts I hid, their old modifiers
	self.CloseTablet = nil :: number?
	self.Hidden = {} :: { [BasePart]: number }
	self.CloseToken = 0
	-- the tablet whose talk I left (Back / walking) until its record stops talking (the server's skip); 0 = none
	self.Left = 0
	self.ExitUnbind = nil :: (() -> ())?
	-- fired once each time I leave my talk (after the screen freed, TabletLeave sent); the anomaly tics' hook
	self.Leaving = self.Libs.Signal.new() :: SignalLib.Signal<Leaving>
end

function TabletController:Enabled(): boolean
	return true
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

-- The speech of the talk at a spot, or nil (no talk there). Not reactive by itself (the record is read untracked)
function TabletController:SpeechAt(spot: Spot): (Record?, Content.Speech?)
	const record = Vide.untrack(spot.Record)
	if record == false or not talking(record) then
		return nil, nil
	end
	return record, speechOf(spot, record, Vide.untrack(self.Dependencies.RoundController.Night))
end

-- Reactive: the talk I am taking right now (nil = none), on the 30 Hz server clock (Now): the whole line, how much is
-- typed, its style, the caption, the items and how many popped (0..#Items, the HUD note reads it too)
function TabletController:MyTalk(): MyTalk?
	const index = self.Mine()
	const spot = if index ~= 0 then self.Spots[index] else nil
	if spot == nil then
		return nil
	end
	const record = spot.Record()
	if record == false or not talking(record) then
		return nil
	end
	const speech = speechOf(spot, record, Vide.untrack(self.Dependencies.RoundController.Night))
	const at = ORDER_SPEECH.At(speech, self.Now() - record.StartedAt)
	return {
		Index = index,
		Npc = record.Npc,
		Items = speech.Items,
		Reveal = at.Reveal,
		Text = speech.Text,
		Typed = at.Typed,
		Caption = at.Caption,
		Style = speech.Style,
		Break = speech.Break,
		Speaker = speakerOf(speech, at.Phase),
	}
end

-- Not reactive, every frame (my card's TypedText): chars typed and the phase of my talk on the live server clock. No talk
-- = the last clock (the card keeps its line while it folds away)
local lastClock: Clock = { Typed = 0, Phase = "Line" }
function TabletController:MyClock(): Clock
	const index = Vide.untrack(self.Mine)
	const spot = if index ~= 0 then self.Spots[index] else nil
	if spot == nil then
		return lastClock
	end
	const record, speech = self:SpeechAt(spot)
	if record == nil or speech == nil then
		return lastClock
	end
	const at = ORDER_SPEECH.At(speech, Workspace:GetServerTimeNow() - record.StartedAt)
	lastClock = { Typed = at.Typed, Phase = at.Phase }
	return lastClock
end

function TabletController:SpotOf(index: number): Spot
	const existing = self.Spots[index]
	if existing ~= nil then
		return existing
	end
	const spot: Spot = {
		Index = index,
		Record = Vide.source(false :: Record | false) :: Vide.Source<Record | false>,
		Odd = Vide.source("") :: Vide.Source<string>,
		Rig = nil,
		Model = nil,
		BalloonUnmount = nil,
		BalloonGui = nil,
		FullUnmount = nil,
		FullGui = nil,
		LastTyped = 0,
		LastReveal = 0,
		Spoke = false,
		Speech = nil,
		SpeechKey = "",
		TalkKey = "",
	}
	self.Spots[index] = spot
	return spot
end

local function isMine(record: Record | false): boolean
	return record ~= false and talking(record) and record.User == Players.LocalPlayer.UserId
end

-- My talk at this tablet and not one I already left (the cancel is on its way)
function TabletController:IsMyTalk(index: number, record: Record | false): boolean
	return isMine(record) and self.Left ~= index
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
	-- a new talk (another customer or another start): rig, odd variant, the speech and the heard words start over
	const key = if copy ~= false and talking(copy) then `{copy.Npc}@{copy.StartedAt}` else ""
	if key ~= spot.TalkKey then
		spot.TalkKey = key
		spot.LastTyped = 0
		spot.LastReveal = 0
		spot.Spoke = false
		spot.Speech = nil
		spot.SpeechKey = ""
		spot.Rig = if copy ~= false and copy.Npc ~= 0 then rigOf(copy.Npc) else nil
		const rig = spot.Rig
		const variant = if rig ~= nil then rig:GetAttribute("Variant") else nil
		spot.Odd(if type(variant) == "string" then variant else "")
	end
	spot.Record(copy)

	if self.Left == index and (copy == false or not talking(copy)) then
		self.Left = 0
	end
	-- my talk: the tablet I am at (one at a time; the last one written wins)
	if self:IsMyTalk(index, copy) then
		self.Mine(index)
	elseif Vide.untrack(self.Mine) == index then
		self.Mine(0)
	end
	self:Present(spot)
	self:RunClock()
	self:SyncCloseUp()
end

-- DEC-353 2nd pass (owner 2026-10-21: "ao clicar em takeorder ele vai dar um close no rosto do cliente (escondendo o
-- tablet q fica na frente)"): while my talk is on, the camera sits CloseUp.Distance studs in front of the customer's face
-- (CameraController:Prep, like the cooking focus), the tablet Model is hidden on my screen only (LocalTransparencyModifier)
-- and walking leaves the talk. It lets go CloseUp.Hold s after the talk ends (owner 2026-10-22: an anomaly whose order
-- was taken scares in the close-up first, "a animação dele surgindo a anomalia"; its module's).
-- The parts between the close-up's lens and the customer (window frame, shutter box, a sign): rays from the eye to a few
-- points of the head and the chest; every part hit that is not the customer hides on this screen (restored with the
-- tablet). At most OCCLUDER_HITS per ray.
const OCCLUDER_HITS = 6
const OCCLUDER_POINTS: { Vector3 } = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 0.9, 0),
	Vector3.new(0.8, 0.3, 0),
	Vector3.new(-0.8, 0.3, 0),
	Vector3.new(0, -1.4, 0),
}
-- the sampled view (2nd pass): offsets from the head, points per line, share of the way to the head they cover, margin
const VIEW_POINTS: { Vector3 } = {
	Vector3.new(0, 0, 0),
	Vector3.new(0, 1.3, 0),
	Vector3.new(1.3, 0.4, 0),
	Vector3.new(-1.3, 0.4, 0),
	Vector3.new(1.3, -1.4, 0),
	Vector3.new(-1.3, -1.4, 0),
	Vector3.new(0, -1.4, 0),
}
const VIEW_STEPS = 24
const VIEW_REACH = 0.92 -- stop short of the customer (the wall behind it never counts)
const VIEW_MARGIN = 0.1
function TabletController:HideBetween(eye: Vector3, rig: Model, head: BasePart, scope: Instance?)
	const ignore: { Instance } = { rig }
	-- my own body (owner print: it stood in the shot) is hidden by CameraController:SetBodyHidden, which owns its modifier
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(ignore, character)
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	for _, offset in OCCLUDER_POINTS do
		const target = head.Position + offset
		for _ = 1, OCCLUDER_HITS do
			params.FilterDescendantsInstances = ignore
			const result = Workspace:Raycast(eye, target - eye, params)
			if result == nil then
				break
			end
			const part = result.Instance
			table.insert(ignore, part)
			if part:IsA("BasePart") and self.Hidden[part] == nil then
				self.Hidden[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
			end
		end
	end
	-- owner 2026-10-21 (2nd print): most of the trailer's trim (shutter box, window trim, skins) has CanQuery off and never
	-- answers a ray. So the view is sampled - points along lines from the eye to the customer's head, shoulders and chest -
	-- and every part of the shop around the tablet (and every other rig) whose box holds one of them hides too
	const candidates: { BasePart } = {}
	local function collect(root: Instance?)
		if root == nil then
			return
		end
		for _, part in root:GetDescendants() do
			if part:IsA("BasePart") and self.Hidden[part] == nil and not part:IsDescendantOf(rig) then
				table.insert(candidates, part)
			end
		end
	end
	collect(scope)
	for _, other in CollectionService:GetTagged(CrewRig.Tag) do
		if other ~= rig and other:IsA("Model") then
			collect(other)
		end
	end
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer then
			collect(player.Character)
		end
	end
	const samples: { Vector3 } = {}
	for _, offset in VIEW_POINTS do
		const target = head.Position + offset
		-- step 0 = the eye itself: a part the lens starts inside hides too
		for step = 0, VIEW_STEPS do
			table.insert(samples, eye:Lerp(target, step / (VIEW_STEPS + 1) * VIEW_REACH))
		end
	end
	const span = (head.Position - eye).Magnitude + 2
	for _, part in candidates do
		const half = part.Size / 2 + Vector3.one * VIEW_MARGIN
		-- far from the view: skip without testing the points
		if (part.Position - eye).Magnitude > span + half.Magnitude then
			continue
		end
		for _, point in samples do
			const p = part.CFrame:PointToObjectSpace(point)
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				self.Hidden[part] = part.LocalTransparencyModifier
				part.LocalTransparencyModifier = 1
				break
			end
		end
	end
end

const FACE_SIDE = 0.2 -- cos: the customer's face counts as turned to my side above this (about 78 degrees)
-- The close-up follows a head that grows (anomaly tics, ANM-014, owner 2026-10-22, Provisional; proposal §5.3): the rig's
-- local TicScale (Effects/Kit/Tic) = how many times its normal size the head is now. The aim stays on the head (it rises
-- with it), the lens backs off FOLLOW_BACK x the growth and the field of view opens FOLLOW_FOV degrees per 1.0 of growth
-- (x1.9 = +2.7). Retargeted on the talk clock, smoothed by the prep springs (FOLLOW_OMEGA 1/s)
const TIC_SCALE = "TicScale"
const FOLLOW_BACK = 0.6
const FOLLOW_FOV = 3
const FOLLOW_OMEGA = 7
const FOLLOW_EPSILON = 0.005

-- The close-up on `rig` now: its axis (forward, right) and the scale it was last framed at
type CloseFollow = { Rig: Model, Forward: Vector3, Right: Vector3, Scale: number }
local closeFollow: CloseFollow? = nil

local function ticScale(rig: Model): number
	const value = rig:GetAttribute(TIC_SCALE)
	return if type(value) == "number" and value > 0 then value else 1
end

-- Eye, aim and field of view of the close-up on `head` along `forward` with the head `scale` x its size
local function closeGoal(head: BasePart, forward: Vector3, right: Vector3, scale: number): (Vector3, Vector3, number)
	const close = TALK_LINES.CloseUp
	const grow = math.max(0, scale - 1)
	const aim = head.Position - Vector3.yAxis * close.Drop * scale - right * close.Shift * (1 + grow * FOLLOW_BACK)
	const eye = head.Position + forward * close.Distance * (1 + grow * FOLLOW_BACK) + Vector3.yAxis * close.Lift
	return eye, aim, close.Fov + grow * FOLLOW_FOV
end
const CLOSE_FREEZE = "TabletCloseUpFreeze"
const TALK_EXIT = "TabletTalkExit"
const CLOSE_UP_ATTRIBUTE = "TalkCloseUp" -- on LocalPlayer while the close-up is on (the tutorial beacon hides)
-- while my talk is on, these leave it (FocusExit adds walking)
const EXIT_KEYS: { Enum.KeyCode } = { Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB }
-- the gamepad's jump is only swallowed (its A is not a way out)
const EXIT_SINK: { Enum.KeyCode } = { Enum.KeyCode.ButtonA }
-- the default walk / jump inputs held in the CloseUp.Hold after the talk (the touch thumbstick goes off with
-- TouchControlsEnabled): an anomaly whose order was just taken scares in the close-up first, walking does not cut it
const FREEZE_INPUTS: { Enum.KeyCode } = table.clone(FocusExit.Walk)
table.insert(FREEZE_INPUTS, Enum.KeyCode.Thumbstick1)
table.insert(FREEZE_INPUTS, Enum.KeyCode.ButtonA)

-- The close-up lets go: the hidden parts come back, the body, walking and the camera
function TabletController:ReleaseCloseUp()
	const camera = self.Dependencies.CameraController
	self.CloseTablet = nil
	closeFollow = nil
	for part, modifier in self.Hidden do
		part.LocalTransparencyModifier = modifier
	end
	table.clear(self.Hidden)
	camera:SetBodyHidden(false)
	ContextActionService:UnbindAction(CLOSE_FREEZE)
	GuiService.TouchControlsEnabled = true
	Players.LocalPlayer:SetAttribute(CLOSE_UP_ATTRIBUTE, nil)
	if Vide.untrack(camera.Mode) == "Prep" then
		camera:Prep(false, nil, { Travel = TALK_LINES.CloseUp.Travel })
	end
end

function TabletController:UnbindExit()
	const unbind = self.ExitUnbind
	if unbind ~= nil then
		self.ExitUnbind = nil
		unbind()
	end
end

-- I leave my talk (Back, walking; owner 2026-10-21): the screen frees at once, the server skips it and takes the order
-- (TabletLeave, owner 2026-10-22). The
-- one way out of the talk screen: anything else that has to end it on this client calls this
function TabletController:Leave(reason: LeaveReason?)
	const index = Vide.untrack(self.Mine)
	const spot = if index ~= 0 then self.Spots[index] else nil
	const record: Record | false = if spot ~= nil then Vide.untrack(spot.Record) else false
	if spot == nil or not self:IsMyTalk(index, record) then
		return
	end
	self.Left = index
	self.Mine(0)
	Restaurant.TabletLeave:fireServer(index)
	self:Present(spot)
	self:SyncCloseUp(true)
	self.Leaving:Fire({ Index = index, Npc = if record ~= false then record.Npc else 0, Reason = reason or "Forced" })
end

-- `now` = let go at once (I left), else after CloseUp.Hold
function TabletController:SyncCloseUp(now: boolean?)
	const index = Vide.untrack(self.Mine)
	const spot = if index ~= 0 then self.Spots[index] else nil
	const rig = if spot ~= nil then spot.Rig else nil
	const head = if rig ~= nil then rig:FindFirstChild("Head") else nil
	const camera = self.Dependencies.CameraController
	const close = TALK_LINES.CloseUp
	-- walking does not walk while my talk is on: it leaves (the touch stick stays on and leaves too); with or without the
	-- close-up (a rig not streamed yet)
	if spot == nil then
		self:UnbindExit()
	elseif self.ExitUnbind == nil then
		self.ExitUnbind = FocusExit.Bind({
			Name = TALK_EXIT,
			Priority = EXIT_PRIORITY,
			OnLeave = function(walked: boolean)
				self:Leave(if walked then "Move" else "Button")
			end,
			Leave = EXIT_KEYS,
			Sink = EXIT_SINK,
			Stick = true,
			Touch = true,
		})
	end
	if spot ~= nil and head ~= nil and head:IsA("BasePart") then
		self.CloseToken += 1
		if self.CloseTablet == index then
			return
		end
		self.CloseTablet = index
		-- the camera stands on my side of the counter: from the customer toward me (owner print: the customer's own facing
		-- put it inside the trailer when it did not face the counter); its facing only when I have no body
		const mine = Players.LocalPlayer.Character
		const root = if mine ~= nil then mine:FindFirstChild("HumanoidRootPart") else nil
		-- owner 2026-10-21 ("câmera na frente do NPC, olhar para ele nos olhos"): the lens on the axis of its face, so the
		-- customer looks straight into it; the face only while it points to my side, else the old way toward me
		local facing = Vector3.new(head.CFrame.LookVector.X, 0, head.CFrame.LookVector.Z)
		if root ~= nil and root:IsA("BasePart") then
			const toward = Vector3.new(root.Position.X - head.Position.X, 0, root.Position.Z - head.Position.Z)
			if toward.Magnitude > 1e-3 and (facing.Magnitude < 1e-3 or facing.Unit:Dot(toward.Unit) < FACE_SIDE) then
				facing = toward
			end
		end
		const forward = if facing.Magnitude > 1e-3 then facing.Unit else Vector3.zAxis
		-- a medium shot (owner sketch): the customer on the right half, the talk card on the left. The lens stays on the
		-- face's axis and turns its aim to the screen's left instead of sliding (a slid lens saw the face from the side).
		-- The camera looks back along -forward; its right is (-forward) x up, so aiming at -right puts the customer right
		const right = (-forward):Cross(Vector3.yAxis)
		const scale = ticScale(rig :: Model)
		const eye, aim, fov = closeGoal(head, forward, right, scale)
		closeFollow = { Rig = rig :: Model, Forward = forward, Right = right, Scale = scale }
		camera:Prep(true, CFrame.lookAt(eye, aim), { Fov = fov, Travel = close.Travel, Min = 0.2, Look = aim })
		const model = spot.Model
		if model ~= nil then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and self.Hidden[part] == nil then
					self.Hidden[part] = part.LocalTransparencyModifier
					part.LocalTransparencyModifier = 1
				end
			end
		end
		-- owner 2026-10-21 (print: "o chapéu tá cobrindo o rosto" - the shutter box over the service window): anything else
		-- between the lens and the customer hides on this screen too
		camera:SetBodyHidden(true)
		self:HideBetween(eye, rig :: Model, head, if model ~= nil then model:FindFirstAncestor("Trailer") or model.Parent else nil)
		-- a close-up still letting go from the last talk: its hold ends here
		ContextActionService:UnbindAction(CLOSE_FREEZE)
		GuiService.TouchControlsEnabled = true
		-- the tutorial's contour and arrow on the tablet hide meanwhile (TutorialController Beacon reads it)
		Players.LocalPlayer:SetAttribute(CLOSE_UP_ATTRIBUTE, true)
		return
	end
	if self.CloseTablet == nil then
		return
	end
	self.CloseToken += 1
	if now then
		self:ReleaseCloseUp()
		return
	end
	ContextActionService:BindActionAtPriority(CLOSE_FREEZE, function(): Enum.ContextActionResult
		return Enum.ContextActionResult.Sink
	end, false, EXIT_PRIORITY, table.unpack(FREEZE_INPUTS))
	GuiService.TouchControlsEnabled = false
	const token = self.CloseToken
	task.delay(close.Hold, function()
		if self.CloseToken ~= token or self.CloseTablet == nil then
			return
		end
		self:ReleaseCloseUp()
	end)
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
	const isTalking = record ~= false and talking(record)
	if spot.BalloonUnmount ~= nil and (not isTalking or spot.BalloonGui == nil or spot.BalloonGui:GetAttribute("Talk") ~= spot.TalkKey) then
		spot.BalloonUnmount()
		spot.BalloonUnmount = nil
		if spot.BalloonGui ~= nil then
			spot.BalloonGui:Destroy()
			spot.BalloonGui = nil
		end
	end
	if isTalking and spot.BalloonUnmount == nil then
		const rig = spot.Rig
		const head = if rig ~= nil then rig:FindFirstChild("Head") else nil
		const adornee = head or self:Anchor(spot)
		if adornee ~= nil then
			const unmount, gui = Vide.root(function()
				-- the customer's line typing for everyone else (owner 2026-10-22), plain (OrderSpeech.Plain), on the 30 Hz clock
				const said = Vide.derive(function(): string
					const now = spot.Record()
					if now == false or not talking(now) then
						return ""
					end
					const speech = speechOf(spot, now, Vide.untrack(self.Dependencies.RoundController.Night))
					return ORDER_SPEECH.Plain(speech, ORDER_SPEECH.At(speech, self.Now() - now.StartedAt).Typed)
				end)
				return SpeechBalloon({
					Name = `TabletBalloon_{spot.Index}`,
					Adornee = adornee,
					StudsOffset = BALLOON_LIFT,
					MaxDistance = BALLOON_DISTANCE,
					Visible = function()
						return said() ~= "" and not isMine(spot.Record()) and not Cinematic.Active()
					end,
					Text = said,
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

-- Sounds of the running talks (everyone, at the tablet): the customer's murmur (order_take) when its line starts, then
-- one sound per typed letter (owner 2026-10-22; was a dialog_blip every OrderTalk.Speech.BlipWords words): a keyboard key
-- for an ordinary customer, the 80 Hz triangle pulse for an anomaly (the tic's freeze is silent: nothing is typed);
-- ticket_pop per item that pops on my card
function TabletController:Cue(spot: Spot, now: number)
	const record, speech = self:SpeechAt(spot)
	if record == nil or speech == nil then
		return
	end
	const at = ORDER_SPEECH.At(speech, now - record.StartedAt)
	const audio = self.Dependencies.AudioController
	const where = spot.Rig or self:Anchor(spot)
	if at.Typed > 0 and not spot.Spoke then
		spot.Spoke = true
		if where ~= nil then
			audio:Play("order_take", where)
		end
	end
	if at.Typed > spot.LastTyped then
		spot.LastTyped = at.Typed
		if where ~= nil then
			const key = if Vide.untrack(spot.Odd) ~= "" then TYPE_ANOMALY else TYPE_KEY
			audio:Play(key, where, { Vary = TYPE_VARY })
		end
	end
	if self:IsMyTalk(spot.Index, record) and at.Reveal > spot.LastReveal then
		spot.LastReveal = at.Reveal
		audio:Play("ticket_pop")
	end
end

-- Server clock while a talk runs (Heartbeat, CLOCK_STEP); stops when every tablet is idle
function TabletController:RunClock()
	local any = false
	for _, spot in self.Spots do
		const record = Vide.untrack(spot.Record)
		if record ~= false and talking(record) then
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
		-- a head that grows in my close-up (ANM-014): the lens rises and backs off with it
		const follow = closeFollow
		if follow ~= nil then
			const scale = ticScale(follow.Rig)
			const head = follow.Rig:FindFirstChild("Head")
			if math.abs(scale - follow.Scale) > FOLLOW_EPSILON and head ~= nil and head:IsA("BasePart") then
				follow.Scale = scale
				const eye, aim, fov = closeGoal(head, follow.Forward, follow.Right, scale)
				self.Dependencies.CameraController:PrepGoal(eye, aim, fov, FOLLOW_OMEGA)
			end
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
		-- the line, its style and break keep the last talk's while the card folds away (no talk = the last ones)
		local lastText = ""
		local lastStyle: Content.TalkStyle? = nil
		local lastBreak: number? = nil
		const text = Vide.derive(function(): string
			const now = talk()
			if now ~= nil then
				lastText = now.Text
			end
			return lastText
		end)
		const style = Vide.derive(function(): Content.TalkStyle?
			const now = talk()
			if now ~= nil then
				lastStyle = TALK_LINES.Styles[now.Style]
			end
			return lastStyle
		end)
		const broken = Vide.derive(function(): number?
			const now = talk()
			if now ~= nil then
				lastBreak = now.Break
			end
			return lastBreak
		end)
		return Vide.create("ScreenGui")({
			Name = GUI_NAME,
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			-- owner 2026-10-22: a tic's black bars (HorrorScenes Cinema, 40) come in during the talk; the card and the Back
			-- button stay over them (under the jumpscare, 50)
			DisplayOrder = DIALOG_ORDER,
			TabletDialog({
				Shown = function()
					return talk() ~= nil and not Cinematic.Active()
				end,
				Speaker = function(): TabletDialog.Speaker
					const now = talk()
					return if now then now.Speaker else "Customer"
				end,
				-- owner 2026-10-22: the customer's line letter by letter, in its style (TypedText reads MyClock every frame)
				Text = text,
				Clock = function()
					return self:MyClock()
				end,
				Style = style,
				Break = broken,
				Caption = function(): string?
					const now = talk()
					return if now then now.Caption else nil
				end,
				Items = function()
					const now = talk()
					return if now then now.Items else {}
				end,
				Reveal = function()
					const now = talk()
					return if now then now.Reveal else 0
				end,
				-- DEC-353 2nd pass: on the left, mid-height, bigger (the camera is on the customer's face)
				Scale = function(): number
					return UiScale.Current() * TALK_LINES.DialogScale
				end,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, DIALOG_LEFT, 0.5, 0),
			}),
			-- owner 2026-10-21: the same Back as the cooking focus (bottom left); walking does the same (FocusExit)
			BackButton({
				Name = "TalkBack",
				OnBack = function()
					self:Leave("Button")
				end,
				Scale = UiScale.Current,
				Visible = function()
					return talk() ~= nil and not Cinematic.Active()
				end,
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
