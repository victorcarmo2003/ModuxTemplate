--!strict
-- Rig: what the focused prep camera must NOT see (docs/art/prep-ui-spec.md §13.3 to §13.6). Presentation only, local only:
-- `LocalTransparencyModifier` (never `Transparency`, which replicates and is used by anomalies and animations).
--   own rig     hidden whole (body, head, ears, tail, accessories, Tool handles) with a 0.15 s fade; the head would sit about
--               1.1 studs from the camera and cover the bottom of the frame. Comes back at the start of the way out.
--   NPCs        customers and crew rigs, judged at 10 Hz against the segment S from the camera to 8 studs past the plate
--               (the line of sight and what is behind the window):
--                 d <= 2.5   Cut     fully hidden (and their name tag off)
--                 d <= 4.5   Ghost   75 % see-through (a faint silhouette that cannot cover the board)
--                 else       Normal
--               a 0.4 stud hysteresis keeps a rig on the border from flickering; every change fades in 0.15 s
--   other players in a neighbouring station: the same rule, plus: inside 5 studs of the camera they are Cut
-- Anomaly safe: hiding is local and only inside this frame; a hidden NPC is not "seen" (the gaze of the server is the camera
-- look, which the Prep mode does not send). Nothing glows or points at an anomalous NPC. Everything is restored in Release.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

export type Rig = {
	-- Starts hiding the own rig and judging the NPCs against `camera` -> `focus`.
	Enter: (self: Rig, camera: Vector3, focus: Vector3) -> (),
	-- Moves the pose (another station) without a fade.
	SetPose: (self: Rig, camera: Vector3, focus: Vector3) -> (),
	-- The NPC (attribute `NpcId`) that is never cut or ghosted while it is set: the customer at the counter in the 3D Window view
	-- (prep-3d.md §4.4, he is the target of the Take). nil = judged like everybody else.
	SetSpared: (self: Rig, npc: number?) -> (),
	-- Own rig starts to come back (60 % of the way out); NPCs return too.
	Release: (self: Rig) -> (),
	-- Per rendered frame.
	Step: (self: Rig, dt: number) -> (),
	-- True once everything is back to 0 (nothing left to restore).
	Idle: (self: Rig) -> boolean,
	-- Everything back at once.
	Destroy: (self: Rig) -> (),
}

type Zone = "Cut" | "Ghost" | "Normal"

type Tracked = {
	Model: Model,
	Zone: Zone,
	Alpha: number,
	Parts: { BasePart },
	PartsAt: number,
	Written: number,
	Display: Enum.HumanoidDisplayDistanceType?,
}

const FADE = 0.15
const CUT_LIMIT = 2.5
const GHOST_LIMIT = 4.5
const HYSTERESIS = 0.4
const NEIGHBOUR_REACH = 5
const WINDOW_DEPTH = 8
const JUDGE_INTERVAL = 0.1
const PARTS_REFRESH = 2
const GHOST_ALPHA = 0.75
const TARGET: { [Zone]: number } = { Cut = 1, Ghost = GHOST_ALPHA, Normal = 0 }

const Rig = {}

local function partsOf(model: Model): { BasePart }
	const out: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(out, descendant)
		end
	end
	return out
end

-- Distance from `point` to the segment a-b.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	const ab = b - a
	const length2 = ab:Dot(ab)
	if length2 < 1e-6 then
		return (point - a).Magnitude
	end
	const t = math.clamp((point - a):Dot(ab) / length2, 0, 1)
	return (point - (a + ab * t)).Magnitude
end

local function zoneOf(distance: number, current: Zone): Zone
	const cutLimit = CUT_LIMIT + (if current == "Cut" then HYSTERESIS else 0)
	const ghostLimit = GHOST_LIMIT + (if current ~= "Normal" then HYSTERESIS else 0)
	if distance <= cutLimit then
		return "Cut"
	elseif distance <= ghostLimit then
		return "Ghost"
	end
	return "Normal"
end

local function write(parts: { BasePart }, value: number)
	for _, part in parts do
		if part.Parent ~= nil and part.LocalTransparencyModifier ~= value then
			part.LocalTransparencyModifier = value
		end
	end
end

