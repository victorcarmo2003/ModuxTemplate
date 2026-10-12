--!strict
--[[
	CoffeeCupController (owner request 2026-10-12; PROVISIONAL; numbers in Content.CoffeeCup)

	The owner-built cup on the trailer counter has an inner Part (the coffee surface). It rises while the machine
	brews and sinks when the coffee is taken. One TweenService tween per change, no Heartbeat.

	State comes from what already exists: KitchenController/Coffee.luau mirrors the replicated coffee_machine record on
	the station Model (CoffeeCupState / CoffeeCupSeconds, client only). This controller finds the station by the cup's
	`CupStation` attribute (its MapId), listens to those attributes, and tweens. `CupDev` (set by /dev coffee) overrides.

	Discovery by tag `CoffeeCup`, tolerant to streaming: the surface and the body are looked up by name and again when
	a descendant streams in. Pure presentation: nothing is sent to the server.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Params = Content.CoffeeCup
const STATION_TAG = "Station"

type Cup = {
	Root: Instance,
	Surface: BasePart?,
	Body: BasePart?,
	FullRelative: CFrame?, -- surface CFrame in body space when full
	EmptyOffset: number,
	Level: number?, -- last target: 1 full, 0 empty (nil = not painted yet)
	Tween: Tween?,
	Stations: { [Instance]: RBXScriptConnection },
	Links: { RBXScriptConnection },
}

const CoffeeCupController = Modux.Controller("CoffeeCupController", { Priority = 300 })

function CoffeeCupController:Setup()
	self.Cups = {} :: { [Instance]: Cup }
end

local function style(name: string, fallback: Enum.EasingStyle): Enum.EasingStyle
	const item = (Enum.EasingStyle :: any)[name]
	return if typeof(item) == "EnumItem" then item else fallback
end

local function direction(name: string, fallback: Enum.EasingDirection): Enum.EasingDirection
	const item = (Enum.EasingDirection :: any)[name]
	return if typeof(item) == "EnumItem" then item else fallback
end

-- Looks up the surface and the body by name below the cup (again when a late part streams in)
local function resolve(cup: Cup)
	const root = cup.Root
	if cup.Surface == nil or cup.Surface.Parent == nil then
		const name = root:GetAttribute(Params.SurfaceAttribute)
		const found = if typeof(name) == "string" then root:FindFirstChild(name, true) else nil
		cup.Surface = if found and found:IsA("BasePart") then found else nil
	end
	if cup.Body == nil or cup.Body.Parent == nil then
		const name = root:GetAttribute(Params.BodyAttribute)
		const found = if typeof(name) == "string" then root:FindFirstChild(name, true) else nil
		cup.Body = if found and found:IsA("BasePart") then found else nil
	end
	const full = root:GetAttribute(Params.FullCFrameAttribute)
	cup.FullRelative = if typeof(full) == "CFrame" then full else nil
	const offset = root:GetAttribute(Params.EmptyOffsetAttribute)
	cup.EmptyOffset = if typeof(offset) == "number" then offset else Params.DefaultEmptyOffset
end

local function ready(cup: Cup): boolean
	return cup.Surface ~= nil and cup.Body ~= nil and cup.FullRelative ~= nil
end

-- (CFrame, Transparency) of the surface at level 1 (full) or 0 (empty)
local function pose(cup: Cup, level: number): (CFrame, number)
	const body = cup.Body :: BasePart
	const full = body.CFrame * (cup.FullRelative :: CFrame)
	if level >= 1 then
		return full, 0
	end
	return full - Vector3.new(0, cup.EmptyOffset, 0), Params.EmptyTransparency
end

-- 0..1: how full the surface is right now (from its transparency, so a tween cut in half resumes from where it is)
local function fillOf(cup: Cup): number
	const surface = cup.Surface :: BasePart
	const span = Params.EmptyTransparency
	if span <= 0 then
		return 1
	end
	return math.clamp(1 - surface.Transparency / span, 0, 1)
end

-- Moves the surface to `level`; `seconds` = 0 snaps. One tween per change, the previous one is cancelled.
function CoffeeCupController:Paint(cup: Cup, level: number, seconds: number, easing: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	if not ready(cup) then
		return
	end
	if cup.Level == level then
		return -- already there, or on its way
	end
	const surface = cup.Surface :: BasePart
	if cup.Tween then
		cup.Tween:Cancel()
		cup.Tween = nil
	end
	cup.Level = level
	const target, transparency = pose(cup, level)
	if seconds <= 0 then
		surface.CFrame = target
		surface.Transparency = transparency
		return
	end
	const tween = TweenService:Create(
		surface,
		TweenInfo.new(seconds, easing or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.Out),
		{ CFrame = target, Transparency = transparency }
	)
	cup.Tween = tween
	tween.Completed:Connect(function()
		if cup.Tween == tween then
			cup.Tween = nil
		end
	end)
	tween:Play()
end

-- What the cup should show now: (level, seconds, easing, direction)
local function desired(cup: Cup): (number, number, Enum.EasingStyle, Enum.EasingDirection)
	const fill = Params.Fill
	const drain = Params.Drain
	const fillStyle, fillDirection = style(fill.Easing, Enum.EasingStyle.Sine), direction(fill.Direction, Enum.EasingDirection.Out)
	const drainStyle, drainDirection = style(drain.Easing, Enum.EasingStyle.Quad), direction(drain.Direction, Enum.EasingDirection.In)

	const dev = cup.Root:GetAttribute(Params.DevAttribute)
	local state = "Empty"
	local left = 0
	if dev == "fill" then
		state = "Ready"
	elseif dev == "empty" then
		state = "Empty"
	else
		for station in cup.Stations do
			const value = station:GetAttribute(Params.StationStateAttribute)
			if typeof(value) == "string" then
				state = value
				const seconds = station:GetAttribute(Params.StationSecondsAttribute)
				left = if typeof(seconds) == "number" then seconds else 0
				break
			end
		end
	end

	if state == "Working" then
		const seconds = if fill.FollowBrew then math.max(left, fill.MinSeconds) else fill.Seconds
		return 1, seconds, fillStyle, fillDirection
	elseif state == "Ready" then
		return 1, fill.Seconds, fillStyle, fillDirection
	end
	return 0, drain.Seconds, drainStyle, drainDirection
end

function CoffeeCupController:Refresh(cup: Cup, snap: boolean?)
	resolve(cup)
	if not ready(cup) then
		return
	end
	const level, seconds, easing, dir = desired(cup)
	local duration = seconds
	if snap then
		duration = 0
	elseif level >= 1 and not Params.Fill.FollowBrew or level < 1 then
		-- a surface already part of the way only travels the rest of the distance
		const remaining = math.abs(level - fillOf(cup))
		duration = seconds * math.max(remaining, Params.MinFraction)
	end
	self:Paint(cup, level, duration, easing, dir)
end

function CoffeeCupController:Link(cup: Cup, station: Instance)
	if cup.Stations[station] ~= nil then
		return
	end
	if station:GetAttribute("MapId") ~= cup.Root:GetAttribute(Params.StationAttribute) then
		return
	end
	const connection = station:GetAttributeChangedSignal(Params.StationStateAttribute):Connect(function()
		self:Refresh(cup)
	end)
	cup.Stations[station] = connection
	self:Refresh(cup)
end

function CoffeeCupController:Add(root: Instance)
	if self.Cups[root] ~= nil then
		return
	end
	const cup: Cup = {
		Root = root,
		Surface = nil,
		Body = nil,
		FullRelative = nil,
		EmptyOffset = Params.DefaultEmptyOffset,
		Level = nil,
		Tween = nil,
		Stations = {},
		Links = {},
	}
	self.Cups[root] = cup
	table.insert(cup.Links, root:GetAttributeChangedSignal(Params.DevAttribute):Connect(function()
		self:Refresh(cup)
	end))
	-- a late-streamed part (surface / body) may complete the cup
	table.insert(cup.Links, root.DescendantAdded:Connect(function()
		if not ready(cup) then
			self:Refresh(cup, true)
		end
	end))
	self:Refresh(cup, true) -- first paint: snap, then follow the machine
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		self:Link(cup, station)
	end
	self:Refresh(cup)
end

function CoffeeCupController:Remove(root: Instance)
	const cup = self.Cups[root]
	if cup == nil then
		return
	end
	self.Cups[root] = nil
	if cup.Tween then
		cup.Tween:Cancel()
	end
	for _, connection in cup.Links do
		connection:Disconnect()
	end
	for _, connection in cup.Stations do
		connection:Disconnect()
	end
end

CoffeeCupController:OnInit(function(self)
	self:Setup()
end)

CoffeeCupController:OnStart(function(self)
	CollectionService:GetInstanceAddedSignal(Params.Tag):Connect(function(root)
		self:Add(root)
	end)
	CollectionService:GetInstanceRemovedSignal(Params.Tag):Connect(function(root)
		self:Remove(root)
	end)
	-- stations (the trailer comes and goes): link every cup that waits for it
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(function(station)
		for _, cup in self.Cups do
			self:Link(cup, station)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(STATION_TAG):Connect(function(station)
		for _, cup in self.Cups do
			const connection = cup.Stations[station]
			if connection then
				connection:Disconnect()
				cup.Stations[station] = nil
				self:Refresh(cup)
			end
		end
	end)
	for _, root in CollectionService:GetTagged(Params.Tag) do
		self:Add(root)
	end
end)

return CoffeeCupController
