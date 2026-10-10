--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Drop = {
	Model: Model,
	Kind: Kind?, -- nil while the Item attribute is not there yet
	Ring: BasePart?,
	Tween: Tween?,
	Links: { RBXScriptConnection },
}
type Kind = "Keep" | "Lost"

export type Public = {
	Count: Vide.Source<number>,
	Drops: { [Model]: Drop },
	Folder: Folder?,
	Probe: RaycastParams,
	Random: Random,
	Setup: (self: Public) -> (),
	VfxFolder: (self: Public) -> Folder,
	Ground: (self: Public, origin: Vector3, ignore: { Instance }) -> Vector3?,
	BuildRing: (self: Public, drop: Drop) -> (),
	FollowRings: (self: Public) -> (),
	DrawSplat: (self: Public, holder: GuiObject) -> (),
	DrawSpill: (self: Public, holder: GuiObject) -> (),
	Dust: (self: Public, at: Vector3) -> (),
	PlayLost: (self: Public, model: Model) -> (),
	Resolve: (self: Public, drop: Drop) -> (),
	Add: (self: Public, instance: Instance) -> (),
	Remove: (self: Public, instance: Instance) -> (),
}

return {}
