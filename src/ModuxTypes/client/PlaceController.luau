--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)

export type Role = "Lobby" | "Run"

export type Public = {
	Dev: boolean,
	Role: Role,
	ServerRole: Roles.Role,
	Setup: (self: Public) -> (),
	Is: (self: Public, role: Role) -> boolean,
	GetServerRole: (self: Public) -> Roles.Role,
	IsDev: (self: Public) -> boolean,
}

return {}
