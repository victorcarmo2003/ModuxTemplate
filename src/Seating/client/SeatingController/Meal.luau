--!strict
-- SeatingController/Meal: a seated diner eats (FEAT-037 "Come o hot dog que recebeu"; network.md §14.3; TASK-147).
-- Local only. While a server rig has the `Seated` attribute (table index, written by SeatingService/Diner) it sits
-- (`npc_sit` loops when it has an Id) and WAITS with empty hands (Q-209: the order is served at the table). Once the
-- server also writes `Eating` = true (the food was served) it eats:
--   * a hot dog in its right hand: a clone of the kit Tool ReplicatedStorage.Assets.Items.Tools.hot_dog (AST-003)
--     held like a Tool (R6 RightGrip frame x Tool.Grip), welded to the "Right Arm"; plain bun + sausage drawn here
--     while the kit is missing. The server pose (shoulders at +-90 by Motor6D.C0) puts the hand over the table; the
--     hot dog is welded SETTLE s after `Seated` shows up, so the replicated pose is already on the arm;
--   * a bite every BITE_EVERY s: the hot dog shrinks one step around the handle (hand weld off while scaling, so the
--     arm never moves; BITES steps, the last one eats it), and the clip `npc_eat_seated` plays when it has an Id;
--     `npc_sit` loops while seated when it has an Id (AnimController plays nothing for an empty Id, so this is free
--     until TASK-151 brings the clips).
-- Cleared when `Seated` goes nil, the rig leaves the Workspace or is destroyed.
--
-- Carried plate (restaurant, TASK-387; restaurant-flow.md §3.1 "Depois de servido"): while the rig has `Carrying` = true
-- (CustomerService, served at the pickup) it walks with a plate (Tray.Plate) + the hot dog of its order on it
-- (HotDogVisual, toppings from Hooks.Toppings), held in front of the torso. When it sits (`Seated`) the plate is put on
-- the table in front of it (between the seat and Hooks.TableTop), and when it eats the hot dog goes from the plate to the
-- hand (same bites as above, with its toppings); the empty plate stays until it stands up, then it walks out empty-handed.
-- Takeaway (no table): it never sits, so it walks out with the plate. `Carrying` nil (record gone, rig back to the pool)
-- clears it all. Without `Carrying` (trailer, SitAt "Order") nothing here changes. Visual only: the server decides.
-- THE hot dog handed over (owner 2026-10-19): with the rig attribute CarryToppings (CustomerService:SetCarrying, from the
-- served Tool) the carried and eaten hot dog is that one: its toppings, the sauce lines the player drew (CarrySauce ->
-- the model's Sauce attribute, HotDogVisual draws them) and, with CarryDish, the kit plate's dish under it (as on the Tool;
-- the empty dish stays on the table). CarryAltered is kept on the model (Altered). Without CarryToppings: the order's
-- toppings on the drawn plate, as before.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)
local Tray = require(script.Parent.Tray)

const SEATED_ATTRIBUTE = "Seated"
const EATING_ATTRIBUTE = "Eating"
const CARRYING_ATTRIBUTE = "Carrying"
-- rig attributes of the served hot dog's look (CustomerService CARRY_LOOK)
const CARRY_TOPPINGS = "CarryToppings"
const CARRY_SAUCE = "CarrySauce"
const CARRY_ALTERED = "CarryAltered"
const CARRY_DISH = "CarryDish"
const TOOL_NAME = "hot_dog"
const ARM = "Right Arm"
const BITES = 3
const BITE_EVERY = 6 -- s (EatTime 20-24 s: 3 bites, the last one just before standing up)
const BITE_SCALE = 0.8
const SETTLE = 0.25 -- s after `Seated` before the hot dog is put in the hand
-- R6 RightGrip C0 (what the engine uses for a held Tool)
const GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
const BUN = Color3.fromHex("#E8B36B")
const SAUSAGE = Color3.fromHex("#B5482E")
const TOPPING_ANCHOR = "Att_Topping1" -- HotDogVisual: the up axis of the stack
-- carried plate (Provisional, judged in Play): in torso space, a little under the chest and in front of it
const HOLD_DROP = 0.3 -- share of the torso height under its centre
const HOLD_AHEAD = 0.55 -- studs in front of the torso face
const REACH = 1.4 -- studs from the seated root towards the table centre where the plate lands (at most)
const REACH_SHARE = 0.75 -- ... and at most this share of the way to the centre

