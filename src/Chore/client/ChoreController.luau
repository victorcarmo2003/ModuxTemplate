--!strict
--[[
	ChoreController (owner request 2026-10-21, Provisional Q-436; Content.Chores; network.md §13.2b)

	Reader of the Chores set (ChoreService). Presentation only, all local:

	  start     a record turning On within Rules.Fresh s of its At: the chore's Sound and its Announce line (Title / Line).
	  grill     while grill_fire is On: flames, smoke and a flickering orange light at the `Chore_Fire` anchor, Loop sound
	            there; when it ends, the Done sound (the extinguisher) and a puff of smoke.
	  rats      one small grey rat (local parts, no asset) at each `Chore_Rat<i>` anchor, twitching and sniffing; when its
	            anchor goes (shooed) it squeaks and darts off the counter.
	  camera    the dead picture is SecurityController's (Dead); here only the Done sound at the camera when fixed.
	  prompts   gate "Chore": the grill's own prompts hide while it burns, a station's while a rat sits on it (the server
	            gate refuses them anyway).
]]
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Announce = require(StarterPlayer.StarterPlayerScripts.client.Interface.Announce)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Record = { On: boolean, Mask: number, At: number }

const CHORES = Content.Chores
const RULES = CHORES.Rules
const ANCHOR_TAG = "Interactable"
const FIRE_ANCHOR = "Chore_Fire"
const RAT_PREFIX = "Chore_Rat"
const CAMERA_ANCHOR = "Chore_Camera"
const FIND_WAIT = 3 -- s the anchors may arrive after the record
const FIRE_COLOR = Color3.fromRGB(255, 140, 40)
const RAT_COLOR = Color3.fromRGB(88, 84, 82)
const RAT_PINK = Color3.fromRGB(214, 150, 150)
const RAT_RUN = 4 -- studs it darts off
const RAT_RUN_TIME = 0.45

type Rat = { Model: Model, Base: CFrame, Seed: number }

const ChoreController = Modux.Controller("ChoreController", {
	Require = { "AudioController", "PromptController" },
	Priority = 300,
})

function ChoreController:Setup()
	self.Records = {} :: { [string]: Record }
	self.Fire = nil :: Attachment?
	self.FirePos = nil :: Vector3?
	self.CameraPos = nil :: Vector3?
	self.Rats = {} :: { [Instance]: Rat }
	self.Connection = nil :: RBXScriptConnection?
	self.Models = {} :: { [string]: Instance }
end

