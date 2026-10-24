--!strict
--[[
	BossController (TASK-071; FEAT-018; architecture.md §19.9 Client; network.md §13.3; AST-042; DEC-076, 077, 124)

	Reads the `Call` set (record 1) and presents the boss call; BossService decides everything (queue, answer,
	auto-answer, line timing). Nothing here is ever sent back: answering is the phone's `Prompt_Answer`
	(answer_phone) through PromptController/InteractionService.

	  Ringing  the phone of the current vehicle (RoundController.Vehicle: the trailer, the only vehicle) blinks its
	           lamp and shows 2D sound ripples; the `phone_ring` loop plays at the phone (3D roll-off = quieter far
	           away). No subtitle while ringing (ui-text.md §12.4).
	  Talking  subtitle "Walt: <line>" at the bottom (CallSubtitle). Line = floor((now - StartedAt) / LineTime) of
	           BossCalls.LinesOf(Call, Shift.Night), the same for everyone; whoever joins mid-call gets only the
	           remaining lines (T44). After the last line the strip hides even if the record is still Talking.
	  Idle     everything off, lamp restored as authored.

	Fittings (AST-042): `Light_Ring` (Neon part) and `VFX_Ring` (ripples) are not on the model yet. Fallbacks, no
	error and no warn: lamp = parts named `*_Lamp` of the phone model (Trailer_Lamp); ripples = on the
	lamp, else above the phone's top. Phone = model with MapId TRL-PHONE inside the current `Vehicle`,
	else the model holding the `answer_phone` anchor. A late fitting (streaming, swap) re-resolves.

	Sound: ids are "" until TASK-087 (Q-168): no Sound is created, nothing is played. The voice (SFX-082) has no key
	in Content.Sounds yet: subtitles only (Provisional). When AudioController (TASK-076) lands, it can read `State`
	for the ducking (SoundRules.DuckOnCall). Phone hallucination is HallucinationController's, not this one.

	Public sources (read-only for other controllers): State ("Idle" | "Ringing" | "Talking"), Call (key), Text,
	Speaker, Showing (subtitle on screen).

	Held subtitle (user request 2026-10-11, Provisional): during the first-hot-dog tutorial call (BossCalls Trigger
	Tutorial) TutorialController owns the strip: Hold(true) stops the timed lines, Say(text) shows one of Walt's step
	lines (nil hides). Hold(false) gives the strip back to the timed lines (by then past their time: hidden).

	Voice (user request 2026-10-11: the day-5 call showed the subtitle and Walt stayed mute; only the tutorial call had a
	voice): every other call is voiced here with Walt's text-to-speech, the cutscene's Speech module (Voices.walt of
	Content.Cutscenes.Rules; the voice health, the warnings and the one audio LoadQueue are shared with the intro and the
	tutorial call, which keep their own Speech instance). Lines are loaded ahead: the lines of the call that rings or
	talks, and of the calls of this shift and the next one (day / night / hints, PrepareUpcoming, queued after
	the loading gate), so a line is Loaded by its beat. Say(line) plays on the server timeline (subtitle and voice
	start together; a line never cuts the one speaking). A line that gets no voice warns once per reason with its cause.
	The tutorial call (Held) is voiced by TutorialController, never here.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Speech = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Speech)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local CallSubtitle = require(Components.CallSubtitle)
local Theme = require(Components.Theme)

const RECORD_ID = 1 -- single record (network.md §13.3)
const SHIFT_ID = 1 -- Shift record (network.md §3.1): Night picks the Short lines of a repeated night
const NONE = "none"
const SPEAKER = "Walt" -- BossCalls Line.Speaker nil
const TICK_RATE = 10 -- Hz: line changes every 2.5 s, lamp blinks at 2 Hz
const BLINK_HZ = 2

const VEHICLE_TAG = "Vehicle"
const INTERACTABLE_TAG = "Interactable"
const PHONE_ACTION = "answer_phone"
const LINE_NOISE = "phone_line" -- Content.Sounds loop at the phone while Walt talks
const PHONE_IDS: { [string]: boolean } = { ["TRL-PHONE"] = true }
const LIGHT_NAME = "Light_Ring"
const VFX_NAME = "VFX_Ring"
const LAMP_SUFFIX = "_Lamp"

const LAMP_ON = Theme.Color.Mustard -- AST-042: Neon Mustard lamp, blinks while ringing
-- 2D ripples: px so they read on a phone; scale part grows with distance a little
const RIPPLE_SIZE = UDim2.new(2, 60, 2, 60)
const RIPPLE_RISE = 0.4
const RIPPLE_PERIOD = 1.2
const RIPPLE_MAX_DISTANCE = 70

-- Voice (Provisional): Walt's key in Content.Cutscenes.Rules.Voices; the lines of the calls are loaded ahead
const VOICE_SPEAKER = "walt"
const VOICE_WARNINGS = 3 -- no-voice warnings per session (one per distinct reason)
const PREPARE_AFTER = 8 -- s after the start before the background load of the upcoming calls (loading gate first)

export type Record = {
	Call: string,
	State: string,
	StartedAt: number,
}

type Lamp = {
	Part: BasePart,
	Color: Color3,
	Material: Enum.Material,
}

type Phone = {
	Model: Instance,
	Lamps: { Lamp },
	Ripple: Instance?, -- adornee of the ripples
	RippleOffset: Vector3,
	Speaker: BasePart?, -- host of the ring Sound
}

const BossController =
	Modux.Controller("BossController", { Require = { "RoundController", "AudioController", "ObjectiveController" }, Priority = 660 })

function BossController:Setup()
	self.State = Vide.source("Idle") :: Vide.Source<string>
	self.Call = Vide.source(NONE) :: Vide.Source<string>
	self.Text = Vide.source("") :: Vide.Source<string>
	self.Speaker = Vide.source(SPEAKER) :: Vide.Source<string>
	self.Showing = Vide.source(false) :: Vide.Source<boolean>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	-- where the line noise loop plays (nil = off)
	self.LineAt = nil :: Instance?
	self.RippleAt = Vide.source(0) :: Vide.Source<number>
	self.StartedAt = 0 :: number
	self.Lines = {} :: { Content.BossCallLine }
	self.LinesNight = 0 :: number
	self.LineIndex = 0 :: number
	self.LampOn = false :: boolean
	self.Phone = nil :: Phone?
	self.PhoneGuided = nil :: Instance? -- the phone marked by GuidePhone (nil = no mark of ours)
	self.Vehicle = nil :: Instance?
	self.VehicleConnections = {} :: { RBXScriptConnection }
	self.RippleGui = nil :: BillboardGui?
	self.RippleUnmount = nil :: (() -> ())?
	self.RingSound = nil :: Sound?
	self.Gui = nil :: ScreenGui?
	-- TutorialController drives the subtitle (Hold/Say)
	self.Held = false :: boolean
	-- Walt's voice for the calls (built on first use) and the call keys already queued for loading
	self.Speech = nil :: Speech.Speech?
	self.Prepared = {} :: { [string]: boolean }
	self.PreparedFor = "" :: string -- "day:night" of the last PrepareUpcoming
	self.StartedClock = os.clock() :: number
	self.Warned = {} :: { [string]: boolean }
	self.Warnings = 0 :: number
	self.CancelSay = nil :: (() -> ())?
end

-- Voice -----------------------------------------------------------------------------------------------------------

function BossController:Voice(): Speech.Speech
	const existing = self.Speech
	if existing ~= nil then
		return existing
	end
	const created = Speech.new(function(): number
		const volumes = self.Dependencies.AudioController.Volumes
		return (volumes.Master or 1) * (volumes.Voice or 1)
	end, function(): Instance?
		return self:PhoneSpeaker()
	end)
	self.Speech = created
	return created
end

-- Where Walt's voice and the line noise come from (owner 2026-10-23: from the phone); nil = no phone found (on screen)
function BossController:PhoneSpeaker(): Instance?
	const phone = self.Phone
	return if phone ~= nil then phone.Speaker else nil
end

local function beatOf(text: string, speaker: string?): Content.CutsceneBeat
	const who = speaker or VOICE_SPEAKER
	return { At = 0, Kind = "Line", Target = who, Speaker = who, Text = text }
end

-- Queues the voice of every line of a call (once per key and night: a repeated night appends its Short lines)
function BossController:PrepareCall(key: string, night: number)
	const id = `{key}:{night}`
	if self.Prepared[id] or Content.BossCalls.ByKey[key] == nil then
		return
	end
	self.Prepared[id] = true
	const beats: { Content.CutsceneBeat } = {}
	for _, line in Content.BossCalls.LinesOf(key, night) do
		table.insert(beats, beatOf(line.Text))
	end
	if #beats > 0 then
		self:Voice().Prepare(beats)
	end
end

-- Calls of this shift and the next: day / night / trailer rows by trigger, plus the one-liner hints. Never the
-- tutorial call (TutorialController voices it).
function BossController:PrepareUpcoming()
	const round = self.Dependencies.RoundController
	if not round.Ready() then
		return
	end
	const day = round.Day()
	const night = round.Night()
	const stamp = `{day}:{night}`
	if stamp == self.PreparedFor then
		return
	end
	self.PreparedFor = stamp
	const tutorial = Content.BossCallRules.Tutorial.Call
	for _, row in Content.BossCalls.List do
		const trigger = row.Trigger
		const kind = trigger.Kind
		local wanted = false
		if kind == "DayPrep" then
			wanted = if trigger.Day ~= nil
				then trigger.Day == day or trigger.Day == day + 1
				else trigger.Night ~= nil and (trigger.Night == night or trigger.Night == night + 1)
		elseif kind == "NightCall" or kind == "NightCoffee" then
			wanted = trigger.Night == night or trigger.Night == night + 1
		elseif kind == "Hint" or kind == "NightRepeat" then
			wanted = true
		elseif kind == "LostCritical" or kind == "LostLastChance" then
			wanted = round.IsNight()
		end
		if wanted and row.Key ~= tutorial then
			self:PrepareCall(row.Key, night)
			if kind == "NightCall" and row.Short ~= nil then
				-- the short form that follows the NightRepeat opener
				const beats: { Content.CutsceneBeat } = {}
				for _, line in row.Short do
					table.insert(beats, beatOf(line.Text))
				end
				self:Voice().Prepare(beats)
			end
		end
	end
end

function BossController:WarnSilent(line: Content.CutsceneBeat)
	const reason = self:Voice().Reason(line)
	const key = if reason ~= "" then reason else "late"
	if self.Warned[key] or self.Warnings >= VOICE_WARNINGS then
		return
	end
	self.Warned[key] = true
	self.Warnings += 1
	const why = if reason ~= "" then reason else "its voice was not loaded in time"
	warn(`[BossController] Walt's line "{line.Text or ""}" goes on as a subtitle only: {why}`)
end

-- Walt says the line on screen now; the subtitle never waits for it
-- speaker = a Content.Cutscenes.Rules.Voices key (nil = Walt); the radio stranger is "radio"
function BossController:Speak(text: string, speaker: string?)
	const beat = beatOf(text, speaker)
	self.CancelSay = self:Voice().Say(beat, {
		OnMiss = function(_line: Content.CutsceneBeat)
			self:WarnSilent(beat)
		end,
	})
end

-- The call ended or changed: the voice stops (nothing speaks over the next call)
function BossController:Quiet()
	const cancel = self.CancelSay
	self.CancelSay = nil
	if cancel ~= nil then
		cancel()
	end
	const speech = self.Speech
	if speech ~= nil then
		speech.Stop()
	end
end

-- Records ------------------------------------------------------------------------------------------------------------

function BossController:Night(): number
	const shift = self.Libs.Net.Shift:get(SHIFT_ID)
	return if shift then shift.Night else 0
end

function BossController:Apply(record: Record)
	const previous = self.State()
	const previousCall = self.Call()
	const key = if Content.BossCalls.ByKey[record.Call] then record.Call else NONE
	if key ~= previousCall or record.State ~= "Talking" or record.StartedAt ~= self.StartedAt then
		self:Quiet()
	end
	if key ~= NONE and record.State ~= "Idle" and key ~= Content.BossCallRules.Tutorial.Call then
		self:PrepareCall(key, self:Night())
	end
	self.StartedAt = record.StartedAt
	self.LinesNight = self:Night()
	self.Lines = if key == NONE then {} else Content.BossCalls.LinesOf(key, self.LinesNight)
	-- -1 = rewrite the strip on the Refresh below (0 would read as "nothing shown": a call that ends while its last line is up
	-- left that line on screen for good, owner 2026-10-19)
	self.LineIndex = -1
	Vide.batch(function()
		self.Call(key)
		self.State(record.State)
		if self.Held and record.State ~= "Talking" then
			self.Showing(false) -- hung up: the held line goes with the call
		end
	end)
	if previous == "Ringing" and record.State == "Talking" then
		self:PlayOnce("phone_pickup")
	elseif previous == "Talking" and record.State ~= "Talking" then
		self:PlayOnce("phone_hangup") -- end of the call (user request 2026-10-10)
	end
	self:SetLineNoise(record.State == "Talking")
	self:Refresh()
end

-- The phone line under Walt's voice (owner 2026-10-23: "coloca mais ruído"): a hiss loop at the phone while the call talks
function BossController:SetLineNoise(on: boolean)
	const audio = self.Dependencies.AudioController
	const at = if on then self:PhoneSpeaker() else nil
	const current = self.LineAt
	if current ~= nil and current ~= at then
		audio:Loop(LINE_NOISE, current, false)
		self.LineAt = nil
	end
	if at ~= nil and current ~= at then
		audio:Loop(LINE_NOISE, at, true)
		self.LineAt = at
	end
end

-- The tutorial takes (true) or gives back (false) the subtitle strip
function BossController:Hold(on: boolean)
	if self.Held == on then
		return
	end
	self.Held = on
	if on then
		self.LineIndex = 0
		self.Showing(false)
	else
		self.LineIndex = -1 -- rewrite from the timed lines
		self:Refresh()
	end
end

-- One line of Walt while held (nil hides the strip)
function BossController:Say(text: string?)
	if not self.Held then
		return
	end
	Vide.batch(function()
		if text ~= nil then
			self.Text(text)
			self.Speaker(SPEAKER)
		end
		self.Showing(text ~= nil)
	end)
end

-- Current line by server time; writes the sources only when something changed.
function BossController:Refresh()
	const now = workspace:GetServerTimeNow()
	const state = self.State()

	-- a late Shift record (join mid-call) changes the Short lines of a repeated night
	if state == "Talking" then
		const night = self:Night()
		if night ~= self.LinesNight then
			self.LinesNight = night
			self.Lines = Content.BossCalls.LinesOf(self.Call(), night)
			self.LineIndex = -1 -- rewrite the current line
		end
	end

	local index = 0
	if state == "Talking" and #self.Lines > 0 then
		const at = Content.BossCalls.LineAt(self.Lines, now - self.StartedAt) -- each line = its voice length
		if at >= 1 and at <= #self.Lines then
			index = at
		end
	end
	if not self.Held and index ~= self.LineIndex then
		self.LineIndex = index
		const line = self.Lines[index]
		Vide.batch(function()
			if line then
				self.Text(line.Text)
				self.Speaker(line.Speaker or SPEAKER)
			end
			self.Showing(line ~= nil)
		end)
		if line ~= nil and self.Call() ~= Content.BossCallRules.Tutorial.Call then
			self:Speak(line.Text)
		end
	end

	const ringing = state == "Ringing"
	self:SetLamp(ringing and math.floor(now * BLINK_HZ * 2) % 2 == 0)
	self:SetRing(ringing)
	if ringing then
		self.RippleAt(now)
	end
	self:GuidePhone(ringing)
end

-- Ringing: the arrow + highlight of the objective point at the phone until somebody answers (owner 2026-10-19: "setas
-- me guiando para atender o telefone"). Cleared only if the mark is still ours (another objective may have taken it).
function BossController:GuidePhone(ringing: boolean)
	const objective = self.Dependencies.ObjectiveController
	const phone = self.Phone
	const target = if phone then phone.Model else nil
	-- the tutorial guides to the phone itself (one arrow, owner 2026-10-19)
	const tutorial = Players.LocalPlayer:GetAttribute("TutorialRunning") == true
	if ringing and target ~= nil and not tutorial then
		if self.PhoneGuided ~= target then
			self.PhoneGuided = target
			objective:Mark(target)
		end
	elseif self.PhoneGuided ~= nil then
		if objective.Beacon.Marked() == self.PhoneGuided then
			objective:Clear()
		end
		self.PhoneGuided = nil
	end
end

-- Phone lookup -------------------------------------------------------------------------------------------------------

function BossController:FindVehicle(): Instance?
	const key = self.Dependencies.RoundController.Vehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute("Vehicle") == key then
			return vehicle
		end
	end
	return nil
end

-- Model under the vehicle that holds `instance` (closest Model ancestor)
local function modelOf(instance: Instance, vehicle: Instance): Instance?
	local current = instance.Parent
	while current and current ~= vehicle do
		if current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function findPhoneModel(vehicle: Instance): Instance?
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") then
			const id = descendant:GetAttribute("MapId")
			if type(id) == "string" and PHONE_IDS[id] then
				return descendant
			end
		end
	end
	for _, anchor in CollectionService:GetTagged(INTERACTABLE_TAG) do
		if anchor:GetAttribute("PromptAction") == PHONE_ACTION and vehicle:IsAncestorOf(anchor) then
			return modelOf(anchor, vehicle)
		end
	end
	return nil
end

local function topPart(model: Instance): BasePart?
	local best: BasePart? = nil
	local bestTop = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			const top = descendant.Position.Y + descendant.Size.Y / 2
			if top > bestTop then
				bestTop = top
				best = descendant
			end
		end
	end
	return best
end

local function describe(model: Instance): Phone
	const lamps: { Lamp } = {}
	local ring: Instance? = nil
	local light: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant.Name == LIGHT_NAME and descendant:IsA("BasePart") then
			light = descendant
		elseif descendant.Name == VFX_NAME and (descendant:IsA("Attachment") or descendant:IsA("BasePart")) then
			ring = descendant
		end
	end
	if light then
		table.insert(lamps, { Part = light, Color = light.Color, Material = light.Material })
	else
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and string.sub(descendant.Name, -#LAMP_SUFFIX) == LAMP_SUFFIX then
				table.insert(lamps, { Part = descendant, Color = descendant.Color, Material = descendant.Material })
			end
		end
	end
	const top = topPart(model)
	local offset = Vector3.zero
	if ring == nil then
		const lamp = lamps[1]
		if lamp then
			ring = lamp.Part
			offset = Vector3.new(0, lamp.Part.Size.Y / 2 + RIPPLE_RISE, 0)
		elseif top then
			ring = top
			offset = Vector3.new(0, top.Size.Y / 2 + RIPPLE_RISE, 0)
		end
	end
	const first = lamps[1]
	return {
		Model = model,
		Lamps = lamps,
		Ripple = ring,
		RippleOffset = offset,
		Speaker = if first then first.Part else top,
	}
end

-- Lamp, ripples and ring ---------------------------------------------------------------------------------------------

function BossController:SetLamp(on: boolean)
	if on == self.LampOn then
		return
	end
	self.LampOn = on
	const phone = self.Phone
	if phone == nil then
		return
	end
	for _, lamp in phone.Lamps do
		-- local only: the server and other clients never see this write
		lamp.Part.Color = if on then LAMP_ON else lamp.Color
		lamp.Part.Material = if on then Enum.Material.Neon else lamp.Material
	end
end

function BossController:SetRing(on: boolean)
	const sound = self.RingSound
	if sound == nil then
		return
	end
	if on and not sound.IsPlaying then
		sound:Play()
	elseif not on and sound.IsPlaying then
		sound:Stop()
	end
end

-- Spatial Sound at the phone for a Content.Sounds key; nil while the id is "" (TASK-087)
function BossController:NewSound(key: string, host: BasePart): Sound?
	const row = Content.Sounds.ByKey[key]
	if row == nil or row.Id == "" then
		return nil
	end
	const sound = Instance.new("Sound")
	sound.Name = "Boss_" .. key
	sound.SoundId = row.Id
	sound.Volume = row.Volume
	sound.Looped = row.Looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = if row.MaxDistance > 0 then row.MaxDistance else 60
	sound.Parent = host
	return sound
end

function BossController:PlayOnce(key: string)
	const phone = self.Phone
	const host = if phone then phone.Speaker else nil
	if host == nil then
		return
	end
	const sound = self:NewSound(key, host)
	if sound then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end
end

-- 2D ripples (VFX_Ring): two rings growing and fading, one per half period
local function ripple(controller: any, phase: number): Frame
	local function alpha(): number
		return ((controller.RippleAt() / RIPPLE_PERIOD) + phase) % 1
	end
	return Vide.create("Frame")({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			const a = alpha()
			return UDim2.fromScale(0.3 + 0.7 * a, 0.3 + 0.7 * a)
		end,
		BackgroundTransparency = 1,
		Vide.create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		(Vide.create :: any)("UIStroke")({
			Color = LAMP_ON,
			Thickness = 4,
			Transparency = alpha,
		}),
	})
end

function BossController:ClearPhone()
	self:SetLamp(false)
	self:SetLineNoise(false)
	const unmount = self.RippleUnmount
	self.RippleUnmount = nil
	if unmount then
		unmount()
	end
	const gui = self.RippleGui
	self.RippleGui = nil
	if gui then
		gui:Destroy()
	end
	const sound = self.RingSound
	self.RingSound = nil
	if sound then
		sound:Destroy()
	end
	self.Phone = nil
end

function BossController:UsePhone(model: Instance?)
	const current = self.Phone
	if current and model == current.Model then
		return
	end
	self:ClearPhone()
	if model == nil then
		return
	end
	const phone = describe(model)
	self.Phone = phone

	const host = phone.Speaker
	if host then
		self.RingSound = self:NewSound("phone_ring", host)
	end
	-- a phone found mid-call (streaming, swap): the line noise moves to it
	self:SetLineNoise(Vide.untrack(self.State) == "Talking")

	const adornee = phone.Ripple
	const parent = self.Gui
	if adornee and parent then
		const unmount, gui = Vide.root(function()
			return Vide.create("BillboardGui")({
				Name = "PhoneRing",
				Adornee = adornee,
				Size = RIPPLE_SIZE,
				StudsOffset = phone.RippleOffset,
				MaxDistance = RIPPLE_MAX_DISTANCE,
				LightInfluence = 0,
				AlwaysOnTop = false,
				ResetOnSpawn = false,
				Enabled = function()
					return self.State() == "Ringing"
				end,
				ripple(self, 0),
				ripple(self, 0.5),
			})
		end)
		gui.Parent = parent
		self.RippleUnmount = unmount
		self.RippleGui = gui
	end
	-- same state as before the swap
	self.LampOn = false
	self:Refresh()
end

-- Follows the current vehicle model (Shift.Vehicle change, model streamed in or swapped).
function BossController:Track()
	const vehicle = self:FindVehicle()
	if vehicle ~= self.Vehicle then
		for _, connection in self.VehicleConnections do
			connection:Disconnect()
		end
		table.clear(self.VehicleConnections)
		self.Vehicle = vehicle
		if vehicle then
			local function relevant(descendant: Instance): boolean
				return descendant.Name == LIGHT_NAME
					or descendant.Name == VFX_NAME
					or string.sub(descendant.Name, -#LAMP_SUFFIX) == LAMP_SUFFIX
					or (descendant:IsA("Model") and type(descendant:GetAttribute("MapId")) == "string")
					or CollectionService:HasTag(descendant, INTERACTABLE_TAG)
			end
			local function again()
				task.defer(function()
					if self.Vehicle == vehicle then
						-- a fitting arriving later re-describes the same model
						self:ClearPhone()
						self:UsePhone(findPhoneModel(vehicle))
					end
				end)
			end
			table.insert(
				self.VehicleConnections,
				vehicle.DescendantAdded:Connect(function(descendant)
					if relevant(descendant) then
						again()
					end
				end)
			)
			table.insert(
				self.VehicleConnections,
				vehicle.DescendantRemoving:Connect(function(descendant)
					const phone = self.Phone
					if phone and (descendant == phone.Model or descendant:IsAncestorOf(phone.Model) or relevant(descendant)) then
						again()
					end
				end)
			)
		end
	end
	self:UsePhone(if vehicle then findPhoneModel(vehicle) else nil)
end

-- Mount --------------------------------------------------------------------------------------------------------------

function BossController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const scale = Theme.ScaleOf(camera.ViewportSize) -- global UI scale (as HudController)
	if math.abs(scale - self.Scale()) > 0.01 then
		self.Scale(scale)
	end
end

function BossController:WatchViewport()
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		const camera = workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:Rescale(camera)
			end)
		end
		self:Rescale(camera)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

function BossController:Mount(playerGui: Instance)
	const round = self.Dependencies.RoundController
	const _, gui = Vide.root(function()
		-- the phone follows the current vehicle
		Vide.effect(function()
			round.Vehicle()
			Vide.untrack(function()
				self:Track()
				return nil
			end)
		end)

		return Vide.create("ScreenGui")({
			Name = "BossCall",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 2,

			CallSubtitle({
				Visible = self.Showing,
				Speaker = self.Speaker,
				Text = self.Text,
				Phone = round.Vehicle,
				Scale = self.Scale,
			}),
		})
	end)
	self.Gui = gui
	gui.Parent = playerGui

	CollectionService:GetInstanceAddedSignal(VEHICLE_TAG):Connect(function()
		self:Track()
	end)
	CollectionService:GetInstanceRemovedSignal(VEHICLE_TAG):Connect(function(vehicle)
		if vehicle == self.Vehicle then
			self:Track()
		end
	end)
	self:Track()
end

BossController:OnInit(function(self)
	self:Setup()

	const call = self.Libs.Net.Call
	call:onAdded(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)
	call:onChanged(function(id, record)
		if id == RECORD_ID then
			self:Apply(record)
		end
	end)
	call:onRemoved(function(id)
		if id == RECORD_ID then
			self:Apply({ Call = NONE, State = "Idle", StartedAt = 0 })
		end
	end)
end)

-- Night 1 opens straight on the Call phase: its calls are voiced from the start so the voices are loaded by the
-- time the phone rings (the rest waits for PREPARE_AFTER)
function BossController:PrepareFirstNight()
	for _, row in Content.BossCalls.List do
		const kind = row.Trigger.Kind
		if (kind == "NightCall" or kind == "NightCoffee") and row.Trigger.Night == 1 then
			self:PrepareCall(row.Key, 1)
		end
	end
end

BossController:OnStart(function(self)
	self:WatchViewport()
	self:PrepareFirstNight()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

BossController:OnTick(function(self)
	if os.clock() - self.StartedClock >= PREPARE_AFTER then
		self:PrepareUpcoming()
	end
	if self.State() ~= "Idle" or self.LineIndex ~= 0 or self.LampOn then
		self:Refresh()
	end
end, TICK_RATE)

return BossController
