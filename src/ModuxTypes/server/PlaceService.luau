--!strict

export type Role = "Lobby" | "Run"

export type Public = {
	Dev: boolean,
	Role: Role,
	Setup: (self: Public) -> (),
	Is: (self: Public, role: Role) -> boolean,
	IsDev: (self: Public) -> boolean,
	ValidateMap: (self: Public) -> (),
}

return {}
