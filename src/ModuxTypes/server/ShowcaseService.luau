--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Catalog = require(ServerScriptService.server.Showcase.ShowcaseService.Catalog)
local Resolve = require(ServerScriptService.server.Showcase.ShowcaseService.Resolve)

type Ended = { Phase: string, Step: number, At: number }

export type Public = {
	Alive: { [string]: Ended },
	Catalog: { Catalog.Item }?,
	Enabled: boolean,
	Ended: { [string]: Ended },
	FrozenElapsed: number?,
	FrozenPhase: string,
	NextStateAt: number,
	Viewers: { [Player]: boolean },
	Setup: (self: Public) -> (),
	Allowed: (self: Public, player: Player) -> boolean,
	Reply: (self: Public, player: Player, kind: "info" | "ok" | "error" | "open", text: string) -> (),
	Dev: (self: Public, player: Player, line: string) -> string,
	Teleport: (self: Public, player: Player, point: string) -> boolean,
	ResolveEnv: (self: Public, player: Player) -> Resolve.Env,
	EnsureNight: (self: Public, player: Player, night: number?, force: boolean?) -> (),
	SetClock: (self: Public, player: Player, minutes: number) -> (),
	Clear: (self: Public, player: Player) -> (),
	StopAll: (self: Public, player: Player) -> string,
	Trigger: (self: Public, player: Player, id: string) -> string,
	StopAnomaly: (self: Public, player: Player, id: string) -> string,
	SetSanity: (self: Public, player: Player, spec: string) -> string,
	Helper: (self: Public, player: Player, arg: string) -> string,
	Control: (self: Public, player: Player, name: string, value: number, arg: string) -> string,
	Run: (self: Public, player: Player, action: string, id: string, arg: string, value: number) -> (boolean, string),
	ClockText: (self: Public) -> string,
	SendCatalog: (self: Public, player: Player) -> (),
	Occurrences: (self: Public) -> { { Ref: string, Phase: string, Step: number, Age: number, Live: boolean } },
	SendState: (self: Public, player: Player) -> (),
	Track: (self: Public) -> (),
	Step: (self: Public) -> (),
	Open: (self: Public, player: Player) -> (boolean, string),
	OnOpen: (self: Public, player: Player) -> (),
	OnClose: (self: Public, player: Player) -> (),
	OnRequest: (self: Public, player: Player, data: { Action: string, Id: string, Arg: string, Value: number }) -> (),
}

return {}
