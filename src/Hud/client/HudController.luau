--!strict
--[[
	HudController (TASK-039, TASK-065; FEAT-032, FEAT-014, FEAT-025, FEAT-026; DEC-015, DEC-048, DEC-051, DEC-053,
	DEC-081, DEC-167)

	Mounts the status HUD in the OnStart, per architecture.md §3 (priority 500).

	Wave 1 (Interface/Components/HudScreen):
	  - clock and "Day N" / "Night k" from RoundController (ClockText, Day, Night, IsNight);
	  - party money from EconomyController.Cash;
	  - toasts from the `Notice` packet (network.md §4.2), text from Content.Notices with {value}/{item}/{upgrade}/
	    {class}/{achievement} filled in; same text already queued is dropped (a spammed "Hands full" shows once);
	  - end-of-shift summary from the `ShiftReport` packet (network.md §4.4), hidden by itself after 15 s on day /
	    20 s at night, or as soon as the next shift starts.

	Wave 2 (TASK-065; architecture.md §19.3, §19.7, §19.16; network.md §13.1; ui-text.md §12, §14):
	  - sanity meter (HudSanity) under the clock: VitalController Sanity/Max/Band, only with Max > 0 and own state
	    Active; portrait = class icon of the AST-071 sheet on the species fur colour until AST-086 (letter fallback);
	  - banners (HudBanner): night start "Night k" (repeated night: "Same night. Same rules."), 6:00 AM "You made
	    it!", from the Shift set on a fresh phase change only (a late joiner gets no old banner);
	  - 10 s window (HudWipe) from Shift.WipeEndsAt (server time; WipeFrozen holds the number, wave 4);
	  - spectate (HudSpectate) while own state is Down / Spectator: card for CARD_TIME s, "Watching: {name}" read from
	    the camera subject (CameraController owns the view and the switch bind) and the switch hint of the device;
	  - toasts from `LifeEvent` with the crewmate's name (Down, Spectating, Revived, WipeCleared);
	  - end of run screen (HudRunEnd) from the `RunReport` packet, 15 s.
	The Shift set is read here only for WipeEndsAt/WipeFrozen and the banner timing (network.md §3.1 lists the HUD as
	a reader); Day/Night/Phase/clock still come from RoundController.

	Order card (user request after Play): HudOrder on the top-left column, under the Roblox menu / chat buttons (money and
	day are top right, 2026-10-12; the Hud ScreenGui has DeviceSafeInsets, the player list is hidden), with the
	order of the customer CustomerController picks (prompt target, else Q1 in Waiting); hidden while Down/Spectator.

	Cinematic and reveal (user request 2026-10-11): the whole Hud ScreenGui is off while Interface/Cinematic is on
	(StageController: intro / finale / credits), and during a first run the money pill and the clock + day pills pop in
	as the tutorial reaches them (TutorialController ShowCash / ShowClock).

	Status only: no button, no input binding (FEAT-032: nothing clickable for an Active player). No reputation, no boss
	chances (Shift.Chances is never read, DEC-053), no XP. The client never writes money, sanity or life state: the
	numbers come from the server's sets and packets. Texts from ui-text.md (Provisional, TASK-082).
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewLooks = require(ReplicatedStorage.shared.Crew.CrewLooks)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local HudOrder = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudOrder)
local HudBanner = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudBanner)
local HudRunEnd = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudRunEnd)
local HudSanity = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSanity)
local HudScreen = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudScreen)
local HudSpectate = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSpectate)
local HudSummary = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSummary)
local HudWipe = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudWipe)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Toast = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast)

-- FEAT-014: summary on screen as long as the Summary phase (Content.Shift: 8 s day, 10 s night; halved by Q-200)
const DAY_SUMMARY = Content.Shift.ByKey.Summary.Duration
const NIGHT_SUMMARY = if Content.Shift.ByKey.Summary.Night ~= nil
	then Content.Shift.ByKey.Summary.Night.Duration
	else DAY_SUMMARY
