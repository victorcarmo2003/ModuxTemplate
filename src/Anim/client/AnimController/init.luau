--!strict
--[[
	AnimController (TASK-075; architecture.md §19.20, T47; content-data.md §3.20; AST-069; Q-167 d)

	Every animation this client shows, from Content.Animations. No network, ever: the server never plays an
	animation (T47); it only moves rigs and fires events, and each client presents.

	  * NPC locomotion: every `AnimalRig` model that is not a player character (server NPCs of the pool) is bound
	    to the `npc` set automatically. The role (idle / walk / run when the set has it) comes from the horizontal
	    speed of the HumanoidRootPart, measured from its position between ticks (works for physics rigs of the
	    server and for CFrame-driven local actors alike), with hysteresis so it does not flicker.
	  * Animator: the one already under the Humanoid / AnimationController, else one is created HERE, locally
	    (Q-167 d: a local Animator on a server rig plays for this client only; nothing replicates back). The own
	    character never gets a local Animator: PlayOwn uses the one the engine made, so the track replicates.
	  * LOD: farther than 120 studs from the camera or off screen (with a margin) -> the locomotion track stops
	    and the rig is not evaluated; coming back resumes the current role.
	  * Fallback: Id "" (or an id whose preload failed) -> stock R6 clip for locomotion roles, nothing for
	    one-shots; never an error, at most one warn per key (Clips.luau).
	  * Preload: every non-empty id plus the stock R6 locomotion through ContentProvider, once, at start.

	API (for Customer/Opal/Hud/Cutscene controllers):
	  Bind(model, set) -> unbind      locomotion by speed (sets: Content.Animations.Locomotion)
	  Unbind(model)
	  Play(model, key, opts?) -> AnimationTrack?   one-shot / looped action on any rig (local for NPCs and actors)
	  Stop(model, key, fadeTime?)
	  PlayOwn(key, opts?) -> AnimationTrack?       own character (replicates to everyone, §19.20)
	  StopOwn(key, fadeTime?)

	Q-167 d probe: the first time a locomotion track of a server NPC (NpcId attribute) is playing with a loaded
	clip (Length > 0), `Probe` becomes "ok" (printed once in Studio). If LoadAnimation itself fails, the binding is
	marked broken (no retry spam) and `Probe` keeps the error; plan B (Motor6D.Transform procedural) is not built.
]]
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Clips = require(script.Clips)
local Verbose = require(ReplicatedStorage.shared.Verbose)

export type PlayOptions = {
	Looped: boolean?,
	Speed: number?, -- multiplier over the row's Speed
	FadeTime: number?,
	Weight: number?,
}

type Binding = {
	Model: Model,
	Set: string,
	Animator: Animator?,
	Role: string, -- "" = nothing playing (paused or not started)
	Track: AnimationTrack?,
	ClipSpeed: number, -- Speed of the current clip row
	Speed: number, -- smoothed horizontal speed (studs/s)
	Paused: boolean,
	Broken: boolean,
	LastPosition: Vector3?,
	LastAt: number,
	Connections: { RBXScriptConnection },
}

type TrackCache = { [Animator]: { [string]: AnimationTrack } }

const NPC_SET = "npc"
const TICK_RATE = 10 -- Hz
const LOD_DISTANCE = 120 -- studs from the camera (§19.20)
const NEAR_DISTANCE = 8 -- studs: always visible (a rig beside the camera can be off its centre point)
const SCREEN_MARGIN = 0.15 -- fraction of the viewport counted as on screen
const WALK_ON = 0.75 -- studs/s to start walking
const WALK_OFF = 0.35 -- studs/s to go back to idle
const RUN_ON = 18 -- studs/s to start the run role (sets with `run` only)
const RUN_OFF = 16
const SMOOTHING = 0.5 -- weight of the new speed sample
const TELEPORT = 20 -- studs between two ticks = a snap, not a walk
-- PROVISIONAL: playback speed = horizontal speed / reference, as the stock R6 Animate does (speed / 14.5) for
-- the walk. The clips of AST-069 may need their own reference once the user uploads them (TASK-086).
const WALK_REFERENCE = 14.5
const PLAYBACK_MIN = 0.4
const PLAYBACK_MAX = 2
const STOP_FADE = 0.1

