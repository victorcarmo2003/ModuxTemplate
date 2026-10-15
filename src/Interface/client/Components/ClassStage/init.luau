--!strict
-- ClassStage: the class rig standing in the middle of the class screen (user request 2026-10-11, "Animal Hospital"
-- style) when the lobby has no world stage (MapPoint LOBBY-CLASS-STAGE): a transparent ViewportFrame with a
-- WorldModel (so an idle animation can play) over a soft floor shadow. The rig faces the camera, swings slowly
-- (Rig.Sway) and pops on every swap (Rig.Pop). The camera is framed once per species from its bounding box.
-- `Rig(species)` builds the model (CrewRig.Build + Dress, pcall'd by the caller); nil = only the floor shadow (the
-- class name is drawn by ClassSelect over the arrows, TASK-298: no placeholder letter here). Each species is built once while the stage lives and destroyed with it. `OnShown(model)` runs after the rig is
-- parented (idle animation). Per-frame work only while visible. Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Rig = require(script.Rig)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; ViewportFrame and WorldModel are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Species: () -> string,
	-- Unused since TASK-298 (the class name is in ClassSelect); kept so older callers still type-check.
	Badge: (() -> string)?,
	Visible: () -> boolean,
	Rig: ((species: string) -> Model?)?,
	OnShown: ((model: Model) -> ())?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,
	ZIndex: number?,
}

const FOV = 28
const MARGIN = 1.08 -- room around the rig
-- Straight front, a little above: rigs face -Z (CrewRig rest pose).
const VIEW_DIRECTION = Vector3.new(0, 0.1, -1).Unit
const REST = CFrame.new(0, 3, 0) -- HumanoidRootPart 3 studs over the ground (architecture.md §18.5)

local function frame(camera: Camera, model: Model)
	const pivot, size = model:GetBoundingBox()
	const half = math.max(size.Y, size.X * 1.4) / 2
	const distance = half * MARGIN / math.tan(math.rad(FOV / 2)) + size.Z / 2
	const centre = pivot.Position
	camera.CFrame = CFrame.lookAt(centre + VIEW_DIRECTION * distance, centre)
end

return function(props: Props): Frame
	const camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	cleanup(camera)

	const cache: { [string]: Model } = {}
	const missing: { [string]: boolean } = {}
	const shown = source(false)
	local current: Model? = nil
	local stopPop: () -> () = function() end

	const world = createRaw("WorldModel")({ Name = "World" }) :: WorldModel
	const viewport = createRaw("ViewportFrame")({
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(205, 200, 210),
		LightColor = Color3.fromRGB(255, 244, 225),
		LightDirection = Vector3.new(-0.4, -1, -0.7),
		CurrentCamera = camera,
		Visible = shown,
		ZIndex = 2,
		world,
	}) :: ViewportFrame
	camera.Parent = viewport

	cleanup(function()
		stopPop()
		for _, model in cache do
			model:Destroy()
		end
		table.clear(cache)
	end)

	local function rigFor(species: string): Model?
		const cached = cache[species]
		const build = props.Rig
		if cached or missing[species] or build == nil then
			return cached
		end
		const built = build(species)
		if built then
			built:PivotTo(REST)
			cache[species] = built
		else
			missing[species] = true
		end
		return built
	end

	effect(function()
		const species = props.Species()
		if not props.Visible() then
			return
		end
		untrack(function()
			const model = rigFor(species)
			if model == current and model ~= nil then
				return nil
			end
			stopPop()
			for key, other in cache do
				if key ~= species then
					Rig.Settle(other)
					other.Parent = nil
				end
			end
			current = model
			if model then
				Rig.Settle(model)
				model:PivotTo(REST)
				model.Parent = world
				frame(camera, model)
				stopPop = Rig.Pop(model)
				if props.OnShown then
					props.OnShown(model)
				end
			end
			shown(model ~= nil)
			return nil
		end)
	end)

	-- slow swing while visible
	effect(function()
		if not (props.Visible() and shown()) then
			return
		end
		local t = 0
		const connection = RunService.RenderStepped:Connect(function(dt: number)
			t += dt
			const model = current
			if model and model.Parent == world then
				model:PivotTo(REST * Rig.Sway(t))
			end
		end)
		cleanup(function()
			connection:Disconnect()
		end)
	end)

	return create("Frame")({
		Name = props.Name or "ClassStage",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,
		-- hidden with the world stage too (it used to leave the placeholder over the arrows)
		Visible = props.Visible,

		-- floor shadow under the feet
		create("Frame")({
			Name = "Shadow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.93),
			Size = UDim2.fromScale(0.55, 0.09),
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.6,
			ZIndex = 1,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),

		viewport,
	}) :: Frame
end
