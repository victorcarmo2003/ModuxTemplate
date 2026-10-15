--!strict
--[[
	Hint ("ObjectiveHint"): the guide to the Gear Stand at closing time (user feedback 2026-10-11; Q-203 Provisional).
	Plain module, client only: no Modux, no network, decides nothing. MarketController says when it is active
	(Closing -> start of Open, money for a line or never bought, player not at the Mart yet) and which instance is the
	target; this draws the tutorial's Beacon (its own instance: pulsing Highlight on the stand + the 3D arrow over it,
	grown with the distance) and, ONLY while neither the arrow tip nor the stand is on screen (EdgePointer), the
	TutorialPointer badge on the screen edge (owner request 2026-10-14: the 2D arrow is gone). The badge is scaled by the
	global UI scale (UiScale.Current). A cinematic hides everything.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Interface = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local EdgePointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.EdgePointer)
local Beacon = require(StarterPlayer.StarterPlayerScripts.client.Tutorial.TutorialController.Beacon)
local TutorialPointer = require(Interface.TutorialPointer)
local UiScale = require(Interface.UiScale)

const EDGE_MARGIN = 48 -- px from the screen edge where the badge sits (x UI scale)
const LIFT = 1.2 -- studs between the top of the stand and the arrow tip
const FX_FOLDER = "MartHintFx"

export type Hint = {
	Active: Vide.Source<boolean>,
	Target: Vide.Source<Instance?>,
	PointerShown: Vide.Source<boolean>,
	PointerAt: Vide.Source<Vector2>,
	PointerAngle: Vide.Source<number>,
	Unmount: () -> (),
	Gui: { Instance },
	Set: (self: Hint, active: boolean) -> (),
	SetTarget: (self: Hint, target: Instance?) -> (),
	Step: (self: Hint) -> (),
	Destroy: (self: Hint) -> (),
}

const Hint = {}
Hint.__index = Hint

local function positionOf(target: Instance?): Vector3?
	if target == nil then
		return nil
	elseif target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Attachment") then
		return target.WorldPosition
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

-- What the Highlight can wrap: a Model or a part; an anchor (Attachment) marks the part or model it sits in
local function adorneeOf(target: Instance?): Instance?
	if target == nil then
		return nil
	elseif target:IsA("Model") or target:IsA("BasePart") then
		return target
	elseif target:IsA("Attachment") then
		const parent = target.Parent
		if parent ~= nil and (parent:IsA("BasePart") or parent:IsA("Model")) then
			return parent
		end
	end
	return nil
end

function Hint.new(playerGui: Instance): Hint
	const self = setmetatable({}, Hint) :: any
	self.Active = Vide.source(false)
	self.Target = Vide.source(nil :: Instance?)
	self.PointerShown = Vide.source(false)
	self.PointerAt = Vide.source(Vector2.zero)
	self.PointerAngle = Vide.source(0)
	self.Gui = {}
	self.Folder = nil :: Folder?
	self.Edge = EdgePointer.new(EDGE_MARGIN)
	self.Beacon = Beacon.new(function(): Instance
		const existing = self.Folder :: Folder?
		if existing ~= nil and existing.Parent ~= nil then
			return existing
		end
		const folder = Instance.new("Folder")
		folder.Name = FX_FOLDER
		folder.Parent = Workspace
		self.Folder = folder
		return folder
	end) :: Beacon.Beacon
	self.Unmount = Vide.root(function()
		-- screen-edge pointer in viewport pixels (whole screen, no inset), like the tutorial's
		const overlay = Vide.create("ScreenGui")({
			Name = "MartHintOverlay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 4,
			Enabled = function()
				return not Cinematic.Active()
			end,
			TutorialPointer({
				Name = "MartHintPointer",
				Shown = function()
					return (self.Active() :: boolean) and self.Target() ~= nil and self.PointerShown()
				end,
				Position = self.PointerAt,
				Angle = self.PointerAngle,
				Scale = UiScale.Current,
			}),
		})
		overlay.Parent = playerGui
		table.insert(self.Gui, overlay)
	end)
	-- the Beacon needs a frame to finish its pop out even when MarketController stops calling Step
	self.Frame = RunService.Heartbeat:Connect(function()
		(self :: Hint):Step()
	end)
	return self :: Hint
end

function Hint.Set(self: Hint, active: boolean)
	if Vide.untrack(self.Active) ~= active then
		self.Active(active)
	end
end

function Hint.SetTarget(self: Hint, target: Instance?)
	if Vide.untrack(self.Target) ~= target then
		self.Target(target)
	end
end

-- Every frame: marks the stand while the hint is active, moves the Beacon and places the edge badge (only while the
-- arrow tip and the stand are both off screen).
function Hint.Step(self: Hint)
	const this = self :: any
	const beacon = this.Beacon :: Beacon.Beacon
	const target = Vide.untrack(self.Target)
	const active = Vide.untrack(self.Active) and target ~= nil
	beacon.Set(if active then adorneeOf(target) else nil, LIFT)
	beacon.Step()
	const tip = beacon.TipPosition()
	const position = positionOf(target)
	if not active or position == nil then
		(this.Edge :: EdgePointer.EdgePointer).Reset()
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const points = if tip then { tip, position } else { position }
	const shown, at, angle = (this.Edge :: EdgePointer.EdgePointer).Update(points, Vide.untrack(UiScale.Current))
	if not shown then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	Vide.batch(function()
		self.PointerAt(at)
		self.PointerAngle(angle)
		if not Vide.untrack(self.PointerShown) then
			self.PointerShown(true)
		end
	end)
end

function Hint.Destroy(self: Hint)
	const this = self :: any
	;(this.Frame :: RBXScriptConnection):Disconnect()
	self.Unmount()
	for _, gui in self.Gui do
		gui:Destroy()
	end
	table.clear(self.Gui)
	;(this.Beacon :: Beacon.Beacon).Destroy()
	const folder = this.Folder :: Folder?
	if folder ~= nil then
		folder:Destroy()
	end
end

return Hint