const AnimController = Modux.Controller("AnimController", { Priority = 700 })

-- Track of `clip` on `animator`, loaded once per animator and id. nil + error message when LoadAnimation fails.
local function load(cache: TrackCache, animator: Animator, clip: Clips.Clip): (AnimationTrack?, string?)
	local byId = cache[animator]
	if byId == nil then
		byId = {}
		cache[animator] = byId
	end
	const cached = byId[clip.Id]
	if cached ~= nil then
		return cached, nil
	end
	const ok, result = pcall(function(): AnimationTrack
		return animator:LoadAnimation(Clips.Animation(clip.Id))
	end)
	if not ok then
		return nil, tostring(result)
	end
	const track = result :: AnimationTrack
	track.Looped = clip.Looped
	track.Priority = clip.Priority
	byId[clip.Id] = track
	return track, nil
end

local function rootOf(model: Model): BasePart?
	const root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

function AnimController:Setup()
	self.Bindings = {} :: { [Model]: Binding }
	-- models bound by the AnimalRig watcher (only those are unbound when the tag goes away)
	self.Auto = {} :: { [Model]: boolean }
	-- weak keys: a destroyed rig never keeps its tracks alive
	self.Tracks = setmetatable({}, { __mode = "k" }) :: TrackCache
	-- Q-167 d: "pending" until a server NPC plays a loaded clip ("ok"), or the LoadAnimation error
	self.Probe = "pending" :: string
end

-- Animator of a rig: under its Humanoid, else under its AnimationController. `create` makes a local one when
-- missing (never for player characters: a local Animator there would stop the own tracks from replicating).
function AnimController:AnimatorOf(model: Model, create: boolean): Animator?
	const humanoid = model:FindFirstChildOfClass("Humanoid")
	const host: Instance? = humanoid or model:FindFirstChildOfClass("AnimationController")
	if host ~= nil then
		const found = host:FindFirstChildOfClass("Animator")
		if found ~= nil or not create then
			return found
		end
		const animator = Instance.new("Animator")
		animator.Parent = host
		return animator
	end
	if not create then
		return nil
	end
	const controller = Instance.new("AnimationController")
	controller.Name = "AnimationController"
	controller.Parent = model
	const animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

-- Locomotion by speed for `model` with a set of Content.Animations.Locomotion. Returns the unbind function.
function AnimController:Bind(model: Model, set: string): () -> ()
	if not Clips.HasSet(set) then
		return function() end
	end
	const existing = self.Bindings[model]
	if existing ~= nil then
		if existing.Set ~= set then
			self:SetRole(existing, "")
			existing.Set = set
		end
		return function()
			if self.Bindings[model] == existing then
				self:Unbind(model)
			end
		end
	end
	const binding: Binding = {
		Model = model,
		Set = set,
		Animator = nil,
		Role = "",
		Track = nil,
		ClipSpeed = 1,
		Speed = 0,
		Paused = true,
		Broken = false,
		LastPosition = nil,
		LastAt = 0,
		Connections = {},
	}
	table.insert(
		binding.Connections,
		model.Destroying:Connect(function()
			self:Unbind(model)
		end)
	)
	self.Bindings[model] = binding
	return function()
		if self.Bindings[model] == binding then
			self:Unbind(model)
		end
	end
end

function AnimController:Unbind(model: Model)
	const binding = self.Bindings[model]
	if binding == nil then
		return
	end
	self.Bindings[model] = nil
	self.Auto[model] = nil
	for _, connection in binding.Connections do
		connection:Disconnect()
	end
	self:SetRole(binding, "")
end

