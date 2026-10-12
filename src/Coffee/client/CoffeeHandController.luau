--!strict
--[[
	CoffeeHandController (owner request 2026-10-12; PROVISIONAL; numbers in Content.CoffeeCup.Sips / Hand)

	The cup in a player's hand (built by CoffeeHandService, tag Hand.Tag, inside the coffee Tool). When VitalService marks
	the Tool `Drinking` the coffee surface of the hand cup sinks and fades (one tween, Sips.EmptySeconds), on every
	client; the Tool is consumed right after. Same surface / body attributes as the map cup (CoffeeCupController).
	Presentation only: nothing is sent to the server.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Params = Content.CoffeeCup
const HOME = "HandHome" -- surface CFrame in body space when full (written on the first paint)

const CoffeeHandController = Modux.Controller("CoffeeHandController", { Priority = 310 })

function CoffeeHandController:Setup()
	self.Cups = {} :: { [Instance]: { RBXScriptConnection } }
end

local function enumItem(enum: any, name: string, fallback: any): any
	const item = enum[name]
	return if typeof(item) == "EnumItem" then item else fallback
end

local function partNamed(cup: Instance, attribute: string): BasePart?
	const name = cup:GetAttribute(attribute)
	const found = if typeof(name) == "string" then cup:FindFirstChild(name, true) else nil
	return if found and found:IsA("BasePart") then found else nil
end

-- Sinks the coffee of `cup` (drinking = true) or puts it back (false: dev preview)
function CoffeeHandController:Paint(cup: Instance, drinking: boolean)
	const surface = partNamed(cup, Params.SurfaceAttribute)
	const body = partNamed(cup, Params.BodyAttribute)
	if surface == nil or body == nil then
		return
	end
	local home = surface:GetAttribute(HOME)
	if typeof(home) ~= "CFrame" then
		home = body.CFrame:ToObjectSpace(surface.CFrame)
		surface:SetAttribute(HOME, home)
	end
	const offset = cup:GetAttribute(Params.EmptyOffsetAttribute)
	const sink = if typeof(offset) == "number" then offset else Params.DefaultEmptyOffset
	const scale = if cup:IsA("Model") then cup:GetScale() else 1
	const full = body.CFrame * (home :: CFrame)
	const goal = if drinking
		then { CFrame = full - Vector3.new(0, sink * scale, 0), Transparency = Params.EmptyTransparency }
		else { CFrame = full, Transparency = 0 }
	TweenService:Create(
		surface,
		TweenInfo.new(
			Params.Sips.EmptySeconds,
			enumItem(Enum.EasingStyle, Params.Sips.Easing, Enum.EasingStyle.Quad),
			enumItem(Enum.EasingDirection, Params.Sips.Direction, Enum.EasingDirection.In)
		),
		goal
	):Play()
end

function CoffeeHandController:Add(cup: Instance)
	if self.Cups[cup] ~= nil then
		return
	end
	const links: { RBXScriptConnection } = {}
	self.Cups[cup] = links
	-- the Tool is the parent; its attribute is the signal
	const tool = cup.Parent
	if tool == nil then
		return
	end
	table.insert(
		links,
		tool:GetAttributeChangedSignal(Params.Sips.DrinkingAttribute):Connect(function()
			self:Paint(cup, tool:GetAttribute(Params.Sips.DrinkingAttribute) == true)
		end)
	)
	if tool:GetAttribute(Params.Sips.DrinkingAttribute) == true then
		self:Paint(cup, true)
	end
end

function CoffeeHandController:Remove(cup: Instance)
	const links = self.Cups[cup]
	if links == nil then
		return
	end
	self.Cups[cup] = nil
	for _, connection in links do
		connection:Disconnect()
	end
end

CoffeeHandController:OnInit(function(self)
	self:Setup()
end)

CoffeeHandController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(Params.Hand.Tag):Connect(function(cup)
		self:Add(cup)
	end)
	CollectionService:GetInstanceRemovedSignal(Params.Hand.Tag):Connect(function(cup)
		self:Remove(cup)
	end)
	for _, cup in CollectionService:GetTagged(Params.Hand.Tag) do
		self:Add(cup)
	end
end)

return CoffeeHandController
