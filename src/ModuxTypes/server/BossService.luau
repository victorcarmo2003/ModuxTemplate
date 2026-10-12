--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Content = require(ReplicatedStorage.shared.Content)

export type State = "Idle" | "Ringing" | "Talking"
export type Record = { Call: string, State: State, StartedAt: number }
export type Entry = { Key: string, Priority: number, Order: number }

export type Public = {
	Cued: { [string]: boolean },
	Enabled: boolean,
	EndsAt: number,
	LastInfinite: string,
	Order: number,
	Pending: { string },
	Played: { [string]: boolean },
	Queue: { Entry },
	Random: Random,
	Record: Charm.Atom<Record>,
	TutorialAnswered: boolean,
	Setup: (self: Public) -> (),
	GetState: (self: Public) -> State,
	GetCall: (self: Public) -> string,
	IsBusy: (self: Public) -> boolean,
	HasPlayed: (self: Public, key: string) -> boolean,
	LinesOf: (self: Public, key: string) -> { Content.BossCallLine },
	CanStart: (self: Public) -> boolean,
	IsQueued: (self: Public, key: string) -> boolean,
	Enqueue: (self: Public, key: string, forced: boolean?, front: boolean?) -> boolean,
	Unqueue: (self: Public, key: string) -> (),
	Pop: (self: Public) -> string?,
	IsPhone: (self: Public, anchor: Instance) -> boolean,
	IsCurrentPhone: (self: Public, anchor: Instance) -> boolean,
	RefreshPhone: (self: Public, anchor: Instance) -> (),
	RefreshPhones: (self: Public) -> (),
	Write: (self: Public, key: string, state: State, startedAt: number) -> (),
	Ring: (self: Public, key: string) -> (),
	Talk: (self: Public, key: string, at: number) -> (),
	Stop: (self: Public, clear: boolean) -> (),
	Finish: (self: Public, at: number) -> (),
	Answer: (self: Public) -> (),
	Step: (self: Public) -> (),
	RunCues: (self: Public, record: Record, t: number) -> (),
	TutorialAllowed: (self: Public) -> boolean,
	QueueTutorial: (self: Public) -> (),
	StepTutorial: (self: Public, t: number) -> (),
	OnDayPrep: (self: Public, day: number, night: number) -> (),
	OnNightCall: (self: Public, night: number, attempt: number) -> (),
	OnPhase: (self: Public, phase: string, day: number, night: number) -> (),
	OnNightResolved: (self: Public, result: string, reason: string?) -> (),
	OnPerformed: (self: Public, action: string) -> (),
	CaptureBoss: (self: Public) -> { string },
	RestoreBoss: (self: Public, data: any) -> (),
	DevCheck: (self: Public, name: string) -> (),
	DevCall: (self: Public, key: string) -> (),
	DevAnswer: (self: Public) -> (),
	DevStop: (self: Public) -> (),
	DevResetTutorial: (self: Public) -> (),
	DevStatus: (self: Public) -> string,
}

return {}
