--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Registry = require(ServerScriptService.server.Interaction.InteractionService.Registry)

export type RejectReason = "rate" | "range" | "target" | "state"
export type GateFn = (player: Player, action: string, anchor: Instance) -> (boolean, string?)
export type Gate = { Name: string, Fn: GateFn }
export type Handler = {
	-- Owner's rules (slot free, stock, hand, phase...). Runs serialized per target, right before Run.
	Validate: (player: Player, anchor: Instance, id: number) -> boolean,
	Run: (player: Player, anchor: Instance, id: number) -> (),
	-- Optional: other PromptAction values whose anchors also accept this action (none in use since DEC-221).
	On: { string }?,
}
export type Request = { Player: Player, Action: string }
export type Bucket = { Tokens: number, At: number }

export type Public = {
	Buckets: { [Player]: Bucket },
	Gates: { Gate },
	Handlers: { [string]: Handler },
	Performed: SignalLib.Signal<Player, string, Instance, number>,
	Queues: { [number]: { Request } },
	Registry: Registry.Registry,
	Rejected: SignalLib.Signal<Player, number, string, string>,
	Watched: { [Instance]: RBXScriptConnection },
	Setup: (self: Public) -> (),
	RegisterAction: (self: Public, key: string, handler: Handler) -> (),
	AddGate: (self: Public, name: string, fn: GateFn) -> (),
	Get: (self: Public, id: number) -> Instance?,
	IdOf: (self: Public, anchor: Instance) -> number?,
	Position: (self: Public, anchor: Instance) -> Vector3?,
	SetPrompt: (self: Public, anchor: Instance, enabled: boolean, text: string?) -> (),
	SetPromptHold: (self: Public, anchor: Instance, hold: number?) -> (),
	IsActive: (self: Public, action: string) -> boolean,
	Track: (self: Public, anchor: Instance) -> (),
	Watch: (self: Public, anchor: Instance) -> (),
	Unwatch: (self: Public, anchor: Instance) -> (),
	Allow: (self: Public, player: Player) -> boolean,
	IsMemberActive: (self: Public, player: Player) -> boolean,
	RootOf: (self: Public, player: Player) -> BasePart?,
	Reject: (self: Public, player: Player, id: number, action: string, reason: RejectReason | string) -> (),
	CheckGates: (self: Public, player: Player, action: string, anchor: Instance) -> string?,
	Process: (self: Public, player: Player, id: number, action: string) -> (),
	Drain: (self: Public, player: Player, id: number, action: string) -> (),
}

return {}