-- Phases that start a new shift: an old summary (or run end screen) still on screen goes away
const NEW_SHIFT: { [string]: boolean } = { Intro = true, Prep = true, Open = true, Call = true, Night = true }
-- network.md §4.2: toast on screen 3-6 s
const TOAST_DURATION = 4
-- Notices waiting beyond this are dropped (the oldest waiting first); 3 are on screen at a time
const MAX_TOASTS = 6
const MAX_VISIBLE = 3
-- UI scale: global rule (Theme.ScaleOf: 1 on a phone, 1.4 at 1080p)

-- Wave 2 layout (px at scale 1): sanity meter and spectate card sit under the clock pill (TOP 6 + 38 + gap 6)
const UNDER_CLOCK = 50
-- Order card: top-left column UNDER the Roblox menu / chat buttons (the HUD gui has DeviceSafeInsets, so the Roblox top
-- bar overlaps its top; money and day moved to the right, 2026-10-12). Real px of the top bar from GuiService.
const ORDER_GAP = 8
const ORDER_LEFT = 10
-- Run end screen on screen (architecture.md §19.16)
const RUN_END_TIME = 15
-- Banner on screen; a phase change older than BANNER_FRESH s (late joiner, reconnect) gets no banner
const BANNER_TIME = 3.5
const BANNER_FRESH = 5
-- Spectate card ("You fainted!", "You're out for now.") on screen after the state change (Provisional)
const CARD_TIME = 10
-- Phases where the 10 s window can run (architecture.md §19.4: LoseNight accepted in Call, Prep, Night)
const WIPE_PHASES: { [string]: boolean } = { Call = true, Prep = true, Night = true }
const SHIFT_RECORD = 1
const TICK_RATE = 10
const CREWMATE = "A crewmate" -- name fallback when the player already left
-- ui-text.md §12.3; keys of the interact bind (PromptController: E / ButtonX / touch button)
const SWITCH_HINT: { [string]: string } = {
	Touch = "Tap to switch",
	KeyboardMouse = "Press E to switch",
	Gamepad = "Press X to switch",
}
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

-- Notice keys shown as an alert (Mustard; never red, style guide §7.4) and as good news (Green). The rest: Info.
const ALERT: { [string]: boolean } = {
	hands_full = true,
	package_limit = true,
	not_enough_cash = true,
	not_enough_gems = true,
	class_locked = true,
}
-- Refusal notices (an action the server turned down): `error` instead of `toast` (user request 2026-10-10)
const REFUSAL: { [string]: boolean } = {
	hands_full = true,
	package_limit = true,
	not_enough_cash = true,
	not_enough_gems = true,
	class_locked = true,
	grill_full = true,
	rail_full = true,
	board_full = true,
	out_of_stock = true,
	topping_max = true,
	topping_repeat = true,
	stock_full = true,
	shelf_locked = true,
	bench_busy = true,
	upgrade_maxed = true,
	shop_closed = true,
	coffee_cooldown = true,
	coffee_full = true,
	coffee_night_only = true,
	coffee_has_one = true,
	shutter_closed = true,
}
const REFUSAL_SOUND = "error"
const TOAST_SOUND = "toast"
-- Notices with their own sound instead of the toast one (live packet only: nothing plays for a late joiner)
const NOTICE_SOUND: { [string]: string } = {
	thief_caught = "thief_caught",
	trailer_cash = "coin", -- Walt's till money for the trailer
}
const SUMMARY_SOUND = "summary"
const GOOD: { [string]: boolean } = {
	upgrade_bought = true,
	ingredient_unlocked = true,
	class_bought = true,
	trailer_cash = true,
}

-- Fields of the ShiftReport packet this controller reads (network.md §4.4)
export type Report = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Arrived: number,
	Completed: number,
	Drawer: number,
	Stolen: number,
	Grade: string,
	Bonus: number,
	Deposited: number,
	Gems: number,
	AfkLocked: boolean,
	LastChanceUsed: boolean,
}