export type Anim = {
	Play: (model: Model, key: string, looped: boolean) -> (),
	Stop: (model: Model, key: string) -> (),
}

-- What the controller knows that this module does not (TASK-387).
export type Hooks = {
	Toppings: (rig: Model) -> { string }, -- topping keys of the order the rig carries ({} = plain)
	TableTop: (index: number) -> CFrame?, -- table top centre (Y up), nil = table not bound
}

-- How the carried / eaten hot dog looks (TASK-387; owner 2026-10-19).
type Look = {
	Toppings: { string },
	Sauce: string?, -- HotDogVisual.Sauce wire of the drawn lines
	Altered: boolean,
	Dish: boolean, -- under it the kit plate's dish (the Tool's Dish)
}

type Diner = {
	Eating: boolean,
	Food: Model?,
	Grip: WeldConstraint?, -- hand weld (arm -> handle)
	Thread: thread?,
}

-- Plate of a rig with `Carrying` (TASK-387).
type Carry = {
	Model: Model?, -- plate (+ Food on it)
	Food: Model?, -- hot dog on the plate
	Hold: WeldConstraint?, -- torso -> plate while it walks
	OnTable: boolean,
	Seated: boolean, -- it sat with the plate: standing up again = done
	Done: boolean, -- ate at a table: walks out empty-handed until `Carrying` goes
}

const Meal = {}
Meal.__index = Meal

export type Meal = typeof(setmetatable(
	{} :: {
		Anim: Anim,
		Hooks: Hooks?,
		Diners: { [Model]: Diner },
		Carries: { [Model]: Carry },
		Tracked: { [Model]: { RBXScriptConnection } },
		Warned: boolean,
	},
	Meal
))

function Meal.new(anim: Anim, hooks: Hooks?): Meal
	return setmetatable({ Anim = anim, Hooks = hooks, Diners = {}, Carries = {}, Tracked = {}, Warned = false }, Meal)
end

local function quiet(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

-- Hand hot dog from the kit Tool: its parts in a Model, primary = Handle, plus the Tool grip.
function Meal.KitFood(self: Meal): (Model?, CFrame)
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const tool = if tools then tools:FindFirstChild(TOOL_NAME) else nil
	if tool == nil or not tool:IsA("Tool") then
		if not self.Warned then
			self.Warned = true
			warn(`[SeatingController] Assets.Items.Tools.{TOOL_NAME} missing: diners hold a drawn hot dog`)
		end
		return nil, CFrame.identity
	end
	const copy = tool:Clone()
	const model = Instance.new("Model")
	model.Name = "Seating_Meal"
	for _, child in copy:GetChildren() do
		if not child:IsA("LuaSourceContainer") then
			child.Parent = model
		end
	end
	copy:Destroy()
	const handle = model:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		model:Destroy()
		return nil, CFrame.identity
	end
	model.PrimaryPart = handle
	return model, tool.Grip
end

-- Drawn fallback: bun + sausage, centred on the hand.
local function drawnFood(): (Model, CFrame)
	const model = Instance.new("Model")
	model.Name = "Seating_Meal"
	const bun = Instance.new("Part")
	bun.Name = "Handle"
	bun.Size = Vector3.new(0.4, 0.3, 1)
	bun.Color = BUN
	bun.Material = Enum.Material.SmoothPlastic
	bun.Parent = model
	const sausage = Instance.new("Part")
	sausage.Name = "Sausage"
	sausage.Shape = Enum.PartType.Cylinder
	sausage.Size = Vector3.new(1.15, 0.22, 0.22)
	sausage.Color = SAUSAGE
	sausage.Material = Enum.Material.SmoothPlastic
	sausage.CFrame = bun.CFrame * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0)
	sausage.Parent = model
	model.PrimaryPart = bun
	return model, CFrame.identity
end

-- A hot dog model (kit or drawn) looking like `look` (toppings and drawn sauce by HotDogVisual; kit only: the drawn one
-- has no anchor). Parts anchored, not parented; returns the model and its Tool grip.
function Meal.Food(self: Meal, look: Look?): (Model, CFrame)
	local food, grip = self:KitFood()
	if food == nil then
		food, grip = drawnFood()
	end
	const model = food :: Model
	const handle = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	const toppings = if look then look.Toppings else nil
	if look ~= nil then
		model:SetAttribute(HotDogVisual.Sauce.Attribute, look.Sauce)
		model:SetAttribute("Altered", if look.Altered then true else nil)
	end
	if toppings ~= nil and #toppings > 0 and handle:FindFirstChild(TOPPING_ANCHOR) ~= nil then
		const ok, err = pcall(HotDogVisual.apply, model, toppings, nil)
		if not ok then
			warn(`[SeatingController] HotDogVisual.apply failed: {err}`)
		end
	end
	return model, grip
