--!strict

export type Party = {
	Id: number,
	Leader: number,
	Members: { number }, -- party order, leader first after any change of leader
	Ready: { [number]: boolean },
	State: State,
}
type Invite = { From: number, ExpiresAt: number }
type Flight = { Options: TeleportOptions, Tries: number, PartyId: number }
export type State = "Forming" | "Starting"

export type Public = {
	Active: boolean,
	InFlight: { [number]: Flight },
	Invites: { [number]: { [number]: Invite } },
	LastId: number,
	LastInvite: { [string]: number },
	Parties: { [number]: Party },
	PartyOf: { [number]: number },
	RateCount: { [Player]: number },
	RateStart: { [Player]: number },
	Setup: (self: Public) -> (),
	Get: (self: Public, partyId: number) -> Party?,
	PartyOfUser: (self: Public, userId: number) -> Party?,
	PlayersOf: (self: Public, party: Party) -> { Player },
	Allow: (self: Public, player: Player) -> boolean,
	Notice: (self: Public, target: Player | number, key: string, userId: number?) -> (),
	NoticeParty: (self: Public, party: Party, key: string, userId: number?) -> (),
	Publish: (self: Public, party: Party, added: boolean) -> (),
	NewId: (self: Public) -> number,
	Create: (self: Public, leader: number) -> Party?,
	Disband: (self: Public, party: Party) -> (),
	RemoveMember: (self: Public, userId: number, kicked: boolean) -> (),
	Join: (self: Public, party: Party, userId: number) -> (),
	HandleCreate: (self: Public, player: Player) -> (),
	HandleInvite: (self: Public, player: Player, target: number) -> (),
	HandleRespond: (self: Public, player: Player, partyId: number, accept: boolean) -> (),
	HandleLeave: (self: Public, player: Player) -> (),
	HandleKick: (self: Public, player: Player, target: number) -> (),
	HandleReady: (self: Public, player: Player, ready: boolean) -> (),
	HandleStart: (self: Public, player: Player) -> (),
	LaunchData: (self: Public, party: Party) -> { [string]: any },
	Reopen: (self: Public, party: Party, notify: boolean) -> (),
	Launch: (self: Public, party: Party) -> (),
	HandleInitFailed: (self: Public, player: Player, result: Enum.TeleportResult, message: string) -> (),
	Forget: (self: Public, player: Player) -> (),
	Gate: (self: Public, player: Player) -> boolean,
}

return {}
