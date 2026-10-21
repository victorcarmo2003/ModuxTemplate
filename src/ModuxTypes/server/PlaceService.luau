--!strict

export type Role = "Lobby" | "Run"

export type Public = {
	AdminDepth: number,
	Dev: boolean,
	Role: Role,
	Setup: (self: Public) -> (),
	Is: (self: Public, role: Role) -> boolean,
	IsDev: (self: Public) -> boolean,
	AsAdmin: (self: Public, run: () -> any) -> any,
	ValidateMap: (self: Public) -> (),
}

return {}