end

-- Every part of `model` loose (no collision, massless) and welded to `root`.
local function weldAll(model: Model, root: BasePart)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			quiet(descendant)
			if descendant ~= root then
				const inner = Instance.new("WeldConstraint")
				inner.Part0 = root
				inner.Part1 = descendant
				inner.Parent = descendant
			end
		end
	end
end

function Meal.Give(self: Meal, rig: Model, look: Look?): (Model?, WeldConstraint?)
	const arm = rig:FindFirstChild(ARM)
	if arm == nil or not arm:IsA("BasePart") then
		return nil, nil
	end
	const model, grip = self:Food(look)
	const handle = model.PrimaryPart :: BasePart
	model:PivotTo(arm.CFrame * GRIP * grip:Inverse())
	weldAll(model, handle)
	const weld = Instance.new("WeldConstraint")
	weld.Part0 = arm
	weld.Part1 = handle
	weld.Parent = handle
	model.Parent = rig
	return model, weld
end

-- One bite: smaller around the handle (the hand weld is off meanwhile, so the arm never moves), or gone.
local function bite(diner: Diner, last: boolean)
	const food = diner.Food
	if food == nil or food.Parent == nil then
		return
	end
	if last then
		food:Destroy()
		diner.Food = nil
		return
	end
	const grip = diner.Grip
	if grip ~= nil then
		grip.Enabled = false
	end
	food:ScaleTo(food:GetScale() * BITE_SCALE)
	if grip ~= nil then
		grip.Enabled = true
	end
end

-- Carried plate ---------------------------------------------------------------------------------------------------

function Meal.ToppingsOf(self: Meal, rig: Model): { string }
	const hooks = self.Hooks
	if hooks == nil then
		return {}
	end
	const ok, keys = pcall(hooks.Toppings, rig)
	return if ok and type(keys) == "table" then keys else {}
end

-- The served hot dog's look (rig Carry* attributes), else the order's toppings on a plain hot dog.
function Meal.LookOf(self: Meal, rig: Model): Look
	const toppings = rig:GetAttribute(CARRY_TOPPINGS)
	if type(toppings) ~= "string" then
		return { Toppings = self:ToppingsOf(rig), Sauce = nil, Altered = false, Dish = false }
	end
	const sauce = rig:GetAttribute(CARRY_SAUCE)
	return {
		Toppings = HotDogVisual.parse(toppings),
		Sauce = if type(sauce) == "string" then sauce else nil,
		Altered = rig:GetAttribute(CARRY_ALTERED) == true,
		Dish = rig:GetAttribute(CARRY_DISH) == true,
	}
end

-- The kit plate's dish (Assets.Items.Tools.plate) under `handle`, as KitchenService attachDish puts it on the Tool: its top
-- (kit Handle +Y) meets the bottom of the hot dog Handle. Anchored parts into `into`; returns the dish base (nil = no kit).
local function dishUnder(handle: BasePart, into: Model): BasePart?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const tools = if items then items:FindFirstChild("Tools") else nil
	const kit = if tools then tools:FindFirstChild(PlateTool.Plate) else nil
	const kitHandle = if kit then kit:FindFirstChild("Handle") else nil
	if kit == nil or kitHandle == nil or not kitHandle:IsA("BasePart") then
		return nil
	end
	const base = handle.CFrame * CFrame.new(0, -handle.Size.Y / 2, 0)
	const kitTop = kitHandle.CFrame * CFrame.new(0, kitHandle.Size.Y / 2, 0)
	local dishBase: BasePart? = nil
	for _, part in kit:GetDescendants() do
		if part:IsA("BasePart") then
			const copy = part:Clone()
			for _, child in copy:GetChildren() do
				if not child:IsA("DataModelMesh") and not child:IsA("SurfaceAppearance") and not child:IsA("Decal") then
					child:Destroy()
				end
			end
			copy.Name = if part == kitHandle then "DishBase" else part.Name
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CFrame = base * kitTop:ToObjectSpace(part.CFrame)
			copy.Parent = into
			if part == kitHandle then
				dishBase = copy
			end
		end
	end
	return dishBase
end

