--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local StationApi = require(ServerScriptService.server.Kitchen.KitchenService.StationApi)

export type Amounts = { [string]: number }
export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean }
type Wanted = { Enabled: boolean, Text: string? }
export type AlterKind = "rail" | "board"
export type DiscardWhere = "Vehicle" | "Street"

export type Public = {
	Active: boolean,
	Amounts: Charm.Atom<Amounts>,
	Bins: { [Instance]: boolean },
	ByInstance: { [Instance]: StationApi.Station },
	Context: StationApi.Context,
	Discarded: SignalLib.Signal<Player, string, boolean, DiscardWhere>,
	Emitted: SignalLib.Signal<string, Player?, { [string]: any }?>,
	Gated: { [Instance]: boolean },
	Locks: { [number]: { thread } },
	ModuleNames: { [string]: string },
	Modules: { [string]: StationApi.Module },
	Published: { [number]: number },
	Stations: { [number]: StationApi.Station },
	StockChanged: SignalLib.Signal<string, number>,
	Wanted: { [Instance]: Wanted },
	Warned: { [string]: boolean },
	WasBlocked: { [string]: boolean },
	Setup: (self: Public) -> (),
	GetVehicle: (self: Public) -> string,
	GetCapacity: (self: Public, ingredient: string) -> number,
	IsBlocked: (self: Public, ingredient: string) -> boolean,
	GetStock: (self: Public, ingredient: string) -> (number, number),
	Stock: (self: Public, ingredient: string) -> StockRecord,
	SetAmount: (self: Public, ingredient: string, amount: number) -> (),
	TakeStock: (self: Public, ingredient: string, n: number) -> boolean,
	LoadModules: (self: Public) -> (),
	RegisterActions: (self: Public) -> (),
	StationOf: (self: Public, instance: Instance) -> StationApi.Station?,
	IsCurrent: (self: Public, station: StationApi.Station) -> boolean,
	VehicleOf: (self: Public, model: Model) -> string?,
	CollectParts: (self: Public, station: StationApi.Station) -> (),
	FreeId: (self: Public) -> number?,
	StableKey: (self: Public, vehicle: string, kind: string) -> string,
	AddStation: (self: Public, instance: Instance) -> (),
	RemoveStation: (self: Public, instance: Instance) -> (),
	RefreshSlots: (self: Public, upgradeKey: string, vehicle: string) -> (),
	Publish: (self: Public, station: StationApi.Station) -> (),
	PushStock: (self: Public) -> (),
	AddBin: (self: Public, instance: Instance) -> (),
	RefreshPrompts: (self: Public, station: StationApi.Station) -> (),
	RefreshAllPrompts: (self: Public) -> (),
	IngredientOf: (self: Public, station: StationApi.Station, anchor: Instance) -> string?,
	Notify: (self: Public, player: Player, notice: string, value: number?) -> (),
	PackageFor: (self: Public, player: Player, ingredient: string) -> (Tool?, number),
	CheckRestock: (self: Public, player: Player, station: StationApi.Station, anchor: Instance) -> (boolean, string?, number?),
	Restock: (self: Public, player: Player, station: StationApi.Station, anchor: Instance) -> (),
	BinOf: (self: Public, anchor: Instance) -> Instance?,
	MeetsRequires: (self: Public, key: string, player: Player) -> boolean,
	CheckStreet: (self: Public, key: string, player: Player, anchor: Instance) -> boolean,
	Evaluate: (self: Public, key: string, player: Player, anchor: Instance) -> (boolean, string?, number?),
	Serialize: (self: Public, station: StationApi.Station, fn: () -> ()) -> (),
	Perform: (self: Public, key: string, player: Player, anchor: Instance) -> (),
	BuildContext: (self: Public) -> StationApi.Context,
	CurrentStation: (self: Public, kind: string) -> StationApi.Station?,
	Alter: (self: Public, kind: AlterKind, slot: number?) -> boolean,
	ClearAltered: (self: Public) -> number,
	HasAltered: (self: Public, kind: AlterKind?) -> boolean,
	DiscardTarget: (self: Public, player: Player) -> (Tool?, string, boolean),
	ReportDiscard: (self: Public, player: Player, tool: Tool?, item: string, altered: boolean, where: DiscardWhere) -> (),
	CaptureStock: (self: Public) -> { [string]: number },
	RestoreStock: (self: Public, data: any) -> (),
	CaptureStations: (self: Public) -> { [string]: any },
	RestoreStations: (self: Public, data: any) -> (),
	RememberBlocked: (self: Public) -> (),
	AnnounceUnlocks: (self: Public) -> (),
}

return {}
