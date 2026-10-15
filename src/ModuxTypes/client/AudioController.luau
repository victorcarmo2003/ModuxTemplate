--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

export type PendingShift = { Id: string, IsNight: boolean }
export type AmbientBed = {
	Key: string,
	Stop: (fade: number?) -> (),
}
export type GroupName = "Music" | "Ambient" | "Sfx" | "Voice" | "Ui" | "Scare"
export type At = Vector3 | Instance
export type PlayOptions = {
	Volume: number?, -- multiplier over the row Volume
	Speed: number?, -- PlaybackSpeed multiplier
	Vary: number?, -- random pitch range (+-), default 0.05 for Sfx/Voice one-shots, 0 otherwise
	Scare: boolean?, -- clamp to SoundRules.ScareMaxVolume (DEC-173)
}
export type Voice = {
	Key: string,
	Sound: Sound,
	Holder: Attachment?,
	Looped: boolean,
	Anchor: any,
	Started: number,
	Destroyed: boolean, -- the anchor took the Sound with it: not reusable
	Connections: { RBXScriptConnection },
}

export type Public = {
	AmbientKey: string?,
	Bed: AmbientBed?,
	CoreIds: { string },
	CoreWarm: boolean,
	CutsceneOn: Vide.Source<boolean>,
	Ducked: Vide.Source<boolean>,
	Groups: { [string]: SoundGroup },
	Idle: { [string]: { Sound } },
	IdleSince: { [Sound]: number },
	LastShiftTrack: { [string]: string },
	Loops: { [string]: { [any]: Voice } },
	Master: SoundGroup?,
	MusicCue: Vide.Source<string>,
	MusicStack: Vide.Source<{ string }>,
	NightIds: { string },
	NightWarm: boolean,
	PendingShift: PendingShift?,
	Rng: Random,
	Screen: Folder?,
	SeenPhase: string?,
	SeenWindow: string?,
	ShiftId: string?,
	ShiftMusic: Vide.Source<string>,
	ShiftTrack: Sound?,
	TensionBed: AmbientBed?,
	Track: Sound?,
	TrackKey: string?,
	Unmount: (() -> ())?,
	Voices: { Voice },
	Volumes: { [string]: number },
	Warned: { [string]: boolean },
	ZoneAmbient: Vide.Source<string>,
	ZoneParts: { [string]: BasePart },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, tag: string, message: string) -> (),
	BuildGroups: (self: Public) -> (),
	ApplyGroup: (self: Public, name: string, time: number?) -> (),
	SetVolume: (self: Public, group: GroupName | "Master", volume: number) -> (),
	Row: (self: Public, key: string) -> Content.Sound?,
	Volume: (self: Public, row: Content.Sound, opts: PlayOptions?) -> number,
	Place: (self: Public, row: Content.Sound, at: At?) -> (Instance?, Attachment?),
	Ensure: (self: Public, row: Content.Sound) -> boolean,
	Take: (self: Public, row: Content.Sound) -> Sound,
	Configure: (self: Public, sound: Sound, row: Content.Sound, opts: PlayOptions?, looped: boolean) -> (),
	Release: (self: Public, voice: Voice) -> (),
	Purge: (self: Public) -> (),
	MakeRoom: (self: Public, key: string) -> boolean,
	Start: (self: Public, row: Content.Sound, at: At?, opts: PlayOptions?, looped: boolean, anchor: any) -> Sound?,
	Play: (self: Public, key: string, at: At?, opts: PlayOptions?) -> Sound?,
	Loop: (self: Public, key: string, at: At?, on: boolean, opts: PlayOptions?) -> Sound?,
	StopAll: (self: Public, key: string) -> (),
	PushMusic: (self: Public, cue: string) -> (),
	PopMusic: (self: Public, cue: string) -> (),
	FadeOut: (self: Public, sound: Sound, time: number) -> (),
	SetMusic: (self: Public, cueKey: string?) -> (),
	StopShiftTrack: (self: Public, time: number) -> (),
	PlayShiftTrack: (self: Public, isNight: boolean, fadeIn: number?) -> (),
	MusicBusy: (self: Public) -> boolean,
	OnShiftState: (self: Public, ready: boolean, phase: string, id: string, isNight: boolean) -> (),
	FlushShift: (self: Public) -> (),
	SetAmbient: (self: Public, key: string?) -> (),
	SetTension: (self: Public, on: boolean) -> (),
	OnStingState: (self: Public, phase: string, window: string?) -> (),
	ZonePart: (self: Public, id: string) -> BasePart?,
	ZoneAt: (self: Public) -> string?,
	PlanTiers: (self: Public) -> (),
	Request: (self: Public, ids: { string }) -> (),
	Preload: (self: Public) -> (),
	Warm: (self: Public, phase: string, isNight: boolean) -> (),
	Sweep: (self: Public) -> (),
	DevReport: (self: Public) -> (),
	SetDucked: (self: Public, record: { State: string }?) -> (),
}

return {}
