--!strict
--[[
	LobbyController (user request 2026-10-11, Provisional; architecture.md §20; network.md §15, §16)

	The lobby UI. Only on lobby servers: ReplicatedStorage attribute "ServerRole" = "Lobby" / "PrivateLobby" (read by
	PlaceController:GetServerRole(), which waits for it; missing = "Game"), or Workspace "ServerRole" = "Lobby" as a
	Studio override. Elsewhere nothing is bound or mounted.

	Layout (user request 2026-10-15, TASK-295): the tiles column on the LEFT, centred vertically (2 x 2 grid on short
	screens; clear of the Roblox top-bar buttons), the gem pill alone on the RIGHT, centred vertically; the squad status
	card and the Play button at the bottom centre, only while the player is in a squad (TASK-296: PlayShown; before
	that the pads, the Squad tile and P are the way in). The Roblox player list is on in the lobby (owner 2026-10-21:
	leaderstats Nights and Gems). The windows are
	centred full-screen modals over a dim backdrop and hide the HUD, so nothing sits over another screen: opening one
	closes the previous (one Panel), the Roblox menu (Esc) closes it too, and a window shrinks to fit a narrow screen.
	Toasts and the invite popup share one column at the top centre.

	Screens (Interface/Components; one open at a time, input context "Menu" while open):
	  LobbyHud      gem balance (opens the shop), tiles Classes · Shop · Codes · Squad, a status card (Solo / Squad
	                n/4, members, Friends only) over the big Play button (START for the leader, a waiting state for the
	                others, CANCEL during the countdown; DEC-344)
	  ClassSelect   every class (Content.Classes): list, card with perks / drawbacks, Buy with Gems / Buy with Robux /
	                Equip. The rig stands in the middle: on the MapPoint LOBBY-CLASS-STAGE with the camera locked in
	                front of it when the map has one (Stage.luau, CameraController External), else in a ClassStage
	                viewport. Slow swing, pop on swap, crew_idle when its id exists
	  GemShop       Content.Shop.GemPacks; the button calls MarketplaceService:PromptProductPurchase (ShopService
	                credits the gems on the receipt; the Profile packet brings the new balance)
	  CodeRedeem    CodeRedeem packet -> CodeRedeemResult (ok / invalid / expired / already used)
	  SquadPanel    the Party set (my squad = the record whose Members has my UserId), invite the players of this
	                server, kick (leader), Start (leader), Leave; InvitePopup for PartyInviteReceived
	  PlayChoice    what Play opens outside a squad: Play Solo · Create Squad (PartyQuickPlay)
	Feedback toasts (top right) for ClassBuyResult, CodeRedeemResult and PartyNotice; texts in Text.luau.

	Client presents, server decides: gems, owned classes and the selection come from the Profile packet
	(ProfileController); a class is bought with ClassBuy (Gems: the server debits; Robux: the server pre-checks and
	answers "Prompt", then this client prompts the Game Pass Content.Shop.GamePasses[key].PassId (TASK-291) and
	ShopService grants on PromptGamePassPurchaseFinished); Equip is the existing ClassAction "Select". Squad state is only what the Party set says.

	Play (user request 2026-10-11, Provisional; network.md §16.7): outside a squad it opens PlayChoice:
	  Play Solo     PartyQuickPlay { Mode = "Solo" }: the server creates a squad of one and starts it at once (normal
	                countdown, then the teleport; Studio answers StudioNoTeleport and drops the squad). The choice
	                closes; the HUD shows "Starting in n..." over the Play button.
	  Create Squad  PartyQuickPlay { Mode = "Squad" }: a friends-only invite squad (no platform); as soon as it arrives
	                the setup window (SquadSetup) opens with Max players, Who can join, Invite players (-> SquadPanel)
	                and Leave. No need to walk to a platform; stepping on a free one takes the squad there.
	Simple pad (DEC-344, TASK-619): in a squad, the leader's Play is START (PartyStart at once, even alone) with a round
	gear beside it that opens the setup window (who can join, max players); the others see a waiting state. No SET UP
	ROOM, no READY, no Leave on the pad: stepping off is leaving.

	Zones (user request 2026-10-11, Provisional; Content.Lobby, shared.Lobby.LobbyZones): every lobby zone is a floor
	Part of the map tagged "LobbyZone" (attribute Zone = Classes / Shop / Codes / Squad1..4; circle on a disc, oriented
	rectangle otherwise; Content position as fallback). Walking in opens its panel,
	walking out closes it (only if that panel is still the open one); checked every Trigger.Poll s from the own
	HumanoidRootPart, with hysteresis. The HUD tiles and keys stay as shortcuts. A panel closed by hand stays closed
	until the player walks out and in again. Squad pads open nothing (DEC-344): the room exists at once and START is
	on the HUD.
	  SquadSetup    the setup window (Panel "Platform", behind the gear): my squad (platform or invite), else the squad
	                on the platform the player stands on; Who can join, Max players, Start (leader) or the countdown;
	                invite squads add Invite players and Leave. Joining / leaving a platform is the server's
	                (PartyService watches the platforms); this client sends PartyConfigure / PartyStart / PartyCancel /
	                PartyLeave. Closes by itself when there is no squad left to show.
	Pad signs (Pads.luau + Interface/Components/PadTag, user request 2026-10-12): over every squad pad a studs-sized
	sign: a big count pill (FREE / SETUP / "n/max" / FULL, green free and open, mustard configuring, Slate closed, Teal
	breathing while starting), a round run seal under it (Content.Lobby.Squad.Pad.Badge, "D1" Provisional) and the
	leader's name; all read from the Party set (Platform, Members, MaxPlayers, StartAt). The pill pops when someone
	steps on / off (+ ui click, ring shiver). The players standing in a pad room do not see its sign (owner request
	2026-10-21): the HUD queue strip (faces + EXIT, top centre, instead of the online pill) and the state line over
	START NOW say it for them; EXIT sends PartyLeave and the server lifts them out of the pad barrier (DEC-348).
	Zone signs (Signs.luau + Interface/Components/ZoneSign, owner request 2026-10-20): over every non-squad zone a
	studs-sized floating sign, icon disc + name (CLASSES / GEMS / CODES), tones of the HUD tiles; hidden while its panel
	is open.
	Zone VFX (Rings.luau): local Neon frames on the floor edges (square / ring) with rising ghost frames, one Heartbeat
	for every zone; pad rings follow the room state (colour, breath speed, floor glow discs, sparks while occupied).
	Floor guide (Guide.luau, owner request 2026-10-20, Provisional): Mustard chevrons on the floor from the player to
	the nearest free squad pad (no room on it: owner 2026-10-21; none free = no guide) until the player steps on one or joins a squad; once the gems buy a class
	not owned yet, to the Classes zone instead, until the class screen opens. Each one only once per account: done goes
	to the server (LobbyGuideDone) and comes back in the Profile packet (Guides); the pad one is done for anyone who
	already started a run. Hidden while a screen is open. Idle nudge (owner 2026-10-21): every visit, GUIDE_IDLE s after
	the loading screen is gone while still outside a room, the guide points at a free pad again (the clock starts over
	after every room).
	Camera: normal third person in the lobby (CameraController External; CameraMode Classic). While the class screen
	shows the world stage every character is hidden locally (LocalTransparencyModifier; LOBBY.md §11).

	Binds (InputController; touch = the HUD tiles and buttons, >= 44 px):
	  Classes C / ButtonY · Shop B / DPadUp · Codes K / DPadLeft · Squad P / DPadRight · Play Return / DPadDown (only
	  while the Play button shows)
	  Close (Menu) ButtonB · previous / next class (Menu) Left / Right, ButtonL1 / ButtonR1
	  Play choice (Menu) Play Solo 1 · Create Squad 2 (gamepad: the selection starts on Play Solo, A picks)
	The Classes bind has a higher priority than ClassController's Crew toggle (C / ButtonY), so in the lobby these keys
	open this screen.
]]
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Backdrop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Backdrop)
local ClassSelect = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect)
local SkinIcons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.SkinIcons)
local ClassEntries = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.Entries)
local ClassStage = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassStage)
local CodeRedeem = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CodeRedeem)
local GemShop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GemShop)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InvitePopup)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.LobbyHud)
local PlayChoice = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlayChoice)
local SquadPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadPanel)
local SquadSetup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadSetup)
local PadTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PadTag)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Pads = require(script.Pads)
local Signs = require(script.Signs)
local Rings = require(script.Rings)
local Extras = require(script.Extras)
local Guide = require(script.Guide)
local Halloween = require(script.Halloween)
local Lanterns = require(script.Lanterns)
local Stage = require(script.Stage)
local Text = require(script.Text)
local Traffic = require(script.Traffic)

export type Panel = "None" | "Classes" | "Shop" | "Codes" | "Squad" | "Platform" | "Play"

export type PartyRecord = {
	Leader: number,
	Members: { number },
	State: "Forming" | "Configuring" | "Starting",
	Platform: number,
	Access: string, -- PartyRules.Access
	MaxPlayers: number,
	StartAt: number,
	Skip: { [number]: boolean }, -- members who skip the run's tutorial (pad bar)
}

export type Invite = {
	PartyId: number,
	From: number,
	Name: string,
	At: number,
}

const STAGE_POINT = "LOBBY-CLASS-STAGE"
const OUTFIT = "crew"
-- uniform circle of the skin row: the crew cap red and the shirt cream (T_Crew_Uniform_Day)
const UNIFORM_SWATCH = { Color3.fromRGB(205, 30, 45), Color3.fromRGB(255, 241, 214) }
const IDLE = "crew_idle"
const CLICK_SOUND = "ui_click"
const PENDING_TIMEOUT = 4 -- s without an answer: the class buttons come back
const PLAY_TIMEOUT = 6 -- s waiting for the squad of a quick play (Play Solo / Create Squad)
const SENT_TIME = 6 -- s an "Invite" button stays "Sent"
-- UI scale: 1 on the smallest landscape phone, grows up to 2 (same rule as the Crew screen)
const BASE_WIDTH = 660
const BASE_HEIGHT = 340
const MAX_SCALE = 2

