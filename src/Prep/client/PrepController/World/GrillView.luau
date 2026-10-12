--!strict
-- World/GrillView: what the 3D grill DRAWS (docs/tech/prep-3d.md §2.4, §3.2; TASK-203). The stage (World/Stages/Grill) decides and
-- sends; this module only presents, from the data the stage hands it each frame:
--   ghost       a see-through copy of the raw sausage on a free roller (the invitation), breathing slowly
--   predicted   the same, steadier, on the roller of a Place that waits for the server
--   carry       the sausage that follows the pointer while it is dragged (snaps to the roller under it)
--   ring        the flip ring: CylinderHandleAdornment (a real ring, InnerRadius) on the grill part, scale From -> To in the window
--   check       a Green check mark above a ready sausage (a shape, not only a colour)
--   turn        the flip: a 180 degree turn about the long axis with a hop, on the REAL sausage of the world (both of its models)
--   shake       a refusal / an early tap: a short side to side shiver of the real sausage
--   fly         a collected sausage in an arc to its slot on the rail
--   hide        the real sausage of the slot is hidden locally (it is on its way to the rail)
-- The real sausages belong to KitchenController (Grill part: container with the raw model and the grilled one over it; the colour
-- of the cooking is that fade). A turn or a shake detaches the models from their weld, moves them with PivotTo and welds them again
-- where they ended. Everything created here lives under the PrepWorld folder (or on the grill part, adornments) and is destroyed
-- with `Destroy`. No Modux, no Vide, no network.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Fx = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Fx)
local Slots = require(StarterPlayer.StarterPlayerScripts.client.Kitchen.KitchenController.Slots)

export type Ring = "None" | "Converge" | "Late"

export type View = {
	-- Ghost on a roller: "None", "Ghost" (the invitation) or "Predicted" (a Place waiting for the server).
	SetGhost: (self: View, slot: number, mode: string) -> (),
	-- Ring on a roller. `progress` is the cooking share 0..1 (Converge uses it), `perfect` the Perfect half-window (share of the
	-- Duration) around the target.
	SetRing: (self: View, slot: number, ring: Ring, progress: number) -> (),
	SetCheck: (self: View, slot: number, on: boolean) -> (),
	-- The sausage under the pointer: nil hides it. `snap` = the roller it will land on, `grilled` = the cooked model.
	SetCarry: (self: View, point: Vector3?, snap: number?, grilled: boolean) -> (),
	-- The real sausage of the slot: turned (sign +1 forward, -1 back), shivered, hidden, flown to the rail.
	Turn: (self: View, slot: number, sign: number) -> (),
	Shake: (self: View, slot: number, amount: number?) -> (),
	Hide: (self: View, slot: number, hidden: boolean) -> (),
	Fly: (self: View, slot: number, railSlot: number, from: CFrame?) -> boolean,
	-- A refused Place: the predicted ghost rises, shivers and goes.
	Reject: (self: View, slot: number) -> (),
	Burst: (self: View, slot: number, band: string) -> (),
	PoseOf: (self: View, slot: number) -> CFrame?,
	ModelOf: (self: View, slot: number) -> Instance?,
	Step: (self: View, dt: number, time: number) -> (),
	Destroy: (self: View) -> (),
}

export type Options = {
	Folder: Folder,
	Rules: Content.PrepWorldRules,
	-- the live slot of the grill / rail (KitchenController:SlotView)
	SlotView: (kind: string, slot: number) -> Slots.Live?,
	Slots: number, -- how many rollers to look for (8)
}

type Anim = {
	Kind: string, -- Turn | Shake
	T: number,
	Duration: number,
	Sign: number,
	Amount: number,
	Models: { Model },
	Bases: { CFrame },
	Container: Model,
	Host: BasePart,
}

type Fly = { Model: Model, From: CFrame, To: CFrame, T: number, Slot: number }

type Reject = { Model: Model, T: number, From: CFrame }

type Face = {
	Ghost: Model?,
	GhostMode: string,
	Ring: CylinderHandleAdornment?,
	RingKind: Ring,
	Check: { BoxHandleAdornment },
	CheckOn: boolean,
	Anim: Anim?,
	Hidden: boolean,
	HiddenContainer: Model?,
	Reject: Reject?,
}

const GrillView = {}

