--!strict
-- World/ToolView: the tool of the topping in the hand (docs/tech/prep-3d.md §2.6, §3.4; TASK-205). One at a time, a spring follows
-- the pointer (no physics): the bottle leans and its sauce level (`Fill`) drops as it pours; the slice, the strip and the pinch are
-- the kit's own topping models (Assets.Items.Toppings: cheese, bacon, potato_sticks) that sway as they are carried.
--   Bottle  PLACEHOLDER made of Parts (Provisional: AST-004 / AST-005 are not importable as a tool yet; TASK-201 / 202 model the real
--           ones, the pivot is the nozzle). Ketchup, mustard and cream cheese differ by the colour of the sauce AND the cap shape
--           (round, flat, tall), never by colour alone.
-- Everything lives under the PrepWorld folder; Destroy removes it. No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Kind = "None" | "Bottle" | "Slice" | "Strip" | "Pinch"

export type Tool = {
	-- The tool in hand: kind and the topping key (nil kind = empty hand).
	Set: (self: Tool, kind: Kind, key: string) -> (),
	Kind: (self: Tool) -> Kind,
	Key: (self: Tool) -> string,
	-- Where it is: a world point on the work plane (nil = hidden); `pour` = the bottle is squeezing; `sway` = side velocity -1..1.
	Move: (self: Tool, point: Vector3?, pour: boolean, sway: number) -> (),
	-- The nozzle of the bottle in the world (the sauce comes out here), or the centre of the thing carried.
	Tip: (self: Tool) -> Vector3,
	-- Sauce level 0..1 of the bottle.
	SetFill: (self: Tool, fill: number) -> (),
	Step: (self: Tool, dt: number) -> (),
	Destroy: (self: Tool) -> (),
}

const ToolView = {}

const SAUCE: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cream_cheese = Color3.fromHex("#FFF8EA"),
}

type PartSpec = { Part: Part, Local: CFrame }

