--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

type OpalPool = Content.OpalPool

export type Public = {
	HideThread: thread?,
	Inside: boolean,
	LastLine: string?,
	LastSpokeAt: number,
	Line: Vide.Source<string>,
	Model: Model?,
	Origin: Vector3?,
	Random: Random,
	Talking: Vide.Source<boolean>,
	UnbindIdle: (() -> ())?,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	NightNumber: (self: Public) -> number,
	CurrentPool: (self: Public) -> OpalPool?,
	DrawLine: (self: Public, pool: OpalPool) -> string?,
	Speak: (self: Public) -> (),
	Check: (self: Public) -> (),
	Animate: (self: Public, model: Model) -> (),
	Mount: (self: Public, point: CFrame) -> (),
}

return {}