local function anchorsNamed(prefix: string): { Attachment }
	const out: { Attachment } = {}
	for _, anchor in CollectionService:GetTagged(ANCHOR_TAG) do
		if anchor:IsA("Attachment") and anchor.Name:sub(1, #prefix) == prefix and anchor:GetAttribute("Chore") == true then
			table.insert(out, anchor)
		end
	end
	return out
end

function ChoreController:ModelOf(mapId: string): Instance?
	const cached = self.Models[mapId]
	if cached ~= nil and cached:IsDescendantOf(Workspace) then
		return cached
	end
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MapId") == mapId then
			self.Models[mapId] = d
			return d
		end
	end
	return nil
end

-- Fire ------------------------------------------------------------------------------------------------------------------

function ChoreController:Ignite(anchor: Attachment)
	if self.Fire == anchor then
		return
	end
	self:Douse(false)
	self.Fire = anchor
	self.FirePos = anchor.WorldPosition
	const fire = Instance.new("Fire")
	fire.Name = "ChoreFlames"
	fire.Size = 6
	fire.Heat = 12
	fire.Color = FIRE_COLOR
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = anchor
	const smoke = Instance.new("Smoke")
	smoke.Name = "ChoreSmoke"
	smoke.Color = Color3.fromRGB(60, 58, 56)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = anchor
	const light = Instance.new("PointLight")
	light.Name = "ChoreGlow"
	light.Color = FIRE_COLOR
	light.Range = 14
	light.Brightness = 3
	light.Shadows = false
	light.Parent = anchor
	const row = CHORES.ByKey.grill_fire
	if row.Loop ~= "" then
		self.Dependencies.AudioController:Loop(row.Loop, anchor, true)
	end
end

function ChoreController:Douse(done: boolean)
	const anchor = self.Fire
	self.Fire = nil
	const row = CHORES.ByKey.grill_fire
	if anchor ~= nil then
		if row.Loop ~= "" then
			self.Dependencies.AudioController:Loop(row.Loop, anchor, false)
		end
		for _, name in { "ChoreFlames", "ChoreSmoke", "ChoreGlow" } do
			const child = anchor:FindFirstChild(name)
			if child ~= nil then
				child:Destroy()
			end
		end
	end
	const at = self.FirePos
	self.FirePos = nil
	if not done or at == nil then
		return
	end
	if row.Done ~= "" then
		self.Dependencies.AudioController:Play(row.Done, at)
	end
	-- a white puff where the flames were
	const puff = Instance.new("Attachment")
	puff.WorldPosition = at
	const smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(235, 235, 235)
	smoke.Opacity = 0.5
	smoke.RiseVelocity = 6
	smoke.Size = 4
	smoke.Parent = puff
	puff.Parent = Workspace.Terrain
	task.delay(1.2, function()
		smoke.Enabled = false
	end)
	Debris:AddItem(puff, 5)
end

-- Rats ------------------------------------------------------------------------------------------------------------------

-- An ellipsoid of `size`: a block with a Sphere SpecialMesh (a Ball part forces all three sizes equal, which shrank the
-- oval body to a small sphere and left the head and the tail floating apart; owner 2026-10-21)
local function ball(model: Model, name: string, size: Vector3, color: Color3): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	const mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- A low-poly rat from parts, its origin on the ground under its belly, nose toward -Z
local function buildRat(): Model
	const model = Instance.new("Model")
	model.Name = "ChoreRat"
	const body = ball(model, "Body", Vector3.new(0.7, 0.5, 1.1), RAT_COLOR)
	const head = ball(model, "Head", Vector3.new(0.42, 0.38, 0.5), RAT_COLOR)
	const nose = ball(model, "Nose", Vector3.new(0.1, 0.1, 0.1), RAT_PINK)
	const earL = ball(model, "EarL", Vector3.new(0.22, 0.22, 0.06), RAT_PINK)
	const earR = ball(model, "EarR", Vector3.new(0.22, 0.22, 0.06), RAT_PINK)
	const eyeL = ball(model, "EyeL", Vector3.new(0.07, 0.07, 0.07), Color3.new(0, 0, 0))
	const eyeR = ball(model, "EyeR", Vector3.new(0.07, 0.07, 0.07), Color3.new(0, 0, 0))
	const tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.06, 0.06, 1.1)
	tail.Color = RAT_PINK
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.CastShadow = false
	tail.Parent = model
	-- offsets from the origin, kept on the parts so the idle can rebuild the pose
	body:SetAttribute("Offset", CFrame.new(0, 0.25, 0))
	head:SetAttribute("Offset", CFrame.new(0, 0.3, -0.65))
	nose:SetAttribute("Offset", CFrame.new(0, 0.28, -0.92))
	earL:SetAttribute("Offset", CFrame.new(-0.15, 0.52, -0.55))
	earR:SetAttribute("Offset", CFrame.new(0.15, 0.52, -0.55))
	eyeL:SetAttribute("Offset", CFrame.new(-0.12, 0.38, -0.85))
	eyeR:SetAttribute("Offset", CFrame.new(0.12, 0.38, -0.85))
	tail:SetAttribute("Offset", CFrame.new(0, 0.12, 1.05) * CFrame.Angles(math.rad(-8), 0, 0))
	return model
end

local function pose(rat: Rat, base: CFrame, t: number)
	-- sniffing: the head bobs and turns a little, the body breathes, every now and then a twitch
	const sniff = math.sin(t * 14 + rat.Seed) * 0.03
	const turn = math.sin(t * 1.7 + rat.Seed) * math.rad(20)
	const twitch = if math.sin(t * 3.1 + rat.Seed * 2) > 0.97 then 0.08 else 0
	const root = base * CFrame.Angles(0, turn * 0.3, 0) * CFrame.new(0, twitch, 0)
	for _, part in rat.Model:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		const offset = part:GetAttribute("Offset")
		if typeof(offset) ~= "CFrame" then
			continue
		end
		local cf = root * offset
		if part.Name ~= "Body" and part.Name ~= "Tail" then
			cf = root * CFrame.new(0, sniff, 0) * CFrame.Angles(0, turn * 0.7, 0) * offset
		elseif part.Name == "Tail" then
			cf = root * CFrame.Angles(0, math.sin(t * 4 + rat.Seed) * math.rad(15), 0) * offset
		end
		part.CFrame = cf
	end
end

function ChoreController:AddRat(anchor: Attachment)
	if self.Rats[anchor] ~= nil then
		return
	end
	const model = buildRat()
	const yaw = math.random() * math.pi * 2
	const base = CFrame.new(anchor.WorldPosition - Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, yaw, 0)
	const rat: Rat = { Model = model, Base = base, Seed = math.random() * 100 }
	pose(rat, base, os.clock())
	model.Parent = Workspace
	self.Rats[anchor] = rat
end

