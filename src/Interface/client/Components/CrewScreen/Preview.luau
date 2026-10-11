--!strict
-- Preview of the focused animal on the "Crew" screen (TASK-020): a ViewportFrame with a local CrewRig in the crew
-- uniform, framed by its bounding box from a 3/4 front angle. Static (no per-frame spin: cheap on a phone).
-- `Rig(species)` builds the model (the caller decides how: CrewRig.Build + Dress, pcall'd); nil = the placeholder
-- letter stays. Each species is built once while the preview lives and destroyed with it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; ViewportFrame and UIStroke are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	Species: () -> string,
	Badge: () -> string,
	Visible: () -> boolean,
	Rig: ((species: string) -> Model?)?,
	LayoutOrder: number?,
	Size: UDim2?,
}

const FOV = 30
const MARGIN = 1.12 -- room around the rig
-- Camera direction from the rig centre: rigs face -Z (CrewRig rest pose), seen from the front-right and a bit above.
const VIEW_DIRECTION = Vector3.new(0.45, 0.12, -1).Unit

local function frame(camera: Camera, model: Model)
	const pivot, size = model:GetBoundingBox()
	const half = math.max(size.Y, size.X) / 2
	const distance = half * MARGIN / math.tan(math.rad(FOV / 2)) + size.Z / 2
	const centre = pivot.Position
	camera.CFrame = CFrame.lookAt(centre + VIEW_DIRECTION * distance, centre)
end

return function(props: Props): Frame
	const camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	cleanup(camera)

	const cache: { [string]: Model } = {}
	const missing: { [string]: boolean } = {} -- species whose rig could not be built
	const shown = source(false)

	const viewport = createRaw("ViewportFrame")({
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 244, 225),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		CurrentCamera = camera,
		Visible = shown,
	}) :: ViewportFrame
	camera.Parent = viewport

	cleanup(function()
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
			for key, other in cache do
				if key ~= species then
					other.Parent = nil
				end
			end
			if model then
				model.Parent = viewport
				frame(camera, model)
			end
			shown(model ~= nil)
			return nil
		end)
	end)

	-- Cartoon pass (AST-091): Cream card with a soft top-light gradient and a thick Ink outline.
	return create("Frame")({
		Name = "Preview",
		LayoutOrder = props.LayoutOrder or 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient gives the Cream

		create("UICorner")({ CornerRadius = Theme.Radius.Card }),
		createRaw("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Theme.Color.Ink,
			Thickness = Theme.Outline.Normal,
		}),
		createRaw("UIGradient")({ Rotation = 90, Color = Theme.Gradient(Theme.Tone.Cream) }),

		-- placeholder until the rig (or its kit) exists
		create("TextLabel")({
			Name = "Badge",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			FontFace = Theme.Font.Title,
			TextScaled = true,
			TextColor3 = Theme.Color.Ink,
			Text = props.Badge,
			Visible = function()
				return not shown()
			end,
			createRaw("UIPadding")({
				PaddingTop = UDim.new(0.2, 0),
				PaddingBottom = UDim.new(0.2, 0),
			}),
		}),

		viewport,
	})
end
