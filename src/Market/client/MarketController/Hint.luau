--!strict
--[[
	Hint ("ObjectiveHint"): the guide to the Gear Stand at closing time (user feedback 2026-10-11; Q-203 Provisional).
	Plain module, client only: no Modux, no network, decides nothing. MarketController says when it is active
	(Closing -> start of Open, money for a line or never bought, player not at the Mart yet) and which instance is the
	target; this draws the TutorialArrow bouncing over it and the TutorialPointer on the screen edge when the target is
	off screen. Both are the tutorial's components, scaled by the global UI scale (UiScale.Current).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Interface = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local TutorialArrow = require(Interface.TutorialArrow)
local TutorialPointer = require(Interface.TutorialPointer)
local UiScale = require(Interface.UiScale)

const ARROW_MAX = 250 -- studs
const EDGE_MARGIN = 48 -- px from the screen edge

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

function Hint.new(playerGui: Instance): Hint
	const self = setmetatable({}, Hint) :: any
	self.Active = Vide.source(false)
	self.Target = Vide.source(nil :: Instance?)
	self.PointerShown = Vide.source(false)
	self.PointerAt = Vide.source(Vector2.zero)
	self.PointerAngle = Vide.source(0)
	self.Gui = {}
	self.Unmount = Vide.root(function()
		const shown = function(): boolean
			return (self.Active() :: boolean) and self.Target() ~= nil and not Cinematic.Active()
		end
		const arrow = TutorialArrow({
			Name = "MartHintArrow",
			Adornee = function(): Instance?
				return self.Target()
			end,
			Shown = shown,
			Offset = Vector3.new(0, 1.2, 0),
			MaxDistance = ARROW_MAX,
			Scale = UiScale.Current,
		})
		arrow.Parent = playerGui
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
					return shown() and self.PointerShown()
				end,
				Position = self.PointerAt,
				Angle = self.PointerAngle,
				Scale = UiScale.Current,
			}),
		})
		overlay.Parent = playerGui
		table.insert(self.Gui, arrow)
		table.insert(self.Gui, overlay)
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

-- Edge pointer: where the target is relative to the camera, hidden while it is on screen.
function Hint.Step(self: Hint)
	const camera = workspace.CurrentCamera
	const position = positionOf(Vide.untrack(self.Target))
	if camera == nil or position == nil or not Vide.untrack(self.Active) then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const viewport = camera.ViewportSize
	const point, onScreen = camera:WorldToViewportPoint(position)
	const centre = viewport / 2
	local delta = Vector2.new(point.X, point.Y) - centre
	if point.Z < 0 then
		delta = -delta -- behind the camera: the projection is mirrored
	end
	const inside = onScreen
		and point.X > EDGE_MARGIN
		and point.X < viewport.X - EDGE_MARGIN
		and point.Y > EDGE_MARGIN
		and point.Y < viewport.Y - EDGE_MARGIN
	if inside or delta.Magnitude < 1 then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const halfX = math.max(viewport.X / 2 - EDGE_MARGIN, 1)
	const halfY = math.max(viewport.Y / 2 - EDGE_MARGIN, 1)
	const t = math.min(
		if delta.X ~= 0 then halfX / math.abs(delta.X) else math.huge,
		if delta.Y ~= 0 then halfY / math.abs(delta.Y) else math.huge
	)
	Vide.batch(function()
		self.PointerAt(centre + delta * t)
		self.PointerAngle(math.deg(math.atan2(delta.Y, delta.X)))
		if not Vide.untrack(self.PointerShown) then
			self.PointerShown(true)
		end
	end)
end

function Hint.Destroy(self: Hint)
	self.Unmount()
	for _, gui in self.Gui do
		gui:Destroy()
	end
	table.clear(self.Gui)
end

return Hint