function ChoreController:RemoveRat(anchor: Instance, run: boolean)
	const rat = self.Rats[anchor]
	if rat == nil then
		return
	end
	self.Rats[anchor] = nil
	if not run then
		rat.Model:Destroy()
		return
	end
	const row = CHORES.ByKey.rats
	if row.Done ~= "" then
		self.Dependencies.AudioController:Play(row.Done, rat.Base.Position)
	end
	-- darts off, nose first, and drops out of sight
	const target = rat.Base * CFrame.new(0, -0.6, -RAT_RUN)
	const info = TweenInfo.new(RAT_RUN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in rat.Model:GetChildren() do
		if part:IsA("BasePart") then
			const offset = part:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				TweenService:Create(part, info, { CFrame = target * offset, Transparency = 1 }):Play()
			end
		end
	end
	Debris:AddItem(rat.Model, RAT_RUN_TIME + 0.1)
end

function ChoreController:SyncRats(on: boolean)
	const live: { [Instance]: boolean } = {}
	if on then
		for _, anchor in anchorsNamed(RAT_PREFIX) do
			live[anchor] = true
			self:AddRat(anchor)
		end
	end
	for anchor in self.Rats do
		if not live[anchor] then
			self:RemoveRat(anchor, on or anchor.Parent == nil)
		end
	end
end

-- Records ---------------------------------------------------------------------------------------------------------------

-- The anchors replicate on their own: look again for a few seconds after the record
function ChoreController:Present(key: string, record: Record)
	if key == "grill_fire" then
		if not record.On then
			self:Douse(true)
			return
		end
		const started = os.clock()
		task.spawn(function()
			while os.clock() - started < FIND_WAIT and self.Records.grill_fire == record do
				const anchor = anchorsNamed(FIRE_ANCHOR)[1]
				if anchor ~= nil then
					self:Ignite(anchor)
					return
				end
				task.wait(0.2)
			end
		end)
	elseif key == "rats" then
		self:SyncRats(record.On)
	elseif key == "camera_static" then
		if record.On then
			const anchor = anchorsNamed(CAMERA_ANCHOR)[1]
			self.CameraPos = if anchor ~= nil then anchor.WorldPosition else nil
			return
		end
		const row = CHORES.ByKey.camera_static
		if self.CameraPos ~= nil and row.Done ~= "" then
			self.Dependencies.AudioController:Play(row.Done, self.CameraPos)
		end
		self.CameraPos = nil
	end
end

function ChoreController:Apply(id: number, record: Record, fresh: boolean)
	const row = CHORES.List[id]
	if row == nil then
		return
	end
	const was = self.Records[row.Key]
	self.Records[row.Key] = record
	const turnedOn = record.On and (was == nil or not was.On)
	if turnedOn and fresh and Workspace:GetServerTimeNow() - record.At <= RULES.Fresh then
		if row.Sound ~= "" then
			self.Dependencies.AudioController:Play(row.Sound)
		end
		if row.Title ~= "" then
			Announce.Show(row.Title, row.Line, RULES.Hold)
		end
	end
	if record.On or (was ~= nil and was.On) then
		self:Present(row.Key, record)
	end
end

-- Gate: prompts of a burning grill / a station with a rat stay hidden (the server refuses them too)
function ChoreController:Hidden(anchor: Instance): boolean
	if anchor:GetAttribute("Chore") == true then
		return false
	end
	const fire = self.Records.grill_fire
	if fire ~= nil and fire.On then
		const grill = self:ModelOf(RULES.Grill)
		if grill ~= nil and anchor:IsDescendantOf(grill) then
			return true
		end
	end
	const rats = self.Records.rats
	if rats ~= nil and rats.On and rats.Mask ~= 0 then
		for index, mapId in RULES.Spots do
			if bit32.band(rats.Mask, bit32.lshift(1, index - 1)) ~= 0 then
				const model = self:ModelOf(mapId)
				if model ~= nil and anchor:IsDescendantOf(model) then
					return true
				end
			end
		end
	end
	return false
end

ChoreController:OnInit(function(self)
	self:Setup()
	const set = self.Libs.Net.Chores
	set:onAdded(function(id, record)
		self:Apply(id, record, false)
	end)
	set:onChanged(function(id, record)
		self:Apply(id, record, true)
	end)
end)

ChoreController:OnStart(function(self)
	self.Dependencies.PromptController:AddGate("Chore", function(anchor: Instance): boolean
		return not self:Hidden(anchor)
	end)
	self.Connection = RunService.RenderStepped:Connect(function()
		if next(self.Rats) == nil then
			const fire = self.Fire
			if fire == nil then
				return
			end
		end
		const t = os.clock()
		for _, rat in self.Rats do
			pose(rat, rat.Base, t)
		end
		const glow = if self.Fire ~= nil then self.Fire:FindFirstChild("ChoreGlow") else nil
		if glow ~= nil and glow:IsA("PointLight") then
			glow.Brightness = 2.4 + math.sin(t * 17) * 0.5 + math.sin(t * 7.3) * 0.4
		end
	end)
	-- anchors that replicate after their record
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(function(anchor)
		if not anchor:IsA("Attachment") or anchor:GetAttribute("Chore") ~= true then
			return
		end
		const rats = self.Records.rats
		if anchor.Name:sub(1, #RAT_PREFIX) == RAT_PREFIX and rats ~= nil and rats.On then
			self:AddRat(anchor)
		elseif anchor.Name == CAMERA_ANCHOR then
			self.CameraPos = anchor.WorldPosition
		end
	end)
	-- a rat shooed by someone else: its anchor leaves before the record changes
	CollectionService:GetInstanceRemovedSignal(ANCHOR_TAG):Connect(function(anchor)
		if self.Rats[anchor] ~= nil then
			self:RemoveRat(anchor, true)
		end
	end)
end)

return ChoreController
