--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local SanityTier = require(ReplicatedStorage.shared.Anomaly.SanityTier)

export type LifeState = "Active" | "Down" | "Reviving" | "Spectator" | "Away"
export type Band = "Day" | "Mid" | "Night"
export type Gain = { Amount: number, Id: number }
export type Shown = { Vignette: number, Saturation: number, Tint: number }
export type Member = {
	State: LifeState,
	StateEndsAt: number,
	KnockedUntil: number,
	Class: string,
}

export type Public = {
	ActiveSince: number,
	Band: Vide.Source<Band>,
	Blackout: Vide.Source<number>,
	Blur: BlurEffect?,
	BlurUntil: number,
	CoffeeAt: number?,
	CoffeeGain: Vide.Source<Gain?>,
	CoffeeHint: Vide.Source<boolean>,
	Color: ColorCorrectionEffect?,
	Dark: Vide.Source<boolean>,
	DarkTickAt: number,
	FaintAt: number?,
	FaintTip: Vide.Source<Content.FaintTip?>,
	GainId: number,
	Gui: ScreenGui?,
	HintMachine: Instance?,
	HintUntil: number,
	LocalState: Vide.Source<LifeState>,
	Max: Vide.Source<number>,
	Members: Vide.Source<{ [number]: Member }>,
	NextBeatAt: number,
	NextBlurAt: number,
	NextBreathAt: number,
	NextWordsAt: number,
	Sanity: Vide.Source<number>,
	Shown: Shown,
	State: Vide.Source<{ [number]: LifeState }>,
	TierIndex: number,
	Unmount: (() -> ())?,
	Vignette: Vide.Source<number>,
	Warm: Vide.Source<number>,
	Setup: (self: Public) -> (),
	BandOf: (self: Public, value: number, max: number) -> Band,
	StateOf: (self: Public, userId: number) -> LifeState?,
	IsActive: (self: Public) -> boolean,
	ApplySanity: (self: Public, value: number, max: number) -> (),
	FindCoffeeMachine: (self: Public) -> Instance?,
	BeginHint: (self: Public, untilT: number) -> (),
	EndHint: (self: Public) -> (),
	ApplyCue: (self: Public, kind: string, amount: number, untilT: number) -> (),
	CoffeePayoff: (self: Public) -> (),
	CoffeeAmount: (self: Public, now: number) -> number,
	ApplyMember: (self: Public, userId: number, record: Member) -> (),
	RemoveMember: (self: Public, userId: number) -> (),
	SetLocalState: (self: Public, state: LifeState) -> (),
	PlayLifeSound: (self: Public, userId: number, previous: LifeState, state: LifeState) -> (),
	FaintAmount: (self: Public, now: number) -> (number, number),
	Effects: (self: Public) -> (ColorCorrectionEffect, BlurEffect),
	EnterTier: (self: Public, now: number) -> (),
	Signs: (self: Public, now: number, tier: SanityTier.Tier) -> (),
	Step: (self: Public, dt: number) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
	TipOf: (self: Public, cause: string, known: boolean) -> Content.FaintTip,
}

return {}
