--!strict
--[[
	OpalController (TASK-038, TASK-077; NPC-020, CHR-003; DEC-079, DEC-099, DEC-178, DEC-191, DEC-203; architecture.md §2.3)

	Opal, the Ninth Street Mart clerk, exists only on this client:
	  * built once with CrewRig.Build at MapPoint OP-1 (architecture.md §18.5: HumanoidRootPart at point + 3 studs,
	    facing the point's front), anchored, untagged (`Tag = false`), so RigController never dresses her (the low
	    band no longer dresses NPCs Night anyway, Provisional 2026-10-14). Dressed here once: Day pack, Normal face;
	  * no Humanoid: the Humanoid Build adds is removed (§2.3); AnimController (TASK-075) makes the local
	    AnimationController + Animator and loops `opal_idle` of Content.Animations (AST-057 `Opal_Crossword`).
	    Id "" -> the `npc` locomotion set binds her instead, which idles with the stock R6 idle while `npc_idle`
	    is empty too (§19.26 A8). No animation id lives in this file;
	  * talks: when the local character enters the 8-stud radius of OP-1, one balloon (3 s) with a line drawn from
	    Content.OpalLines for the current phase (day / nights 1-3 / 4-6 / 7-10), never the same as this player's
	    last line. One balloon per visit, at most one every 90 s (NPC-020). The balloon is local, so only the player
	    who entered sees it.

	Mart v2 (TASK-141; Q-175 A Provisional): Opal stands behind the short counter in the middle of the Gear Stand and
	still sells nothing (no prompt). Spawn point, first found: Attachment/Part `Att_Opal` inside the Gear Stand model
	(searched in the Model ancestors of the `GearPedestal` instances, TASK-137 fitting; its front = LookVector),
	else MapPoint OP-1 (moved to the counter by TASK-138). No position constant lives here. No balloon while the
	kiosk shutter is down (Content.Mart.KioskClosedPhases: door C in front of her is closed); a visit only counts
	with the shutter up. The optional purchase line (pool "Purchase", TASK-142) is not wired: the pool does not exist.

	Zero network: no Net, no set, no packet. Reads RoundController sources only (IsNight, Night, Phase: TASK-055).
	Outside the NPC cap of 12 (DEC-191: no server rig at all) and never an anomaly nor an anomaly anchor: there is
	no hook here for AnomalyController, on purpose.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local SpeechBalloon = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SpeechBalloon)

type OpalPool = Content.OpalPool

const POINT_ID = "OP-1"
const COUNTER_FITTING = "Att_Opal" -- Gear Stand counter (TASK-137), preferred over OP-1
const KIOSK_SEARCH_DEPTH = 4 -- Model ancestors of a pedestal searched for the fitting
const KIOSK_CLOSED: { [string]: boolean } = {}
for _, phase in Content.Mart.KioskClosedPhases do
	KIOSK_CLOSED[phase] = true
end
const SPECIES = "owl" -- DEC-203
-- PROVISIONAL (AST-057 sheet is Draft): no Opal outfit in the kit yet (Mart vest, green cardigan, glasses on a
-- chain); a civil outfit without the crew cap stands in until the art-director's sheet ships.
const OUTFIT = "civil_a"
const PACK: CrewRig.Pack = "Day" -- the Mart never goes dark (NPC-020); never Night
const FACE = "Normal"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const IDLE_KEY = "opal_idle" -- Content.Animations (AST-057 Opal_Crossword)
-- PROVISIONAL (§19.26 A8: empty id = R6 idle): Opal has no locomotion set of her own; the `npc` set idles with
-- the stock R6 clip while its ids are empty. She is anchored, so the set never leaves `idle`.
const FALLBACK_SET = "npc"

const RADIUS = 8 -- studs from OP-1 (NPC-020, architecture.md §18.5)
const EXIT_MARGIN = 1 -- leave only past RADIUS + margin, so standing on the edge is one visit
const COOLDOWN = 90 -- seconds between balloons for this player (NPC-020)
const BALLOON_TIME = 3 -- seconds (NPC-020, style guide "Falas em balão")
const BALLOON_OFFSET = Vector3.new(0, 2.6, 0)
const BALLOON_DISTANCE = 30
const TICK_RATE = 5 -- Hz; walking speed 16 crosses the 1-stud margin in ~0.06 s, 0.2 s is a short delay at most
const NEVER = -math.huge -- LastSpokeAt before the first balloon
const MAP_WAIT = 60 -- seconds MapIndex.WaitReady may wait for streaming
const FIRST_NIGHT = 1
const LAST_NIGHT = Content.RunParams.Nights

const OpalController =
	Modux.Controller("OpalController", { Require = { "RoundController", "AnimController" }, Priority = 600 })

function OpalController:Setup()
	self.Model = nil :: Model?
	self.Origin = nil :: Vector3?
	self.Inside = false :: boolean
	self.LastSpokeAt = NEVER :: number
	self.LastLine = nil :: string?
	self.Random = Random.new() :: Random
	self.Line = Vide.source("") :: Vide.Source<string>
	self.Talking = Vide.source(false) :: Vide.Source<boolean>
	self.HideThread = nil :: thread?
	self.Unmount = nil :: (() -> ())?
	self.UnbindIdle = nil :: (() -> ())?
end

-- Night number of the shift (RoundController.Night, TASK-055; 0 on day shifts). Unknown at night -> first night.
function OpalController:NightNumber(): number
	const value = self.Dependencies.RoundController.Night()
	if value < FIRST_NIGHT then
		return FIRST_NIGHT
	end
	return math.min(value, LAST_NIGHT)
end

-- Pool of the current phase (Content.OpalLines: FromNight 0 = day).
function OpalController:CurrentPool(): OpalPool?
	const isNight = self.Dependencies.RoundController.IsNight()
	const night = if isNight then self:NightNumber() else 0
	for _, pool in Content.OpalLines.List do
		if night >= pool.FromNight and night <= pool.ToNight then
			return pool
		end
	end
	return nil
end

-- Random line of the pool, never this player's last one (when the pool has another).
function OpalController:DrawLine(pool: OpalPool): string?
	const lines = pool.Lines
	if #lines == 0 then
		return nil
	end
	const candidates: { string } = {}
	for _, line in lines do
		if line ~= self.LastLine then
			table.insert(candidates, line)
		end
	end
	if #candidates == 0 then
		return lines[1]
	end
	return candidates[self.Random:NextInteger(1, #candidates)]
end

function OpalController:Speak()
	const pool = self:CurrentPool()
	const line = if pool then self:DrawLine(pool) else nil
	if line == nil then
		return
	end
	self.LastLine = line
	self.LastSpokeAt = os.clock()
	const previous = self.HideThread
	if previous ~= nil and coroutine.status(previous) == "suspended" then
		task.cancel(previous)
	end
	Vide.batch(function()
		self.Line(line)
		self.Talking(true)
	end)
	self.HideThread = task.delay(BALLOON_TIME, function()
		self.HideThread = nil
		self.Talking(false)
	end)
end

-- Kiosk shutter down (door C in front of the counter): no balloon (FEAT-015 v2, Q-176 A). Business hours (owner
-- request 2026-10-17): the server's Workspace attribute Content.Mart.Hours.Attributes.Open; before it is published,
-- the always-closed phases.
function OpalController:KioskClosed(): boolean
	const open = workspace:GetAttribute(Content.Mart.Hours.Attributes.Open)
	if type(open) == "boolean" then
		return not open
	end
	return KIOSK_CLOSED[Vide.untrack(self.Dependencies.RoundController.Phase)] == true
end

-- Visit tracking: entering the radius is a visit; one balloon per visit, respecting the cooldown. With the shutter
-- down nobody is "inside": the visit starts when it goes up.
function OpalController:Check()
	const origin = self.Origin
	if origin == nil then
		return
	end
	if self:KioskClosed() then
		self.Inside = false
		if Vide.untrack(self.Talking) then
			self.Talking(false)
		end
		return
	end
	const character = Players.LocalPlayer.Character
	const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		self.Inside = false
		return
	end
	const distance = (root.Position - origin).Magnitude
	if self.Inside then
		if distance > RADIUS + EXIT_MARGIN then
			self.Inside = false
		end
		return
	end
	if distance <= RADIUS then
		self.Inside = true
		if os.clock() - self.LastSpokeAt >= COOLDOWN then
			self:Speak()
		end
	end
end

-- Drops the Humanoid from Build (§2.3) and loops the idle through AnimController (it makes the local
-- AnimationController + Animator). Empty / failed id -> the fallback set (stock R6 idle).
function OpalController:Animate(model: Model)
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	const anim = self.Dependencies.AnimController
	if anim:Play(model, IDLE_KEY, { Looped = true }) == nil then
		self.UnbindIdle = anim:Bind(model, FALLBACK_SET)
	end
end

function OpalController:Mount(point: CFrame)
	const options: CrewRig.BuildOptions = {
		Name = "Opal",
		CFrame = point + SPAWN_LIFT,
		Anchored = true,
		Tag = false,
		LookPack = PACK,
		Cap = false,
	}
	const ok, result = pcall(function(): Model
		return CrewRig.Build(SPECIES, OUTFIT, options)
	end)
	if not ok then
		warn(`[OpalController] could not build Opal: {result}`)
		return
	end
	const model = result :: Model
	model.Parent = Workspace
	self.Model = model
	CrewRig.Dress(model, PACK, FACE)
	self:Animate(model)

	const head = model:FindFirstChild("Head")
	const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	const unmount, gui = Vide.root(function()
		return SpeechBalloon({
			Name = "OpalBalloon",
			Adornee = head or model.PrimaryPart,
			Visible = function()
				return self.Talking()
			end,
			Text = function()
				return self.Line()
			end,
			StudsOffset = BALLOON_OFFSET,
			MaxDistance = BALLOON_DISTANCE,
		})
	end)
	gui.Parent = playerGui
	self.Unmount = function()
		unmount()
		gui:Destroy()
	end
	self.Origin = point.Position
end

-- Counter fitting `Att_Opal` in the Gear Stand (Model ancestors of a GearPedestal), as a CFrame facing its front.
local function counterPoint(): CFrame?
	for _, pedestal in CollectionService:GetTagged(Content.Mart.Tags.Pedestal) do
		if not pedestal:IsDescendantOf(Workspace) then
			continue
		end
		local node: Instance? = pedestal.Parent
		local depth = 0
		while node ~= nil and node ~= Workspace and depth < KIOSK_SEARCH_DEPTH do
			if node:IsA("Model") then
				const fitting = node:FindFirstChild(COUNTER_FITTING, true)
				if fitting and fitting:IsA("Attachment") then
					const cf = fitting.WorldCFrame
					return CFrame.lookAt(cf.Position, cf.Position + cf.LookVector * Vector3.new(1, 0, 1))
				elseif fitting and fitting:IsA("BasePart") then
					return CFrame.lookAt(fitting.Position, fitting.Position + fitting.CFrame.LookVector * Vector3.new(1, 0, 1))
				end
			end
			node = node.Parent
			depth += 1
		end
	end
	return nil
end

OpalController:OnInit(function(self)
	self:Setup()
end)

OpalController:OnStart(function(self)
	-- The map streams in after boot: wait off the start chain.
	task.spawn(function()
		if not MapIndex.WaitReady(MAP_WAIT) then
			warn("[OpalController] map binding not ready: Opal not placed")
			return
		end
		const point = counterPoint() or MapIndex.FindPoint(POINT_ID)
		if point == nil then
			warn(`[OpalController] no {COUNTER_FITTING} in the Gear Stand and MapPoint {POINT_ID} missing: Opal not placed`)
			return
		end
		self:Mount(point)
	end)
end)

OpalController:OnTick(function(self)
	self:Check()
end, TICK_RATE)

return OpalController
