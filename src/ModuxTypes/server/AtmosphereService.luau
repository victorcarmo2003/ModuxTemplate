--!strict

export type Public = {
	Enabled: boolean,
	Forced: string?,
	Natural: string?,
	Setup: (self: Public) -> (),
	KeyFor: (self: Public, night: number) -> string,
	Get: (self: Public) -> string?,
	IsForced: (self: Public) -> boolean,
	Publish: (self: Public) -> (),
	Set: (self: Public, key: string?) -> (),
	Force: (self: Public, key: string?) -> (),
	Refresh: (self: Public) -> (),
}

return {}
