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
	  - sanity meter (HudSanity) TOP LEFT under the Roblox menu / chat bar (owner request 2026-10-12): VitalController
	    Sanity/Max/Band, only with Max > 0 and own state Active; compact on a phone (34 px portrait, 110 x 10 bar),
	    bigger on desktop; portrait = class icon of the AST-071 sheet on the species fur colour (letter fallback);
	  - banners (HudBanner): night start "Night k" (repeated night: "Same night. Same rules."), 6:00 AM "You made
	    it!", from the Shift set on a fresh phase change only (a late joiner gets no old banner); Resume phase
	    (DEC-080): "Resuming Day n" / "Resuming Night k" for the rest of the phase, late joiner included;
	  - 10 s window (HudWipe) from Shift.WipeEndsAt (server time; WipeFrozen holds the number, wave 4);
	  - spectate (HudSpectate) while own state is Down / Spectator: card for CARD_TIME s, "Watching: {name}" read from
	    the camera subject (CameraController owns the view and the switch bind) and the switch hint of the device;
	  - toasts from `LifeEvent` with the crewmate's name (Down, Spectating, Revived, WipeCleared);
	  - end of run screen (HudRunEnd) from the `RunReport` packet, 15 s.
	The Shift set is read here only for WipeEndsAt/WipeFrozen and the banner timing (network.md §3.1 lists the HUD as
	a reader); Day/Night/Phase/clock still come from RoundController.

	Order card (user request after Play): HudOrder on the top-left column, under the Roblox menu / chat buttons and under
	the sanity meter when that is on screen (money and day are top right, 2026-10-12; the Hud ScreenGui has
	DeviceSafeInsets, the player list is hidden), with the order of the customer CustomerController picks (prompt target,
	else Q1 in Waiting); hidden while Down/Spectator.

	Toasts (owner request 2026-10-12): bottom centre above the hotbar (HudScreen), never in the top right.

	Cinematic and progressive reveal (user request 2026-10-11, owner request 2026-10-12): the whole Hud ScreenGui is off
	while Interface/Cinematic is on (StageController: intro / finale / credits). During a first run the HUD starts with
	only the essentials and releases the rest as the tutorial moves (Content.HudReveal: element -> trigger; the client
	reads TutorialController StepKey / Finished and the shift; EvaluateReveal latches each element for the session, the
	server is not involved). A player who skips the tutorial, a run past Day 1 and every night shift see everything. Dev:
	`/dev hud reveal all|reset|status` (DevClient command "hud_reveal").

	Status only: no input binding and two buttons top right, the settings gear (TASK-279, SettingsController) and the
	shop cart (TASK-290, ShopController), with their key labels, plus the shop's quick note under them; FEAT-032
	otherwise holds, nothing else clickable for an Active player. No reputation, no boss
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
local Steps = require(StarterPlayer.StarterPlayerScripts.client.Tutorial.TutorialController.Steps)
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

-- FEAT-014: the summary card stays SUMMARY_SHOWN s on screen, day and night (owner request 2026-10-16: the frame must be
-- short; the Summary phase itself keeps its Content.Shift length, 8 s day / 10 s night, as the break between shifts)
const SUMMARY_SHOWN = 3
-- Phases that start a new shift: an old summary (or run end screen) still on screen goes away
const NEW_SHIFT: { [string]: boolean } = { Intro = true, Prep = true, Open = true, Call = true, Night = true }
-- network.md §4.2: toast on screen 3-6 s
const TOAST_DURATION = 4
-- Notices waiting beyond this are dropped (the oldest waiting first); 3 are on screen at a time
const MAX_TOASTS = 6
const MAX_VISIBLE = 3
-- UI scale: global rule (Theme.ScaleOf: 1 on a phone, 1.4 at 1080p)

