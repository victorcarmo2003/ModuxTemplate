--!strict
--[[
	CoffeeHandController (owner request 2026-10-12; PROVISIONAL; numbers in Content.CoffeeCup.Sips / Hand)

	The cup in a player's hand (built by CoffeeHandService, tag Hand.Tag, inside the coffee Tool). When VitalService marks
	the Tool `Drinking` the coffee surface of the hand cup sinks and fades (one tween, Sips.EmptySeconds), on every
	client; the Tool is consumed right after. Same surface / body attributes as the map cup (CoffeeCupController).
	Click response (TASK-479, Provisional): the server applies the sip Sips.DrinkTime after the click, so the holder's
	client puffs a little steam from its cup at once on Tool.Activated (no wait for the round trip); the payoff itself
	(screen pulse, sparkles, "+N") is VitalController / HudSanity on the `Gain` cue. Skipped with reduced motion.
	Presentation only: nothing is sent to the server.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)

const Params = Content.CoffeeCup
const HOME = "HandHome" -- surface CFrame in body space when full (written on the first paint)
const STEAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const STEAM_PUFF = 4 -- wisps on the click
const STEAM_LIFE = 0.7 -- s

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

-- A short steam puff above the hand cup (the holder's click, before the server answers)
function CoffeeHandController:Puff(cup: Instance)
	if Motion.Reduced() then
		return
	end
	const body = partNamed(cup, Params.BodyAttribute)
	if body == nil then
		return
	end
	const attachment = Instance.new("Attachment")
	attachment.Name = "CoffeePuff"
	attachment.Position = Vector3.new(0, body.Size.Y / 2, 0)
	const steam = Instance.new("ParticleEmitter")
	steam.Texture = STEAM_TEXTURE
	steam.Enabled = false
	steam.LightInfluence = 0
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Size = NumberSequence.new(0.2, 0.7)
	steam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Lifetime = NumberRange.new(STEAM_LIFE * 0.7, STEAM_LIFE)
	steam.Speed = NumberRange.new(1.5, 3)
	steam.SpreadAngle = Vector2.new(25, 25)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Parent = attachment
	attachment.Parent = body
	steam:Emit(STEAM_PUFF)
	task.delay(STEAM_LIFE + 0.2, function()
		attachment:Destroy()
	end)
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
	-- Activated only fires on the holder's client; the character check keeps it to our own hand
	if tool:IsA("Tool") then
		const held: Tool = tool
		table.insert(
			links,
			held.Activated:Connect(function()
				const character = Players.LocalPlayer.Character
				if character ~= nil and held.Parent == character and held:GetAttribute(Params.Sips.DrinkingAttribute) ~= true then
					self:Puff(cup)
				end
			end)
		)
	end
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
