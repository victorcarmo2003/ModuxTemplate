--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local TicketHud = require(StarterPlayer.StarterPlayerScripts.client.Plate.PlateController.TicketHud)

type Customer = {
	State: string,
	PatienceEndsAt: number,
	PatienceSpan: number,
	Number: number?,
	Order: { [string]: boolean },
	Order2: { [string]: boolean }?,
	Pickup: number?,
	Drive: number?,
	Bread: boolean, -- the order is a bun alone (Content.OrderRules.BreadOnly, ANM-011)
}
type TicketMemo = { Number: number?, Order: { string }, Order2: { string }?, Drive: boolean, Bread: boolean }

export type Public = {
	Clock: Vide.Source<number>,
	Customers: Vide.Source<{ [number]: Customer }>,
	Hand: TicketHud.Tracker?,
	HudGui: ScreenGui?,
	HudPosition: Vide.Source<UDim2>,
	Lit: { [string]: Highlight },
	Pans: { [string]: Instance },
	Scale: Vide.Source<number>,
	Tickets: { [number]: TicketMemo },
	Setup: (self: Public) -> (),
	WriteCustomer: (self: Public, id: number, record: any?) -> (),
	TicketNumber: (self: Public, npc: number) -> number?,
	OrderOf: (self: Public, ticket: number, line: number) -> { string }?,
	BreadOf: (self: Public, ticket: number) -> boolean,
	BreadReady: (self: Public, held: TicketHud.HeldPlate) -> boolean,
	Current: (self: Public) -> TicketHud.HeldPlate?,
	HudCard: (self: Public) -> TicketHud.CardProps,
	PlaceHud: (self: Public) -> (),
	EquippedPlate: (self: Public) -> TicketHud.HeldPlate?,
	AtPickup: (self: Public, ticket: number) -> boolean?,
	PanOf: (self: Public, key: string) -> Instance?,
	LightPans: (self: Public) -> (),
	Watch: (self: Public, gui: Instance) -> (),
}

return {}