-- Handle frame that lays the hot dog on `top` (Y up): the stack's up axis (Att_Topping1) up, resting on its side.
local function lay(handle: BasePart, top: CFrame): CFrame
	const anchor = handle:FindFirstChild(TOPPING_ANCHOR)
	const turn = if anchor ~= nil and anchor:IsA("Attachment") then anchor.CFrame.Rotation else CFrame.identity
	const up = turn.UpVector -- handle space
	const size = handle.Size
	const half = 0.5 * (math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z)
	return top * CFrame.new(0, half, 0) * turn:Inverse()
end

-- `food` laid on what it is carried on: the Tool's dish (with `dish`, built under it), else the drawn plate (Tray.Plate).
-- Pivot = centre of the bottom, Y up (Land puts it on the table). Returns the model and its base part.
local function carried(food: Model, dish: boolean): (Model, BasePart)
	const handle = food.PrimaryPart :: BasePart
	if dish then
		food:PivotTo(lay(handle, CFrame.identity))
		const model = Instance.new("Model")
		const dishBase = dishUnder(handle, model)
		if dishBase ~= nil then
			local bottom = math.huge
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") then
					bottom = math.min(bottom, part.Position.Y - part.Size.Y / 2)
				end
			end
			const centre = dishBase.Position
			model.PrimaryPart = dishBase
			dishBase.PivotOffset = dishBase.CFrame:ToObjectSpace(CFrame.new(centre.X, bottom, centre.Z))
			food.Parent = model
			return model, dishBase
		end
		model:Destroy()
	end
	const plate, topHeight = Tray.Plate()
	food:PivotTo(lay(handle, CFrame.new(0, topHeight, 0)))
	food.Parent = plate
	return plate, plate.PrimaryPart :: BasePart
end

-- Plate + hot dog in front of the torso (walking to the table, or takeaway).
function Meal.Hold(self: Meal, rig: Model, carry: Carry)
	const torso = rig:FindFirstChild("Torso") or rig:FindFirstChild("HumanoidRootPart")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	const look = self:LookOf(rig)
	const food = self:Food(look)
	const plate, base = carried(food, look.Dish)
	plate.Name = "Seating_Carry"
	-- level in torso space (the torso stays upright while it walks)
	plate:PivotTo(torso.CFrame * CFrame.new(0, -torso.Size.Y * HOLD_DROP, -(torso.Size.Z / 2 + HOLD_AHEAD)))
	weldAll(plate, base)
	const hold = Instance.new("WeldConstraint")
	hold.Part0 = torso
	hold.Part1 = base
	hold.Parent = base
	plate.Parent = rig
	carry.Model = plate
	carry.Food = food
	carry.Hold = hold
	carry.OnTable = false
end

-- Seated with the plate: it goes on the table, between the diner and the table centre. Idempotent.
function Meal.Land(self: Meal, rig: Model)
	const carry = self.Carries[rig]
	const hooks = self.Hooks
	const seated = rig:GetAttribute(SEATED_ATTRIBUTE)
	if carry == nil or carry.OnTable or carry.Model == nil or hooks == nil or typeof(seated) ~= "number" then
		return
	end
	const plate = carry.Model :: Model
	const root = rig:FindFirstChild("HumanoidRootPart")
	const top = hooks.TableTop(seated)
	if top == nil or root == nil or not root:IsA("BasePart") then
		return -- no bound table: the plate stays in the hands
	end
	const centre = top.Position
	const from = Vector3.new(root.Position.X, centre.Y, root.Position.Z)
	const toward = centre - from
	const distance = toward.Magnitude
	const at = if distance > 1e-3 then from + toward.Unit * math.min(REACH, distance * REACH_SHARE) else centre
	if carry.Hold ~= nil then
		carry.Hold:Destroy()
		carry.Hold = nil
	end
	const flat = if distance > 1e-3 then toward.Unit else top.LookVector
	plate:PivotTo(CFrame.lookAt(at, at + flat))
	for _, descendant in plate:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	carry.OnTable = true
end

-- The hot dog leaves the plate (it goes to the hand).
local function takeFood(carry: Carry?)
	if carry ~= nil and carry.Food ~= nil then
		carry.Food:Destroy()
		carry.Food = nil
	end
end

function Meal.ClearCarry(_self: Meal, carry: Carry)
	if carry.Model ~= nil then
		carry.Model:Destroy()
	end
	carry.Model = nil
	carry.Food = nil
	carry.Hold = nil
	carry.OnTable = false
end

function Meal.DropCarry(self: Meal, rig: Model)
	const carry = self.Carries[rig]
	if carry ~= nil then
		self.Carries[rig] = nil
		self:ClearCarry(carry)
	end
