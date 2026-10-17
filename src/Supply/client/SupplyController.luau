--!strict
--[[
	SupplyController (FEAT-050 client; design/restaurant-flow.md; TASK-389; infinite stock room, owner 2026-10-17)

	Presents the low stock of the restaurant stations. Decides nothing: it reads the Stock set the KitchenService writes.
	There is no phone order, no van and no hatch: every StockShelf bay of the stock room always gives a box (server
	SupplyService), so the bays carry no counter. Inert (no listener, no GUI) unless Content.Restaurant.Supply.Enabled AND
	Content.Restaurant.Rules.Enabled (both false by default, the same gate as the SupplyService).

	  Low stock: a Stock record (ingredient with a package, not Blocked, not Wrapped, Capacity > 0) at or under
	    Supply.LowAt of its Capacity. Crossing into low (from a record seen above it) pushes the stock_low toast once
	    ("Low on Buns": Content.Notices text with the Package name) through HudController; it re-arms above LowAt.
	  HUD chip (StockMenu.Chip, under the clock): "Low on <Package>" with the package icon pulsing while any product is
	    low; hidden otherwise.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local StockMenu = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.StockMenu)

-- HUD: under the clock pill (HudScreen TOP 6 + 32 + gap 8), px at UI scale 1
const UNDER_CLOCK = 46

export type StockRecord = { Amount: number, Capacity: number, Blocked: boolean, Wrapped: boolean? }

-- Packages row by ingredient key (first package of each ingredient)
const PACKAGE_OF: { [string]: any } = {}
for _, row in Content.Packages.List do
	if PACKAGE_OF[row.Ingredient] == nil then
		PACKAGE_OF[row.Ingredient] = row
	end
end

-- Ingredient key by Stock record id (Content.Ingredients.IndexOf)
const INGREDIENT_AT: { [number]: string } = {}
for key, index in Content.Ingredients.IndexOf do
	INGREDIENT_AT[index] = key
end

const SupplyController = Modux.Controller("SupplyController", {
	Require = { "HudController" },
	Priority = 280,
})

function SupplyController:Setup()
	self.Live = (Content.Restaurant.Supply.Enabled and Content.Restaurant.Rules.Enabled) :: boolean
	self.Stock = {} :: { [string]: StockRecord }
	-- ingredient keys under LowAt now, and the ones already toasted this drop
	self.LowKeys = Vide.source({}) :: Vide.Source<{ string }>
	self.Toasted = {} :: { [string]: boolean }
	self.Gui = nil :: ScreenGui?
end

local function isLow(record: StockRecord): boolean
	return not record.Blocked
		and record.Wrapped ~= true
		and record.Capacity > 0
		and record.Amount / record.Capacity <= Content.Restaurant.Supply.LowAt
end

-- Writes ----------------------------------------------------------------------------------------------------------------

function SupplyController:WriteStock(id: number, record: StockRecord?)
	const key = INGREDIENT_AT[id]
	if key == nil or PACKAGE_OF[key] == nil then
		return
	end
	const before = self.Stock[key]
	self.Stock[key] = record
	if record == nil or not isLow(record) then
		self.Toasted[key] = nil
	elseif before ~= nil and not isLow(before) and not self.Toasted[key] then
		-- one toast per drop under LowAt (a late joiner's first record, already low, is silent)
		self.Toasted[key] = true
		self:ToastLow(key)
	elseif before == nil then
		self.Toasted[key] = true
	end
	const low: { string } = {}
	for _, row in Content.Ingredients.List do
		const stock = self.Stock[row.Key]
		if stock ~= nil and PACKAGE_OF[row.Key] ~= nil and isLow(stock) then
			table.insert(low, row.Key)
		end
	end
	self.LowKeys(low)
end

function SupplyController:ToastLow(ingredient: string)
	const package = PACKAGE_OF[ingredient]
	const notice = Content.Notices.ByKey.stock_low
	if package == nil or notice == nil then
		return
	end
	const name = string.gsub(package.Name, "%%", "%%%%")
	const text = string.gsub(notice.Text, "{item}", name)
	pcall(function()
		self.Dependencies.HudController:PushText(text, "Alert")
	end)
end

-- HUD -------------------------------------------------------------------------------------------------------------------

function SupplyController:ChipText(): string
	const low = self.LowKeys()[1]
	const package = if low then PACKAGE_OF[low] else nil
	return if package then `Low on {package.Name}` else ""
end

function SupplyController:ChipIcon(): string
	const low = self.LowKeys()[1]
	const package = if low then PACKAGE_OF[low] else nil
	return `Item/{if package then package.Key else Content.Packages.List[1].Key}`
end

function SupplyController:Mount()
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	const hud = self.Dependencies.HudController
	const _, gui = Vide.root(function(): ScreenGui
		const scale = function(): number
			return hud.Scale()
		end
		return Vide.create("ScreenGui")({
			Name = "Supply",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 1,
			Enabled = function()
				return not Cinematic.Active()
			end,
			Vide.create("Frame")({
				Name = "Layer",
				BackgroundTransparency = 1,
				Size = function()
					const s = scale()
					return UDim2.fromScale(1 / s, 1 / s)
				end,
				(Vide.create :: any)("UIScale")({ Scale = scale }),
				StockMenu.Chip({
					Visible = function()
						return self:ChipText() ~= ""
					end,
					Icon = function()
						return self:ChipIcon()
					end,
					Text = function()
						return self:ChipText()
					end,
					Pulse = function()
						return #self.LowKeys() > 0
					end,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, UNDER_CLOCK),
				}),
			}),
		})
	end)
	gui.Parent = playerGui
	self.Gui = gui
end

SupplyController:OnInit(function(self)
	self:Setup()
	if not self.Live then
		return
	end
	-- listeners before Lync.start (README "Rede"); late joiners get the records through onAdded
	const net = self.Libs.Net
	net.Stock:onAdded(function(id, record)
		self:WriteStock(id, record :: any)
	end)
	net.Stock:onChanged(function(id, record)
		self:WriteStock(id, record :: any)
	end)
	net.Stock:onRemoved(function(id)
		self:WriteStock(id, nil)
	end)
end)

SupplyController:OnStart(function(self)
	if not self.Live then
		return
	end
	-- PlayerGui may arrive a little late; do not hold up the other OnStart
	task.spawn(function()
		self:Mount()
	end)
end)

return SupplyController
