--!strict
-- SeatingController/Tray: what a dirty Pad table shows (FEAT-037 "Ao levantar": tray + crumpled wrapper + tip coins;
-- TASK-147). Local only, never collides or blocks a prompt ray.
-- Model: a Model named TEMPLATE anywhere under ReplicatedStorage.Assets (TASK-153, pivot = centre of the tray bottom)
-- replaces the drawn tray automatically. Until it exists the tray is drawn here from primitives (Provisional, AST-082
-- has no coin mesh either): red plastic tray with a rim, crumpled paper wrapper, ketchup smear, soda cup with lid,
-- and 1..MAX_COINS flat Mustard coins beside it (one per diner's TableTip, never Gold: AST-082).
-- `at` = the tray anchor: Tray_Anchor of the table, else the centre of the table top (the caller decides).
-- Tray.Plate: the plate a served customer carries and puts on the table (restaurant, SitAt "Served"; TASK-387).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const TEMPLATE = "Table_Tray"
const MAX_COINS = 4
const PLATE_TEMPLATE = "Customer_Plate"
const PLATE_SIZE = 1.4 -- studs, drawn plate diameter
const PLATE_THICK = 0.08

-- Palette (style guide §2.1)
const KETCHUP = Color3.fromHex("#E2402E")
const KETCHUP_DARK = Color3.fromHex("#A8261B")
const MUSTARD = Color3.fromHex("#F6C12B")
const CREAM = Color3.fromHex("#FFF8EC")
const PAPER = Color3.fromHex("#F3E9D6")
const TEAL = Color3.fromHex("#3FA7A0")
const WHITE = Color3.fromHex("#FFFFFF")

const Tray = {}

local function part(model: Model, name: string, size: Vector3, color: Color3, frame: CFrame, shape: Enum.PartType?): Part
	const p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CFrame = frame
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Upright cylinder (Roblox cylinders run along X): height h, diameter d.
local function upright(model: Model, name: string, h: number, d: number, color: Color3, frame: CFrame): Part
	return part(model, name, Vector3.new(h, d, d), color, frame * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
end

local function template(): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(TEMPLATE, true) else nil
	return if found and found:IsA("Model") then found else nil
end

local function drawTray(model: Model, at: CFrame)
	const w, d, t, rim = 1.6, 1.1, 0.06, 0.1
	part(model, "Tray", Vector3.new(w, t, d), KETCHUP, at * CFrame.new(0, t / 2, 0))
	part(model, "RimN", Vector3.new(w, rim, 0.06), KETCHUP_DARK, at * CFrame.new(0, rim / 2, -d / 2 + 0.03))
	part(model, "RimS", Vector3.new(w, rim, 0.06), KETCHUP_DARK, at * CFrame.new(0, rim / 2, d / 2 - 0.03))
	part(model, "RimE", Vector3.new(0.06, rim, d), KETCHUP_DARK, at * CFrame.new(w / 2 - 0.03, rim / 2, 0))
	part(model, "RimW", Vector3.new(0.06, rim, d), KETCHUP_DARK, at * CFrame.new(-w / 2 + 0.03, rim / 2, 0))
	-- crumpled wrapper: two squashed paper balls
	part(
		model,
		"Wrapper",
		Vector3.new(0.5, 0.3, 0.42),
		PAPER,
		at * CFrame.new(-0.3, t + 0.13, 0.1) * CFrame.Angles(0.3, 0.6, 0.2),
		Enum.PartType.Ball
	)
	part(
		model,
		"WrapperFold",
		Vector3.new(0.32, 0.22, 0.3),
		CREAM,
		at * CFrame.new(-0.12, t + 0.12, -0.08) * CFrame.Angles(-0.4, 1.1, 0.3),
		Enum.PartType.Ball
	)
	-- ketchup smear
	upright(model, "Smear", 0.02, 0.28, KETCHUP_DARK, at * CFrame.new(0.15, t + 0.01, 0.25))
	-- soda cup with lid
	upright(model, "Cup", 0.5, 0.3, WHITE, at * CFrame.new(0.45, t + 0.25, -0.15))
	upright(model, "CupBand", 0.14, 0.31, TEAL, at * CFrame.new(0.45, t + 0.3, -0.15))
	upright(model, "Lid", 0.05, 0.32, KETCHUP, at * CFrame.new(0.45, t + 0.52, -0.15))
end

-- Coins beside the tray: one per TableTip of the tip on the table, 1..MAX_COINS.
local function drawCoins(model: Model, at: CFrame, tip: number, tableTip: number)
	if tip <= 0 then
		return
	end
	const count = math.clamp(math.ceil(tip / math.max(tableTip, 1)), 1, MAX_COINS)
	for index = 1, count do
		-- a small leaning stack beside the tray
		const offset = CFrame.new(1.05 + (index % 2) * 0.05, 0.04 + (index - 1) * 0.085, 0.25 - (index % 2) * 0.04)
		upright(model, `Coin{index}`, 0.08, 0.4, MUSTARD, at * offset * CFrame.Angles(0, index * 0.7, 0))
	end
end

-- The plate a served customer carries (restaurant, TASK-387; Meal.luau puts the hot dog on it). A Model named
-- PLATE_TEMPLATE under ReplicatedStorage.Assets (pivot = centre of the plate bottom, optional number attribute TopHeight)
-- replaces the drawn one (Provisional: white round plate with a teal band, no asset yet). Not parented, parts anchored;
-- returns the model (PrimaryPart set, pivot = centre of the bottom) and the height of its top over the pivot.
function Tray.Plate(): (Model, number)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const found = if assets then assets:FindFirstChild(PLATE_TEMPLATE, true) else nil
	if found ~= nil and found:IsA("Model") then
		const copy = found:Clone()
		const base = copy.PrimaryPart or copy:FindFirstChildWhichIsA("BasePart", true)
		if base ~= nil then
			const pivot = copy:GetPivot()
			copy.PrimaryPart = base
			base.PivotOffset = base.CFrame:ToObjectSpace(pivot)
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			end
			copy:PivotTo(CFrame.identity)
			const top = copy:GetAttribute("TopHeight")
			return copy, if typeof(top) == "number" then top else PLATE_THICK
		end
		copy:Destroy()
	end
	const model = Instance.new("Model")
	model.Name = "Seating_Plate"
	const base = upright(model, "Plate", PLATE_THICK, PLATE_SIZE, WHITE, CFrame.new(0, PLATE_THICK / 2, 0))
	upright(model, "Band", PLATE_THICK * 0.6, PLATE_SIZE + 0.08, TEAL, CFrame.new(0, PLATE_THICK * 0.3, 0))
	model.PrimaryPart = base
	base.PivotOffset = base.CFrame:Inverse() -- pivot = identity = centre of the bottom, Y up
	return model, PLATE_THICK
end

-- New tray model (not parented). `at` = anchor frame on the table top (Y up).
function Tray.Build(at: CFrame, tip: number, tableTip: number): Model
	const model = Instance.new("Model")
	model.Name = "Seating_Tray"
	const kit = template()
	if kit ~= nil then
		const copy = kit:Clone()
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		copy:PivotTo(at)
		copy.Parent = model
	else
		drawTray(model, at)
	end
	drawCoins(model, at, tip, tableTip)
	return model
end

return table.freeze(Tray)
