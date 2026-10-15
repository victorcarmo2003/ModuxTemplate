--!strict
-- World/GrillView: what the 3D grill DRAWS (docs/tech/prep-3d.md §2.4, §3.2; TASK-203). The stage (World/Stages/Grill) decides and
-- sends; this module only presents, from the data the stage hands it each frame:
--   ghost       a see-through copy of the raw sausage on a free roller (the invitation), breathing slowly
--   predicted   the same, steadier, on the roller of a Place that waits for the server
--   carry       the sausage that follows the pointer while it is dragged (snaps to the roller under it)
--   ring        the bars over the roller (World/GrillBar, TASK-280: the cartoon kit of the settings panel): the cooking bar and the flip
--               window (Good band Mustard, Perfect band Cream, a Cream knob that swings)
--   check       a HintMark Check (Green rounded square, check glyph, in studs over the sausage) on a ready sausage (a shape, not only a colour)
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
local GrillRig = require(script.Parent.GrillRig)
local Juice = require(script.Parent.Juice)
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)
local GrillBar = require(script.Parent.GrillBar)

-- TASK-257 (owner request 2026-10-14): "Progress" = the cooking bar (grey track, Green fill, a Mustard line at 50%); "Converge" =
-- the flip timing bar (Good / Perfect bands in the middle, a cursor that swings end to end until the tap). One swaps for the other
-- with springs (the leaving one pops out, the coming one pops in). TASK-280: both drawn by World/GrillBar
export type Ring = "None" | "Converge" | "Late" | "Progress"

