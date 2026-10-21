--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local DrawerValue = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DrawerValue)
local TipJar = require(StarterPlayer.StarterPlayerScripts.client.Economy.EconomyController.TipJar)

type Mount = {
	Vehicle: Instance,
	Adornee: Instance?,
	Gui: Instance?,
	Unmount: (() -> ())?,
	Connections: { RBXScriptConnection },
	Fallback: thread?,
	Warned: boolean,
	Jar: TipJar.TipJar?,
}
export type Record = {
	Cash: number,
	Drawer: number,
}

export type Public = {
	Cash: Vide.Source<number>,
	Drawer: Vide.Source<number>,
	FlyGui: ScreenGui?,
	Gui: Instance?,
	JarConfig: TipJar.Config,
	LandSerial: number,
	Mounts: { [Instance]: Mount },
	Pops: Vide.Source<{ DrawerValue.Pop }>,
	Ready: Vide.Source<boolean>,
	Shown: Vide.Source<number>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	IsCurrent: (self: Public, vehicle: Instance) -> boolean,
	Apply: (self: Public, record: Record) -> (),
	Land: (self: Public, cash: number, ready: boolean) -> (),
	Pop: (self: Public, amount: number) -> (),
	PopDone: (self: Public, pop: DrawerValue.Pop) -> (),
	DrawerAnchor: (self: Public) -> Instance?,
	Tipped: (self: Public, amount: number) -> (),
	SalePosition: (self: Public, npc: number) -> Vector3?,
	Chime: (self: Public, amount: number, npc: number) -> (),
	Collected: (self: Public, amount: number) -> (),
	FlyScreen: (self: Public) -> ScreenGui?,
	PillTarget: (self: Public, scale: number, viewport: Vector2) -> Vector2,
	FlyPiece: (self: Public, position: Vector3?, coin: boolean, delay: number) -> (),
	Fly: (self: Public, amount: number, position: Vector3?) -> (),
	Draw: (self: Public, mount: Mount, adornee: Instance, offset: number) -> (),
	ResolveJar: (self: Public, mount: Mount) -> (),
	Clear: (self: Public, mount: Mount) -> (),
	Resolve: (self: Public, mount: Mount) -> (),
	Track: (self: Public, vehicle: Instance) -> (),
	Untrack: (self: Public, vehicle: Instance) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
