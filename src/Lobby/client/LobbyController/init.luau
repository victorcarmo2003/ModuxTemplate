--!strict
--[[
	LobbyController (user request 2026-10-11, Provisional; architecture.md §20; network.md §15, §16)

	The lobby UI. Only on lobby servers: ReplicatedStorage attribute "ServerRole" = "Lobby" / "PrivateLobby" (read by
	PlaceController:GetServerRole(), which waits for it; missing = "Game"), or Workspace "ServerRole" = "Lobby" as a
	Studio override. Elsewhere nothing is bound or mounted.

	Layout (user request 2026-10-12): ALL the lobby UI is on the RIGHT (gem pill + tiles column at the top right, 2 x 2 grid
	on short screens), the squad status card and the Play button at the bottom centre; the LEFT stays free for the Roblox
	menu and chat (the Roblox player list is turned off in the lobby: the squad panel lists the players). The windows are
	centred full-screen modals over a dim backdrop and hide the HUD, so nothing sits over another screen: opening one
	closes the previous (one Panel), the Roblox menu (Esc) closes it too, and a window shrinks to fit a narrow screen.
	Toasts and the invite popup share one column at the top centre.

	Screens (Interface/Components; one open at a time, input context "Menu" while open):
	  LobbyHud      gem balance (opens the shop), tiles Classes · Shop · Codes · Squad, a status card (Solo / Squad
	                n/4, members, Friends only) over the big Play button (PLAY green · START SQUAD mustard · READY)
	  ClassSelect   every class (Content.Classes): list, card with perks / drawbacks, Buy with Gems / Buy with Robux /
	                Equip. The rig stands in the middle: on the MapPoint LOBBY-CLASS-STAGE with the camera locked in
	                front of it when the map has one (Stage.luau, CameraController External), else in a ClassStage
	                viewport. Slow swing, pop on swap, crew_idle when its id exists
	  GemShop       Content.Shop.GemPacks; the button calls MarketplaceService:PromptProductPurchase (ShopService
	                credits the gems on the receipt; the Profile packet brings the new balance)
	  CodeRedeem    CodeRedeem packet -> CodeRedeemResult (ok / invalid / expired / already used)
	  SquadPanel    the Party set (my squad = the record whose Members has my UserId), invite the players of this
	                server, kick (leader), Ready, Start (leader), Leave; InvitePopup for PartyInviteReceived
	  PlayChoice    what Play opens outside a squad: Play Solo · Create Squad (PartyQuickPlay)
	Feedback toasts (top right) for ClassBuyResult, CodeRedeemResult and PartyNotice; texts in Text.luau.

	Client presents, server decides: gems, owned classes and the selection come from the Profile packet
	(ProfileController); a class is bought with ClassBuy (Gems: the server debits; Robux: the server pre-checks and
	answers "Prompt", then this client prompts Content.Shop.ClassProducts[key].ProductId and ShopService grants on the
	receipt); Equip is the existing ClassAction "Select". Squad state is only what the Party set says.

	Play (user request 2026-10-11, Provisional; network.md §16.7): outside a squad it opens PlayChoice:
	  Play Solo     PartyQuickPlay { Mode = "Solo" }: the server creates a squad of one and starts it at once (normal
	                countdown, then the teleport; Studio answers StudioNoTeleport and drops the squad). The choice
	                closes; the HUD shows "Starting in n..." over the Play button.
	  Create Squad  PartyQuickPlay { Mode = "Squad" }: an open invite squad (no platform); as soon as it arrives the
	                setup window (SquadSetup) opens: Friends only, Max players, Invite players (-> SquadPanel), Leave,
	                Start. No need to walk to a platform; stepping on a free one takes the squad there.
	In a squad, Play opens the setup window of my squad (Start for the leader, Ready for invite squad members).

	Zones (user request 2026-10-11, Provisional; Content.Lobby, shared.Lobby.LobbyZones): every lobby zone is a floor
	Part of the map tagged "LobbyZone" (attribute Zone = Classes / Shop / Codes / Squad1..4; circle on a disc, oriented
	rectangle otherwise; Content position as fallback). Walking in opens its panel,
	walking out closes it (only if that panel is still the open one); checked every Trigger.Poll s from the own
	HumanoidRootPart, with hysteresis. The HUD tiles and keys stay as shortcuts. A panel closed by hand stays closed
	until the player walks out and in again.
	  SquadSetup    the setup window (Panel "Platform"): my squad (platform or invite), else the squad on the platform
	                the player stands on; Friends only, Max players, Start (leader) or the countdown; invite squads add
	                Ready (members), Invite players and Leave. Joining / leaving a platform is the server's
	                (PartyService watches the platforms); this client sends PartyConfigure / PartyStart / PartyReady /
	                PartyLeave. Opened by Play too; closes by itself when there is no squad left to show.
	Pad signs (Pads.luau + Interface/Components/PadTag): over every squad pad a studs-sized sign "SQUAD n", four slots,
	"n/4" and the state (Open / Room for n / Friends only / Full / Starting in 3...), green free, yellow taken, red full,
	all read from the Party set (Platform, Members, MaxPlayers, StartAt).
	Zone VFX (Rings.luau): local Neon frames on the floor edges (square / ring) with rising ghost frames, one Heartbeat
	for every zone; platform colours follow the Party set (free / squad / starting).
	Camera: normal third person in the lobby (CameraController External; CameraMode Classic). While the class screen
	shows the world stage every character is hidden locally (LocalTransparencyModifier; LOBBY.md §11).

	Binds (InputController; touch = the HUD tiles and buttons, >= 44 px):
	  Classes C / ButtonY · Shop B / DPadUp · Codes K / DPadLeft · Squad P / DPadRight · Play Return / DPadDown
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
local ClassSelect = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect)
local ClassEntries = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.Entries)
local ClassStage = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassStage)
local CodeRedeem = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CodeRedeem)
local GemShop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GemShop)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InvitePopup)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.LobbyHud)
local PlayChoice = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlayChoice)
local SquadPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadPanel)
local SquadSetup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadSetup)
local SquadStatus = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadStatus)
local PadTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PadTag)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Pads = require(script.Pads)
local Rings = require(script.Rings)
local Stage = require(script.Stage)
local Text = require(script.Text)

