--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Atomic = require(ReplicatedStorage.shared.Types.Atomic)
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Template = require(ServerScriptService.server.Profile.ProfileService.Template)

type Profile = Atomic.Table<Template.Data>
export type Handler = (player: Player, profile: Profile) -> Grant
export type Receipt = {
	PlayerId: number,
	PurchaseId: string,
	ProductId: number,
}
export type Grant = {
	Patch: Patch,
	After: (() -> ())?,
	Wait: boolean?,
	Send: ((purchaseId: string) -> boolean)?,
}
export type Patch = Struct.Partial<Template.Data>

export type Public = {
	ByKey: { [string]: Handler },
	Handlers: { [number]: Handler },
	Names: { [number]: string },
	Passes: { [Player]: { [number]: boolean } },
	Sending: { [string]: boolean },
	Setup: (self: Public) -> (),
	RegisterProduct: (self: Public, productId: number, name: string, handler: Handler) -> (),
	Notify: (self: Public, player: Player, kind: string, value: number) -> (),
	ReplyClass: (self: Public, player: Player, key: string, reason: "Granted") -> (),
	GemPackHandler: (self: Public, pack: Content.ShopGemPack) -> Handler,
	BundleHandler: (self: Public, bundle: Content.ShopBundle) -> Handler,
	OwnsPass: (self: Public, player: Player, passId: number) -> boolean?,
	OwnsClassPass: (self: Public, player: Player, key: string) -> boolean,
	GrantPass: (self: Public, player: Player, key: string, notify: boolean) -> boolean,
	CheckPasses: (self: Public, player: Player) -> (),
	OnPassFinished: (self: Public, player: Player, passId: number, purchased: boolean) -> (),
	RegisterContent: (self: Public) -> (),
	WaitProfile: (self: Public, player: Player) -> Profile?,
	ProcessReceipt: (self: Public, receipt: Receipt) -> Enum.ProductPurchaseDecision,
	Fulfil: (self: Public, player: Player, handler: Handler, purchaseId: string, name: string) -> Enum.ProductPurchaseDecision,
	DevReceipt: (self: Public, player: Player, key: string, purchaseId: string) -> string,
}

return {}
