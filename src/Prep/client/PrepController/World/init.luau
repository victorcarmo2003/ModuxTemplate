--!strict
-- World: the 3D layer of the focused prep mode (docs/tech/prep-3d.md §2; TASK-194 stub, the files below are filled by later
-- tasks and each has ONE owner):
--   Types.luau      shared vocabulary (this task)
--   Ray, Aim, Targets, Marker      TASK-196        Plane  TASK-197        Access  TASK-207
--   Stages/<Name>.luau (Stage3D)   TASK-203 Grill, 204 Board, 205 Toppings, 206 Order and Serve
--   GrillView  TASK-203        Director3D  TASK-204/205        Strokes  205        Puppet  208        Coach  209
--   Editable  TASK-218 (behind Rules.World.Editable)
-- Until then the layer is inert: `Active()` is false while Content.Prep.Rules.ThreeD is false, `Enter` / `Leave` / `Send` do
-- nothing, and the 2D mode runs exactly as before. The controller (TASK-198) calls Enter and Leave; no one else does.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Types = require(script.Types)

export type WorldMsg = Types.WorldMsg

const World = {}

World.Types = Types

-- Whether the 3D layer is on at all (a stage may still be 2D: Stage.Armed).
function World.Active(): boolean
	return Content.Prep.Rules.ThreeD
end

-- The mode was entered at `station` (1..Content.Prep.Stations): build the registry, the pools and the folder (TASK-196+).
function World.Enter(_station: number) end

-- The mode was left (every pool destroyed; no leak after 20 entries, prep-3d.md §8).
function World.Leave() end

-- A presentation message from a stage to the world (TASK-203+).
function World.Send(_message: WorldMsg) end

return World
