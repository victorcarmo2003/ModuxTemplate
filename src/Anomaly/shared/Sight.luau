--!strict
-- Line of sight for "is it seen" tests (TASK-493). Shared by the server (AnomalyService:Looking, the stare drain, the
-- suspense hidden test) and the client (stare pressure, the suspense glance). Pure: no Modux.
-- A raycast alone was wrong at the restaurant counter: the invisible CounterBarrier collides, and Roblox ignores
-- CanQuery = false on a part that collides, so nobody could ever "see" a customer at the window. Here a hit on a part
-- you can see through (Transparency >= SEE_THROUGH, Glass, ForceField) does not block: the ray goes on from just past it.
local Sight = {}

const SEE_THROUGH = 0.4 -- transparency from which a part does not hide what is behind it (glass, barriers)
const MAX_HOPS = 6
const NUDGE = 0.05 -- studs past a see-through hit before casting again

local function seeThrough(part: BasePart): boolean
	return part.Transparency >= SEE_THROUGH
		or part.Material == Enum.Material.Glass
		or part.Material == Enum.Material.ForceField
end

-- true when nothing opaque stands between `origin` and `origin + offset` (params = the caller's filter).
function Sight.Clear(origin: Vector3, offset: Vector3, params: RaycastParams): boolean
	const total = offset.Magnitude
	if total < 1e-4 then
		return true
	end
	const direction = offset.Unit
	local from = origin
	local left = total
	for _ = 1, MAX_HOPS do
		const hit = workspace:Raycast(from, direction * left, params)
		if hit == nil then
			return true
		end
		const part = hit.Instance
		if not (part:IsA("BasePart") and seeThrough(part)) then
			return false
		end
		const travelled = (hit.Position - from).Magnitude + NUDGE
		left -= travelled
		if left <= 0 then
			return true
		end
		from = hit.Position + direction * NUDGE
	end
	return false
end

return table.freeze(Sight)
