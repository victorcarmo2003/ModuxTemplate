--!strict

type Cup = {
	Root: Instance,
	Surface: BasePart?,
	Body: BasePart?,
	FullRelative: CFrame?, -- surface CFrame in body space when full
	EmptyOffset: number,
	Level: number?, -- last target: 1 full, 0 empty (nil = not painted yet)
	Tween: Tween?,
	Stations: { [Instance]: RBXScriptConnection },
	Links: { RBXScriptConnection },
}

export type Public = {
	Cups: { [Instance]: Cup },
	Setup: (self: Public) -> (),
	Paint: (self: Public, cup: Cup, level: number, seconds: number, easing: Enum.EasingStyle?, dir: Enum.EasingDirection?) -> (),
	Refresh: (self: Public, cup: Cup, snap: boolean?) -> (),
	Link: (self: Public, cup: Cup, station: Instance) -> (),
	Add: (self: Public, root: Instance) -> (),
	Remove: (self: Public, root: Instance) -> (),
}

return {}
