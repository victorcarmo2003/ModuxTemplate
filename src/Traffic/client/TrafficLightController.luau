--!strict
--[[
	TrafficLightController (owner request 2026-10-12; PROVISIONAL; cycle in Content.TrafficLights)

	Paints the street lights of MAP-01 from the pure cycle in `Content.TrafficLights`, on `workspace:GetServerTimeNow()`
	so every client shows the same phase. Purely visual: nothing on the server reads it (the cars of TrafficService
	do not stop for it yet).

	Discovery by tag, tolerant to streaming: a model/part tagged `TrafficSignal` (car head, lamps Red / Yellow / Green)
	or `PedSignal` (lamps Walk / Hand), attribute `Axis` = EW | NS. Lamps are found by name among the descendants and
	again when a descendant streams in. Each lamp keeps its lit colour in the attribute `OnColor` (written once from the
	current colour when the lamp is Neon and the attribute is missing; a lamp with no known lit colour is left alone).

	Look (same as the first Studio-only script): lit = Neon + OnColor; off = SmoothPlastic + OnColor x OffDim; an existing
	PointLight on the lamp follows it (none is created). One Heartbeat, two samples per frame (one per axis, numbers only),
	and a signal is repainted only when its (phase, ped) pair changes: no table is allocated per frame.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Cycle = Content.TrafficLights
const BLACK = Color3.new(0, 0, 0)

type Lamp = {
	Part: BasePart,
	OnColor: Color3?,
	Lit: boolean?, -- last look written
}

type Signal = {
	Root: Instance,
	Axis: string,
	IsPed: boolean,
	Lamps: { Lamp }, -- head: [1] Red [2] Yellow [3] Green; ped: [1] Walk [2] Hand
	Count: number, -- lamps found (a late-streamed lamp triggers a rescan)
	Key: number, -- last painted phase * 10 + ped; -1 = repaint
	Link: RBXScriptConnection?,
}

const TrafficLightController = Modux.Controller("TrafficLightController", { Priority = 300 })

function TrafficLightController:Setup()
	self.Signals = {} :: { Signal }
	self.ByRoot = {} :: { [Instance]: Signal }
	self.Beat = nil :: RBXScriptConnection?
end

local function lampNames(isPed: boolean): { string }
	return if isPed then Cycle.PedLamps else Cycle.HeadLamps
end

-- Finds the lamps by name below the root (or the root itself) and returns how many were found
local function scan(signal: Signal)
	const names = lampNames(signal.IsPed)
	local found = 0
	for index, name in names do
		local part: Instance? = if signal.Root.Name == name then signal.Root else signal.Root:FindFirstChild(name, true)
		const known = signal.Lamps[index]
		if part ~= nil and part:IsA("BasePart") then
			found += 1
			if known == nil or known.Part ~= part then
				local onColor: Color3? = nil
				const attribute = part:GetAttribute(Cycle.OnColorAttribute)
				if typeof(attribute) == "Color3" then
					onColor = attribute
				elseif part.Material == Enum.Material.Neon then
					onColor = part.Color
					part:SetAttribute(Cycle.OnColorAttribute, part.Color)
				end
				signal.Lamps[index] = { Part = part, OnColor = onColor, Lit = nil }
			end
		end
	end
	signal.Count = found
	signal.Key = -1
end

local function paintLamp(lamp: Lamp, lit: boolean)
	if lamp.Lit == lit then
		return
	end
	const onColor = lamp.OnColor
	if onColor == nil then
		return
	end
	lamp.Lit = lit
	const part = lamp.Part
	if lit then
		part.Material = Enum.Material.Neon
		part.Color = onColor
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = onColor:Lerp(BLACK, 1 - Cycle.OffDim)
	end
	const light = part:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Enabled = lit
	end
end

local function paint(signal: Signal, phase: number, ped: number)
	const lamps = signal.Lamps
	if signal.IsPed then
		const walk = lamps[1]
		const hand = lamps[2]
		if walk then
			paintLamp(walk, ped == Cycle.PED_WALK)
		end
		if hand then
			paintLamp(hand, ped == Cycle.PED_HAND_LIT)
		end
	else
		const red = lamps[1]
		const yellow = lamps[2]
		const green = lamps[3]
		if red then
			paintLamp(red, phase == Cycle.PHASE_RED)
		end
		if yellow then
			paintLamp(yellow, phase == Cycle.PHASE_YELLOW)
		end
		if green then
			paintLamp(green, phase == Cycle.PHASE_GREEN)
		end
	end
end

function TrafficLightController:Add(root: Instance, isPed: boolean)
	if self.ByRoot[root] ~= nil then
		return
	end
	const axis = root:GetAttribute(Cycle.AxisAttribute)
	if axis ~= "EW" and axis ~= "NS" then
		warn(`[TrafficLight] {root:GetFullName()} has no valid Axis attribute (EW | NS)`)
		return
	end
	const signal: Signal = { Root = root, Axis = axis, IsPed = isPed, Lamps = {}, Count = 0, Key = -1, Link = nil }
	scan(signal)
	-- lamps stream in part by part: a new descendant rescans only while some lamp is still missing
	signal.Link = root.DescendantAdded:Connect(function()
		if signal.Count < #lampNames(isPed) then
			scan(signal)
		end
	end)
	self.ByRoot[root] = signal
	table.insert(self.Signals, signal)
end

function TrafficLightController:Remove(root: Instance)
	const signal = self.ByRoot[root]
	if signal == nil then
		return
	end
	self.ByRoot[root] = nil
	if signal.Link then
		signal.Link:Disconnect()
	end
	const index = table.find(self.Signals, signal)
	if index then
		table.remove(self.Signals, index)
	end
end

-- Heartbeat: sample each axis once, repaint only the signals whose pair changed
function TrafficLightController:Step()
	const now = Workspace:GetServerTimeNow()
	const ewPhase, ewPed = Cycle.sample("EW", now)
	const nsPhase, nsPed = Cycle.sample("NS", now)
	for _, signal in self.Signals do
		const isEW = signal.Axis == "EW"
		const phase = if isEW then ewPhase else nsPhase
		const ped = if isEW then ewPed else nsPed
		const key = phase * 10 + ped
		if signal.Key ~= key then
			signal.Key = key
			paint(signal, phase, ped)
		end
	end
end

TrafficLightController:OnInit(function(self)
	self:Setup()
end)

TrafficLightController:OnStart(function(self)
	for _, kind in { Cycle.Tags.Head, Cycle.Tags.Ped } do
		const isPed = kind == Cycle.Tags.Ped
		CollectionService:GetInstanceAddedSignal(kind):Connect(function(root)
			self:Add(root, isPed)
		end)
		CollectionService:GetInstanceRemovedSignal(kind):Connect(function(root)
			self:Remove(root)
		end)
		for _, root in CollectionService:GetTagged(kind) do
			self:Add(root, isPed)
		end
	end
	self.Beat = RunService.Heartbeat:Connect(function()
		self:Step()
	end)
end)

return TrafficLightController
