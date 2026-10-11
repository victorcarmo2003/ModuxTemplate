--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(StarterPlayer.StarterPlayerScripts.client.Anomaly.AnomalyController.Effect)

export type Record = Effect.Record
export type Occurrence = Effect.Occurrence
export type Context = Effect.Context
export type Module = Effect.Module
export type Live = {
	Occurrence: Occurrence,
	Source: Vide.Source<Record>,
	Destroy: (() -> ())?,
}

export type Public = {
	Count: Vide.Source<number>,
	Ctx: Context?,
	Effects: { [string]: Module },
	Lives: { [number]: Live },
	LocalFolder: Folder?,
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, tag: string, message: string) -> (),
	LoadEffects: (self: Public) -> (),
	Folder: (self: Public) -> Folder,
	Point: (self: Public, id: string) -> CFrame?,
	Anchor: (self: Public, anchorId: string) -> Instance?,
	Occurrences: (self: Public, key: string?) -> { Occurrence },
	Context: (self: Public) -> Context,
	Mount: (self: Public, id: number, record: Record) -> (),
	Unmount: (self: Public, id: number) -> (),
	Write: (self: Public, id: number, raw: any?) -> (),
	Sting: (self: Public, key: string) -> (),
	RecordOf: (self: Public, id: number) -> Record?,
	OnCue: (self: Public, raw: any) -> (),
	WatchNight: (self: Public) -> (),
}

return {}
