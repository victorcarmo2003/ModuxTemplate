--!strict
-- WorldStroke: keeps the outlines of a studs-sized BillboardGui (PadTag, ZoneSign) in proportion to the sign. A UIStroke
-- is in screen px: far away the sign shrinks and the outline does not, so the text turned into a black blot (owner
-- 2026-10-20, the FREE tags over the lobby pads). Every UIStroke under the billboard is scaled by the billboard's
-- current height over `reference` (the height in px where the kit outlines read right), at most 1: up close nothing
-- changes. The design thickness of a stroke is read the first time it is seen (and again when a component rewrites it).
-- Returns the disconnect.
local RunService = game:GetService("RunService")

const BASE = "WorldStrokeBase"

return function(billboard: BillboardGui, reference: number): () -> ()
	local factor = 1
	-- Thickness this module last wrote on each stroke: our own writes are not design changes. Property signals are
	-- deferred, so a flag around the write misses them and every write was read back as a new base (a loop that shrank
	-- the outline to 0 and hit the re-entrancy limit, owner 2026-10-20).
	const written: { [UIStroke]: number } = setmetatable({}, { __mode = "k" }) :: any

	local function apply(stroke: UIStroke)
		const base = stroke:GetAttribute(BASE)
		if type(base) ~= "number" then
			return
		end
		const thickness = base * factor
		written[stroke] = thickness
		stroke.Thickness = thickness
	end

	local function track(object: Instance)
		if not object:IsA("UIStroke") then
			return
		end
		const stroke = object :: UIStroke
		stroke:SetAttribute(BASE, stroke.Thickness)
		apply(stroke)
		stroke:GetPropertyChangedSignal("Thickness"):Connect(function()
			const mine = written[stroke]
			if mine ~= nil and math.abs(stroke.Thickness - mine) < 1e-3 then
				return
			end
			stroke:SetAttribute(BASE, stroke.Thickness)
			apply(stroke)
		end)
	end

	for _, object in billboard:GetDescendants() do
		track(object)
	end
	const added = billboard.DescendantAdded:Connect(track)

	-- AbsoluteSize of a BillboardGui follows the camera distance; checked once a frame (cheap: one compare)
	const step = RunService.Heartbeat:Connect(function()
		if not billboard.Enabled then
			return
		end
		const next = math.clamp(billboard.AbsoluteSize.Y / reference, 0, 1)
		if math.abs(next - factor) < 0.02 then
			return
		end
		factor = next
		for _, object in billboard:GetDescendants() do
			if object:IsA("UIStroke") then
				apply(object)
			end
		end
	end)

	return function()
		added:Disconnect()
		step:Disconnect()
	end
end
