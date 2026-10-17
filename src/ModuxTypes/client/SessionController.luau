--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local RejoinPopup = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.RejoinPopup)

export type Public = {
	Active: boolean,
	Busy: Vide.Source<boolean>,
	Gui: ScreenGui?,
	Now: Vide.Source<number>,
	Offer: Vide.Source<{ RejoinPopup.Offer }>,
	Token: number,
	Setup: (self: Public) -> (),
	Click: (self: Public) -> (),
	Toast: (self: Public, text: string, kind: "Info" | "Good" | "Alert") -> (),
	OnReconnect: (self: Public, data: { Mode: string, Day: number, IsNight: boolean, Reason: string, Left: number }) -> (),
	Rejoin: (self: Public) -> (),
	Dismiss: (self: Public) -> (),
	Tick: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
