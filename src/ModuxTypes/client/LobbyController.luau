--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local ClassSelect = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect)
local ClassEntries = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.Entries)
local CodeRedeem = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CodeRedeem)
local GemShop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GemShop)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InvitePopup)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.LobbyHud)
local PlayChoice = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlayChoice)
local SquadPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadPanel)
local SquadSetup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadSetup)
local PadTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PadTag)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Pads = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Pads)
local Signs = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Signs)
local Rings = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Rings)
local Extras = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Extras)
local Stage = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Stage)
local Text = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Text)

export type Panel = "None" | "Classes" | "Shop" | "Codes" | "Squad" | "Platform" | "Play"
export type PartyRecord = {
	Leader: number,
	Members: { number },
	Ready: { [number]: boolean },
	State: "Forming" | "Configuring" | "Starting",
	Platform: number,
	Access: string, -- PartyRules.Access
	MaxPlayers: number,
	StartAt: number,
}
export type Draft = {
	Access: string,
	MaxPlayers: number,
}
export type Invite = {
	PartyId: number,
	From: number,
	Name: string,
	At: number,
}

export type Public = {
	Active: boolean,
	CameraBefore: string?,
	Clock: Vide.Source<number>,
	CodeFeedback: Vide.Source<CodeRedeem.Feedback>,
	Draft: Vide.Source<Draft>,
	DraftParty: number,
	Entries: { ClassEntries.Entry },
	Extras: Extras.Extras?,
	Focus: Vide.Source<string>,
	FovBefore: number,
	Gui: ScreenGui?,
	Hiding: boolean,
	Invites: Vide.Source<{ Invite }>,
	Online: Vide.Source<number>,
	Pads: Pads.Pads?,
	Panel: Vide.Source<Panel>,
	Parties: Vide.Source<{ [number]: PartyRecord }>,
	Pending: Vide.Source<string>,
	PendingThread: thread?,
	Prices: Vide.Source<{ [number]: number }>,
	PromptClass: string,
	Prompting: Vide.Source<boolean>,
	QuickAt: number,
	QuickMode: PlayChoice.Choice,
	QuickPending: Vide.Source<boolean>,
	RigWarned: boolean,
	Rings: Rings.Rings?,
	Roster: Vide.Source<{ Player }>,
	Scale: Vide.Source<number>,
	Sent: Vide.Source<{ [number]: boolean }>,
	Signs: Signs.Signs?,
	SkinFocus: Vide.Source<string>,
	Stage: Stage.Stage?,
	StagePoint: CFrame?,
	Standing: Vide.Source<number>,
	Toasts: Vide.Source<{ ToastStack.Entry }>,
	Unmount: (() -> ())?,
	Viewport: Vide.Source<Vector2>,
	WorldStage: Vide.Source<boolean>,
	ZoneInside: { [string]: boolean },
	Setup: (self: Public) -> (),
	Toast: (self: Public, text: string, kind: Text.Kind) -> (),
	ToastDone: (self: Public, entry: ToastStack.Entry) -> (),
	Click: (self: Public) -> (),
	StateOf: (self: Public, key: string) -> ClassSelect.State,
	RobuxOf: (self: Public, key: string) -> number?,
	Busy: (self: Public) -> boolean,
	ClearPending: (self: Public) -> (),
	SetPending: (self: Public, key: string) -> (),
	BuyClass: (self: Public, key: string, currency: "Gems" | "Robux") -> (),
	Equip: (self: Public, key: string) -> (),
	OnClassBuyResult: (self: Public, class: string, reason: string) -> (),
	Step: (self: Public, delta: number) -> (),
	BuildRig: (self: Public, species: string, skin: string?) -> Model?,
	PlayIdle: (self: Public, model: Model) -> (),
	TakeCamera: (self: Public) -> (),
	HideCharacters: (self: Public, on: boolean) -> (),
	ReleaseCamera: (self: Public) -> (),
	FindStagePoint: (self: Public) -> CFrame?,
	OpenStage: (self: Public) -> (),
	SpeciesOf: (self: Public, key: string) -> string,
	FocusClass: (self: Public, key: string) -> (),
	SkinEntries: (self: Public, class: string) -> { ClassSelect.SkinEntry },
	SkinStateOf: (self: Public, key: string) -> ClassSelect.SkinState,
	EquipSkin: (self: Public, key: string) -> (),
	SkinBanner: (self: Public) -> string,
	Packs: (self: Public) -> { GemShop.Pack },
	BuyPack: (self: Public, key: string) -> (),
	LoadPrices: (self: Public) -> (),
	MyParty: (self: Public) -> (number?, PartyRecord?),
	Members: (self: Public) -> { SquadPanel.Member },
	Candidates: (self: Public) -> { SquadPanel.Candidate },
	IsLeader: (self: Public) -> boolean,
	AllReady: (self: Public, party: PartyRecord) -> boolean,
	Invite: (self: Public, userId: number) -> (),
	Answer: (self: Public, accept: boolean) -> (),
	CurrentInvite: (self: Public) -> InvitePopup.Invite?,
	ReceiveInvite: (self: Public, from: number, partyId: number) -> (),
	CanCancel: (self: Public) -> boolean,
	Cancel: (self: Public) -> (),
	CancelKey: (self: Public) -> string,
	PlayShown: (self: Public) -> boolean,
	PlayButton: (self: Public) -> LobbyHud.PlayButton,
	GearShown: (self: Public) -> boolean,
	Play: (self: Public) -> (),
	ClearQuickPlay: (self: Public) -> (),
	QuickPlay: (self: Public, choice: PlayChoice.Choice) -> (),
	CheckQuickPlay: (self: Public) -> (),
	PlatformParty: (self: Public, n: number) -> PartyRecord?,
	SetupParty: (self: Public) -> PartyRecord?,
	SetupMembers: (self: Public) -> { SquadSetup.Member },
	Drafting: (self: Public) -> boolean,
	CheckDraft: (self: Public, id: number, record: PartyRecord) -> (),
	CreateRoom: (self: Public) -> (),
	Countdown: (self: Public) -> number?,
	Configure: (self: Public, access: string, maxPlayers: number) -> (),
	PadMembers: (self: Public, n: number) -> number,
	PadMax: (self: Public, n: number) -> number,
	PadState: (self: Public, n: number) -> PadTag.State,
	PadStatus: (self: Public, n: number) -> string,
	PadLeader: (self: Public, n: number) -> string,
	PadFaces: (self: Public, n: number) -> { number },
	PaintPlatforms: (self: Public) -> (),
	OnPadCount: (self: Public, n: number, _from: number, _to: number) -> (),
	OnZone: (self: Public, zone: LobbyZones.Zone, inside: boolean) -> (),
	CheckZones: (self: Public) -> (),
	RunZones: (self: Public) -> (),
	ThirdPerson: (self: Public) -> (),
	NoticeScale: (self: Public) -> number,
	ClearLeftSide: (self: Public) -> (),
	SelectFirst: (self: Public, panel: Panel) -> (),
	SetPanel: (self: Public, panel: Panel) -> (),
	Toggle: (self: Public, panel: Panel) -> (),
	DeviceKeys: (self: Public) -> { [string]: string },
	Bind: (self: Public) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	WatchRoster: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
