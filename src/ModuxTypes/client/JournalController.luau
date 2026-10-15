--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	AwayThread: thread?,
	Fresh: Vide.Source<{ [string]: boolean }>,
	GlowConnection: RBXScriptConnection?,
	GlowUntil: number,
	Gui: ScreenGui?,
	Index: Vide.Source<number>,
	Open: Vide.Source<boolean>,
	Pages: Vide.Source<{ [string]: boolean }>,
	Scale: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Anchor: (self: Public) -> Instance?,
	BookModel: (self: Public) -> Instance?,
	StopGlow: (self: Public) -> (),
	StartGlow: (self: Public) -> (),
	OnJournal: (self: Public, data: any) -> (),
	FreshIndex: (self: Public) -> number?,
	MarkRead: (self: Public) -> (),
	Turn: (self: Public, delta: number) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	WatchAway: (self: Public) -> (),
	Select: (self: Public, open: boolean) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
