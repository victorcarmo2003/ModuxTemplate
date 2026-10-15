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
}

export type Shop = {
	GemPacks: Table.Table<GemPack>,
	GamePasses: Table.Table<GamePass>,
	Utilities: Table.Table<Utility>,
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
-- follow the run economy (a Storage level costs $40..$110, economy.md): $100 is a good night, never a whole run.
const utilities: { Utility } = {
	{
		Key = "util_scare",
		ProductId = 3718677086,
		Robux = 50,
		Name = "Scare a Friend",
		Text = "Boo! A cartoon jumpscare on a mate",
		Icon = "Ui/megaphone",
		Kind = "Scare",
		Amount = 0,
		Target = "Mate",
		Night = false,
	},
	{
		Key = "util_radar",
		ProductId = 3718677699,
		Robux = 20,
		Name = "Anomaly Radar",
		Text = "Marks every anomaly for 90 s",
		Icon = "Ui/spectate",
		Kind = "Radar",
		Amount = 90,
		Night = true,
	},
	{
		Key = "util_coffee",
		ProductId = 3718677756,
		Robux = 10,
		Name = "Hot Coffee",
		Text = "Sanity back to full",
		Icon = "Item/coffee",
		Kind = "Coffee",
		Amount = 0,
		Night = false,
	},
	{
		Key = "util_restock",
		ProductId = 3718682098,
		Robux = 25,
		Name = "Wild Restock",
		Text = "Fills any ingredient you pick",
		Icon = "Item/pack_sausages",
		Kind = "Restock",
		Amount = 0,
		Target = "Ingredient",
		Night = false,
	},
	{
		Key = "util_pantry",
		ProductId = 3718682101,
		Robux = 59,
		Name = "Full Pantry",
		Text = "Fills every ingredient",
		Icon = "Upgrade/cooler/3",
		Kind = "Pantry",
		Amount = 0,
		Night = false,
	},
	{
		Key = "util_revive",
		ProductId = 3718682106, -- live since VitalService:Revive (TASK-317, closes Q-273)
		Robux = 39,
		Name = "Revive Kit",
		Text = "Saved for when you go down",
		Icon = "Item/revive_kit",
		Kind = "Revive",
		Amount = 0,
		Night = false,
	},
	{
		Key = "cash_100",
		ProductId = 3718682111,
		Robux = 29,
		Name = "Tip Bag",
		Text = "+$100 for the crew",
		Icon = "Hud/coin",
		Kind = "Cash",
		Amount = 100,
		Night = false,
	},
	{
		Key = "cash_300",
		ProductId = 3718682118,
		Robux = 69,
		Name = "Coin Pile", -- art: a pile of the game's coins (owner 2026-10-15)
		Text = "+$300 for the crew",
		Icon = "Ui/cash",
		Kind = "Cash",
		Amount = 300,
		Night = false,
	},
	{
		Key = "cash_800",
		ProductId = 3718682122,
		Robux = 149,
		Name = "Coin Chest", -- art: a chest full of coins (owner 2026-10-15)
		Text = "+$800 for the crew",
		Icon = "Ui/tip_jar",
		Kind = "Cash",
		Amount = 800,
		Night = false,
	},
}

const shop: Shop = {
	GemPacks = Table.new(gemPacks),
	GamePasses = Table.new(gamePasses),
	Utilities = Table.new(utilities),
}

return Table.record(shop)
