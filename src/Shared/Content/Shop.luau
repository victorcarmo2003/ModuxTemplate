--!strict
-- Robux shop (user request 2026-10-11, Provisional; TASK-160; economy.md §9, data.md §1.7, network.md §15; Q-190).
-- Owner of the numbers: game-designer. Owner of the ids: the user (Creator Hub), copied here by backend-coder.
-- ProductId = Developer Product id from the Creator Hub. 0 = NOT CREATED YET: the server refuses it (ClassBuy answers
-- "Unavailable", no receipt can map to it) and the client hides or disables the Robux button. A ProductId > 0 that is
-- not on this experience fails at the client's PromptProductPurchase, never on the server.
-- Robux = SUGGESTED price for the Creator Hub and a display fallback only. The real price is the one set on the Creator
-- Hub (architecture.md §10.1): the client reads it with MarketplaceService:GetProductInfo(id, Enum.InfoType.Product).
-- Classes: one Developer Product per class, not a Game Pass (data.md §1.7: ownership lives in profile.Classes for both
-- currencies; a product bought for a class already owned turns into its gem price, nothing is lost).
-- Keys are persisted nowhere (receipts store the PurchaseId) but ClassProducts.Key must be a Content.Classes key.
local Table = require(script.Parent.Table)

export type GemPack = {
	Key: string,
	ProductId: number, -- 0 = not created on the Creator Hub yet
	Gems: number, -- credited to profile.Gems on the receipt (GemsEarned is not touched: earned, not bought)
	Robux: number, -- suggested price (Creator Hub), display fallback
	Name: string, -- placeholder (narrative-writer); also the suggested Creator Hub product name
}

export type ClassProduct = {
	Key: string, -- Content.Classes key; only InMvp classes are sold
	ProductId: number, -- 0 = not created on the Creator Hub yet
	Robux: number, -- suggested price (Creator Hub), display fallback
}

export type Shop = {
	GemPacks: Table.Table<GemPack>,
	ClassProducts: Table.Table<ClassProduct>,
}

-- Gem packs: bigger pack = cheaper gem (1.98 -> 1.28 R$/gem). Reference: a full solo run earns ~375 gems in ~6.4 h
-- (economy.md §6); tier 1/2/3 classes cost 45/120/180 gems (DEC-070).
const gemPacks: { GemPack } = {
	{ Key = "gems_50", ProductId = 0, Gems = 50, Robux = 99, Name = "Handful of Gems" },
	{ Key = "gems_130", ProductId = 0, Gems = 130, Robux = 229, Name = "Pouch of Gems" },
	{ Key = "gems_300", ProductId = 0, Gems = 300, Robux = 449, Name = "Crate of Gems" },
	{ Key = "gems_700", ProductId = 0, Gems = 700, Robux = 899, Name = "Truckload of Gems" },
}

-- Direct class purchase: a bit cheaper than buying the same gems in the smallest pack (tier 1: 79 vs ~99 for 50 gems).
-- Panda and Lion are not InMvp (DEC-186): no product until the first update.
const classProducts: { ClassProduct } = {
	{ Key = "class_rabbit", ProductId = 0, Robux = 79 }, -- tier 1, 45 gems
	{ Key = "class_cat", ProductId = 0, Robux = 79 }, -- tier 1, 45 gems
	{ Key = "class_bear", ProductId = 0, Robux = 79 }, -- tier 1, 45 gems
	{ Key = "class_fox", ProductId = 0, Robux = 199 }, -- tier 2, 120 gems
	{ Key = "class_owl", ProductId = 0, Robux = 199 }, -- tier 2, 120 gems
}

const shop: Shop = {
	GemPacks = Table.new(gemPacks),
	ClassProducts = Table.new(classProducts),
}

return Table.record(shop)
