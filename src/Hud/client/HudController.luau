--!strict
--[[
	HudController (TASK-039; FEAT-032, FEAT-014; DEC-015, DEC-048, DEC-051, DEC-053, DEC-081)

	Mounts the status HUD (Interface/Components/HudScreen) in the OnStart, per architecture.md §3 (priority 500):
	  - clock and "Day N" from RoundController (ClockText, Day, IsNight; the Shift set is never read here);
	  - party money from EconomyController.Cash;
	  - toasts from the `Notice` packet (network.md §4.2), text from Content.Notices with {value}/{item}/{upgrade}/
	    {class}/{achievement} filled in; same text already queued is dropped (a spammed "Hands full" shows once);
	  - end-of-shift summary from the `ShiftReport` packet (network.md §4.4), hidden by itself after 15 s on day /
	    20 s at night, or as soon as the next shift starts.

	Status only: no button, no input binding (FEAT-032: nothing clickable for an Active player). No reputation, no boss
	chances (Shift.Chances is not read), no XP, no sanity (night only, wave 2). The client never writes money: the
	numbers come from the server's sets and packets. Texts are placeholders until ui-text.md.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local HudScreen = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudScreen)
local HudSummary = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSummary)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Toast = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast)

-- FEAT-014: summary on screen 15 s on day (= Content.Shift Summary), 20 s at night
const DAY_SUMMARY = Content.Shift.ByKey.Summary.Duration
const NIGHT_SUMMARY = 20
-- Phases that start a new shift: an old summary still on screen goes away
const NEW_SHIFT: { [string]: boolean } = { Intro = true, Prep = true, Open = true, Call = true, Night = true }
-- network.md §4.2: toast on screen 3-6 s
const TOAST_DURATION = 4
-- Notices waiting beyond this are dropped (the oldest waiting first); 3 are on screen at a time
const MAX_TOASTS = 6
const MAX_VISIBLE = 3
-- UI scale: 1 on the smallest phone (375 px tall), grows with the screen up to 2 (1080p)
const BASE_HEIGHT = 540
const MAX_SCALE = 2

-- Notice keys shown as an alert (Mustard; never red, style guide §7.4) and as good news (Green). The rest: Info.
const ALERT: { [string]: boolean } = {
	hands_full = true,
	package_limit = true,
	not_enough_cash = true,
	not_enough_gems = true,
	class_locked = true,
}
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
	Stolen: number,
	Grade: string,
	Bonus: number,
	Deposited: number,
	Gems: number,
	AfkLocked: boolean,
	LastChanceUsed: boolean,
}

const HudController = Modux.Controller(
	"HudController",
	{ Require = { "RoundController", "EconomyController", "ProfileController" }, Priority = 500 }
)

function HudController:Setup()
	self.Toasts = Vide.source({} :: { ToastStack.Entry }) :: Vide.Source<{ ToastStack.Entry }>
	-- false = no summary on screen (a Source of an optional type is ambiguous to call under the new solver)
	self.Report = Vide.source(false :: HudSummary.Shown) :: Vide.Source<HudSummary.Shown>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.ReportThread = nil :: thread?
	self.Gui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?
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
	const list = table.clone(self.Toasts())
	for _, entry in list do
		if entry.Text == text then
			return
		end
	end
	if #list >= MAX_TOASTS then
		-- keep what is on screen; drop the oldest one still waiting
		table.remove(list, MAX_VISIBLE + 1)
	end
	const toastKind: Toast.Kind = if ALERT[kind] then "Alert" elseif GOOD[kind] then "Good" else "Info"
	table.insert(list, { Text = text, Kind = toastKind, Duration = TOAST_DURATION })
	self.Toasts(list)
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
	const thread = self.ReportThread
	self.ReportThread = nil
	if thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
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

function HudController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const scale = math.clamp(camera.ViewportSize.Y / BASE_HEIGHT, 1, MAX_SCALE)
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
		-- A new shift clears a summary that is still up (e.g. dev "skip" shortened the Summary)
		Vide.effect(function()
			if NEW_SHIFT[round.Phase()] then
				Vide.untrack(function()
					self:HideReport()
					return nil
				end)
			end
		end)

		return Vide.create("ScreenGui")({
			Name = "Hud",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 1,

			HudScreen({
				Clock = round.ClockText,
				Shift = function()
					return if round.IsNight() then "Night" else `Day {round.Day()}`
				end,
				IsNight = round.IsNight,
				Cash = economy.Cash,
				Toasts = self.Toasts,
				OnToastDone = function(entry)
					self:ToastDone(entry)
				end,
				Report = self.Report,
				Scale = self.Scale,
			}),
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
end

HudController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Notice:onClient(function(notice)
		self:PushToast(notice.Kind, notice.Value)
	end)

	self.Libs.Net.ShiftReport:onClient(function(report)
		self:ShowReport(report)
	end)
end)

HudController:OnStart(function(self)
	self:WatchViewport()
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return HudController