-- Fields of the Shift record this controller reads (network.md §3.1)
export type ShiftRecord = {
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	PhaseStartedAt: number,
	WipeEndsAt: number,
	WipeFrozen: boolean,
}

-- RunReport packet (network.md §13.1)
export type RunReport = {
	Result: "Success" | "Failed",
	Day: number,
	Night: number,
	Gems: number,
}

-- LifeEvent packet (network.md §13.1)
export type LifeEvent = {
	UserId: number,
	Event: "Down" | "Revived" | "Spectating" | "Hit" | "Wipe" | "WipeCleared",
}

const HudController = Modux.Controller("HudController", {
	Require = {
		"RoundController",
		"EconomyController",
		"ProfileController",
		"VitalController",
		"InputController",
		"CustomerController",
		"AudioController",
		"TutorialController",
		"PlaceController",
	},
	Priority = 500,
})

local function cancel(thread: thread?)
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
end

function HudController:Setup()
	self.Toasts = Vide.source({} :: { ToastStack.Entry }) :: Vide.Source<{ ToastStack.Entry }>
	-- false = no summary on screen (a Source of an optional type is ambiguous to call under the new solver)
	self.Report = Vide.source(false :: HudSummary.Shown) :: Vide.Source<HudSummary.Shown>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.ReportThread = nil :: thread?
	self.Gui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?

	-- wave 2. WipeLeft: whole seconds of the 10 s window, -1 = none. WipePhase: the current phase can hold a
	-- window. BannerKey: "night:attempt" of the last night-start banner (one per try). ShiftPhase: last Shift.Phase
	-- seen. Watching: display name of the watched crewmate, "" = none.
	self.WipeLeft = Vide.source(-1) :: Vide.Source<number>
	self.WipeEndsAt = 0 :: number
	self.WipeFrozen = false :: boolean
	self.WipePhase = false :: boolean
	self.Banner = Vide.source(false :: HudBanner.Shown) :: Vide.Source<HudBanner.Shown>
	self.BannerThread = nil :: thread?
	self.BannerKey = "" :: string
	self.ShiftPhase = "" :: string
	self.Card = Vide.source(false) :: Vide.Source<boolean>
	self.CardThread = nil :: thread?
	self.Watching = Vide.source("") :: Vide.Source<string>
	self.RunEnd = Vide.source(false :: HudRunEnd.Shown) :: Vide.Source<HudRunEnd.Shown>
	self.RunEndThread = nil :: thread?
end

-- Name of the table row a Notice.Value points at (IndexOf = list position), "?" when out of range
local function rowName(from: string, index: number): string
	local row: { Name: string }? = nil
	if from == "Ingredients" then
		row = Content.Ingredients.List[index]
	elseif from == "Upgrades" then
		row = Content.Upgrades.List[index]
	elseif from == "Classes" then
		row = Content.Classes.List[index]
	elseif from == "Achievements" then
		row = Content.Achievements.List[index]
	elseif from == "Items" then
		row = Content.Items.List[index]
	end
	return if row then row.Name else "?"
end

-- Content.Notices text with its placeholder filled; nil for an unknown key
function HudController:NoticeText(kind: string, value: number): string?
	const notice = Content.Notices.ByKey[kind]
	if notice == nil then
		warn(`[HudController] unknown Notice kind "{kind}"`)
		return nil
	end
	const name = rowName(notice.ValueFrom, value)
	-- "%" is special in a gsub replacement string
	const safeName = string.gsub(name, "%%", "%%%%")
	local text = notice.Text
	text = string.gsub(text, "{value}", tostring(value))
	text = string.gsub(text, "{item}", safeName)
	text = string.gsub(text, "{upgrade}", safeName)
	text = string.gsub(text, "{class}", safeName)
	text = string.gsub(text, "{achievement}", safeName)
	return text
end

function HudController:PushToast(kind: string, value: number)
	const text = self:NoticeText(kind, value)
	if text == nil then
		return
	end
	const toastKind: Toast.Kind = if ALERT[kind] then "Alert" elseif GOOD[kind] then "Good" else "Info"
	if self:PushText(text, toastKind) then
		self.Dependencies.AudioController:Play(
			NOTICE_SOUND[kind] or (if REFUSAL[kind] then REFUSAL_SOUND else TOAST_SOUND)
		)
	end
