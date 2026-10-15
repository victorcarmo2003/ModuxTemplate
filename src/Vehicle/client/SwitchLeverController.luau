--!strict
--[[
	SwitchLeverController (owner request 2026-10-12, Provisional)

	The wall levers of the trailer (parts Box + Lever + PilotLamp): the BLUE switch is the lights (PromptAction
	switch_light), the service window lever next to the phone is the shop (PromptAction shutter_toggle, TRL-SHUTTER;
	TASK-284 2026-10-14: the red "Open Shop" switch open_sign left, the window is the shop). This only flips the Lever
	part, local and purely visual: up = on (lights lit / window open), down = off (lights out / window shut), a short
	tween and the `switch_click` sound at the lever. The state is the server's: the Lights record of the Switch group
	(LightService) and the `Shutter` attribute of the vehicle Model (VehicleService, true = closed).
	Provisional: TILT, TIME, the pivot on the Box surface.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const ANCHOR_TAG = "Interactable"
const LIGHT_ACTION = "switch_light"
const SHUTTER_ACTION = "shutter_toggle"
const VEHICLE_TAG = "Vehicle"
const SHUTTER_ATTRIBUTE = "Shutter" -- on the vehicle Model, true = closed
const LEVER_NAME = "Lever"
const TILT = math.rad(26) -- lever swing around the Box X axis, up (on) / down (off)
const TIME = 0.18 -- s of the flip
const CLICK = "switch_click"
const TICK_RATE = 4

type Switch = {
	Box: BasePart,
	Lever: BasePart,
	Rel: CFrame, -- authored Lever in Box space
	Pivot: Vector3, -- tilt pivot in Box space (the Lever base on the Box surface)
	Action: string,
	Vehicle: Instance?, -- shutter lever: the `Vehicle`-tagged ancestor carrying the Shutter attribute
	Angle: number,
	From: number,
	To: number,
	StartedAt: number?,
	Seen: boolean, -- the first state is set without a flip
}

const SwitchLeverController = Modux.Controller("SwitchLeverController", { Require = { "RoundController", "AudioController" }, Priority = 310 })

function SwitchLeverController:Setup()
	self.Switches = {} :: { [Instance]: Switch }
	-- Lights record of the Switch group (true until the first record arrives: every night starts lit)
	self.LightOn = true :: boolean
	self.Step = nil :: RBXScriptConnection?
end

function SwitchLeverController:Register(anchor: Instance)
	if not anchor:IsA("Attachment") or self.Switches[anchor] ~= nil then
		return
	end
	const action = anchor:GetAttribute("PromptAction")
	if typeof(action) ~= "string" or (action ~= LIGHT_ACTION and action ~= SHUTTER_ACTION) then
		return
	end
	const box = anchor.Parent
	const model = if box then box.Parent else nil
	const lever = if model then model:FindFirstChild(LEVER_NAME) else nil
	if box == nil or not box:IsA("BasePart") or lever == nil or not lever:IsA("BasePart") then
		return
	end
	const rel = box.CFrame:ToObjectSpace(lever.CFrame)
	-- the Lever sits on the +Z face of the Box: the pivot is that face under the lever
	const pivot = Vector3.new(rel.X, rel.Y, math.sign(rel.Z) * box.Size.Z / 2)
	local vehicle: Instance? = model
	while vehicle ~= nil and vehicle ~= workspace and not CollectionService:HasTag(vehicle, VEHICLE_TAG) do
		vehicle = vehicle.Parent
	end
	self.Switches[anchor] = {
		Box = box,
		Lever = lever,
		Rel = rel,
		Pivot = pivot,
		Action = action,
		Vehicle = if vehicle ~= workspace then vehicle else nil,
		Angle = 0,
		From = 0,
		To = 0,
		StartedAt = nil,
		Seen = false,
	}
end

function SwitchLeverController:IsOn(switch: Switch): boolean
	if switch.Action == LIGHT_ACTION then
		return self.LightOn
	end
	const vehicle = switch.Vehicle
	return vehicle ~= nil and vehicle:GetAttribute(SHUTTER_ATTRIBUTE) ~= true
end

local function pose(switch: Switch, angle: number): CFrame
	const pivot = CFrame.new(switch.Pivot)
	return switch.Box.CFrame * pivot * CFrame.Angles(angle, 0, 0) * pivot:Inverse() * switch.Rel
end

function SwitchLeverController:Apply(switch: Switch)
	if switch.Lever.Parent ~= nil then
		switch.Lever.CFrame = pose(switch, switch.Angle)
	end
end

function SwitchLeverController:Refresh()
	for anchor, switch in self.Switches do
		if not anchor:IsDescendantOf(workspace) then
			self.Switches[anchor] = nil
			continue
		end
		const target = if self:IsOn(switch) then TILT else -TILT
		if not switch.Seen then
			switch.Seen = true
			switch.Angle, switch.From, switch.To = target, target, target
			self:Apply(switch)
		elseif switch.To ~= target then
			switch.From = switch.Angle
			switch.To = target
			switch.StartedAt = os.clock()
			self.Dependencies.AudioController:Play(CLICK, switch.Box.Position)
			if self.Step == nil then
				self.Step = RunService.RenderStepped:Connect(function()
					self:StepLevers()
				end)
			end
		elseif switch.StartedAt == nil then
			-- at rest: keep the pose (the part can be moved by a late stream-in)
			const wanted = pose(switch, switch.Angle)
			if (switch.Lever.CFrame.Position - wanted.Position).Magnitude > 1e-3 then
				switch.Lever.CFrame = wanted
			end
		end
	end
end

function SwitchLeverController:StepLevers()
	const now = os.clock()
	local moving = false
	for _, switch in self.Switches do
		const startedAt = switch.StartedAt
		if startedAt == nil then
			continue
		end
		const alpha = math.clamp((now - startedAt) / TIME, 0, 1)
		const eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		switch.Angle = switch.From + (switch.To - switch.From) * eased
		if alpha >= 1 then
			switch.Angle = switch.To
			switch.StartedAt = nil
		else
			moving = true
		end
		self:Apply(switch)
	end
	if not moving then
		const step = self.Step
		if step then
			self.Step = nil
			step:Disconnect()
		end
	end
end

SwitchLeverController:OnInit(function(self)
	self:Setup()

	const lights = self.Libs.Net.Lights
	const keys = Content.LightGroups.Keys
	local function store(id: number, record: { On: boolean })
		const key = keys[id]
		const group = if key then Content.LightGroups.ByKey[key] else nil
		if group and group.Kind == "Switch" then
			self.LightOn = record.On
		end
	end
	lights:onAdded(store)
	lights:onChanged(store)
end)

SwitchLeverController:OnStart(function(self)
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		self:Register(anchor)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		-- attributes and parents replicate after the tag: try again a moment later
		task.delay(0.5, function()
			self:Register(anchor)
		end)
	end)
	self:Refresh()
end)

SwitchLeverController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return SwitchLeverController
