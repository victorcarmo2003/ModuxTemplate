--!strict
--[[
	ChoreService (owner request 2026-10-21, Provisional Q-436; Content.Chores; network.md §13.2b)

	Night chores: small troubles of the shop with no anomaly behind them, drawn a few times a night. Server-authoritative:
	this service draws them, owns their prompts and penalties and writes the Chores set (record = Content.Chores.IndexOf);
	the clients only show them (ChoreController, SecurityController).

	  grill_fire     anchor `Chore_Fire` (fire_out, hold) on the grill model (MapId Chores.Rules.Grill). While it burns the
	                 gate refuses every other prompt of that model.
	  back_door      RestaurantDoorService:SetOpen(door, true): the door swings open by itself. Closing it (its own
	                 door_toggle, any Closed) ends the chore. Skipped while the door is locked (an anomaly holds it).
	  rats           RatCount anchors `Chore_Rat<i>` (rat_shoo, tap) on top of the prep stations (MapIds Chores.Rules.Spots),
	                 one per station; the gate refuses the station's prompts while its rat sits there. Mask = bit per spot.
	  camera_static  one camera of Content.Security.Cams loses its picture (Mask = its index). Anchor `Chore_Camera`
	                 (camera_fix, hold, Radius 22) inside the camera model at its pivot: reached from below, never through a
	                 wall (InSight: head -> anchor, the camera's own model, see-through parts and small props do not block).

	Deadline: Deadline s after the start, if still on, every Active player loses Penalty sanity once (back_door: a family D
	scare for everyone too). Chores stay on until fixed or until the next shift.

	Draw (Night phase only; never under the tutorial hold or the grace, AnomalyService:Held): at most PerNight[night] a
	night, one every Every {min, max} s; never while an anomaly runs (AnomalyService:AnyRunning) nor when the beat budget
	says wait (AnomalyService:BeatClear, owner 2026-10-21; waits Retry s). A chore counts as an active beat until its
	deadline or its end. Dev:
	`/dev chore`.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(ServerScriptService.server.Modux)

const CHORES = Content.Chores
const RULES = CHORES.Rules
const ANCHOR_TAG = "Interactable"
const NIGHT_PHASE = "Night"
const FOLDER = "ChoreAnchors"
const TICK_RATE = 2
const SIGHT_STEPS = 8
const SIGHT_SEE_THROUGH = 0.9
const SIGHT_MIN_SIZE = 2.5
const FIRE_LIFT = 0.8 -- studs above the grill top
const RAT_LIFT = 0.35 -- studs above a station top
const SANITY_CAUSE = "chore"

export type Active = {
	At: number, -- server time it started
	DeadlineAt: number, -- 0 = none
	Paid: boolean,
	Mask: number,
	Anchors: { [Instance]: number }, -- anchor -> spot index (rats) or 0
	Model: Instance?, -- grill model / camera model
}

local function now(): number
	return workspace:GetServerTimeNow()
end

const ChoreService = Modux.Service("ChoreService", {
	Require = {
		"PlaceService",
		"NetService",
		"RoundService",
		"InteractionService",
		"AnomalyService",
		"VitalService",
		"HallucinationService",
		"RestaurantDoorService",
	},
	Priority = 560,
})

function ChoreService:Setup()
	self.Enabled = false :: boolean
	self.Published = false :: boolean
	self.Active = {} :: { [string]: Active }
	self.Count = 0 :: number
	self.Night = 0 :: number
	self.NextAt = 0 :: number
	self.Random = Random.new() :: Random
	self.Models = {} :: { [string]: Instance }
end

-- Map lookups -----------------------------------------------------------------------------------------------------------

-- The Model with this MapId (cached while it stays in the Workspace)
function ChoreService:ModelOf(mapId: string): Model?
	const cached = self.Models[mapId]
	if cached ~= nil and cached:IsDescendantOf(workspace) then
		return cached :: Model
	end
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("MapId") == mapId then
			self.Models[mapId] = d
			return d
		end
	end
	return nil
end

function ChoreService:CameraModel(index: number): Model?
	const cam = Content.Security.Cams.List[index]
	const folder = workspace:FindFirstChild(Content.Security.Rules.Folder)
	const model = if cam ~= nil and folder ~= nil then folder:FindFirstChild(cam.Model) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

local function biggestPart(model: Instance): BasePart?
	local best: BasePart? = nil
	local volume = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			const v = d.Size.X * d.Size.Y * d.Size.Z
			if v > volume then
				volume = v
				best = d
			end
		end
	end
	return best
end

function ChoreService:Folder(): Folder
	const found = workspace:FindFirstChild(FOLDER)
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = workspace
	return folder
end

-- An Interactable Attachment at `at`, inside `host` (a part of the map model, so the sight check ignores that model)
-- or inside a holder Part of the ChoreAnchors folder.
function ChoreService:Anchor(name: string, action: string, at: Vector3, host: BasePart?): Attachment
	local parent: BasePart? = host
	if parent == nil then
		const holder = Instance.new("Part")
		holder.Name = name
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		holder.CFrame = CFrame.new(at)
		holder.Parent = self:Folder()
		parent = holder
	end
	const anchor = Instance.new("Attachment")
	anchor.Name = name
	anchor:SetAttribute("PromptAction", action)
	anchor:SetAttribute("PromptEnabled", true)
	anchor:SetAttribute("Chore", true)
	anchor.Parent = parent
	anchor.WorldPosition = at
	CollectionService:AddTag(anchor, ANCHOR_TAG)
	return anchor
end

local function drop(anchor: Instance)
	const holder = anchor.Parent
	anchor:Destroy()
	if holder ~= nil and holder:IsA("BasePart") and holder.Parent ~= nil and holder.Parent.Name == FOLDER then
		holder:Destroy()
	end
end

-- Records -------------------------------------------------------------------------------------------------------------

function ChoreService:Write(key: string)
	if not self.Published then
		return
	end
	const active = self.Active[key]
	self.Libs.Net.Chores:update(CHORES.IndexOf[key], {
		On = active ~= nil,
		Mask = if active ~= nil then active.Mask else 0,
		At = if active ~= nil then active.At else 0,
	})
end

-- Start / end ---------------------------------------------------------------------------------------------------------

-- false when the map has nothing for it now (no grill, door locked, no camera...)
function ChoreService:Start(key: string): boolean
	if self.Active[key] ~= nil then
		return false
	end
	const row = CHORES.ByKey[key]
	if row == nil then
		return false
	end
	const t = now()
	const active: Active = {
		At = t,
		DeadlineAt = if row.Deadline > 0 then t + row.Deadline else 0,
		Paid = false,
		Mask = 0,
		Anchors = {},
		Model = nil,
	}
	if key == "grill_fire" then
		const model = self:ModelOf(RULES.Grill)
		const host = if model ~= nil then biggestPart(model) else nil
		if model == nil or host == nil then
			return false
		end
		const cf, size = model:GetBoundingBox()
		const at = cf.Position + Vector3.new(0, size.Y / 2 + FIRE_LIFT, 0)
		active.Model = model
		active.Anchors[self:Anchor("Chore_Fire", row.Action, at, host)] = 0
	elseif key == "back_door" then
		const doors = self.Dependencies.RestaurantDoorService
		const door = doors:Door(nil)
		if door == nil or doors:IsLocked() or door.Open then
			return false
		end
		self.Active[key] = active
		doors:SetOpen(door.MapId, true, nil)
	elseif key == "rats" then
		const spots: { number } = {}
		for index, mapId in RULES.Spots do
			if self:ModelOf(mapId) ~= nil then
				table.insert(spots, index)
			end
		end
		if #spots == 0 then
			return false
		end
		for count = 1, math.min(RULES.RatCount, #spots) do
			const pick = table.remove(spots, self.Random:NextInteger(1, #spots)) :: number
			const model = self:ModelOf(RULES.Spots[pick]) :: Model
			const cf, size = model:GetBoundingBox()
			const spread = Vector3.new(
				self.Random:NextNumber(-0.3, 0.3) * size.X,
				0,
				self.Random:NextNumber(-0.25, 0.25) * size.Z
			)
			-- sits on the first surface below the top of the station (a tall part of the model, the wall shelf, must not
			-- leave it floating at the bounding box top)
			const top = cf.Position + spread + Vector3.new(0, size.Y / 2 + 0.5, 0)
			const visible: { Instance } = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 0.9 then
					table.insert(visible, part)
				end
			end
			const params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = visible
			local hit = workspace:Raycast(top, Vector3.new(0, -(size.Y + 1), 0), params)
			if hit == nil then
				hit = workspace:Raycast(cf.Position + Vector3.new(0, size.Y / 2 + 0.5, 0), Vector3.new(0, -(size.Y + 1), 0), params)
			end
			const ground = if hit ~= nil then hit.Position.Y else cf.Position.Y + size.Y / 2
			const at = Vector3.new(top.X, ground + RAT_LIFT, top.Z)
			active.Anchors[self:Anchor(`Chore_Rat{count}`, row.Action, at, nil)] = pick
			active.Mask = bit32.bor(active.Mask, bit32.lshift(1, pick - 1))
		end
	elseif key == "camera_static" then
		const choices: { number } = {}
		for index in Content.Security.Cams.List do
			if self:CameraModel(index) ~= nil then
				table.insert(choices, index)
			end
		end
		if #choices == 0 then
			return false
		end
		const index = choices[self.Random:NextInteger(1, #choices)]
		const model = self:CameraModel(index) :: Model
		const host = biggestPart(model)
		if host == nil then
			return false
		end
		active.Mask = index
		active.Model = model
		active.Anchors[self:Anchor("Chore_Camera", row.Action, model:GetPivot().Position, host)] = 0
	end
	self.Active[key] = active
	self:Write(key)
	return true
end

function ChoreService:End(key: string)
	const active = self.Active[key]
	if active == nil then
		return
	end
	self.Active[key] = nil
	for anchor in active.Anchors do
		drop(anchor)
	end
	self:Write(key)
	self.Dependencies.AnomalyService:BeatEnd(`chore:{key}`)
end

function ChoreService:EndAll()
	for key in self.Active do
		self:End(key)
	end
end

-- Deadline: every Active player pays once
function ChoreService:Penalize(key: string)
	const row = CHORES.ByKey[key]
	const players = self.Dependencies.AnomalyService:ActivePlayers()
	if row.Penalty > 0 then
		for _, player in players do
			self.Dependencies.VitalService:AddSanity(player, -row.Penalty, SANITY_CAUSE)
		end
	end
	if key == "back_door" and #players > 0 then
		self.Dependencies.HallucinationService:Scare(nil, nil)
	end
end

-- Draw ------------------------------------------------------------------------------------------------------------------

function ChoreService:Limit(): number
	const list = RULES.PerNight
	return if self.Night < 1 then 0 else list[math.clamp(self.Night, 1, #list)] or 0
end

function ChoreService:Between(): number
	return self.Random:NextNumber(RULES.Every[1], RULES.Every[2] or RULES.Every[1])
end

-- One chore allowed tonight and not on now, by weight (nil = none)
function ChoreService:Pick(avoid: { [string]: boolean }): string?
	local total = 0
	const pool: { Content.Chore } = {}
	for _, row in CHORES.List do
		if row.FromNight <= self.Night and self.Active[row.Key] == nil and not avoid[row.Key] and row.Weight > 0 then
			table.insert(pool, row)
			total += row.Weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = self.Random:NextNumber() * total
	for _, row in pool do
		roll -= row.Weight
		if roll <= 0 then
			return row.Key
		end
	end
	return pool[#pool].Key
end

-- Starts one drawn chore; tries the others when the map refuses one. Returns the key, nil when none could start.
function ChoreService:DrawOne(): string?
	const avoid: { [string]: boolean } = {}
	for _ = 1, #CHORES.List do
		const key = self:Pick(avoid)
		if key == nil then
			return nil
		end
		if self:Start(key) then
			return key
		end
		avoid[key] = true
	end
	return nil
end

function ChoreService:Step()
	const round = self.Dependencies.RoundService
	if not round:IsStarted() or round:GetPhase() ~= NIGHT_PHASE then
		return
	end
	const t = now()
	for key, active in self.Active do
		if active.DeadlineAt > 0 and not active.Paid and t >= active.DeadlineAt then
			active.Paid = true
			self:Penalize(key)
		end
	end
	const anomalies = self.Dependencies.AnomalyService
	if anomalies:Held(round:Minutes()) or self.Count >= self:Limit() then
		return
	end
	if self.NextAt == 0 then
		self.NextAt = t + self:Between()
		return
	end
	if t < self.NextAt then
		return
	end
	-- the beat budget (AnomalyService:BeatClear, Content.Nights.Beats): no anomaly running, the gap since the last
	-- beat, nothing else asking for action, no regular anomaly due soon
	if anomalies:AnyRunning() or not anomalies:BeatClear("chore") then
		self.NextAt = t + RULES.Retry
		return
	end
	const key = self:DrawOne()
	if key == nil then
		self.NextAt = t + RULES.Retry
		return
	end
	-- active until its deadline (or Beats.Hold with none) or until it ends (End)
	const row = CHORES.ByKey[key]
	anomalies:BeatBegin(`chore:{key}`, if row ~= nil and row.Deadline > 0 then row.Deadline else nil)
	self.Count += 1
	self.NextAt = t + self:Between()
end

function ChoreService:OnShift(info: { Day: number, Night: number, IsNight: boolean, Attempt: number })
	self:EndAll()
	self.Count = 0
	self.NextAt = 0
	self.Night = if info.IsNight then info.Night else 0
	self.Random = Random.new((info.Day * 131 + info.Night * 17 + info.Attempt) * 7919 + os.time() % 100000)
end

-- Checks ----------------------------------------------------------------------------------------------------------------

function ChoreService:Owns(key: string, anchor: Instance): number?
	const active = self.Active[key]
	return if active ~= nil then active.Anchors[anchor] else nil
end

-- Clear line from the player's head to the anchor (same rule as SecurityService / PromptController:InSight)
function ChoreService:InSight(player: Player, anchor: Instance): boolean
	const character = player.Character
	const head = if character ~= nil then character:FindFirstChild("Head") else nil
	if character == nil or head == nil or not head:IsA("BasePart") or not anchor:IsA("Attachment") then
		return false
	end
	const ignore: { Instance } = { character }
	const own = anchor:FindFirstAncestorWhichIsA("Model")
	if own ~= nil then
		table.insert(ignore, own)
	end
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const target = anchor.WorldPosition
	const origin = head.Position
	for _ = 1, SIGHT_STEPS do
		params.FilterDescendantsInstances = ignore
		const offset = target - origin
		if offset.Magnitude < 0.05 then
			return true
		end
		const hit = workspace:Raycast(origin, offset, params)
		if hit == nil then
			return true
		end
		const part = hit.Instance
		if part.Transparency < SIGHT_SEE_THROUGH and math.max(part.Size.X, part.Size.Y, part.Size.Z) >= SIGHT_MIN_SIZE then
			return false
		end
		table.insert(ignore, part)
	end
	return true
end

-- Gate: the grill on fire and a station with a rat refuse their own prompts
function ChoreService:Blocked(action: string, anchor: Instance): string?
	if anchor:GetAttribute("Chore") == true then
		return nil
	end
	const fire = self.Active.grill_fire
	if fire ~= nil and fire.Model ~= nil and anchor:IsDescendantOf(fire.Model) and action ~= "fire_out" then
		return "Fire"
	end
	const rats = self.Active.rats
	if rats ~= nil then
		for _, spot in rats.Anchors do
			const model = self:ModelOf(RULES.Spots[spot])
			if model ~= nil and anchor:IsDescendantOf(model) then
				return "Rats"
			end
		end
	end
	return nil
end

-- Dev -------------------------------------------------------------------------------------------------------------------

function ChoreService:DevDescribe(): string
	const t = now()
	const lines: { string } = {
		`chores {self.Count}/{self:Limit()} (night {self.Night}); next {if self.NextAt == 0
			then "not started"
			else string.format("in %.0fs", math.max(0, self.NextAt - t))}`,
	}
	for _, row in CHORES.List do
		const active = self.Active[row.Key]
		table.insert(
			lines,
			`  {row.Key}: {if active == nil
				then "off"
				else string.format(
					"ON mask %d%s",
					active.Mask,
					if active.DeadlineAt > 0 then string.format(", deadline in %.0fs", active.DeadlineAt - t) else ""
				)}`
		)
	end
	return table.concat(lines, "\n")
end

-- `/dev chore <key>` starts one now (no deadline check of the night), `end <key|all>` ends, `now` draws now
function ChoreService:DevRun(args: { string }): string
	const first = args[1]
	if first == nil or first == "list" then
		return self:DevDescribe()
	end
	if first == "end" then
		if args[2] == nil or args[2] == "all" then
			self:EndAll()
		else
			self:End(args[2])
		end
		return self:DevDescribe()
	end
	if first == "now" then
		const key = self:DrawOne()
		return if key ~= nil then `started {key}` else "nothing could start"
	end
	if CHORES.ByKey[first] == nil then
		return `unknown chore {first} ({table.concat(CHORES.Keys, ", ")})`
	end
	return if self:Start(first) then `started {first}` else `{first} could not start (already on, or nothing on the map)`
end

-- Lifecycle -------------------------------------------------------------------------------------------------------------

ChoreService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true
	const interaction = self.Dependencies.InteractionService
	interaction:RegisterAction("fire_out", {
		Validate = function(_player: Player, anchor: Instance, _id: number): boolean
			return self:Owns("grill_fire", anchor) ~= nil
		end,
		Run = function(_player: Player, _anchor: Instance, _id: number)
			self:End("grill_fire")
		end,
	})
	interaction:RegisterAction("rat_shoo", {
		Validate = function(_player: Player, anchor: Instance, _id: number): boolean
			return self:Owns("rats", anchor) ~= nil
		end,
		Run = function(_player: Player, anchor: Instance, _id: number)
			const active = self.Active.rats
			const spot = if active ~= nil then active.Anchors[anchor] else nil
			if active == nil or spot == nil then
				return
			end
			active.Anchors[anchor] = nil
			active.Mask = bit32.band(active.Mask, bit32.bnot(bit32.lshift(1, spot - 1)))
			drop(anchor)
			if next(active.Anchors) == nil then
				self:End("rats")
			else
				self:Write("rats")
			end
		end,
	})
	interaction:RegisterAction("camera_fix", {
		Validate = function(player: Player, anchor: Instance, _id: number): boolean
			-- the camera is high on the wall: reached from far below, never through a wall
			return self:Owns("camera_static", anchor) ~= nil and self:InSight(player, anchor)
		end,
		Run = function(_player: Player, _anchor: Instance, _id: number)
			self:End("camera_static")
		end,
	})
	interaction:AddGate(RULES.Gate, function(_player: Player, action: string, anchor: Instance): (boolean, string?)
		const reason = self:Blocked(action, anchor)
		return reason == nil, reason
	end)
end)

ChoreService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	for index in CHORES.List do
		self.Libs.Net.Chores:add(index, { On = false, Mask = 0, At = 0 })
	end
	self.Published = true
	const round = self.Dependencies.RoundService
	round.ShiftStarted:Connect(function(info)
		self:OnShift(info)
	end)
	round.PhaseChanged:Connect(function(phase)
		if phase ~= NIGHT_PHASE then
			self:EndAll()
		end
	end)
	self.Dependencies.RestaurantDoorService.Closed:Connect(function(_player, _mapId)
		self:End("back_door")
	end)
end)

ChoreService:OnTick(function(self)
	if self.Enabled then
		self:Step()
	end
end, TICK_RATE)

return ChoreService
