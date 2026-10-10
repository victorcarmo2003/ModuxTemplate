--!strict
--[[
	OpalController (TASK-038; NPC-020, CHR-003; DEC-079, DEC-099, DEC-178, DEC-191, DEC-203; architecture.md §2.3)

	Opal, the Ninth Street Mart clerk, exists only on this client:
	  * built once with CrewRig.Build at MapPoint OP-1 (architecture.md §18.5: HumanoidRootPart at point + 3 studs,
	    facing the point's front), anchored, untagged (`Tag = false`), so RigController never dresses her and the
	    local low-band Night swap (DEC-168) never reaches her. Dressed here once: Day pack, Normal face;
	  * no Humanoid: the Humanoid Build adds is replaced by an AnimationController + Animator (§2.3) playing a
	    looped idle;
	  * talks: when the local character enters the 8-stud radius of OP-1, one balloon (3 s) with a line drawn from
	    Content.OpalLines for the current phase (day / nights 1-3 / 4-6 / 7-10), never the same as this player's
	    last line. One balloon per visit, at most one every 90 s (NPC-020). The balloon is local, so only the player
	    who entered sees it.

	Zero network: no Net, no set, no packet. Reads RoundController sources only (IsNight, and Night when it exists).
	Outside the NPC cap of 12 (DEC-191: no server rig at all) and never an anomaly nor an anomaly anchor: there is
	no hook here for AnomalyController, on purpose.
]]
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
const SPECIES = "owl" -- DEC-203
-- PROVISIONAL (AST-057 sheet is Rascunho): no Opal outfit in the kit yet (Mart vest, green cardigan, glasses on a
-- chain); a civil outfit without the crew cap stands in until the art-director's sheet ships.
const OUTFIT = "civil_a"
const PACK: CrewRig.Pack = "Day" -- the Mart never goes dark (NPC-020); not affected by the local Night swap
const FACE = "Normal"
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
-- PROVISIONAL: stock R6 idle (Roblox-owned) until the crossword idle of AST-057 exists.
const IDLE_ANIMATION = "rbxassetid://180435571"

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

const OpalController = Modux.Controller("OpalController", { Require = { "RoundController" }, Priority = 600 })

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
end

-- Night number of the shift. RoundController exposes no Night source in wave 1 (Shift.Night is always 0 there);
-- once it does, this reads it. Unknown at night -> first night.
function OpalController:NightNumber(): number
	const getter: unknown = (self.Dependencies.RoundController :: any).Night
	if type(getter) == "function" then
		const value = (getter :: () -> unknown)()
		if typeof(value) == "number" and value >= FIRST_NIGHT then
			return math.min(value, LAST_NIGHT)
		end
	end
	return FIRST_NIGHT
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

-- Visit tracking: entering the radius is a visit; one balloon per visit, respecting the cooldown.
function OpalController:Check()
	const origin = self.Origin
	if origin == nil then
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

-- Replaces the Humanoid from Build with an AnimationController and loops the idle.
function OpalController:Animate(model: Model)
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:Destroy()
	end
	const controller = Instance.new("AnimationController")
	controller.Name = "AnimationController"
	controller.Parent = model
	const animator = Instance.new("Animator")
	animator.Parent = controller
	const animation = Instance.new("Animation")
	animation.Name = "Idle"
	animation.AnimationId = IDLE_ANIMATION
	const ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Idle
		track:Play()
	else
		warn(`[OpalController] idle animation failed to load: {track}`)
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
		const point = MapIndex.FindPoint(POINT_ID)
		if point == nil then
			warn(`[OpalController] MapPoint {POINT_ID} missing: Opal not placed`)
			return
		end
		self:Mount(point)
	end)
end)

OpalController:OnTick(function(self)
	self:Check()
end, TICK_RATE)

return OpalController