const GHOST_PART_ALPHA = 0.85 -- Transparency of the ghost while carried (more solid than the invitation)
const CARRY_SMOOTH = 22 -- 1/s: how fast the carried sausage catches the pointer
const LATE_ALPHA = 0.15
const RING_LIFT = 0.28 -- studs over the roller
const CHECK_LIFT = 0.62

-- The raw / grilled sausage model of the kit (ReplicatedStorage.Assets.Items.Food), nil when it is missing.
local function template(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const food = if items then items:FindFirstChild("Food") else nil
	const model = if food then food:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- A local, inert copy: anchored, never hit by a ray, never casting a shadow.
local function inert(name: string, transparency: number, parent: Instance): Model?
	const source = template(name)
	if source == nil then
		return nil
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
			descendant.Transparency = transparency
		elseif descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
	copy.Name = `Prep_{name}`
	copy.Parent = parent
	return copy
end

local function setAlpha(model: Model, alpha: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = alpha
		end
	end
end

local function easeInOut(t: number): number
	return t * t * (3 - 2 * t)
end

function GrillView.new(options: Options): View
	const folder = options.Folder
	const rules = options.Rules
	const grill = rules.Grill
	const faces: { [number]: Face } = {}
	local carry: Model? = nil
	local carryGrilled = false
	local carryTarget: CFrame? = nil
	local carryPose: CFrame? = nil
	const flights: { Fly } = {}
	const tolerance = Content.Prep.Tolerances.ByKey["grill_flip"]
	const perfect = (if tolerance ~= nil then tolerance.Perfect else 5) / 100
	const good = (if tolerance ~= nil then tolerance.Good else 10) / 100
	local lastRotation = CFrame.identity

	local function faceOf(slot: number): Face
		const known = faces[slot]
		if known ~= nil then
			return known
		end
		do
			const face: Face = {
				Ghost = nil,
				GhostMode = "None",
				Ring = nil,
				RingKind = "None",
				Check = {},
				CheckOn = false,
				Anim = nil,
				Hidden = false,
				HiddenContainer = nil,
				Reject = nil,
			}
			faces[slot] = face
			return face
		end
	end

	-- world pose of the food of a slot (where the roller holds it), nil when the grill is not streamed in
	local function poseOf(slot: number): CFrame?
		const entry = options.SlotView("grill", slot)
		if entry == nil then
			return nil
		end
		const spot = entry.Spot
		if spot.Host.Parent == nil then
			return nil
		end
		const pose = spot.Host.CFrame * spot.Offset
		lastRotation = pose.Rotation
		return pose
	end

	-- Ghost ----------------------------------------------------------------------------------------------------------------

	local function ensureGhost(face: Face): Model?
		if face.Ghost == nil or face.Ghost.Parent == nil then
			face.Ghost = inert("SausageRaw", 1, folder)
			if face.Ghost ~= nil then
				-- a pale, see-through copy: Cream over the texture, not the dark of the roller behind it
				for _, descendant in face.Ghost:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Color = Theme.Color.Cream
						descendant.Material = Enum.Material.SmoothPlastic
					end
				end
			end
		end
		return face.Ghost
	end

	-- Ring and check -----------------------------------------------------------------------------------------------------------

	local function ensureRing(face: Face, host: BasePart): CylinderHandleAdornment
		local ring = face.Ring
		if ring == nil or ring.Parent == nil or ring.Adornee ~= host then
			if ring ~= nil then
				ring:Destroy()
			end
			ring = Instance.new("CylinderHandleAdornment")
			ring.Name = "FlipRing"
			ring.Adornee = host
			ring.Color3 = Theme.Color.Mustard
			ring.AlwaysOnTop = false
			ring.ZIndex = 2
			ring.Height = 0.02
			ring.Transparency = 1
			ring.Parent = folder
			face.Ring = ring
		end
		return ring :: CylinderHandleAdornment
	end

	local function ensureCheck(face: Face, host: BasePart): { BoxHandleAdornment }
		const bars = face.Check
		if #bars == 0 or bars[1].Parent == nil or bars[1].Adornee ~= host then
			for _, bar in bars do
				bar:Destroy()
			end
			table.clear(bars)
			for index = 1, 2 do
				const bar = Instance.new("BoxHandleAdornment")
				bar.Name = `Check{index}`
				bar.Adornee = host
				bar.Color3 = Theme.Color.Green
				bar.AlwaysOnTop = false
				bar.ZIndex = 3
				bar.Transparency = 1
				bar.Parent = folder
				table.insert(bars, bar)
			end
		end
		return bars
	end

	-- Moving the real models -------------------------------------------------------------------------------------------------

	local function modelsOf(entry: Slots.Live): { Model }
		const models: { Model } = {}
		if entry.Raw ~= nil and entry.Raw.Parent ~= nil then
			table.insert(models, entry.Raw)
		end
		if entry.Over ~= nil and entry.Over.Parent ~= nil then
			table.insert(models, entry.Over)
		end
		return models
	end

	local function startAnim(slot: number, kind: string, duration: number, sign: number, amount: number)
		const entry = options.SlotView("grill", slot)
		if entry == nil or entry.Container == nil then
			return
		end
		const face = faceOf(slot)
		-- a running animation finishes where it would have ended, so the next one starts from a clean pose
		if face.Anim ~= nil then
			face.Anim.T = face.Anim.Duration
		end
		const models = modelsOf(entry)
		if #models == 0 then
			return
		end
		const bases: { CFrame } = {}
		for _, model in models do
			table.insert(bases, model:GetPivot())
		end
		if face.Anim == nil then
			for _, model in models do
				Slots.Detach(model)
			end
		end
		face.Anim = {
			Kind = kind,
			T = 0,
			Duration = duration,
			Sign = sign,
			Amount = amount,
			Models = models,
			Bases = bases,
			Container = entry.Container,
			Host = entry.Spot.Host,
		}
	end

	-- the pose of an animation at t (0..1) relative to its base
	local function offsetOf(anim: Anim, t: number): CFrame
		if anim.Kind == "Turn" then
			const angle = math.pi * anim.Sign * easeInOut(t)
			const centre = Slots.FlipCenter
		return CFrame.new(0, rules.Ring.Hop * math.sin(math.pi * t) + centre, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -centre, 0)
		end
		-- Shake: side to side along the roller, dying out
		return CFrame.new(0, 0, math.sin(t * math.pi * 7) * anim.Amount * (1 - t))
	end

	local function finishAnim(face: Face, anim: Anim)
		face.Anim = nil
		for index, model in anim.Models do
			if model.Parent ~= nil then
				model:PivotTo(anim.Bases[index] * offsetOf(anim, 1))
				if anim.Host.Parent ~= nil then
					Slots.Attach(model, anim.Host)
				end
			end
		end
	end

	-- Public ----------------------------------------------------------------------------------------------------------------------

	const self = {} :: any

	function self.PoseOf(_: any, slot: number): CFrame?
		return poseOf(slot)
	end

	function self.ModelOf(_: any, slot: number): Instance?
		const face = faces[slot]
		const entry = options.SlotView("grill", slot)
		if entry ~= nil and entry.Container ~= nil then
			return entry.Container
		end
		return if face ~= nil then face.Ghost else nil
	end

	function self.SetGhost(_: any, slot: number, mode: string)
		const face = faceOf(slot)
		face.GhostMode = mode
		if mode == "None" and face.Ghost ~= nil then
			setAlpha(face.Ghost, 1)
		end
	end

	function self.SetRing(_: any, slot: number, ring: Ring, progress: number)
		const face = faceOf(slot)
		face.RingKind = ring
		const entry = options.SlotView("grill", slot)
		const pose = poseOf(slot)
		if ring == "None" or entry == nil or pose == nil then
			if face.Ring ~= nil then
				face.Ring.Transparency = 1
			end
			return
		end
		const host = entry.Spot.Host
		const adornment = ensureRing(face, host)
		local radius = grill.RingRadius
		local thickness = rules.Ring.Good
		if ring == "Converge" then
			const window = Content.Prep.Rules.Grill
			const span = math.max(window.Target - window.From, 1e-3)
			const t = math.clamp((progress - window.From) / span, 0, 1)
			radius *= rules.Ring.From + (rules.Ring.To - rules.Ring.From) * easeInOut(t)
			const distance = math.abs(progress - window.Target)
			thickness = if distance <= perfect then rules.Ring.Perfect elseif distance <= good then rules.Ring.Good else rules.Ring.Good * 0.6
			adornment.Transparency = 0.25
		else
			-- Late: small, opaque, still worth a tap
			radius *= rules.Ring.Late
			thickness = rules.Ring.Good
			adornment.Transparency = LATE_ALPHA
		end
		adornment.Radius = radius
		adornment.InnerRadius = math.max(radius - thickness, 0.01)
		-- the cylinder of an adornment runs along its Z: turn it to stand on the roller
		adornment.CFrame = host.CFrame:ToObjectSpace(pose * CFrame.new(0, RING_LIFT, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
	end

	function self.SetCheck(_: any, slot: number, on: boolean)
		const face = faceOf(slot)
		face.CheckOn = on
		const entry = options.SlotView("grill", slot)
		const pose = poseOf(slot)
		if not on or entry == nil or pose == nil then
			for _, bar in face.Check do
				bar.Transparency = 1
			end
			return
		end
		const host = entry.Spot.Host
		const bars = ensureCheck(face, host)
		const size = grill.CheckSize
		-- a check lying over the roller, readable from the camera above: a short stroke and a long one
		const base = pose * CFrame.new(0, CHECK_LIFT, 0)
		const short = base * CFrame.new(-size * 0.45, 0, size * 0.1) * CFrame.Angles(0, math.rad(45), 0)
		const long = base * CFrame.new(size * 0.35, 0, -size * 0.1) * CFrame.Angles(0, math.rad(-50), 0)
		bars[1].Size = Vector3.new(size * 0.55, 0.03, size * 0.16)
		bars[2].Size = Vector3.new(size * 1.1, 0.03, size * 0.16)
		bars[1].CFrame = host.CFrame:ToObjectSpace(short)
		bars[2].CFrame = host.CFrame:ToObjectSpace(long)
		bars[1].Transparency = 0
		bars[2].Transparency = 0
	end

	function self.SetCarry(_: any, point: Vector3?, snap: number?, grilled: boolean)
		if point == nil and snap == nil then
			carryTarget = nil
			if carry ~= nil then
				carry:Destroy()
				carry = nil
				carryPose = nil
			end
			return
		end
		if carry == nil or carryGrilled ~= grilled then
			if carry ~= nil then
				carry:Destroy()
			end
			carryGrilled = grilled
			carry = inert(if grilled then "SausageGrilled" else "SausageRaw", GHOST_PART_ALPHA - 0.5, folder)
			carryPose = nil
		end
		local pose: CFrame? = nil
		if snap ~= nil then
			pose = poseOf(snap)
		end
		if pose == nil and point ~= nil then
			pose = CFrame.new(point) * lastRotation.Rotation
		end
		carryTarget = pose
	end

	function self.Turn(_: any, slot: number, sign: number)
		startAnim(slot, "Turn", rules.Ring.Turn, sign, 0)
	end

	function self.Shake(_: any, slot: number, amount: number?)
		startAnim(slot, "Shake", grill.Shake, 1, amount or grill.ShakeAmount)
	end

	function self.Hide(_: any, slot: number, hidden: boolean)
		const face = faceOf(slot)
		face.Hidden = hidden
		face.HiddenContainer = nil
		if not hidden then
			const entry = options.SlotView("grill", slot)
			if entry ~= nil and entry.Container ~= nil then
				for _, descendant in entry.Container:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end

	function self.Fly(_: any, slot: number, railSlot: number, from: CFrame?): boolean
		const start = from or poseOf(slot)
		const railEntry = options.SlotView("rail", railSlot)
		if start == nil or railEntry == nil then
			return false
		end
		const spot = railEntry.Spot
		if spot.Host.Parent == nil then
			return false
		end
		const model = inert("SausageGrilled", 0, folder)
		if model == nil then
			return false
		end
		table.insert(flights, { Model = model, From = start, To = spot.Host.CFrame * spot.Offset, T = 0, Slot = slot })
		return true
	end

	function self.Reject(_: any, slot: number)
		const face = faceOf(slot)
		if face.Ghost == nil then
			return
		end
		face.GhostMode = "None"
		face.Reject = { Model = face.Ghost, T = 0, From = face.Ghost:GetPivot() }
		setAlpha(face.Ghost, 0.45)
	end

	function self.Burst(_: any, slot: number, band: string)
		const pose = poseOf(slot)
		if pose == nil then
			return
		end
		const at = pose.Position + Vector3.new(0, 0.3, 0)
		if band == "Perfect" then
			Fx.Burst(at, "Ready", 12, Theme.Color.Mustard)
		elseif band == "Good" then
			Fx.Burst(at, "Ready", 6, Theme.Color.Cream)
		else
			Fx.Burst(at, "Dust", 6)
		end
	end

	function self.Step(_: any, dt: number, time: number)
		for slot, face in faces do
			-- ghost: invitation breathes, a prediction is steady
			const ghostModel = face.Ghost
			if face.GhostMode ~= "None" then
				const pose = poseOf(slot)
				const ghost = ensureGhost(face)
				if ghost ~= nil and pose ~= nil then
					if face.Reject == nil then
						ghost:PivotTo(pose)
					end
					const breath = if face.GhostMode == "Ghost" then math.sin(time * 2.2 + slot) * grill.GhostBreath else 0
					setAlpha(ghost, if face.GhostMode == "Ghost" then grill.GhostAlpha + breath else grill.GhostAlpha - 0.28)
				end
			elseif ghostModel ~= nil and face.Reject == nil and ghostModel.Parent ~= nil then
				setAlpha(ghostModel, 1)
			end
			-- a refused ghost rises, shivers and goes
			const reject = face.Reject
			if reject ~= nil then
				reject.T += dt
				const t = math.clamp(reject.T / (grill.Shake * 1.4), 0, 1)
				reject.Model:PivotTo(
					reject.From * CFrame.new(math.sin(t * math.pi * 8) * grill.ShakeAmount, 0.5 * easeInOut(t), 0)
				)
				setAlpha(reject.Model, 0.45 + 0.55 * t)
				if t >= 1 then
					face.Reject = nil
					setAlpha(reject.Model, 1)
				end
			end
			-- turn / shake of the real sausage
			const anim = face.Anim
			if anim ~= nil then
				const entry = options.SlotView("grill", slot)
				if entry == nil or entry.Container ~= anim.Container or anim.Container.Parent == nil then
					face.Anim = nil
				else
					anim.T += dt
					const t = math.clamp(anim.T / anim.Duration, 0, 1)
					for index, model in anim.Models do
						if model.Parent ~= nil then
							model:PivotTo(anim.Bases[index] * offsetOf(anim, t))
						end
					end
					if t >= 1 then
						finishAnim(face, anim)
					end
				end
			end
			-- hidden: the container of the slot (re-made by the world) is kept see-through
			if face.Hidden then
				const entry = options.SlotView("grill", slot)
				if entry ~= nil and entry.Container ~= nil and entry.Container ~= face.HiddenContainer then
					face.HiddenContainer = entry.Container
					for _, descendant in entry.Container:GetDescendants() do
						if descendant:IsA("BasePart") then
							descendant.LocalTransparencyModifier = 1
						end
					end
				end
			end
		end
		-- flights to the rail
		for index = #flights, 1, -1 do
			const flight = flights[index]
			flight.T += dt
			const t = math.clamp(flight.T / grill.Collect, 0, 1)
			const position = flight.From.Position:Lerp(flight.To.Position, easeInOut(t)) + Vector3.new(0, grill.CollectArc * math.sin(math.pi * t), 0)
			flight.Model:PivotTo(CFrame.new(position) * flight.To.Rotation)
			if t >= 1 then
				flight.Model:Destroy()
				table.remove(flights, index)
			end
		end
		-- the carried sausage
		if carry ~= nil and carryTarget ~= nil then
			if carryPose == nil then
				carryPose = carryTarget
			else
				carryPose = carryPose:Lerp(carryTarget, 1 - math.exp(-CARRY_SMOOTH * dt))
			end
			carry:PivotTo(carryPose :: CFrame)
		end
	end

	function self.Destroy(_: any)
		for _, face in faces do
			const anim = face.Anim
			if anim ~= nil then
				finishAnim(face, anim)
			end
			if face.Ghost ~= nil then
				face.Ghost:Destroy()
			end
			if face.Ring ~= nil then
				face.Ring:Destroy()
			end
			for _, bar in face.Check do
				bar:Destroy()
			end
		end
		for slot in faces do
			-- give a hidden sausage back (the world keeps its model)
			const entry = options.SlotView("grill", slot)
			if entry ~= nil and entry.Container ~= nil and faces[slot].Hidden then
				for _, descendant in entry.Container:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.LocalTransparencyModifier = 0
					end
				end
			end
		end
		table.clear(faces)
		for _, flight in flights do
			flight.Model:Destroy()
		end
		table.clear(flights)
		if carry ~= nil then
			carry:Destroy()
			carry = nil
		end
	end

	return self :: View
end

return GrillView
