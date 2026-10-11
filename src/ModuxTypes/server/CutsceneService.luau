--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Route = require(ReplicatedStorage.shared.Cutscene.Route)

type Beat = Content.CutsceneBeat
type TrafficHook = {
	Hold: (self: any, reason: string, on: boolean) -> (),
}

export type Public = {
	Changed: SignalLib.Signal<string>,
	Done: boolean,
	Enabled: boolean,
	Frozen: { [Player]: boolean },
	Moves: { Beat },
	NextMove: number,
	Owner: string?,
	Participants: { number },
	Placed: any,
	Plans: { [number]: Route.Plan },
	Scene: string,
	StartedAt: number,
	Target: string?,
	Traffic: TrafficHook?,
	Votes: { [number]: boolean },
	Written: boolean,
	Setup: (self: Public) -> (),
	IsPlaying: (self: Public) -> boolean,
	IsParticipant: (self: Public, player: Player) -> boolean,
	SlotOf: (self: Public, userId: number) -> number?,
	Connected: (self: Public, userId: number) -> Player?,
	ConnectedCount: (self: Public) -> number,
	VoteCount: (self: Public) -> number,
	Needed: (self: Public) -> number,
	Write: (self: Public) -> (),
	TrafficHook: (self: Public) -> TrafficHook?,
	HoldTraffic: (self: Public, on: boolean) -> (),
	DressPoster: (self: Public) -> (),
	PlanFor: (self: Public, slot: number) -> Route.Plan?,
	SpotFor: (self: Public, slot: number) -> CFrame?,
	BodyOf: (self: Public, player: Player) -> Model?,
	Place: (self: Public, player: Player, slot: number) -> (),
	Hold: (self: Public) -> (),
	ReleaseAll: (self: Public) -> (),
	RunMove: (self: Public, beat: Beat) -> (),
	Begin: (self: Public, key: string) -> (),
	Play: (self: Public, key: string, owner: string?) -> boolean,
	Finish: (self: Public) -> (),
	EndSegment: (self: Public) -> (),
	Vote: (self: Public, player: Player) -> boolean,
	Settle: (self: Public) -> (),
	Step: (self: Public) -> (),
	OnPhaseChanged: (self: Public, phase: string) -> (),
	ProbeDone: (self: Public, phase: string) -> boolean,
}

return {}