-- Switches the locomotion role of a binding ("" stops it). `speed` scales walk/run playback.
function AnimController:SetRole(binding: Binding, role: string, speed: number?)
	if role ~= binding.Role then
		const old = binding.Track
		if role == "" then
			if old ~= nil and old.IsPlaying then
				old:Stop(STOP_FADE)
			end
			binding.Role = ""
			binding.Track = nil
			return
		end
		if binding.Broken then
			return
		end
		const clip = Clips.Locomotion(binding.Set, role)
		local track: AnimationTrack? = nil
		if clip ~= nil then
			local animator = binding.Animator
			if animator == nil or animator.Parent == nil then
				animator = self:AnimatorOf(binding.Model, true)
				binding.Animator = animator
			end
			if animator ~= nil then
				const loaded, problem = load(self.Tracks, animator, clip)
				if loaded == nil then
					binding.Broken = true
					self.Probe = `failed: {problem}`
					warn(`[AnimController] Q-167 probe: LoadAnimation failed on {binding.Model:GetFullName()}: {problem}`)
				end
				track = loaded
			end
		end
		if old ~= nil and old ~= track and old.IsPlaying then
			old:Stop(if clip ~= nil then clip.FadeTime else STOP_FADE)
		end
		binding.Role = role
		binding.Track = track
		binding.ClipSpeed = if clip ~= nil then clip.Speed else 1
		if track ~= nil and clip ~= nil and not track.IsPlaying then
			track:Play(clip.FadeTime, 1, clip.Speed)
		end
	end
	const track = binding.Track
	if track ~= nil and speed ~= nil and (role == "walk" or role == "run") then
		track:AdjustSpeed(binding.ClipSpeed * math.clamp(speed / WALK_REFERENCE, PLAYBACK_MIN, PLAYBACK_MAX))
	end
end

-- Role for a smoothed speed, with hysteresis around the current one.
function AnimController:RoleFor(binding: Binding, speed: number): string
	const current = binding.Role
	if Clips.HasRole(binding.Set, "run") then
		const runOn = if current == "run" then RUN_OFF else RUN_ON
		if speed >= runOn then
			return "run"
		end
	end
	const walkOn = if current == "walk" or current == "run" then WALK_OFF else WALK_ON
	return if speed >= walkOn then "walk" else "idle"
end

-- LOD: within LOD_DISTANCE of the camera and on screen (with a margin).
function AnimController:IsVisible(position: Vector3, camera: Camera?): boolean
	if camera == nil then
		return false
	end
	const distance = (camera.CFrame.Position - position).Magnitude
	if distance > LOD_DISTANCE then
		return false
	end
	if distance <= NEAR_DISTANCE then
		return true
	end
	const point = camera:WorldToViewportPoint(position)
	if point.Z <= 0 then
		return false
	end
	const size = camera.ViewportSize
	const marginX = size.X * SCREEN_MARGIN
	const marginY = size.Y * SCREEN_MARGIN
	return point.X >= -marginX and point.X <= size.X + marginX and point.Y >= -marginY and point.Y <= size.Y + marginY
end

function AnimController:Step(binding: Binding, camera: Camera?, now: number)
	const model = binding.Model
	if Players:GetPlayerFromCharacter(model) ~= nil then
		-- a crew character tagged AnimalRig: its Animate script owns the locomotion
		self:Unbind(model)
		return
	end
	const root = rootOf(model)
	if root == nil or not model:IsDescendantOf(Workspace) then
		if not binding.Paused then
			binding.Paused = true
			self:SetRole(binding, "")
		end
		binding.LastPosition = nil
		return
	end

	const position = root.Position
	const last = binding.LastPosition
	const elapsed = now - binding.LastAt
	local sample = 0
	if last ~= nil and elapsed > 0 then
		const moved = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
		if moved < TELEPORT then
			sample = moved / elapsed
		end
	end
	binding.LastPosition = position
	binding.LastAt = now
	binding.Speed += (sample - binding.Speed) * SMOOTHING

	if not self:IsVisible(position, camera) then
		if not binding.Paused then
			binding.Paused = true
			self:SetRole(binding, "")
		end
		return
	end
	binding.Paused = false
	self:SetRole(binding, self:RoleFor(binding, binding.Speed), binding.Speed)

	const track = binding.Track
	if self.Probe == "pending" and track ~= nil and track.IsPlaying and track.Length > 0 then
		if model:GetAttribute("NpcId") ~= nil then
			self.Probe = "ok"
			if RunService:IsStudio() and Verbose.On() then
				print(`[AnimController] Q-167 probe ok: local Animator plays "{binding.Role}" on server NPC {model:GetFullName()}`)
			end
		end
	end
