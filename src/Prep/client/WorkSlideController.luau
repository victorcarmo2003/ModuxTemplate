--!strict
--[[
	WorkSlideController (TASK-354; owner request 2026-10-17, Provisional; Content.Prep.WorkSlide)

	The grill Work prompt (Prompt_Work with PromptStep Grill) follows the local character along the counter: every frame
	the Attachment is moved, on this client only, to shared/Prep/WorkSlide.Position (the player's projection on the
	counter, clamped to [0, Fraction] from the grill end). PromptController reads the anchor's WorldPosition live, so the
	pill slides with it. The server measures the range from the same point (InteractionService Reach of prep_work,
	PrepService:WorkDistance), so pressing it far from the grill is accepted. The authored position is kept (local
	Position at first sight) and put back when the character is gone or the anchor leaves.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local WorkSlide = require(ReplicatedStorage.shared.Prep.WorkSlide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const TAG = "Interactable"

const WorkSlideController = Modux.Controller("WorkSlideController", {
	Require = {},
	Priority = 400,
})

function WorkSlideController:Setup()
	-- sliding anchor -> its authored Position (local to the parent)
	self.Anchors = {} :: { [Attachment]: Vector3 }
end

function WorkSlideController:Track(instance: Instance)
	if instance:IsA("Attachment") and WorkSlide.Applies(instance) and self.Anchors[instance] == nil then
		self.Anchors[instance] = instance.Position
	end
end

function WorkSlideController:Untrack(instance: Instance)
	const authored = if instance:IsA("Attachment") then self.Anchors[instance] else nil
	if authored ~= nil and instance:IsA("Attachment") then
		instance.Position = authored
		self.Anchors[instance] = nil
	end
end

function WorkSlideController:Step()
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	for anchor, authored in self.Anchors do
		const parent = anchor.Parent
		if parent == nil or not parent:IsA("BasePart") then
			continue
		end
		if root == nil or not root:IsA("BasePart") then
			anchor.Position = authored
			continue
		end
		const home = parent.CFrame:PointToWorldSpace(authored)
		anchor.WorldPosition = WorkSlide.Position(anchor, home, root.Position)
	end
end

WorkSlideController:OnInit(function(self)
	self:Setup()
end)

WorkSlideController:OnStart(function(self)
	for _, instance in CollectionService:GetTagged(TAG) do
		self:Track(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
		self:Track(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		self:Untrack(instance)
	end)
	RunService.PreRender:Connect(function()
		self:Step()
	end)
end)

return WorkSlideController
