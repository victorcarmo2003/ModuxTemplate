--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type Band = "Day" | "Mid" | "Night"
export type Shown = { Vignette: number, Saturation: number, Tint: number }
export type Member = {
	State: LifeState,
	StateEndsAt: number,
	KnockedUntil: number,
	Class: string,
}

export type Public = {
	Band: Vide.Source<Band>,
	Blackout: Vide.Source<number>,
	Blur: BlurEffect?,
	BlurUntil: number,
	Color: ColorCorrectionEffect?,
	Dark: Vide.Source<boolean>,
	DarkTickAt: number,
	FaintAt: number?,
	Gui: ScreenGui?,
	LocalState: Vide.Source<LifeState>,
	Max: Vide.Source<number>,
	Members: Vide.Source<{ [number]: Member }>,
	NextBlurAt: number,
	Sanity: Vide.Source<number>,
	Shown: Shown,
	State: Vide.Source<{ [number]: LifeState }>,
	Unmount: (() -> ())?,
	Vignette: Vide.Source<number>,
	Setup: (self: Public) -> (),
	BandOf: (self: Public, value: number, max: number) -> Band,
	StateOf: (self: Public, userId: number) -> LifeState?,
	IsActive: (self: Public) -> boolean,
	ApplySanity: (self: Public, value: number, max: number) -> (),
	ApplyMember: (self: Public, userId: number, record: Member) -> (),
	RemoveMember: (self: Public, userId: number) -> (),
	SetLocalState: (self: Public, state: LifeState) -> (),
	FaintAmount: (self: Public, now: number) -> (number, number),
	Effects: (self: Public) -> (ColorCorrectionEffect, BlurEffect),
	Step: (self: Public, dt: number) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
