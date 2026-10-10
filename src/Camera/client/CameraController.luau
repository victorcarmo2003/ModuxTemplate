--!strict
--[[
	CameraController (TASK-019)

	Locked first person with the stock Roblox camera (DEC-039, DEC-097) on the project's
	own crew rig (DEC-146). The stock TransparencyController hides the whole character in
	first person; this controller runs right after it every frame and owns the local body
	visibility instead:

	  - head group (Head, Face, Cap, ears, hat, accessories and anything welded to the
	    head): always hidden in first person, so a big animal head never covers the view;
	  - arms: hidden by default (DEC-097, Roblox standard). `SetArmsVisible(true)` is the
	    hook for DEC-167 (own sanity band shown on the arms/hands in first person);
	  - rest of the body (Torso, legs, Apron, tail): hidden, as the stock camera does;
	  - Tools are never touched, so the held item stays visible (DEC-097).

	LocalTransparencyModifier is local: teammates always see the full character.
	`Mode` "External" hands the camera to someone else (spectate/cutscene, wave 2) and
	restores every part to visible.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Mode = "FirstPerson" | "External"

type Group = "Head" | "Arm" | "Body"

const RENDER_STEP = "CameraController.BodyVisibility"
-- Right after the stock CameraModule (which updates its TransparencyController at Camera).
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1
-- Camera closer than this to the head counts as first person (stock zoom in LockFirstPerson is 0.5).
const FIRST_PERSON_DISTANCE = 2

-- R6 core parts: the head-group walk never crosses them.
const CORE: { [string]: boolean } = {
	HumanoidRootPart = true,
	Torso = true,
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

const ARMS: { [string]: boolean } = {
	["Left Arm"] = true,
	["Right Arm"] = true,
}

-- Name fallback for head pieces that might not be welded to Head (architecture §18.9.1/§18.9.2).
const HEAD_NAMES: { [string]: boolean } = {
	Head = true,
	Face = true,
	Cap = true,
	Hat = true,
	ThiefHat = true,
}
const HEAD_PREFIXES = { "Head_", "Face_", "Ears", "Cap" }

local function isHeadName(name: string): boolean
	if HEAD_NAMES[name] then
		return true
	end
	for _, prefix in HEAD_PREFIXES do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function inTool(part: Instance): boolean
	return part:FindFirstAncestorOfClass("Tool") ~= nil
end

local function link(adjacency: { [BasePart]: { BasePart } }, a: BasePart?, b: BasePart?)
	if a == nil or b == nil then
		return
	end
	local fromA = adjacency[a]
	if fromA == nil then
		fromA = {}
		adjacency[a] = fromA
	end
	table.insert(fromA, b)
	local fromB = adjacency[b]
	if fromB == nil then
		fromB = {}
		adjacency[b] = fromB
	end
	table.insert(fromB, a)
end

-- Every non-core part reachable from `root` through welds/joints, Tools excluded.
local function attached(root: BasePart, adjacency: { [BasePart]: { BasePart } }, into: { [BasePart]: Group }, group: Group)
	local stack = { root }
	local seen: { [BasePart]: boolean } = { [root] = true }
	while #stack > 0 do
		local part = table.remove(stack) :: BasePart
		into[part] = group
		for _, neighbor in adjacency[part] or {} do
			if not seen[neighbor] and not CORE[neighbor.Name] and not inTool(neighbor) then
				seen[neighbor] = true
				table.insert(stack, neighbor)
			end
		end
	end
end

local function classify(character: Model): { [BasePart]: Group }
	const adjacency: { [BasePart]: { BasePart } } = {}
	const groups: { [BasePart]: Group } = {}
	const parts: { BasePart } = {}

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("JointInstance") then
			link(adjacency, descendant.Part0, descendant.Part1)
		elseif descendant:IsA("WeldConstraint") then
			link(adjacency, descendant.Part0, descendant.Part1)
		elseif descendant:IsA("BasePart") and not inTool(descendant) then
			table.insert(parts, descendant)
		end
	end

	-- Body first, then arms, then head: the most specific group wins.
	for _, part in parts do
		if part.Name ~= "HumanoidRootPart" then
			groups[part] = "Body"
		end
	end

	for _, part in parts do
		if ARMS[part.Name] and part.Parent == character then
			attached(part, adjacency, groups, "Arm")
		end
	end

	const head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		attached(head, adjacency, groups, "Head")
	end

	for _, part in parts do
		if isHeadName(part.Name) or part:FindFirstAncestorOfClass("Accessory") ~= nil then
			groups[part] = "Head"
		end
	end

	return groups
end

const CameraController = Modux.Controller("CameraController", { Priority = 690 })

function CameraController:Setup()
	self.Mode = Vide.source("FirstPerson" :: Mode) :: Vide.Source<Mode>
	-- DEC-097 default (no arms). Hook for DEC-167: show own arms/hands with the sanity band texture.
	self.ArmsVisible = Vide.source(false) :: Vide.Source<boolean>
	self.Character = nil :: Model?
	self.Groups = {} :: { [BasePart]: Group }
	self.Dirty = true
	self.Applied = false
	self.CharacterConnections = {} :: { RBXScriptConnection }
end

function CameraController:SetMode(mode: Mode)
	self.Mode(mode)
	if mode == "FirstPerson" then
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

function CameraController:SetArmsVisible(visible: boolean)
	self.ArmsVisible(visible)
end

function CameraController:IsFirstPerson(): boolean
	if self.Mode() ~= "FirstPerson" then
		return false
	end
	const character = self.Character
	const camera = workspace.CurrentCamera
	if character == nil or camera == nil then
		return false
	end
	const head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return false
	end
	return (camera.CFrame.Position - head.Position).Magnitude <= FIRST_PERSON_DISTANCE
end

function CameraController:Track(character: Model?)
	for _, connection in self.CharacterConnections do
		connection:Disconnect()
	end
	table.clear(self.CharacterConnections)
	table.clear(self.Groups)
	self.Character = character
	self.Applied = false
	self.Dirty = true

	if character == nil then
		return
	end

	local function markDirty(descendant: Instance)
		if
			descendant:IsA("BasePart")
			or descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Accessory")
		then
			self.Dirty = true
		end
	end

	table.insert(self.CharacterConnections, character.DescendantAdded:Connect(markDirty))
	table.insert(self.CharacterConnections, character.DescendantRemoving:Connect(markDirty))
end

function CameraController:Restore()
	for part in self.Groups do
		if part.LocalTransparencyModifier ~= 0 then
			part.LocalTransparencyModifier = 0
		end
	end
	self.Applied = false
end

function CameraController:Update()
	const character = self.Character
	if character == nil then
		return
	end

	if self.Dirty then
		self.Dirty = false
		self.Groups = classify(character)
	end

	if not self:IsFirstPerson() then
		if self.Applied then
			self:Restore()
		end
		return
	end

	const armTransparency = if self.ArmsVisible() then 0 else 1
	for part, group in self.Groups do
		const target = if group == "Arm" then armTransparency else 1
		if part.LocalTransparencyModifier ~= target then
			part.LocalTransparencyModifier = target
		end
	end
	self.Applied = true
end

CameraController:OnInit(function(self)
	self:Setup()
end)

CameraController:OnStart(function(self)
	const player = Players.LocalPlayer
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	player.CharacterAdded:Connect(function(character)
		self:Track(character)
	end)
	player.CharacterRemoving:Connect(function(character)
		if self.Character == character then
			self:Track(nil)
		end
	end)
	if player.Character then
		self:Track(player.Character)
	end

	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function()
		self:Update()
	end)
end)

return CameraController
