--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)
local ShopPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ShopPanel)

type Utility = ShopContent.Utility
export type AnomalyRecord = { Anomaly: string, Phase: string, StartedAt: number, Step: number, Anchor: number }

export type Public = {
	Announced: { [number]: boolean },
	Enabled: boolean,
	Flash: Vide.Source<string>,
	Glow: Vide.Source<boolean>,
	Gui: ScreenGui?,
	NextNudge: number,
	Nudge: Vide.Source<string>,
	NudgeGate: (() -> boolean)?,
	NudgeIcon: Vide.Source<string>,
	NudgePad: Vide.Source<string>,
	NudgeShown: (() -> ())?,
	OfferClick: (() -> ())?,
	OfferHint: Vide.Source<boolean>,
	OfferPadImage: string,
	Open: Vide.Source<boolean>,
	Others: Vide.Source<number>,
	Outlines: { [number]: Highlight },
	PickKey: string,
	Picking: Vide.Source<ShopPanel.Pick | false>,
	Prices: Vide.Source<{ [string]: number }>,
	RadarUntil: number,
	Records: { [number]: AnomalyRecord },
	Scale: Vide.Source<number>,
	Status: Vide.Source<string>,
	Tokens: { [string]: number },
	Setup: (self: Public) -> (),
	Flashy: (self: Public, slot: string, target: Vide.Source<string>, text: string, time: number) -> (),
	Say: (self: Public, text: string) -> (),
	Note: (self: Public, text: string, time: number?) -> (),
	Offer: (self: Public, text: string, icon: string, time: number, click: () -> ()) -> number,
	EndOffer: (self: Public) -> (),
	NoteToken: (self: Public) -> number,
	CanOffer: (self: Public) -> boolean,
	PromptOffer: (self: Public, key: string, target: number?) -> (),
	ShowCard: (self: Public, key: string) -> (),
	SetOpen: (self: Public, open: boolean) -> (),
	Select: (self: Public, open: boolean) -> (),
	NudgeLine: (self: Public) -> string,
	Toggle: (self: Public) -> (),
	FlashScare: (self: Public) -> (),
	FlashCard: (self: Public, key: string) -> (),
	OnNudge: (self: Public) -> (),
	PriceOf: (self: Public, utility: Utility) -> string,
	Cards: (self: Public) -> { ShopPanel.Card },
	Prompt: (self: Public, utility: Utility) -> (),
	Buy: (self: Public, key: string) -> (),
	Pick: (self: Public, id: number) -> (),
	Scare: (self: Public) -> (),
	OnGrant: (self: Public, data: { Product: string, Value: number, From: number }) -> (),
	ClearOutline: (self: Public, id: number) -> (),
	RefreshRadar: (self: Public) -> (),
	WatchAnomalies: (self: Public) -> (),
	CanNudge: (self: Public) -> boolean,
	StepNudge: (self: Public) -> (),
	CountOthers: (self: Public) -> (),
	LoadPadImage: (self: Public) -> (),
	LoadPrices: (self: Public) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
