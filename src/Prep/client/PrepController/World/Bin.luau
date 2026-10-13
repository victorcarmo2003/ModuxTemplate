--!strict
-- World/Bin: what is left of the 3D bin after the polish of 2026-10-12 (decision of the owner: the bin is a 2D UI ZONE, drawn by the
-- PrepShell at Layout.Mini.Bin, tested in px). No Parts, no hitbox, no lid here any more. This module keeps:
--   `SetWanted`  there is something to throw in this view: the zone shows (BinZone, read by the shell). Stages call it as before.
--   `Eat`        the model that was dropped shrinks and falls toward the 3D point under the zone (the ray of the zone centre, at the
--                depth Rules.World.Bin.Depth of the view), with dust, crumbs and the sound; then `done`.
--   the target "Bin" of the registry has no Part: the Aim answers it when the pointer, with something in hand, is inside the zone
--   (BinZone.Hit), so the stages still read `over.Target.Kind == "Bin"` in a Drop.
-- Nothing here is networked: the stage sends PrepTrash (controller:Trash). No Modux, no Vide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local BinZone = require(script.Parent.BinZone)
local Juice = require(script.Parent.Juice)
local Targets = require(script.Parent.Targets)
local Types = require(script.Parent.Types)

export type Bin = {
	-- The frame and field of view the camera ends on in this view and the distance to the plate (the Focus); the bin goes to its place
	-- on the screen of that view, at Rules.World.Bin.Depth of that distance (a bin as big as the sausages and the plate it takes).
	SetView: (self: Bin, frame: CFrame, fov: number, distance: number) -> (),
	-- There is something in this view that can be thrown (the hitbox answers the ray only then).
	SetWanted: (self: Bin, wanted: boolean) -> (),
	-- Takes a local inert model (a copy of what was dropped), swallows it and destroys it. `done` runs when it is in.
	Eat: (self: Bin, model: Model, done: (() -> ())?) -> (),
	-- The world point of its mouth (the lid), where the thing falls in.
	Mouth: (self: Bin) -> Vector3,
	Step: (self: Bin, dt: number) -> (),
	Destroy: (self: Bin) -> (),
}

const BinModule = {}

type Eating = { Model: Model, From: CFrame, T: number, Spin: number, Start: number, Done: (() -> ())? }

function BinModule.new(
	_folder: Folder,
	rules: Content.PrepWorldRules,
	registry: Targets.Registry,
	juice: () -> Juice.Juice,
	audio: Juice.Audio?
): Bin
	const cfg = rules.Bin
	local frame: CFrame = CFrame.identity
	local fov: number = 70
	local distance: number = 3
	local placed = false
	const eating: { Eating } = {}

	-- The world point of the mouth: the ray of the centre of the zone at the depth of the view; before the zone is on screen, the
	-- old place of the view (Rules.World.Bin.Screen).
	local function mouthPoint(): Vector3
		const camera = workspace.CurrentCamera
		if camera == nil then
			return frame.Position
		end
		const depth = math.max(distance, 1) * cfg.Depth
		const centre = BinZone.Center()
		if centre ~= nil then
			const unit = camera:ViewportPointToRay(centre.X, centre.Y)
			const along = math.max(unit.Direction:Dot(camera.CFrame.LookVector), 0.2)
			const point: Vector3 = unit.Origin + unit.Direction * (depth / along)
			return point
		end
		const aspect = if camera.ViewportSize.Y > 0 then camera.ViewportSize.X / camera.ViewportSize.Y else 16 / 9
		const half = depth * math.tan(math.rad(fov) / 2)
		const local_ = Vector3.new((cfg.Screen.X * 2 - 1) * half * aspect, (1 - cfg.Screen.Y * 2) * half, -depth)
		const world: Vector3 = frame:PointToWorldSpace(local_)
		return world
	end

	const self = {} :: any

	function self.SetView(_: any, newFrame: CFrame, newFov: number, newDistance: number)
		frame = newFrame
		fov = newFov
		distance = newDistance
		placed = true
	end

	function self.SetWanted(_: any, value: boolean)
		BinZone.SetWanted(value)
	end

	function self.Mouth(_: any): Vector3
		return mouthPoint()
	end

	function self.Eat(_: any, thing: Model, done: (() -> ())?)
		const from = thing:GetPivot()
		table.insert(eating, { Model = thing, From = from, T = 0, Spin = (if math.random() < 0.5 then -1 else 1) * 2.5, Start = thing:GetScale(), Done = done })
		if audio ~= nil then
			audio("trash", mouthPoint(), nil)
		end
	end

	function self.Step(_: any, dt: number)
		if not placed and #eating == 0 then
			return
		end
		-- the things being swallowed: a short arc to the mouth, shrinking, turning
		for index = #eating, 1, -1 do
			const entry = eating[index]
			entry.T += dt
			const t = math.clamp(entry.T / cfg.Eat, 0, 1)
			const mouth = mouthPoint()
			const eased = t * t * (3 - 2 * t)
			const arc = math.sin(math.pi * math.min(t * 1.6, 1)) * 0.25
			const position = entry.From.Position:Lerp(mouth, eased) + Vector3.new(0, arc, 0)
			if entry.Model.Parent ~= nil then
				entry.Model:PivotTo(CFrame.new(position) * entry.From.Rotation * CFrame.Angles(0, 0, entry.Spin * t))
				entry.Model:ScaleTo(math.max(entry.Start * (1 - 0.8 * eased), 0.02))
			end
			if t >= 1 then
				table.remove(eating, index)
				entry.Model:Destroy()
				BinZone.Swallowed()
				juice():Burst("Dust", mouth, 5)
				juice():Burst("Crumbs", mouth, 4)
				if entry.Done ~= nil then
					entry.Done()
				end
			end
		end
	end

	-- The target answers the Aim when the pointer with something in hand is inside the 2D zone: it has no Part.
	registry:Add({
		Target = Types.Target("Bin"),
		Parts = {},
		Enabled = function(): boolean
			return BinZone.Wanted()
		end,
		Handlers = {
			Hover = function(entered: boolean)
				BinZone.SetOver(entered)
			end,
		},
	})

	function self.Destroy(_: any)
		registry:Remove("Bin")
		for _, entry in eating do
			if entry.Done ~= nil then
				entry.Done()
			end
			entry.Model:Destroy()
		end
		table.clear(eating)
		BinZone.Reset()
	end

	return self :: Bin
end

return BinModule