end

-- One toast line; the same text already queued is dropped (false)
function HudController:PushText(text: string, toastKind: Toast.Kind): boolean
	const list = table.clone(self.Toasts())
	for _, entry in list do
		if entry.Text == text then
			return false
		end
	end
	if #list >= MAX_TOASTS then
		-- keep what is on screen; drop the oldest one still waiting
		table.remove(list, MAX_VISIBLE + 1)
	end
	table.insert(list, { Text = text, Kind = toastKind, Duration = TOAST_DURATION })
	self.Toasts(list)
	return true
end

function HudController:ToastDone(entry: ToastStack.Entry)
	const list = self.Toasts()
	const index = table.find(list, entry)
	if index then
		const copy = table.clone(list)
		table.remove(copy, index)
		self.Toasts(copy)
	end
end

function HudController:CancelReport()
	cancel(self.ReportThread)
	self.ReportThread = nil
end

function HudController:HideReport()
	self:CancelReport()
	if self.Report() then
		self.Report(false)
	end
end

function HudController:ShowReport(report: Report)
	const grade: HudSummary.Grade = if report.Grade == "A"
		then "A"
		elseif report.Grade == "B" then "B"
		elseif report.Grade == "D" then "D"
		else "C"
	const profile = self.Dependencies.ProfileController
	self:CancelReport()
	self.Dependencies.AudioController:Play(SUMMARY_SOUND)
	self.Report({
		Title = if report.IsNight then `Night {report.Night}` else `Day {report.Day}`,
		Arrived = report.Arrived,
		Completed = report.Completed,
		Drawer = report.Drawer,
		Stolen = report.Stolen,
		Grade = grade,
		Bonus = report.Bonus,
		Deposited = report.Deposited,
		Gems = report.Gems,
		-- gems are credited per event before the report (DEC-104), so the profile already holds the total
		GemsTotal = if profile.Ready() then profile.Gems() else nil,
		AfkLocked = report.AfkLocked,
		LastChanceUsed = report.LastChanceUsed,
	})
	self.ReportThread = task.delay(if report.IsNight then NIGHT_SUMMARY else DAY_SUMMARY, function()
		self.ReportThread = nil
		self.Report(false)
	end)
end

-- Wave 2 ------------------------------------------------------------------------------------------------------------

-- "Day 3" / "Night 2" (ui-text.md §5); "Night" alone while the record carries no number
function HudController:ShiftText(): string
	const round = self.Dependencies.RoundController
	if round.IsNight() then
		const night = round.Night()
		return if night > 0 then `Night {night}` else "Night"
	end
	return `Day {round.Day()}`
end

