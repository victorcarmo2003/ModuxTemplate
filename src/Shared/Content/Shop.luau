--!strict
-- Robux shop (user request 2026-10-11, Provisional; TASK-160; economy.md §9, data.md §1.7, network.md §15; Q-190).
-- Owner of the numbers: game-designer. Owner of the ids: the user (Creator Hub), copied here by backend-coder.
-- ProductId = Developer Product id from the Creator Hub. 0 = NOT CREATED YET: the server refuses it (ClassBuy answers
-- "Unavailable", no receipt can map to it) and the client hides or disables the Robux button. A ProductId > 0 that is
-- not on this experience fails at the client's PromptProductPurchase, never on the server.
-- Robux = SUGGESTED price for the Creator Hub and a display fallback only. The real price is the one set on the Creator
-- Hub (architecture.md §10.1): the client reads it with MarketplaceService:GetProductInfo(id, Enum.InfoType.Product).
-- Classes: one GAME PASS per class (TASK-291; owner request 2026-10-14, Provisional; was a Developer Product).
-- PassId = Game Pass id from the Creator Hub, 0 = not created yet (ClassBuy answers "Unavailable"). ShopService unlocks
-- the class in profile.Classes when the pass is bought (PromptGamePassPurchaseFinished) and on every join for an owner
-- of the pass (UserOwnsGamePassAsync, cached); a class already in the profile (gems, code) is never written twice.
-- The real pass price: GetProductInfo(id, Enum.InfoType.GamePass). GamePasses.Key must be a Content.Classes key.
-- Shop icons (one per key): Assets/textures/ui/shop/<Key>.png (+ .svg source), e.g. util_scare.png, class_fox.png,
-- gems_50.png, cash_100.png; uploaded 2026-10-15, ids in Assets/textures/ui/_texture_ids.json ("shop/<Key>").
local Table = require(script.Parent.Table)

export type GemPack = {
	Key: string,
	ProductId: number, -- 0 = not created on the Creator Hub yet
	Gems: number, -- credited to profile.Gems on the receipt (GemsEarned is not touched: earned, not bought)
	Robux: number, -- suggested price (Creator Hub), display fallback
	Name: string, -- placeholder (narrative-writer); also the suggested Creator Hub product name
	-- Display only (TASK-301, Provisional): the card shows Base + Bonus; Base + Bonus == Gems, the receipt credits Gems.
	Base: number,
	Bonus: number, -- 0 = no bonus tag
	Badge: GemBadge?, -- ribbon over the card
}

-- Ribbon of a gem pack card (GemShop): "Popular" (one mid pack), "Best" (the biggest, the highlighted card).
export type GemBadge = "Popular" | "Best"

export type GamePass = {
	Key: string, -- Content.Classes key; only InMvp classes are sold
	PassId: number, -- Game Pass id; 0 = not created on the Creator Hub yet
	Robux: number, -- suggested price (Creator Hub), display fallback
	Name: string, -- suggested Creator Hub pass name
}

-- Kept for the Content type export (Content.ShopClassProduct): a class is sold as a GamePass now.
export type ClassProduct = GamePass

-- In-run utilities (TASK-290; owner request 2026-10-14, Provisional): Developer Products bought from the HUD cart (key B).
-- Granted by ShopUtilityService on the Roblox receipt (server authority); the client only picks a target first (ShopPick).
--   Kind     what the grant does (ShopUtilityService):
--            Radar    marks the anomalies of the night for the buyer for Amount s (customers get an outline)
--            Scare    cartoon jumpscare (Mild, DEC-256) on one mate chosen by the buyer (Target = Mate)
--            Cash     party Cash += Amount (EconomyService:TopUp)
--            Restock  one ingredient to its capacity (Target = Ingredient; KitchenService:StockFree)
--            Pantry   every open ingredient to its capacity
--            Coffee   sanity to full at night; by day a coffee to keep (ItemService:Give)
--            Revive   +1 profile.ReviveCredits (DEC-117); spent by ReviveKitService (TASK-317): self while Down, or on a
--                     fallen mate's body (VitalService:Revive)
--   Target   what the buyer picks before the prompt ("Mate" | "Ingredient"); nil = nothing to pick
--   Night    only sold while a night shift runs (the client disables the card by day)
export type UtilityKind = "Radar" | "Scare" | "Cash" | "Restock" | "Pantry" | "Coffee" | "Revive"
export type UtilityTarget = "Mate" | "Ingredient"

