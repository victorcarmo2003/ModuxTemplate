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
	Fade: Vide.Source<number>,
	FadeConnection: RBXScriptConnection?,
	FadeIsDoor: boolean,
	FadeStartedAt: number,
	ShutterPending: { [Instance]: boolean },
	ShutterStep: RBXScriptConnection?,
	Shutters: { [Instance]: Shutter },
	Unmounts: { () -> () },
	Warned: { [string]: boolean },
	Setup: (self: Public) -> (),
	WarnOnce: (self: Public, tag: string, message: string) -> (),
	WatchVehicle: (self: Public, model: Instance) -> (),
	UnwatchVehicle: (self: Public, model: Instance) -> (),
	WatchShutter: (self: Public, model: Model, retry: boolean) -> (),
	WantClosed: (self: Public, model: Model) -> boolean,
	PoseShutter: (self: Public, shutter: Shutter) -> (),
	SwingShutter: (self: Public, shutter: Shutter) -> (),
	StepShutters: (self: Public) -> (),
	RefreshPanels: (self: Public) -> (),
	IsShutterClosed: (self: Public) -> boolean,
	PlayLocked: (self: Public) -> (),
	PlayFade: (self: Public, startedAt: number, door: boolean?) -> (),
	StepFade: (self: Public) -> (),
	MountFade: (self: Public, playerGui: Instance) -> (),
}

return {}
