--!strict
--[[
	ObjectiveController (user request 2026-10-11, Provisional; first user: the FOR SALE sign of the trailer, day 5)

	General-purpose "look here" for a world objective, outside the tutorial. Two pieces, both local presentation:

	  Mark(adornee, lift)   Pulsing Mustard Highlight on the thing + the bobbing 3D arrow over it (the tutorial's Beacon,
	                        required as is; the arrow grows with the distance) and, ONLY while neither the arrow tip nor
	                        the thing is on screen, the TutorialPointer badge on the screen edge (EdgePointer; owner
	                        request 2026-10-14). Clear() takes both away. One objective at a time (the last Mark wins).
	                        The owner (e.g. VehicleController) says when to mark and when to clear. A cinematic hides
	                        the marks (Beacon) and the badge.
	  Focus(getter, seconds, fov)
	                        Short, smooth camera focus: CameraController Cutscene mode (own head, eased turn to the
	                        point, a light depth of field) for `seconds`, then back to the first person. Only when the
	                        camera is in the normal first person (never over a cutscene, spectating, the loading
	                        curtain). The server holds the body still for the same time (VehicleService:FocusSign), so
	                        the player never walks relative to a turned camera. Returns whether it started.

	Nothing is sent and nothing is decided here.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Beacon = require(StarterPlayer.StarterPlayerScripts.client.Tutorial.TutorialController.Beacon)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local TutorialPointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialPointer)
local EdgePointer = require(StarterPlayer.StarterPlayerScripts.client.Interface.EdgePointer)

const FX_FOLDER = "ObjectiveFx"
const DEFAULT_LIFT = 1.2 -- studs between the top of the thing and the arrow tip
const FOCUS_FOV = 60 -- degrees while the focus holds (the player's own is wider); Provisional

const ObjectiveController = Modux.Controller(
	"ObjectiveController",
	{ Require = { "CameraController" }, Priority = 765 }
)

function ObjectiveController:Setup()
	self.Folder = nil :: Folder?
	self.Beacon = Beacon.new(function(): Instance
		return self:FxFolder()
	end) :: Beacon.Beacon
	self.Marked = Vide.source(false) :: Vide.Source<boolean>
	self.PointerShown = Vide.source(false) :: Vide.Source<boolean>
	self.PointerAt = Vide.source(Vector2.zero) :: Vide.Source<Vector2>
	self.PointerAngle = Vide.source(0) :: Vide.Source<number>
	self.Scale = Vide.source(1) :: Vide.Source<number>
	self.Edge = EdgePointer.new() :: EdgePointer.EdgePointer
	self.FocusToken = 0 :: number
	self.Focusing = false :: boolean
	self.Mounted = false :: boolean
	self.Unmounts = {} :: { () -> () }
end

function ObjectiveController:FxFolder(): Folder
	const existing = self.Folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = FX_FOLDER
	folder.Parent = Workspace
	self.Folder = folder
	return folder
end

-- Marks `adornee` (nil clears). lift = studs between its top and the arrow tip.
function ObjectiveController:Mark(adornee: Instance?, lift: number?)
	self.Beacon.Set(adornee, lift or DEFAULT_LIFT)
	self.Marked(adornee ~= nil)
end

function ObjectiveController:Clear()
	self:Mark(nil, nil)
end

function ObjectiveController:IsMarked(): boolean
	return self.Beacon.Marked() ~= nil
end

-- Camera focus for `seconds` on a live position (re-read every frame; nil = the own facing)
function ObjectiveController:Focus(getter: () -> Vector3?, seconds: number, fov: number?): boolean
	const camera = self.Dependencies.CameraController
	if self.Focusing or Vide.untrack(camera.Mode) ~= "FirstPerson" or Cinematic.Active() then
		return false
	end
	self.Focusing = true
	self.FocusToken += 1
	const token = self.FocusToken
	camera:Cutscene(true)
	camera:Focus(getter, fov or FOCUS_FOV)
	task.delay(seconds, function()
		if self.FocusToken ~= token then
			return
		end
		self:EndFocus()
	end)
	return true
end

function ObjectiveController:EndFocus()
	if not self.Focusing then
		return
	end
	self.Focusing = false
	const camera = self.Dependencies.CameraController
	-- only if nobody else (a cutscene) took the POV meanwhile
	if Vide.untrack(camera.Mode) == "Cutscene" then
		camera:Focus(nil, nil)
		camera:Cutscene(false)
	end
end

function ObjectiveController:Mount(playerGui: Instance)
	if self.Mounted then
		return
	end
	self.Mounted = true
	-- Edge pointer: viewport pixels (WorldToViewportPoint), so the whole screen with no inset
	const unmount, overlay = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "ObjectiveOverlay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = 4,
			Enabled = function()
				return not Cinematic.Active()
			end,
			TutorialPointer({
				Name = "ObjectivePointer",
				Shown = function()
					return self.Marked() and self.PointerShown()
				end,
				Position = self.PointerAt,
				Angle = self.PointerAngle,
				Scale = function()
					return self.Scale()
				end,
			}),
		})
	end)
	table.insert(self.Unmounts, unmount)
	overlay.Parent = playerGui
end

-- Every frame: move the marks, then decide whether the edge badge shows (the tip and the thing both off screen)
function ObjectiveController:Update()
	self.Beacon.Step()
	const adornee = self.Beacon.Marked()
	const tip = self.Beacon.TipPosition()
	const camera = Workspace.CurrentCamera
	if adornee == nil or tip == nil or camera == nil then
		self.Edge.Reset()
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	const scale = Theme.ScaleOf(camera.ViewportSize)
	if math.abs(scale - Vide.untrack(self.Scale)) > 0.01 then
		self.Scale(scale)
	end
	const points = { tip }
	local at: Vector3? = nil
	if adornee:IsA("Model") then
		at = adornee:GetPivot().Position
	elseif adornee:IsA("BasePart") then
		at = adornee.Position
	elseif adornee:IsA("Attachment") then
		at = adornee.WorldPosition
	end
	if at ~= nil then
		table.insert(points, at)
	end
	const shown, edgeAt, angle = self.Edge.Update(points, scale)
	if not shown then
		if Vide.untrack(self.PointerShown) then
			self.PointerShown(false)
		end
		return
	end
	Vide.batch(function()
		self.PointerAt(edgeAt)
		self.PointerAngle(angle)
		if not Vide.untrack(self.PointerShown) then
			self.PointerShown(true)
		end
	end)
end

ObjectiveController:OnInit(function(self)
	self:Setup()
end)

ObjectiveController:OnStart(function(self)
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
	RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end)

return ObjectiveController