const PANEL_BINDS: { { Name: string, Panel: Panel, Key: Enum.KeyCode, Pad: Enum.KeyCode, PadText: string } } = {
	{ Name = "LobbyClasses", Panel = "Classes", Key = Enum.KeyCode.C, Pad = Enum.KeyCode.ButtonY, PadText = "Y" },
	{ Name = "LobbyShop", Panel = "Shop", Key = Enum.KeyCode.B, Pad = Enum.KeyCode.DPadUp, PadText = "Up" },
	{ Name = "LobbyCodes", Panel = "Codes", Key = Enum.KeyCode.K, Pad = Enum.KeyCode.DPadLeft, PadText = "Left" },
	{ Name = "LobbySquad", Panel = "Squad", Key = Enum.KeyCode.P, Pad = Enum.KeyCode.DPadRight, PadText = "Right" },
}
const PLAY = "LobbyPlay"
const PLAY_CHOICES: { { Name: string, Key: Enum.KeyCode, Choice: PlayChoice.Choice } } = {
	{ Name = "LobbyPlaySolo", Key = Enum.KeyCode.One, Choice = "Solo" },
	{ Name = "LobbyPlaySquad", Key = Enum.KeyCode.Two, Choice = "Squad" },
}
const CANCEL = "LobbyCancel"
const CANCEL_MARGIN = 0.1 -- s: the button goes away this much before the server window closes (clock tick, latency)
const CLOSE = "LobbyClose"
const PREVIOUS = "LobbyPrevious"
const NEXT = "LobbyNext"
-- Notices column (invite popup + toasts), top centre: px from the top; on a narrow screen under the HUD column
-- (real px, same rule as the LobbyHud online pill: TOP / TOPBAR_FREE); the column starts under that pill (TASK-312)
const NOTICE_TOP = 8
const NOTICE_TOP_NARROW = 64 -- under the Roblox top bar (the HUD sides are centred, the top is free)
const NARROW_VIEWPORT = 420
const ONLINE_SPACE = 34 -- px (x the notice scale) the LobbyHud online pill takes, gap included (28 + 6)
const QUEUE_SPACE = 56 -- px (x the notice scale) the LobbyHud queue strip takes in a pad room, gap included (48 + 8)
const BIND_PRIORITY = 10 -- over ClassController's Crew toggle (priority 0) on C / ButtonY

-- First button a gamepad selects when a panel opens (by instance name, searched in the panel).
const FIRST_SELECTION: { [Panel]: { string } } = {
	None = { "Play", "Squad" }, -- the Play / START button (TASK-306: before the gear); no squad yet: the Squad tile
	Classes = {}, -- the focused class row (its name is the class key)
	Shop = { "Buy" },
	Codes = { "Redeem" },
	Squad = { "Start", "Create", "Invite" },
	Platform = { "Start", "Toggle", "Leave" },
	Play = { "Solo", "Squad" },
}

-- MetricUi event of each window opening (MetricsService/Lobby.luau funnels; owner request 2026-10-17)
const PANEL_METRIC: { [Panel]: string } = {
	Shop = "lobby_shop_open",
	Classes = "lobby_classes_open",
	Codes = "lobby_codes_open",
	Squad = "lobby_squad_open",
	Play = "lobby_play_open",
}

-- Root instance of each panel (component Name), where SelectFirst looks.
const PANEL_ROOT: { [Panel]: string } = {
	None = "LobbyHud",
	Classes = "ClassSelect",
	Shop = "GemShop",
	Codes = "CodeRedeem",
	Squad = "SquadPanel",
	Platform = "SquadSetup",
	Play = "PlayChoice",
}

const LOBBY = Content.Lobby
const HIDE_STEP = "LobbyController.HideCharacters"
const HIDE_PRIORITY = Enum.RenderPriority.Camera.Value + 2 -- after the stock camera and CameraController
const CLOCK_INTERVAL = 0.1 -- s between two countdown clock ticks
const GUIDE_IDLE = 20 -- s in the lobby (after the loading screen) outside a room before the guide points at a free pad
const LOADING_GUI = "LoadingScreen" -- Loading/boot ScreenGui: gone once the loading lifted
const PAD_SOUND_RANGE = 24 -- studs past a pad edge where somebody stepping on / off it still clicks

local function isLobby(placeRole: Roles.Role): boolean
	if Roles.IsLobby(placeRole) then
		return true
	end
	return workspace:GetAttribute(Roles.Attribute) == "Lobby"
end

-- Visible itself and every GuiObject above it (a hidden parent hides the button).
local function shown(object: GuiObject): boolean
	local current: Instance? = object
	while current and current:IsA("GuiObject") do
		if not current.Visible then
			return false
		end
		current = current.Parent
	end
	return true
end

local function nameOf(userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "Player"
end

const LobbyController = Modux.Controller("LobbyController", {
	Require = {
		"PlaceController",
		"PurchaseFxController",
		"ProfileController",
		"InputController",
		"AudioController",
		"AnimController",
		"CameraController",
		"GiftController",
		"SkinController",
	},
	Priority = 440,
})

function LobbyController:Setup()
	self.Active = false :: boolean
	self.Panel = Vide.source("None" :: Panel) :: Vide.Source<Panel>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	-- camera viewport px (the invite / toast column steps under the HUD column on a narrow screen)
	self.Viewport = Vide.source(Vector2.new(1280, 720)) :: Vide.Source<Vector2>
	self.Toasts = Vide.source({}) :: Vide.Source<{ ToastStack.Entry }>
	-- players online in the whole game (`Online` set, TASK-312); 0 = not known yet (no pill)
	self.Online = Vide.source(0) :: Vide.Source<number>

	-- classes
	self.Entries = ClassEntries.Build() :: { ClassEntries.Entry }
	self.Focus = Vide.source("class_dog") :: Vide.Source<string>
	-- skin previewed on the stage (Content.Skins key; "" = the crew uniform; owner request 2026-10-17)
	self.SkinFocus = Vide.source("") :: Vide.Source<string>
	-- class key of the request on its way
	self.Pending = Vide.source("") :: Vide.Source<string>
	self.PendingThread = nil :: thread?
	self.WorldStage = Vide.source(false) :: Vide.Source<boolean>
	self.Stage = nil :: Stage.Stage?
	self.StagePoint = nil :: CFrame?
	self.RigWarned = false :: boolean
	self.CameraBefore = nil :: string?
	self.FovBefore = 70 :: number

	-- shop
	-- ProductId -> live Robux price
	self.Prices = Vide.source({}) :: Vide.Source<{ [number]: number }>
	self.Prompting = Vide.source(false) :: Vide.Source<boolean>
	-- class key of an open class product prompt
	self.PromptClass = "" :: string

	-- codes
	self.CodeFeedback = Vide.source({ Text = "", Kind = "None" } :: CodeRedeem.Feedback) :: Vide.Source<CodeRedeem.Feedback>

	-- squad
	self.Parties = Vide.source({}) :: Vide.Source<{ [number]: PartyRecord }>
	self.Roster = Vide.source({}) :: Vide.Source<{ Player }>
	self.Sent = Vide.source({}) :: Vide.Source<{ [number]: boolean }>
	self.Invites = Vide.source({}) :: Vide.Source<{ Invite }>
	-- a quick play (PartyQuickPlay) waiting for its squad
	self.QuickPending = Vide.source(false) :: Vide.Source<boolean>
	self.QuickMode = "Solo" :: PlayChoice.Choice
	-- os.clock() of the quick play on its way; 0 = none
	self.QuickAt = 0 :: number

	-- zones
	-- zone key -> the own root is inside (hysteresis)
	self.ZoneInside = {} :: { [string]: boolean }
	-- squad platform the own root stands on; 0 = none
	self.Standing = Vide.source(0) :: Vide.Source<number>
	-- server time, ticked every CLOCK_INTERVAL s (countdowns)
	self.Clock = Vide.source(0) :: Vide.Source<number>
	self.Rings = nil :: Rings.Rings?
	self.Extras = nil :: Extras.Extras? -- TASK-452: set-dressing NPCs (crew at the HQ cart, shopkeeper, food court)
	self.Pads = nil :: Pads.Pads?
	self.Signs = nil :: Signs.Signs?
	self.Guide = nil :: Guide.Guide?
	self.Halloween = nil :: Halloween.Halloween? -- DEC-346: seasonal overlay (cauldron bubbles, bats); nil = event off
	-- guide due now ("" = none; Content.Lobby.Guide key) and the ones sent as done this session
	self.GuideKey = "" :: string
	self.GuideSent = {} :: { [string]: boolean }
	-- os.clock() since the player is in the lobby, loaded and outside a room (nil = loading or in a room)
	self.IdleFrom = nil :: number?
	self.Hiding = false :: boolean
	self.StageLights = nil :: Folder? -- local spotlights of the dark class stage (SetStageLights)
	self.StageDimmed = nil :: any -- lights / Neon switched off around the stage while it shows (restored after)

	self.Gui = nil :: ScreenGui?
	self.Unmount = nil :: (() -> ())?
end

-- Toasts ------------------------------------------------------------------------------------------------------------

function LobbyController:Toast(text: string, kind: Text.Kind)
	const list = table.clone(Vide.untrack(self.Toasts))
	for _, entry in list do
		if entry.Text == text then
			return -- same text already queued
		end
	end
	table.insert(list, { Text = text, Kind = kind })
	self.Toasts(list)
end

function LobbyController:ToastDone(entry: ToastStack.Entry)
	const list = table.clone(Vide.untrack(self.Toasts))
	const index = table.find(list, entry)
	if index then
		table.remove(list, index)
		self.Toasts(list)
	end
end

function LobbyController:Click()
	self.Dependencies.AudioController:Play(CLICK_SOUND)
end

-- Classes -----------------------------------------------------------------------------------------------------------

function LobbyController:StateOf(key: string): ClassSelect.State
	const profile = self.Dependencies.ProfileController
	if profile.Classes()[key] == true then
		return if profile.Selected() == key then "Equipped" else "Owned"
	end
	const class = Content.Classes.ByKey[key]
	return if class and class.InMvp then "Locked" else "Soon"
end

-- Robux price shown for a class (live Creator Hub price of its Game Pass when known); nil = no pass yet. Pass prices
-- live under -PassId in Prices (product and pass ids are separate number spaces).
function LobbyController:RobuxOf(key: string): number?
	const suggested, passId = ClassEntries.Robux(key)
	if suggested == nil then
		return nil
	end
	return self.Prices()[-passId] or suggested
end

function LobbyController:Busy(): boolean
	return self.Pending() ~= "" or not self.Dependencies.ProfileController.Ready()
end

function LobbyController:ClearPending()
	const thread = self.PendingThread
	self.PendingThread = nil
	if thread and thread ~= coroutine.running() and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
	if Vide.untrack(self.Pending) ~= "" then
		self.Pending("")
	end
end

function LobbyController:SetPending(key: string)
	self:ClearPending()
	self.Pending(key)
	self.PendingThread = task.delay(PENDING_TIMEOUT, function()
		self.PendingThread = nil
		self.Pending("")
	end)
end

function LobbyController:BuyClass(key: string, currency: "Gems" | "Robux")
	if self:Busy() then
		return
	end
	self:SetPending(key)
	self.Libs.Net.ClassBuy:fireServer({ Class = key, Currency = currency })
end

function LobbyController:Equip(key: string)
	if self:Busy() or self:StateOf(key) ~= "Owned" then
		return
	end
	self:SetPending(key)
	self.Libs.Net.ClassAction:fireServer({ Action = "Select", Class = key })
end

function LobbyController:OnClassBuyResult(class: string, reason: string)
	if reason == "Prompt" then
		-- Robux pre-check passed: prompt the class Game Pass; the server answers "Granted" after the purchase.
		const pass = Content.Shop.GamePasses.ByKey[class]
		if pass and pass.PassId > 0 then
			self.PromptClass = class
			const ok, err = pcall(function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.PassId)
			end)
			if ok then
				return -- pending until PromptGamePassPurchaseFinished
			end
			warn(`[LobbyController] PromptGamePassPurchase failed: {err}`)
			self.PromptClass = ""
		end
		self:ClearPending()
		const line = Text.ClassBuy("Unavailable", class)
		self:Toast(line.Text, line.Kind)
		return
	end
	self:ClearPending()
	const line = Text.ClassBuy(reason, class)
	self:Toast(line.Text, line.Kind)
