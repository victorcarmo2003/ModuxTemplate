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
}
export type Patch = Struct.Partial<Template.Data>

export type Public = {
	Handlers: { [number]: Handler },
	Names: { [number]: string },
	Setup: (self: Public) -> (),
	RegisterProduct: (self: Public, productId: number, name: string, handler: Handler) -> (),
	Notify: (self: Public, player: Player, kind: string, value: number) -> (),
	ReplyClass: (self: Public, player: Player, key: string, reason: "Granted" | "Converted") -> (),
	GemPackHandler: (self: Public, pack: Content.ShopGemPack) -> Handler,
	ClassHandler: (self: Public, key: string) -> Handler,
	RegisterContent: (self: Public) -> (),
	WaitProfile: (self: Public, player: Player) -> Profile?,
	ProcessReceipt: (self: Public, receipt: Receipt) -> Enum.ProductPurchaseDecision,
	Fulfil: (self: Public, player: Player, handler: Handler, purchaseId: string, name: string) -> Enum.ProductPurchaseDecision,
	DevReceipt: (self: Public, player: Player, key: string, purchaseId: string) -> string,
}

return {}
