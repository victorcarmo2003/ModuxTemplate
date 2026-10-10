--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CrewScreen = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CrewScreen)
local CardState = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CrewCard.State)

export type Action = "Buy" | "Select"

export type Public = {
	Entries: { CrewScreen.Entry },
	Focus: Vide.Source<string>,
	Gui: ScreenGui?,
	Open: Vide.Source<boolean>,
	Pending: Vide.Source<string>,
	PendingThread: thread?,
	RigWarned: boolean,
	Scale: Vide.Source<number>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	Available: (self: Public) -> boolean,
	StateOf: (self: Public, key: string) -> CardState.State,
	Busy: (self: Public) -> boolean,
	ClearPending: (self: Public) -> (),
	Send: (self: Public, action: Action, key: string) -> (),
	Act: (self: Public, key: string) -> (),
	Buy: (self: Public, key: string) -> (),
	Select: (self: Public, key: string) -> (),
	BuildRig: (self: Public, species: string) -> Model?,
	SelectCard: (self: Public) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	Toggle: (self: Public) -> (),
	Bind: (self: Public) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
