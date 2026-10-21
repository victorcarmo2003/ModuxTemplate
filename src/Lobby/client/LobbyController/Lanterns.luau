--!strict
-- Floating smoke lanterns of the lobby (owner request 2026-10-21): the models under LOBBY_Assets.Lights rise RISE studs
-- from where they were placed and come back down, in a loop, each one on its own phase so they never move together.
-- The curve eases in and out like a soft spring (slow at the top and at the bottom). Local only (this client moves its
-- own copy; nothing replicates), presentation only. Nothing in the map = no animation, silently.
--   Streaming  the lanterns may reach the client after this module starts: they are picked up lazily for SCAN_FOR s.
local Workspace = game:GetService("Workspace")

const FOLDER = "Lights" -- under LOBBY_Assets
const RISE = 3 -- studs above the placed pivot at the top of the bob
const PERIOD = 4.2 -- s for one rise and fall
const PHASE_STEP = 0.37 -- fraction of a period between two lanterns
const SCAN_EVERY = 1 -- s between two looks for lanterns still streaming in
const SCAN_FOR = 30 -- s during which new lanterns are still picked up

export type Lanterns = {
	Step: (t: number) -> (),
	Destroy: () -> (),
}

type Lantern = { Model: Model, Home: CFrame, Phase: number }

return function(): Lanterns
	const lanterns: { Lantern } = {}
	const known: { [Instance]: boolean } = {}
	local nextScan = 0
	local startedAt: number? = nil

	local function scan()
		const root = Workspace:FindFirstChild("LOBBY_Assets")
		const folder = if root ~= nil then root:FindFirstChild(FOLDER) else nil
		if folder == nil then
			return
		end
		for _, item in folder:GetChildren() do
			if item:IsA("Model") and not known[item] then
				known[item] = true
				table.insert(lanterns, { Model = item, Home = item:GetPivot(), Phase = #lanterns * PHASE_STEP })
			end
		end
	end

	return {
		Step = function(t: number)
			const since = startedAt or t
			startedAt = since
			if t >= nextScan and t - since <= SCAN_FOR then
				nextScan = t + SCAN_EVERY
				scan()
			end
			for _, lantern in lanterns do
				-- 0 at the placed height, RISE at the top; cosine = eased at both ends
				const k = 0.5 - 0.5 * math.cos((t / PERIOD + lantern.Phase) * math.pi * 2)
				lantern.Model:PivotTo(lantern.Home + Vector3.new(0, k * RISE, 0))
			end
		end,
		Destroy = function()
			for _, lantern in lanterns do
				lantern.Model:PivotTo(lantern.Home)
			end
			table.clear(lanterns)
		end,
	}
end