end

-- One-shot (or looped action) of Content.Animations on any rig. nil = empty id, unknown key or no Animator.
function AnimController:Play(model: Model, key: string, opts: PlayOptions?): AnimationTrack?
	const clip = Clips.Action(key)
	if clip == nil then
		return nil
	end
	const animator = self:AnimatorOf(model, Players:GetPlayerFromCharacter(model) == nil)
	if animator == nil then
		return nil
	end
	const track = load(self.Tracks, animator, clip)
	if track == nil then
		return nil
	end
	const o: PlayOptions = opts or {}
	track.Looped = if o.Looped ~= nil then o.Looped else clip.Looped
	track:Play(o.FadeTime or clip.FadeTime, o.Weight or 1, clip.Speed * (o.Speed or 1))
	return track
end

function AnimController:Stop(model: Model, key: string, fadeTime: number?)
	const clip = Clips.Action(key)
	if clip == nil then
		return
	end
	const animator = self:AnimatorOf(model, false)
	const byId = if animator ~= nil then self.Tracks[animator] else nil
	const track = if byId ~= nil then byId[clip.Id] else nil
	if track ~= nil and track.IsPlaying then
		track:Stop(fadeTime or clip.FadeTime)
	end
end

-- One-shot on the own character, through the engine's Animator (replicates to everyone, §19.20).
function AnimController:PlayOwn(key: string, opts: PlayOptions?): AnimationTrack?
	const character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return self:Play(character, key, opts)
end

function AnimController:StopOwn(key: string, fadeTime: number?)
	const character = Players.LocalPlayer.Character
	if character ~= nil then
		self:Stop(character, key, fadeTime)
	end
end

-- AnimalRig watcher: server NPCs get the `npc` set. Deferred, so a player character has its Player link first
-- (Step unbinds it anyway if the link arrives later).
function AnimController:Watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	const model = instance
	task.defer(function()
		if self.Bindings[model] ~= nil or Players:GetPlayerFromCharacter(model) ~= nil then
			return
		end
		if not CollectionService:HasTag(model, CrewRig.Tag) then
			return
		end
		self:Bind(model, NPC_SET)
		if self.Bindings[model] ~= nil then
			self.Auto[model] = true
		end
	end)
end

function AnimController:Unwatch(instance: Instance)
	if instance:IsA("Model") and self.Auto[instance] then
		self:Unbind(instance)
	end
end

-- Async, best effort: failed ids fall back from then on (Clips.Report).
function AnimController:Preload()
	const list = Clips.PreloadList()
	if #list == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
				Clips.Report(contentId, status == Enum.AssetFetchStatus.Success)
			end)
		end)
	end)
end

AnimController:OnInit(function(self)
	self:Setup()
end)

AnimController:OnStart(function(self)
	self:Preload()
	CollectionService:GetInstanceAddedSignal(CrewRig.Tag):Connect(function(instance: Instance)
		self:Watch(instance)
	end)
	CollectionService:GetInstanceRemovedSignal(CrewRig.Tag):Connect(function(instance: Instance)
		self:Unwatch(instance)
	end)
	for _, instance in CollectionService:GetTagged(CrewRig.Tag) do
		self:Watch(instance)
	end
end)

AnimController:OnTick(function(self)
	const camera = Workspace.CurrentCamera
	const now = os.clock()
	for _, binding in self.Bindings do
		self:Step(binding, camera, now)
	end
end, TICK_RATE)

return AnimController
