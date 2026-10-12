--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Speech = require(StarterPlayer.StarterPlayerScripts.client.Cutscene.CutsceneController.Speech)

export type Record = {
	Call: string,
	State: string,
	StartedAt: number,
}
type Phone = {
	Model: Instance,
	Lamps: { Lamp },
	Ripple: Instance?, -- adornee of the ripples
	RippleOffset: Vector3,
	Speaker: BasePart?, -- host of the ring Sound
}
type Lamp = {
	Part: BasePart,
	Color: Color3,
	Material: Enum.Material,
}

export type Public = {
	Call: Vide.Source<string>,
	CancelSay: (() -> ())?,
	Gui: ScreenGui?,
	Held: boolean,
	LampOn: boolean,
	LineIndex: number,
	Lines: { Content.BossCallLine },
	LinesNight: number,
	Phone: Phone?,
	Prepared: { [string]: boolean },
	PreparedFor: string,
	RingSound: Sound?,
	RippleAt: Vide.Source<number>,
	RippleGui: BillboardGui?,
	RippleUnmount: (() -> ())?,
	Scale: Vide.Source<number>,
	Showing: Vide.Source<boolean>,
	Speaker: Vide.Source<string>,
	Speech: Speech.Speech?,
	StartedAt: number,
	StartedClock: number,
	State: Vide.Source<string>,
	Text: Vide.Source<string>,
	Vehicle: Instance?,
	VehicleConnections: { RBXScriptConnection },
	Warned: { [string]: boolean },
	Warnings: number,
	Setup: (self: Public) -> (),
	Voice: (self: Public) -> Speech.Speech,
	PrepareCall: (self: Public, key: string, night: number) -> (),
	PrepareUpcoming: (self: Public) -> (),
	WarnSilent: (self: Public, line: Content.CutsceneBeat) -> (),
	Speak: (self: Public, text: string) -> (),
	Quiet: (self: Public) -> (),
	Night: (self: Public) -> number,
	Apply: (self: Public, record: Record) -> (),
	Hold: (self: Public, on: boolean) -> (),
	Say: (self: Public, text: string?) -> (),
	Refresh: (self: Public) -> (),
	FindVehicle: (self: Public) -> Instance?,
	SetLamp: (self: Public, on: boolean) -> (),
	SetRing: (self: Public, on: boolean) -> (),
	NewSound: (self: Public, key: string, host: BasePart) -> Sound?,
	PlayOnce: (self: Public, key: string) -> (),
	ClearPhone: (self: Public) -> (),
	UsePhone: (self: Public, model: Instance?) -> (),
	Track: (self: Public) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
