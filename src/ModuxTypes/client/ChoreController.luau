--!strict

type Record = { On: boolean, Mask: number, At: number }
type Rat = { Model: Model, Base: CFrame, Seed: number }

export type Public = {
	CameraPos: Vector3?,
	Connection: RBXScriptConnection?,
	Fire: Attachment?,
	FirePos: Vector3?,
	Models: { [string]: Instance },
	Rats: { [Instance]: Rat },
	Records: { [string]: Record },
	Setup: (self: Public) -> (),
	ModelOf: (self: Public, mapId: string) -> Instance?,
	Ignite: (self: Public, anchor: Attachment) -> (),
	Douse: (self: Public, done: boolean) -> (),
	AddRat: (self: Public, anchor: Attachment) -> (),
	RemoveRat: (self: Public, anchor: Instance, run: boolean) -> (),
	SyncRats: (self: Public, on: boolean) -> (),
	Present: (self: Public, key: string, record: Record) -> (),
	Apply: (self: Public, id: number, record: Record, fresh: boolean) -> (),
	Hidden: (self: Public, anchor: Instance) -> boolean,
}

return {}
