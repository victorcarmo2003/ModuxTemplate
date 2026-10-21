--!strict
--[[
	NeonController (user request 2026-10-11; tools/assetplace/decor_mart.luau; Content.Neon)

	Neon tube signs: Models tagged NeonSign (attribute Color = lit colour, optional Flicker = true), made of Neon parts
	("Tube" cylinders, "Joint" balls). Purely visual and local: no packet, no set, no game rule.

	  * Discovery: the tag (GetTagged + GetInstanceAddedSignal, so signs streamed in later are picked up) and the
	    Model's DescendantAdded (tube parts that stream in after the Model). Each part keeps its lit colour.
	  * Every sign stays lit, day and night (Content.Neon.FlickerByDay = false keeps Flicker signs steady by day).
	  * Flicker signs: every Interval s (random per sign) a burst of Blinks short outages (BlinkOff / BlinkOn s), and
	    with LongOffChance a final outage of LongOff s. Out = OffMaterial with the colour darkened by OffDarken.
	    At the start of a burst `neon_click` plays on a tube part, quiet, only within SoundRange studs of the camera;
	    it stops when the burst ends.
	  * Hands off: an OverrideAttribute (NeonOverride) on the Model or the part skips it (a running burst puts the
	    sign back and ends). A part is switched off only while it still shows Neon, and put back only while it still
	    shows exactly the off look this controller wrote: another system (LightController, an anomaly) that rewrote
	    Material/Color meanwhile keeps its look.
	  * One OnTick for every sign; a sign only costs work at its next scheduled step.
	  * Dim (owner 2026-10-20, Realistic lighting style blew the neon out): every lit colour is scaled by Dim.Scale
	    (sign tubes and the loose Neon parts under the Dim.Roots models of Workspace: stage edges, gems, lenses).
	    A dimmed part carries the DimAttribute, so a re-tag or a second pass never scales it twice.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const RULES = Content.Neon
const DIM = RULES.Dim
const TICK_RATE = 60 -- Hz: blinks are 40 ms long
const BLACK = Color3.new(0, 0, 0)

type Tube = {
	Part: BasePart,
	Lit: Color3,
	Off: Color3?, -- the colour read back after this controller switched the part off; nil = not switched off
}

type Sign = {
	Model: Instance,
	Tubes: { Tube },
	Known: { [BasePart]: true },
	Flicker: boolean,
	NextAt: number, -- os.clock() of the next step (burst start or next blink edge)
	Steps: { number }, -- durations of the running burst, alternating out / lit, starting with out
	Step: number, -- index into Steps; 0 = idle
	Sound: Sound?,
	Connections: { RBXScriptConnection },
}

const NeonController =
	Modux.Controller("NeonController", { Require = { "RoundController", "AudioController" }, Priority = 300 })

function NeonController:Setup()
	self.Signs = {} :: { [Instance]: Sign }
	self.Rng = Random.new() :: Random
end

local function between(rng: Random, range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function overridden(instance: Instance): boolean
	return instance:GetAttribute(RULES.OverrideAttribute) == true
end

local function isTubeName(name: string): boolean
	return table.find(RULES.PartNames, name) ~= nil
end

local function scaled(color: Color3): Color3
	return Color3.new(color.R * DIM.Scale, color.G * DIM.Scale, color.B * DIM.Scale)
end

-- Lit Neon part: scales its colour once (DimAttribute) and returns the dimmed lit colour.
local function dim(part: BasePart): Color3
	if part:GetAttribute(DIM.Attribute) ~= true then
		part.Color = scaled(part.Color)
		part:SetAttribute(DIM.Attribute, true)
	end
	return part.Color
end

local function inSign(part: Instance): boolean
	local node = part.Parent
	while node and node ~= Workspace do
		if CollectionService:HasTag(node, RULES.Tag) then
			return true
		end
		node = node.Parent
	end
	return false
end

-- Loose Neon part under a Dim root (not a sign tube: Track dims those).
local function dimLoose(instance: Instance)
	if
		instance:IsA("BasePart")
		and instance.Material == Enum.Material.Neon
		and not overridden(instance)
		and not inSign(instance)
	then
		dim(instance)
	end
end

local function watchRoot(root: Instance)
	for _, descendant in root:GetDescendants() do
		dimLoose(descendant)
	end
	root.DescendantAdded:Connect(dimLoose)
end

-- Track one part of a sign (Neon parts, or the named tube parts found already off: lit colour from the Model).
function NeonController:Track(sign: Sign, part: Instance)
	if not part:IsA("BasePart") or sign.Known[part] then
		return
	end
	local lit: Color3
	if part.Material == Enum.Material.Neon then
		lit = dim(part)
	elseif isTubeName(part.Name) then
		const attribute = sign.Model:GetAttribute(RULES.ColorAttribute)
		if typeof(attribute) ~= "Color3" then
			return
		end
		lit = scaled(attribute)
	else
		return
	end
	sign.Known[part] = true
	table.insert(sign.Tubes, { Part = part, Lit = lit, Off = nil })
end

function NeonController:Add(model: Instance)
	if self.Signs[model] ~= nil then
		return
	end
	const sign: Sign = {
		Model = model,
		Tubes = {},
		Known = {},
		Flicker = model:GetAttribute(RULES.FlickerAttribute) == true,
		NextAt = os.clock() + between(self.Rng, RULES.Interval),
		Steps = {},
		Step = 0,
		Sound = nil,
		Connections = {},
	}
	for _, descendant in model:GetDescendants() do
		self:Track(sign, descendant)
	end
	table.insert(
		sign.Connections,
		model.DescendantAdded:Connect(function(descendant)
			self:Track(sign, descendant)
		end)
	)
	table.insert(
		sign.Connections,
		model:GetAttributeChangedSignal(RULES.FlickerAttribute):Connect(function()
			sign.Flicker = model:GetAttribute(RULES.FlickerAttribute) == true
		end)
	)
	self.Signs[model] = sign
end

function NeonController:Remove(model: Instance)
	const sign = self.Signs[model]
	if sign == nil then
		return
	end
	self.Signs[model] = nil
	self:EndBurst(sign, os.clock())
	for _, connection in sign.Connections do
		connection:Disconnect()
	end
end

-- Out: only parts still showing Neon (someone else's look is left alone).
function NeonController:SwitchOff(sign: Sign)
	for _, tube in sign.Tubes do
		const part = tube.Part
		if tube.Off ~= nil or part.Parent == nil or overridden(part) or part.Material ~= Enum.Material.Neon then
			continue
		end
		part.Material = RULES.OffMaterial
		part.Color = tube.Lit:Lerp(BLACK, RULES.OffDarken)
		tube.Off = part.Color -- read back: BasePart.Color is stored quantised
	end
end

-- Lit: only parts still showing exactly the off look written by SwitchOff.
function NeonController:SwitchOn(sign: Sign)
	for _, tube in sign.Tubes do
		const off = tube.Off
		if off == nil then
			continue
		end
		tube.Off = nil
		const part = tube.Part
		if part.Parent == nil or part.Material ~= RULES.OffMaterial or part.Color ~= off then
			continue
		end
		part.Material = Enum.Material.Neon
		part.Color = tube.Lit
	end
end

function NeonController:EndBurst(sign: Sign, now: number)
	self:SwitchOn(sign)
	sign.Step = 0
	table.clear(sign.Steps)
	sign.NextAt = now + between(self.Rng, RULES.Interval)
	const sound = sign.Sound
	sign.Sound = nil
	if sound and sound.Name == RULES.Sound and sound.IsPlaying then
		sound:Stop()
	end
end

local function listenerPosition(): Vector3?
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	const camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

function NeonController:StartBurst(sign: Sign, now: number)
	const steps = sign.Steps
	table.clear(steps)
	const blinks = self.Rng:NextInteger(RULES.Blinks[1], RULES.Blinks[2])
	for index = 1, blinks do
		table.insert(steps, between(self.Rng, RULES.BlinkOff))
		if index < blinks then
			table.insert(steps, between(self.Rng, RULES.BlinkOn))
		end
	end
	if self.Rng:NextNumber() < RULES.LongOffChance then
		table.insert(steps, between(self.Rng, RULES.BlinkOn))
		table.insert(steps, RULES.LongOff)
	end
	sign.Step = 1
	sign.NextAt = now + steps[1]
	self:SwitchOff(sign)

	-- the click, on the middle tube, only near the listener
	const tube = sign.Tubes[math.max(1, (#sign.Tubes + 1) // 2)]
	const listener = listenerPosition()
	if tube and listener and (tube.Part.Position - listener).Magnitude <= RULES.SoundRange then
		sign.Sound = self.Dependencies.AudioController:Play(RULES.Sound, tube.Part, { Volume = RULES.SoundVolume })
	end
end

function NeonController:Tick()
	const now = os.clock()
	const night = self.Dependencies.RoundController.IsNight()
	for _, sign in self.Signs do
		if now < sign.NextAt then
			continue
		end
		if sign.Step > 0 then
			if overridden(sign.Model) or not sign.Model:IsDescendantOf(Workspace) then
				self:EndBurst(sign, now)
				continue
			end
			sign.Step += 1
			const duration = sign.Steps[sign.Step]
			if duration == nil then
				self:EndBurst(sign, now)
				continue
			end
			if sign.Step % 2 == 1 then
				self:SwitchOff(sign)
			else
				self:SwitchOn(sign)
			end
			sign.NextAt = now + duration
		elseif
			sign.Flicker
			and #sign.Tubes > 0
			and (night or RULES.FlickerByDay)
			and not overridden(sign.Model)
			and sign.Model:IsDescendantOf(Workspace)
		then
			self:StartBurst(sign, now)
		else
			sign.NextAt = now + between(self.Rng, RULES.Interval)
		end
	end
end

NeonController:OnInit(function(self)
	self:Setup()
end)

NeonController:OnStart(function(self)
	if DIM.Scale < 1 then
		for _, name in DIM.Roots do
			const root = Workspace:FindFirstChild(name)
			if root then
				watchRoot(root)
			end
		end
		Workspace.ChildAdded:Connect(function(child)
			if table.find(DIM.Roots, child.Name) then
				watchRoot(child)
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal(RULES.Tag):Connect(function(instance)
		self:Add(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(RULES.Tag):Connect(function(instance)
		self:Remove(instance)
	end)
	for _, instance in CollectionService:GetTagged(RULES.Tag) do
		self:Add(instance)
	end
end)

NeonController:OnTick(function(self)
	self:Tick()
end, TICK_RATE)

return NeonController