-- Display name of a run member; CREWMATE when the player already left
local function nameOf(userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else CREWMATE
end

-- ui-text.md §12.3: toasts by LifeEvent, built on the client. Own events show on the spectate card instead.
function HudController:OnLifeEvent(event: LifeEvent)
	if event.Event == "WipeCleared" then
		self:PushText("Someone's back! Keep going!", "Good")
		return
	end
	if event.UserId == Players.LocalPlayer.UserId then
		return
	end
	if event.Event == "Down" then
		self:PushText(`{nameOf(event.UserId)} fainted!`, "Alert")
	elseif event.Event == "Spectating" then
		self:PushText(`{nameOf(event.UserId)} is resting for now.`, "Info")
	elseif event.Event == "Revived" then
		self:PushText(`{nameOf(event.UserId)} is back on shift!`, "Good")
	end
	-- Hit: comic text in the world (Traffic, wave 3); Wipe: the counter shows it
end

function HudController:ShowBanner(banner: HudBanner.Banner)
	cancel(self.BannerThread)
	self.Banner(banner)
	self.BannerThread = task.delay(BANNER_TIME, function()
		self.BannerThread = nil
		self.Banner(false)
	end)
end

-- Whole seconds left in the 10 s window from Shift.WipeEndsAt (server time); frozen keeps the number (DEC-118)
function HudController:RefreshWipe()
	const shown = Vide.untrack(self.WipeLeft)
	local left = -1
	if self.WipeEndsAt > 0 and self.WipePhase then
		if self.WipeFrozen and shown >= 0 then
			left = shown
		else
			const total = Content.Revive.WipeWindow
			left = math.clamp(math.ceil(self.WipeEndsAt - workspace:GetServerTimeNow()), 0, total)
		end
	end
	if left ~= shown then
		self.WipeLeft(left)
	end
end

-- Shift record: wipe window fields and banners on a fresh phase change (ui-text.md §12.2)
function HudController:ApplyShift(record: ShiftRecord)
	self.WipeEndsAt = record.WipeEndsAt
	self.WipeFrozen = record.WipeFrozen
	self.WipePhase = WIPE_PHASES[record.Phase] == true
	self:RefreshWipe()

	const changed = record.Phase ~= self.ShiftPhase
	self.ShiftPhase = record.Phase
	if not changed or workspace:GetServerTimeNow() - record.PhaseStartedAt > BANNER_FRESH then
		return
	end
	if record.IsNight and record.Night > 0 and (record.Phase == "Call" or record.Phase == "Prep") then
		-- the night opens on Call (or Prep without a call): one banner per try of the night
		const key = `{record.Night}:{record.Attempt}`
		if key ~= self.BannerKey then
			self.BannerKey = key
			self:ShowBanner({
				Title = `Night {record.Night}`,
				Line = if record.Attempt > 0 then "Same night. Same rules." else "Stay open till 6:00 AM.",
			})
		end
	elseif record.Phase == "NightEnd" then
		self:ShowBanner({ Title = "6:00 AM", Line = "You made it!" })
	end
end

-- Spectate mode from the own life state (Down: fainted tonight; Spectator: out until the next night)
function HudController:SpectateMode(): HudSpectate.Mode
	const state = self.Dependencies.VitalController.LocalState()
	return if state == "Down" then "Down" elseif state == "Spectator" then "Out" else "None"
end

function HudController:ShowCard()
	cancel(self.CardThread)
	self.Card(true)
	self.CardThread = task.delay(CARD_TIME, function()
		self.CardThread = nil
		self.Card(false)
	end)
end

function HudController:HideCard()
	cancel(self.CardThread)
	self.CardThread = nil
	if Vide.untrack(self.Card) then
		self.Card(false)
	end
end

-- Who the camera follows: the player of the camera subject when it is a crewmate (CameraController:Spectate,
-- TASK-064); "" for the fixed trailer view (SPEC-P / SPEC-M) or the own character. Provisional until the
-- CameraController exposes its target as a source.
function HudController:RefreshWatching()
	local name = ""
	const state = Vide.untrack(self.Dependencies.VitalController.LocalState)
	if state == "Down" or state == "Spectator" then
		const camera = workspace.CurrentCamera
		const subject = if camera then camera.CameraSubject else nil
		local model: Instance? = nil
		if subject and subject:IsA("Humanoid") then
			model = subject.Parent
		elseif subject and subject:IsA("BasePart") then
			model = subject:FindFirstAncestorOfClass("Model")
		end
		const player = if model and model:IsA("Model") then Players:GetPlayerFromCharacter(model) else nil
		if player and player ~= Players.LocalPlayer then
			name = player.DisplayName
		end
	end
	if name ~= Vide.untrack(self.Watching) then
		self.Watching(name)
	end
end

-- Switch hint of the current device; none when there is nobody to switch to
function HudController:SwitchHint(): string
	if self.Watching() == "" then
		return ""
	end
	return SWITCH_HINT[self.Dependencies.InputController.Device()] or ""
end

-- Own species: Vitals.Class of the own record; Profile.Selected before the first record
function HudController:Species(): string?
	const member = self.Dependencies.VitalController.Members()[Players.LocalPlayer.UserId]
	const classKey = if member then member.Class else self.Dependencies.ProfileController.Selected()
	const class = Content.Classes.ByKey[classKey]
	return if class then class.Species else nil
end

function HudController:ShowRunEnd(report: RunReport)
	const quote: { string } = {}
	if report.Result == "Failed" then
		const call = Content.BossCalls.ByKey.call_run_over
		if call then
			for _, line in call.Lines do
				table.insert(quote, line.Text)
			end
		end
	end
	self:HideReport()
	cancel(self.RunEndThread)
	self.RunEnd({
		Result = report.Result,
		Day = report.Day,
		Night = report.Night,
		Gems = report.Gems,
		Quote = quote,
	})
	self.RunEndThread = task.delay(RUN_END_TIME, function()
		self.RunEndThread = nil
		self.RunEnd(false)
	end)
end

function HudController:HideRunEnd()
	cancel(self.RunEndThread)
	self.RunEndThread = nil
	if Vide.untrack(self.RunEnd) then
		self.RunEnd(false)
	end
end

-- Full-screen frame scaled like HudScreen (UIScale also scales the frame, so it is shrunk by the same factor)
function HudController:Layer(name: string, zIndex: number, children: { Instance }): Frame
	const scale = function(): number
		return self.Scale()
	end
	return Vide.create("Frame")({
		Name = name,
		ZIndex = zIndex,
		Size = function()
			const s = scale()
			return UDim2.fromScale(1 / s, 1 / s)
		end,
		BackgroundTransparency = 1,
		createRaw("UIScale")({ Scale = scale }),
		children,
	})
end

function HudController:SanityMeter(): Frame
	const vital = self.Dependencies.VitalController
	const speciesRow = function()
		const species = self:Species()
		return if species then Content.Species.ByKey[species] else nil
	end
	return HudSanity({
		Value = vital.Sanity,
		Max = vital.Max,
		Band = vital.Band,
		Shown = function()
			return vital.Max() > 0 and vital.LocalState() == "Active"
		end,
		Icon = function()
			const row = speciesRow()
			return if row and row.Class then `Class/{row.Class}` else ""
		end,
		Letter = function()
			const row = speciesRow()
			return if row then string.upper(string.sub(row.Name, 1, 1)) else "?"
		end,
		Fur = function()
			const species = self:Species()
			const look = if species then CrewLooks.Species[species] else nil
			return if look then look.Fur else Theme.Color.Cream
		end,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, UNDER_CLOCK),
		-- Night 1 coffee lesson + coffee gain feedback (VitalController, server cue SanityCue)
		Emphasis = vital.CoffeeHint,
		Gain = vital.CoffeeGain,
	})
