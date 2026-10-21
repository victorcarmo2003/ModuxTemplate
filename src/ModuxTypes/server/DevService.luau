--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Api = require(ServerScriptService.server.Dev.DevService.Api)

export type Public = {
	Commands: { [string]: Api.Command },
	Enabled: boolean,
	Order: { string },
	Setup: (self: Public) -> (),
	Add: (self: Public, command: Api.Command, source: string) -> (),
	Load: (self: Public) -> (),
	Help: (self: Public) -> string,
	HelpOf: (self: Public, name: string) -> string,
	Allowed: (self: Public, caller: Player?) -> boolean,
	Execute: (self: Public, name: string, args: { string }, caller: Player?) -> string?,
	BindBridge: (self: Public) -> (),
	BindChat: (self: Public) -> (),
}

return {}
