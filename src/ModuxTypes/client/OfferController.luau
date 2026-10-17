--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)

type Offer = ShopContent.Offer
type Utility = ShopContent.Utility
type Due = {
	Offer: Offer,
	Target: number?,
	Fill: { [string]: string },
	Memo: string?, -- per-target memory key ("restock:bun", "mate:123:45.2"): shown once
}
type PendingCash = { Product: string, Missing: number, At: number }
type PendingScare = { From: number, At: number }

export type Public = {
	Control: boolean,
	Enabled: boolean,
	Failed: { [number]: boolean },
	HadStock: { [string]: boolean },
	Ignored: { [string]: number },
	IgnoredRow: number,
	LastAt: number,
	LiveAt: number,
	Memo: { [string]: boolean },
	Muted: { [string]: boolean },
	OfferAt: { [string]: number },
	OfferCount: { [string]: number },
	PausedUntil: number,
	Pending: PendingCash?,
	PromptAt: number,
	Scare: PendingScare?,
	Shift: string,
	ShiftCount: number,
	ShopClick: boolean,
	Showing: { Key: string, Token: number, Clicked: boolean }?,
	Tips: boolean,
	Setup: (self: Public) -> (),
	Metric: (self: Public, event: string, offer: Offer?) -> (),
	ShiftKey: (self: Public) -> string,
	StepShift: (self: Public) -> (),
	PastTutorial: (self: Public) -> boolean,
	Calm: (self: Public, now: number) -> boolean,
	HasCoffee: (self: Public) -> boolean,
	Price: (self: Public, utility: Utility) -> string,
	Budget: (self: Public, now: number) -> boolean,
	Allowed: (self: Public, offer: Offer, now: number) -> boolean,
	StockDue: (self: Public, due: { Due }) -> (),
	SanityDue: (self: Public, due: { Due }) -> (),
	MateDue: (self: Public, due: { Due }) -> (),
	NightDue: (self: Public, due: { Due }) -> (),
	CashDue: (self: Public, due: { Due }, now: number) -> (),
	ScareDue: (self: Public, due: { Due }, now: number) -> (),
	ProductOf: (self: Public, entry: Due) -> string,
	Show: (self: Public, entry: Due, forced: boolean?) -> (),
	Ignore: (self: Public, offer: Offer, metricOffer: Offer) -> (),
	Blocked: (self: Public) -> boolean,
	Step: (self: Public) -> (),
	Reset: (self: Public) -> (),
	Status: (self: Public) -> string,
	Dev: (self: Public, text: string) -> (),
}

return {}
