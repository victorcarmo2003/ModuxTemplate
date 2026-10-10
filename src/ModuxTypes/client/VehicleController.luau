--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Bought: Vide.Source<boolean>,
	BoughtDay: number,
	Fade: Vide.Source<number>,
	FadeConnection: RBXScriptConnection?,
	FadeStartedAt: number,
	SignAnchor: Attachment?,
	SignModel: Model?,
	Unmounts: { () -> () },
	Setup: (self: Public) -> (),
	SignText: (self: Public, day: number) -> string,
	SignVisible: (self: Public) -> boolean,
	PlayFade: (self: Public, startedAt: number) -> (),
	StepFade: (self: Public) -> (),
	OnBought: (self: Public) -> (),
	MountFade: (self: Public, playerGui: Instance) -> (),
	MountSign: (self: Public, playerGui: Instance) -> (),
}

return {}
