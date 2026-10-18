--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Look = { TextSize: number, IconSize: number, Padding: number, Outline: number?, Studs: boolean? }

export type Public = {
	Bound: boolean,
	Busy: Vide.Source<boolean>,
	Count: Vide.Source<number>,
	Focus: Vide.Source<boolean>,
	FocusThread: thread?,
	Gui: ScreenGui?,
	Setup: (self: Public) -> (),
	Shows: (self: Public) -> boolean,
	Offered: (self: Public) -> boolean,
	SetFocus: (self: Public, down: boolean) -> (),
	CanBuy: (self: Public) -> boolean,
	Label: (self: Public) -> string,
	Use: (self: Public) -> (),
	Buy: (self: Public) -> (),
	SetBound: (self: Public, on: boolean) -> (),
	Row: (self: Public, name: string, anchor: Vector2, position: UDim2, height: number, visible: () -> boolean, look: Look) -> Frame,
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
