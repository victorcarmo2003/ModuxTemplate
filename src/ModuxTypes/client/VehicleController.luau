--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Shutter = {
	Model: Model,
	Part: BasePart,
	Hinge: Attachment,
	HingeOffset: CFrame, -- hinge in part space (authored)
	Rest: CFrame, -- part in model-pivot space (authored = open)
	Closed: number, -- radians around the hinge X axis
	Angle: number,
	From: number,
	To: number,
	StartedAt: number?, -- os.clock of the tween in progress; nil = at rest
	Connections: { RBXScriptConnection },
}

export type Public = {
	Bought: Vide.Source<boolean>,
	BoughtDay: number,
	Fade: Vide.Source<number>,
	FadeConnection: RBXScriptConnection?,
	FadeIsDoor: boolean,
	FadeStartedAt: number,
	SaleBought: Vide.Source<boolean>,
	SaleModels: { [Instance]: RBXScriptConnection },
	ShutterPending: { [Instance]: boolean },
	ShutterStep: RBXScriptConnection?,
	Shutters: { [Instance]: Shutter },
	SignAnchor: Attachment?,
	SignModel: Model?,
	Unmounts: { () -> () },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, tag: string, message: string) -> (),
	NightsPlayed: (self: Public) -> number,
	SignText: (self: Public, nights: number) -> string,
	SignVisible: (self: Public) -> boolean,
	SignFocusPosition: (self: Public) -> Vector3?,
	RevealSign: (self: Public) -> (),
	WatchVehicle: (self: Public, model: Instance) -> (),
	WatchSale: (self: Public, model: Instance) -> (),
	UnwatchVehicle: (self: Public, model: Instance) -> (),
	WatchShutter: (self: Public, model: Model, retry: boolean) -> (),
	PoseShutter: (self: Public, shutter: Shutter) -> (),
	SwingShutter: (self: Public, shutter: Shutter) -> (),
	StepShutters: (self: Public) -> (),
	IsShutterClosed: (self: Public) -> boolean,
	PlayFade: (self: Public, startedAt: number, door: boolean?) -> (),
	StepFade: (self: Public) -> (),
	OnBought: (self: Public) -> (),
	MountFade: (self: Public, playerGui: Instance) -> (),
	MountSign: (self: Public, playerGui: Instance) -> (),
}

return {}