export type View = {
	-- Ghost on a roller: "None", "Ghost" (the invitation) or "Predicted" (a Place waiting for the server).
	SetGhost: (self: View, slot: number, mode: string) -> (),
	-- Ring on a roller. `progress` is the cooking share 0..1 (Converge uses it), `perfect` the Perfect half-window (share of the
	-- Duration) around the target.
	-- `swing` = where the flip cursor is (0..1 of the bar, Grade.SwingAt) for "Converge".
	SetRing: (self: View, slot: number, ring: Ring, progress: number, swing: number?) -> (),
	SetCheck: (self: View, slot: number, on: boolean) -> (),
	-- The sausage under the pointer: nil hides it. `snap` = the roller it will land on, `grilled` = the cooked model.
	SetCarry: (self: View, point: Vector3?, snap: number?, grilled: boolean) -> (),
	-- The carried model, handed over (the bin swallows it); nil when nothing is carried.
	TakeCarry: (self: View) -> Model?,
	-- The real sausage of the slot: turned (sign +1 forward, -1 back), shivered, hidden, flown to the rail.
	Turn: (self: View, slot: number, sign: number) -> (),
	Shake: (self: View, slot: number, amount: number?) -> (),
	Hide: (self: View, slot: number, hidden: boolean) -> (),
	Fly: (self: View, slot: number, railSlot: number, from: CFrame?) -> boolean,
	-- A refused Place: the predicted ghost rises, shivers and goes.
	Reject: (self: View, slot: number) -> (),
	Burst: (self: View, slot: number, band: string) -> (),
	-- TASK-261: the answer of a flip (the server's band): Perfect = sparks, flash, "Perfect!", a big kick of the bar; Good =
	-- lighter, "Nice!"; Messy = a puff, the sausage shivers, "Oops!" and a dull sound. `word` = the text of the badge (TASK-280:
	-- a cartoon pill of the kit, GrillBar.Badge, instead of a bare floating word).
	FlipResult: (self: View, slot: number, band: string, word: string) -> (),
	PoseOf: (self: View, slot: number) -> CFrame?,
	-- The ONE model a contour is drawn around: the raw sausage while it cooks, the grilled one once it is done (the two are
	-- cross-faded, and an outline on the pair is drawn twice). `done` = the cooking is over.
	ModelOf: (self: View, slot: number, done: boolean?) -> Instance?,
	-- Grill marks on the face that was down, shown after the flip: strength 0 (none) .. 1 (dark), by the server clock.
	SetMarks: (self: View, slot: number, strength: number) -> (),
	-- The slot is in use at this level of the grill (the placeholder plate covers these only).
	SetActive: (self: View, slot: number, active: boolean) -> (),
	-- How many rollers cook (the heat of the placeholder bars follows).
	SetBusy: (self: View, busy: number, total: number) -> (),
	Step: (self: View, dt: number, time: number) -> (),
	Destroy: (self: View) -> (),
}

export type Options = {
	Folder: Folder,
	Rules: Content.PrepWorldRules,
	-- the live slot of the grill / rail (KitchenController:SlotView)
	SlotView: (kind: string, slot: number) -> Slots.Live?,
	Slots: number, -- how many rollers to look for (8)
	-- the juice of the world (pops, bursts, floating words); World.Juice
	Juice: () -> Juice.Juice,
}

type Anim = {
	Kind: string, -- Turn | Shake | Land
	Scales: { number },
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
	Ring: GrillBar.Bar?, -- the flip timing bar (TASK-257)
	Bar: GrillBar.Bar?, -- the cooking progress bar (TASK-257)
	RingKind: Ring,
	Check: HintMark.Mark?,
	CheckOn: boolean,
	Anim: Anim?,
	Hidden: boolean,
	HiddenContainer: Model?,
	Reject: Reject?,
	Known: Model?, -- the container seen last frame (a new one = a sausage landed)
	Marks: { Part },
	MarkStrength: number,
}

const GrillView = {}

const GHOST_PART_ALPHA = 0.85 -- Transparency of the ghost while carried (more solid than the invitation)
const CARRY_SMOOTH = 22 -- 1/s: how fast the carried sausage catches the pointer
const RING_LIFT = 0.7 -- studs over the roller (the flip bar floats clear of the 0.24 sausage)
const BAR_HEIGHT = 0.32 -- studs: the bars (TASK-280: a little thicker, the Ink pill has a channel and a lip)
const BADGE_LIFT = 0.55 -- studs over the sausage where the badge of a flip pops
const CHECK_LIFT = 0.62
const LAND_HEIGHT = 0.4 -- studs a placed sausage falls from
const LAND_TIME = 0.3 -- s
const MARK_X = { -0.25, 0, 0.25, 0.1, -0.1 } -- studs along the sausage where the bars touched it
const MARK_TOP = 0.236 -- studs over the foot of the sausage (its top is 0.24)
const MARK_COLOR = Color3.fromHex("#3A2418")

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
	const perfect = (if tolerance ~= nil then tolerance.Perfect else 7) / 100
	const good = (if tolerance ~= nil then tolerance.Good else 14) / 100
	local lastRotation = CFrame.identity
	local busy, busyTotal = 0, 1
	const activeSlots: { [number]: boolean } = {}
	local seeded = false

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
				Bar = nil,
				RingKind = "None",
				Check = nil,
				CheckOn = false,
				Anim = nil,
				Hidden = false,
				HiddenContainer = nil,
				Reject = nil,
				Known = nil,
				Marks = {},
				MarkStrength = 0,
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

	-- the placeholder bar grill (Parts, named like AST-120); the roller grill of the trailer is hidden meanwhile
	const rig = GrillRig.new({
		Folder = folder,
		Rules = options.Rules,
		PoseOf = poseOf,
		Active = function(slot: number): boolean
			return activeSlots[slot] == true
		end,
		Roller = function(): Model?
			for slot = 1, options.Slots do
				const entry = options.SlotView("grill", slot)
				if entry ~= nil and entry.Spot.Host.Parent ~= nil then
					return entry.Spot.Host:FindFirstAncestorOfClass("Model")
				end
			end
			return nil
		end,
		Slots = options.Slots,
	})

	-- the marks the bars left on the face that was down: a few dark strips across the top of the sausage once it has been flipped
	local function ensureMarks(face: Face): { Part }
		if #face.Marks == 0 or face.Marks[1].Parent == nil then
			for _, mark in face.Marks do
				mark:Destroy()
			end
			table.clear(face.Marks)
			for index = 1, rules.Rig.Marks.Count do
				const mark = Instance.new("Part")
				mark.Name = "GrillMark"
				mark.Anchored = true
				mark.CanCollide = false
				mark.CanQuery = false
				mark.CanTouch = false
				mark.CastShadow = false
				mark.Massless = true
				mark.Material = Enum.Material.SmoothPlastic
				mark.Color = MARK_COLOR
				mark.Size = Vector3.new(rules.Rig.Marks.Width, 0.012, rules.Rig.Marks.Length)
				mark.Transparency = 1
				mark.Parent = folder
				face.Marks[index] = mark
			end
		end
		return face.Marks
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

	local function ensureRing(face: Face): GrillBar.Bar
		local bar = face.Ring
		if bar == nil then
			bar = GrillBar.new()
			face.Ring = bar
		end
		return bar :: GrillBar.Bar
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
		const scales: { number } = {}
		for _, model in models do
			table.insert(bases, model:GetPivot())
			table.insert(scales, model:GetScale())
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
			Scales = scales,
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
		if anim.Kind == "Land" then
			-- falls from LAND_HEIGHT, a small rebound at the end
			const fall = 1 - math.min(t / 0.72, 1)
			const rebound = if t > 0.72 then math.sin((t - 0.72) / 0.28 * math.pi) * 0.06 else 0
			return CFrame.new(0, LAND_HEIGHT * fall * fall + rebound, 0)
		end
		-- Shake: side to side along the roller, dying out
		return CFrame.new(0, 0, math.sin(t * math.pi * 7) * anim.Amount * (1 - t))
	end

	-- the squash of a landing: stretched while it falls, flat at the touch, then settling (1 for the other animations)
	local function scaleOf(anim: Anim, t: number): number
		if anim.Kind ~= "Land" then
			return 1
		end
		if t < 0.72 then
			return 1 + 0.06 * (t / 0.72)
		end
		return 1 + 0.12 * math.sin((t - 0.72) / 0.28 * math.pi * 2) * (1 - (t - 0.72) / 0.28)
	end

	local function finishAnim(face: Face, anim: Anim)
		face.Anim = nil
		for index, model in anim.Models do
			if model.Parent ~= nil then
				if anim.Kind == "Land" then
					model:ScaleTo(anim.Scales[index])
				end
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

	function self.ModelOf(_: any, slot: number, done: boolean?): Instance?
		const face = faces[slot]
		const entry = options.SlotView("grill", slot)
		if entry ~= nil and entry.Container ~= nil then
			-- ONE of the two cross-faded models, never the pair: an outline on both is doubled
			const raw, over = entry.Raw, entry.Over
			if done == true and over ~= nil and over.Parent ~= nil then
				return over
			elseif raw ~= nil and raw.Parent ~= nil then
				return raw
			end
			return entry.Container
		end
		return if face ~= nil then face.Ghost else nil
	end

	function self.SetBusy(_: any, count: number, total: number)
		busy, busyTotal = count, total
	end

	function self.SetActive(_: any, slot: number, active: boolean)
		activeSlots[slot] = active
	end

	function self.SetMarks(_: any, slot: number, strength: number)
		faceOf(slot).MarkStrength = strength
	end

	function self.SetGhost(_: any, slot: number, mode: string)
		const face = faceOf(slot)
		face.GhostMode = mode
		if mode == "None" and face.Ghost ~= nil then
			setAlpha(face.Ghost, 1)
		end
	end

	function self.SetRing(_: any, slot: number, ring: Ring, progress: number, swing: number?)
		const face = faceOf(slot)
		face.RingKind = ring
		const entry = options.SlotView("grill", slot)
		const pose = poseOf(slot)
		const timing = ring == "Converge" or ring == "Late"
		-- the bar that is not wanted pops out (spring), so the swap reads as one bar leaving and the other arriving
		if (ring ~= "Progress" or entry == nil or pose == nil) and face.Bar ~= nil then
			face.Bar:Hide()
		end
		if (not timing or entry == nil or pose == nil) and face.Ring ~= nil then
			face.Ring:Hide()
		end
		if ring == "None" or entry == nil or pose == nil then
			return
		end
		const at = (pose * CFrame.new(0, RING_LIFT, 0)).Position
		if ring == "Progress" then
			-- the cooking bar: Ink pill, Green fill from the left, a Mustard pip at 50% (where the flip comes)
			local bar = face.Bar
			if bar == nil then
				bar = GrillBar.new()
				face.Bar = bar
			end
			const mark = bar :: GrillBar.Bar
			mark:SetProgress(math.clamp(progress, 0, 1))
			mark:SetMark(0.5)
			mark:Show("Cook", at, grill.RingRadius * 2, BAR_HEIGHT)
			return
		end
		-- the flip timing bar (TASK-257): the whole bar is the swing of the cursor, the Good / Perfect bands are the error tolerance
		-- around the middle (tolerance in % of the bar, Grade.FlipScore), the cursor goes end to end until the tap
		const bar = ensureRing(face)
		bar:SetWindow(0.5, math.min(good * 2, 1), math.min(perfect * 2, 1))
		bar:SetCursor(math.clamp(swing or 0, 0, 1))
		bar:Show("Timing", at, grill.RingRadius * 2, BAR_HEIGHT)
	end

	function self.SetCheck(_: any, slot: number, on: boolean)
		const face = faceOf(slot)
		face.CheckOn = on
		const pose = poseOf(slot)
		if not on or pose == nil then
			if face.Check ~= nil then
				face.Check:Hide()
			end
			return
		end
		-- one HintMark per roller, made on first use: a Green disc with a check, in studs, over the sausage (no bars of its own)
		const mark = face.Check or HintMark.new()
		face.Check = mark
		mark:Show("Check", (pose * CFrame.new(0, CHECK_LIFT, 0)).Position, grill.CheckSize)
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

	function self.TakeCarry(_: any): Model?
		const model = carry
		carry = nil
		carryTarget = nil
		carryPose = nil
		return model
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
		options.Juice():Burst("Steam", start.Position + Vector3.new(0, 0.3, 0), 4)
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
		const entry = options.SlotView("grill", slot)
		options.Juice():Grade(band, at, if entry ~= nil then entry.Container else nil, nil)
	end

	function self.FlipResult(_: any, slot: number, band: string, word: string)
		const pose = poseOf(slot)
		if pose == nil then
			return
		end
		const at = pose.Position + Vector3.new(0, 0.3, 0)
		const entry = options.SlotView("grill", slot)
		const juice = options.Juice()
		const face = faceOf(slot)
		const target = if entry ~= nil then entry.Container else nil
		const float = rules.Juice.Float
		const badgeAt = at + Vector3.new(0, BADGE_LIFT, 0)
		-- the pieces of Juice:Grade without its bare floating word: the word is the badge of the kit (TASK-280)
		const run = juice:Note(band)
		if band == "Perfect" then
			juice:Burst("Sparks", at, 14, Theme.Color.Mustard)
			juice:Burst("Ring", at, 10, Theme.Color.Cream)
			juice:Flash(target, Theme.Color.Cream)
			juice:Tone("grill_ready", at, run)
			GrillBar.Badge(band, word, badgeAt, if run >= rules.Juice.Combo.Show then string.format(Content.Prep.Texts.Combo, run) else nil, float.Rise, float.Time + 0.2)
			if face.Bar ~= nil then
				face.Bar:Kick(9)
			end
		elseif band == "Good" then
			juice:Burst("Sparks", at, 6, Theme.Color.Cream)
			juice:Flash(target, Theme.Color.Cream)
			juice:Tone("grill_collect", at, 0)
			GrillBar.Badge(band, word, badgeAt, nil, float.Rise, float.Time + 0.2)
			if face.Bar ~= nil then
				face.Bar:Kick(5)
			end
		else
			juice:Burst("Dust", at, 5)
			juice:Burst("Steam", at, 4)
			GrillBar.Badge(band, word, badgeAt, nil, float.Rise * 0.6, float.Time + 0.2)
			self:Shake(slot, grill.ShakeAmount)
			juice:Tone("error", at, 0)
		end
	end

	function self.Step(_: any, dt: number, time: number)
		rig:Step(dt, busy, busyTotal)
		for slot, face in faces do
			-- a new real sausage on the roller = it landed (the first frame only learns what is already there)
			const live = options.SlotView("grill", slot)
			const container = if live ~= nil then live.Container else nil
			if container ~= face.Known then
				if container ~= nil and seeded and face.Anim == nil and not face.Hidden then
					startAnim(slot, "Land", LAND_TIME, 1, 0)
					const pose = poseOf(slot)
					if pose ~= nil then
						options.Juice():Burst("Dust", pose.Position + Vector3.new(0, 0.05, 0), 6)
						options.Juice():Burst("Steam", pose.Position + Vector3.new(0, 0.15, 0), 3)
					end
				end
				face.Known = container
			end
			-- the grill marks of the flipped face
			if face.MarkStrength > 0 and face.Anim == nil and container ~= nil then
				const pose = poseOf(slot)
				if pose ~= nil then
					const marks = ensureMarks(face)
					for index, mark in marks do
						mark.CFrame = pose * CFrame.new(MARK_X[index] or 0, MARK_TOP, 0)
						mark.Transparency = 1 - 0.82 * math.clamp(face.MarkStrength, 0, 1)
					end
				end
			else
				for _, mark in face.Marks do
					mark.Transparency = 1
				end
			end
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
							if anim.Kind == "Land" then
								model:ScaleTo(anim.Scales[index] * scaleOf(anim, t))
							end
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
		seeded = true
		-- flights to the rail
		for index = #flights, 1, -1 do
			const flight = flights[index]
			flight.T += dt
			const t = math.clamp(flight.T / grill.Collect, 0, 1)
			const position = flight.From.Position:Lerp(flight.To.Position, easeInOut(t)) + Vector3.new(0, grill.CollectArc * math.sin(math.pi * t), 0)
			flight.Model:PivotTo(CFrame.new(position) * flight.To.Rotation)
			if t >= 1 then
				options.Juice():Burst("Sparks", flight.To.Position + Vector3.new(0, 0.25, 0), 5, Theme.Color.Cream)
				options.Juice():Burst("Steam", flight.To.Position + Vector3.new(0, 0.2, 0), 3)
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
		rig:Destroy()
		for _, face in faces do
			for _, mark in face.Marks do
				mark:Destroy()
			end
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
			if face.Bar ~= nil then
				face.Bar:Destroy()
			end
			if face.Check ~= nil then
				face.Check:Destroy()
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
		GrillBar.Clear()
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
