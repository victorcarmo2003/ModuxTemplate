--!strict
-- What a plate in hand shows (TASK-570; kitchen-world.md §2). Local, for every plate Tool any character holds: the cut bun and
-- the grilled sausage that are on it (Tool attributes Bun / Sausage, shared/Plate/PlateTool) as kit food models
-- (ReplicatedStorage.Assets.Items.Food BunOpen / SausageGrilled) welded on the Handle; placeholders when the kit is missing. The
-- hot dog a full plate becomes draws itself (HotDogVisual on the server). Plain module: the controller calls Watch once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlateTool = require(ReplicatedStorage.shared.Plate.PlateTool)

const FOLDER = "PlateFood"
const BUN_COLOR = Color3.fromHex("#E8B36B")
const DOG_COLOR = Color3.fromHex("#C8553D")
const LIFT = 0.06 -- studs over the top of the Handle
const SAUSAGE_LIFT = 0.17 -- the sausage in the groove of the open bun

const HandFood = {}

local function kit(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const food = if items then items:FindFirstChild("Food") else nil
	const model = if food then food:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

local function placeholder(name: string, bun: boolean): Model
	const model = Instance.new("Model")
	model.Name = name
	const part = Instance.new("Part")
	part.Name = "Body"
	if bun then
		part.Size = Vector3.new(1.0, 0.25, 0.4)
		part.Color = BUN_COLOR
	else
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(1.1, 0.2, 0.2)
		part.Color = DOG_COLOR
	end
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	model.PrimaryPart = part
	return model
end

-- A food model welded to the Handle, its pivot at `at` (Handle space)
local function addFood(folder: Instance, handle: BasePart, name: string, at: CFrame, bun: boolean)
	const template = kit(name)
	const model = if template then template:Clone() else placeholder(name, bun)
	model:PivotTo(handle.CFrame * at)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			const weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = folder
end

-- Rebuilds the food of one plate Tool from its attributes
local function draw(tool: Tool)
	const old = tool:FindFirstChild(FOLDER)
	if old ~= nil then
		old:Destroy()
	end
	if tool:GetAttribute(PlateTool.Attr.Item) ~= PlateTool.Plate then
		return
	end
	const handle = tool:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return
	end
	const bun, sausage = PlateTool.Parts(tool)
	if not bun and not sausage then
		return
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	const top = CFrame.new(0, handle.Size.Y / 2 + LIFT, 0)
	if bun then
		addFood(folder, handle, "BunOpen", top, true)
	end
	if sausage then
		addFood(folder, handle, "SausageGrilled", top * CFrame.new(0, if bun then SAUSAGE_LIFT else 0, 0), false)
	end
	folder.Parent = tool
end

-- Follows every plate Tool in every character (and its Bun / Sausage writes). Returns the stop function.
function HandFood.Watch(): () -> ()
	const links: { RBXScriptConnection } = {}
	const tools: { [Tool]: RBXScriptConnection } = {}

	local function track(child: Instance)
		if not child:IsA("Tool") or tools[child] ~= nil then
			return
		end
		const tool = child :: Tool
		tools[tool] = tool.AttributeChanged:Connect(function(name: string)
			if name == PlateTool.Attr.Bun or name == PlateTool.Attr.Sausage or name == PlateTool.Attr.Item then
				draw(tool)
			end
		end)
		draw(tool)
	end
	local function untrack(child: Instance)
		if child:IsA("Tool") and tools[child] ~= nil then
			tools[child]:Disconnect()
			tools[child] = nil
		end
	end
	local function watchCharacter(character: Model)
		table.insert(links, character.ChildAdded:Connect(track))
		table.insert(links, character.ChildRemoved:Connect(untrack))
		for _, child in character:GetChildren() do
			track(child)
		end
	end
	local function watchPlayer(player: Player)
		table.insert(links, player.CharacterAdded:Connect(watchCharacter))
		if player.Character ~= nil then
			watchCharacter(player.Character)
		end
	end
	table.insert(links, Players.PlayerAdded:Connect(watchPlayer))
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	return function()
		for _, link in links do
			link:Disconnect()
		end
		table.clear(links)
		for tool, link in tools do
			link:Disconnect()
		end
		table.clear(tools)
	end
end

return table.freeze(HandFood)
