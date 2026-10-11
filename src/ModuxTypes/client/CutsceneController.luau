--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Actors = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Actors)
local Speech = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Speech)
local Walker = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Walker)

type Beat = Content.CutsceneBeat
type Scene = Content.Cutscene
export type Record = { Scene: string, StartedAt: number, Votes: number, Needed: number }
type Shown = { Title: string, Line: string } | false

export type Public = {
	Active: Vide.Source<boolean>,
	Actors: { [string]: { Actor: Actors.Actor, At: number } },
	Balloons: { () -> () },
	Banner: Vide.Source<Shown>,
	Beats: { Beat },
	EndAlpha: number,
	EndedAt: number?,
	Fade: Vide.Source<number>,
	Fired: { [number]: boolean },
	Folder: Folder?,
	Gui: Instance?,
	HoldStart: number?,
	LastElapsed: number,
	LineShown: Vide.Source<boolean>,
	LineText: Vide.Source<string>,
	LookIndex: number,
	Music: string?,
	Needed: Vide.Source<number>,
	Party: boolean,
	Playing: boolean,
	PreviousContext: string?,
	Progress: Vide.Source<number>,
	PromptHolder: BasePart?,
	PromptShown: Vide.Source<boolean>,
	PromptText: Vide.Source<string>,
	Scene: Scene?,
	SceneKey: Vide.Source<string>,
	Skippable: Vide.Source<boolean>,
	Speaker: Vide.Source<string>,
	Speech: Speech.Speech?,
	StartedAt: number,
	Stepping: boolean,
	Unmounts: { () -> () },
	Voted: Vide.Source<boolean>,
	Votes: Vide.Source<number>,
	Walker: Walker.Walker?,
	Warned: { [string]: boolean },
	Windows: { BasePart }?,
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, key: string, message: string) -> (),
	IsPlaying: (self: Public) -> boolean,
	TargetPosition: (self: Public, target: string) -> Vector3?,
	WindowCards: (self: Public) -> { BasePart },
	FocusGetter: (self: Public, target: string) -> (() -> Vector3?)?,
	CrossClock: (self: Public, target: string) -> (() -> number?)?,
	ActorContext: (self: Public) -> Actors.Context,
	ActorFolder: (self: Public) -> Folder,
	ClearSegment: (self: Public) -> (),
	VoiceVolume: (self: Public) -> number,
	BeginChain: (self: Public) -> (),
	EndChain: (self: Public) -> (),
	BeginSegment: (self: Public, key: string, startedAt: number) -> (),
	Apply: (self: Public, record: Record?) -> (),
	FireBeat: (self: Public, beat: Beat, live: boolean) -> (),
	CrewBalloons: (self: Public, text: string) -> (),
	PlacePrompt: (self: Public, target: string) -> (),
	Step: (self: Public) -> (),
	CanVote: (self: Public) -> boolean,
	PressSkip: (self: Public) -> (),
	ReleaseSkip: (self: Public) -> (),
	StepHold: (self: Public) -> (),
	BindSkip: (self: Public) -> (),
	UnbindSkip: (self: Public) -> (),
	StartStepping: (self: Public) -> (),
	StopStepping: (self: Public) -> (),
	Mount: (self: Public, gui: Instance) -> (),
}

return {}