export type Panel = "None" | "Classes" | "Shop" | "Codes" | "Squad" | "Platform" | "Play"

export type PartyRecord = {
	Leader: number,
	Members: { number },
	Ready: { [number]: boolean },
	State: "Forming" | "Configuring" | "Starting",
	Platform: number,
	FriendsOnly: boolean,
	MaxPlayers: number,
	StartAt: number,
}

export type Invite = {
	PartyId: number,
	From: number,
	Name: string,
	At: number,
}

const STAGE_POINT = "LOBBY-CLASS-STAGE"
const OUTFIT = "crew"
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
const CLOSE = "LobbyClose"
const PREVIOUS = "LobbyPrevious"
const NEXT = "LobbyNext"
-- Notices column (invite popup + toasts), top centre: px from the top; on a narrow screen under the HUD column
const NOTICE_TOP = 8
const NOTICE_TOP_NARROW = 290
const NARROW_VIEWPORT = 420
const BIND_PRIORITY = 10 -- over ClassController's Crew toggle (priority 0) on C / ButtonY

-- First button a gamepad selects when a panel opens (by instance name, searched in the panel).
const FIRST_SELECTION: { [Panel]: { string } } = {
	None = { "Play" },
	Classes = {}, -- the focused class row (its name is the class key)
	Shop = { "Buy" },
	Codes = { "Redeem" },
	Squad = { "Start", "Ready", "Create", "Invite" },
	Platform = { "Start", "Ready", "Toggle", "Leave" },
	Play = { "Solo", "Squad" },
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

local function isLobby(placeRole: Roles.Role): boolean
	if Roles.IsLobby(placeRole) then
		return true
	end
	return workspace:GetAttribute(Roles.Attribute) == "Lobby"
end

local function nameOf(userId: number): string
	const player = Players:GetPlayerByUserId(userId)
	return if player then player.DisplayName else "Player"
end

const LobbyController = Modux.Controller("LobbyController", {
	Require = {
		"PlaceController",
		"ProfileController",
		"InputController",
		"AudioController",
		"AnimController",
		"CameraController",
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

	-- classes
	self.Entries = ClassEntries.Build() :: { ClassEntries.Entry }
	self.Focus = Vide.source("class_dog") :: Vide.Source<string>
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
	self.Pads = nil :: Pads.Pads?
	self.Hiding = false :: boolean

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

-- Robux price shown for a class (live Creator Hub price when known); nil = no product yet.
function LobbyController:RobuxOf(key: string): number?
	const suggested, productId = ClassEntries.Robux(key)
	if suggested == nil then
		return nil
	end
	return self.Prices()[productId] or suggested
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
		-- Robux pre-check passed: prompt the class product; the receipt answers "Granted" / "Converted" later.
		const product = Content.Shop.ClassProducts.ByKey[class]
		if product and product.ProductId > 0 then
			self.PromptClass = class
			const ok, err = pcall(function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.ProductId)
			end)
			if ok then
				return -- pending until PromptProductPurchaseFinished
			end
			warn(`[LobbyController] PromptProductPurchase failed: {err}`)
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

-- Local preview rig: never tagged (RigController leaves it alone), dressed once here.
function LobbyController:BuildRig(species: string): Model?
	const ok, result = pcall(function(): Model
		const model = CrewRig.Build(species, OUTFIT, {
			Tag = false,
			Anchored = true,
			Name = `LobbyClass_{species}`,
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

function LobbyController:HideCharacters(on: boolean)
	if on == self.Hiding then
		return
	end
	self.Hiding = on
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
			Build = function(species: string): Model?
				return self:BuildRig(species)
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
	for _, product in Content.Shop.ClassProducts.List do
		if product.ProductId > 0 then
			table.insert(ids, product.ProductId)
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
			Ready = party.Ready[userId] == true or userId == party.Leader,
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

function LobbyController:AllReady(party: PartyRecord): boolean
	for _, userId in party.Members do
		if userId ~= party.Leader and party.Ready[userId] ~= true then
			return false
		end
	end
	return true
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

function LobbyController:PlayButton(): LobbyHud.PlayButton
	const _, party = self:MyParty()
	if party == nil then
		return if self.QuickPending()
			then { Text = "...", Kind = "Off", Enabled = false }
			else { Text = "PLAY", Kind = "Go", Enabled = true }
	end
	if party.State == "Starting" then
		return { Text = "STARTING...", Kind = "Go", Enabled = true }
	end
	const me = Players.LocalPlayer.UserId
	if party.Leader == me then
		return { Text = "START SQUAD", Kind = "Wait", Enabled = true }
	end
	return if party.Ready[me] == true
		then { Text = "READY!", Kind = "Go", Enabled = true }
		else { Text = "READY", Kind = "Wait", Enabled = true }
end

function LobbyController:PlayStatus(): string
	const _, party = self:MyParty()
	if party == nil then
		return if self.QuickPending() then "Starting..." else "Pick solo or squad"
	end
	if party.State == "Starting" then
		if party.StartAt <= 0 then
			return ""
		end
		const left = party.StartAt - self.Clock()
		return if left > 0 then `Starting in {math.ceil(left)}...` else "Here we go!"
	end
	local waiting = 0
	for _, userId in party.Members do
		if userId ~= party.Leader and party.Ready[userId] ~= true then
			waiting += 1
		end
	end
	if waiting == 0 then
		return if #party.Members > 1 then "Everyone is ready!" else "Invite your friends"
	end
	return if waiting == 1 then "Waiting for 1 player" else `Waiting for {waiting} players`
end

-- Status card over the Play button: alone ("Solo") or in a squad ("Squad 2/4"), who is in it, Friends only.
function LobbyController:PlayCard(): SquadStatus.Info
	const _, party = self:MyParty()
	const me = Players.LocalPlayer.UserId
	if party == nil then
		return {
			Squad = false,
			Members = { { UserId = me, Leader = true, Ready = true } },
			Max = 1,
			FriendsOnly = false,
			Status = self:PlayStatus(),
		}
	end
	const members: { SquadStatus.Member } = {}
	for _, userId in party.Members do
		table.insert(members, {
			UserId = userId,
			Leader = userId == party.Leader,
			Ready = party.Ready[userId] == true or userId == party.Leader,
		})
	end
	-- a squad of one that is already starting is a solo run (Play Solo)
	const solo = #members == 1 and party.State == "Starting"
	return {
		Squad = not solo,
		Members = members,
		Max = if solo then 1 else math.max(party.MaxPlayers, #members),
		FriendsOnly = party.FriendsOnly and not solo,
		Status = self:PlayStatus(),
	}
end

-- Play button: outside a squad the choice (Play Solo / Create Squad); in a squad its setup window.
function LobbyController:Play()
	-- event handlers run outside any reactive scope: plain reads
	const id = self:MyParty()
	if id == nil then
		if not Vide.untrack(self.QuickPending) then
			self:SetPanel("Play")
		end
		return
	end
	self:SetPanel("Platform")
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
		self:SetPanel("Platform")
		return
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
	const panel = Vide.untrack(self.Panel)
	if self.QuickMode == "Squad" and (panel == "Play" or panel == "None") then
		self:SetPanel("Platform")
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
			-- invite squads only: platform members are ready by standing there
			Ready = if party.Platform == 0 and userId ~= party.Leader then party.Ready[userId] == true else nil,
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

function LobbyController:Configure(friendsOnly: boolean, maxPlayers: number)
	self.Libs.Net.PartyConfigure:fireServer({
		FriendsOnly = friendsOnly,
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
	return if party then math.max(party.MaxPlayers, #party.Members) else PartyRules.Rules.MaxSize
end

function LobbyController:PadState(n: number): PadTag.State
	const party = self:PlatformParty(n)
	if party == nil then
		return "Open"
	elseif party.State == "Starting" then
		return "Starting"
	end
	return if #party.Members >= math.max(party.MaxPlayers, 1) then "Full" else "Busy"
end

function LobbyController:PadStatus(n: number): string
	const party = self:PlatformParty(n)
	if party == nil then
		return "OPEN"
	end
	if party.State == "Starting" then
		if party.StartAt <= 0 then
			return "STARTING..."
		end
		const left = party.StartAt - self.Clock()
		return if left > 0 then `STARTING IN {math.ceil(left)}...` else "GO!"
	end
	const free = math.max(party.MaxPlayers - #party.Members, 0)
	if free == 0 then
		return "FULL"
	end
	return if party.FriendsOnly then "FRIENDS ONLY" else `ROOM FOR {free}`
end

-- Ring colour of each platform: free / owned by a squad (someone is setting it up) / starting.
function LobbyController:PaintPlatforms()
	const rings = self.Rings
	if rings == nil then
		return
	end
	const colors = LOBBY.Squad.Colors
	for n = 1, PartyRules.Rules.Platforms do
		const party = self:PlatformParty(n)
		const color = if party == nil
			then colors.Free
			elseif party.State == "Starting" then colors.Starting
			else colors.Busy
		rings.SetColor(`Squad{n}`, color)
	end
end

-- Zones -------------------------------------------------------------------------------------------------------------

function LobbyController:OnZone(zone: LobbyZones.Zone, inside: boolean)
	if zone.Platform > 0 then
		if inside then
			self.Standing(zone.Platform)
		elseif Vide.untrack(self.Standing) == zone.Platform then
			self.Standing(0)
		end
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
		const pads = self.Pads
		if pads then
			pads.Step()
		end
		const now = os.clock()
		if now >= nextZones then
			nextZones = now + LOBBY.Trigger.Poll
			self:CheckZones()
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
	return math.max(math.min(self.Scale(), UiScale.Current()), Theme.Scale.Min)
end

-- The left side stays free for the Roblox menu and chat: the player list (top right on desktop, under our column) is off
-- in the lobby, and the Roblox menu (Esc) closes the open window so the two never stack.
function LobbyController:ClearLeftSide()
	const ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
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
			if descendant.Name == name and descendant:IsA("GuiButton") and descendant.Visible then
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
		self.Focus(self.Dependencies.ProfileController.Selected())
		self:OpenStage()
	end
	if panel == "Codes" and Vide.untrack(self.CodeFeedback).Kind ~= "Wait" then
		self.CodeFeedback({ Text = "", Kind = "None" })
	end
	self.Panel(panel)
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
			if self:PlayButton().Enabled then
				self:Click()
				self:Play()
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
		-- A Profile packet answers a class request: whatever it says, the buttons come back.
		Vide.effect(function()
			profile.Classes()
			profile.Selected()
			profile.Gems()
			Vide.untrack(function()
				if self.PromptClass == "" then
					self:ClearPending()
				end
				return nil
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

		-- The setup window opened by Play closes when there is no squad to show anymore (left, solo run over)
		Vide.effect(function()
			const panel = self.Panel()
			const party = self:SetupParty()
			Vide.untrack(function()
				if panel == "Platform" and party == nil and self.Standing() == 0 then
					self:SetPanel("None")
				end
				return nil
			end)
		end)

		-- Class swap on the world stage
		Vide.effect(function()
			const key = self.Focus()
			const open = self.Panel() == "Classes" and self.WorldStage()
			Vide.untrack(function()
				const stage = self.Stage
				if open and stage then
					stage.Show(self:SpeciesOf(key))
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
			IgnoreGuiInset = false,
			ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
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
				Card = function()
					return self:PlayCard()
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
				Scale = self.Scale,
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
						self.Focus(key)
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
				OnClose = close,
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
				OnReady = function(ready: boolean)
					self:Click()
					self.Libs.Net.PartyReady:fireServer({ Ready = ready })
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
				FriendsOnly = function()
					const party = self:SetupParty()
					return party ~= nil and party.FriendsOnly
				end,
				MaxPlayers = function()
					const party = self:SetupParty()
					return if party then party.MaxPlayers else PartyRules.Rules.DefaultMaxPlayers
				end,
				MaxSize = PartyRules.Rules.MaxSize,
				Countdown = function()
					return self:Countdown()
				end,
				CanStart = function()
					const party = self:SetupParty()
					return party ~= nil and party.State ~= "Starting" and self:AllReady(party)
				end,
				OnFriendsOnly = function(on: boolean)
					self:Click()
					const party = self:SetupParty()
					if party then
						self:Configure(on, party.MaxPlayers)
					end
				end,
				OnMaxPlayers = function(count: number)
					self:Click()
					const party = self:SetupParty()
					if party then
						self:Configure(party.FriendsOnly, count)
					end
				end,
				OnStart = function()
					self:Click()
					self.Libs.Net.PartyStart:fireServer()
				end,
				OnClose = close,
				Scale = self.Scale,
				Invite = function()
					const party = self:SetupParty()
					return party ~= nil and party.Platform == 0
				end,
				Ready = function()
					const party = self:SetupParty()
					return party ~= nil and party.Ready[Players.LocalPlayer.UserId] == true
				end,
				OnReady = function(ready: boolean)
					self:Click()
					self.Libs.Net.PartyReady:fireServer({ Ready = ready })
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

			-- Notices column, top centre (clear of the right-hand HUD): the invite popup, the toasts under it. One UIScale.
			-- On a narrow screen it steps down under the HUD column instead of running into it.
			Vide.create("Frame")({
				Name = "Notices",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = function()
					const narrow = self.Viewport().X < NARROW_VIEWPORT
					return UDim2.new(0.5, 0, 0, if narrow then NOTICE_TOP_NARROW * self:NoticeScale() else NOTICE_TOP)
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
		self:Toast(line.Text, line.Kind)
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
			self:Toast(text, "Good")
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

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, _productId: number, _bought: boolean)
		if userId ~= Players.LocalPlayer.UserId then
			return
		end
		self.Prompting(false)
		if self.PromptClass ~= "" then
			-- a bought class arrives with the receipt (ClassBuyResult "Granted" + Profile); a closed prompt ends here
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
