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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Content = require(ReplicatedStorage.shared.Content)

const VISUAL_NAME = "ToppingVisual"
const ANCHOR_NAME = "Att_Topping1"
const SEPARATOR = ","

local HotDogVisual = {}

HotDogVisual.VisualName = VISUAL_NAME

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
function HotDogVisual.apply(hotDog: Instance, toppings: { string } | string, kit: Instance?): { string }
	HotDogVisual.clear(hotDog)
	const missing: { string } = {}
	const keys = HotDogVisual.order(if type(toppings) == "string" then HotDogVisual.parse(toppings) else toppings)
	if #keys == 0 then
		return missing
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
	visual.Parent = hotDog
	return missing
end

-- Same as apply, reading the Tool attribute `Toppings`.
function HotDogVisual.refresh(hotDog: Instance, kit: Instance?): { string }
	const value = hotDog:GetAttribute("Toppings")
	return HotDogVisual.apply(hotDog, if type(value) == "string" then value else "", kit)
end

return HotDogVisual
