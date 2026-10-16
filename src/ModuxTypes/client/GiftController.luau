--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local GiftPicker = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.GiftPicker)

export type Kind = "Info" | "Good" | "Alert"
export type Toaster = (text: string, kind: Kind) -> ()

export type Public = {
	Before: GuiObject?,
	Busy: Vide.Source<boolean>,
	CloseHandle: any,
	Found: Vide.Source<{ GiftPicker.Candidate }>,
	Gui: ScreenGui?,
	Key: Vide.Source<string>,
	Lookup: Vide.Source<GiftPicker.Lookup>,
	Recipients: { [string]: string },
	Roster: Vide.Source<{ GiftPicker.Candidate }>,
	Scale: Vide.Source<number>,
	SearchId: number,
	Selected: Vide.Source<number>,
	SentAt: number,
	Shown: Vide.Source<boolean>,
	Toaster: Toaster?,
	Waiting: string,
	Setup: (self: Public) -> (),
	GiftOf: (self: Public, target: string) -> Content.ShopGift?,
	CanGift: (self: Public, target: string) -> boolean,
	TitleOf: (self: Public, key: string) -> string,
	PriceOf: (self: Public, key: string) -> string,
	SetToaster: (self: Public, toaster: Toaster?) -> (),
	Say: (self: Public, text: string, kind: Kind) -> (),
	Click: (self: Public) -> (),
	Candidates: (self: Public) -> { GiftPicker.Candidate },
	RefreshRoster: (self: Public, leaving: Player?) -> (),
	Open: (self: Public, key: string) -> (),
	Close: (self: Public) -> (),
	IsOpen: (self: Public) -> boolean,
	SelectFirst: (self: Public) -> (),
	BindClose: (self: Public) -> (),
	UnbindClose: (self: Public) -> (),
	Select: (self: Public, userId: number) -> (),
	Search: (self: Public, raw: string) -> (),
	NameOf: (self: Public, userId: number) -> string,
	Confirm: (self: Public) -> (),
	Prompt: (self: Public, key: string) -> (),
	OnResult: (self: Public, result: { Ok: boolean, Reason: string, Key: string }) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
