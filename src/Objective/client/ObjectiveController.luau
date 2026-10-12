--!strict
--[[
	ObjectiveController (user request 2026-10-11, Provisional; first user: the FOR SALE sign of the trailer, day 5)

	General-purpose "look here" for a world objective, outside the tutorial. Two pieces, both local presentation:

	  Mark(adornee, lift)   Pulsing Mustard Highlight on the thing + the bobbing 3D arrow over it (the tutorial's Beacon,
	                        required as is) and, when the player is far from it, the screen-sized bouncing arrow
	                        (TutorialArrow component). Clear() takes both away. One objective at a time (the last
	                        Mark wins). The owner (e.g. VehicleController) says when to mark and when to clear.
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
local TutorialArrow = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.TutorialArrow)

const FX_FOLDER = "ObjectiveFx"
const ARROW_FAR = 22 -- studs from the camera to the objective from where the screen-sized arrow shows
const ARROW_MAX = 400 -- studs: MaxDistance of that arrow
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
	self.ArrowFar = Vide.source(false) :: Vide.Source<boolean>
	self.Scale = Vide.source(1) :: Vide.Source<number>
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
	const unmount, arrow = Vide.root(function()
		return TutorialArrow({
			Name = "ObjectiveArrow",
			Adornee = function(): Instance?
				return if self.Marked() then self.Beacon.Tip else nil
			end,
			Shown = function()
				return self.Marked() and self.ArrowFar() and not Cinematic.Active()
			end,
			Offset = Vector3.zero,
			MaxDistance = ARROW_MAX,
			Scale = function()
				return self.Scale()
			end,
		})
	end)
	table.insert(self.Unmounts, unmount)
	arrow.Parent = playerGui
end

-- Every frame: move the marks, decide whether the screen-sized arrow shows (far from the camera)
function ObjectiveController:Update()
	self.Beacon.Step()
	if self.Beacon.Marked() == nil then
		if Vide.untrack(self.ArrowFar) then
			self.ArrowFar(false)
		end
		return
	end
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	const scale = Theme.ScaleOf(camera.ViewportSize)
	if math.abs(scale - Vide.untrack(self.Scale)) > 0.01 then
		self.Scale(scale)
	end
	const far = (self.Beacon.Tip.Position - camera.CFrame.Position).Magnitude > ARROW_FAR
	if far ~= Vide.untrack(self.ArrowFar) then
		self.ArrowFar(far)
	end
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
