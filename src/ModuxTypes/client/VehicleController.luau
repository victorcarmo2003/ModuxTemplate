--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Bought: Vide.Source<boolean>,
	BoughtDay: number,
	Fade: Vide.Source<number>,
	FadeConnection: RBXScriptConnection?,
	FadeStartedAt: number,
	SaleBought: Vide.Source<boolean>,
	SaleModels: { [Instance]: RBXScriptConnection },
	SignAnchor: Attachment?,
	SignModel: Model?,
	Unmounts: { () -> () },
	Setup: (self: Public) -> (),
	SignText: (self: Public, day: number) -> string,
	SignVisible: (self: Public) -> boolean,
	WatchVehicle: (self: Public, model: Instance) -> (),
	UnwatchVehicle: (self: Public, model: Instance) -> (),
	PlayFade: (self: Public, startedAt: number) -> (),
	StepFade: (self: Public) -> (),
	OnBought: (self: Public) -> (),
	MountFade: (self: Public, playerGui: Instance) -> (),
	MountSign: (self: Public, playerGui: Instance) -> (),
}

return {}
