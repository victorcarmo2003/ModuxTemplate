--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Life = require(ServerScriptService.server.Vital.VitalService.Life)
local Sanity = require(ServerScriptService.server.Vital.VitalService.Sanity)

export type LifeState = Life.State
export type LifeEventKind = "Down" | "Revived" | "Spectating" | "Hit" | "Wipe" | "WipeCleared"
export type PickupHandler = (userId: number, bodyPos: Vector3?) -> ()
export type Entry = {
	UserId: number,
	-- night token the entry belongs to (0 = day, no sanity)
	Night: number,
	-- class start values still to apply (member was not in the server at the night start)
	Fresh: boolean,
	Sanity: number,
	Max: number,
	DarkSince: number?,
	ProtectUntil: number,
	CoffeeReadyAt: number,
	-- Night 1 coffee lesson: server time the HUD emphasis ends (0 = none running); see StartCoffeeHint
	HintUntil: number,
	RevivesTonight: number,
	Seen: { [string]: boolean },
	StateEndsAt: number,
	KnockedUntil: number,
	Band: Band,
	Pending: Band?,
	PendingSince: number,
	SentValue: number,
	SentMax: number,
	LastCause: string,
}
export type Band = Sanity.Band

export type Public = {
	DevGodMode: boolean,
	DevLit: boolean?,
	Enabled: boolean,
	Entries: { [number]: Entry },
	LastFallen: number,
	Live: boolean,
	MemberStateChanged: SignalLib.Signal<number, LifeState, LifeState>,
	NextDarkAt: number,
	Night: number,
	NightSerial: number,
	PickupHandler: PickupHandler?,
	Published: { [number]: boolean },
	WarnedLight: boolean,
	Wipe: SignalLib.Signal<boolean, number>,
	WipeEndsAt: number,
	WipeQueued: boolean,
	Setup: (self: Public) -> (),
	EntryOf: (self: Public, userId: number) -> Entry,
	Ensure: (self: Public, player: Player) -> Entry,
	GetSanity: (self: Public, player: Player) -> (number, number),
	GetState: (self: Public, userId: number) -> LifeState?,
	IsActive: (self: Public, player: Player) -> boolean,
	IsKnocked: (self: Public, player: Player) -> boolean,
	Counts: (self: Public) -> (number, number),
	Verdict: (self: Public) -> boolean,
	IsLit: (self: Public, position: Vector3) -> boolean,
	ClassOf: (self: Public, userId: number, class: string) -> string,
	Publish: (self: Public, userId: number) -> (),
	SendSanity: (self: Public, player: Player, force: boolean) -> (),
	FireLife: (self: Public, userId: number, event: LifeEventKind) -> (),
	ApplyLook: (self: Public, userId: number) -> (),
	RefreshBand: (self: Public, userId: number, immediate: boolean) -> (),
	AddSanity: (self: Public, player: Player, delta: number, cause: string) -> number,
	Penalize: (self: Public, player: Player, cause: string) -> number,
	SeeAnomaly: (self: Public, player: Player, key: string) -> boolean,
	SetKnocked: (self: Public, player: Player, untilT: number) -> (),
	SetPickupHandler: (self: Public, handler: PickupHandler) -> (),
	DefaultPickup: (self: Public, userId: number, _bodyPos: Vector3?) -> (),
	Pickup: (self: Public, userId: number, bodyPos: Vector3?) -> (),
	Fall: (self: Public, player: Player, forced: LifeState?) -> (),
	EndDowns: (self: Public) -> (),
	OnLifeChanged: (self: Public, userId: number, old: LifeState, new: LifeState) -> (),
	QueueWipe: (self: Public) -> (),
	EvaluateWipe: (self: Public) -> (),
	CloseWipe: (self: Public, cleared: boolean) -> (),
	ExpireWipe: (self: Public) -> (),
	OnShiftStarted: (self: Public, info: { IsNight: boolean }) -> (),
	OnPhase: (self: Public, phase: string) -> (),
	OnJoined: (self: Public, player: Player) -> (),
	DarkTick: (self: Public, t: number) -> (),
	Step: (self: Public) -> (),
	RestoreOf: (self: Public, player: Player, tool: Tool) -> number,
	CanDrink: (self: Public, player: Player, _tool: Tool) -> (boolean, string?),
	Drink: (self: Public, player: Player, tool: Tool) -> (),
	SendCue: (self: Public, player: Player, kind: "Hint" | "Gain" | "End", amount: number, untilT: number) -> (),
	EndHint: (self: Public, player: Player, entry: Entry) -> (),
	StartCoffeeHint: (self: Public, callLeft: number) -> number,
	ResendHint: (self: Public, player: Player) -> (),
	StepHints: (self: Public, t: number, over: boolean) -> (),
	DevSetSanity: (self: Public, player: Player, value: number) -> number,
	DevFall: (self: Public, player: Player, state: LifeState?) -> (),
	DevDark: (self: Public, mode: boolean?) -> (),
	DevGod: (self: Public, on: boolean) -> (),
	IsDevGod: (self: Public) -> boolean,
	DevDarkMode: (self: Public) -> number,
	DevRevive: (self: Public, player: Player) -> string,
}

return {}
