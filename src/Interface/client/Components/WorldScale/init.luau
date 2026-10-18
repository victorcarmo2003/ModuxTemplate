--!strict
-- WorldScale: makes a pixel-sized BillboardGui behave like an object in the world (owner request 2026-10-18: the kitchen
-- stock pills "ficam maiores na tela conforme o jogador se afasta", cover each other and the HUD).
-- A BillboardGui sized in Offset keeps the same pixels at any distance, so from far it looks huge next to the shrinking
-- station. Track(gui, width, height) scales it by NEAR / distance (camera to the adornee + StudsOffset), clamped to
-- [MIN, 1]: design size up close (the prompt radius), shrinking like a real tag from there on. The layout stays in
-- pixels (outlines, insets, TextSize): the gui Size becomes base * s and a UIScale s on the gui scales the content
-- laid out in the base box. The distance adds StudsOffset as if it were world space (it is camera space; the error is a
-- fraction of a stud).
-- One PreRender loop for every tracked gui; skips disabled guis. Call inside a Vide scope: it untracks on cleanup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)

const cleanup = Vide.cleanup

const NEAR = 9 -- studs: at or closer than this the gui shows at its design size
const MIN = 0.3 -- smallest scale (about 37 studs); MaxDistance hides it past that

type Entry = { Gui: BillboardGui, Scale: UIScale, Width: number, Height: number, Last: number }

const entries: { [BillboardGui]: Entry } = {}
local connection: RBXScriptConnection? = nil

local function positionOf(gui: BillboardGui): Vector3?
	const adornee = gui.Adornee or gui.Parent
	local position: Vector3
	if adornee == nil then
		return nil
	elseif adornee:IsA("Attachment") then
		position = adornee.WorldPosition
	elseif adornee:IsA("BasePart") then
		position = adornee.Position
	elseif adornee:IsA("Model") then
		position = adornee:GetPivot().Position
	else
		return nil
	end
	return position + gui.StudsOffset + gui.StudsOffsetWorldSpace
end

local function apply(entry: Entry, scale: number)
	if math.abs(scale - entry.Last) < 0.005 then
		return
	end
	entry.Last = scale
	entry.Scale.Scale = scale
	entry.Gui.Size = UDim2.fromOffset(entry.Width * scale, entry.Height * scale)
end

local function step()
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const eye = camera.CFrame.Position
	for gui, entry in entries do
		if not gui.Enabled then
			continue
		end
		const position = positionOf(gui)
		if position == nil then
			continue
		end
		const distance = (position - eye).Magnitude
		apply(entry, math.clamp(NEAR / math.max(distance, 1e-3), MIN, 1))
	end
end

const WorldScale = {}

-- width / height: the design size in pixels (the Offset the gui was built with).
function WorldScale.Track(gui: BillboardGui, width: number, height: number)
	const scale = Instance.new("UIScale")
	scale.Name = "WorldScale"
	scale.Parent = gui
	entries[gui] = { Gui = gui, Scale = scale, Width = width, Height = height, Last = -1 }
	if connection == nil then
		connection = RunService.PreRender:Connect(step)
	end
	cleanup(function()
		entries[gui] = nil
		if next(entries) == nil and connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end)
end

return table.freeze(WorldScale)
