--!strict
-- World stage of the class screen (user request 2026-10-11): the class rig stands on the MapPoint LOBBY-CLASS-STAGE
-- (tag MapPoint, attribute PointId; facing = the point's look vector, rigs face -Z) and the camera is locked in front
-- of it, framed from the rig's bounding box. Local only: the rigs are client models in a Folder of the Workspace,
-- never tagged (RigController leaves them alone), dressed by the caller's Build. Same motion as the viewport stage
-- (ClassStage.Rig: slow swing, pop on swap). The camera is taken with `Take()` (CameraController External) and
-- given back with `Release()`. Without the point the caller uses the ClassStage viewport instead.
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Rig = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ClassStage.Rig)

export type Options = {
	Point: CFrame,
	-- skin: Content.Skins key previewed on the class screen ("" = the crew uniform, owner request 2026-10-17)
	Build: (species: string, skin: string) -> Model?,
	OnShown: (model: Model) -> (),
	Take: () -> (),
	Release: () -> (),
}

export type Stage = {
	Show: (species: string, skin: string?) -> (),
	Close: () -> (),
	Destroy: () -> (),
}

const LIFT = Vector3.new(0, 3, 0) -- HumanoidRootPart over the ground point (architecture.md §18.5)
const FOV = 38
const MARGIN = 1.4 -- room around the rig: framed once on the first rig, bigger animals must still fit
const RISE = 0.06 -- the camera looks a little down at the rig
-- The rig sits this share of the half view above the screen centre: its feet clear the class name and the arrows
-- under it (ClassSelect, TASK-298).
const LIFT_VIEW = 0.12

return function(options: Options): Stage
	const folder = Instance.new("Folder")
	folder.Name = "LobbyClassStage"
	const base = CFrame.new(options.Point.Position + LIFT) * options.Point.Rotation
	const cache: { [string]: Model } = {}
	const missing: { [string]: boolean } = {}
	local current: Model? = nil
	local open = false
	local stopPop: () -> () = function() end
	local sway: RBXScriptConnection? = nil
	-- until a rig is framed (or when every rig fails to build): a fixed view of the point
	local framing: CFrame = CFrame.lookAt(base.Position + base.LookVector * 12 + Vector3.new(0, 1, 0), base.Position)
	local framed = false

	local function rigFor(species: string, skin: string): Model?
		const key = `{species}|{skin}`
		const cached = cache[key]
		if cached or missing[key] then
			return cached
		end
		const built = options.Build(species, skin)
		if built then
			built:PivotTo(base)
			cache[key] = built
		else
			missing[key] = true
		end
		return built
	end

	local function frame(model: Model)
		const pivot, size = model:GetBoundingBox()
		const half = math.max(size.Y, size.X * 1.6) / 2
		const distance = half * MARGIN / math.tan(math.rad(FOV / 2)) + size.Z / 2
		const centre = pivot.Position
		const look = base.LookVector
		const eye = centre + (look + Vector3.new(0, RISE, 0)).Unit * distance
		const drop = Vector3.new(0, distance * math.tan(math.rad(FOV / 2)) * LIFT_VIEW, 0)
		framing = CFrame.lookAt(eye - drop, centre - drop)
		framed = true
	end

	local function apply()
		const camera = workspace.CurrentCamera
		const target = framing
		if camera == nil then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if camera.FieldOfView ~= FOV then
			camera.FieldOfView = FOV
		end
		camera.CFrame = target
	end

	local function stopSway()
		if sway then
			sway:Disconnect()
			sway = nil
		end
	end

	local function show(species: string, skin: string?)
		if not open then
			open = true
			options.Take()
			folder.Parent = workspace
			local t = 0
			stopSway()
			sway = RunService.RenderStepped:Connect(function(dt: number)
				t += dt
				const model = current
				if model and model.Parent == folder then
					model:PivotTo(base * Rig.Sway(t))
				end
				apply()
			end)
		end
		const model = rigFor(species, skin or "")
		if model == current then
			return
		end
		stopPop()
		if current then
			Rig.Settle(current)
			current.Parent = nil
		end
		current = model
		if model then
			Rig.Settle(model)
			model:PivotTo(base)
			model.Parent = folder
			if not framed then
				frame(model) -- framed once: every class rig shares the same camera, so the swap reads as a swap
			end
			stopPop = Rig.Pop(model)
			options.OnShown(model)
		end
	end

	local function close()
		if not open then
			return
		end
		open = false
		stopSway()
		stopPop()
		if current then
			Rig.Settle(current)
			current.Parent = nil
			current = nil
		end
		folder.Parent = nil
		options.Release()
	end

	local function destroy()
		close()
		for _, model in cache do
			model:Destroy()
		end
		table.clear(cache)
		folder:Destroy()
	end

	return {
		Show = show,
		Close = close,
		Destroy = destroy,
	}
end
