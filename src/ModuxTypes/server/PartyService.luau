--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartyRules = require(ReplicatedStorage.shared.Party.PartyRules)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type Party = {
	Id: number,
	Leader: number,
	Members: { number }, -- party order, leader first after any change of leader
	Ready: { [number]: boolean },
	State: State,
	Platform: number, -- 1..8 = owns LOBBY-SQUAD-n; 0 = invite squad
	Access: string, -- PartyRules.Access: "Setup" (private, being set up) | "Open" | "Friends" | "Invite" | "Closed"
	MaxPlayers: number, -- 1..Rules.MaxSize, never below #Members when set
	StartAt: number, -- workspace:GetServerTimeNow() of the teleport; 0 = no countdown
	Launched: boolean, -- countdown over: reserve / teleport running
	Solo: boolean, -- quick play "Solo": disbanded instead of going back to the idle state
	Token: number, -- bumped by every Begin and Cancel: a countdown thread only fires for the token it was born with
}
type Invite = { From: number, ExpiresAt: number }
type Flight = { Options: TeleportOptions, Tries: number, PartyId: number }
export type State = "Forming" | "Configuring" | "Starting"

export type Public = {
	Active: boolean,
	Checking: { [number]: boolean },
	InFlight: { [number]: Flight },
	Invites: { [number]: { [number]: Invite } },
	LastId: number,
	LastInvite: { [string]: number },
	OnPlatform: { [number]: number },
	Parties: { [number]: Party },
	PartyOf: { [number]: number },
	PollAt: number,
	RateCount: { [Player]: number },
	RateStart: { [Player]: number },
	Refused: { [number]: number },
	Tracked: SignalLib.Signal<string, Party, number, string>,
	Setup: (self: Public) -> (),
	Get: (self: Public, partyId: number) -> Party?,
	PartyOfUser: (self: Public, userId: number) -> Party?,
	PlayersOf: (self: Public, party: Party) -> { Player },
	PartyOnPlatform: (self: Public, platform: number) -> Party?,
	Allow: (self: Public, player: Player) -> boolean,
	Notice: (self: Public, target: Player | number, key: string, userId: number?) -> (),
	NoticeParty: (self: Public, party: Party, key: string, userId: number?) -> (),
	Publish: (self: Public, party: Party, added: boolean) -> (),
	NewId: (self: Public) -> number,
	Create: (self: Public, leader: number, platform: number, access: string) -> Party?,
	Disband: (self: Public, party: Party) -> (),
	RemoveMember: (self: Public, userId: number, kicked: boolean) -> (),
	Join: (self: Public, party: Party, userId: number, ready: boolean) -> (),
	Leave: (self: Public, userId: number) -> (),
	HandleCreate: (self: Public, player: Player) -> (),
	HandleInvite: (self: Public, player: Player, target: number) -> (),
	HandleRespond: (self: Public, player: Player, partyId: number, accept: boolean) -> (),
	HandleLeave: (self: Public, player: Player) -> (),
	HandleKick: (self: Public, player: Player, target: number) -> (),
	HandleReady: (self: Public, player: Player, ready: boolean) -> (),
	HandleConfigure: (self: Public, player: Player, requested: string, maxPlayers: number) -> (),
	HandleStart: (self: Public, player: Player) -> (),
	Begin: (self: Public, party: Party) -> (),
	HandleCancel: (self: Public, player: Player) -> (),
	HandleQuickPlay: (self: Public, player: Player, mode: string) -> (),
	LaunchData: (self: Public, party: Party) -> { [string]: any },
	Fire: (self: Public, party: Party) -> (),
	Reopen: (self: Public, party: Party, notify: boolean) -> (),
	Launch: (self: Public, party: Party) -> (),
	HandleInitFailed: (self: Public, player: Player, result: Enum.TeleportResult, message: string) -> (),
	PlatformOf: (self: Public, player: Player, was: number) -> number,
	CanJoinPlatform: (self: Public, party: Party, platform: number) -> string?,
	JoinPlatform: (self: Public, player: Player, party: Party) -> (),
	Refuse: (self: Public, player: Player, platform: number, key: string) -> (),
	EnterPlatform: (self: Public, player: Player, platform: number) -> (),
	ExitPlatform: (self: Public, player: Player, platform: number) -> (),
	PollPlatforms: (self: Public) -> (),
	Forget: (self: Public, player: Player) -> (),
	Gate: (self: Public, player: Player) -> boolean,
}

return {}