local function newPart(shape: Enum.PartType, size: Vector3, color: Color3, alpha: number): Part
	const part = Instance.new("Part")
	part.Shape = shape
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.Transparency = alpha
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function kitModel(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const folder = if items then items:FindFirstChild("Toppings") else nil
	const model = if folder then folder:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- `orient` = the axes of the board (X = screen right), so the lean is toward the right of the screen.
function ToolView.new(folder: Folder, rules: Content.PrepWorldRules, orient: CFrame): Tool
	const board = rules.Board
	const look = rules.Toppings
	const scale = board.Scale
	local kind: Kind = "None"
	local key = ""
	local specs: { PartSpec } = {}
	local liquid: PartSpec? = nil
	local model: Model? = nil
	local target: Vector3? = nil
	local pose = CFrame.identity
	local seen = false
	local pouring = false
	local pourBlend = 0
	local sway = 0
	local fill = 1
	local liquidHeight = 0

	local function clear()
		for _, spec in specs do
			spec.Part:Destroy()
		end
		table.clear(specs)
		liquid = nil
		if model ~= nil then
			model:Destroy()
			model = nil
		end
		seen = false
		target = nil
	end

	-- the bottle, built around its nozzle (origin) pointing down -Y; the body rises over it
	local function buildBottle(topping: string)
		const color = SAUCE[topping] or Theme.Color.Mustard
		const length = look.Bottle.Length
		const radius = look.Bottle.Radius
		const cap = Theme.Color.Cream
		-- nozzle, neck, body, liquid, cap (cylinders stand along Y: their axis is X, so they are turned)
		const stand = CFrame.Angles(0, 0, math.pi / 2)
		const nozzleH, neckH = length * 0.12, length * 0.2
		const bodyH = length - nozzleH - neckH
		const nozzle = newPart(Enum.PartType.Cylinder, Vector3.new(nozzleH, radius * 0.3, radius * 0.3), color, 0)
		const neck = newPart(Enum.PartType.Cylinder, Vector3.new(neckH, radius * 0.6, radius * 0.6), cap, 0)
		const body = newPart(Enum.PartType.Cylinder, Vector3.new(bodyH, radius * 2, radius * 2), Color3.fromHex("#FFF1D6"), 0.55)
		const inner = newPart(Enum.PartType.Cylinder, Vector3.new(bodyH * 0.9, radius * 1.8, radius * 1.8), color, 0)
		table.insert(specs, { Part = nozzle, Local = CFrame.new(0, nozzleH / 2, 0) * stand })
		table.insert(specs, { Part = neck, Local = CFrame.new(0, nozzleH + neckH / 2, 0) * stand })
		table.insert(specs, { Part = body, Local = CFrame.new(0, nozzleH + neckH + bodyH / 2, 0) * stand })
		-- the cap differs by shape: a ball (ketchup), a flat disc (mustard), a tall pin (cream cheese)
		const capShape = if topping == "ketchup" then Vector3.new(radius * 0.7, radius * 0.7, radius * 0.7) elseif topping == "mustard" then Vector3.new(radius * 0.15, radius * 1.4, radius * 1.4) else Vector3.new(radius * 1.2, radius * 0.4, radius * 0.4)
		const top = newPart(if topping == "ketchup" then Enum.PartType.Ball else Enum.PartType.Cylinder, capShape, Theme.Color.Ink, 0)
		table.insert(specs, { Part = top, Local = CFrame.new(0, length + capShape.X * 0.2, 0) * (if topping == "ketchup" then CFrame.identity else stand) })
		const liquidSpec: PartSpec = { Part = inner, Local = CFrame.new(0, nozzleH + neckH + bodyH * 0.45, 0) * stand }
		table.insert(specs, liquidSpec)
		liquid = liquidSpec
		liquidHeight = bodyH * 0.9
		for _, spec in specs do
			spec.Part.Parent = folder
			spec.Part.Name = "Prep_Bottle"
		end
	end

	local function buildModel(topping: string)
		const source = kitModel(topping)
		if source == nil then
			return
		end
		const copy = source:Clone()
		for _, descendant in copy:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.CastShadow = false
				descendant.Massless = true
			elseif descendant:IsA("WeldConstraint") then
				descendant:Destroy()
			end
		end
		copy.Name = `Prep_Tool_{topping}`
		copy:ScaleTo(scale * (if topping == "potato_sticks" then 0.35 else 0.9))
		copy.Parent = folder
		model = copy
	end

	const self = {} :: any

	function self.Set(_: any, wanted: Kind, topping: string)
		if wanted == kind and topping == key then
			return
		end
		clear()
		kind = wanted
		key = topping
		fill = 1
		if wanted == "Bottle" then
			buildBottle(topping)
		elseif wanted ~= "None" then
			buildModel(topping)
		end
	end

	function self.Kind(_: any): Kind
		return kind
	end

	function self.Key(_: any): string
		return key
	end

	function self.Move(_: any, point: Vector3?, pour: boolean, side: number)
		target = point
		pouring = pour
		sway = side
	end

	function self.Tip(_: any): Vector3
		return pose.Position
	end

	function self.SetFill(_: any, value: number)
		fill = math.clamp(value, 0, 1)
	end

	function self.Step(_: any, dt: number)
		const goal = target
		if goal == nil or kind == "None" then
			for _, spec in specs do
				spec.Part.LocalTransparencyModifier = 1
			end
			if model ~= nil then
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.LocalTransparencyModifier = 1
					end
				end
			end
			seen = false
			return
		end
		const spring = look.Bottle.Spring
		pourBlend += ((if pouring then 1 else 0) - pourBlend) * (1 - math.exp(-10 * dt))
		if kind == "Bottle" then
			-- the nozzle rides over the point; the bottle leans (idle: Tilt, pouring: Tilt - 70 degrees) about the long axis of the bun
			const lean = math.rad(look.Bottle.Tilt - 70 * pourBlend)
			const wanted = CFrame.new(goal + Vector3.yAxis * look.Bottle.Length * 0.35 * (1 - pourBlend * 0.4)) * orient * CFrame.Angles(0, 0, -lean)
			pose = if seen then pose:Lerp(wanted, 1 - math.exp(-spring * dt)) else wanted
			for _, spec in specs do
				spec.Part.CFrame = pose * spec.Local
				spec.Part.LocalTransparencyModifier = 0
			end
			if liquid ~= nil then
				const height = math.max(liquidHeight * fill, 0.001)
				const base = liquid.Local * CFrame.new(0, 0, 0)
				liquid.Part.Size = Vector3.new(height, liquid.Part.Size.Y, liquid.Part.Size.Z)
				liquid.Part.CFrame = pose * base * CFrame.new(-(liquidHeight - height) / 2, 0, 0)
				liquid.Part.Transparency = if fill <= 0.02 then 1 else 0
			end
		elseif model ~= nil then
			const rise = look.Hand.Rise
			const wanted = CFrame.new(goal + Vector3.yAxis * rise) * orient * CFrame.Angles(0, 0, math.rad(12) * sway)
			pose = if seen then pose:Lerp(wanted, 1 - math.exp(-look.Hand.Spring * dt)) else wanted
			model:PivotTo(pose)
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.LocalTransparencyModifier = 0
				end
			end
		end
		seen = true
	end

	function self.Destroy(_: any)
		clear()
	end

	return self :: Tool
end

return ToolView
