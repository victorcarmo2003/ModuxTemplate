--!strict
-- HUD cart utilities (TASK-290; owner request 2026-10-14, Provisional): the Developer Products of Content.Shop.Utilities.
-- Registers each one with ShopService:RegisterProduct (receipts, idempotency and the confirmed save stay there), and the
-- grant acts on the run through the public APIs of the owners (no rewrite of their state):
--   Cash     EconomyService:TopUp(cash + Amount)            Restock / Pantry  KitchenService:StockFree(ingredient, cap)
--   Coffee   VitalService:AddSanity to full at night; otherwise a coffee Tool (ItemService:Give) to drink later
--   Revive   profile.ReviveCredits + 1 (DEC-117); ReviveKitService spends it (self while Down, or on a fallen mate,
--            VitalService:Revive; TASK-317) and gets the new count to the client. Bought while Down ("Revive now",
--            TASK-330): the new credit is spent on the buyer right away (ReviveKitService:Use), kept if refused
--   Radar    ShopGrant to the buyer (the client marks the anomalies of the Anomalies set for Amount s)
--   Scare    ShopGrant to the chosen mate (the client plays the cartoon jumpscare, Mild, DEC-256)
-- Run utilities (Cash, Restock, Pantry, Coffee, Radar) bought where no run exists (lobby) answer Wait: the receipt stays
-- unprocessed and Roblox delivers it again in a later server. Scare and Revive grant anywhere.
-- Targets: the client sends ShopPick right before the prompt; the next receipt of that product uses it. A missing or
-- stale pick falls back to a server choice (another player at random; the emptiest open ingredient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local ShopContent = require(ReplicatedStorage.shared.Content.Shop)
local Modux = require(ServerScriptService.server.Modux)

type Utility = ShopContent.Utility

const PICK_GAP = 0.2 -- s between two ShopPick of the same player
const REVIVE_MAX = 99
const SANITY_CAUSE = "shop_coffee"

const ShopUtilityService = Modux.Service("ShopUtilityService", {
	Require = {
		"ShopService",
		"ProfileService",
		"NetService",
		"PlaceService",
		"EconomyService",
		"KitchenService",
		"VitalService",
		"ItemService",
		"ReviveKitService",
	},
	Priority = 400,
})

function ShopUtilityService:Setup()
	-- player -> product key -> target (UserId or ingredient index)
	self.Picks = {} :: { [Player]: { [string]: number } }
	self.PickAt = {} :: { [Player]: number }
end

function ShopUtilityService:InRun(): boolean
	return not self.Dependencies.PlaceService:Is("Lobby")
end

function ShopUtilityService:Send(player: Player, key: string, value: number, from: number)
	const net = self.Dependencies.NetService
	if not net:IsRunning() or not net:IsReady(player) then
		return
	end
	self.Libs.Net.ShopGrant:fireClient(player, {
		Product = key,
		Value = math.clamp(math.floor(value), 0, 100000),
		From = from,
	})
end

function ShopUtilityService:TakePick(player: Player, key: string): number
	const picks = self.Picks[player]
	if picks == nil then
		return 0
	end
	const target = picks[key] or 0
	picks[key] = nil
	return target
end

-- The mate to scare: the picked one if still here and not the buyer, else another player at random (nil = alone).
function ShopUtilityService:MateOf(player: Player, picked: number): Player?
	const chosen = Players:GetPlayerByUserId(picked)
	if chosen ~= nil and chosen ~= player then
		return chosen
	end
	const others: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, other)
		end
	end
	if #others == 0 then
		return nil
	end
	return others[math.random(1, #others)]
end

-- The ingredient to fill: the picked one if open and not full, else the open one with the lowest fill.
function ShopUtilityService:IngredientOf(picked: number): string?
	const kitchen = self.Dependencies.KitchenService
	const row = Content.Ingredients.List[picked]
	if row ~= nil and not kitchen:IsBlocked(row.Key) then
		const have, capacity = kitchen:GetStock(row.Key)
		if have < capacity then
			return row.Key
		end
	end
	local best: string? = nil
	local bestFill = math.huge
	for _, ingredient in Content.Ingredients.List do
		if kitchen:IsBlocked(ingredient.Key) then
			continue
		end
		const have, capacity = kitchen:GetStock(ingredient.Key)
		if capacity > 0 and have < capacity and have / capacity < bestFill then
			best = ingredient.Key
			bestFill = have / capacity
		end
	end
	return best
end

function ShopUtilityService:Fill(ingredient: string): number
	const kitchen = self.Dependencies.KitchenService
	const _, capacity = kitchen:GetStock(ingredient)
	return kitchen:StockFree(ingredient, capacity)
end

-- Handler of one utility (ShopService.Handler): the effect runs in After, once, right after the PurchaseId is written.
function ShopUtilityService:Handler(utility: Utility): any
	const key = utility.Key
	return function(player: Player, profile: any): any
		const kind = utility.Kind
		const runOnly = kind == "Cash" or kind == "Restock" or kind == "Pantry" or kind == "Coffee" or kind == "Radar"
		if runOnly and not self:InRun() then
			return { Patch = {}, Wait = true }
		end

		if kind == "Revive" then
			return {
				Patch = { ReviveCredits = math.clamp(profile.ReviveCredits() + 1, 0, REVIVE_MAX) },
				After = function()
					const kits = self.Dependencies.ReviveKitService
					-- bought while Down ("Revive now" on the faint screen, TASK-330): spent on the buyer at once;
					-- refused (night over, revives spent) = the credit stays for later
					if self.Dependencies.VitalService:GetState(player.UserId) == "Down" and kits:Use(player, player) then
						self:Send(player, key, 1, 0)
						return
					end
					kits:SendCount(player)
					self:Send(player, key, 1, 0)
				end,
			}
		elseif kind == "Coffee" then
			const vital = self.Dependencies.VitalService
			const _, max = vital:GetSanity(player)
			if max > 0 and vital:IsActive(player) then
				return {
					Patch = {},
					After = function()
						vital:AddSanity(player, max, SANITY_CAUSE)
						self:Send(player, key, 1, 0)
					end,
				}
			end
			-- by day (or Down): a coffee to drink later; no free hand = try again later
			const items = self.Dependencies.ItemService
			if not items:CanGive(player, "coffee") then
				return { Patch = {}, Wait = true }
			end
			return {
				Patch = {},
				After = function()
					items:Give(player, "coffee")
					self:Send(player, key, 0, 0)
				end,
			}
		elseif kind == "Scare" then
			const mate = self:MateOf(player, self:TakePick(player, key))
			return {
				Patch = {},
				After = function()
					if mate ~= nil then
						self:Send(mate, key, 1, player.UserId) -- Value 1 = you are the one scared
					end
					self:Send(player, key, 0, if mate then mate.UserId else 0)
				end,
			}
		elseif kind == "Restock" then
			const picked = self:TakePick(player, key)
			return {
				Patch = {},
				After = function()
					const ingredient = self:IngredientOf(picked)
					if ingredient ~= nil then
						self:Fill(ingredient)
					end
					self:Send(player, key, if ingredient then Content.Ingredients.IndexOf[ingredient] else 0, 0)
				end,
			}
		elseif kind == "Pantry" then
			return {
				Patch = {},
				After = function()
					local filled = 0
					for _, ingredient in Content.Ingredients.List do
						if self:Fill(ingredient.Key) > 0 then
							filled += 1
						end
					end
					self:Send(player, key, filled, 0)
				end,
			}
		elseif kind == "Cash" then
			return {
				Patch = {},
				After = function()
					const economy = self.Dependencies.EconomyService
					const added = economy:TopUp(economy:GetCash() + utility.Amount)
					self:Send(player, key, added, 0)
				end,
			}
		end
		-- Radar
		return {
			Patch = {},
			After = function()
				self:Send(player, key, utility.Amount, 0)
			end,
		}
	end
end

ShopUtilityService:OnInit(function(self)
	self:Setup()

	const shop = self.Dependencies.ShopService
	for _, utility in Content.Shop.Utilities.List do
		shop:RegisterProduct(utility.ProductId, utility.Key, self:Handler(utility))
	end

	self.Libs.Net.ShopPick:onServer(function(data, player: Player)
		const now = os.clock()
		const last = self.PickAt[player]
		if last ~= nil and now - last < PICK_GAP then
			return
		end
		self.PickAt[player] = now
		const target = data.Target
		if target ~= target or target < 0 or target > 1e15 then
			return
		end
		const picks = self.Picks[player] or {}
		picks[data.Product] = math.floor(target)
		self.Picks[player] = picks
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.Picks[player] = nil
		self.PickAt[player] = nil
	end)
end)

return ShopUtilityService