end

function LobbyController:Step(delta: number)
	const key = Vide.untrack(self.Focus)
	local index = 1
	for i, entry in self.Entries do
		if entry.Key == key then
			index = i
		end
	end
	const n = #self.Entries
	self.Focus(self.Entries[(index - 1 + delta) % n + 1].Key)
end

-- Local preview rig: never tagged (RigController leaves it alone), dressed once here. `skin` = Content.Skins key previewed
-- ("" / nil = the crew uniform).
function LobbyController:BuildRig(species: string, skin: string?): Model?
	const ok, result = pcall(function(): Model
		const model = CrewRig.Build(species, OUTFIT, {
			Tag = false,
			Anchored = true,
			Name = `LobbyClass_{species}`,
			Skin = if skin ~= nil and skin ~= "" then skin else nil,
		})
		CrewRig.Dress(model)
		return model
	end)
	if ok then
		return result
	end
	if not self.RigWarned then
		self.RigWarned = true
		warn(`[LobbyController] class rig unavailable ({result}); showing the placeholder`)
	end
	return nil
end

function LobbyController:PlayIdle(model: Model)
	pcall(function()
		self.Dependencies.AnimController:Play(model, IDLE, { Looped = true })
	end)
end

function LobbyController:TakeCamera()
	const camera = self.Dependencies.CameraController
	self.CameraBefore = Vide.untrack(camera.Mode)
	camera:SetMode("External")
	const current = workspace.CurrentCamera
	if current then
		self.FovBefore = current.FieldOfView
	end
	self:HideCharacters(true)
end

-- Every character hidden locally while the world stage shows (the stage camera stands in the walkable area, and the
-- class zone is right in front of it: LOBBY.md §11, P-L10). Every frame, after the stock camera.
local function setCharacterTransparency(value: number)
	for _, player in Players:GetPlayers() do
		const character = player.Character
		if character then
			for _, descendant in character:GetDescendants() do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") then
					descendant.LocalTransparencyModifier = value
				end
			end
		end
	end
end

-- Stage props that sit between the class camera and the rig: hidden locally with the characters (owner 2026-10-21:
-- the red safety rope "Cinta" crossed the class screen). Paths under LOBBY_Assets; missing = skipped.
const STAGE_HIDE = { { "LobbyProcedural", "Cinta" } }

local function setStagePropsHidden(hidden: boolean)
	const root = workspace:FindFirstChild("LOBBY_Assets")
	if root == nil then
		return
	end
	for _, path in STAGE_HIDE do
		local item: Instance? = root
		for _, name in path do
			item = if item then item:FindFirstChild(name) else nil
		end
		if item then
			const parts = item:GetDescendants()
			table.insert(parts, item)
			for _, part in parts do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
end

-- Dark stage while the class screen shows the rig (owner 2026-10-21: "the focus should be only on the skin"): the
-- LightController blends to Content.LightPresets.ClassStage on this player attribute, and two local spotlights (key from
-- the front, soft rim from behind) light only the rig. Offsets from the stage point (its LookVector faces the camera).
const STAGE_LOOK_ATTRIBUTE = "ClassStage"
const STAGE_LIGHTS = {
	-- key far up in front, no shadow (a shadowed key put the cap's shadow over the eyes), narrow cone on the rig (2nd pass,
	-- owner 2026-10-21: "move the light away, put it higher, the rig is too dark"); 3rd pass (owner print, the white rabbit
	-- blown out: "menos estourado, tá muito branco"): key 4.5 -> 3, rim 2.5 -> 1.6
	{ Name = "Key", Ahead = 13, Up = 14, Color = Color3.fromRGB(255, 242, 225), Brightness = 3, Range = 30, Angle = 32, Shadows = false },
	{ Name = "Rim", Ahead = -4, Up = 8, Color = Color3.fromRGB(190, 200, 255), Brightness = 1.6, Range = 14, Angle = 50, Shadows = false },
}
const STAGE_AIM = 3 -- studs over the stage point the lights aim at (the rig's chest)
-- Local lights and Neon of the lobby around the stage ignore the Lighting preset: within this radius they are switched
-- off / turned matte for this client while the stage shows, and restored after.
const STAGE_DIM_RADIUS = 28
const STAGE_DIM_COLOR = 0.35 -- Neon parts keep this share of their colour while matte

type Dimmed = { Lights: { [Light]: boolean }, Neon: { [BasePart]: Color3 } }

local function dimAround(centre: Vector3): Dimmed
	const dimmed: Dimmed = { Lights = {}, Neon = {} }
	const root = workspace:FindFirstChild("LOBBY_Assets")
	if root == nil then
		return dimmed
	end
	for _, item in root:GetDescendants() do
		if item:IsA("Light") then
			const holder = item.Parent
			if holder and holder:IsA("BasePart") and (holder.Position - centre).Magnitude <= STAGE_DIM_RADIUS and item.Enabled then
				dimmed.Lights[item] = true
				item.Enabled = false
			end
		elseif item:IsA("BasePart") and item.Material == Enum.Material.Neon then
			if (item.Position - centre).Magnitude <= STAGE_DIM_RADIUS then
				dimmed.Neon[item] = item.Color
				item.Material = Enum.Material.SmoothPlastic
				item.Color = item.Color:Lerp(Color3.new(), 1 - STAGE_DIM_COLOR)
			end
		end
	end
	return dimmed
end

local function restoreDimmed(dimmed: Dimmed)
	for light in dimmed.Lights do
		if light.Parent then
			light.Enabled = true
		end
	end
	for part, color in dimmed.Neon do
		if part.Parent then
			part.Material = Enum.Material.Neon
			part.Color = color
		end
	end
end

function LobbyController:SetStageLights(on: boolean)
	Players.LocalPlayer:SetAttribute(STAGE_LOOK_ATTRIBUTE, if on then true else nil)
	const old = self.StageLights
	if old then
		old:Destroy()
		self.StageLights = nil
	end
	const dimmed = self.StageDimmed
	if dimmed then
		restoreDimmed(dimmed)
		self.StageDimmed = nil
	end
	if not on then
		return
	end
	const point = self:FindStagePoint()
	if point == nil then
		return
	end
	const folder = Instance.new("Folder")
	folder.Name = "ClassStageLights"
	const aim = point.Position + Vector3.new(0, STAGE_AIM, 0)
	for _, row in STAGE_LIGHTS do
		const at = point.Position + point.LookVector * row.Ahead + Vector3.new(0, row.Up, 0)
		const part = Instance.new("Part")
		part.Name = row.Name
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = CFrame.lookAt(at, aim)
		const light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Color = row.Color
		light.Brightness = row.Brightness
		light.Range = row.Range
		light.Angle = row.Angle
		light.Shadows = row.Shadows
		light.Parent = part
		part.Parent = folder
	end
	folder.Parent = workspace
	self.StageLights = folder
	self.StageDimmed = dimAround(point.Position)
end

function LobbyController:HideCharacters(on: boolean)
	if on == self.Hiding then
		return
	end
	self.Hiding = on
	setStagePropsHidden(on)
	self:SetStageLights(on)
	if on then
		RunService:BindToRenderStep(HIDE_STEP, HIDE_PRIORITY, function()
			setCharacterTransparency(1)
		end)
	else
		RunService:UnbindFromRenderStep(HIDE_STEP)
		setCharacterTransparency(0)
	end
end

function LobbyController:ReleaseCamera()
	self:HideCharacters(false)
	const current = workspace.CurrentCamera
	if current then
		current.FieldOfView = self.FovBefore
		current.CameraType = Enum.CameraType.Custom
		const character = Players.LocalPlayer.Character
		const humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			current.CameraSubject = humanoid
		end
	end
	const before = self.CameraBefore
	self.CameraBefore = nil
	const camera = self.Dependencies.CameraController
	if before == "External" then
		return -- someone else owned it already
	end
	-- Fixed / Spectate need their target: FirstPerson, and the camera driver picks the right mode again.
	camera:SetMode(if before == "Cutscene" then "Cutscene" else "FirstPerson")
end

-- World stage when the map has the point (looked up when the screen opens: the map may stream in late).
function LobbyController:FindStagePoint(): CFrame?
	if not MapIndex.HasBinding() then
		return nil
	end
	local ok, point = pcall(MapIndex.FindPoint, STAGE_POINT)
	if ok and point == nil then
		-- streamed in after the cache was built: one fresh read
		MapIndex.Refresh()
		ok, point = pcall(MapIndex.FindPoint, STAGE_POINT)
	end
	return if ok then point else nil
end

function LobbyController:OpenStage()
	const point = self:FindStagePoint()
	if point == nil then
		self.WorldStage(false)
		return
	end
	if self.Stage == nil or self.StagePoint ~= point then
		if self.Stage then
			self.Stage.Destroy()
		end
		self.StagePoint = point
		self.Stage = Stage({
			Point = point,
			Build = function(species: string, skin: string): Model?
				return self:BuildRig(species, skin)
			end,
			OnShown = function(model: Model)
				self:PlayIdle(model)
			end,
			Take = function()
				self:TakeCamera()
			end,
			Release = function()
				self:ReleaseCamera()
			end,
		})
	end
	self.WorldStage(true)
end

function LobbyController:SpeciesOf(key: string): string
	const class = Content.Classes.ByKey[key]
	return if class then class.Species else "dog"
end

-- Skins (owner request 2026-10-17, design/skins-proposal.md) ---------------------------------------------------------

-- Focus a class and preview the skin it wears.
function LobbyController:FocusClass(key: string)
	if Vide.untrack(self.Panel) == "Classes" and Vide.untrack(self.Focus) ~= key then
		self.Libs.Net.MetricUi:fireServer({ Event = "lobby_class_pick", Key = nil }) -- analytics: browsed a class
	end
	self.Focus(key)
	self.SkinFocus(self.Dependencies.SkinController:EquippedOf(key))
end

-- Circles under the card: the crew uniform, then the skins on show for the class.
function LobbyController:SkinEntries(class: string): { ClassSelect.SkinEntry }
	const row = Content.Classes.ByKey[class]
	const list: { ClassSelect.SkinEntry } = {
		{
			Key = "",
			Name = if row then row.Name else "Crew",
			Text = if row then row.Blurb else "",
			Swatch = { UNIFORM_SWATCH[1], UNIFORM_SWATCH[2] },
			Image = "",
			Limited = false,
		},
	}
	for _, key in self.Dependencies.SkinController:Shown(class) do
		const skin = Content.Skins.ByKey[key]
		table.insert(list, {
			Key = key,
			Name = skin.Name,
			Text = skin.Text,
			Swatch = skin.Swatch,
			Image = SkinIcons[key] or "",
			Limited = skin.Limited,
		})
	end
	return list
end

function LobbyController:SkinStateOf(key: string): ClassSelect.SkinState
	const skins = self.Dependencies.SkinController
	const owned = self.Dependencies.ProfileController.Classes()
	if key == "" then
		const class = self.Focus()
		if owned[class] ~= true then
			return "Locked"
		end
		return if skins:EquippedOf(class) == "" then "Equipped" else "Owned"
	end
	const skin = Content.Skins.ByKey[key]
	if skin == nil then
		return "Soon"
	end
	if skins:Owns(key) then
		if owned[skin.Class] ~= true then
			return "NeedsClass"
		end
		return if skins:EquippedOf(skin.Class) == key then "Equipped" else "Owned"
	end
	return if skins:OnSale(key) then "Locked" else "Soon"
end

-- Wear `key` ("" = the uniform) with the focused class; an owned class that is not the selected one gets selected too.
function LobbyController:EquipSkin(key: string)
	const class = Vide.untrack(self.Focus)
	self.Dependencies.SkinController:Equip(class, key)
	if self:StateOf(class) == "Owned" then
		self:Equip(class)
	end
end

-- Top banner of the class screen: the limited sale countdown ("" = none on sale).
function LobbyController:SkinBanner(): string
	const left = self.Dependencies.SkinController:LimitedLeft()
	if left == nil then
		return ""
	end
	const days = math.floor(left / 86400)
	if days >= 1 then
		return `Halloween Skins · Limited · {days}d left`
	end
	return `Halloween Skins · Last day!`
end

-- Shop --------------------------------------------------------------------------------------------------------------

function LobbyController:Packs(): { GemShop.Pack }
	const list: { GemShop.Pack } = {}
	for _, pack in Content.Shop.GemPacks.List do
		table.insert(list, {
			Key = pack.Key,
			Name = pack.Name,
			Gems = pack.Gems,
			Robux = pack.Robux,
			Available = pack.ProductId > 0,
		})
	end
	return list
end

function LobbyController:BuyPack(key: string)
	const pack = Content.Shop.GemPacks.ByKey[key]
	if pack == nil or pack.ProductId <= 0 or Vide.untrack(self.Prompting) then
		return
	end
	self.Prompting(true)
	self.Libs.Net.MetricUi:fireServer({ Event = "lobby_gem_prompt", Key = nil }) -- analytics
	const ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, pack.ProductId)
	end)
	if not ok then
		warn(`[LobbyController] PromptProductPurchase failed: {err}`)
		self.Prompting(false)
	end