-- Wave 2 layout (px at scale 1): the spectate card sits under the clock pill (TOP 6 + 38 + gap 6)
const UNDER_CLOCK = 50
-- Order card: top-left column UNDER the Roblox menu / chat buttons (the HUD gui has DeviceSafeInsets, so the Roblox top
-- bar overlaps its top; money and day moved to the right, 2026-10-12). Real px of the top bar from GuiService.
const ORDER_GAP = 8
const ORDER_LEFT = 8
-- Sanity meter: left margin as the order card; height in UI px with the Ink outline (HudSanity: portrait 34 + 2 x 2 on a
-- phone, 44 + 2 x 3 on desktop)
const SANITY_LEFT = 8
const SANITY_ROW_COMPACT = 38
const SANITY_ROW_LARGE = 50
const DEV_PREFIX = "[HudReveal]"
-- Real px the Roblox top-left bar (menu, chat) takes on a phone; GetGuiInset reports 0 there (user report 2026-10-12)
const TOPBAR_REAL = 60
-- Same threshold as HudScreen (px at UI scale 1): under it money / day stack in a column (6 + 38 + 6 + 38)
const NARROW_WIDTH = 560
const UNDER_PILL_COLUMN = 88
-- Run end screen on screen (architecture.md §19.16)
const RUN_END_TIME = 15
-- Banner on screen; a phase change older than BANNER_FRESH s (late joiner, reconnect) gets no banner
const BANNER_TIME = 3.5
const BANNER_FRESH = 5
-- Resume phase (DEC-080, architecture.md §5.5 step 5): the banner stays up for the rest of the phase, also for a crewmate
-- who arrives mid-phase (the restored server is the one they teleport into); never shorter than BANNER_TIME (Provisional)
const RESUME_PHASE = "Resume"
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
}
const SUMMARY_SOUND = "summary"
const GOOD: { [string]: boolean } = {
	upgrade_bought = true,
	ingredient_unlocked = true,
	class_bought = true,
}

-- Fields of the ShiftReport packet this controller reads (network.md §4.4)
export type Report = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Arrived: number,
	Completed: number,
	Drawer: number,
	Tips: number,
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
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
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
		"SettingsController",
		"ShopController",
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
	self.Viewport = Vide.source(Vector2.new(1000, 700)) :: Vide.Source<Vector2>
	-- progressive reveal: Content.HudReveal rows already on screen (latched for the session), the ones that opened with
	-- a presentation pulse, and the dev switches (all = everything open, gate = apply the reveal outside a first run,
	-- epoch = a reset happened)
	self.Open = Vide.source({} :: { [string]: boolean }) :: Vide.Source<{ [string]: boolean }>
	self.Intros = Vide.source({} :: { [string]: boolean }) :: Vide.Source<{ [string]: boolean }>
	self.DevAll = Vide.source(false) :: Vide.Source<boolean>
	self.DevGate = Vide.source(false) :: Vide.Source<boolean>
	self.Epoch = Vide.source(0) :: Vide.Source<number>
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
	-- not released yet (first run, before the first customer): nothing to show, and no sound
	if not self:IsOpenNow("toasts") then
		return false
	end
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
		-- report.Drawer = the day take; the tips are the jar part of it (sales go straight to the shared money)
		Sales = math.max(0, report.Drawer - report.Tips),
		Tips = report.Tips,
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
	self.ReportThread = task.delay(SUMMARY_SHOWN, function()
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

function HudController:ShowBanner(banner: HudBanner.Banner, duration: number?)
	cancel(self.BannerThread)
	self.Banner(banner)
	self.BannerThread = task.delay(duration or BANNER_TIME, function()
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
	if changed and record.Phase == RESUME_PHASE then
		-- restored shift (DEC-080): "Resuming Day n" / "Resuming Night k" until the shift starts again
		const left = record.PhaseStartedAt + record.PhaseDuration - workspace:GetServerTimeNow()
		self:ShowBanner({
			Title = if record.IsNight and record.Night > 0
				then `Resuming Night {record.Night}`
				else `Resuming Day {record.Day}`,
			Line = "Waiting for your crew...",
		}, math.max(left, BANNER_TIME))
		return
	end
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
		-- class animal of the player (Content.Species Class icon, AST-071 sheet)
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
		Compact = function()
			return self:Compact()
		end,
		-- top left, under the Roblox menu / chat bar (the order card goes under it)
		Position = function()
			return UDim2.fromOffset(SANITY_LEFT, self:TopLeftY())
		end,
		-- progressive reveal (night 1): scales in with a presentation pulse
		Revealed = function()
			return self:IsOpen("sanity")
		end,
		Intro = function()
			return self.Intros().sanity == true
		end,
		-- Night 1 coffee lesson + coffee gain feedback (VitalController, server cue SanityCue)
		Emphasis = vital.CoffeeHint,
		Gain = vital.CoffeeGain,
	})