export type Utility = {
	Key: string,
	ProductId: number, -- 0 = not created on the Creator Hub yet
	Robux: number, -- suggested price (Creator Hub), display fallback
	Name: string, -- card title; also the suggested Creator Hub product name
	Text: string, -- one line under the title
	Icon: string, -- Icons name ("" = none)
	Kind: UtilityKind,
	Amount: number, -- Radar: seconds; Cash: dollars; others 0
	Target: UtilityTarget?,
	Night: boolean,
	Category: string, -- a Content.Shop.Categories key: the shop section the card sits in
	Tone: string, -- Theme.Tone name of the card (owner 2026-10-16: coins yellow, scare red, revive green...)
}

-- In-run shop sections, in order (owner request 2026-10-16: "dividir em categorias", a header line + icon + title, then
-- the cards; plain words a kid reads at a glance)
export type Category = { Key: string, Title: string, Icon: string }

-- Gifts (TASK-352; owner request 2026-10-16, Provisional): one Developer Product per giftable item, bought by the giver
-- for another player. GiftPrompt stores the recipient, the receipt sends a ProfileStore message to the recipient's
-- profile (GiftService), delivered even offline. Key = "gift_" .. Target.
--   Kind     Class  Target = a Content.Shop.GamePasses key (an owned class arrives as its gem Price instead)
--            Gems   Target = a Content.Shop.GemPacks key (credits that pack's Gems)
export type GiftKind = "Class" | "Gems"

export type Gift = {
	Key: string,
	ProductId: number, -- 0 = not created on the Creator Hub yet ("coming soon": never prompted, the server refuses)
	Kind: GiftKind,
	Target: string, -- GamePasses key (Class) or GemPacks key (Gems)
	Robux: number, -- suggested price (Creator Hub) = the price of the item itself, display fallback
	Name: string, -- suggested Creator Hub product name
}

export type Shop = {
	GemPacks: Table.Table<GemPack>,
	GamePasses: Table.Table<GamePass>,
	Utilities: Table.Table<Utility>,
	Categories: { Category },
	Gifts: Table.Table<Gift>,
	Keys: { string }, -- every product / pass key (gem packs, passes, utilities, gifts): the MetricUi.Key wire enum
}

-- Gem packs: bigger pack = cheaper gem (99 -> 90 R$ per 1,000 gems). Gem economy x75 (TASK-308, owner request
-- 2026-10-15, Provisional; economy.md §6/§9, Q-274): a full solo run earns ~28,000 gems in ~6.4 h; classes cost
-- 2,000..20,000. Keys stay (Creator Hub products, icons); the Robux prices did not change, so the totals are capped by
-- them: popular 4,800 and not 5,000 (5,000 for 449 would beat the 10,000 for 899 per gem).
-- Base / Bonus / Badge: display only (TASK-301, owner request 2026-10-15): the same totals shown as a promotion,
-- bigger bonus on bigger packs (0 / +20% / +33% / +43%).
const gemPacks: { GemPack } = {
	{
		Key = "gems_50",
		ProductId = 3718682061,
		Gems = 1000,
		Robux = 99,
		Name = "Handful of Gems",
		Base = 1000,
		Bonus = 0,
	},
	{
		Key = "gems_130",
		ProductId = 3718682070,
		Gems = 2400,
		Robux = 229,
		Name = "Pouch of Gems",
		Base = 2000,
		Bonus = 400,
	},
	{
		Key = "gems_300",
		ProductId = 3718682077,
		Gems = 4800,
		Robux = 449,
		Name = "Crate of Gems",
		Base = 3600,
		Bonus = 1200,
		Badge = "Popular",
	},
	{
		Key = "gems_700",
		ProductId = 3718682082,
		Gems = 10000,
		Robux = 899,
		Name = "Truckload of Gems",
		Base = 7000,
		Bonus = 3000,
		Badge = "Best",
	},
}

-- Class Game Passes (TASK-291): were a bit cheaper than buying the same gems (tier 1: 79 vs ~99 for 50 gems). With the
-- x75 gem prices (TASK-308) a pass is far cheaper than the gems of the class (Rabbit: 79 vs ~190); suggested Robux
-- kept until the owner answers Q-274 (c). Panda and Lion are not InMvp (DEC-186): no pass until the first update.
const gamePasses: { GamePass } = {
	{ Key = "class_rabbit", PassId = 2036210519, Robux = 79, Name = "Rabbit Crew" }, -- tier 1, 2,000 gems
	{ Key = "class_cat", PassId = 2037014530, Robux = 79, Name = "Cat Crew" }, -- tier 1, 2,000 gems
	{ Key = "class_bear", PassId = 2037116542, Robux = 79, Name = "Bear Crew" }, -- tier 1, 3,000 gems
	{ Key = "class_fox", PassId = 2040074273, Robux = 199, Name = "Fox Crew" }, -- tier 2, 10,000 gems
	{ Key = "class_owl", PassId = 2037164541, Robux = 199, Name = "Owl Crew" }, -- tier 2, 10,000 gems
}

-- Utilities (TASK-290, Provisional; Q-271 to Q-273 in open-questions.md). Cheap impulse buys, 15..149 R$. Cash packs
-- (TASK-324, owner request 2026-10-15, Provisional; economy.md §5): fixed amounts sized on a solo night of the anomaly
-- run (~$55 on Night 1, ~$90 on Night 10, ~$75 average): $60 ~ one night, $150 ~ two, $330 ~ four, never the whole
-- Gear Stand (~$850 in the anomaly mode). Bigger pack = a bit more cash per Robux (2.07 / 2.17 / 2.21). Keys and
-- ProductIds stay (Creator Hub); only Amount, Text and the Creator Hub description changed (was $100 / $300 / $800).
const utilities: { Utility } = {
	{
		Key = "util_scare",
		ProductId = 3718677086,
		Robux = 50,
		Name = "Scare a Friend",
		Text = "Give a friend a big BOO!",
		Icon = "Ui/megaphone",
		Kind = "Scare",
		Amount = 0,
		Target = "Mate",
		Night = false,
		Category = "Fun",
		Tone = "Ketchup",
	},
	{
		Key = "util_radar",
		ProductId = 3718677699,
		Robux = 20,
		Name = "Anomaly Radar",
		Text = "Shows every anomaly for 90 s",
		Icon = "Ui/spectate",
		Kind = "Radar",
		Amount = 90,
		Night = true,
		Category = "Survive",
		Tone = "Ink",
	},
	{
		Key = "util_coffee",
		ProductId = 3718677756,
		Robux = 10,
		Name = "Hot Coffee",
		Text = "Fills your sanity bar",
		Icon = "Item/coffee",
		Kind = "Coffee",
		Amount = 0,
		Night = false,
		Category = "Survive",
		Tone = "Teal",
	},
	{
		Key = "util_restock",
		ProductId = 3718682098,
		Robux = 25,
		Name = "Wild Restock",
		Text = "Refills 1 ingredient",
		Icon = "Item/pack_sausages",
		Kind = "Restock",
		Amount = 0,
		Target = "Ingredient",
		Night = false,
		Category = "Kitchen",
		Tone = "Violet",
	},
	{
		Key = "util_pantry",
		ProductId = 3718682101,
		Robux = 59,
		Name = "Full Pantry",
		Text = "Refills all ingredients",
		Icon = "Upgrade/cooler/3",
		Kind = "Pantry",
		Amount = 0,
		Night = false,
		Category = "Kitchen",
		Tone = "Violet",
	},
	{
		Key = "util_revive",
		ProductId = 3718682106, -- live since VitalService:Revive (TASK-317, closes Q-273)
		Robux = 39,
		Name = "Revive Kit",
		Text = "Get back up when you faint",
		Icon = "Item/revive_kit",
		Kind = "Revive",
		Amount = 0,
		Night = false,
		Category = "Survive",
		Tone = "Green",
	},
	{
		Key = "cash_100",
		ProductId = 3718682111,
		Robux = 29,
		Name = "Tip Bag",
		Text = "+60 Coins",
		Icon = "Shop/cash_100",
		Kind = "Cash",
		Amount = 60,
		Night = false,
		Category = "Coins",
		Tone = "Mustard",
	},
	{
		Key = "cash_300",
		ProductId = 3718682118,
		Robux = 69,
		Name = "Coin Pile", -- art: a pile of the game's coins (owner 2026-10-15)
		Text = "+150 Coins",
		Icon = "Shop/cash_300",
		Kind = "Cash",
		Amount = 150,
		Night = false,
		Category = "Coins",
		Tone = "Mustard",
	},
	{
		Key = "cash_800",
		ProductId = 3718682122,
		Robux = 149,
		Name = "Coin Chest", -- art: a chest full of coins (owner 2026-10-15)
		Text = "+330 Coins",
		Icon = "Shop/cash_800",
		Kind = "Cash",
		Amount = 330,
		Night = false,
		Category = "Coins",
		Tone = "Mustard",
	},
}

-- Gifts (TASK-352): derived, one per gem pack and one per class pass, same suggested Robux as the item. ProductIds
-- come from the Creator Hub (owner); 0 = not created yet.
const giftIds: { [string]: number } = {
	gift_gems_50 = 3719096880,
	gift_gems_130 = 3719096895,
	gift_gems_300 = 3719096906,
	gift_gems_700 = 3719096913,
	gift_class_rabbit = 3719096829,
	gift_class_cat = 3719096836,
	gift_class_bear = 3719096850,
	gift_class_fox = 3719096863,
	gift_class_owl = 3719096870,
}

const gifts: { Gift } = {}
for _, pack in gemPacks do
	const key = `gift_{pack.Key}`
	const row: Gift = {
		Key = key,
		ProductId = giftIds[key] or 0,
		Kind = "Gems",
		Target = pack.Key,
		Robux = pack.Robux,
		Name = `Gift: {pack.Name}`,
	}
	table.insert(gifts, row)
end
for _, pass in gamePasses do
	const key = `gift_{pass.Key}`
	const row: Gift = {
		Key = key,
		ProductId = giftIds[key] or 0,
		Kind = "Class",
		Target = pass.Key,
		Robux = pass.Robux,
		Name = `Gift: {pass.Name}`,
	}
	table.insert(gifts, row)
end

const allKeys: { string } = {}
for _, list in { gemPacks :: { any }, gamePasses :: { any }, utilities :: { any }, gifts :: { any } } do
	for _, row in list do
		table.insert(allKeys, row.Key)
	end
end

const categories: { Category } = {
	{ Key = "Coins", Title = "Coins", Icon = "Hud/coin" },
	{ Key = "Survive", Title = "Survive the Night", Icon = "Item/revive_kit" },
	{ Key = "Kitchen", Title = "Kitchen", Icon = "Item/pack_sausages" },
	{ Key = "Fun", Title = "Fun", Icon = "Ui/megaphone" },
}

const shop: Shop = {
	GemPacks = Table.new(gemPacks),
	GamePasses = Table.new(gamePasses),
	Utilities = Table.new(utilities),
	Categories = table.freeze(categories),
	Gifts = Table.new(gifts),
	Keys = table.freeze(allKeys),
}

return Table.record(shop)
