--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ClassSelect = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect)
local ClassEntries = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassSelect.Entries)
local CodeRedeem = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CodeRedeem)
local GemShop = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GemShop)
local InvitePopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InvitePopup)
local LobbyHud = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.LobbyHud)
local SquadPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SquadPanel)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Stage = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Stage)
local Text = require(StarterPlayer.StarterPlayerScripts.client.Lobby.LobbyController.Text)

export type Panel = "None" | "Classes" | "Shop" | "Codes" | "Squad"
export type PartyRecord = {
	Leader: number,
	Members: { number },
	Ready: { [number]: boolean },
	State: "Forming" | "Starting",
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
	CodeFeedback: Vide.Source<CodeRedeem.Feedback>,
	Entries: { ClassEntries.Entry },
	Focus: Vide.Source<string>,
	FovBefore: number,
	Gui: ScreenGui?,
	Invites: Vide.Source<{ Invite }>,
	Panel: Vide.Source<Panel>,
	Parties: Vide.Source<{ [number]: PartyRecord }>,
	Pending: Vide.Source<string>,
	PendingThread: thread?,
	PlayAfterCreate: number,
	Prices: Vide.Source<{ [number]: number }>,
	PromptClass: string,
	Prompting: Vide.Source<boolean>,
	RigWarned: boolean,
	Roster: Vide.Source<{ Player }>,
	Scale: Vide.Source<number>,
	Sent: Vide.Source<{ [number]: boolean }>,
	Stage: Stage.Stage?,
	StagePoint: CFrame?,
	Toasts: Vide.Source<{ ToastStack.Entry }>,
	Unmount: (() -> ())?,
	WorldStage: Vide.Source<boolean>,
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
	BuildRig: (self: Public, species: string) -> Model?,
	PlayIdle: (self: Public, model: Model) -> (),
	TakeCamera: (self: Public) -> (),
	ReleaseCamera: (self: Public) -> (),
	FindStagePoint: (self: Public) -> CFrame?,
	OpenStage: (self: Public) -> (),
	SpeciesOf: (self: Public, key: string) -> string,
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
	PlayButton: (self: Public) -> LobbyHud.PlayButton,
	PlayStatus: (self: Public) -> string,
	Play: (self: Public) -> (),
	CheckPlayAfterCreate: (self: Public) -> (),
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