end

-- Live Creator Hub prices (the table only has the suggested ones). One request per created product.
function LobbyController:LoadPrices()
	const ids: { number } = {}
	for _, pack in Content.Shop.GemPacks.List do
		if pack.ProductId > 0 then
			table.insert(ids, pack.ProductId)
		end
	end
	-- class Game Passes: stored under -PassId (RobuxOf)
	for _, pass in Content.Shop.GamePasses.List do
		if pass.PassId > 0 then
			task.spawn(function()
				const ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(pass.PassId, Enum.InfoType.GamePass)
				end)
				const price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
				if type(price) == "number" then
					const copy = table.clone(Vide.untrack(self.Prices))
					copy[-pass.PassId] = price
					self.Prices(copy)
				end
			end)
		end
	end
	for _, id in ids do
		task.spawn(function()
			const ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			const price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
			if type(price) == "number" then
				const copy = table.clone(Vide.untrack(self.Prices))
				copy[id] = price
				self.Prices(copy)
			end
		end)
	end
end

-- Squad -------------------------------------------------------------------------------------------------------------

function LobbyController:MyParty(): (number?, PartyRecord?)
	const me = Players.LocalPlayer.UserId
	for id, record in self.Parties() do
		if table.find(record.Members, me) then
			return id, record
		end
	end
	return nil, nil
end

function LobbyController:Members(): { SquadPanel.Member }
	const _, party = self:MyParty()
	const list: { SquadPanel.Member } = {}
	if party == nil then
		return list
	end
	const me = Players.LocalPlayer.UserId
	self.Roster() -- names follow players joining / leaving
	for _, userId in party.Members do
		table.insert(list, {
			UserId = userId,
			Name = if userId == me then `{nameOf(userId)} (you)` else nameOf(userId),
			Leader = userId == party.Leader,
			Me = userId == me,
		})
	end
	return list
end

function LobbyController:Candidates(): { SquadPanel.Candidate }
	const _, party = self:MyParty()
	const me = Players.LocalPlayer.UserId
	const sent = self.Sent()
	const list: { SquadPanel.Candidate } = {}
	for _, player in self.Roster() do
		const userId = player.UserId
		if userId ~= me and not (party and table.find(party.Members, userId)) then
			table.insert(list, { UserId = userId, Name = player.DisplayName, Invited = sent[userId] == true })
		end
	end
	table.sort(list, function(a: SquadPanel.Candidate, b: SquadPanel.Candidate): boolean
		return a.Name < b.Name
	end)
	return list
end

function LobbyController:IsLeader(): boolean
	const _, party = self:MyParty()
	return party ~= nil and party.Leader == Players.LocalPlayer.UserId
end

function LobbyController:Invite(userId: number)
	const sent = table.clone(Vide.untrack(self.Sent))
	sent[userId] = true
	self.Sent(sent)
	self.Libs.Net.PartyInvite:fireServer({ UserId = userId })
	task.delay(SENT_TIME, function()
		const copy = table.clone(Vide.untrack(self.Sent))
		copy[userId] = nil
		self.Sent(copy)
	end)
end

function LobbyController:Answer(accept: boolean)
	const list = table.clone(Vide.untrack(self.Invites))
	const invite = table.remove(list, 1)
	self.Invites(list)
	if invite then
		self.Libs.Net.PartyRespond:fireServer({ PartyId = invite.PartyId, Accept = accept })
	end
end

function LobbyController:CurrentInvite(): InvitePopup.Invite?
	const invite = self.Invites()[1]
	if invite == nil then
		return nil
	end
	return { UserId = invite.From, Name = invite.Name }
end

function LobbyController:ReceiveInvite(from: number, partyId: number)
	const list = table.clone(Vide.untrack(self.Invites))
	for index, invite in list do
		if invite.PartyId == partyId then
			table.remove(list, index)
			break
		end
	end
	const invite: Invite = { PartyId = partyId, From = from, Name = nameOf(from), At = os.clock() }
	table.insert(list, invite)
	self.Invites(list)
	self.Dependencies.AudioController:Play(CLICK_SOUND)
	-- the server drops it after InviteTtl: so does the card
	task.delay(PartyRules.Rules.InviteTtl, function()
		const now = table.clone(Vide.untrack(self.Invites))
		const at = table.find(now, invite)
		if at then
			table.remove(now, at)
			self.Invites(now)
		end
	end)
end

-- The leader (and a solo player) may abort the countdown until PartyRules.Rules.CancelCutoff s before the teleport; the
-- server refuses later, and the button is gone by then (user request 2026-10-12; network.md §16.8). Reactive (Clock).
function LobbyController:CanCancel(): boolean
	const _, party = self:MyParty()
	if party == nil or party.State ~= "Starting" or party.StartAt <= 0 then
		return false
	end
	if party.Leader ~= Players.LocalPlayer.UserId then
		return false
	end
	return party.StartAt - self.Clock() > PartyRules.Rules.CancelCutoff + CANCEL_MARGIN
end

function LobbyController:Cancel()
	-- event handlers run outside any reactive scope: plain reads
	if self:CanCancel() then
		self.Libs.Net.PartyCancel:fireServer()
	end
end

function LobbyController:CancelKey(): string
	return if self.Dependencies.InputController.Device() == "Touch" then "" else "X"
end

-- The status card and the Play button show only once the player has a squad (a pad, Create Squad, an accepted invite; a
-- quick play waiting for its squad too). User request 2026-10-15, TASK-296. Reactive (Parties).
function LobbyController:PlayShown(): boolean
	const _, party = self:MyParty()
	if party ~= nil and party.Platform > 0 then
		return false -- a pad room has the pad bar instead
	end
	return party ~= nil or self.QuickPending()
end

-- Pad bar (owner request 2026-10-21, Provisional): under a pad room, START NOW · SKIP TUTORIAL · FRIENDS ONLY (the
-- countdown lives on the pad sign). nil = not in a pad room. Reactive (Parties).
function LobbyController:PadBar(): LobbyHud.PadBar?
	const _, party = self:MyParty()
	if party == nil or party.Platform <= 0 then
		return nil
	end
	const me = Players.LocalPlayer.UserId
	return {
		Leader = party.Leader == me,
		Skip = party.Skip[me] == true,
		Friends = party.Access == "Friends",
	}
end

