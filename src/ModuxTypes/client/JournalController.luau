--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Spot = { AnchorPoint: Vector2, Position: UDim2, Size: UDim2, SizeConstraint: Enum.SizeConstraint }

export type Public = {
	AwayThread: thread?,
	BadgeGui: SurfaceGui?,
	BadgeOn: Vide.Source<boolean>,
	BadgeSpot: Vide.Source<Spot>,
	ClaimSerial: number,
	Fresh: Vide.Source<{ [string]: boolean }>,
	GlowConnection: RBXScriptConnection?,
	Gui: ScreenGui?,
	Index: Vide.Source<number>,
	Open: Vide.Source<boolean>,
	Pages: Vide.Source<{ [string]: boolean }>,
	Pending: { [string]: number },
	Scale: Vide.Source<number>,
	ShownAt: number,
	ShownKey: string?,
	Unseen: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	Anchor: (self: Public) -> Instance?,
	BookModel: (self: Public) -> Instance?,
	StopGlow: (self: Public) -> (),
	StartGlow: (self: Public) -> (),
	OnJournal: (self: Public, data: any) -> (),
	PlayCollect: (self: Public) -> (),
	TickClaim: (self: Public) -> (),
	ScheduleClaim: (self: Public) -> (),
	FreshIndex: (self: Public) -> number?,
	Turn: (self: Public, delta: number) -> (),
	Sticker: (self: Public) -> (TextLabel?, SurfaceGui?),
	WatchBadge: (self: Public) -> (),
	MountBadge: (self: Public, playerGui: Instance) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	WatchAway: (self: Public) -> (),
	Select: (self: Public, open: boolean) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
