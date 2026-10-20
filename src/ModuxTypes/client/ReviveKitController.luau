--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)

export type Stage = "None" | "Cause" | "Countdown" | "Wait" | "ReviveAll"

export type Public = {
	Bound: boolean,
	Busy: Vide.Source<boolean>,
	CauseUntil: Vide.Source<number>,
	Count: Vide.Source<number>,
	Focus: Vide.Source<boolean>,
	FocusThread: thread?,
	Gui: ScreenGui?,
	Now: Vide.Source<number>,
	Setup: (self: Public) -> (),
	Shows: (self: Public) -> boolean,
	Stage: (self: Public) -> Stage,
	Seconds: (self: Public) -> number,
	Tip: (self: Public) -> Content.FaintTip,
	Offered: (self: Public) -> boolean,
	SetFocus: (self: Public, down: boolean) -> (),
	CanBuy: (self: Public) -> boolean,
	Label: (self: Public) -> string,
	Use: (self: Public) -> (),
	Buy: (self: Public, key: string) -> (),
	SetBound: (self: Public, on: boolean) -> (),
	Offer: (self: Public) -> Frame,
	CauseCard: (self: Public) -> Frame,
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