-- Queue strip + state line of a pad room (owner request 2026-10-21, Provisional): who is in, the seats, and
-- "Starting in 9..." over START NOW (the pad sign is hidden for its players). nil = not in a pad room. Reactive.
function LobbyController:Queue(): LobbyHud.Queue?
	const _, party = self:MyParty()
	if party == nil or party.Platform <= 0 then
		return nil
	end
	local status = ""
	if party.State == "Starting" then
		if party.StartAt <= 0 then
			status = "Starting..."
		else
			const left = party.StartAt - self.Clock()
			status = if left > 0 then `Starting in {math.ceil(left)}...` else "Teleporting..."
		end
	end
	return {
		Members = party.Members,
		Max = math.max(party.MaxPlayers, #party.Members),
		Leader = party.Leader,
		Status = status,
	}
end

-- The pad of my own pad room (0 = none). Reactive (Parties).
function LobbyController:MyPad(): number
	const _, party = self:MyParty()
	return if party then party.Platform else 0
end

-- EXIT on the queue strip: leave the room; the server takes the player out of the pad barrier (DEC-348).
function LobbyController:ExitPad()
	-- event handlers run outside any reactive scope: plain reads
	if self:MyPad() > 0 then
		self.Libs.Net.PartyLeave:fireServer()
	end
end

function LobbyController:PadAction(action: LobbyHud.PadAction)
	-- event handlers run outside any reactive scope: plain reads
	const bar = Vide.untrack(function()
		return self:PadBar()
	end)
	if bar == nil then
		return
	end
	const on = if action == "SkipTutorial" then not bar.Skip elseif action == "FriendsOnly" then not bar.Friends else true
	self.Libs.Net.PartyPad:fireServer({ Action = action, On = on })
end

function LobbyController:PlayButton(): LobbyHud.PlayButton
	const _, party = self:MyParty()
	if party == nil then
		return if self.QuickPending()
			then { Text = "...", Kind = "Off", Enabled = false }
			else { Text = "PLAY", Kind = "Go", Enabled = true }
	end
	if party.State == "Starting" then
		if self:CanCancel() then
			return { Text = "CANCEL", Kind = "Cancel", Enabled = true }
		end
		return { Text = "STARTING...", Kind = "Go", Enabled = true }
	end
	-- one button (DEC-344): the leader starts with whoever is in, alone included; the others wait for the leader
	if party.Leader == Players.LocalPlayer.UserId then
		return { Text = "START", Kind = "Go", Enabled = true }
	end
	return { Text = "WAITING...", Kind = "Off", Enabled = false }
end

-- The gear beside START: the leader, before the countdown (TASK-306, DEC-344). Reactive (Parties).
-- The room setup window is no longer opened (owner request 2026-10-21: the pad bar replaces it; the code stays)
function LobbyController:GearShown(): boolean
	return false
end

-- Play button: outside a squad the choice (Play Solo / Create Squad); the leader starts the squad (DEC-344); the others
-- have nothing to press (the button waits).
function LobbyController:Play()
	-- event handlers run outside any reactive scope: plain reads
	if self:CanCancel() then
		self:Cancel()
		return
	end
	const id = self:MyParty()
	if id == nil then
		if not Vide.untrack(self.QuickPending) then
			self:SetPanel("Play")
		end
		return
	end
	if self:IsLeader() then
		self.Libs.Net.PartyStart:fireServer()
	end
end

function LobbyController:ClearQuickPlay()
	self.QuickAt = 0
	if Vide.untrack(self.QuickPending) then
		self.QuickPending(false)
	end
end

-- Play Solo / Create Squad: the server creates the squad (and starts it for Solo); nothing is assumed here.
function LobbyController:QuickPlay(choice: PlayChoice.Choice)
	if Vide.untrack(self.QuickPending) then
		return
	end
	const id = self:MyParty()
	if id ~= nil then
		return -- already in a squad: the HUD shows its button
	end
	const at = os.clock()
	self.QuickMode = choice
	self.QuickAt = at
	self.QuickPending(true)
	self.Libs.Net.PartyQuickPlay:fireServer({ Mode = choice })
	if choice == "Solo" then
		self:SetPanel("None") -- the HUD shows the countdown
	end
	-- no answer (dropped by the rate limit): the buttons come back
	task.delay(PLAY_TIMEOUT, function()
		if self.QuickAt == at then
			self:ClearQuickPlay()
		end
	end)
end

-- The squad of a quick play arrived: Create Squad opens its setup window.
function LobbyController:CheckQuickPlay()
	if not Vide.untrack(self.QuickPending) then
		return
	end
	-- event handlers run outside any reactive scope: plain reads
	const id = self:MyParty()
	if id == nil then
		return
	end
	self:ClearQuickPlay()
	if Vide.untrack(self.Panel) == "Play" then
		self:SetPanel("None") -- the squad is there: the HUD shows START (no setup window any more)
	end
end

-- Squad platforms ---------------------------------------------------------------------------------------------------

-- The squad that owns platform n (Party set); nil = free.
function LobbyController:PlatformParty(n: number): PartyRecord?
	if n <= 0 then
		return nil
	end
	for _, record in self.Parties() do
		if record.Platform == n then
			return record
		end
	end
	return nil
end

-- The squad shown in the setup window: my own squad (platform or invite), else the one on the platform I stand on
-- (being refused, or a friends-only check on its way).
function LobbyController:SetupParty(): PartyRecord?
	const _, mine = self:MyParty()
	if mine then
		return mine
	end
	return self:PlatformParty(self.Standing())
end

function LobbyController:SetupMembers(): { SquadSetup.Member }
	const party = self:SetupParty()
	const list: { SquadSetup.Member } = {}
	if party == nil then
		return list
	end
	const me = Players.LocalPlayer.UserId
	self.Roster()
	for _, userId in party.Members do
		table.insert(list, {
			UserId = userId,
			Name = if userId == me then `{nameOf(userId)} (you)` else nameOf(userId),
			Leader = userId == party.Leader,
			Me = userId == me,
		})
	end
	return list
end

-- Seconds before the teleport of the shown squad; nil = not starting.
function LobbyController:Countdown(): number?
	const party = self:SetupParty()
	if party == nil or party.State ~= "Starting" or party.StartAt <= 0 then
		return nil
	end
	return math.max(party.StartAt - self.Clock(), 0)
end

function LobbyController:Configure(access: string, maxPlayers: number)
	self.Libs.Net.PartyConfigure:fireServer({
		Access = access :: any,
		MaxPlayers = math.clamp(maxPlayers, 1, PartyRules.Rules.MaxSize),
	})
end

-- Pad signs: players on the pad (0 = free), table size, state and the line under the slots.
function LobbyController:PadMembers(n: number): number
	const party = self:PlatformParty(n)
	return if party then #party.Members else 0
end

function LobbyController:PadMax(n: number): number
	const party = self:PlatformParty(n)
	-- no fixed capacity per pad: a free pad has no size
	return if party then math.max(party.MaxPlayers, #party.Members) else 0
end

function LobbyController:PadState(n: number): PadTag.State
	const party = self:PlatformParty(n)
	if party == nil then
		return "Free"
	elseif party.State == "Starting" then
		return "Starting"
	end
	return if party.Access == "Closed" or #party.Members >= math.max(party.MaxPlayers, 1) then "Closed" else "Open"
end

function LobbyController:PadStatus(n: number): string
	const party = self:PlatformParty(n)
	if party == nil then
		return "STEP IN"
	end
	if party.State == "Starting" then
		if party.StartAt <= 0 then
			return "STARTING..."
		end
		const left = party.StartAt - self.Clock()
		-- after the count the squad is on its way (owner 2026-10-17: everyone in the lobby sees it leave)
		return if left > 0 then `STARTING IN {math.ceil(left)}...` else "TELEPORTING..."
	end
	if party.Access == "Closed" then
		return "CLOSED"
	elseif #party.Members >= math.max(party.MaxPlayers, 1) then
		return "FULL"
	end
	const count = `{#party.Members}/{math.max(party.MaxPlayers, #party.Members)}`
	if party.Access == "Friends" then
		return "FRIENDS ONLY"
	elseif party.Access == "Invite" then
		return "INVITE ONLY"
	end
	return `OPEN {count}`
end

-- Display name of the leader of the squad on pad n ("" = free pad).
function LobbyController:PadLeader(n: number): string
	const party = self:PlatformParty(n)
	if party == nil then
		return ""
	end
	self.Roster() -- names follow players joining / leaving
	return nameOf(party.Leader)
end

-- Head shots on the sign of pad n (owner request 2026-10-17): the members, leader first
function LobbyController:PadFaces(n: number): { number }
	const party = self:PlatformParty(n)
	return if party then party.Members else {}
end

-- Ring + floor glow of each platform by room state (Content.Lobby.Squad.Pad): green free / open, Slate full / closed, Teal starting; the breath speeds up with the countdown; sparks while someone stands on it.
function LobbyController:PaintPlatforms()
	const rings = self.Rings
	if rings == nil then
		return
	end
	const pad = LOBBY.Squad.Pad
	for n = 1, PartyRules.Rules.Platforms do
		const state = self:PadState(n)
		rings.SetPad(`Squad{n}`, pad.Colors[state], pad.Pulse[state], self:PadMembers(n) > 0)
	end
end

-- Somebody stepped on / off pad n: the ring shivers; a click when it is the own pad or one close by.
function LobbyController:OnPadCount(n: number, _from: number, _to: number)
	const rings = self.Rings
	if rings then
		rings.Kick(`Squad{n}`)
	end
	const zone = LobbyZones.Platform(n)
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if zone and root and root:IsA("BasePart") and (root.Position - zone.Center).Magnitude <= zone.Radius + PAD_SOUND_RANGE then
		self:Click()
	end
end

-- Floor guide -------------------------------------------------------------------------------------------------------

-- Cheapest class on sale this account does not own yet (gems); nil when there is none
function LobbyController:CheapestClass(): number?
	const owned = self.Dependencies.ProfileController.Classes()
	local best: number? = nil
	for _, class in Content.Classes.List do
		if class.InMvp and class.Price > 0 and owned[class.Key] ~= true and (best == nil or class.Price < best) then
			best = class.Price
		end
	end
	return best
end

function LobbyController:GuidePending(key: string): boolean
	return self.GuideSent[key] ~= true and self.Dependencies.ProfileController.Guides()[key] ~= true
end

-- The guide due now ("" = none) and its zone
function LobbyController:GuideTarget(): (string, LobbyZones.Zone?)
	const profile = self.Dependencies.ProfileController
	if not profile.Ready() then
		return "", nil
	end
	if self:GuidePending("classes") then
		const price = self:CheapestClass()
		if price ~= nil and profile.Gems() >= price then
			for _, zone in LobbyZones.List() do
				if zone.Panel == "Classes" then
					return "classes", zone
				end
			end
		end
	end
	if self:GuidePending("pad") then
		return "pad", self:FreePad()
	end
	-- idle nudge (owner 2026-10-21): GUIDE_IDLE s in the lobby outside a room = the pad guide again, every visit
	const idle = self.IdleFrom
	if idle ~= nil and os.clock() - idle >= GUIDE_IDLE then
		return "idle", self:FreePad()
	end
	return "", nil
end

-- The nearest pad nobody owns (not a room counting down nor teleporting; owner 2026-10-21); nil = none free
function LobbyController:FreePad(): LobbyZones.Zone?
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best: LobbyZones.Zone? = nil
	local bestDistance = math.huge
	for n = 1, PartyRules.Rules.Platforms do
		const zone = LobbyZones.Platform(n)
		if zone ~= nil and self:PlatformParty(n) == nil then
			const distance = (zone.Center - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end
	return best
end

function LobbyController:GuideDone(key: string)
	if not self:GuidePending(key) then
		return
	end
	self.GuideSent[key] = true
	self.Libs.Net.LobbyGuideDone:fireServer(key)
end

-- Every zone poll: what the guide points at (nothing while a screen is open)
function LobbyController:CheckGuide()
	const guide = self.Guide
	if guide == nil then
		return
	end
	const inRoom = self:MyParty() ~= nil
	if self:GuidePending("pad") and inRoom then
		self:GuideDone("pad") -- joined a squad some other way (Play Solo, an invite)
	end
	-- idle clock: runs while loaded and outside a room, starts over on every room
	const playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	const loading = playerGui ~= nil and playerGui:FindFirstChild(LOADING_GUI) ~= nil
	if loading or inRoom then
		self.IdleFrom = nil
	elseif self.IdleFrom == nil then
		self.IdleFrom = os.clock()
	end
	const key, zone = self:GuideTarget()
	self.GuideKey = key
	if zone == nil or Vide.untrack(self.Panel) ~= "None" then
		guide.Clear()
	else
		guide.Point(zone.Center, zone.Radius)
	end
end

-- Zones -------------------------------------------------------------------------------------------------------------

function LobbyController:OnZone(zone: LobbyZones.Zone, inside: boolean)
	-- TASK-450: the zone glows only while the local player is in it
	const rings = self.Rings
	if rings then
		rings.SetInside(zone.Key, inside)
	end
	if zone.Platform > 0 then
		if inside then
			self:GuideDone("pad")
			self.Standing(zone.Platform)
		elseif Vide.untrack(self.Standing) == zone.Platform then
			self.Standing(0)
		end
	end
	if zone.Platform > 0 then
		return -- a pad opens nothing (DEC-344): START is on the HUD, the setup window is behind the gear
	end
	const panel: Panel = zone.Panel
	if inside then
		if Vide.untrack(self.Panel) ~= panel then
			self:Click()
			self:SetPanel(panel)
		end
	elseif Vide.untrack(self.Panel) == panel then
		self:SetPanel("None")
	end
end

-- Own root against every zone (hysteresis in LobbyZones.Inside). Exits first, so walking from one zone straight
-- into the next opens the new panel last.
function LobbyController:CheckZones()
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const position = if root and root:IsA("BasePart") then root.Position else nil
	const entered: { LobbyZones.Zone } = {}
	for _, zone in LobbyZones.List() do
		const was = self.ZoneInside[zone.Key] == true
		const inside = position ~= nil and LobbyZones.Inside(zone, position, was)
		if inside ~= was then
			self.ZoneInside[zone.Key] = if inside then true else nil
			if inside then
				table.insert(entered, zone)
			else
				self:OnZone(zone, false)
			end
		end
	end
	for _, zone in entered do
		self:OnZone(zone, true)
	end
end

-- One Heartbeat for the lobby: ring VFX every frame, zones every Trigger.Poll s, the countdown clock.
function LobbyController:RunZones()
	self.Rings = Rings()
	self.Extras = Extras()
	self.Guide = Guide()
	self.Halloween = Halloween()
	-- floating smoke lanterns of LOBBY_Assets.Lights bob up and down (owner request 2026-10-21)
	const lanterns = Lanterns()
	-- street traffic between the two lobby tunnels (owner 2026-10-16); nil when the map lacks the cars or the tunnels
	const traffic = Traffic()
	self:PaintPlatforms()
	local t = 0
	local nextZones = 0
	local nextClock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		const rings = self.Rings
		if rings then
			const camera = workspace.CurrentCamera
			rings.Step(t, if camera then camera.CFrame.Position else nil)
		end
		const extras = self.Extras
		if extras then
			const camera = workspace.CurrentCamera
			extras.Step(t, if camera then camera.CFrame.Position else nil)
		end
		if traffic then
			traffic.Step(dt)
		end
		lanterns.Step(t)
		const halloween = self.Halloween
		if halloween then
			const camera = workspace.CurrentCamera
			halloween.Step(t, if camera then camera.CFrame.Position else nil)
		end
		const pads = self.Pads
		if pads then
			pads.Step()
		end
		const signs = self.Signs
		if signs then
			signs.Step()
		end
		const now = os.clock()
		if now >= nextZones then
			nextZones = now + LOBBY.Trigger.Poll
			self:CheckZones()
			self:CheckGuide()
		end
		const guide = self.Guide
		if guide then
			guide.Step()
		end
		if now >= nextClock then
			nextClock = now + CLOCK_INTERVAL
			self.Clock(workspace:GetServerTimeNow())
		end
	end)
end

-- Third person in the lobby (the game is locked first person): CameraController hands-off, stock Classic camera,
-- pushed out of a first-person zoom once.
function LobbyController:ThirdPerson()
	const player = Players.LocalPlayer
	const rules = LOBBY.Camera
	self.Dependencies.CameraController:SetMode("External")
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = rules.MaxZoom
	player.CameraMinZoomDistance = math.min(rules.StartZoom, rules.MaxZoom)
	task.delay(0.5, function()
		player.CameraMinZoomDistance = rules.MinZoom
	end)
	const camera = workspace.CurrentCamera
	if camera and Vide.untrack(self.Panel) ~= "Classes" then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- UI scale of the notices column (same rule as the windows).
function LobbyController:NoticeScale(): number
	return math.max(math.min(self.Scale(), UiScale.Current()), UiScale.Floor())
end

-- The top left stays free for the Roblox menu and chat (the tiles sit at the middle of the left edge), and the Roblox
-- menu (Esc) closes the open window so the two never stack. The player list (top right on desktop) is ON in the lobby
-- (owner 2026-10-21): it shows the leaderstats, Nights and Gems (ProfileService:Leaderstats; ranking only in the
-- lobby, DEC-339).
function LobbyController:ClearLeftSide()
	const ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
	if not ok then
		warn(`[LobbyController] could not hide the player list: {err}`)
	end
	GuiService.MenuOpened:Connect(function()
		if Vide.untrack(self.Panel) ~= "None" then
			self:SetPanel("None")
		end
	end)
end

-- Panels and input --------------------------------------------------------------------------------------------------

function LobbyController:SelectFirst(panel: Panel)
	if Vide.untrack(self.Dependencies.InputController.Device) ~= "Gamepad" then
		return
	end
	const gui = self.Gui
	if gui == nil then
		return
	end
	const names = if panel == "Classes" then { Vide.untrack(self.Focus) } else FIRST_SELECTION[panel]
	const root: Instance = if panel == "None" then gui else (gui:FindFirstChild(PANEL_ROOT[panel], true) or gui)
	for _, name in names do
		for _, descendant in root:GetDescendants() do
			if descendant.Name == name and descendant:IsA("GuiButton") and shown(descendant) then
				GuiService.SelectedObject = descendant
				return
			end
		end
	end
end

function LobbyController:SetPanel(panel: Panel)
	const before = Vide.untrack(self.Panel)
	if before == panel then
		return
	end
	if before == "Classes" then
		const stage = self.Stage
		if stage then
			stage.Close()
		end
	end
	if panel == "Classes" then
		if self.GuideKey == "classes" then
			self:GuideDone("classes")
		end
		self:FocusClass(self.Dependencies.ProfileController.Selected())
		self:OpenStage()
	end
	if panel == "Codes" and Vide.untrack(self.CodeFeedback).Kind ~= "Wait" then
		self.CodeFeedback({ Text = "", Kind = "None" })
	end
	self.Panel(panel)
	const metric = PANEL_METRIC[panel]
	if metric ~= nil then
		self.Libs.Net.MetricUi:fireServer({ Event = metric :: any, Key = nil }) -- analytics (lobby window funnels)
	end
	self.Dependencies.InputController:SetContext(if panel == "None" then "Gameplay" else "Menu")
	const selected = GuiService.SelectedObject
	const gui = self.Gui
	if selected and gui and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if panel ~= "None" then
		task.defer(function()
			self:SelectFirst(panel)
		end)
	end
end

function LobbyController:Toggle(panel: Panel)
	self:Click()
	self:SetPanel(if Vide.untrack(self.Panel) == panel then "None" else panel)
end

function LobbyController:DeviceKeys(): { [string]: string }
	const device = self.Dependencies.InputController.Device()
	const keys: { [string]: string } = {}
	if device == "Touch" then
		return keys
	end
	for _, bind in PANEL_BINDS do
		keys[bind.Panel] = if device == "Gamepad" then bind.PadText else bind.Key.Name
	end
	return keys
end

function LobbyController:Bind()
	const input = self.Dependencies.InputController
	for _, bind in PANEL_BINDS do
		input
			:Bind({
				Name = bind.Name,
				Key = bind.Key,
				Keys = { bind.Pad },
				Priority = BIND_PRIORITY,
			})
			.OnPress(function()
				self:Toggle(bind.Panel)
			end)
	end
	input
		:Bind({
			Name = PLAY,
			Key = Enum.KeyCode.Return,
			Keys = { Enum.KeyCode.DPadDown },
			Priority = BIND_PRIORITY,
			Context = "Gameplay",
		})
		.OnPress(function()
			if self:PlayShown() and self:PlayButton().Enabled then
				self:Click()
				self:Play()
			end
		end)
	-- X / gamepad X: cancel the countdown (any context: the squad window may be open over it)
	input
		:Bind({
			Name = CANCEL,
			Key = Enum.KeyCode.X,
			Keys = { Enum.KeyCode.ButtonX },
			Priority = BIND_PRIORITY,
		})
		.OnPress(function()
			if self:CanCancel() then
				self:Click()
				self:Cancel()
			end
		end)
	for _, choice in PLAY_CHOICES do
		input
			:Bind({
				Name = choice.Name,
				Key = choice.Key,
				Context = "Menu",
				Priority = BIND_PRIORITY,
			})
			.OnPress(function()
				if Vide.untrack(self.Panel) == "Play" then
					self:Click()
					self:QuickPlay(choice.Choice)
				end
			end)
	end
	input
		:Bind({
			Name = CLOSE,
			Key = Enum.KeyCode.ButtonB,
			Context = "Menu",
			Priority = BIND_PRIORITY,
		})
		.OnPress(function()
			self:SetPanel("None")
		end)
	input
		:Bind({
			Name = PREVIOUS,
			Key = Enum.KeyCode.Left,
			Keys = { Enum.KeyCode.ButtonL1 },
			Context = "Menu",
			Priority = BIND_PRIORITY,
		})
		.OnPress(function()
			if Vide.untrack(self.Panel) == "Classes" then
				self:Click()
				self:Step(-1)
			end
		end)
	input
		:Bind({
			Name = NEXT,
			Key = Enum.KeyCode.Right,
			Keys = { Enum.KeyCode.ButtonR1 },
			Context = "Menu",
			Priority = BIND_PRIORITY,
		})
		.OnPress(function()
			if Vide.untrack(self.Panel) == "Classes" then
				self:Click()
				self:Step(1)
			end
		end)
end

function LobbyController:Rescale(camera: Camera?)
	if camera == nil then
		return
	end
	const size = camera.ViewportSize
	if size ~= Vide.untrack(self.Viewport) then
		self.Viewport(size)
	end
	const scale = math.clamp(math.min(size.X / BASE_WIDTH, size.Y / BASE_HEIGHT), 1, MAX_SCALE)
	if math.abs(scale - Vide.untrack(self.Scale)) > 0.01 then
		self.Scale(scale)
	end
end

function LobbyController:WatchViewport()
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

function LobbyController:WatchRoster()
	local function refresh()
		self.Roster(Players:GetPlayers())
	end
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	refresh()
end

-- Mount -------------------------------------------------------------------------------------------------------------

function LobbyController:Mount(playerGui: Instance)
	const profile = self.Dependencies.ProfileController
	const gifts = self.Dependencies.GiftController
	const isOpen = function(panel: Panel): () -> boolean
		return function()
			return self.Panel() == panel
		end
	end
	local function close()
		self:Click()
		self:SetPanel("None")
	end

	const unmount, gui = Vide.root(function()
		-- A Profile packet answers a class request: whatever it says, the buttons come back. Sources are written deferred,
		-- never inside an effect (see the setup window effect below).
		Vide.effect(function()
			profile.Classes()
			profile.Selected()
			profile.Gems()
			task.defer(function()
				if self.PromptClass == "" then
					self:ClearPending()
				end
			end)
		end)

		-- The gift picker (TASK-353) shares the window scale and closes with the shop / class screen under it
		Vide.effect(function()
			const scale = self.Scale()
			const panel = self.Panel()
			task.defer(function()
				gifts.Scale(scale)
				if panel ~= "Shop" and panel ~= "Classes" then
					gifts:Close()
				end
			end)
		end)

		-- Platform ring colours follow the Party set
		Vide.effect(function()
			self.Parties()
			Vide.untrack(function()
				self:PaintPlatforms()
				return nil
			end)
		end)

		-- Blur + Ink veil behind every window (TASK-311, BackdropController; full screen, no insets). The class screen on
		-- the world stage keeps the world sharp: the rig in front of the camera is the content
		Backdrop.Hold(function()
			const panel = self.Panel()
			return panel ~= "None" and (panel ~= "Classes" or not self.WorldStage())
		end)

		-- The setup window opened by Play closes when there is no squad to show anymore (left, solo run over). Deferred:
		-- writing Panel inside an effect breaks Vide's graph ("attempt to call a boolean"), and the error aborted the
		-- OnZone that set Standing, leaving the window stuck open (owner 2026-10-20: lobby UI froze on pad in / out).
		Vide.effect(function()
			const panel = self.Panel()
			const party = self:SetupParty()
			if panel == "Platform" and party == nil and Vide.untrack(self.Standing) == 0 then
				task.defer(function()
					if Vide.untrack(self.Panel) == "Platform" and self:SetupParty() == nil and Vide.untrack(self.Standing) == 0 then
						self:SetPanel("None")
					end
				end)
			end
		end)

		-- The zone rings leave the world while the class panel is open (they drew over the class on the stage, owner
		-- 2026-10-16) and come back when it closes
		Vide.effect(function()
			const open = self.Panel() == "Classes"
			Vide.untrack(function()
				const rings = self.Rings
				if rings then
					rings.SetHidden(open)
				end
				const extras = self.Extras
				if extras then
					extras.SetHidden(open)
				end
				return nil
			end)
		end)

		-- Class swap on the world stage
		Vide.effect(function()
			const key = self.Focus()
			const skin = self.SkinFocus()
			const open = self.Panel() == "Classes" and self.WorldStage()
			Vide.untrack(function()
				const stage = self.Stage
				if open and stage then
					stage.Show(self:SpeciesOf(key), skin)
				end
				return nil
			end)
		end)

		const stage = ClassStage({
			Species = function()
				return self:SpeciesOf(self.Focus())
			end,
			Badge = function()
				const class = Content.Classes.ByKey[self.Focus()]
				return if class then string.upper(string.sub(class.Species, 1, 1)) else "?"
			end,
			Visible = function()
				return self.Panel() == "Classes" and not self.WorldStage()
			end,
			Rig = function(species: string): Model?
				return self:BuildRig(species)
			end,
			OnShown = function(model: Model)
				self:PlayIdle(model)
			end,
		})

		return Vide.create("ScreenGui")({
			Name = "Lobby",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 6,

			-- frees the mouse of a first-person camera while a screen is open
			Vide.create("TextButton")({
				Name = "Modal",
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				Modal = function()
					return self.Panel() ~= "None"
				end,
				Visible = function()
					return self.Panel() ~= "None"
				end,
			}),

			LobbyHud({
				Visible = isOpen("None"),
				Gems = profile.Gems,
				Squad = function()
					const _, party = self:MyParty()
					return if party then `{#party.Members}/{PartyRules.Rules.MaxSize}` else ""
				end,
				Play = function()
					return self:PlayButton()
				end,
				Keys = function()
					return self:DeviceKeys()
				end,
				OnOpen = function(tile: LobbyHud.Tile)
					self:Toggle(tile)
				end,
				OnPlay = function()
					self:Click()
					self:Play()
				end,
				CancelKey = function()
					return self:CancelKey()
				end,
				PlayShown = function()
					return self:PlayShown()
				end,
				Gear = function()
					return self:GearShown()
				end,
				OnGear = function()
					self:Click()
				end,
				Pad = function()
					return self:PadBar()
				end,
				OnPad = function(action: LobbyHud.PadAction)
					self:Click()
					self:PadAction(action)
				end,
				Scale = self.Scale,
				Online = self.Online,
				Queue = function()
					return self:Queue()
				end,
				OnExit = function()
					self:Click()
					self:ExitPad()
				end,
			}),

			ClassSelect({
				Entries = self.Entries,
				Visible = isOpen("Classes"),
				Gems = profile.Gems,
				Focus = self.Focus,
				StateOf = function(key: string): ClassSelect.State
					return self:StateOf(key)
				end,
				RobuxOf = function(key: string): number?
					return self:RobuxOf(key)
				end,
				Busy = function()
					return self:Busy()
				end,
				OnFocus = function(key: string)
					if Vide.untrack(self.Focus) ~= key then
						self:Click()
						self:FocusClass(key)
					end
				end,
				OnBuyGems = function(key: string)
					self:Click()
					self:BuyClass(key, "Gems")
				end,
				OnBuyRobux = function(key: string)
					self:Click()
					self:BuyClass(key, "Robux")
				end,
				OnEquip = function(key: string)
					self:Click()
					self:Equip(key)
				end,
				-- gift a class to another player (TASK-353, GiftController)
				OnGift = function(key: string)
					gifts:Open(`gift_{key}`)
				end,
				Giftable = function(key: string): boolean
					return gifts:GiftOf(key) ~= nil
				end,
				CanGift = function(key: string): boolean
					return gifts:CanGift(key)
				end,
				OnClose = close,
				-- class skins (owner request 2026-10-17): circles under the card, preview on the stage, Robux only
				Skins = {
					Entries = function(class: string)
						return self:SkinEntries(class)
					end,
					Focus = self.SkinFocus,
					OnFocus = function(key: string)
						if Vide.untrack(self.SkinFocus) ~= key then
							self:Click()
							self.SkinFocus(key)
						end
					end,
					StateOf = function(key: string): ClassSelect.SkinState
						return self:SkinStateOf(key)
					end,
					RobuxOf = function(key: string): number?
						return self.Dependencies.SkinController:RobuxOf(key)
					end,
					OnBuy = function(key: string)
						self:Click()
						self.Dependencies.SkinController:Buy(key)
					end,
					OnEquip = function(key: string)
						self:Click()
						self:EquipSkin(key)
					end,
					Banner = function()
						return self:SkinBanner()
					end,
				},
				Stage = stage,
				Scale = self.Scale,
			}),

			GemShop({
				Packs = self:Packs(),
				Visible = isOpen("Shop"),
				Gems = profile.Gems,
				PriceOf = function(key: string): number?
					const pack = Content.Shop.GemPacks.ByKey[key]
					return if pack then self.Prices()[pack.ProductId] else nil
				end,
				Busy = self.Prompting,
				OnBuy = function(key: string)
					self:Click()
					self:BuyPack(key)
				end,
				-- gift a gem pack to another player (TASK-353, GiftController)
				OnGift = function(key: string)
					gifts:Open(`gift_{key}`)
				end,
				CanGift = function(key: string): boolean
					return gifts:CanGift(key)
				end,
				OnClose = close,
				Scale = self.Scale,
			}),

			CodeRedeem({
				Visible = isOpen("Codes"),
				Feedback = self.CodeFeedback,
				OnRedeem = function(code: string)
					self:Click()
					self.CodeFeedback({ Text = "", Kind = "Wait" })
					self.Libs.Net.CodeRedeem:fireServer({ Code = code })
					-- no answer (dropped by the rate limit): the box comes back
					task.delay(PENDING_TIMEOUT, function()
						if Vide.untrack(self.CodeFeedback).Kind == "Wait" then
							self.CodeFeedback({ Text = "No answer, try again", Kind = "Bad" })
						end
					end)
				end,
				OnClose = close,
				Scale = self.Scale,
			}),

			SquadPanel({
				Visible = isOpen("Squad"),
				InSquad = function()
					const id = self:MyParty()
					return id ~= nil
				end,
				Members = function()
					return self:Members()
				end,
				IsLeader = function()
					return self:IsLeader()
				end,
				Starting = function()
					const _, party = self:MyParty()
					return party ~= nil and party.State == "Starting"
				end,
				Candidates = function()
					return self:Candidates()
				end,
				MaxSize = PartyRules.Rules.MaxSize,
				OnCreate = function()
					self:Click()
					self.Libs.Net.PartyCreate:fireServer()
				end,
				OnInvite = function(userId: number)
					self:Click()
					self:Invite(userId)
				end,
				OnKick = function(userId: number)
					self:Click()
					self.Libs.Net.PartyKick:fireServer({ UserId = userId })
				end,
				OnLeave = function()
					self:Click()
					self.Libs.Net.PartyLeave:fireServer()
				end,
				OnStart = function()
					self:Click()
					self.Libs.Net.PartyStart:fireServer()
				end,
				OnClose = close,
				Scale = self.Scale,
			}),

			PlayChoice({
				Visible = isOpen("Play"),
				Busy = self.QuickPending,
				Keys = function()
					return if self.Dependencies.InputController.Device() == "KeyboardMouse"
						then { Solo = "1", Squad = "2" }
						else {}
				end,
				OnChoose = function(choice: PlayChoice.Choice)
					self:Click()
					self:QuickPlay(choice)
				end,
				OnClose = close,
				Scale = self.Scale,
			}),

			SquadSetup({
				Visible = isOpen("Platform"),
				Platform = self.Standing,
				Members = function()
					return self:SetupMembers()
				end,
				IsLeader = function()
					const party = self:SetupParty()
					return party ~= nil and party.Leader == Players.LocalPlayer.UserId
				end,
				Access = function()
					const party = self:SetupParty()
					return if party then party.Access else "Friends"
				end,
				MaxPlayers = function()
					const party = self:SetupParty()
					return if party then party.MaxPlayers else PartyRules.Rules.DefaultMaxPlayers
				end,
				MaxSize = PartyRules.Rules.MaxSize,
				Countdown = function()
					return self:Countdown()
				end,
				OnAccess = function(access: string)
					self:Click()
					const party = self:SetupParty()
					if party then
						self:Configure(access, party.MaxPlayers)
					end
				end,
				OnMaxPlayers = function(count: number)
					self:Click()
					const party = self:SetupParty()
					if party then
						self:Configure(party.Access, count)
					end
				end,
				OnStart = function()
					self:Click()
					self.Libs.Net.PartyStart:fireServer()
				end,
				CanCancel = function()
					return self:CanCancel()
				end,
				OnCancel = function()
					self:Click()
					self:Cancel()
				end,
				OnClose = close,
				Scale = self.Scale,
				Invite = function()
					const party = self:SetupParty()
					return party ~= nil and party.Platform == 0
				end,
				OnInvite = function()
					self:Click()
					self:SetPanel("Squad")
				end,
				OnLeave = function()
					self:Click()
					self.Libs.Net.PartyLeave:fireServer()
					self:SetPanel("None")
				end,
			}),

			-- Notices column, top centre (the HUD sides are centred vertically): the invite popup, the toasts under it. One
			-- UIScale. On a narrow screen it steps down under the Roblox top bar instead of running into its buttons.
			Vide.create("Frame")({
				Name = "Notices",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = function()
					const narrow = self.Viewport().X < NARROW_VIEWPORT
					const top = if narrow then NOTICE_TOP_NARROW else NOTICE_TOP
					-- under the queue strip (pad room) or the online pill while it is shown (HUD up, count known)
					const hud = self.Panel() == "None"
					const space = if hud and self:MyPad() > 0
						then QUEUE_SPACE
						elseif hud and self.Online() > 0 then ONLINE_SPACE
						else 0
					return UDim2.new(0.5, 0, 0, top + space * self:NoticeScale())
				end,
				Size = UDim2.fromOffset(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				(Vide.create :: any)("UIScale")({
					Scale = function()
						return self:NoticeScale()
					end,
				}),
				Vide.create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),

				InvitePopup({
					Invite = function()
						return self:CurrentInvite()
					end,
					OnAccept = function()
						self:Click()
						self:Answer(true)
					end,
					OnDecline = function()
						self:Click()
						self:Answer(false)
					end,
				}),

				ToastStack({
					Entries = self.Toasts,
					MaxVisible = 2,
					OnDone = function(entry: ToastStack.Entry)
						self:ToastDone(entry)
					end,
				}),
			}),
		})
	end)
	self.Unmount = unmount
	self.Gui = gui
	gui.Parent = playerGui
	-- capacity signs over the squad pads (BillboardGuis in PlayerGui, adorned to local anchor Parts)
	self.Pads = Pads({
		Parent = playerGui,
		Count = PartyRules.Rules.Platforms,
		Members = function(n: number)
			return self:PadMembers(n)
		end,
		Max = function(n: number)
			return self:PadMax(n)
		end,
		State = function(n: number)
			return self:PadState(n)
		end,
		Status = function(n: number)
			return self:PadStatus(n)
		end,
		Leader = function(n: number)
			return self:PadLeader(n)
		end,
		Faces = function(n: number)
			return self:PadFaces(n)
		end,
		Badge = LOBBY.Squad.Pad.Badge,
		OnCount = function(n: number, from: number, to: number)
			self:OnPadCount(n, from, to)
		end,
		Visible = function(n: number)
			return self.Panel() ~= "Classes" and self:MyPad() ~= n
		end,
	})
	-- floating name signs over the Classes / Gems / Codes zones (Signs.luau, owner request 2026-10-20)
	self.Signs = Signs({
		Parent = playerGui,
		Panel = function()
			return self.Panel()
		end,
		Visible = function()
			return self.Panel() ~= "Classes"
		end,
	})
end

-- Lifecycle ---------------------------------------------------------------------------------------------------------

LobbyController:OnInit(function(self)
	self:Setup()
	const net = self.Libs.Net

	-- Listeners in OnInit (before Lync.start); they only fill sources, the UI exists only on lobby servers.
	net.Party:onAdded(function(id, record)
		const copy = table.clone(Vide.untrack(self.Parties))
		copy[id] = record :: any
		self.Parties(copy)
		self:CheckQuickPlay()
	end)
	net.Party:onChanged(function(id, record)
		const copy = table.clone(Vide.untrack(self.Parties))
		copy[id] = record :: any
		self.Parties(copy)
		self:CheckQuickPlay()
	end)
	net.Party:onRemoved(function(id)
		const copy = table.clone(Vide.untrack(self.Parties))
		copy[id] = nil
		self.Parties(copy)
	end)

	-- players online (record 1, lobby roles only; PresenceService)
	net.Online:onAdded(function(_, record)
		self.Online(record.Count)
	end)
	net.Online:onChanged(function(_, record)
		self.Online(record.Count)
	end)

	net.PartyInviteReceived:onClient(function(data)
		if self.Active then
			self:ReceiveInvite(data.From, data.PartyId)
		end
	end)

	net.PartyNotice:onClient(function(data)
		if not self.Active then
			return
		end
		if data.Key == "AlreadyInParty" or data.Key == "TooFast" or data.Key == "WrongServer" then
			self:ClearQuickPlay() -- a quick play refused: the buttons come back
		end
		const line = Text.Party(data.Key, if data.UserId then nameOf(data.UserId) else nil)
		if not line.Quiet then
			self:Toast(line.Text, line.Kind)
		end
	end)

	net.ClassBuyResult:onClient(function(data)
		if self.Active then
			self:OnClassBuyResult(data.Class, data.Reason)
		end
	end)

	net.CodeRedeemResult:onClient(function(data)
		if not self.Active then
			return
		end
		const text = Text.Code(data.Ok, data.Reason, data.Reward.Gems, data.Reward.Class)
		self.CodeFeedback({ Text = text, Kind = if data.Ok then "Good" else "Bad" })
		if data.Ok then
			-- no toast (owner 2026-10-17): the Codes window line says it and the confetti celebrates it
			-- confetti + the buy chime for a redeemed code (owner 2026-10-17)
			self.Dependencies.PurchaseFxController:Show("Code redeemed!", 1.6)
		end
	end)

	-- class Notices (ClassAction Select) answer an Equip
	net.Notice:onClient(function(notice)
		if notice.Kind == "class_selected" or notice.Kind == "class_locked" then
			self:ClearPending()
		end
	end)
end)

LobbyController:OnStart(function(self)
	if not isLobby(self.Dependencies.PlaceController:GetServerRole()) then
		return
	end
	self.Active = true
	self:Bind()
	self:WatchViewport()
	self:WatchRoster()
	self:LoadPrices()
	self:ThirdPerson()
	self:RunZones()
	self:ClearLeftSide()
	-- gift answers (GiftResult) land in the lobby toast column
	self.Dependencies.GiftController:SetToaster(function(text: string, kind: Text.Kind)
		self:Toast(text, kind)
	end)

	-- a skin bought (receipt -> SkinState): toast; the stage shows it when it is the one previewed
	self.Dependencies.SkinController.Granted:Connect(function(key: string)
		const skin = Content.Skins.ByKey[key]
		if skin then
			self:Toast(`{skin.Name} is yours!`, "Good")
		end
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, _bought: boolean)
		if userId ~= Players.LocalPlayer.UserId then
			return
		end
		self.Prompting(false)
		if self.PromptClass ~= "" then
			self.PromptClass = ""
			self:ClearPending()
		end
	end)
	-- class Game Pass (TASK-291): a bought class arrives as ClassBuyResult "Granted" + Profile; a closed prompt ends here
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _passId: number, _bought: boolean)
		if player ~= Players.LocalPlayer then
			return
		end
		self.Prompting(false)
		if self.PromptClass ~= "" then
			self.PromptClass = ""
			self:ClearPending()
		end
	end)

	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end)

return LobbyController
