--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ShowcasePanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ShowcasePanel)

type Item = ShowcasePanel.Item
type Row = ShowcasePanel.Row
type State = ShowcasePanel.State

export type Public = {
	Items: Vide.Source<{ Item }>,
	LogKind: Vide.Source<string>,
	LogText: Vide.Source<string>,
	Mounted: boolean,
	Open: Vide.Source<boolean>,
	State: Vide.Source<State>,
	Tab: Vide.Source<string>,
	Viewport: Vide.Source<Vector2>,
	Setup: (self: Public) -> (),
	IsDev: (self: Public) -> boolean,
	Send: (self: Public, action: string, id: string, arg: string, value: number) -> (),
	Show: (self: Public) -> (),
	Hide: (self: Public) -> (),
	Toggle: (self: Public) -> (),
	Log: (self: Public, kind: string, text: string) -> (),
	BuildRows: (self: Public) -> { Row },
	OnScare: (self: Public, id: string, stop: boolean) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
