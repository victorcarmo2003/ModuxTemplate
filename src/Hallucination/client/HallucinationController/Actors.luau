--!strict
-- Local figures shared by the hallucination effects (ghost_customer, street_watcher, post_figure, shop_shadow,
-- night_opening). Plain module, client-only:
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

-- Dark faceless silhouette (owner 2026-10-20, Provisional Q-415: the figure under the post and the shop shadows), pivot
-- at the feet facing -Z, not parented. ReplicatedStorage.Assets...Shadow_Card (AST-085) when it exists; else a
-- placeholder of `height` studs in the same ink as window_shadow (#2B2233), never the Walker (#14162A, tall, hat).
const SHADOW_ASSET = "Shadow_Card"
const SHADOW_COLOR = Color3.fromHex("#2B2233")

local function shadowPart(name: string, size: Vector3, transparency: number, shape: Enum.PartType?): Part
	const made = Instance.new("Part")
	made.Name = name
	made.Size = size
	if shape then
		made.Shape = shape
	end
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.SmoothPlastic
	made.Color = SHADOW_COLOR
	made.Transparency = transparency
	return made
end

function Actors.Silhouette(height: number, transparency: number): Model
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(SHADOW_ASSET, true) else nil
	if found and found:IsA("Model") then
		const model = found:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
			end
		end
		return model
	end
	const k = height / 5
	const model = Instance.new("Model")
	model.Name = SHADOW_ASSET
	const body = shadowPart("Body", Vector3.new(1.8, 2.6, 0.9) * k, transparency)
	body.CFrame = CFrame.new(0, 1.3 * k, 0)
	body.Parent = model
	const head = shadowPart("Head", Vector3.new(2.2, 2.2, 2.2) * k, transparency, Enum.PartType.Ball)
	head.CFrame = CFrame.new(0, 3.7 * k, 0)
	head.Parent = model
	for _, x in { -0.8, 0.8 } do
		const ear = shadowPart("Ear", Vector3.new(0.7, 0.7, 0.7) * k, transparency, Enum.PartType.Ball)
		ear.CFrame = CFrame.new(x * k, 4.75 * k, 0)
		ear.Parent = model
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	return model
end

-- Head position of a rig (falls back to the pivot).
function Actors.HeadOf(model: Model): Vector3
	const head = model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else model:GetPivot().Position
end

return Actors
