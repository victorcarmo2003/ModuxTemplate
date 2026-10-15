--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

type Saved = { [string]: any }

export type Public = {
	BoundNames: { string },
	Cam: Vide.Source<string>,
	Clock: Vide.Source<string>,
	Connection: RBXScriptConnection?,
	Effect: ColorCorrectionEffect?,
	Fov: number,
	Frame: CFrame?,
	Hidden: { BasePart },
	Inset: Vide.Source<number>,
	Light: Part?,
	NightText: Vide.Source<string>,
	Open: Vide.Source<boolean>,
	PreviousContext: string,
	Saved: Saved,
	Scale: Vide.Source<number>,
	Since: Vide.Source<number>,
	Static: Vide.Source<number>,
	SwitchedAt: number,
	Time: Vide.Source<number>,
	Unmount: (() -> ())?,
	View: Vide.Source<Content.SecurityView>,
	Setup: (self: Public) -> (),
	ModelOf: (self: Public, cam: Content.SecurityCam) -> PVInstance?,
	FrameOf: (self: Public, key: string) -> CFrame?,
	Look: (self: Public) -> Content.SecurityLook,
	Enter: (self: Public) -> (),
	Cut: (self: Public, key: string, frame: CFrame) -> (),
	HideHousing: (self: Public, model: PVInstance?) -> (),
	Leave: (self: Public) -> (),
	Teardown: (self: Public) -> (),
	SetCam: (self: Public, key: string) -> (),
	Step: (self: Public, delta: number) -> (),
	ToggleView: (self: Public) -> (),
	Burst: (self: Public) -> (),
	ApplyLook: (self: Public) -> (),
	Publish: (self: Public) -> (),
	Update: (self: Public) -> (),
	Isolate: (self: Public, on: boolean) -> (),
	Bind: (self: Public, on: boolean) -> (),
	Mount: (self: Public) -> (),
}

return {}