end

function Meal.RefreshCarry(self: Meal, rig: Model)
	if rig:GetAttribute(CARRYING_ATTRIBUTE) ~= true or not rig:IsDescendantOf(workspace) then
		self:DropCarry(rig)
		return
	end
	local carry = self.Carries[rig]
	if carry == nil then
		const created: Carry = { Model = nil, Food = nil, Hold = nil, OnTable = false, Seated = false, Done = false }
		self.Carries[rig] = created
		carry = created
	end
	const state = carry :: Carry
	if state.Done then
		return
	end
	if typeof(rig:GetAttribute(SEATED_ATTRIBUTE)) == "number" then
		state.Seated = true
		if state.Model == nil then
			self:Hold(rig, state) -- late join: Land / Eat put it on the table after SETTLE
		end
	elseif state.Seated then
		-- stood up from the table: the plate stays behind, it walks out empty-handed
		state.Done = true
		self:ClearCarry(state)
	elseif state.Model == nil then
		self:Hold(rig, state)
	end
end

-- Seat ------------------------------------------------------------------------------------------------------------

function Meal.Sit(self: Meal, rig: Model)
	if self.Diners[rig] ~= nil then
		return
	end
	const diner: Diner = { Eating = false, Food = nil, Grip = nil, Thread = nil }
	self.Diners[rig] = diner
	self.Anim.Play(rig, "npc_sit", true)
	if self.Carries[rig] ~= nil then
		task.delay(SETTLE, function()
			if self.Diners[rig] == diner then
				self:Land(rig)
			end
		end)
	end
end

-- The food arrived: the hot dog goes into the hand and the bites start.
function Meal.Eat(self: Meal, rig: Model)
	const diner = self.Diners[rig]
	if diner == nil or diner.Eating then
		return
	end
	diner.Eating = true
	diner.Thread = task.spawn(function()
		task.wait(SETTLE)
		if self.Diners[rig] ~= diner then
			return
		end
		const carry = self.Carries[rig]
		local look: Look? = nil
		if carry ~= nil then
			-- carried plate (TASK-387): it lands on the table and the hot dog handed over goes to the hand
			self:Land(rig)
			takeFood(carry)
			look = self:LookOf(rig)
		end
		diner.Food, diner.Grip = self:Give(rig, look)
		for count = 1, BITES do
			task.wait(BITE_EVERY)
			if self.Diners[rig] ~= diner then
				return
			end
			self.Anim.Play(rig, "npc_eat_seated", false)
			bite(diner, count >= BITES)
		end
	end)
end

function Meal.Stand(self: Meal, rig: Model)
	const diner = self.Diners[rig]
	if diner == nil then
		return
	end
	self.Diners[rig] = nil
	const thread = diner.Thread
	if thread ~= nil and coroutine.running() ~= thread and coroutine.status(thread) == "suspended" then
		task.cancel(thread)
	end
	if diner.Food ~= nil then
		diner.Food:Destroy()
	end
	self.Anim.Stop(rig, "npc_sit")
end

function Meal.Refresh(self: Meal, rig: Model)
	self:RefreshCarry(rig)
	const seated = rig:GetAttribute(SEATED_ATTRIBUTE)
	if typeof(seated) == "number" and rig:IsDescendantOf(workspace) then
		self:Sit(rig)
		if rig:GetAttribute(EATING_ATTRIBUTE) == true then
			self:Eat(rig)
		end
	else
		self:Stand(rig)
	end
end

function Meal.Track(self: Meal, instance: Instance)
	if not instance:IsA("Model") or self.Tracked[instance] ~= nil then
		return
	end
	const rig = instance
	local function refresh()
		self:Refresh(rig)
	end
	self.Tracked[rig] = {
		rig:GetAttributeChangedSignal(SEATED_ATTRIBUTE):Connect(refresh),
		rig:GetAttributeChangedSignal(EATING_ATTRIBUTE):Connect(refresh),
		rig:GetAttributeChangedSignal(CARRYING_ATTRIBUTE):Connect(refresh),
		rig.AncestryChanged:Connect(refresh),
		rig.Destroying:Connect(function()
			self:Untrack(rig)
		end),
	}
	refresh()
end

function Meal.Untrack(self: Meal, instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const connections = self.Tracked[instance]
	if connections == nil then
		return
	end
	self.Tracked[instance] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
	self:Stand(instance)
	self:DropCarry(instance)
end

return Meal