end

-- Height in real px of the Roblox top bar (menu / chat buttons), which the HUD gui does not inset for.
function HudController:TopBar(): number
	const inset = GuiService:GetGuiInset()
	return inset.Y
end

function HudController:OrderCard(): Frame
	const customer = self.Dependencies.CustomerController
	return HudOrder({
		Shown = function()
			return customer:CardShown() and self:SpectateMode() == "None"
		end,
		Toppings = function()
			return customer:CardToppings()
		end,
		-- pair (FEAT-038, TASK-148): 2nd row
		Toppings2 = function()
			return customer:CardToppings2()
		end,
		Empty = function()
			return customer:CardEmpty()
		end,
		Patience = function()
			return customer:CardPatience()
		end,
		WarnAt = Content.Moods.Rules.AnnoyedAt,
		Position = function()
			return UDim2.fromOffset(ORDER_LEFT, math.ceil(self:TopBar() / self.Scale()) + ORDER_GAP)
		end,
	})
end

-- Wave 1 -----------------------------------------------------------------------------------------------------------

function HudController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const scale = Theme.ScaleOf(camera.ViewportSize)
	if math.abs(scale - self.Scale()) > 0.01 then
		self.Scale(scale)
	end
end

function HudController:WatchViewport()
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

function HudController:Mount(playerGui: Instance)
	const round = self.Dependencies.RoundController
	const economy = self.Dependencies.EconomyController
	const tutorial = self.Dependencies.TutorialController

	const unmount, gui = Vide.root(function()
		-- A new shift clears a summary / run end screen that is still up (e.g. dev "skip" shortened the phase)
		Vide.effect(function()
			if NEW_SHIFT[round.Phase()] then
				Vide.untrack(function()
					self:HideReport()
					self:HideRunEnd()
					return nil
				end)
			end
		end)

		-- Spectate card on each change to Down / Spectator
		Vide.effect(function()
			const mode = self:SpectateMode()
			Vide.untrack(function()
				if mode == "None" then
					self:HideCard()
				else
					self:ShowCard()
				end
				return nil
			end)
		end)

		return Vide.create("ScreenGui")({
			Name = "Hud",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 1,
			-- no HUD while a cinematic owns the screen (intro / finale / credits; Interface/Cinematic)
			Enabled = function()
				return not Cinematic.Active()
			end,

			-- Wave 2 night layer, under the wave-1 HUD so toasts stay readable on a narrow phone
			self:Layer("Night", 0, {
				self:SanityMeter(),
				HudBanner({ Banner = self.Banner }),
				HudSpectate({
					Mode = function()
						return self:SpectateMode()
					end,
					Card = self.Card,
					Target = self.Watching,
					Hint = function()
						return self:SwitchHint()
					end,
					CardTop = UNDER_CLOCK,
				}),
				HudWipe({ Seconds = self.WipeLeft, Total = Content.Revive.WipeWindow }),
			}),

			-- Order card (top-left column), under the wave-1 pills
			self:Layer("Order", 1, {
				self:OrderCard(),
			}),

			HudScreen({
				Clock = round.ClockText,
				Shift = function()
					return self:ShiftText()
				end,
				IsNight = round.IsNight,
				Cash = economy.Cash,
				Toasts = self.Toasts,
				OnToastDone = function(entry)
					self:ToastDone(entry)
				end,
				Report = self.Report,
				Scale = self.Scale,
				-- progressive reveal of the first-run tutorial (TutorialController)
				ShowCash = function()
					return tutorial:ShowCash()
				end,
				ShowClock = function()
					return tutorial:ShowClock()
				end,
			}),

			-- End of run covers everything (15 s)
			self:Layer("RunEnd", 3, {
				HudRunEnd({ Report = self.RunEnd }),
			}),
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
end

HudController:OnInit(function(self)
	self:Setup()

	const net = self.Libs.Net

	net.Notice:onClient(function(notice)
		self:PushToast(notice.Kind, notice.Value)
	end)

	net.ShiftReport:onClient(function(report)
		self:ShowReport(report)
	end)

	-- wave 2
	net.LifeEvent:onClient(function(event)
		self:OnLifeEvent(event :: LifeEvent)
	end)

	net.RunReport:onClient(function(report)
		self:ShowRunEnd(report :: RunReport)
	end)

	net.Shift:onAdded(function(id, record)
		if id == SHIFT_RECORD then
			self:ApplyShift(record :: ShiftRecord)
		end
	end)

	net.Shift:onChanged(function(id, record)
		if id == SHIFT_RECORD then
			self:ApplyShift(record :: ShiftRecord)
		end
	end)

	net.Shift:onRemoved(function(id)
		if id == SHIFT_RECORD then
			self.WipeEndsAt = 0
			self:RefreshWipe()
		end
	end)
end)

HudController:OnStart(function(self)
	-- the game HUD only lives in Game servers; the lobby has its own HUD (LobbyController, 2026-10-11)
	const place = self.Dependencies.PlaceController
	if place:Is("Lobby") then
		return
	end
	-- The money / day / toast column lives top right: the Roblox player list would sit under it
	const ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if not ok then
		warn(`[HudController] could not hide the player list: {err}`)
	end
	self:WatchViewport()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

HudController:OnTick(function(self)
	self:RefreshWipe()
	self:RefreshWatching()
end, TICK_RATE)

return HudController
