--!strict
--[[
	DeliveryController (owner request 2026-10-14, Provisional; open-questions.md "pedidos do dono 2026-10-14")

	Delivery by drag-and-drop in the world: the customer waits at the trailer service window, the player HOLDS the finished
	hot dog (the hot_dog Tool in hand, ItemService) and DRAGS it onto the customer, dropping it there.
	  * While a hot dog is in hand and a customer's `serve` prompt is enabled within Content.Actions.serve.Radius, a
	    DeliverMark (Green striped "DELIVER" card, Interface/Components/DeliverMark) floats over that customer: the drop zone.
	    Only then: no hot dog, nobody waiting or out of range = no mark.
	  * Mouse / touch: press anywhere in the world (not on a GUI) with the hot dog in hand, drag, release over the customer
	    (a ray from the pointer hits its rig, or the pointer is within DROP_PX of the mark on screen): the customer's own
	    `serve` prompt is fired (PromptController:FireAnchor), the same Interact packet as pressing it. While dragging over a
	    customer the mark lights up (SetHot). In first person the pointer is the screen centre (aim and release).
	  * Gamepad and the prompt itself stay as the fallback (the `serve` pill on the customer is untouched).
	Server-authoritative: CustomerService validates the order, the range, the phase and picks the exact hot dog
	(PickServeTool); nothing here judges. Seated in the focused prep mode (character attribute Working) the world drag is off:
	the prep Toppings view has its own drop on the customer (PrepController World/Stages/Build).
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local DeliverMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.DeliverMark)

const HOT_DOG = "hot_dog"
const SERVE = "serve"
const RIG_TAG = "AnimalRig"
const WORKING = "Working" -- character attribute while seated in the prep mode (PrepService)
const TICK_RATE = 30
const SLACK = 1 -- studs under the server radius (the server adds its own slack on top)
const MARK_LIFT = 2.4 -- studs over the serve anchor (the neck): above the head
const DROP_PX = 90 -- px from the mark on screen that still count as a drop on the customer
const RAY_LENGTH = 120

const RADIUS = (Content.Actions.ByKey[SERVE] :: Content.Action).Radius

const DeliveryController = Modux.Controller("DeliveryController", {
	Require = { "PromptController", "InputController" },
	Priority = 500,
})

type Candidate = { Anchor: Attachment, Rig: Model, Distance: number }

function DeliveryController:Setup()
	self.Mark = nil :: DeliverMark.Mark?
	self.Dragging = false :: boolean
	-- customer under the pointer while dragging (its serve anchor), nil = none
	self.Over = nil :: Attachment?
	self.Current = nil :: Candidate?
	-- touch position while a finger drags (nil = mouse)
	self.TouchAt = nil :: Vector2?
end

-- The hot dog Tool in the own hand (nil = none, or seated in the prep mode)
function DeliveryController:HeldHotDog(): Tool?
	const character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute(WORKING) ~= nil then
		return nil
	end
	const tool = character:FindFirstChildOfClass("Tool")
	if tool ~= nil and tool:GetAttribute("Item") == HOT_DOG then
		return tool
	end
	return nil
end

-- The enabled `serve` anchor of a customer rig (Attachment with PromptAction serve, PromptEnabled not false)
local function serveAnchor(rig: Instance): Attachment?
	for _, descendant in rig:GetDescendants() do
		if
			descendant:IsA("Attachment")
			and descendant:GetAttribute("PromptAction") == SERVE
			and descendant:GetAttribute("PromptEnabled") ~= false
		then
			return descendant
		end
	end
	return nil
end

-- Customers that can take a hot dog now, nearest first
function DeliveryController:Candidates(): { Candidate }
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	const out: { Candidate } = {}
	if root == nil or not root:IsA("BasePart") then
		return out
	end
	for _, rig in CollectionService:GetTagged(RIG_TAG) do
		if not rig:IsA("Model") or not rig:IsDescendantOf(workspace) or rig:GetAttribute("NpcId") == nil then
			continue
		end
		const anchor = serveAnchor(rig)
		if anchor == nil then
			continue
		end
		const distance = (anchor.WorldPosition - root.Position).Magnitude
		if distance <= RADIUS - SLACK then
			table.insert(out, { Anchor = anchor, Rig = rig, Distance = distance })
		end
	end
	table.sort(out, function(a: Candidate, b: Candidate): boolean
		return a.Distance < b.Distance
	end)
	return out
end

-- Pointer position on screen (mouse, or the screen centre when the mouse is locked in first person)
local function pointer(touch: Vector2?): Vector2
	if touch ~= nil then
		return touch
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		const camera = workspace.CurrentCamera
		return if camera then camera.ViewportSize / 2 else Vector2.zero
	end
	return UserInputService:GetMouseLocation()
end

-- The candidate under the pointer: a ray that hits its rig, else the one whose mark is within DROP_PX on screen
function DeliveryController:Under(candidates: { Candidate }, at: Vector2): Candidate?
	const camera = workspace.CurrentCamera
	if camera == nil or #candidates == 0 then
		return nil
	end
	const ray = camera:ViewportPointToRay(at.X, at.Y)
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	const rigs: { Instance } = {}
	for _, candidate in candidates do
		table.insert(rigs, candidate.Rig)
	end
	params.FilterDescendantsInstances = rigs
	const hit = workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if hit ~= nil then
		for _, candidate in candidates do
			if hit.Instance:IsDescendantOf(candidate.Rig) then
				return candidate
			end
		end
	end
	local best: Candidate? = nil
	local bestPx = DROP_PX
	for _, candidate in candidates do
		const point, visible = camera:WorldToViewportPoint(candidate.Anchor.WorldPosition + Vector3.new(0, MARK_LIFT * 0.5, 0))
		if visible then
			const px = (Vector2.new(point.X, point.Y) - at).Magnitude
			if px < bestPx then
				best, bestPx = candidate, px
			end
		end
	end
	return best
end

function DeliveryController:Step()
	const mark = self.Mark
	if mark == nil then
		return
	end
	if self:HeldHotDog() == nil then
		self.Dragging = false
		self.Current = nil
		mark:Hide()
		return
	end
	const candidates = self:Candidates()
	local shown: Candidate? = candidates[1]
	if self.Dragging then
		const over = self:Under(candidates, pointer(self.TouchAt))
		self.Over = if over then over.Anchor else nil
		shown = over or shown
		mark:SetHot(over ~= nil)
	else
		self.Over = nil
		mark:SetHot(false)
	end
	self.Current = shown
	if shown == nil then
		mark:Hide()
		return
	end
	mark:Show(shown.Anchor.WorldPosition + Vector3.new(0, MARK_LIFT, 0))
end

-- Release: over a customer = deliver through its own serve prompt
function DeliveryController:Drop(at: Vector2)
	if not self.Dragging then
		return
	end
	self.Dragging = false
	self.TouchAt = nil
	if self:HeldHotDog() == nil then
		return
	end
	const target = self:Under(self:Candidates(), at)
	if target == nil then
		return
	end
	if self.Dependencies.PromptController:FireAnchor(target.Anchor) and self.Mark ~= nil then
		self.Mark:Kick(8)
	end
end

function DeliveryController:BindInput()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		const kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if self:HeldHotDog() == nil then
			return
		end
		self.Dragging = true
		self.TouchAt = if kind == Enum.UserInputType.Touch then Vector2.new(input.Position.X, input.Position.Y) else nil
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if self.Dragging and input.UserInputType == Enum.UserInputType.Touch then
			self.TouchAt = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		const kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 then
			self:Drop(pointer(nil))
		elseif kind == Enum.UserInputType.Touch then
			self:Drop(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
end

DeliveryController:OnInit(function(self)
	self:Setup()
end)

DeliveryController:OnStart(function(self)
	self.Mark = DeliverMark.new()
	self:BindInput()
end)

DeliveryController:OnTick(function(self)
	self:Step()
end, TICK_RATE)

return DeliveryController
