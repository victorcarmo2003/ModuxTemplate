--!strict
-- NpcService/Walker: follows a list of graph waypoints with Humanoid:MoveTo (architecture.md §12.3, T11). TASK-031.
-- One waypoint at a time (graph edges are <= 40 studs, §18.6, so a single MoveTo never hits its 8 s give-up at
-- customer speeds). A waypoint missed twice is snapped to (PROVISIONAL anti-stuck: the NPC never blocks the queue).
-- `alive` is polled so a despawn or a newer walk order stops this one within POLL seconds; nothing here outlives it.
-- Walk animation is not here: Motor6D.Transform does not replicate, so the limbs are animated by the client
-- (DEC-183 note, Provisional; NpcController/RigController). No network, no Modux.

export type Mover = { Model: Model, Root: BasePart, Humanoid: Humanoid }

const POLL = 0.1 -- seconds between checks of arrival / cancellation
const STEP_TIMEOUT = 9 -- seconds; Humanoid:MoveTo gives up at 8 s and fires MoveToFinished(false)
const RETRIES = 1 -- extra MoveTo per waypoint before snapping
const LIFT = 3 -- HumanoidRootPart above the floor point (architecture.md §18.5)

const Walker = {}

-- One MoveTo. true = reached, false = gave up or cancelled.
local function step(mover: Mover, target: Vector3, alive: () -> boolean): boolean
	local finished: boolean? = nil
	const connection = mover.Humanoid.MoveToFinished:Connect(function(reached: boolean)
		finished = reached
	end)
	mover.Humanoid:MoveTo(target)
	const deadline = os.clock() + STEP_TIMEOUT
	while finished == nil and alive() and os.clock() < deadline do
		task.wait(POLL)
	end
	connection:Disconnect()
	return finished == true
end

-- Puts the rig on `target` (floor point), keeping its heading.
function Walker.Snap(mover: Mover, target: Vector3)
	const rotation = mover.Root.CFrame.Rotation
	mover.Model:PivotTo(CFrame.new(target + Vector3.new(0, LIFT, 0)) * rotation)
end

-- Turns the rig to face `look` (horizontal part only).
function Walker.Face(mover: Mover, look: Vector3)
	const flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	const position = mover.Root.Position
	mover.Root.CFrame = CFrame.lookAt(position, position + flat.Unit)
end

-- Walks through `points` in order. `reached(index)` runs after each waypoint. true = all reached (or snapped),
-- false = cancelled (`alive` turned false).
function Walker.Follow(mover: Mover, points: { Vector3 }, alive: () -> boolean, reached: (index: number) -> ()): boolean
	for index, point in points do
		local arrived = false
		for _ = 0, RETRIES do
			if not alive() then
				return false
			end
			arrived = step(mover, point, alive)
			if arrived then
				break
			end
		end
		if not alive() then
			return false
		end
		if not arrived then
			Walker.Snap(mover, point)
		end
		reached(index)
	end
	return true
end

-- Stops any MoveTo in progress.
function Walker.Stop(mover: Mover)
	if mover.Root:IsDescendantOf(workspace) then
		mover.Humanoid:MoveTo(mover.Root.Position)
	end
end

return table.freeze(Walker)
