--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DrawerValue = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue)

type Mount = {
	Vehicle: Instance,
	Adornee: Instance?,
	Gui: Instance?,
	Unmount: (() -> ())?,
	Connections: { RBXScriptConnection },
	Fallback: thread?,
	Warned: boolean,
}
export type Record = {
	Cash: number,
	Drawer: number,
}

export type Public = {
	Cash: Vide.Source<number>,
	Drawer: Vide.Source<number>,
	Gui: Instance?,
	Mounts: { [Instance]: Mount },
	Pops: Vide.Source<{ DrawerValue.Pop }>,
	Ready: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	Apply: (self: Public, record: Record) -> (),
	Pop: (self: Public, amount: number) -> (),
	PopDone: (self: Public, pop: DrawerValue.Pop) -> (),
	Draw: (self: Public, mount: Mount, adornee: Instance, offset: number) -> (),
	Clear: (self: Public, mount: Mount) -> (),
	Resolve: (self: Public, mount: Mount) -> (),
	Track: (self: Public, vehicle: Instance) -> (),
	Untrack: (self: Public, vehicle: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