end

-- Height in real px of the Roblox top bar (menu / chat buttons), which the HUD gui does not inset for.
function HudController:TopBar(): number
	const inset = GuiService:GetGuiInset()
	return math.max(inset.Y, TOPBAR_REAL)
end

-- Top of the top-left column (UI px): just under the Roblox menu / chat bar (it covers about 0-60 px tall, 0-270 px
-- wide; the GUI inset reads 0 on a phone, so TOPBAR_REAL is the floor), clear of the joystick (bottom left).
function HudController:TopLeftY(): number
	return math.ceil(self:TopBar() / self.Scale()) + ORDER_GAP
end

-- Phone-sized layout of the sanity meter: the touch device (compact portrait and bar); keyboard / gamepad get the bigger one
function HudController:Compact(): boolean
	return self.Dependencies.InputController.Device() == "Touch"
end

-- The sanity meter is on screen (alive, a night with sanity, released by the reveal)
function HudController:SanityOn(): boolean
	const vital = self.Dependencies.VitalController
	return vital.Max() > 0 and vital.LocalState() == "Active" and self:IsOpen("sanity")
end

-- Order card position (UI px): the top-left column, stacked under the sanity meter when that is on screen (night: the
-- sanity first, then the order). Portrait / narrow (the pills stack in a column): never above the end of that column.
function HudController:OrderPosition(): UDim2
	const scale = self.Scale()
	const viewport = self.Viewport()
	local top = self:TopLeftY()
	if viewport.X / scale < NARROW_WIDTH then
		top = UNDER_PILL_COLUMN + ORDER_GAP
	end
	if self:SanityOn() then
		const row = if self:Compact() then SANITY_ROW_COMPACT else SANITY_ROW_LARGE
		top = math.max(top, self:TopLeftY() + row + ORDER_GAP)
	end
	return UDim2.fromOffset(ORDER_LEFT, top)
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
		-- talk reveal at the tablet (FEAT-043, TASK-384): items said so far, each new one pops in; restaurant only
		Reveal = if Content.Restaurant.Rules.Enabled
			then function()
				return customer:CardReveal() or math.huge
			end
			else nil,
		Revealed = function()
			return self:IsOpen("order_card")
		end,
		Position = function()
			return self:OrderPosition()
		end,
	})
end

-- Progressive reveal (Content.HudReveal) ---------------------------------------------------------------------------------

-- Row `key` is on screen (latched). Read inside a reactive binding: tracks the Open source.
function HudController:IsOpen(key: string): boolean
	return self.Open()[key] == true
end

-- Same, without tracking (for plain code: notices)
function HudController:IsOpenNow(key: string): boolean
	return Vide.untrack(self.Open)[key] == true
end

-- Opens the rows whose trigger fired and latches them (never closes one). Reads (tracked): the tutorial (StepKey, Finished,
-- first-run state), the shift (phase, night, readiness), the cinematic and the dev switches, so it runs again on any of them.
-- Waits for the profile and the round: a first run is only known after the Profile packet (else everything would open).
function HudController:EvaluateReveal()
	const tutorial = self.Dependencies.TutorialController
	const round = self.Dependencies.RoundController
	self.Epoch()
	const ready = self.Dependencies.ProfileController.Ready() and round.Ready()
	const everything = self.DevAll()
	const gated = tutorial:FirstRun() or self.DevGate()
	const night = round.IsNight()
	const nightNumber = round.Night()
	const phase = round.Phase()
	const finished = tutorial.Finished()
	const stepIndex = Steps.IndexOf[tutorial.StepKey()] or 0
	const cinematic = Cinematic.Active()
	if not ready then
		return
	end

	Vide.untrack(function()
		const open = self.Open()
		const intros = self.Intros()
		const nextOpen = table.clone(open)
		const nextIntros = table.clone(intros)
		local changed = false
		for _, row in Content.HudReveal.List do
			if open[row.Key] then
				continue
			end
			local on = false
			if everything then
				on = true
			elseif row.Trigger == "Night" then
				-- its own trigger, also outside a first run: the first night with it is the introduction
				on = night and nightNumber >= row.Night
				if on and row.Pulse then
					nextIntros[row.Key] = true
				end
			elseif not gated or night then
				on = true
			elseif row.Trigger == "Start" then
				on = phase ~= "Intro" and not cinematic
			elseif row.Trigger == "Step" then
				on = stepIndex > 0 and stepIndex >= (Steps.IndexOf[row.Step] or math.huge)
			elseif row.Trigger == "TutorialEnd" then
				on = finished
			end
			if on then
				nextOpen[row.Key] = true
				changed = true
			end
		end
		if changed then
			Vide.batch(function()
				self.Open(nextOpen)
				self.Intros(nextIntros)
			end)
		end
		return nil
	end)
