--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Record = {
	State: string, -- "Idle" | "Talking" | "Full" | "Deciding"
	Npc: number,
	User: number,
	StartedAt: number,
	EndsAt: number,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
}
export type Talk = {
	Steps: { Step },
	Items: { string }, -- ingredient keys in the order they are said
	Base: number, -- s of the script without speed-ups (Open + Lead + PerItem x items + PairExtra + Confirm)
}
export type MyTalk = { Index: number, Npc: number, Items: { string }, Reveal: number, Step: Step, Deciding: boolean }
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
	LastStep: number, -- index of the last step heard (blip), 0 = none
	LastReveal: number, -- items popped for me (ticket_pop)
	Talk: Talk?, -- script of the running talk (built once per talk)
	TalkKey: string,
}
export type Step = { At: number, Speaker: Speaker, Text: string, Reveal: number }
export type Speaker = "Player" | "Customer"

export type Public = {
	Clock: RBXScriptConnection?,
	CloseTablet: number?,
	CloseToken: number,
	DecideBound: boolean,
	DecideSentAt: number,
	DialogUnmount: (() -> ())?,
	Gui: Instance?,
	Hidden: { [BasePart]: number },
	Holder: Folder?,
	Mine: Vide.Source<number>,
	Now: Vide.Source<number>,
	Spots: { [number]: Spot },
	Tracked: { [Instance]: { RBXScriptConnection } },
	Setup: (self: Public) -> (),
	Timeline: (self: Public, record: Record, odd: string, night: number) -> Talk,
	StepAt: (self: Public, record: Record, talk: Talk, now: number) -> number,
	Enabled: (self: Public) -> boolean,
	RecordOf: (self: Public, index: number) -> Record?,
	MyTalk: (self: Public) -> MyTalk?,
	SpotOf: (self: Public, index: number) -> Spot,
	WriteRecord: (self: Public, index: number, record: Record?) -> (),
	HideBetween: (self: Public, eye: Vector3, rig: Model, head: BasePart, scope: Instance?) -> (),
	SyncCloseUp: (self: Public) -> (),
	SyncDecide: (self: Public) -> (),
	Decide: (self: Public, serve: boolean) -> (),
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
