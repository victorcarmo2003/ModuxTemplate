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
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Objective = require(StarterPlayer.StarterPlayerScripts.client.Interface.Objective)
local Zones = require(StarterPlayer.StarterPlayerScripts.client.Interface.Zones)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local PlateView = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateView)
local PrepShell = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PrepShell)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local TicketRail = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TicketRail)
local KitchenFx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local KitchenSlots = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Slots)
local Prefs = require(StarterPlayer.StarterPlayerScripts.client.Settings.Prefs)
local Cursor = require(script.Cursor)
local Feed = require(script.Feed)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local Session = require(script.Stages.Build.Session)
local Gestures = require(script.Gestures)
local Mock = require(script.Mock)
local Pan = require(script.Pan)
local Parts = require(script.Parts)
local Pointer = require(script.Pointer)
local Poses = require(script.Poses)
local Rig = require(script.Rig)
local Stage = require(script.Stage)
local World = require(script.World)
local BinZone = require(script.World.BinZone)
local Director3D = require(script.World.Director3D)
local FlipWatch = require(script.World.FlipWatch)
local Zones = require(StarterPlayer.StarterPlayerScripts.client.Interface.Zones)

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
-- the layer of the Hud ScreenGui that holds the order card (HudController:Layer("Order"))
const HUD_ORDER_LAYER = "Order"
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
	self.Tab = source(prep.Tabs.List[1].Key) :: Vide.Source<string>
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
	-- cosmetic plate mask of PrepTab.Plate (Prep/shared/PlateMask), written by the 3D Board / Toppings stage (TASK-204, 205)
	self.PlateMask = 0 :: number
	self.ToastId = 0 :: number
	self.Stages = {} :: { [string]: Stage.Stage }
	-- 3D stages (World/Stages/*.luau, Rules.ThreeD only): by tab, and once each in a list
	self.Stages3D = {} :: { [string]: Stage.Stage3D }
	self.List3D = {} :: { Stage.Stage3D }
	-- the NPC at the counter that the Window view must not cut (Rig:SetSpared), re-judged at 4 Hz
	self.SpareAt = 0 :: number
	-- the Ink veil of a blink (PrepController:Blink), nil when none
	self.Veil = nil :: ScreenGui?
	-- the pulsing marker over the Work prompts for a player who has not entered yet (P-3)
	self.Pointer = nil :: Pointer.Pointer?
	self.Gestures = nil :: Gestures.Recogniser?
	self.Cursor = nil :: Cursor.Cursor?
	self.Rig = Rig.new() :: Rig.Rig
	self.Pose = nil :: Poses.Pose?
	-- the pan along the stations (Pan.luau; Rules.ThreeD only): the trail of the seat, the pan, and the dot it lights while it moves
	-- (0 = the dot of the current tab)
	self.Trail = nil :: Poses.Trail?
	self.TrailStation = 0 :: number
	self.Pan = nil :: Pan.Pan?
	self.RoofBody = nil :: BasePart?
	self.PanDriving = false :: boolean
	self.PanNear = source(0) :: Vide.Source<number>
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
			-- a closed gift bowl reads as locked on the panels (it is opened in the world)
			const info = self:InfoOf(key)
			return { Stock = info.Stock, Locked = info.Locked or info.Wrapped, Used = info.Used }
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
-- Wrapped = a gift bowl still closed (owner request 2026-10-14): "Open" it in the world first
function PrepController:InfoOf(key: string): { Stock: number, Locked: boolean, Used: boolean, Wrapped: boolean }
	const used = self.View.Used()[key] == true
	if self.Mock then
		const row = Mock.Stock[key]
		return { Stock = if row ~= nil then row.Stock else 0, Locked = row ~= nil and row.Locked, Used = used, Wrapped = false }
	end
	const record = self.Dependencies.KitchenController:StockOf(key)
	return {
		Stock = if record ~= nil then record.Amount else 0,
		Locked = record ~= nil and record.Blocked,
		Used = used,
		Wrapped = record ~= nil and record.Wrapped == true,
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
		-- Rules.Delivery = "Prompt": the delivery is the customer's world prompt, the Serve stage stays unloaded (rollback: "Window")
		if rules.Delivery == "Prompt" and child.Name == "Serve" then
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
		-- the 2D stages are written for the legacy tabs (Order, Grill, Build, Serve), whichever set Rules.ThreeD picked
		if prep.TabsLegacy.ByKey[stage.Tab] == nil and prep.Tabs.ByKey[stage.Tab] == nil then
			warn(`[PrepController] Stages/{child.Name}: unknown tab '{stage.Tab}'`)
			continue
		end
		self.Stages[stage.Tab] = stage
	end
	for _, row in prep.Tabs.List do
		if self:StageOf(row.Key) == nil and self.Stages3D[row.Key] == nil then
			warn(`[PrepController] no stage for the tab '{row.Key}'`)
		end
	end
end

-- World/Stages/*.luau (docs/tech/prep-3d.md §11.3): the 3D stages, found like the 2D ones. A module serves one or more tabs of
-- Content.Prep.Tabs3D; it runs for a tab only when Stage.Armed (Rules.ThreeD and World.Stages.<tab>). Nothing loads while
-- Rules.ThreeD is false.
function PrepController:Load3DStages()
	if not rules.ThreeD then
		return
	end
	const folder = (script :: any).World:FindFirstChild("Stages")
	if folder == nil then
		return
	end
	for _, child in (folder :: Instance):GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		if rules.Delivery == "Prompt" and child.Name == "Serve" then
			continue
		end
		const ok, value = pcall(require, child)
		if not ok then
			warn(`[PrepController] World/Stages/{child.Name} failed to load: {value}`)
			continue
		end
		const problem = Stage.check3D(value, child.Name, prep.Tabs3D.ByKey)
		if problem ~= nil then
			warn(`[PrepController] World/Stages/{problem}`)
			continue
		end
		const stage = value :: Stage.Stage3D
		table.insert(self.List3D, stage)
		for _, tab in stage.Tabs do
			self.Stages3D[tab] = stage
		end
	end
end

-- The tab key of the current set for `tab` (a key of the other mode resolves through Content.Prep.TabAlias); nil = unknown.
function PrepController:ResolveTab(tab: string?): string?
	if tab == nil then
		return nil
	end
	if prep.Tabs.ByKey[tab] ~= nil then
		return tab
	end
	const alias = prep.TabAlias[tab]
	if alias ~= nil and prep.Tabs.ByKey[alias] ~= nil then
		return alias
	end
	return nil
end

-- The 2D stage of a tab (Stages/*.luau). In the 3D set Board and Toppings are served by the 2D Build stage (TabAlias) until
-- their 3D stage is armed.
function PrepController:StageOf(tab: string?): Stage.Stage?
	const key = tab or untrack(self.Tab)
	return self.Stages[key] or self.Stages[prep.TabAlias[key] or ""]
end

-- The 3D stage of a tab when it is armed (Rules.ThreeD + World.Stages.<tab> + the module exists), else nil.
function PrepController:Stage3DOf(tab: string?): Stage.Stage3D?
	const key = tab or untrack(self.Tab)
	const stage = self.Stages3D[key]
	if stage ~= nil and Stage.Armed(rules, key) then
		return stage
	end
	return nil
end

-- The tab draws in the world (the shell goes minimal); reactive when read inside a binding.
function PrepController:Armed(tab: string): boolean
	return self:Stage3DOf(tab) ~= nil
end

-- The section a tab teaches in the drag tutorial (Texts.Coach key).
function PrepController:CoachKeyOf(tab: string): string
	return if tab == "Build" then "Board" else tab
end

-- One line of hint / the corner button of a tab, from its 3D stage when armed, else from the 2D one.
function PrepController:HintOf(tab: string): string
	-- the drag tutorial speaks first while its hand is on screen (both sources are read: the binding depends on both)
	const coachLine, coachTab = World.CoachLine(), World.CoachTab()
	-- the sausage paw (rail -> bun) belongs to the Board section too (owner request 2026-10-14)
	const coachSection = if coachTab == "Sausage" then "Board"
		elseif coachTab == "Deliver" then "Toppings"
		elseif coachTab == "Pan" then self:CoachKeyOf(tab)
		else coachTab
	if coachLine ~= "" and coachSection == self:CoachKeyOf(tab) then
		return coachLine
	end
	const stage3D = self:Stage3DOf(tab)
	if stage3D ~= nil then
		return stage3D.Hint(self)
	end
	const stage = self:StageOf(tab)
	return if stage ~= nil then stage.Hint(self) else ""
end

function PrepController:NextOf(tab: string): Stage.Next
	const stage3D = self:Stage3DOf(tab)
	if stage3D ~= nil then
		return stage3D.Next(self)
	end
	const stage = self:StageOf(tab)
	return if stage ~= nil then stage.Next(self) else { Label = prep.Texts.Next, Enabled = false }
end

-- The stage of `tab` comes to the front / goes to the back (3D: Enter / Leave + the current step; 2D: OnEnter / OnLeave).
function PrepController:EnterStage(tab: string)
	const stage3D = self:Stage3DOf(tab)
	if stage3D ~= nil then
		stage3D.Enter(self, tab)
		stage3D.Step(self, untrack(self.Step))
		return
	end
	const stage = self:StageOf(tab)
	if stage ~= nil and stage.OnEnter ~= nil then
		stage.OnEnter(self)
	end
end

function PrepController:LeaveStage(tab: string)
	const stage3D = self:Stage3DOf(tab)
	if stage3D ~= nil then
		stage3D.Leave(self, tab)
		return
	end
	const stage = self:StageOf(tab)
	if stage ~= nil and stage.OnLeave ~= nil then
		stage.OnLeave(self)
	end
end

-- A World aim message (Hover, Press, Move, Release, Drop, Tap, Cancel; TASK-196) to the 3D stage in front.
function PrepController:OnAim(message: any)
	const stage3D = self:Stage3DOf(nil)
	if stage3D ~= nil and stage3D.OnAim ~= nil then
		stage3D.OnAim(self, message)
	end
end

-- Share of the plate done in a section, 0..1, for the progress card (Provisional, prep-3d.md §5: Grill = a sausage ready on the
-- rail, Board = cut + placed, Toppings = toppings made over the ones of the ticket, Serve = the plate is sealed). Reactive.
function PrepController:SectionProgress(tab: string): number
	if tab == "Grill" then
		return if (self.Badges().Grill or 0) > 0 then 1 else 0
	elseif tab == "Board" or tab == "Build" then
		const cut = if self.Needs().BunCut == true then 0.5 else 0
		const placed = if self.View.Sausage() ~= false then 0.5 else 0
		return cut + placed
	elseif tab == "Toppings" then
		const ticket = self.View.Ticket()
		const wanted = if ticket ~= false then #ticket.Toppings else 0
		return if wanted > 0 then math.clamp(#self.View.Toppings() / wanted, 0, 1) else 0
	elseif tab == "Serve" then
		return if self.View.Seal() ~= false then 1 else 0
	end
	return 0
end

-- 0..1 over the whole run: one division per tab of the set.
function PrepController:RunProgress(): number
	const tab = self.Tab()
	const list = prep.Tabs.List
	local index = 1
	for position, row in list do
		if row.Key == tab then
			index = position
		end
	end
	return ((index - 1) + self:SectionProgress(tab)) / #list
end

-- Public API of the stages ----------------------------------------------------------------------------------------------

-- A tab to the front (the bar, 1 to 4, LB / RB, a stage that moves on). Sends PrepTab (also the keep-alive).
function PrepController:SetTab(wanted: string)
	-- a key of the other mode (a 2D stage asking for Order or Build in the 3D set) resolves through TabAlias
	const tab = self:ResolveTab(wanted)
	if tab == nil or untrack(self.Tab) == tab then
		return
	end
	const previousTab = untrack(self.Tab)
	self:CancelGestures()
	self:LeaveStage(previousTab)
	const viewBefore = Poses.ViewOf(previousTab)
	self.Tab(tab)
	-- the camera glides when the view changes (2D: the grill and the board; 3D: one view per section, Poses.luau)
	if self.InMode and not self.Leaving and not self.Mock and not self.PanDriving and Poses.ViewOf(tab) ~= viewBefore then
		self:MoveTo(untrack(self.Station))
	end
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
	self:PanSync()
	self:EnterStage(tab)
	self:SendTab()
end

-- The same step in the other mode: the 2D `build` is the 3D `place` (a 2D stage asking for its own step in the 3D set)
const STEP_ALIAS: { [string]: string } = { build = "place", place = "build" }

-- A step of the plate (`grill`, `bun`, `build` / `place` + `toppings`, `serve`); brings its tab to the front.
function PrepController:SetStage(stepKey: string)
	const step = prep.Steps.ByKey[stepKey] or prep.Steps.ByKey[STEP_ALIAS[stepKey] or ""]
	if step == nil then
		return
	end
	self.Step(step.Key)
	const tabBefore = untrack(self.Tab)
	self:SetTab(step.Tab)
	-- same tab: a 3D stage hears the step change here (SetTab tells it when the tab changes)
	if tabBefore == step.Tab then
		const stage3D = self:Stage3DOf(step.Tab)
		if stage3D ~= nil then
			stage3D.Step(self, step.Key)
		end
	end
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
	self:Need("SausagePlaced", false)
	self.PlateMask = 0
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
	World.SetAssist(on)
end

-- What the stage in front receives: every gesture event, a "Pick" (tap on a topping box), a "Result" (PrepResult).
function PrepController:OnGesture(event: any)
	-- a 3D stage takes its input from the World (OnAim), not from the 2D gesture layer
	if self:Stage3DOf(nil) ~= nil then
		return
	end
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
	const tab = untrack(self.Tab)
	const stage3D = self:Stage3DOf(tab)
	const stage = self:StageOf(tab)
	if stage3D == nil and stage == nil then
		return
	end
	const state = self:NextOf(tab)
	if not state.Enabled then
		self:Toast(self:HintOf(tab), "Alert")
		return
	end
	if stage3D ~= nil then
		if stage3D.OnNext ~= nil then
			stage3D.OnNext(self)
		end
	elseif stage ~= nil and stage.OnNext ~= nil then
		stage.OnNext(self)
	end
end

-- The bin by drag. From = "Plate" (default): the plate goes (the server drops its bun and sausage on PrepTrash). "Grill" / "Rail": a
-- sausage of that roller / the front of the rail is thrown (Slot 1..8); the stage predicts it and listens to PrepResult Act = Trash
-- with Value 1 (grill) or 2 (rail).
function PrepController:Trash(from: string?, slot: number?)
	const origin = from or "Plate"
	if origin ~= "Plate" then
		if not self.Mock then
			self.Libs.Net.PrepTrash:fireServer({ From = origin, Slot = math.clamp(math.floor(slot or 1), 1, 8) })
		end
		return
	end
	const had = untrack(self.View.Bun) ~= "None"
	self:ResetPlate()
	self:SetStage("grill")
	if had then
		self:Toast(prep.Texts.Trashed, "Info")
		if not self.Mock then
			self.Libs.Net.PrepTrash:fireServer({ From = "Plate", Slot = 0 })
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
	for _, stage in self.List3D do
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
		Plate = self.PlateMask,
	})
end

function PrepController:OnResult(result: any)
	if result.Act == "Kick" then
		self:Leave("Kick", true, true)
		self:Notice(result.Reason)
		return
	end
	-- a sausage thrown by drag (Trash with a Value) is answered by its stage, with its own words
	const sausageTrash = result.Act == "Trash" and result.Value ~= 0
	if not result.Ok and not sausageTrash then
		self:Notice(result.Reason)
	end
	self:Broadcast({ Kind = "Result", Result = result })
	const stage3D = self:Stage3DOf(nil)
	if stage3D ~= nil then
		if stage3D.OnResult ~= nil then
			stage3D.OnResult(self, result)
		end
		return
	end
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
-- The roof of the trailer (the `Body` mesh) is above the camera of the overhead views (about 11 studs, the roof is at 9.7): it is
-- hidden LOCALLY while the mode is up (LocalTransparencyModifier, never Transparency) and given back on the way out. The walls go
-- with it: seen from above the room is a cutaway, the counters, floor and fixtures are their own parts and stay.
function PrepController:HideRoof(on: boolean)
	const previous = self.RoofBody
	if not on then
		if previous ~= nil and previous.Parent ~= nil then
			previous.LocalTransparencyModifier = 0
		end
		self.RoofBody = nil
		return
	end
	-- (the walls give the room its ambience: the Body stays visible, the camera of the views sits under the roof instead)
end

function PrepController:Isolate(on: boolean)
	const saved = self.Saved
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if on then
		if playerGui ~= nil then
			-- 3D (prep-3d.md §5, DT-23): the Hud (sanity, money, clock) stays on screen; only the order card (the ticket replaces
			-- it) goes. The 2D mode hides the whole Hud as before.
			for _, name in { "Hud", "TouchGui" } do
				const gui = playerGui:FindFirstChild(name)
				if gui ~= nil and gui:IsA("ScreenGui") then
					if name == "Hud" and rules.ThreeD then
						const card = gui:FindFirstChild(HUD_ORDER_LAYER)
						if card ~= nil and card:IsA("GuiObject") then
							saved.HudOrder = card.Visible
							card.Visible = false
						end
					else
						saved[name] = gui.Enabled
						gui.Enabled = false
					end
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
		const hud = playerGui:FindFirstChild("Hud")
		const card = if hud ~= nil then hud:FindFirstChild(HUD_ORDER_LAYER) else nil
		if card ~= nil and card:IsA("GuiObject") and saved.HudOrder ~= nil then
			card.Visible = saved.HudOrder :: boolean
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
	const tabs: { PrepShell.Tab } = {}
	for _, row in prep.Tabs.List do
		table.insert(tabs, { Key = row.Key, Label = row.Label, Icon = row.Icon })
	end
	-- the 2D stage of a tab (Build serves Board and Toppings in the 3D set until their 3D stage is armed)
	local function stageOr(tab: string): Stage.Stage?
		return self:StageOf(tab)
	end
	-- the plate sections: the grade pips, the bin and the cut / place gauges belong to them
	local function isPlateTab(tab: string): boolean
		return tab == "Build" or tab == "Board" or tab == "Toppings"
	end
	const unmount, gui = Vide.root(function(): ScreenGui
		-- the tutorial step lives in the progress card of the minimal shell while it is on screen (Objective): one card, not two
		Vide.effect(function()
			Objective.SetHosted(self.Active() and self.Shown() and self:Armed(self.Tab()))
		end)
		-- the world cooking bars of the slots would be a dark copy of what the 3D grill already shows
		Vide.effect(function()
			KitchenSlots.SetBarsHidden(self.Active())
		end)
		-- the 2D bin zone of the shell reads the state the world keeps (BinZone); the shell tells it where the zone is
		const binWanted = Vide.source(BinZone.Wanted())
		const binOver = Vide.source(BinZone.Over())
		const binChomp = Vide.source(BinZone.Chomp())
		const stopBin = BinZone.Subscribe(function()
			binWanted(BinZone.Wanted())
			binOver(BinZone.Over())
			binChomp(BinZone.Chomp())
		end)
		Vide.cleanup(function()
			stopBin()
			BinZone.Bind(nil, nil)
			Objective.SetHosted(false)
			KitchenSlots.SetBarsHidden(false)
		end)
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
				-- Settings "Prep helper" off (TASK-279): no step-by-step line (the blocked-Next toast still explains)
				Hint = function(): string
					if not Prefs.PrepAssist() then
						return ""
					end
					return self:HintOf(self.Tab())
				end,
				Pips = function(): { Pip }
					return if isPlateTab(self.Tab()) then self.View.Pips() else {}
				end,
				HasPanel = function(): boolean
					const tab = self.Tab()
					const stage = stageOr(tab)
					return not self:Armed(tab) and stage ~= nil and stage.HasPanel
				end,
				-- the minimal 3D mode (TASK-199): only for a tab whose 3D stage is armed; the others keep the 2D chrome
				Minimal = function(): boolean
					return self:Armed(self.Tab())
				end,
				-- the dots light the section the camera is nearest to while it pans
				Near = self.PanNear,
				-- a flip window is open while another tab is in front: the Grill dot pulses, a "Flip!" chip calls back (FlipWatch)
				Alert = FlipWatch.Alert,
				DotSize = rules.Camera.Pan.Dots.Size,
				DotActive = rules.Camera.Pan.Dots.Active,
				Progress = {
					Label = function(): string
						const row = prep.Tabs.ByKey[self.Tab()]
						return if row ~= nil then row.Label else ""
					end,
					Value = function(): number
						return self:RunProgress()
					end,
				},
				Seal = function(): PlateView.Grade?
					const value = self.View.Seal()
					return if value ~= false then value else nil
				end,
				SealLabel = function(grade: PlateView.Grade): string
					return prep.Grades.Labels[grade]
				end,
				-- the number that rolls 0 -> N under the seal: the mean of the stage scores of this plate (a preview)
				SealScore = function(): number
					return Session.Note()
				end,
				-- the live grade of the plate on the progress card, and the Perfects in a row
				Note = function(): PrepShell.Note?
					if Session.Counted() == 0 then
						return nil
					end
					const mean = Session.Note()
					return { Score = mean, Grade = Grade.Band(prep, mean) }
				end,
				Streak = World.Streak,
				Pad = function(): boolean
					return self.Dependencies.InputController.Device() == "Gamepad"
				end,
				Next = {
					Label = function(): string
						return self:NextOf(self.Tab()).Label
					end,
					Enabled = function(): boolean
						return self:NextOf(self.Tab()).Enabled
					end,
					Pulse = function(): boolean
						return self:NextOf(self.Tab()).Pulse == true
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
						return self.View.Bun() ~= "None" and self.View.Seal() == false and isPlateTab(self.Tab())
					end,
					Hold = TRASH_HOLD,
					HoldText = TRASH_TEXT,
					OnTrash = function()
						self:Trash()
					end,
				},
				Bin = {
					Wanted = binWanted,
					Over = binOver,
					Chomp = binChomp,
					Label = "Bin",
					Bind = BinZone.Bind,
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
							Roomy = function(): boolean
								return layout().Kind == "Desktop"
							end,
							-- No Take here (playtest 2026-10-14): an order is taken only by facing the customer (the tap on him in the
							-- Window view, World/Stages/Order, or the world prompt take_order), so the player looks at him (anomalies).
							OnCycle = function()
								self:CycleTicket()
							end,
						})
					end,
					Board = function(_layout: () -> any): any
						const map: { [string]: () -> any } = {}
						for _, row in prep.Tabs.List do
							const key = row.Key
							map[key] = function(): any
								-- a 3D stage draws in the world: the board slot of the minimal shell stays empty
								if self:Armed(key) then
									return create("Frame")({ Name = "World", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
								end
								const stage = stageOr(key)
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
				Objective = Objective.Card,
				OnSkip = Objective.Skip,
				Reserved = function(): { Zones.Zone }
					const list: { Zones.Zone } = {}
					for _, zone in Zones.All() do
						table.insert(list, zone)
					end
					return list
				end,
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
	FlipWatch.Reset()
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

-- Enters the station. `mock` = the dev preview (no seat, no packets). `plate` = the cosmetic mask of the seat record (nil / 0 =
-- the server holds no built plate for us). Returns whether it did.
function PrepController:Enter(station: number, mock: boolean?, tab: string?, plate: number?): boolean
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
		-- the server already seated (and froze) us: hand the seat back instead of staying stuck in place
		if not mock then
			warn(`[PrepController] cannot enter station {station}: camera {untrack(camera.Mode)}, state {untrack(vital.LocalState)}`)
			self.Libs.Net.PrepLeave:fireServer()
		end
		return false
	end
	-- the tab it opens on: the one of the prompt used (the seat record; a key of the other mode resolves through TabAlias), the
	-- first of the set (Order in 2D, Grill in 3D) when it is not known
	const startTab = self:ResolveTab(tab) or prep.Tabs.List[1].Key
	local pose = Poses.Of(station, Poses.ViewOf(startTab))
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
	camera:Prep(true, pose.Frame, self:CameraOptions(pose, dof, reduced))
	if untrack(camera.Mode) ~= "Prep" then
		if not mock then
			self.Libs.Net.PrepLeave:fireServer()
		end
		return false
	end

	self.InMode = true
	self.Mock = mock == true
	self.Leaving = false
	self.RigReleased = false
	self.Forced = false
	self.Pose = pose
	self.TrailStation = 0
	self:BuildTrail(station)
	self.Vignette(not dof)
	self.Shown(false)
	self.Tab(startTab)
	self.Step(self:FirstStepOf(startTab))
	self.Needs({})
	self.Assist(false)
	self.Toasts(false)
	self:ResetPlate()
	self:LoadPreview()
	-- TASK-260: the plate left on the board last time comes back (the server kept it parked). TASK-283: only when the seat record
	-- still carries it; a plate the server dropped meanwhile (shop closed) must not come back as a picture the server lacks
	if not self.Mock then
		Session.Unpark(self, plate ~= nil and plate ~= 0)
	end
	self.Station(station)
	self.Active(true)

	self:HideRoof(true)
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
	self:BuildPan(pointer)
	-- a stage that errors while the UI is built must never leave the player seated and frozen without a UI: give the seat
	-- back and warn (the Output has the cause)
	const viewFrame, viewFov, viewDistance = pose.Frame, pose.Fov, (pose.Frame.Position - pose.Focus).Magnitude
	const mounted, mountError = pcall(function()
		self:Mount()
		-- the 3D layer (raycast, targets, marker; inert while Rules.ThreeD is false, `/dev prep ray` aside) and the stage in front
		-- listens to its aim messages
		World.SetListener(function(message: any)
			self:OnAim(message)
		end)
		World.SetAssist(untrack(self.Assist))
		World.SetAudio(function(key: string, at: Vector3?, speed: number?)
			if Content.Sounds.ByKey[key] == nil then
				return
			end
			pcall(function()
				((self.Dependencies.KitchenController :: any).Dependencies.AudioController):Play(key, at, if speed ~= nil then { Speed = speed } else nil)
			end)
		end)
		World.SetView(viewFrame, viewFov, viewDistance)
		KitchenFx.SetNear(true)
		World.Enter(station, pointer)
		-- the 2D Order stage starts the Feed (the shared picture of the line and the grill), whatever tab opens first; it is not a
		-- tab of the 3D set, but its module stays loaded for that
		const order = self.Stages.Order
		if order ~= nil and order.OnEnter ~= nil then
			order.OnEnter(self)
		end
		if startTab ~= "Order" then
			self:EnterStage(startTab)
		end
	end)
	if not mounted then
		warn(`[PrepController] the UI of station {station} failed to mount, leaving the mode: {mountError}`)
		self:Unmounted()
		self:Leave("MountFailed", false, false)
		return false
	end
	self.NextBeat = os.clock() + rules.Heartbeat
	task.delay(if reduced then 0 else CHROME_DELAY, function()
		if self.InMode and not self.Leaving then
			self.Shown(true)
		end
	end)
	return true
end

-- What the camera glides to for a pose: the point looked at, the field of view and the depth of field of THAT view (the focus
-- distance and the radius follow the distance to the plate, they are not one number for every view). The glide lasts between
-- Rules.Camera.Min and Max by distance; reduced motion cuts.
function PrepController:CameraOptions(pose: Poses.Pose, dof: boolean, reduced: boolean): any
	const focus = (pose.Frame.Position - pose.Focus).Magnitude
	return {
		Fov = pose.Fov,
		Travel = if reduced then 0 else rules.Camera.Max,
		Min = rules.Camera.Min,
		Look = pose.Focus,
		Dof = dof,
		Focus = focus,
		Radius = math.max(0.4, focus * 0.28),
		Far = 0.7,
	}
end

-- A cut with a blink (reduced motion, forced exits): an Ink veil comes over the screen in Rules.Camera.Fade s, `cut` runs behind it,
-- the veil goes in the same time. Never two at once.
function PrepController:Blink(cut: () -> ())
	if self.Veil ~= nil then
		cut()
		return
	end
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		cut()
		return
	end
	const gui = Instance.new("ScreenGui")
	gui.Name = "PrepVeil"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	const veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Theme.Color.Ink
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui
	gui.Parent = playerGui
	self.Veil = gui
	const fade = rules.Camera.Fade
	const info = TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	const inTween = TweenService:Create(veil, info, { BackgroundTransparency = 0 })
	inTween.Completed:Once(function()
		cut()
		const outTween = TweenService:Create(veil, info, { BackgroundTransparency = 1 })
		outTween.Completed:Once(function()
			gui:Destroy()
			if self.Veil == gui then
				self.Veil = nil
			end
		end)
		outTween:Play()
	end)
	inTween:Play()
end

-- The pan trail of a seat (Poses.Trail), rebuilt when the seat changes; nil in the 2D mode (no pan).
function PrepController:BuildTrail(station: number)
	if self.TrailStation == station and self.Trail ~= nil then
		return
	end
	self.TrailStation = station
	self.Trail = if rules.ThreeD then Poses.Trail(station) else nil
end

-- The index of the trail stop a tab stands on (1 when there is no trail).
function PrepController:StopOf(tab: string?): number
	const trail = self.Trail
	if trail == nil then
		return 1
	end
	const view = Poses.ViewOf(tab or untrack(self.Tab))
	for index, stop in trail.Stops do
		if stop.View == view then
			return index
		end
	end
	return 1
end

-- The camera went to the stop of the front tab on its own (a tab, LB / RB, a station change): the pan follows.
function PrepController:PanSync()
	const pan = self.Pan
	-- a tab change that the pan itself asked for (the camera is already where the hand put it) must not pull `u` to the station
	if pan ~= nil and not self.PanDriving then
		pan:Sync(self:StopOf(nil))
	end
end

-- The pan settled on stop `index`: that is the only moment the stage changes (Enter / Leave of the stages, the step and PrepTab
-- follow SetTab); on the stop it already stood on, the camera just glides back onto it.
function PrepController:PanCommit(index: number, live: boolean)
	const trail = self.Trail
	const stop = if trail ~= nil then trail.Stops[index] else nil
	if stop == nil or not self.InMode or self.Leaving then
		return
	end
	if stop.Tab == untrack(self.Tab) then
		if not live then
			self:MoveTo(untrack(self.Station))
		end
		return
	end
	-- live: the active station changes while the camera keeps moving with the hand (no glide, `u` untouched)
	-- (pcall: a stage that errors in Enter must never leave the flag up, or every later tab change would skip its camera glide)
	self.PanDriving = live
	const ok, problem = pcall(self.SetTab, self, stop.Tab)
	self.PanDriving = false
	if not ok then
		warn(`[PrepController] pan: tab change to {stop.Tab} failed: {problem}`)
	end
	if live then
		self.Pose = stop.Pose
	end
end

-- The pan of the seat, wired to the pointer, the camera and the guards of the precision gestures. Called once per Enter.
function PrepController:BuildPan(pointer: Pointer.Pointer)
	if self.Pan ~= nil then
		self.Pan:Destroy()
		self.Pan = nil
	end
	if not rules.ThreeD or self.Trail == nil then
		return
	end
	const camera = self.Dependencies.CameraController
	const panRules = rules.Camera.Pan
	const pan = Pan.new({
		Pointer = pointer,
		Rules = panRules,
		Trail = function(): Poses.Trail?
			return self.Trail
		end,
		Stop = function(): number
			return self:StopOf(nil)
		end,
		Goal = function(eye: Vector3, look: Vector3, fov: number)
			const focus = (eye - look).Magnitude
			-- omega 0 = a cut: the drag is 1:1 with the pointer, the smoothness is in `u` (inertia, edge ramp)
			camera:PrepGoal(eye, look, fov, 0, focus, math.max(0.4, focus * 0.28))
		end,
		Commit = function(index: number, live: boolean)
			self:PanCommit(index, live)
		end,
		Near = function(index: number?)
			-- the stop index of the trail -> the index of its tab in the bar (the dots are drawn per tab)
			const trail = self.Trail
			const stop = if trail ~= nil and index ~= nil then trail.Stops[index] else nil
			local lit = 0
			if stop ~= nil then
				for position, row in prep.Tabs.List do
					if row.Key == stop.Tab then
						lit = position
						break
					end
				end
			end
			self.PanNear(lit)
		end,
		Gate = function(): boolean
			return self.InMode and not self.Leaving and not self.Mock and untrack(self.Shown)
		end,
		Armed = function(): boolean
			return Director3D.IsArmed()
		end,
		Precision = function(): boolean
			return Director3D.IsPrecisionActive()
		end,
		Holding = function(): boolean
			const aim = World.Aim()
			return aim ~= nil and aim.Source ~= nil
		end,
		Reserved = function(): { Pan.Zone }
			const list: { Pan.Zone } = {}
			for _, zone in Zones.All() do
				table.insert(list, zone)
			end
			return list
		end,
		Reduced = Motion.Reduced,
	})
	self.Pan = pan
	pan:Sync(self:StopOf(nil))
end

-- Another station while seated (the server moved the seat): new pose, same session.
function PrepController:MoveTo(station: number)
	const pose = Poses.Of(station, Poses.ViewOf(untrack(self.Tab)))
	if pose == nil then
		return
	end
	self:BuildTrail(station)
	self:PanSync()
	const camera = self.Dependencies.CameraController
	const reduced = Motion.Reduced()
	const options = self:CameraOptions(pose, untrack(self.Vignette) == false, reduced)
	if reduced then
		-- a cut is a blink, not a jump: the screen dips to Ink for 0.15 s around it
		self:Blink(function()
			camera:Prep(true, pose.Frame, options)
		end)
	else
		camera:Prep(true, pose.Frame, options)
	end
	self.Pose = pose
	World.SetView(pose.Frame, pose.Fov, (pose.Frame.Position - pose.Focus).Magnitude)
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
	if travel <= 0 then
		-- no glide (reduced motion): the cut hides behind a 0.15 s blink instead of jumping
		self:Blink(function()
			camera:Prep(false, nil, { Travel = 0 })
		end)
	else
		camera:Prep(false, nil, { Travel = travel })
	end
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
	-- the 3D stage in front lets go of the world, then the world itself (pools, folder, listener)
	const frontStage = self:Stage3DOf(untrack(self.Tab))
	if frontStage ~= nil then
		const ok, problem = pcall(frontStage.Leave, self, untrack(self.Tab))
		if not ok then
			warn(`[PrepController] 3D stage Leave failed: {problem}`)
		end
	end
	if self.Veil ~= nil then
		self.Veil:Destroy()
		self.Veil = nil
	end
	World.SetListener(nil)
	World.SetAudio(nil)
	KitchenFx.SetNear(false)
	World.Leave()
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
	self:HideRoof(false)
	if self.Pan ~= nil then
		self.Pan:Destroy()
		self.Pan = nil
	end
	self.Trail = nil
	self.TrailStation = 0
	self.PanNear(0)
	self:Bind(false)
	self:Unmounted()
	self:Isolate(false)
	self.Shown(false)
	self.Active(false)
	self.Station(0)
	self.Toasts(false)
	-- TASK-260: an open plate stays on the board (server parks it): keep its picture for the next Enter
	Session.Park(self)
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

-- The first step of a tab in Content.Prep.Steps ("grill" when it has none, like the 2D Order tab).
function PrepController:FirstStepOf(tab: string): string
	for _, row in prep.Steps.List do
		if row.Tab == tab then
			return row.Key
		end
	end
	return "grill"
end

-- The customer at the counter (the Take target) is not cut or ghosted by the Rig in the Window view, nor the one waiting for the
-- plate in the Toppings view (the delivery by drag); with any other view he comes back to the cut / ghost zones (prep-3d.md
-- §4.4). Re-judged at 4 Hz.
function PrepController:SpareCustomer(now: number)
	if now < self.SpareAt then
		return
	end
	self.SpareAt = now + 0.25
	local npc: number? = nil
	const view = if rules.ThreeD and not self.Leaving then Poses.ViewOf(untrack(self.Tab)) else ""
	if view == "Window" then
		for _, id in untrack(Feed.Ids) do
			const card = untrack(Feed.CardOf(id))
			if card.Status == "Ready" and card.Place == "Counter" then
				npc = id
				break
			end
		end
	elseif view == "Toppings" then
		-- the customer waiting for the plate stays whole in the Toppings view too: it is the drop target of the delivery by drag
		-- (World/Stages/Build, owner request 2026-10-14)
		const pinned = untrack(Feed.Pinned)
		for _, id in untrack(Feed.Ids) do
			const card = untrack(Feed.CardOf(id))
			if card.Status == "Taken" and card.Place == "Counter" and (npc == nil or id == pinned) then
				npc = id
			end
		end
	end
	self.Rig:SetSpared(npc)
end

-- Per frame -------------------------------------------------------------------------------------------------------------

-- TASK-262 (owner request 2026-10-14): the first time the mode opens in the session, before any hot dog, the paw drags left and
-- right across the view (Coach "Pan"): the sections are reached by dragging sideways. Once per session (module state); it goes
-- at the first press like every hand of the Coach, and the grill hand waits for it.
local panTaught = false
-- TASK-266 (owner request 2026-10-14): off again, it showed up over the tutorial's bun-cut step and confused it (true = back)
const TEACH_PAN = false

function PrepController:TeachPan()
	if not TEACH_PAN or panTaught or self.Pan == nil or self.Leaving or not rules.ThreeD then
		return
	end
	const coach = World.Coach()
	const camera = workspace.CurrentCamera
	if coach:Active() or camera == nil then
		return
	end
	panTaught = true
	const frame = camera.CFrame
	const flatRight = Vector3.new(frame.RightVector.X, 0, frame.RightVector.Z)
	const right = if flatRight.Magnitude > 1e-3 then flatRight.Unit else Vector3.xAxis
	-- a point in front of the camera, down on the counter, swept from left to right
	const centre = frame.Position + frame.LookVector * 2.4 - Vector3.yAxis * 0.6
	coach:Show("Pan", { centre - right * 1.1, centre + right * 1.1 })
end

function PrepController:Update(dt: number)
	if not self.InMode then
		return
	end
	self.Rig:Step(dt)
	self:SpareCustomer(os.clock())
	if self.Pan ~= nil then
		self.Pan:Step(dt)
	end
	if not panTaught and untrack(self.Shown) then
		self:TeachPan()
	end
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
	FlipWatch.Step(self, function(key: string, speed: number)
		if Content.Sounds.ByKey[key] == nil then
			return
		end
		pcall(function()
			((self.Dependencies.KitchenController :: any).Dependencies.AudioController):Play(key, nil, { Speed = speed })
		end)
	end)
end

-- Startup ---------------------------------------------------------------------------------------------------------------

PrepController:OnInit(function(self)
	self:Setup()
	self:Load3DStages()
	self:LoadStages()

	const net = self.Libs.Net
	const me = Players.LocalPlayer.UserId

	-- a seat of mine = the mode; the seat gone or given to someone else = out
	local function onSeat(id: number, record: any)
		if record.User == me then
			self:Enter(id, false, record.Step, record.Plate)
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
