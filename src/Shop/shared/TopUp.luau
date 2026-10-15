--!strict
-- TopUp (owner request 2026-10-15): when a player tries to buy something without enough gems (lobby: a class) or Cash
-- (run: market, upgrades, tables), the game prompts the Developer Product that covers the difference. Roblox products
-- have fixed prices, so "the difference" is the smallest CREATED pack (ProductId > 0) whose amount covers `missing`;
-- when none is big enough, the biggest created one (the player can buy again). Gems: Content.Shop.GemPacks; Cash: the
-- Cash utilities (Content.Shop.Utilities, Kind "Cash"; only sold in a run). Pure: Content only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Pack = {
	Key: string,
	ProductId: number,
	Amount: number,
}

local function pick(packs: { Pack }, missing: number): Pack?
	if missing <= 0 then
		return nil
	end
	local best: Pack? = nil
	local biggest: Pack? = nil
	for _, pack in packs do
		if pack.ProductId > 0 then
			if pack.Amount >= missing and (best == nil or pack.Amount < best.Amount) then
				best = pack
			end
			if biggest == nil or pack.Amount > biggest.Amount then
				biggest = pack
			end
		end
	end
	return best or biggest
end

-- Gem pack for `missing` gems; nil = nothing missing or no pack created.
local function gems(missing: number): Pack?
	const packs: { Pack } = {}
	for _, pack in Content.Shop.GemPacks.List do
		table.insert(packs, { Key = pack.Key, ProductId = pack.ProductId, Amount = pack.Gems })
	end
	return pick(packs, missing)
end

-- Cash pack for `missing` dollars of the party Cash; nil = nothing missing or no pack created.
local function cash(missing: number): Pack?
	const packs: { Pack } = {}
	for _, utility in Content.Shop.Utilities.List do
		if utility.Kind == "Cash" then
			table.insert(packs, { Key = utility.Key, ProductId = utility.ProductId, Amount = utility.Amount })
		end
	end
	return pick(packs, missing)
end

return table.freeze({
	Gems = gems,
	Cash = cash,
})