function Rig.new(): Rig
	local camera = Vector3.zero
	local focus = Vector3.zero
	local entered = false
	local released = false
	-- own rig
	local ownAlpha = 0
	local ownTarget = 0
	local ownCharacter: Model? = nil
	local ownParts: { BasePart } = {}
	local ownPartsAt = 0
	-- NPCs and other players
	const tracked: { [Model]: Tracked } = {}
	local judgeIn = 0
	local spared: number? = nil

	local function refreshOwn(now: number)
		const character = Players.LocalPlayer.Character
		if character ~= ownCharacter or now - ownPartsAt >= PARTS_REFRESH then
			ownCharacter = character
			ownPartsAt = now
			ownParts = if character ~= nil then partsOf(character) else {}
		end
	end

	local function candidates(): { Model }
		const list: { Model } = {}
		const own = Players.LocalPlayer.Character
		for _, instance in CollectionService:GetTagged("AnimalRig") do
			if instance:IsA("Model") and instance ~= own then
				table.insert(list, instance)
			end
		end
		for _, player in Players:GetPlayers() do
			const character = player.Character
			if player ~= Players.LocalPlayer and character ~= nil and not table.find(list, character) then
				table.insert(list, character)
			end
		end
		return list
	end

	local function judge(now: number)
		const flat = Vector3.new(focus.X - camera.X, 0, focus.Z - camera.Z)
		const sightEnd = focus + (if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero) * WINDOW_DEPTH
		const seen: { [Model]: boolean } = {}
		for _, model in candidates() do
			seen[model] = true
			const root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if root == nil or not root:IsA("BasePart") then
				continue
			end
			local found: Tracked
			const existing = tracked[model]
			if existing == nil then
				const created: Tracked = {
					Model = model,
					Zone = "Normal",
					Alpha = 0,
					Parts = partsOf(model),
					PartsAt = now,
					Written = 0,
					Display = nil,
				}
				tracked[model] = created
				found = created
			else
				found = existing
				if now - found.PartsAt >= PARTS_REFRESH then
					found.Parts = partsOf(model)
					found.PartsAt = now
				end
			end
			local distance = distanceToSegment(root.Position, camera, sightEnd)
			const isPlayer = Players:GetPlayerFromCharacter(model) ~= nil
			if released then
				found.Zone = "Normal"
			else
				if isPlayer and (root.Position - camera).Magnitude <= NEIGHBOUR_REACH then
					distance = 0
				end
				found.Zone = zoneOf(distance, found.Zone)
				if spared ~= nil and model:GetAttribute("NpcId") == spared then
					found.Zone = "Normal"
				end
			end
			-- the name tag goes with a hidden rig
			const humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				if found.Zone == "Cut" then
					if found.Display == nil then
						found.Display = humanoid.DisplayDistanceType
					end
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				elseif found.Display ~= nil then
					humanoid.DisplayDistanceType = found.Display
					found.Display = nil
				end
			end
		end
		for model, entry in tracked do
			if not seen[model] or model.Parent == nil then
				tracked[model] = nil
				write(entry.Parts, 0)
			end
		end
	end

	const self = {} :: any

	function self.Enter(_: any, cameraPosition: Vector3, focusPosition: Vector3)
		camera = cameraPosition
		focus = focusPosition
		entered = true
		released = false
		ownTarget = 1
		judgeIn = 0
	end
	function self.SetPose(_: any, cameraPosition: Vector3, focusPosition: Vector3)
		camera = cameraPosition
		focus = focusPosition
		judgeIn = 0
	end
	function self.SetSpared(_: any, npc: number?)
		if npc ~= spared then
			spared = npc
			judgeIn = 0
		end
	end
	function self.Release(_: any)
		released = true
		ownTarget = 0
		judgeIn = 0
	end
	function self.Step(_: any, dt: number)
		if not entered then
			return
		end
		const now = os.clock()
		const rate = dt / FADE
		-- own rig
		refreshOwn(now)
		if ownAlpha ~= ownTarget then
			ownAlpha = if ownAlpha < ownTarget then math.min(ownAlpha + rate, ownTarget) else math.max(ownAlpha - rate, ownTarget)
		end
		if ownAlpha > 0 or ownTarget > 0 or ownPartsAt == now then
			write(ownParts, ownAlpha)
		end
		-- the others, judged at 10 Hz and faded every frame
		judgeIn -= dt
		if judgeIn <= 0 then
			judgeIn = JUDGE_INTERVAL
			judge(now)
		end
		local busy = false
		for model, entry in tracked do
			const target = TARGET[entry.Zone]
			if entry.Alpha ~= target then
				entry.Alpha = if entry.Alpha < target then math.min(entry.Alpha + rate, target) else math.max(entry.Alpha - rate, target)
			end
			if entry.Alpha ~= entry.Written or entry.Alpha > 0 then
				write(entry.Parts, entry.Alpha)
				entry.Written = entry.Alpha
			end
			if entry.Alpha > 0 then
				busy = true
			elseif released and entry.Alpha == 0 then
				if entry.Display ~= nil then
					const humanoid = model:FindFirstChildOfClass("Humanoid")
					if humanoid ~= nil then
						humanoid.DisplayDistanceType = entry.Display
					end
					entry.Display = nil
				end
				tracked[model] = nil
			end
		end
		if released and ownAlpha == 0 and not busy then
			write(ownParts, 0)
			entered = false
		end
	end
	function self.Idle(_: any): boolean
		return not entered
	end
	function self.Destroy(_: any)
		write(ownParts, 0)
		for model, entry in tracked do
			write(entry.Parts, 0)
			if entry.Display ~= nil then
				const humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid ~= nil then
					humanoid.DisplayDistanceType = entry.Display
				end
			end
			tracked[model] = nil
		end
		entered = false
		ownAlpha = 0
		ownTarget = 0
		spared = nil
	end
	return self :: Rig
end

return Rig
