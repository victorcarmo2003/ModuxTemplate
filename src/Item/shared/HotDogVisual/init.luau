--!strict
--[[
	HotDogVisual (TASK-023; DEC-142; architecture.md §18.9.5). Pure shared module: no Modux, Lync, Vide or Charm.
	Called by ItemService on the server (the parts replicate); also usable on a client-side copy (vitrine, story).

	Rule (DEC-142):
	  - the 1st topping sits on Att_Topping1 of the hot_dog Handle (top of the sausage);
	  - every next one sits on the previous pivot + the previous TopHeight, along the up axis of Att_Topping1;
	  - cheese ("BeforeCords") always goes before the cords (ketchup, mustard, cream_cheese); the rest keeps the
	    assembly order. Visual only: the order itself has no order (DEC-071).

	Kit: ReplicatedStorage.Assets.Items.Toppings/<ingredient key> (Model, pivot = resting point, attribute TopHeight),
	built by tools/assetplace/build_items.luau (TASK-007).

	Drawn sauce (owner request 2026-10-14, Provisional): the Tool attribute `Sauce` (Sauce.luau, written by PrepService from the
	strokes of the 3D prep mode) replaces the stacked model of that sauce by the line the player drew: thin cylinders + round joints
	in the sauce colour, laid over the top of the stack. Bun space -> Handle space: X along the longest horizontal side of the Handle
	(BUN_LENGTH of it), Y across (BUN_WIDTH of the other side), on the up axis of Att_Topping1. A Tool without `Sauce` (the world
	prompts, an old snapshot) keeps the models.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.shared.Content)
local Sauce = require(script.Sauce)

const VISUAL_NAME = "ToppingVisual"
const ANCHOR_NAME = "Att_Topping1"
const SEPARATOR = ","
-- drawn sauce (Provisional, judged in Play): share of the Handle the bun-space square covers, bead width, lift over the stack
const BUN_LENGTH = 0.85
const BUN_WIDTH = 0.7
const BEAD = 0.05 -- share of the bun length
const BEAD_MIN = 0.04 -- studs
const SAUCE_LIFT = 0.35 -- beads over the top of the stack

local HotDogVisual = {}

HotDogVisual.VisualName = VISUAL_NAME
HotDogVisual.Sauce = Sauce

-- "ketchup,cheese" -> { "ketchup", "cheese" } (Tool attribute Toppings, assembly order; "" = none).
function HotDogVisual.parse(value: string?): { string }
	local out: { string } = {}
	if not value then
		return out
	end
	for key in string.gmatch(value, "[^" .. SEPARATOR .. "]+") do
		const trimmed = string.match(key, "^%s*(.-)%s*$") :: string
		if trimmed ~= "" then
			table.insert(out, trimmed)
		end
	end
	return out
end

-- Visual stacking order (DEC-142): every "BeforeCords" topping first, then the rest in assembly order.
function HotDogVisual.order(assembly: { string }): { string }
	local first: { string } = {}
	local rest: { string } = {}
	for _, key in assembly do
		const row = Content.Ingredients.ByKey[key]
		const stack = if row then row.Stack else nil
		table.insert(if stack == "BeforeCords" then first else rest, key)
	end
	for _, key in rest do
		table.insert(first, key)
	end
	return first
end

local function toppingKit(): Instance?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = assets and assets:FindFirstChild("Items")
	return items and items:FindFirstChild("Toppings")
end

-- Removes the stacked toppings from the Tool (or Model copy) of a hot dog.
function HotDogVisual.clear(hotDog: Instance)
	const old = hotDog:FindFirstChild(VISUAL_NAME)
	if old then
		old:Destroy()
	end
end

--[[
	Rebuilds the toppings of `hotDog` (Tool `hot_dog` or an anchored Model copy with a `Handle`), welded to the
	Handle. `toppings` = keys in assembly order or the raw `Toppings` attribute string. `kit` overrides the
	Assets.Items.Toppings folder (tests). Returns the keys that could not be placed (unknown or missing in the kit);
	an empty list = all placed.
]]
-- One straight bead (a cylinder along X) between two Handle-space points, welded like the topping parts
local function bead(visual: Instance, handle: BasePart, from: CFrame, to: Vector3, width: number, color: Color3, anchored: boolean, ball: boolean)
	const part = Instance.new("Part")
	part.Name = if ball then "SauceJoint" else "SauceBead"
	part.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Cylinder
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0.08
	part.Color = color
	part.CastShadow = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = anchored
	local offset: CFrame
	if ball then
		part.Size = Vector3.one * width
		offset = from
	else
		const a = from.Position
		const length = (to - a).Magnitude
		part.Size = Vector3.new(length + width * 0.5, width, width)
		-- a cylinder lies along its X axis: look along the bead, then turn X onto the look
		offset = CFrame.lookAt(a:Lerp(to, 0.5), to, from.UpVector) * CFrame.Angles(0, math.rad(90), 0)
	end
	part.CFrame = handle.CFrame * offset
	if not anchored then
		const weld = Instance.new("Weld")
		weld.Name = "ToppingWeld"
		weld.Part0 = handle
		weld.Part1 = part
		weld.C0 = offset
		weld.C1 = CFrame.identity
		weld.Parent = part
	end
	part.Parent = visual
end

-- The lines of the drawn sauces over the top of the stack (`top` = Handle space, up axis = Att_Topping1's)
local function drawSauces(visual: Instance, handle: BasePart, top: CFrame, sauces: { [string]: Sauce.Segments }, anchored: boolean)
	-- the bun's long side: the Handle axis with the largest size that is not the up axis
	const up = top.UpVector
	local along, alongSize, across, acrossSize = Vector3.xAxis, 0, Vector3.zAxis, 0
	for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		if math.abs(axis:Dot(up)) > 0.7 then
			continue
		end
		const size = math.abs(handle.Size:Dot(axis))
		if size > alongSize then
			across, acrossSize = along, alongSize
			along, alongSize = axis, size
		elseif size > acrossSize then
			across, acrossSize = axis, size
		end
	end
	const length = alongSize * BUN_LENGTH
	const width = acrossSize * BUN_WIDTH
	const thickness = math.max(length * BEAD, BEAD_MIN)
	const origin = top.Position + up * (thickness * SAUCE_LIFT)
	local function at(uv: Vector2): Vector3
		return origin + along * ((uv.X - 0.5) * length) + across * ((uv.Y - 0.5) * width)
	end
	for key, segments in sauces do
		const color = Sauce.ColorOf(key)
		const model = Instance.new("Model")
		model.Name = `Sauce_{key}`
		model:SetAttribute("Ingredient", key)
		for _, points in segments do
			for index = 1, #points do
				const here = at(points[index])
				const frame = CFrame.lookAt(here, here + along, up)
				bead(model, handle, frame, here, thickness, color, anchored, true)
				if index > 1 then
					const back = at(points[index - 1])
					bead(model, handle, CFrame.lookAt(back, back + along, up), here, thickness, color, anchored, false)
				end
			end
		end
		model.Parent = visual
	end
end

function HotDogVisual.apply(hotDog: Instance, toppings: { string } | string, kit: Instance?): { string }
	HotDogVisual.clear(hotDog)
	const missing: { string } = {}
	const keys = HotDogVisual.order(if type(toppings) == "string" then HotDogVisual.parse(toppings) else toppings)
	if #keys == 0 then
		return missing
	end
	-- the sauces the player drew (Tool attribute Sauce) are lines, not models; only for toppings that are on the hot dog
	const drawn: { [string]: Sauce.Segments } = {}
	local anyDrawn = false
	for key, segments in Sauce.Decode(hotDog:GetAttribute(Sauce.Attribute)) do
		if table.find(keys, key) then
			drawn[key] = segments
			anyDrawn = true
		end
	end

	const handle = hotDog:FindFirstChild("Handle")
	const anchor = handle and handle:FindFirstChild(ANCHOR_NAME)
	if not (handle and handle:IsA("BasePart") and anchor and anchor:IsA("Attachment")) then
		warn(`HotDogVisual: {hotDog:GetFullName()} has no Handle.{ANCHOR_NAME}`)
		return keys
	end
	const source = kit or toppingKit()
	if not source then
		warn("HotDogVisual: ReplicatedStorage.Assets.Items.Toppings missing (run build_items.luau)")
		return keys
	end

	const anchored = handle.Anchored
	const visual = Instance.new("Model")
	visual.Name = VISUAL_NAME

	-- cursor in Handle space: the up axis of Att_Topping1 carries the whole stack
	local cursor = anchor.CFrame
	for _, key in keys do
		if drawn[key] ~= nil then
			continue
		end
		const template = source:FindFirstChild(key)
		if not (template and template:IsA("Model")) then
			table.insert(missing, key)
			continue
		end
		const pivot = template:GetPivot()
		const copy = template:Clone()
		copy:SetAttribute("Ingredient", key)
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				const offset = cursor * pivot:ToObjectSpace(d.CFrame) -- Handle space
				d.Anchored = anchored
				d.Massless = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CFrame = handle.CFrame * offset
				if not anchored then
					-- Weld (not WeldConstraint): offset fixed by C0, independent of where the Handle is right now
					const weld = Instance.new("Weld")
					weld.Name = "ToppingWeld"
					weld.Part0 = handle
					weld.Part1 = d
					weld.C0 = offset
					weld.C1 = CFrame.identity
					weld.Parent = d
				end
			end
		end
		copy.Parent = visual
		const height = template:GetAttribute("TopHeight")
		if type(height) == "number" then
			cursor *= CFrame.new(0, height, 0)
		else
			warn(`HotDogVisual: Toppings.{key} has no TopHeight`)
		end
	end
	if anyDrawn then
		drawSauces(visual, handle, cursor, drawn, anchored)
	end
	visual.Parent = hotDog
	return missing
end

-- Same as apply, reading the Tool attribute `Toppings`.
function HotDogVisual.refresh(hotDog: Instance, kit: Instance?): { string }
	const value = hotDog:GetAttribute("Toppings")
	return HotDogVisual.apply(hotDog, if type(value) == "string" then value else "", kit)
end

return HotDogVisual
