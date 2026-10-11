--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roles = require(ReplicatedStorage.shared.ServerRole.Roles)

export type Role = Roles.Role
export type Launch = Roles.Launch

export type Public = {
	Launch: Launch?,
	Reserved: boolean,
	Role: Role,
	Setup: (self: Public) -> (),
	Resolve: (self: Public) -> (Role, Launch?),
	Get: (self: Public) -> Role,
	Is: (self: Public, role: Role) -> boolean,
	IsLobby: (self: Public) -> boolean,
	IsGame: (self: Public) -> boolean,
	IsReserved: (self: Public) -> boolean,
	GetLaunch: (self: Public) -> Launch?,
}

return {}
