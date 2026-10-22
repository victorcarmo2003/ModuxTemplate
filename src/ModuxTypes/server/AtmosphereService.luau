--!strict

export type Public = {
	Dark: boolean,
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
	Strike: (self: Public, near: boolean) -> (),
	Shower: (self: Public, length: number) -> (),
	Refresh: (self: Public) -> (),
}

return {}
