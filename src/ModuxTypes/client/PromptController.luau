--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local InteractionMenu = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.InteractionMenu)
local Prompt = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Prompt)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local Menu = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Menu)

export type Public = {
	AutoSelectSaved: boolean?,
	DoorPair: any,
	FocusButtons: { [InteractionMenu.Item]: GuiButton },
	Gate: ((Instance) -> boolean)?,
	Gates: { [string]: (Instance) -> boolean },
	Gui: Instance?,
	HoldSound: Sound?,
	HoldThread: thread?,
	Holding: Prompt.Prompt?,
	LastFire: number,
	MenuActive: boolean,
	MenuBound: number,
	MenuGlyphs: Vide.Source<InteractionMenu.Glyphs>,
	MenuItems: { [Prompt.Prompt]: { Item: InteractionMenu.Item, Enabled: Vide.Source<boolean> } },
	MenuList: Vide.Source<{ InteractionMenu.Item }>,
	MenuPrompts: { [InteractionMenu.Item]: Prompt.Prompt },
	MenuSelected: Vide.Source<InteractionMenu.Item?>,
	MenuState: Menu.State,
	MenuVisible: Vide.Source<boolean>,
	Prompts: { [Instance]: Prompt.Prompt },
	Target: Prompt.Prompt?,
	WindowFocused: boolean,
	Setup: (self: Public) -> (),
	IsSingle: (self: Public, device: string) -> boolean,
	SinglePointer: (self: Public, device: string, viewport: Vector2) -> Vector2?,
	InSight: (self: Public, anchor: Instance, position: Vector3, from: Vector3, character: Model) -> boolean,
	PickSingle: (self: Public, candidates: { [Prompt.Prompt]: { Screen: Vector2, World: number } }, pointer: Vector2?, margin: number) -> Prompt.Prompt?,
	SetGate: (self: Public, gate: ((Instance) -> boolean)?) -> (),
	AddGate: (self: Public, name: string, gate: (Instance) -> boolean) -> (),
	RemoveGate: (self: Public, name: string) -> (),
	Gated: (self: Public, anchor: Instance) -> boolean,
	DoorSideAllows: (self: Public, anchor: Instance, action: string) -> boolean,
	Add: (self: Public, anchor: Instance) -> (),
	Remove: (self: Public, anchor: Instance) -> (),
	Fire: (self: Public, prompt: Prompt.Prompt) -> (),
	FireAnchor: (self: Public, anchor: Instance) -> boolean,
	Celebrate: (self: Public, prompt: Prompt.Prompt) -> (),
	WatchDiscard: (self: Public, anchor: Instance) -> (),
	CancelHold: (self: Public) -> (),
	BeginHold: (self: Public, prompt: Prompt.Prompt) -> (),
	EndHold: (self: Public) -> (),
	SetTarget: (self: Public, prompt: Prompt.Prompt?) -> (),
	MenuItemOf: (self: Public, prompt: Prompt.Prompt) -> InteractionMenu.Item,
	ForgetMenu: (self: Public, prompt: Prompt.Prompt) -> (),
	PublishMenu: (self: Public) -> (),
	ApplyMenuTarget: (self: Public) -> (),
	MenuStep: (self: Public, delta: number) -> (),
	MenuPress: (self: Public, prompt: Prompt.Prompt) -> (),
	BindMenuPicks: (self: Public, count: number) -> (),
	SetMenuActive: (self: Public, active: boolean) -> (),
	OnWheel: (self: Public, state: Enum.UserInputState, wheel: InputObject) -> Enum.ContextActionResult,
	SyncFocus: (self: Public) -> (),
	MountMenu: (self: Public, gui: Instance) -> (),
	HideAll: (self: Public) -> (),
	Held: (self: Public, character: Model) -> Rules.Held?,
	RulesContext: (self: Public, character: Model) -> Rules.Context,
	Tick: (self: Public) -> (),
	Watch: (self: Public, gui: Instance) -> (),
	Retick: (self: Public) -> (),
}

return {}
