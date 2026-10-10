--!strict

export type PlayOptions = {
	Looped: boolean?,
	Speed: number?, -- multiplier over the row's Speed
	FadeTime: number?,
	Weight: number?,
}
type Binding = {
	Model: Model,
	Set: string,
	Animator: Animator?,
	Role: string, -- "" = nothing playing (paused or not started)
	Track: AnimationTrack?,
	ClipSpeed: number, -- Speed of the current clip row
	Speed: number, -- smoothed horizontal speed (studs/s)
	Paused: boolean,
	Broken: boolean,
	LastPosition: Vector3?,
	LastAt: number,
	Connections: { RBXScriptConnection },
}
type TrackCache = { [Animator]: { [string]: AnimationTrack } }

export type Public = {
	Auto: { [Model]: boolean },
	Bindings: { [Model]: Binding },
	Probe: string,
	Tracks: TrackCache,
	Setup: (self: Public) -> (),
	AnimatorOf: (self: Public, model: Model, create: boolean) -> Animator?,
	Bind: (self: Public, model: Model, set: string) -> () -> (),
	Unbind: (self: Public, model: Model) -> (),
	SetRole: (self: Public, binding: Binding, role: string, speed: number?) -> (),
	RoleFor: (self: Public, binding: Binding, speed: number) -> string,
	IsVisible: (self: Public, position: Vector3, camera: Camera?) -> boolean,
	Step: (self: Public, binding: Binding, camera: Camera?, now: number) -> (),
	Play: (self: Public, model: Model, key: string, opts: PlayOptions?) -> AnimationTrack?,
	Stop: (self: Public, model: Model, key: string, fadeTime: number?) -> (),
	PlayOwn: (self: Public, key: string, opts: PlayOptions?) -> AnimationTrack?,
	StopOwn: (self: Public, key: string, fadeTime: number?) -> (),
	Watch: (self: Public, instance: Instance) -> (),
	Unwatch: (self: Public, instance: Instance) -> (),
	Preload: (self: Public) -> (),
}

return {}
