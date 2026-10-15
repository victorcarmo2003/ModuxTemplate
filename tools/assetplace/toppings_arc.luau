--!nocheck
-- toppings_arc.luau (Studio snippet, idempotent; owner layout of 2026-10-14, Provisional)
-- Toppings section: the plate with the bun sits in the FRONT CENTRE of the topping counter, on a white `Board` slab, and the bowls go
-- round it: the two that unlock last (Bacon, Cream Cheese) in the front corners, a back row of four (Potato Sticks, Ketchup, Mustard,
-- Cheese). Positions below are the owner's hand layout, captured from the Studio place (world studs). Each `Bin_*` MeshPart of
-- TRL-K_AST-017_ToppingGrid (Fill, Lid, Label, Lock and the Prompt_Use / Prompt_Restock attachments ride on it) and its PrepTargets
-- part PT_Topping_<key> (the 3D hitbox) are moved as one piece. The old `Base` mesh is replaced by the `Board` slab.
-- Not recreated by Place.run: run it AFTER bind_map01 (see STUDIO_LAYER.md). Run: run("assetplace/toppings_arc") or paste in the command bar.
local trailer = workspace.MAP01_Assets.Night_Trailer:FindFirstChild("TRL_AST-027_OpenLateTrailer")
	or workspace.MAP01_Assets.Night_Trailer:FindFirstChild("TRL-AST-027_OpenLateTrailer")
assert(trailer, "toppings_arc: trailer model not found")
local grid = trailer:FindFirstChild("TRL-K_AST-017_ToppingGrid")
local targets = trailer:FindFirstChild("PrepTargets")
assert(grid and targets, "toppings_arc: ToppingGrid or PrepTargets not found")

local layout = {
	{ Bin = "Bin_PotatoSticks", Target = "PT_Topping_potato_sticks", BinAt = Vector3.new(-54.5033, 3.8150, 16.3015), TargetAt = Vector3.new(-54.5033, 3.9425, 16.3015) },
	{ Bin = "Bin_CreamCheese", Target = "PT_Topping_cream_cheese", BinAt = Vector3.new(-49.2233, 3.2900, 14.5000), TargetAt = Vector3.new(-49.2233, 3.4175, 14.5000) },
	{ Bin = "Bin_Cheese", Target = "PT_Topping_cheese", BinAt = Vector3.new(-49.3733, 3.8021, 16.2700), TargetAt = Vector3.new(-49.3733, 4.0844, 16.2700) },
	{ Bin = "Bin_Ketchup", Target = "PT_Topping_ketchup", BinAt = Vector3.new(-52.8029, 3.7900, 16.3000), TargetAt = Vector3.new(-52.8029, 3.9175, 16.3000) },
	{ Bin = "Bin_Mustard", Target = "PT_Topping_mustard", BinAt = Vector3.new(-51.0733, 3.7900, 16.3000), TargetAt = Vector3.new(-51.0733, 3.9175, 16.3000) },
	{ Bin = "Bin_Bacon", Target = "PT_Topping_bacon", BinAt = Vector3.new(-54.7537, 3.2900, 14.5501), TargetAt = Vector3.new(-54.7537, 3.4175, 14.5501) },
}

local moved = 0
for _, row in layout do
	local bin = grid:FindFirstChild(row.Bin) :: BasePart
	local target = targets:FindFirstChild(row.Target) :: BasePart
	assert(bin and target, "toppings_arc: missing " .. row.Bin)
	local delta = row.BinAt - bin.Position
	if delta.Magnitude > 1e-3 then
		bin.CFrame += delta
		for _, child in bin:GetDescendants() do
			if child:IsA("BasePart") then
				child.CFrame += delta
			end
		end
		moved += 1
	end
	target.CFrame += row.TargetAt - target.Position
end

-- the white slab the plate sits on (front centre); replaces the old Base mesh
local board = grid:FindFirstChild("Board")
if board == nil then
	board = Instance.new("Part")
	board.Name = "Board"
	board.Anchored = true
	board.Size = Vector3.new(3.7767, 0.0673, 1.5)
	board.Color = Color3.fromRGB(248, 248, 248)
	board.Material = Enum.Material.Plastic
	board.Parent = grid
end
board.CFrame = CFrame.new(-51.9117, 3.1088, 14.45)
local base = grid:FindFirstChild("Base")
if base ~= nil then
	base:Destroy()
end
return `toppings_arc: {moved} bowls moved`
