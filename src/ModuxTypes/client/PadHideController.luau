--!strict

type Saved = { [string]: any }

export type Public = {
	Hidden: boolean,
	Saved: { [Instance]: Saved },
	Watched: { [Instance]: RBXScriptConnection },
	Setup: (self: Public) -> (),
	HideOne: (self: Public, instance: Instance) -> (),
	ShowOne: (self: Public, instance: Instance, saved: Saved) -> (),
	HideTree: (self: Public, root: Instance) -> (),
	Apply: (self: Public) -> (),
	Restore: (self: Public) -> (),
	Refresh: (self: Public) -> (),
}

return {}