end

-- `/dev hud reveal all|reset|status` (DevClient command "hud_reveal", plugged into TutorialController:SetDevHandler)
function HudController:DevReveal(text: string)
	const arg = string.lower(string.match(text, "^%s*(%S*)") or "")
	if arg == "all" then
		Vide.batch(function()
			self.DevAll(true)
			self.DevGate(false)
		end)
		print(`{DEV_PREFIX} everything on screen`)
	elseif arg == "reset" then
		Vide.batch(function()
			self.DevAll(false)
			self.DevGate(true)
			self.Open({})
			self.Intros({})
			self.Epoch(Vide.untrack(self.Epoch) + 1)
		end)
		print(`{DEV_PREFIX} reset: only the essentials; the steps release the rest ("/dev tutorial reset" to play them)`)
	elseif arg == "status" or arg == "" then
		const open = Vide.untrack(self.Open)
		const lines: { string } = {}
		for _, row in Content.HudReveal.List do
			table.insert(lines, `{row.Key}={if open[row.Key] then "on" else "off"} ({row.Trigger})`)
		end
		print(`{DEV_PREFIX} {table.concat(lines, ", ")}`)
	else
		warn(`{DEV_PREFIX} usage: /dev hud reveal all | reset | status`)
	end
end

-- Wave 1 -----------------------------------------------------------------------------------------------------------

function HudController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const scale = Theme.ScaleOf(camera.ViewportSize)
	if camera.ViewportSize ~= self.Viewport() then
		self.Viewport(camera.ViewportSize)
	end
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

	const unmount, gui = Vide.root(function()
		-- Progressive reveal: opens the HUD elements as their triggers fire (Content.HudReveal)
		Vide.effect(function()
			self:EvaluateReveal()
		end)

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
				-- progressive reveal (Content.HudReveal): clock, shift, money, toasts
				Reveal = function(key: string)
					return self:IsOpen(key)
				end,
				-- settings gear (TASK-279)
				OnSettings = function()
					self.Dependencies.SettingsController:Toggle()
				end,
				SettingsOpen = self.Dependencies.SettingsController.Open,
				-- shop cart, key labels and the quick note (TASK-290)
				OnShop = function()
					self.Dependencies.ShopController:Toggle()
				end,
				ShopOpen = self.Dependencies.ShopController.Open,
				ShopGlow = self.Dependencies.ShopController.Glow,
				Device = self.Dependencies.InputController.Device,
				Nudge = function()
					return self.Dependencies.ShopController:NudgeLine()
				end,
				OnNudge = function()
					self.Dependencies.ShopController:OnNudge()
				end,
				NudgeIcon = self.Dependencies.ShopController.NudgeIcon,
				NudgePad = self.Dependencies.ShopController.NudgePad,
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
	-- The money / day pills live top right: the Roblox player list would sit under them
	const ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if not ok then
		warn(`[HudController] could not hide the player list: {err}`)
	end
	self:WatchViewport()
	-- a reveal table row naming a step the tutorial does not have would never open: say so at once
	for _, row in Content.HudReveal.List do
		if row.Trigger == "Step" and Steps.ByKey[row.Step] == nil then
			warn(`[HudController] HudReveal '{row.Key}': unknown tutorial step '{row.Step}'`)
		end
	end
	-- dev only: /dev hud reveal (the server sends it through the DevClient packet; TutorialController routes it here)
	self.Dependencies.TutorialController:SetDevHandler("hud_reveal", function(text: string)
		self:DevReveal(text)
	end)
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
