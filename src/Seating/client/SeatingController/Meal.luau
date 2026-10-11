--!strict
-- SeatingController/Meal: a seated diner eats (FEAT-037 "Come o hot dog que recebeu"; network.md §14.3; TASK-147).
-- Local only. While a server rig has the `Seated` attribute (table index, written by SeatingService/Diner):
--   * a hot dog in its right hand: a clone of the kit Tool ReplicatedStorage.Assets.Items.Tools.hot_dog (AST-003)
--     held like a Tool (R6 RightGrip frame x Tool.Grip), welded to the "Right Arm"; plain bun + sausage drawn here
--     while the kit is missing. The server pose (shoulders at +-90 by Motor6D.C0) puts the hand over the table; the
--     hot dog is welded SETTLE s after `Seated` shows up, so the replicated pose is already on the arm;
--   * a bite every BITE_EVERY s: the hot dog shrinks one step around the handle (hand weld off while scaling, so the
--     arm never moves; BITES steps, the last one eats it), and the clip `npc_eat_seated` plays when it has an Id;
--     `npc_sit` loops while seated when it has an Id (AnimController plays nothing for an empty Id, so this is free
--     until TASK-151 brings the clips).
-- Cleared when `Seated` goes nil, the rig leaves the Workspace or is destroyed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const SEATED_ATTRIBUTE = "Seated"
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

export type Anim = {
	Play: (model: Model, key: string, looped: boolean) -> (),
	Stop: (model: Model, key: string) -> (),
}

type Diner = {
	Food: Model?,
	Grip: WeldConstraint?, -- hand weld (arm -> handle)
	Thread: thread?,
}

const Meal = {}
Meal.__index = Meal

export type Meal = typeof(setmetatable(
	{} :: {
		Anim: Anim,
		Diners: { [Model]: Diner },
		Tracked: { [Model]: { RBXScriptConnection } },
		Warned: boolean,
	},
	Meal
))

function Meal.new(anim: Anim): Meal
	return setmetatable({ Anim = anim, Diners = {}, Tracked = {}, Warned = false }, Meal)
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

function Meal.Give(self: Meal, rig: Model): (Model?, WeldConstraint?)
	const arm = rig:FindFirstChild(ARM)
	if arm == nil or not arm:IsA("BasePart") then
		return nil, nil
	end
	local food, grip = self:KitFood()
	if food == nil then
		food, grip = drawnFood()
	end
	const model = food :: Model
	const handle = model.PrimaryPart :: BasePart
	model:PivotTo(arm.CFrame * GRIP * grip:Inverse())
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			quiet(descendant)
			if descendant ~= handle then
				const inner = Instance.new("WeldConstraint")
				inner.Part0 = handle
				inner.Part1 = descendant
				inner.Parent = descendant
			end
		end
	end
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

function Meal.Sit(self: Meal, rig: Model)
	if self.Diners[rig] ~= nil then
		return
	end
	const diner: Diner = { Food = nil, Grip = nil, Thread = nil }
	self.Diners[rig] = diner
	self.Anim.Play(rig, "npc_sit", true)
	diner.Thread = task.spawn(function()
		task.wait(SETTLE)
		if self.Diners[rig] ~= diner then
			return
		end
		diner.Food, diner.Grip = self:Give(rig)
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
	const seated = rig:GetAttribute(SEATED_ATTRIBUTE)
	if typeof(seated) == "number" and rig:IsDescendantOf(workspace) then
		self:Sit(rig)
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
end

return Meal
