--!strict
-- Local figures shared by the hallucination effects (ghost_customer, street_watcher). Plain module, client-only:
-- CrewRig.Build with Tag = false (RigController and the server never see it), Night pack + its face (kept on purpose,
-- Provisional 2026-10-14: it highlights the hallucination), anchored, no collision, no query, no prompt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)

const PACK: CrewRig.Pack = "Night"
const FACE = Content.Looks.PackFace.Night

const Actors = {}

Actors.HIP = Vector3.new(0, 3, 0) -- HRP = ground point + 3 studs (architecture.md §18.5)

-- A random customer species and civil outfit; nil when the tables have none.
function Actors.PickLook(random: Random): (string?, string?)
	const species: { string } = {}
	for _, row in Content.Species.List do
		if row.Customer and row.ReservedFor == nil then
			table.insert(species, row.Key)
		end
	end
	const outfits: { string } = {}
	for _, row in Content.Outfits.List do
		if row.Use == "Civil" then
			table.insert(outfits, row.Key)
		end
	end
	if #species == 0 or #outfits == 0 then
		return nil, nil
	end
	return species[random:NextInteger(1, #species)], outfits[random:NextInteger(1, #outfits)]
end

-- Customer-looking rig with its root at `frame` (already HIP above the ground). Not parented.
function Actors.Customer(random: Random, name: string, frame: CFrame): Model?
	const species, outfit = Actors.PickLook(random)
	if species == nil or outfit == nil then
		return nil
	end
	const ok, result = pcall(function(): Model
		const model = CrewRig.Build(species, outfit, {
			Tag = false,
			Anchored = true,
			LookPack = PACK,
			Name = name,
			CFrame = frame,
		})
		CrewRig.Dress(model, PACK, FACE)
		return model
	end)
	if not ok then
		return nil
	end
	const model = result
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return model
end

-- Head position of a rig (falls back to the pivot).
function Actors.HeadOf(model: Model): Vector3
	const head = model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else model:GetPivot().Position
end

return Actors
