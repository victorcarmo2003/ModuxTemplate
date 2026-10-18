--[[
	build_restaurant_items.luau — the three restaurant kit Tools that were never built (Content.Items ITM-022..024;
	tech/restaurant-flow.md rev. 2 §4.2). EDIT MODE ONLY: Command Bar or Studio MCP. Not gameplay code.

	Without them ItemService:Give refuses ("no kit Tool for bun_sliced"), so a cut bun / grilled sausage never reaches
	the hand and the assembly table has nothing to receive (owner 2026-10-18: "a mesa de trabalho não funciona").

	Builds ONLY these children of ReplicatedStorage.Assets.Items.Tools (replaces them if present, leaves the rest):
	  bun_sliced       from Assets.Items.Food.BunOpen (AST-001)
	  sausage_grilled  from Assets.Items.Food.SausageGrilled (AST-002)
	  stock_box        Provisional cardboard box (one Part, brown), attribute Package / Count are set by the server
	Same conventions as build_items.luau: Handle + welded parts, unanchored, Massless, no collision/touch/query,
	CanBeDropped false, Grip = base centre (item upright, front -Z), Att_Hand, attribute Item / Asset.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local items = ReplicatedStorage.Assets.Items
local tools = items.Tools
local food = items.Food

local function finish(tool, handle, parts, asset)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Asset", asset)
	handle.Name = "Handle"
	for _, p in parts do
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = tool
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = handle
		end
	end
	-- grip: base centre of the whole item, in the handle's space
	local cf, size = (function()
		local m = Instance.new("Model")
		for _, p in parts do
			p:Clone().Parent = m
		end
		local a, b = m:GetBoundingBox()
		m:Destroy()
		return a, b
	end)()
	local base = cf * CFrame.new(0, -size.Y / 2, 0)
	local grip = CFrame.new(handle.CFrame:PointToObjectSpace(base.Position))
	tool.Grip = grip
	local att = Instance.new("Attachment")
	att.Name = "Att_Hand"
	att.CFrame = grip
	att.Parent = handle
end

local function fromFood(key, modelName, asset)
	local source = food:FindFirstChild(modelName)
	assert(source and source:IsA("Model"), "Assets.Items.Food." .. modelName .. " missing (run build_items.luau first)")
	local copy = source:Clone()
	local parts = {}
	local handle
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if handle == nil or d.Size.Magnitude > handle.Size.Magnitude then
				handle = d
			end
		end
	end
	assert(handle, modelName .. " has no parts")
	local tool = Instance.new("Tool")
	tool.Name = key
	tool:SetAttribute("Item", key)
	finish(tool, handle, parts, asset)
	copy:Destroy()
	return tool
end

local function stockBox()
	local tool = Instance.new("Tool")
	tool.Name = "stock_box"
	tool:SetAttribute("Item", "stock_box")
	local box = Instance.new("Part")
	box.Size = Vector3.new(1.4, 0.9, 1.1)
	box.Color = Color3.fromRGB(176, 128, 84)
	box.Material = Enum.Material.Cardboard
	box.CFrame = CFrame.new()
	local tape = Instance.new("Part")
	tape.Name = "Tape"
	tape.Size = Vector3.new(0.25, 0.92, 1.12)
	tape.Color = Color3.fromRGB(214, 196, 160)
	tape.Material = Enum.Material.SmoothPlastic
	tape.CFrame = CFrame.new()
	finish(tool, box, { box, tape }, "ITM-024_StockBox (Provisional)")
	return tool
end

local built = {
	fromFood("bun_sliced", "BunOpen", "AST-001_Bun"),
	fromFood("sausage_grilled", "SausageGrilled", "AST-002_Sausage"),
	stockBox(),
}
for _, tool in built do
	local old = tools:FindFirstChild(tool.Name)
	if old then
		old:Destroy()
	end
	tool.Parent = tools
end
print("[build_restaurant_items] built bun_sliced, sausage_grilled, stock_box")
