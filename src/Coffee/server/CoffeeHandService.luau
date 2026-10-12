--!strict
--[[
	CoffeeHandService (owner request 2026-10-12; PROVISIONAL; numbers in Content.CoffeeCup.Hand / Sips)

	The coffee the player takes from the machine is a Tool (ItemService "coffee"). Its template Handle is a plain cup
	mesh; here every coffee Tool that lands in a player's Backpack gets a visible cup in the hand: a clone of the
	owner-built map cup (tag CoffeeCup, Workspace.ManFaceMug), parts only, welded to the Handle, with the template mesh
	hidden. The clone is tagged Hand.Tag; CoffeeHandController (client) sinks its coffee when VitalService marks the Tool
	`Drinking`. It lives inside the Tool, so the Consume of the drink (or a hand-over to a mate) takes it along.
	No network: parts and the tag replicate by themselves. A missing map cup leaves the template cup visible.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const Params = Content.CoffeeCup
const COFFEE_ITEM = "coffee"
const ITEM_ATTRIBUTE = "Item" -- Tool attribute written by ItemService:Give
const CUP_NAME = "HandCup"

const CoffeeHandService = Modux.Service("CoffeeHandService", { Priority = 300 })

-- The map cup, found by tag (its attributes name the surface and the body)
local function mapCup(): Model?
	for _, cup in CollectionService:GetTagged(Params.Tag) do
		if cup:IsA("Model") then
			return cup
		end
	end
	return nil
end

-- Hand cup for `tool`; false when the map cup is not there (yet)
function CoffeeHandService:Dress(tool: Tool): boolean
	if tool:FindFirstChild(CUP_NAME) then
		return true
	end
	const handle = tool:FindFirstChild("Handle")
	const source = mapCup()
	if source == nil or handle == nil or not handle:IsA("BasePart") then
		return false
	end

	const cup = source:Clone()
	cup.Name = CUP_NAME
	-- only the cup itself: no scripts, no station link, no tag of the map cup
	for _, descendant in cup:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Camera") then
			descendant:Destroy()
		end
	end
	cup:SetAttribute(Params.DevAttribute, nil)
	cup:SetAttribute(Params.StationAttribute, nil)
	for _, tag in CollectionService:GetTags(cup) do
		CollectionService:RemoveTag(cup, tag)
	end
	cup:ScaleTo(Params.Hand.Scale)

	-- centre of the cup on the Handle (the pivot of the map cup is not its centre), orientation as built (upright)
	const box = cup:GetBoundingBox()
	const delta = (handle.Position + Vector3.new(0, Params.Hand.OffsetY, 0)) - box.Position
	cup:PivotTo(cup:GetPivot() + delta)

	for _, descendant in cup:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	-- the template cup mesh goes invisible, the Handle still holds the grip
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		end
	end
	cup.Parent = tool
	CollectionService:AddTag(cup, Params.Hand.Tag)
	tool.ToolTip = Params.Sips.ToolTip
	return true
end

function CoffeeHandService:Watch(player: Player)
	local function consider(instance: Instance)
		if instance:IsA("Tool") and instance:GetAttribute(ITEM_ATTRIBUTE) == COFFEE_ITEM then
			self:Dress(instance)
		end
	end
	player.DescendantAdded:Connect(consider)
	for _, descendant in player:GetDescendants() do
		consider(descendant)
	end
end

CoffeeHandService:OnInit(function(_self) end)

CoffeeHandService:OnStart(function(self)
	Players.PlayerAdded:Connect(function(player)
		self:Watch(player)
	end)
	for _, player in Players:GetPlayers() do
		self:Watch(player)
	end
end)

return CoffeeHandService
