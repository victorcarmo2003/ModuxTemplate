--!strict
--[[
	PrepController (TASK-173, TASK-174, TASK-175; docs/tech/prep-mode.md §2, §5, §6; docs/art/prep-ui-spec.md; DEC-223)

	The client of the focused prep mode: the player sits at a station of the trailer and works the plate on a 2D board over
	a blurred 3D trailer. The server decides (PrepService seats, validates, grades); this client predicts and presents.

	Enter / leave
	  - the set `PrepSeats` (id = station 1..4): a record with `User` = the own UserId enters that station; a record that
	    changes hands or is freed leaves. `PrepResult` Act = Kick (forced exit: anomaly signal, sanity band, Down, cutscene,
	    closing, thief, idle) leaves in Rules.ForcedExit.Signal s; any other refusal shows its Notice as a toast.
	  - entering (from FirstPerson and `Active` only, never over a cutscene / spectate): camera Scriptable on the pose of the
	    station (Station_n CamAnchor, else the TRL fallback of Poses.luau) with a Rules.Camera.Travel s tween, depth of
	    field only above graphics quality 3 (else an Ink vignette), own rig hidden locally (fade 0.15 s), NPCs on the line
	    camera -> plate cut / ghosted (Rig.luau), InputController context `Menu` (restored), the Roblox hotbar, touch
	    controls, chat and the Hud gui hidden (restored), the world prompts gated (PromptController:AddGate("Prep")), then the
	    chrome pops in (PrepShell). Movement is locked by the server (`Frozen`).
	  - Leave is always on screen (the Exit / Leave button) and on Q / gamepad B; leaving runs the way out (chrome out,
	    camera back in Rules.Camera.Leave s, rig back at 60 % of it) and gives everything back. Anything that takes the camera
	    meanwhile (cutscene) is a takeover: the mode drops at once without touching the camera.
	  - `reduced motion` (UserGameSettings.ReducedMotion): the camera cuts, the chrome does not pop.

	Input (one Pointer for mouse, touch and the gamepad cursor; Gestures.luau gives the stages Drag, Trace, Tap, Hold)
	  keyboard   mouse drag, Tab next tab, 1 to 4 tabs, Enter next, Q leave
	  touch      drag outside the (hidden) joystick, the point drawn Rules.TouchOffset px above the finger
	  gamepad    left stick = virtual cursor, A = hold / release, B leave, Y next, LB / RB tabs

	API for the stages (TASK-176 to 179), see Stage.luau: `View` (plate, toppings, seal, strokes, hint pips), `Step`, `Tab`,
	`Needs`, `Gestures`, `Assist`, :SetStage, :SetTab, :Need, :SetPip, :ResetPlate, :Toast, :OnGesture, :OnPick, :Trash.
	Stages/*.luau are discovered at boot (a new tab behaviour is a new file; the init is not edited).

	Dev (Studio Run place only): `/dev prep ui` toggles the mode locally with mock data (DevClient "prep_ui", text = the
	station, default 1). It never sends a Prep packet.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local PlateView = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateView)
local PrepShell = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PrepShell)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local TicketRail = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TicketRail)
local Cursor = require(script.Cursor)
local Feed = require(script.Feed)
local Gestures = require(script.Gestures)
local Mock = require(script.Mock)
local Parts = require(script.Parts)
local Pointer = require(script.Pointer)
local Poses = require(script.Poses)
local Rig = require(script.Rig)
local Stage = require(script.Stage)

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack

const prep = Content.Prep
const rules = prep.Rules

export type Toast = { Text: string, Kind: "Info" | "Good" | "Alert", Id: number }

export type Pip = PrepShell.Pip

-- View-model of the board: the stages write it, PlateView / TicketRail / IngredientPanel read it. `false` = none (a Source of
-- an optional type makes the 0-argument call ambiguous for the solver).
export type View = {
	Bun: Vide.Source<PlateView.BunState>,
	Cut: Vide.Source<number>,
	Guide: Vide.Source<boolean>,
	Sausage: Vide.Source<PlateView.Sausage | false>,
	Toppings: Vide.Source<{ PlateView.Topping }>,
	Seal: Vide.Source<PlateView.Grade | false>,
	Message: Vide.Source<string>,
	Pips: Vide.Source<{ Pip }>,
	-- ingredient boxes: the keys already on the plate, the box in focus, a refused pick, the plate is full
	Used: Vide.Source<{ [string]: boolean }>,
	Focus: Vide.Source<string>,
	Refused: Vide.Source<{ Key: string, Id: number } | false>,
	Full: () -> boolean,
	Info: (key: string) -> { Stock: number, Locked: boolean, Used: boolean },
	-- sauce stroke layer (StrokeCanvas): points 0..1, the target path, the colour, the meter
	Stroke: Vide.Source<{ Vector2 }>,
	StrokeGuide: Vide.Source<{ Vector2 }>,
	StrokeColor: Vide.Source<Color3>,
	Meter: Vide.Source<{ Fill: number, Target: number, Window: number } | false>,
	-- the ticket in front and the line behind it
	Ticket: Vide.Source<Mock.Ticket | false>,
	Queue: Vide.Source<number>,
}

const PrepController = Modux.Controller("PrepController", {
	Require = {
		"InputController",
		"CameraController",
		"PromptController",
		"KitchenController",
		"CustomerController",
		"RoundController",
		"VitalController",
		"EconomyController",
		"PlaceController",
	},
	Priority = 675,
})

const RENDER_STEP = "PrepController.Step"
-- After the CameraController (Camera + 1): its first-person groups never run in the Prep mode, but the last word on the rig
-- visibility is ours.
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 2
const GUI_ORDER = 6
const CURSOR_ORDER = 7
const TOAST_TIME = 2.2
const TOAST_ALERT_TIME = 3
const CHROME_DELAY = 0.2 -- s after the camera starts to move: the chrome pops in
const RIG_RELEASE = 0.6 -- fraction of the way out at which the own rig comes back (spec §13.3)
const LEAVE_TIMEOUT = 2.5 -- s: the way out is finished anyway
const TRASH_HOLD = 0.5 -- s of the hold on the bin (spec §6.5, Provisional)
const TRASH_TEXT = "Hold to trash" -- Provisional text
const CURSOR_SIZE = 30
const TAB_KEYS: { Enum.KeyCode } = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
-- World prompts of the kitchen the mode replaces (Content.Prep.Rules.WorldKitchenPrompts = false hides them, DEC-223).
-- `discard` is left to the server (the street bin keeps it): KitchenService hides only the BIN-C one.
const KITCHEN_ACTIONS: { [string]: boolean } = {
	grill_place = true,
	grill_collect = true,
	bun_cut = true,
	board_add_sausage = true,
	topping_add = true,
}

local function newPips(): { Pip }
	return { { Label = "Cut" }, { Label = "Place" }, { Label = "Top" } }
end

-- Graphics quality 1..3 keeps the vignette instead of the depth of field (spec §13.7). Automatic (0) counts as high.
local function dofAllowed(): boolean
	const ok, level = pcall(function(): any
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	if not ok then
		return true
	end
	const value = (level :: Enum.SavedQualitySetting).Value
	return value == 0 or value > 3
end

function PrepController:Setup()
	-- the mode is on: from Enter to the end of the way out
	self.Active = source(false) :: Vide.Source<boolean>
	-- the chrome is on screen (pop in / out)
	self.Shown = source(false) :: Vide.Source<boolean>
	self.Station = source(0) :: Vide.Source<number>
	-- Content.Prep.Tabs key in front
	self.Tab = source("Order") :: Vide.Source<string>
	-- Content.Prep.Steps key of the plate
	self.Step = source("grill") :: Vide.Source<string>
	-- what the corner button waits for: BunCut, PlateBuilt, TicketPicked
	self.Needs = source({} :: { [string]: boolean }) :: Vide.Source<{ [string]: boolean }>
	self.Badges = source({} :: { [string]: number }) :: Vide.Source<{ [string]: number }>
	self.Toasts = source(false :: Toast | false) :: Vide.Source<Toast | false>
	-- +30 % tolerance of the gestures (Rules.Assist), mandatory option of phase 1
	self.Assist = source(false) :: Vide.Source<boolean>
	-- no depth of field: the chrome draws an Ink vignette
	self.Vignette = source(false) :: Vide.Source<boolean>
	self.View = self:MakeView() :: View

	-- the mode runs on mock data (`/dev prep ui`): no packet goes out
	self.Mock = false :: boolean
	-- same, but only true between Enter and the finish of the way out (the gate and the context read it)
	self.InMode = false :: boolean
	self.Leaving = false :: boolean
	self.LeavingSince = 0 :: number
	self.RigReleased = false :: boolean
	self.LeaveTravel = 0 :: number
	self.Forced = false :: boolean
	self.LeaveReason = "" :: string
	self.NextBeat = 0 :: number
	self.ToastId = 0 :: number
	self.Stages = {} :: { [string]: Stage.Stage }
	self.Pointer = nil :: Pointer.Pointer?
	self.Gestures = nil :: Gestures.Recogniser?
	self.Cursor = nil :: Cursor.Cursor?
	self.Rig = Rig.new() :: Rig.Rig
	self.Pose = nil :: Poses.Pose?
	self.Unmount = nil :: (() -> ())?
	self.Gui = nil :: ScreenGui?
	self.CursorGui = nil :: ScreenGui?
	self.UnmountCursor = nil :: (() -> ())?
	self.PreviousContext = "Gameplay" :: string
	self.BoundNames = {} :: { string }
	-- what Isolate hid and must give back
	self.Saved = {} :: { [string]: any }
	self.PointerStops = {} :: { () -> () }
end

function PrepController:MakeView(): View
	const toppings = source({} :: { PlateView.Topping })
	const used = source({} :: { [string]: boolean })
	local view: View
	view = {
		Bun = source("None" :: PlateView.BunState),
		Cut = source(0),
		Guide = source(false),
		Sausage = source(false :: PlateView.Sausage | false),
		Toppings = toppings,
		Seal = source(false :: PlateView.Grade | false),
		Message = source(""),
		Pips = source(newPips()),
		Used = used,
		Focus = source(""),
		Refused = source(false :: { Key: string, Id: number } | false),
		Full = function(): boolean
			return #toppings() >= Content.OrderRules.MaxToppings
		end,
		Info = function(key: string): { Stock: number, Locked: boolean, Used: boolean }
			return self:InfoOf(key)
		end,
		Stroke = source({} :: { Vector2 }),
		StrokeGuide = source({} :: { Vector2 }),
		StrokeColor = source(Theme.Tone.Mustard.Bottom),
		Meter = source(false :: { Fill: number, Target: number, Window: number } | false),
		Ticket = source(false :: Mock.Ticket | false),
		Queue = source(0),
	}
	return view
end

-- Stock of a topping box: the real stock (KitchenController, reactive) or the mock one.
function PrepController:InfoOf(key: string): { Stock: number, Locked: boolean, Used: boolean }
	const used = self.View.Used()[key] == true
	if self.Mock then
		const row = Mock.Stock[key]
		return { Stock = if row ~= nil then row.Stock else 0, Locked = row ~= nil and row.Locked, Used = used }
	end
	const record = self.Dependencies.KitchenController:StockOf(key)
	return {
		Stock = if record ~= nil then record.Amount else 0,
		Locked = record ~= nil and record.Blocked,
		Used = used,
	}
end

-- Stages ------------------------------------------------------------------------------------------------------------

function PrepController:LoadStages()
	const folder = script:FindFirstChild("Stages")
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		const ok, value = pcall(require, child)
		if not ok then
			warn(`[PrepController] Stages/{child.Name} failed to load: {value}`)
			continue
		end
		const problem = Stage.check(value, child.Name)
		if problem ~= nil then
			warn(`[PrepController] Stages/{problem}`)
			continue
		end
		const stage = value :: Stage.Stage
		if prep.Tabs.ByKey[stage.Tab] == nil then
			warn(`[PrepController] Stages/{child.Name}: unknown tab '{stage.Tab}'`)
			continue
		end
		self.Stages[stage.Tab] = stage
	end
	for _, row in prep.Tabs.List do
		if self.Stages[row.Key] == nil then
			warn(`[PrepController] no stage for the tab '{row.Key}'`)
		end
	end
end

function PrepController:StageOf(tab: string?): Stage.Stage?
	return self.Stages[tab or untrack(self.Tab)]
end

-- Public API of the stages ----------------------------------------------------------------------------------------------

-- A tab to the front (the bar, 1 to 4, LB / RB, a stage that moves on). Sends PrepTab (also the keep-alive).
function PrepController:SetTab(tab: string)
	if prep.Tabs.ByKey[tab] == nil or untrack(self.Tab) == tab then
		return
	end
	const previous = self:StageOf()
	self:CancelGestures()
	if previous ~= nil and previous.OnLeave ~= nil then
		previous.OnLeave(self)
	end
	self.Tab(tab)
	-- keep the step on a tab that owns it
	const step = prep.Steps.ByKey[untrack(self.Step)]
	if step == nil or step.Tab ~= tab then
		for _, row in prep.Steps.List do
			if row.Tab == tab then
				self.Step(row.Key)
				break
			end
		end
	end
	const stage = self:StageOf(tab)
	if stage ~= nil and stage.OnEnter ~= nil then
		stage.OnEnter(self)
	end
	self:SendTab()
end

-- A step of the plate (`grill`, `bun`, `build`, `serve`); brings its tab to the front.
function PrepController:SetStage(stepKey: string)
	const step = prep.Steps.ByKey[stepKey]
	if step == nil then
		return
	end
	self.Step(stepKey)
	self:SetTab(step.Tab)
end

function PrepController:Need(name: string, value: boolean)
	if untrack(self.Needs)[name] == value then
		return
	end
	const copy = table.clone(untrack(self.Needs))
	copy[name] = value
	self.Needs(copy)
end

-- Grade of one of the three pips of the board header (1 Cut, 2 Place, 3 Top); nil = empty again.
function PrepController:SetPip(index: number, grade: PlateView.Grade?)
	const copy = table.clone(untrack(self.View.Pips))
	if copy[index] == nil then
		return
	end
	copy[index] = { Label = copy[index].Label, Grade = grade }
	self.View.Pips(copy)
end

-- Back to an empty board (after Serve, the bin, Leave).
function PrepController:ResetPlate()
	const view = self.View
	Vide.batch(function()
		view.Bun("None")
		view.Cut(0)
		view.Guide(false)
		view.Sausage(false)
		view.Toppings({})
		view.Seal(false)
		view.Message("")
		view.Pips(newPips())
		view.Used({})
		view.Focus("")
		view.Stroke({})
		view.StrokeGuide({})
		view.Meter(false)
	end)
	self:Need("BunCut", false)
	self:Need("PlateBuilt", false)
end

-- One line at the bottom (one at a time, a new one replaces the old).
function PrepController:Toast(text: string, kind: ("Info" | "Good" | "Alert")?)
	self.ToastId += 1
	const id = self.ToastId
	const value: Toast = { Text = text, Kind = kind or "Info", Id = id }
	self.Toasts(value)
	task.delay(if kind == "Alert" then TOAST_ALERT_TIME else TOAST_TIME, function()
		const current = untrack(self.Toasts)
		if current ~= false and current.Id == id then
			self.Toasts(false)
		end
	end)
end

function PrepController:SetAssist(on: boolean)
	self.Assist(on)
end

-- What the stage in front receives: every gesture event, a "Pick" (tap on a topping box), a "Result" (PrepResult).
function PrepController:OnGesture(event: any)
	const stage = self:StageOf()
	if stage ~= nil and stage.OnGesture ~= nil then
		stage.OnGesture(self, event)
	end
end

function PrepController:OnPick(key: string)
	self:OnGesture({ Kind = "Pick", Key = key })
end

function PrepController:CancelGestures()
	const recogniser = self.Gestures
	if recogniser ~= nil then
		recogniser:CancelAll()
	end
end

function PrepController:PressNext()
	const stage = self:StageOf()
	if stage == nil then
		return
	end
	const state = stage.Next(self)
	if not state.Enabled then
		self:Toast(stage.Hint(self), "Alert")
		return
	end
	if stage.OnNext ~= nil then
		stage.OnNext(self)
	end
end

-- The bin: the plate goes (the server drops its bun and sausage on PrepTrash).
function PrepController:Trash()
	const had = untrack(self.View.Bun) ~= "None"
	self:ResetPlate()
	self:SetStage("grill")
	if had then
		self:Toast("Plate trashed", "Info")
		if not self.Mock then
			self.Libs.Net.PrepTrash:fireServer()
		end
	end
end

-- Cycle the pinned ticket (the ticket rail tap): every stage with OnEvent hears it, whatever tab is in front (Feed.luau).
function PrepController:CycleTicket()
	self:Broadcast({ Kind = "Cycle" })
end

-- An event for every stage that listens (Stage.OnEvent), not only the one in front: PrepResult, Sale, Cycle.
function PrepController:Broadcast(event: any)
	for _, stage in self.Stages do
		if stage.OnEvent ~= nil then
			stage.OnEvent(self, event)
		end
	end
end

-- Network -------------------------------------------------------------------------------------------------------------------

function PrepController:SendTab()
	if self.Mock or not self.InMode then
		return
	end
	self.NextBeat = os.clock() + rules.Heartbeat
	const ticket = untrack(self.View.Ticket)
	self.Libs.Net.PrepTab:fireServer({
		Step = untrack(self.Tab),
		Ticket = if ticket ~= false then math.clamp(ticket.Id, 0, 65535) else 0,
	})
end

function PrepController:OnResult(result: any)
	if result.Act == "Kick" then
		self:Leave("Kick", true, true)
		self:Notice(result.Reason)
		return
	end
	if not result.Ok then
		self:Notice(result.Reason)
	end
	self:Broadcast({ Kind = "Result", Result = result })
	const stage = self:StageOf()
	if stage ~= nil and stage.OnResult ~= nil then
		stage.OnResult(self, result)
	end
end

-- The Notice a refusal reason carries (Content.Prep.Reasons), as a toast.
function PrepController:Notice(reason: string)
	const row = prep.Reasons.ByKey[reason]
	if row == nil or row.Notice == nil then
		return
	end
	const notice = Content.Notices.ByKey[row.Notice]
	if notice ~= nil then
		self:Toast(notice.Text, "Alert")
	end
end

-- Enter / leave -------------------------------------------------------------------------------------------------------------

-- Isolation: what is hidden while the mode is up, and what must come back (nothing is left hidden by an error: Finish runs
-- in every way out).
function PrepController:Isolate(on: boolean)
	const saved = self.Saved
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if on then
		if playerGui ~= nil then
			for _, name in { "Hud", "TouchGui" } do
				const gui = playerGui:FindFirstChild(name)
				if gui ~= nil and gui:IsA("ScreenGui") then
					saved[name] = gui.Enabled
					gui.Enabled = false
				end
			end
		end
		const ok, hotbar = pcall(function(): boolean
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end)
		if ok then
			saved.Backpack = hotbar
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		end
		const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if chat ~= nil then
			saved.Chat = chat.Enabled
			chat.Enabled = false
		end
		saved.AutoSelect = GuiService.AutoSelectGuiEnabled
		return
	end
	if playerGui ~= nil then
		for _, name in { "Hud", "TouchGui" } do
			const gui = playerGui:FindFirstChild(name)
			if gui ~= nil and gui:IsA("ScreenGui") and saved[name] ~= nil then
				gui.Enabled = saved[name]
			end
		end
	end
	if saved.Backpack ~= nil then
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, saved.Backpack)
	end
	const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if chat ~= nil and saved.Chat ~= nil then
		chat.Enabled = saved.Chat :: boolean
	end
	if saved.AutoSelect ~= nil then
		GuiService.AutoSelectGuiEnabled = saved.AutoSelect :: boolean
	end
	GuiService.SelectedObject = nil
	table.clear(saved)
end

-- Keys and gamepad buttons of the mode (context Menu). B / Y / LB / RB / A and the left stick are the gamepad map.
function PrepController:Bind(on: boolean)
	const input = self.Dependencies.InputController
	if not on then
		for _, name in self.BoundNames do
			input:Unbind(name)
		end
		table.clear(self.BoundNames)
		return
	end
	local function bind(name: string, key: Enum.KeyCode, keys: { Enum.KeyCode | Enum.UserInputType }?, press: (() -> ())?, release: (() -> ())?)
		const handle = input:Bind({
			Name = name,
			Key = key,
			Keys = keys,
			Priority = Enum.ContextActionPriority.High.Value,
			Context = "Menu",
		})
		if press ~= nil then
			handle.OnPress(press)
		end
		if release ~= nil then
			handle.OnRelease(release)
		end
		table.insert(self.BoundNames, name)
	end
	local function nextTab(step: number)
		const list = prep.Tabs.List
		local index = 1
		for position, row in list do
			if row.Key == untrack(self.Tab) then
				index = position
			end
		end
		self:SetTab(list[(index - 1 + step) % #list + 1].Key)
	end
	bind("PrepLeave", Enum.KeyCode.Q, { Enum.KeyCode.ButtonB }, function()
		self:Leave("Key", false, false)
	end, nil)
	bind("PrepNext", Enum.KeyCode.Return, { Enum.KeyCode.ButtonY }, function()
		self:PressNext()
	end, nil)
	bind("PrepTabNext", Enum.KeyCode.Tab, { Enum.KeyCode.ButtonR1 }, function()
		nextTab(1)
	end, nil)
	bind("PrepTabPrev", Enum.KeyCode.ButtonL1, nil, function()
		nextTab(-1)
	end, nil)
	for index, key in TAB_KEYS do
		const row = prep.Tabs.List[index]
		if row ~= nil then
			bind(`PrepTab{index}`, key, nil, function()
				self:SetTab(row.Key)
			end, nil)
		end
	end
	-- A holds / releases the virtual cursor; the left stick is swallowed (the cursor reads it itself)
	bind("PrepGrab", Enum.KeyCode.ButtonA, nil, function()
		const cursor = self.Cursor
		if cursor ~= nil then
			cursor:Press()
		end
	end, function()
		const cursor = self.Cursor
		if cursor ~= nil then
			cursor:Release()
		end
	end)
	bind("PrepStick", Enum.KeyCode.Thumbstick1, nil, nil, nil)
end

-- The ScreenGui of the chrome (and the one of the cursor, in screen px).
function PrepController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	const stages = self.Stages
	const tabs: { PrepShell.Tab } = {}
	for _, row in prep.Tabs.List do
		table.insert(tabs, { Key = row.Key, Label = row.Label, Icon = row.Icon })
	end
	local function stageOr(tab: string): Stage.Stage?
		return stages[tab]
	end
	const unmount, gui = Vide.root(function(): ScreenGui
		return create("ScreenGui")({
			Name = "Prep",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = GUI_ORDER,
			Enabled = self.Active,
			PrepShell({
				Tabs = tabs,
				Tab = self.Tab,
				Badges = self.Badges,
				OnTab = function(key: string)
					self:SetTab(key)
				end,
				OnLeave = function()
					self:Leave("Button", false, false)
				end,
				LeaveText = prep.Texts.Leave,
				Hint = function(): string
					const stage = stageOr(self.Tab())
					return if stage ~= nil then stage.Hint(self) else ""
				end,
				Pips = function(): { Pip }
					return if self.Tab() == "Build" then self.View.Pips() else {}
				end,
				HasPanel = function(): boolean
					const stage = stageOr(self.Tab())
					return stage ~= nil and stage.HasPanel
				end,
				Next = {
					Label = function(): string
						const stage = stageOr(self.Tab())
						return if stage ~= nil then stage.Next(self).Label else prep.Texts.Next
					end,
					Enabled = function(): boolean
						const stage = stageOr(self.Tab())
						return stage ~= nil and stage.Next(self).Enabled
					end,
					Pulse = function(): boolean
						const stage = stageOr(self.Tab())
						return stage ~= nil and stage.Next(self).Pulse == true
					end,
					OnPress = function()
						self:PressNext()
					end,
					OnBlocked = function()
						self:PressNext()
					end,
				},
				Trash = {
					Visible = function(): boolean
						return self.View.Bun() ~= "None" and self.View.Seal() == false and self.Tab() == "Build"
					end,
					Hold = TRASH_HOLD,
					HoldText = TRASH_TEXT,
					OnTrash = function()
						self:Trash()
					end,
				},
				Assist = {
					Label = prep.Texts.Assist,
					On = self.Assist,
					OnToggle = function()
						self:SetAssist(not untrack(self.Assist))
					end,
				},
				Cash = self.Dependencies.EconomyController.Cash,
				Clock = self.Dependencies.RoundController.ClockText,
				IsNight = self.Dependencies.RoundController.IsNight,
				Sanity = function(): number?
					const vital = self.Dependencies.VitalController
					const max = vital.Max()
					return if max > 0 then math.clamp(vital.Sanity() / max, 0, 1) else nil
				end,
				Toast = function(): PrepShell.Toast?
					const value = self.Toasts()
					return if value ~= false then value else nil
				end,
				Slots = {
					Ticket = function(layout: () -> any): any
						return TicketRail({
							Ticket = function(): TicketRail.Ticket?
								const value = self.View.Ticket()
								return if value ~= false then value else nil
							end,
							Queue = self.View.Queue,
							Strip = function(): boolean
								return layout().TicketStrip
							end,
							OnCycle = function()
								self:CycleTicket()
							end,
						})
					end,
					Board = function(_layout: () -> any): any
						const map: { [string]: () -> any } = {}
						for _, row in prep.Tabs.List do
							const stage = stageOr(row.Key)
							map[row.Key] = function(): any
								return if stage ~= nil then stage.Board(self) else Parts.Notice(function(): string
									return "Stage missing"
								end)
							end
						end
						return Vide.switch(self.Tab)(map :: any)
					end,
					Panel = function(layout: () -> any): any
						const stage = stageOr("Build")
						return if stage ~= nil and stage.Panel ~= nil then stage.Panel(self, layout) else nil
					end,
				},
				Shown = self.Shown,
				Vignette = self.Vignette,
			}),
		}) :: ScreenGui
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui

	-- the cursor ring (gamepad cursor, touch point) in raw screen px: no insets
	const cursor = self.Cursor
	if cursor ~= nil then
		const unmountCursor, cursorGui = Vide.root(function(): ScreenGui
			return create("ScreenGui")({
				Name = "PrepCursor",
				ResetOnSpawn = false,
				ScreenInsets = Enum.ScreenInsets.None,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = CURSOR_ORDER,
				Enabled = function()
					return cursor.Visible()
				end,
				create("Frame")({
					Name = "Ring",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = function(): UDim2
						const at = cursor.Position()
						return UDim2.fromOffset(at.X, at.Y)
					end,
					Size = function(): UDim2
						const side = if cursor.Held() then CURSOR_SIZE - 6 else CURSOR_SIZE
						return UDim2.fromOffset(side, side)
					end,
					BackgroundColor3 = Theme.Color.Mustard,
					BackgroundTransparency = 0.35,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					(Vide.create :: any)("UIStroke")({
						Color = Theme.Color.Ink,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				}),
			}) :: ScreenGui
		end)
		self.UnmountCursor = unmountCursor
		self.CursorGui = cursorGui
		cursorGui.Parent = playerGui
	end
end

function PrepController:Unmounted()
	const unmount = self.Unmount
	self.Unmount = nil
	if unmount ~= nil then
		unmount()
	end
	if self.Gui ~= nil then
		self.Gui:Destroy()
		self.Gui = nil
	end
	const unmountCursor = self.UnmountCursor
	self.UnmountCursor = nil
	if unmountCursor ~= nil then
		unmountCursor()
	end
	if self.CursorGui ~= nil then
		self.CursorGui:Destroy()
		self.CursorGui = nil
	end
end

-- Enters the station. `mock` = the dev preview (no seat, no packets). Returns whether it did.
function PrepController:Enter(station: number, mock: boolean?): boolean
	if self.InMode then
		if untrack(self.Station) ~= station and not self.Leaving then
			self:MoveTo(station)
		end
		return self.InMode
	end
	if not rules.Enabled then
		return false
	end
	const camera = self.Dependencies.CameraController
	const vital = self.Dependencies.VitalController
	if untrack(camera.Mode) ~= "FirstPerson" or untrack(vital.LocalState) ~= "Active" then
		return false
	end
	local pose = Poses.Of(station)
	if pose == nil and mock then
		pose = Poses.Mock()
	end
	if pose == nil then
		-- the trailer is not streamed in (no anchor, no TRL): nothing to look at, hand the seat back
		if not mock then
			self.Libs.Net.PrepLeave:fireServer()
		end
		return false
	end

	const reduced = Motion.Reduced()
	const dof = dofAllowed()
	const travel = if reduced then 0 else rules.Camera.Travel
	camera:Prep(true, pose.Frame, {
		Fov = rules.Camera.Fov,
		Travel = travel,
		Dof = dof,
		Focus = rules.Camera.Distance,
		Radius = 0.4,
		Far = 0.7,
	})
	if untrack(camera.Mode) ~= "Prep" then
		return false
	end

	self.InMode = true
	self.Mock = mock == true
	self.Leaving = false
	self.RigReleased = false
	self.Forced = false
	self.Pose = pose
	self.Vignette(not dof)
	self.Shown(false)
	self.Tab("Order")
	self.Step("grill")
	self.Needs({})
	self.Assist(false)
	self.Toasts(false)
	self:ResetPlate()
	self:LoadPreview()
	self.Station(station)
	self.Active(true)

	self:Isolate(true)
	const input = self.Dependencies.InputController
	self.PreviousContext = input.Context
	input:SetContext("Menu")
	self.Rig:Enter(pose.Frame.Position, pose.Focus)

	const pointer = Pointer.new()
	self.Pointer = pointer
	self.Gestures = Gestures.new(pointer)
	self.Cursor = Cursor.new(pointer)
	table.insert(self.PointerStops, pointer:OnDown(function(position: Vector2)
		const key = pointer:HitGrab(position)
		if key ~= nil then
			const stage = self:StageOf()
			if stage ~= nil and stage.OnGrab ~= nil then
				stage.OnGrab(self, key, position)
			end
		end
	end))
	self:Bind(true)
	self:Mount()

	const stage = self:StageOf("Order")
	if stage ~= nil and stage.OnEnter ~= nil then
		stage.OnEnter(self)
	end
	self.NextBeat = os.clock() + rules.Heartbeat
	task.delay(if reduced then 0 else CHROME_DELAY, function()
		if self.InMode and not self.Leaving then
			self.Shown(true)
		end
	end)
	return true
end

-- Another station while seated (the server moved the seat): new pose, same session.
function PrepController:MoveTo(station: number)
	const pose = Poses.Of(station)
	if pose == nil then
		return
	end
	const camera = self.Dependencies.CameraController
	camera:Prep(true, pose.Frame, {
		Fov = rules.Camera.Fov,
		Travel = if Motion.Reduced() then 0 else rules.Camera.Travel,
		Dof = untrack(self.Vignette) == false,
		Focus = rules.Camera.Distance,
		Radius = 0.4,
		Far = 0.7,
	})
	self.Pose = pose
	self.Rig:SetPose(pose.Frame.Position, pose.Focus)
	self.Station(station)
end

-- The way out. `forced` = the server (or an anomaly signal) threw the player out: 0.4 s and the input stays closed for
-- Rules.ForcedExit.NoInput s more. `fromServer` = the seat is already gone there, no PrepLeave.
function PrepController:Leave(reason: string, forced: boolean?, fromServer: boolean?)
	if not self.InMode or self.Leaving then
		return
	end
	self.Leaving = true
	self.LeavingSince = os.clock()
	self.Forced = forced == true
	self.RigReleased = false
	if not self.Mock and not fromServer then
		self.Libs.Net.PrepLeave:fireServer()
	end
	self:CancelGestures()
	self.Shown(false)
	const camera = self.Dependencies.CameraController
	const travel = if Motion.Reduced() then 0 elseif forced then rules.ForcedExit.Signal else rules.Camera.Leave
	self.LeaveTravel = travel
	camera:Prep(false, nil, { Travel = travel })
	-- (a plate that was open stays parked on the server for Rules.ClientIdle s; P7c brings the toast)
	self.LeaveReason = reason
end

-- The mode is over: everything given back. `takeover` = someone else owns the camera now, do not touch it.
function PrepController:Finish(takeover: boolean)
	if not self.InMode then
		return
	end
	self.InMode = false
	self.Leaving = false
	self.Rig:Destroy()
	for _, stop in self.PointerStops do
		stop()
	end
	table.clear(self.PointerStops)
	const recogniser = self.Gestures
	if recogniser ~= nil then
		recogniser:Destroy()
	end
	self.Gestures = nil
	const cursor = self.Cursor
	if cursor ~= nil then
		cursor:Destroy()
	end
	self.Cursor = nil
	const pointer = self.Pointer
	if pointer ~= nil then
		pointer:Destroy()
	end
	self.Pointer = nil
	self:Bind(false)
	self:Unmounted()
	self:Isolate(false)
	self.Shown(false)
	self.Active(false)
	self.Station(0)
	self.Toasts(false)
	self:ResetPlate()
	if takeover then
		const camera = self.Dependencies.CameraController
		if untrack(camera.Mode) == "Prep" then
			camera:Prep(false, nil, { Travel = 0 })
		end
	end
	-- a forced exit keeps the input closed a little longer (Rules.ForcedExit.NoInput), then the context comes back
	const input = self.Dependencies.InputController
	const context = if self.PreviousContext == "Menu" then "Menu" else "Gameplay"
	if self.Forced then
		task.delay(rules.ForcedExit.NoInput, function()
			if not self.InMode then
				input:SetContext(context)
			end
		end)
	else
		input:SetContext(context)
	end
	self.Mock = false
end

-- Mock data of the dev preview.
function PrepController:LoadPreview()
	if not self.Mock then
		return
	end
	const view = self.View
	view.Ticket(Mock.Ticket)
	view.Queue(Mock.Queue)
	self.Badges(Mock.Badges)
	self.Needs({ TicketPicked = true })
end

-- Per frame -------------------------------------------------------------------------------------------------------------

function PrepController:Update(dt: number)
	if not self.InMode then
		return
	end
	self.Rig:Step(dt)
	const camera = self.Dependencies.CameraController
	const mode = untrack(camera.Mode)
	const now = os.clock()

	if self.Leaving then
		const done = mode ~= "Prep"
		-- the own rig comes back at 60 % of the way out
		if not self.RigReleased and (self.LeaveTravel <= 0 or now - self.LeavingSince >= self.LeaveTravel * RIG_RELEASE) then
			self.RigReleased = true
			self.Rig:Release()
		end
		if (done and self.Rig:Idle()) or now - self.LeavingSince > LEAVE_TIMEOUT then
			self:Finish(not done)
		elseif done and not self.RigReleased then
			self.RigReleased = true
			self.Rig:Release()
		end
		return
	end

	if mode ~= "Prep" then
		-- a cutscene or another owner took the camera: drop the mode without touching it
		self.Rig:Release()
		self:Finish(false)
		return
	end
	if untrack(self.Dependencies.VitalController.LocalState) ~= "Active" then
		self:Leave("State", true, true)
		return
	end

	const cursor = self.Cursor
	if cursor ~= nil then
		cursor:SetPad(untrack(self.Dependencies.InputController.Device) == "Gamepad")
	end
	const pointer = self.Pointer
	const viewport = workspace.CurrentCamera
	if pointer ~= nil and viewport ~= nil then
		pointer:SetOffset(rules.TouchOffset * Theme.ScaleOf(viewport.ViewportSize))
	end
	if not self.Mock and now >= self.NextBeat then
		self:SendTab()
	end
end

-- Startup ---------------------------------------------------------------------------------------------------------------

PrepController:OnInit(function(self)
	self:Setup()
	self:LoadStages()

	const net = self.Libs.Net
	const me = Players.LocalPlayer.UserId

	-- a seat of mine = the mode; the seat gone or given to someone else = out
	local function onSeat(id: number, record: any)
		if record.User == me then
			self:Enter(id, false)
		elseif untrack(self.Station) == id and self.InMode then
			self:Leave("Seat", false, true)
		end
	end
	net.PrepSeats:onAdded(onSeat)
	net.PrepSeats:onChanged(onSeat)
	net.PrepSeats:onRemoved(function(id)
		if untrack(self.Station) == id and self.InMode then
			self:Leave("Seat", false, true)
		end
	end)
	net.PrepResult:onClient(function(result)
		self:OnResult(result)
	end)
	-- the verdict of a Serve (Complete / Incomplete / Wrong, tip) comes with the Sale packet of the CustomerService
	net.Sale:onClient(function(sale)
		if self.InMode then
			self:Broadcast({ Kind = "Sale", Npc = sale.Npc, Result = sale.Result, Amount = sale.Amount })
		end
	end)

	-- dev: /dev prep ui [station] [tab] (the server sends it through the DevClient packet; text = "<station> <tab>")
	net.DevClient:onClient(function(data)
		if data.Command ~= "prep_ui" or not self.Dependencies.PlaceController:IsDev() then
			return
		end
		if self.InMode then
			self:Leave("Dev", false, true)
			return
		end
		const text: string = data.Text
		const station = math.clamp(tonumber(string.match(text, "%d+")) or 1, 1, prep.Stations)
		if not self:Enter(station, true) then
			warn("[PrepController] /dev prep ui: not now (the camera is not in first person or the player is not Active)")
			return
		end
		-- `/dev prep ui 1 Serve` opens straight on a tab (Serve with a finished plate); the mock world is Feed.luau's
		const tab = string.match(text, "%a+")
		if tab ~= nil then
			task.defer(function()
				if self.InMode and self.Mock then
					Feed.Preview(self, tab)
				end
			end)
		end
	end)
end)

PrepController:OnStart(function(self)
	-- the gate of the world prompts: all of them while in the mode, the kitchen ones always (WorldKitchenPrompts = false)
	self.Dependencies.PromptController:AddGate("Prep", function(anchor: Instance): boolean
		if self.InMode then
			return false
		end
		if not rules.WorldKitchenPrompts then
			const action = anchor:GetAttribute("PromptAction")
			if type(action) == "string" and KITCHEN_ACTIONS[action] then
				return false
			end
		end
		return true
	end)
	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function(dt: number)
		self:Update(dt)
	end)
end)

return PrepController
