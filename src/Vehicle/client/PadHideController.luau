--!strict
--[[
	PadHideController (user request 2026-10-12, Provisional, Q-216; MAP-01 §5.3; upgrades.md "Food Trailer")

	When the TRAILER is the vehicle in use (Shift.Vehicle ~= Content.RunParams.StartVehicle) the hot dog stand of the
	Pad disappears completely: the cart (and its tarp), the Pad decoration (back wall neon, menu board, string lights,
	crates, plants, picnic tables of the Pad) and the blockout CART model. What stays is an empty floor (the PadFloor
	slab). Back to the cart (/dev trailer swap, ResetDev) everything is restored.

	Server-authoritative state: Shift.Vehicle (VehicleService is its only writer); this controller only presents it.
	Per instance of the hidden roots (late streamed ones too):
	  * BasePart: LocalTransparencyModifier = 1, CanCollide / CanQuery / CanTouch = false (the picnic tables keep their
	    collision to SeatingService, which already locks them: it writes it for everyone)
	  * Decal / Texture: Transparency = 1; Light, ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles, Highlight,
	    ProximityPrompt, BillboardGui, SurfaceGui: Enabled = false (lights get the local attribute PadHidden, which
	    LightController respects)
	  * Interactable anchors: the tag is removed locally (PromptController drops the prompt) and put back on restore
	Kept on purpose: the OPEN sign stand (Prompt_Open is the only way to open the shop and the trailer has none) and the
	queue marks Q1..Q5 (the queue is shared by both vehicles).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const START_VEHICLE = Content.RunParams.StartVehicle
const TICK_RATE = 4
const ANCHOR_TAG = "Interactable"
const TABLE_TAG = "SeatTable"
const HIDDEN_ATTRIBUTE = "PadHidden"

-- Roots hidden while the trailer is the vehicle, as paths under Workspace
const ROOTS: { { string } } = {
	{ "MAP01_Assets", "Cart" },
	{ "MAP01_Assets", "PadDecor" },
	{ "MAP01_Blockout", "Pad", "CART" },
}

const ENABLED_CLASSES = {
	"Light",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"Fire",
	"Smoke",
	"Sparkles",
	"Highlight",
	"ProximityPrompt",
	"BillboardGui",
	"SurfaceGui",
}

type Saved = { [string]: any }

const PadHideController = Modux.Controller("PadHideController", { Require = { "RoundController" }, Priority = 300 })

function PadHideController:Setup()
	self.Hidden = false
	self.Saved = {} :: { [Instance]: Saved }
	self.Watched = {} :: { [Instance]: RBXScriptConnection }
end

local function findRoot(path: { string }): Instance?
	local current: Instance? = Workspace
	for _, name in path do
		if current == nil then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function inTable(instance: Instance): boolean
	local current: Instance? = instance
	while current ~= nil do
		if CollectionService:HasTag(current, TABLE_TAG) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isEnabledClass(instance: Instance): boolean
	for _, class in ENABLED_CLASSES do
		if instance:IsA(class) then
			return true
		end
	end
	return false
end

function PadHideController:HideOne(instance: Instance)
	if self.Saved[instance] ~= nil then
		return
	end
	if instance:IsA("BasePart") then
		const saved: Saved = { Modifier = instance.LocalTransparencyModifier }
		if not inTable(instance) then
			saved.CanCollide = instance.CanCollide
			saved.CanQuery = instance.CanQuery
			saved.CanTouch = instance.CanTouch
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
		end
		instance.LocalTransparencyModifier = 1
		self.Saved[instance] = saved
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		self.Saved[instance] = { Transparency = instance.Transparency }
		instance.Transparency = 1
	elseif isEnabledClass(instance) then
		const toggle = instance :: any
		self.Saved[instance] = { Enabled = toggle.Enabled }
		toggle.Enabled = false
		if instance:IsA("Light") then
			instance:SetAttribute(HIDDEN_ATTRIBUTE, true)
		end
	elseif instance:IsA("Attachment") and CollectionService:HasTag(instance, ANCHOR_TAG) and not inTable(instance) then
		self.Saved[instance] = { Anchor = true }
		CollectionService:RemoveTag(instance, ANCHOR_TAG)
	end
end

function PadHideController:ShowOne(instance: Instance, saved: Saved)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = saved.Modifier
		if saved.CanCollide ~= nil then
			instance.CanCollide = saved.CanCollide
			instance.CanQuery = saved.CanQuery
			instance.CanTouch = saved.CanTouch
		end
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Transparency = saved.Transparency
	elseif saved.Anchor then
		CollectionService:AddTag(instance, ANCHOR_TAG)
	elseif saved.Enabled ~= nil then
		const toggle = instance :: any
		toggle.Enabled = saved.Enabled
		if instance:IsA("Light") then
			instance:SetAttribute(HIDDEN_ATTRIBUTE, nil)
		end
	end
end

function PadHideController:HideTree(root: Instance)
	self:HideOne(root)
	for _, descendant in root:GetDescendants() do
		self:HideOne(descendant)
	end
end

-- Hides the roots found now and watches them for pieces that stream in later (the roots may stream in too).
function PadHideController:Apply()
	for _, path in ROOTS do
		const root = findRoot(path)
		if root ~= nil and self.Watched[root] == nil then
			self:HideTree(root)
			self.Watched[root] = root.DescendantAdded:Connect(function(descendant)
				if self.Hidden then
					self:HideOne(descendant)
				end
			end)
		end
	end
end

function PadHideController:Restore()
	for _, connection in self.Watched do
		connection:Disconnect()
	end
	table.clear(self.Watched)
	for instance, saved in self.Saved do
		self:ShowOne(instance, saved)
	end
	table.clear(self.Saved)
end

function PadHideController:Refresh()
	const trailer = self.Dependencies.RoundController.Vehicle() ~= START_VEHICLE
	if trailer then
		self.Hidden = true
		self:Apply() -- also picks up roots that streamed in since the last tick
	elseif self.Hidden then
		self.Hidden = false
		self:Restore()
	end
end

PadHideController:OnInit(function(self)
	self:Setup()
end)

PadHideController:OnTick(function(self)
	self:Refresh()
end, TICK_RATE)

return PadHideController
