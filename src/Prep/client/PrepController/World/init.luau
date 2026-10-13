--!strict
-- World: the 3D layer of the focused prep mode (docs/tech/prep-3d.md §2; TASK-194 stub, the files below are filled by later
-- tasks and each has ONE owner):
--   Types.luau      shared vocabulary (TASK-194)
--   Ray, Aim, Targets, Marker, Highlight   TASK-196 (the pointer ray, the hover, the hitbox registry, the 3D marker)
--   Plane  TASK-197        Access  TASK-207
--   Stages/<Name>.luau (Stage3D)   TASK-203 Grill, 204 Board, 205 Toppings, 206 Order and Serve
--   GrillView  TASK-203        Director3D  TASK-204/205        Strokes  205        Puppet  208        Coach  209
--   Editable  TASK-218 (behind Rules.World.Editable)
-- The layer is inert while Content.Prep.Rules.ThreeD is false, and the 2D mode runs exactly as before: `Enter` does nothing
-- (only the dev switch `/dev prep ray`, the player attribute PrepRay, wakes the aim to print what a click hits). The controller
-- (TASK-198) calls Enter and Leave; no one else does. While it runs there is ONE frame loop (Aim's RenderStepped) and one folder
-- (`Types.FolderName`) under the camera; Leave destroys all of it.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Aim = require(script.Aim)
local Bin = require(script.Bin)
local Coach = require(script.Coach)
local Highlight = require(script.Highlight)
local Juice = require(script.Juice)
local Marker = require(script.Marker)
local Plane = require(script.Plane)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local Pointer = require(script.Parent.Pointer)
local Targets = require(script.Targets)
local Types = require(script.Types)

export type WorldMsg = Types.WorldMsg

-- Attribute of the local player the server toggles with `/dev prep ray`.
const DEBUG_ATTRIBUTE = "PrepRay"

const World = {}

World.Types = Types
World.CoachLine = Coach.Line
World.CoachTab = Coach.Tab
World.Streak = Juice.Streak
World.Plane = Plane

local running: {
	Folder: Folder,
	Registry: Targets.Registry,
	Outline: Highlight.Outline,
	Marker: Marker.Marker,
	Aim: Aim.Aim?,
	Juice: Juice.Juice,
	Bin: Bin.Bin,
	Coach: Coach.Coach,
	StopFrame: (() -> ())?,
}? = nil
-- the sound player of the controller (key, world point, playback speed); the juice and the bin use it
local audio: Juice.Audio? = nil
-- the camera frame and field of view of the view that is in front, for the bin
local view: { Frame: CFrame, Fov: number, Distance: number }? = nil
-- the one no-op Juice a stage gets while the world is not running
local nothing: Juice.Juice? = nil
local listener: ((Types.AimMsg) -> ())? = nil
local assist = false
local workPlane: Aim.WorkPlane? = nil

local function debugOn(): boolean
	return Players.LocalPlayer:GetAttribute(DEBUG_ATTRIBUTE) == true
end

-- Whether the 3D layer is on at all (a stage may still be 2D: Stage.Armed).
function World.Active(): boolean
	return Content.Prep.Rules.ThreeD
end

-- The mode was entered at `station` (1..Content.Prep.Stations): builds the registry of the tagged hitboxes of that seat, the
-- pools, the marker and the aim on `pointer` (Pointer.luau; without it the targets exist but nothing aims).
function World.Enter(station: number, pointer: Pointer.Pointer?)
	World.Leave()
	if not World.Active() and not debugOn() then
		return
	end
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const rules = Content.Prep.Rules.World
	const folder = Instance.new("Folder")
	folder.Name = Types.FolderName
	folder.Parent = camera
	const registry = Targets.new(rules, folder)
	registry:Scan(workspace, station, not World.Active())
	const outline = Highlight.new(folder, rules, Motion.Reduced)
	const marker = Marker.new(folder, rules)
	const juice = Juice.new(folder, rules, audio)
	const binView = Bin.new(folder, rules, registry, function(): Juice.Juice
		return juice
	end, audio)
	if view ~= nil then
		binView:SetView(view.Frame, view.Fov, view.Distance)
	end
	local aim: Aim.Aim? = nil
	if pointer ~= nil then
		aim = Aim.new({
			Pointer = pointer,
			Targets = registry,
			Rules = rules,
			Marker = marker,
			Highlight = outline,
			Assist = function(): boolean
				return assist
			end,
			Listener = listener,
			Debug = debugOn,
		})
		if workPlane ~= nil then
			aim:SetWorkPlane(workPlane)
		end
	end
	const coach = Coach.new(folder, rules, pointer, station)
	local stop: (() -> ())? = nil
	if aim ~= nil then
		stop = aim:OnFrame(function(dt: number)
			juice:Step(dt)
			binView:Step(dt)
			coach:Step(dt)
		end)
	end
	running = {
		Folder = folder,
		Registry = registry,
		Outline = outline,
		Marker = marker,
		Aim = aim,
		Juice = juice,
		Bin = binView,
		Coach = coach,
		StopFrame = stop,
	}
end

-- The mode was left (every pool destroyed; no leak after 20 entries, prep-3d.md §8).
function World.Leave()
	const current = running
	if current == nil then
		return
	end
	running = nil
	if current.Aim ~= nil then
		current.Aim:Cancel("Leave")
	end
	if current.StopFrame ~= nil then
		current.StopFrame()
	end
	current.Coach:Destroy()
	current.Bin:Destroy()
	current.Juice:Destroy()
	if current.Aim ~= nil then
		current.Aim:Destroy()
	end
	current.Outline:Destroy()
	current.Marker:Destroy()
	current.Registry:Destroy()
	current.Folder:Destroy()
end

-- Is the 3D layer built right now?
function World.Running(): boolean
	return running ~= nil
end

-- The registry: stages add their targets here (`Add`) and read the scanned ones (`Get`).
function World.Targets(): Targets.Registry?
	return if running ~= nil then running.Registry else nil
end

function World.Aim(): Aim.Aim?
	return if running ~= nil then running.Aim else nil
end

-- The stage that owns the front tab hears every AimMsg here (Stage3D.OnAim); it survives Enter / Leave.
function World.SetListener(fn: ((Types.AimMsg) -> ())?)
	listener = fn
	if running ~= nil and running.Aim ~= nil then
		running.Aim:SetListener(fn)
	end
end

-- Assist: hitboxes x Rules.World.Hitbox.AssistScale (the next Refresh applies it).
function World.SetAssist(on: boolean)
	assist = on
end

-- The plane a drag is read on (the bench top at the Y of the view focus); nil = none (the hit point is used).
function World.SetWorkPlane(plane: Aim.WorkPlane?)
	workPlane = plane
	if running ~= nil and running.Aim ~= nil then
		running.Aim:SetWorkPlane(plane)
	end
end

-- The `X` button: moves the gamepad cursor to the next enabled target of the stage.
function World.Next(): Types.Target?
	return if running ~= nil and running.Aim ~= nil then running.Aim:Next() else nil
end

-- The juice of the world (pops, bursts, floating words, flashes); a no-op while the world is not running, so a stage never checks.
function World.Juice(): Juice.Juice
	if running ~= nil then
		return running.Juice
	end
	if nothing == nil then
		nothing = Juice.None()
	end
	return nothing :: Juice.Juice
end

-- The drag tutorial (ghost hand); a no-op while the world is not running.
function World.Coach(): Coach.Coach
	if running ~= nil then
		return running.Coach
	end
	return Coach.None()
end

-- The virtual bin of the view (nil while the world is not running).
function World.Bin(): Bin.Bin?
	return if running ~= nil then running.Bin else nil
end

-- The sound player (key, world point, playback speed); set by the controller on Enter.
function World.SetAudio(fn: Juice.Audio?)
	audio = fn
end

-- The camera frame and Fov the view in front ends on: the bin goes to its place on that screen.
function World.SetView(frame: CFrame, fov: number, distance: number)
	view = { Frame = frame, Fov = fov, Distance = distance }
	if running ~= nil then
		running.Bin:SetView(frame, fov, distance)
	end
end

-- A presentation message from a stage to the world (TASK-203+).
function World.Send(_message: WorldMsg) end

return World
