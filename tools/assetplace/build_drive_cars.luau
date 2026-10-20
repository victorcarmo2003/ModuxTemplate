--!strict
--[[
	Drive-thru car kit (TASK-574; owner request 2026-10-20: "vidro transparente, um personagem dentro do carro"). EDIT MODE
	ONLY (Command Bar or Studio MCP, InsertService). Idempotent: rebuilds ONLY ReplicatedStorage.Assets.Vehicles.DriveCars,
	never touches Cars (the street traffic keeps its closed cars: they have nobody inside).

	  DriveCars/<Shape>   copy of Cars/<Shape> (paints, wheels, headlights, attachments) with:
	    Body              AST-035_Car<Shape>_Drive Body: the base body without its glass faces (PrimaryPart; its
	                      PivotOffset keeps the base car pivot: base centre, LookVector = front)
	    Glass             the glass faces alone: Material Glass, Transparency GLASS_TRANSPARENCY, no shadow
	    Interior          dark inner shell (flipped body + paint, 0.06 studs inside): the cabin is not hollow through the glass

	Source: tools/blender/drive_cars.py -> Assets/blender/vehicle/AST-035_Car<Shape>_Drive.blend and
	Assets/import/vehicle/AST-035_Car<Shape>_Drive.fbx, uploaded to the group (ids in Assets/import/_asset_ids.json).
	The parts are placed by matching the base car's own uploaded Body to the Cars/<Shape> Body (same Blender origin).
	The consumer is DriveThruController (DriveCars first, Cars as fallback). Save the place afterwards.

	Usage (Edit): loadstring(HttpService:GetAsync(".../tools/assetplace/build_drive_cars.luau"))()() -> report
]]
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

const BASE = { Sedan = 122844071213000, Hatch = 97691661428766, Van = 75116537691175, Pickup = 121980743977812 }
const DRIVE = { Sedan = 109569168758603, Hatch = 102040297017466, Van = 90726438082789, Pickup = 122899572597072 }
const GLASS_TRANSPARENCY = 0.6

local function findPart(model: Instance, name: string): BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

return function(): string
	const vehicles = (ReplicatedStorage :: any).Assets.Vehicles
	local folder = vehicles:FindFirstChild("DriveCars")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "DriveCars"
		folder.Parent = vehicles
	end
	folder:SetAttribute("Source", "TASK-574: AST-035 cars with a Glass part (translucent) and a dark Interior")
	const out: { string } = {}
	for shape, id in DRIVE do
		const template = vehicles.Cars:FindFirstChild(shape)
		if template == nil then
			table.insert(out, `{shape}: no Cars/{shape}`)
			continue
		end
		const old = InsertService:LoadAsset(BASE[shape])
		const new = InsertService:LoadAsset(id)
		const oldBody = findPart(old, "Body")
		const baseBody = template:FindFirstChild("Body") :: BasePart
		if oldBody == nil or baseBody == nil then
			table.insert(out, `{shape}: Body missing`)
			continue
		end
		const toKit = baseBody.CFrame * oldBody.CFrame:Inverse()
		const car = template:Clone()
		const existing = folder:FindFirstChild(shape)
		if existing then
			existing:Destroy()
		end
		local body: BasePart? = nil
		for _, name in { "Body", "Glass", "Interior" } do
			const part = findPart(new, name)
			if part == nil then
				table.insert(out, `{shape}: {name} missing in the upload`)
				continue
			end
			part.CFrame = toKit * part.CFrame
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part:SetAttribute("Asset", `AST-035_Car{shape}_Drive`)
			if name == "Body" then
				part.Color = baseBody.Color
				part.Material = baseBody.Material
				for key, value in baseBody:GetAttributes() do
					if key ~= "Asset" then
						part:SetAttribute(key, value)
					end
				end
				-- attachments (Hit_Front, VFX_Honk, Beam_*) move to the new body
				for _, child in (car:FindFirstChild("Body") :: Instance):GetChildren() do
					child.Parent = part
				end
				(car:FindFirstChild("Body") :: Instance):Destroy()
				body = part
			elseif name == "Glass" then
				part.Material = Enum.Material.Glass
				part.Transparency = GLASS_TRANSPARENCY
				part.CastShadow = false
			else
				part.CastShadow = false
			end
			part.Parent = car
		end
		if body ~= nil then
			car.PrimaryPart = body
			body.PivotOffset = body.CFrame:Inverse() * template:GetPivot()
		end
		car.Parent = folder
		old:Destroy()
		new:Destroy()
		table.insert(out, `{shape}: ok, pivot {car:GetPivot().Position}`)
	end
	return table.concat(out, "\n")
end
