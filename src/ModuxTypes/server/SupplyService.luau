--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Order = require(ServerScriptService.server.Supply.SupplyService.Order)
local Shelves = require(ServerScriptService.server.Supply.SupplyService.Shelves)

export type Call = { Id: number, Boxes: Order.Boxes, EndsAt: number }
export type Box = { Package: string, Amount: number }

export type Public = {
	Calls: { Call },
	Enabled: boolean,
	HatchAnchor: Instance?,
	LastTake: { [Player]: number },
	NextCall: number,
	NoticeAt: { [Player]: { [string]: number } },
	Outside: { Box },
	PhoneAnchor: Instance?,
	Published: { [number]: boolean },
	Seeded: boolean,
	Shelves: Shelves.State,
	Spots: { [number]: Box },
	SupplyPublished: boolean,
	Setup: (self: Public) -> (),
	IsLive: (self: Public) -> boolean,
	IsOpen: (self: Public, key: string) -> boolean,
	OpenPackages: (self: Public) -> { string },
	MaxBoxes: (self: Public) -> number,
	Eta: (self: Public) -> number,
	IsBusy: (self: Public) -> boolean,
	SecondsLeft: (self: Public) -> number,
	Stock: (self: Public) -> { [string]: number },
	CanAct: (self: Public, player: Player) -> boolean,
	NotifyThrottled: (self: Public, player: Player, key: string, value: number?) -> (),
	PublishSupply: (self: Public) -> (),
	PublishHatch: (self: Public) -> (),
	FirstSpot: (self: Public) -> number?,
	RefreshPrompts: (self: Public) -> (),
	Refresh: (self: Public) -> (),
	Land: (self: Public, box: Box) -> (),
	PullOutside: (self: Public) -> (),
	LandAll: (self: Public, boxes: Order.Boxes) -> (),
	Arrive: (self: Public, id: number) -> boolean,
	Order: (self: Public, player: Player?, boxes: Order.Boxes) -> (boolean, string),
	QuickOrder: (self: Public, player: Player?) -> (boolean, string),
	BoxAt: (self: Public, anchor: Instance) -> string?,
	Take: (self: Public, player: Player, anchor: Instance) -> boolean,
	ValidateTake: (self: Public, player: Player, anchor: Instance) -> boolean,
	ValidateOrder: (self: Public, player: Player, anchor: Instance) -> boolean,
	Clear: (self: Public) -> (),
	Seed: (self: Public) -> (),
	Capture: (self: Public) -> any,
	Restore: (self: Public, data: any) -> (),
	BindAnchor: (self: Public, anchor: Instance, action: string, hold: number?) -> (),
	Bind: (self: Public) -> (),
	DevCheck: (self: Public) -> (),
	DevState: (self: Public) -> string,
	DevOrder: (self: Public, player: Player?, boxes: Order.Boxes?) -> string,
	DevArrive: (self: Public) -> string,
	DevTake: (self: Public, player: Player, package: string?) -> string,
	DevSeed: (self: Public) -> string,
	DevClear: (self: Public) -> string,
}

return {}
