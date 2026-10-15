--!strict

export type Public = {
	Blur: BlurEffect?,
	Gui: ScreenGui?,
	Tweens: { Tween },
	Setup: (self: Public) -> (),
	BlurEffect: (self: Public) -> BlurEffect,
	Wanted: (self: Public) -> boolean,
	Apply: (self: Public, on: boolean, veil: Frame) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
