--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)

export type LeaveReason = "Button" | "Move" | "Forced"
export type Leaving = { Index: number, Npc: number, Reason: LeaveReason }
export type Record = {
	State: string, -- "Idle" | "Talking" | "Full"
	Npc: number,
	User: number,
	StartedAt: number,
	EndsAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}
export type MyTalk = {
	Index: number,
	Npc: number,
	Items: { string },
	Reveal: number,
	Text: string,
	Typed: number,
	Caption: string?,
	Style: string,
	Break: number?,
	Speaker: Speaker,
}
export type Clock = { Typed: number, Phase: Content.SpeechPhase }
type Spot = {
	Index: number,
	Record: Vide.Source<Record | false>,
	Odd: Vide.Source<string>, -- rig Variant of an odd customer (DEC-353), "" = ordinary
	Rig: Model?, -- the customer talking at it
	Model: Model?,
	BalloonUnmount: (() -> ())?,
	BalloonGui: Instance?,
	FullUnmount: (() -> ())?,
	FullGui: Instance?,
	LastTyped: number, -- letters typed at the last cue (one talk_key / talk_anomaly each)
	LastReveal: number, -- items popped for me (ticket_pop)
	Spoke: boolean, -- the murmur of this talk played
	Speech: Content.Speech?, -- the running talk's speech (Content.OrderSpeech), nil = not built yet
	SpeechKey: string, -- what it was built from (the talk and the rig's tic attributes)
	TalkKey: string,
}
export type Speaker = "Player" | "Customer"

export type Public = {
	Clock: RBXScriptConnection?,
	CloseTablet: number?,
	CloseToken: number,
	DialogUnmount: (() -> ())?,
	ExitUnbind: (() -> ())?,
	Gui: Instance?,
	Hidden: { [BasePart]: number },
	Holder: Folder?,
	Leaving: SignalLib.Signal<Leaving>,
	Left: number,
	Mine: Vide.Source<number>,
	Now: Vide.Source<number>,
	Spots: { [number]: Spot },
	Tracked: { [Instance]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	Enabled: (self: Public) -> boolean,
	RecordOf: (self: Public, index: number) -> Record?,
	SpeechAt: (self: Public, spot: Spot) -> (Record?, Content.Speech?),
	MyTalk: (self: Public) -> MyTalk?,
	MyClock: (self: Public) -> Clock,
	SpotOf: (self: Public, index: number) -> Spot,
	IsMyTalk: (self: Public, index: number, record: Record | false) -> boolean,
	WriteRecord: (self: Public, index: number, record: Record?) -> (),
	HideBetween: (self: Public, eye: Vector3, rig: Model, head: BasePart, scope: Instance?) -> (),
	ReleaseCloseUp: (self: Public) -> (),
	UnbindExit: (self: Public) -> (),
	Leave: (self: Public, reason: LeaveReason?) -> (),
	SyncCloseUp: (self: Public, now: boolean?) -> (),
	Anchor: (self: Public, spot: Spot) -> Instance?,
	Present: (self: Public, spot: Spot) -> (),
	DropBalloons: (self: Public, spot: Spot) -> (),
	Cue: (self: Public, spot: Spot, now: number) -> (),
	RunClock: (self: Public) -> (),
	MountDialog: (self: Public, gui: Instance) -> (),
	Bind: (self: Public, instance: Instance) -> (),
	Track: (self: Public, instance: Instance) -> (),
	Untrack: (self: Public, instance: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
