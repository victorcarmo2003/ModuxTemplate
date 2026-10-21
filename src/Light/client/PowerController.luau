--!strict
--[[
	PowerController (owner requests 2026-10-21, Provisional; network.md §13.2a)

	Reader of the Power set (record 1, LightService): mirrors it into Light/Power (Out = ANM-020 blackout still on,
	Burnt = kitchen bulb) for the other client modules (Effects/ANM-020 keeps its dark while Out after the occurrence
	ended) and presents the kitchen bulb burnout (Content.Bulb; the count is LightService's). When the record turns Burnt within Bulb.Fresh s of its At: a spark burst and a short flash at the light
	switch, the Bulb.Sound sting and the Announce line ("BULB BURNT OUT" / "Fix it at the breaker outside."). The dark
	itself is the Lights record (trailer_interior off, LightController's SwitchOff look); the way to the fix is the
	breaker's guide arrow (AnomalyController/Breaker.luau shows it whenever the breaker prompt is on); the dead switch
	shows Bulb.DeadText on its prompt. Late joiners get only the state, no burst. All local, one-shot.
	Breaker trip (Q-435, Content.Breaker): when the record turns Out with Trip within Breaker.Fresh s of its At, the
	Breaker.Sound crack and the Announce line ("BREAKER TRIPPED" / "Reset it outside."); the dark and the arrow as above.
]]
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Announce = require(StarterPlayer.StarterPlayerScripts.client.Interface.Announce)
local Power = require(script.Parent.Power)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Record = { Burnt: boolean, Out: boolean, Trip: boolean, At: number }

const BULB = Content.Bulb
const BREAKER = Content.Breaker
const ANCHOR_TAG = "Interactable"
const SWITCH_ACTION = "switch_light"
const SPARK_COLOR = Color3.fromHex("#FFD27A")
const FLASH_COLOR = Color3.fromHex("#FFF1CF")
const LIFETIME = 1.5 -- s before the burst's attachment is removed

const PowerController = Modux.Controller("PowerController", { Require = { "AudioController" }, Priority = 300 })

function PowerController:Setup()
	self.Burnt = false :: boolean
	self.Out = false :: boolean
end

-- The enabled light switch closest to the camera (the trailer for sale keeps its prompt off)
local function switchPosition(): Vector3?
	const camera = Workspace.CurrentCamera
	const from = if camera then camera.CFrame.Position else Vector3.zero
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if anchor:GetAttribute("PromptAction") ~= SWITCH_ACTION or anchor:GetAttribute("PromptEnabled") == false then
			continue
		end
		local at: Vector3? = nil
		if anchor:IsA("Attachment") then
			at = anchor.WorldPosition
		elseif anchor:IsA("BasePart") then
			at = anchor.Position
		end
		if at ~= nil and (at - from).Magnitude < bestDistance then
			best = at
			bestDistance = (at - from).Magnitude
		end
	end
	return best
end

local function burst(at: Vector3)
	const attachment = Instance.new("Attachment")
	attachment.Name = "BulbSparks"
	attachment.WorldPosition = at
	const sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Color = ColorSequence.new(SPARK_COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.12, 0)
	sparks.Lifetime = NumberRange.new(0.25, 0.6)
	sparks.Speed = NumberRange.new(10, 18)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Drag = 2
	sparks.Parent = attachment
	const flash = Instance.new("PointLight")
	flash.Color = FLASH_COLOR
	flash.Range = 10
	flash.Brightness = 4
	flash.Parent = attachment
	attachment.Parent = Workspace.Terrain
	sparks:Emit(BULB.Sparks)
	task.delay(0.12, function()
		flash.Enabled = false
	end)
	Debris:AddItem(attachment, LIFETIME)
end

function PowerController:Burn()
	const at = switchPosition()
	if at ~= nil then
		burst(at)
	end
	self.Dependencies.AudioController:Play(BULB.Sound)
	Announce.Show(BULB.Title, BULB.Line, BULB.Hold)
end

function PowerController:Apply(record: Record, fresh: boolean)
	const was = self.Burnt
	const wasOut = self.Out
	self.Burnt = record.Burnt
	self.Out = record.Out
	Power.Set(record.Out, record.Burnt)
	const age = Workspace:GetServerTimeNow() - record.At
	if record.Burnt and not was and fresh and age <= BULB.Fresh then
		task.defer(function()
			self:Burn()
		end)
	end
	if record.Out and record.Trip and not wasOut and fresh and age <= BREAKER.Fresh then
		task.defer(function()
			self.Dependencies.AudioController:Play(BREAKER.Sound)
			Announce.Show(BREAKER.Title, BREAKER.Line, BREAKER.Hold)
		end)
	end
end

PowerController:OnInit(function(self)
	self:Setup()
	const power = self.Libs.Net.Power
	power:onAdded(function(_id, record)
		self:Apply(record, false)
	end)
	power:onChanged(function(_id, record)
		self:Apply(record, true)
	end)
end)

return PowerController
