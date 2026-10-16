--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local ShopTypes = require(ServerScriptService.server.ModuxTypes.ShopService)

type Handler = ShopTypes.Handler
export type Kind = Content.ShopGiftKind
export type Message = {
	Gift: true, -- marks a gift message (other message kinds may share the profile queue later)
	Id: string, -- PurchaseId of the receipt, or "admin:<guid>"
	Kind: Kind,
	Key: string, -- Class: class key. Gems: gem pack key, "" for an admin gift
	Amount: number, -- Gems: gems to credit. Class: 0
	From: number, -- UserId of the giver (0 = admin console without a player)
	FromName: string,
	At: number, -- os.time() when sent
}
export type Reason = "Ok" | "Sent" | "Self" | "NotFound" | "Unavailable" | "Rate" | "Busy" | "Failed"

export type Public = {
	Busy: { [Player]: boolean },
	Known: { [number]: boolean },
	Outbox: { [Player]: { any } },
	PromptAt: { [Player]: number },
	Setup: (self: Public) -> (),
	Reply: (self: Public, player: Player, key: string, reason: Reason) -> (),
	Tell: (self: Public, player: Player, payload: any) -> (),
	Flush: (self: Public, player: Player) -> (),
	Exists: (self: Public, userId: number) -> boolean?,
	Send: (self: Public, recipient: number, message: Message) -> boolean,
	SendFree: (self: Public, recipient: number, kind: Kind, key: string, amount: number, from: Player?) -> boolean,
	Prompt: (self: Public, player: Player, key: string, recipient: number) -> Reason,
	ClearPending: (self: Public, player: Player, key: string, recipient: number) -> (),
	Handler: (self: Public, gift: Content.ShopGift) -> Handler,
	Receive: (self: Public, player: Player, raw: { [string]: any }, processed: () -> ()) -> (),
}

return {}
