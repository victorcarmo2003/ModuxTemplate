--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Steps = require(StarterPlayer.StarterPlayerScripts.client.Tutorial.TutorialController.Steps)

type Held = { Item: string, Toppings: { [string]: boolean } }
type Kitchen = {
	GrillWorking: boolean,
	GrillReady: boolean,
	Rail: number,
	BoardWorking: boolean,
	BoardReady: boolean,
}

export type Public = {
	CashRevealed: Vide.Source<boolean>,
	ClockRevealed: Vide.Source<boolean>,
	Finished: Vide.Source<boolean>,
	Folder: Folder?,
	Highlight: Highlight?,
	Item: Vide.Source<string>,
	LastHotDogAt: number,
	MoneyThread: thread?,
	PointerAngle: Vide.Source<number>,
	PointerAt: Vide.Source<Vector2>,
	PointerShown: Vide.Source<boolean>,
	Running: Vide.Source<boolean>,
	Scale: Vide.Source<number>,
	Sent: boolean,
	Spot: Vide.Source<GuiObject | false>,
	StepKey: Vide.Source<string>,
	Target: Vide.Source<Instance | false>,
	Unmounts: { () -> () },
	Setup: (self: Public) -> (),
	FirstRun: (self: Public) -> boolean,
	ShowCash: (self: Public) -> boolean,
	ShowClock: (self: Public) -> boolean,
	Step: (self: Public) -> Steps.Step?,
	PanelText: (self: Public) -> string,
	SkipText: (self: Public) -> string,
	Root: (self: Public) -> BasePart?,
	Held: (self: Public) -> Held?,
	Kitchen: (self: Public) -> Kitchen,
	Ordering: (self: Public) -> { [number]: boolean },
	Anchor: (self: Public, action: string, enabled: boolean, filter: ((Instance) -> boolean)?) -> Instance?,
	Decide: (self: Public) -> (string, Instance?, string),
	FxFolder: (self: Public) -> Folder,
	SetHighlight: (self: Public, anchor: Instance?) -> (),
	ClearGuidance: (self: Public) -> (),
	UpdatePointer: (self: Public) -> (),
	Rescale: (self: Public) -> (),
	SetStep: (self: Public, key: string, target: Instance?, item: string) -> (),
	OnSale: (self: Public, result: string) -> (),
	Finish: (self: Public) -> (),
	Tick: (self: Public) -> (),
	BindSkip: (self: Public, on: boolean) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
