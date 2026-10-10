--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Registry = require(ServerScriptService.server.Interaction.InteractionService.Registry)

export type RejectReason = "rate" | "range" | "target" | "state"
export type Handler = {
	-- Owner's rules (slot free, stock, hand, phase...). Runs serialized per target, right before Run.
	Validate: (player: Player, anchor: Instance, id: number) -> boolean,
	Run: (player: Player, anchor: Instance, id: number) -> (),
}
export type Request = { Player: Player, Action: string }
export type Bucket = { Tokens: number, At: number }

export type Public = {
	Buckets: { [Player]: Bucket },
	Handlers: { [string]: Handler },
	Queues: { [number]: { Request } },
	Registry: Registry.Registry,
	Rejected: SignalLib.Signal<Player, number, string, RejectReason>,
	Watched: { [Instance]: RBXScriptConnection },
	Setup: (self: Public) -> (),
	RegisterAction: (self: Public, key: string, handler: Handler) -> (),
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
	RootOf: (self: Public, player: Player) -> BasePart?,
	Reject: (self: Public, player: Player, id: number, action: string, reason: RejectReason) -> (),
	Process: (self: Public, player: Player, id: number, action: string) -> (),
	Drain: (self: Public, player: Player, id: number, action: string) -> (),
}

return {}
