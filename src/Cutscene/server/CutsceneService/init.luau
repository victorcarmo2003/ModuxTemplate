--!strict
-- Cutscenes: opening and dawn of Night 10 (architecture.md §19.16, R23; network.md §6.2, §13.7; FEAT-004, FEAT-027;
-- script.md §1; ending.md §2; DEC-078, DEC-088, DEC-194, DEC-205; TASK-120). Run place only. Single writer of the
-- Cutscene set (record 1; Scene = "none" when idle).
--
-- Trigger: RoundService phase probes. PhaseChanged("Intro") plays "intro"; PhaseChanged("Finale") plays "finale"
-- and then its Next ("credits") as a new segment with 0 votes. The probe says "can end" once the chain is over, so
-- the phase ends early; the phase cap still wins (leaving the phase stops the scene).
-- Participants: members connected (not Away) when the chain starts, in roster order (slot 1..4). A late member is
-- not one: no vote, no freeze; during the Intro CharacterService keeps it without a body until the phase ends.
-- Avatars: CharacterService:Freeze(p, "Cutscene", true); at the start of each segment the body is pivoted to
-- Marks[slot]; MoveTo beats walk every body to the target (R23: the body is pivoted to the last target first when
-- it is far from it). A body that appears later (spawn after join, rejoin) is frozen and pivoted where it should be.
-- Vote: SkipVote from a connected participant (spectators too, DEC-194 a), once per segment. The segment ends when
-- Votes >= Needed = ceil(0.5 x connected participants), recomputed when someone leaves. Everything else in the
-- beats (fade, text, lines, actors, look, prompt) is client presentation (CutsceneController, TASK-121).
-- Traffic: TrafficService:Hold("cutscene", on) while a chain plays (runtime lookup: Traffic is not in Require).
-- PROVISIONAL (TASK-120 note): side-by-side spacing on shared targets; walk speed = StarterPlayer default; intro end
-- moves participants to their spawn point (PS-n, "at work"); chain ends when no participant is connected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Modux = require(ServerScriptService.server.Modux)

type Scene = Content.Cutscene
type Beat = Content.CutsceneBeat

-- TrafficService seen through a runtime lookup (TASK-104; not in Require, architecture.md §19.2)
type TrafficHook = {
	Hold: (self: any, reason: string, on: boolean) -> (),
}

const RECORD = 1
const NONE = "none"
const FREEZE_REASON = "Cutscene"
const HOLD_REASON = "cutscene"
const SLOT_TOKEN = "{slot}"
const MAX_WIRE = 4 -- Cutscene.Votes / Needed wire range
const VOTE_SHARE = 0.5 -- DEC-194
const TICK_RATE = 10 -- Hz: beat timing and late bodies
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
-- Provisional presentation (TASK-120 note; candidates for Content.Cutscenes): side-by-side gap on a shared target and
-- distance from the last target that triggers a re-pivot at the next shot (R23)
const LINE_SPACING = 2.5 -- 4 avatars fit inside the 8-stud CW-1 stripes (MAP-01 P46)
const SNAP_DISTANCE = 6
const PHASE_SCENES: { [string]: string } = { Intro = "intro", Finale = "finale" }

local function sceneOf(key: string): Scene?
	const scene = Content.Cutscenes.ByKey[key]
	if scene == nil or key == NONE then
		return nil
	end
	return scene
end

-- MoveTo beats of a scene, in time order
local function movesOf(scene: Scene): { Beat }
	const moves: { Beat } = {}
	for _, beat in scene.Beats do
		if beat.Kind == "MoveTo" then
			table.insert(moves, beat)
		end
	end
	table.sort(moves, function(a: Beat, b: Beat): boolean
		return a.At < b.At
	end)
	return moves
end

local function rootOf(character: Model): BasePart?
	const root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

const CutsceneService = Modux.Service("CutsceneService", {
	Require = { "PlaceService", "NetService", "RoundService", "RunStateService", "CharacterService" },
	Priority = 540,
})

function CutsceneService:Setup()
	self.Enabled = false :: boolean
	-- record 1 of the Cutscene set already added
	self.Written = false :: boolean
	-- current segment ("none" = idle) and its start (server clock)
	self.Scene = NONE :: string
	self.StartedAt = 0 :: number
	-- Round phase that owns the chain (Intro/Finale); nil = dev play
	self.Owner = nil :: string?
	-- true once the chain of the owning phase is over (phase probe)
	self.Done = true :: boolean
	-- participant UserIds in roster order (index = slot)
	self.Participants = {} :: { number }
	-- UserIds that voted in the current segment
	self.Votes = {} :: { [number]: boolean }
	-- MoveTo beats of the current segment and the next one to run
	self.Moves = {} :: { Beat }
	self.NextMove = 1 :: number
	-- where bodies stand now: nil = Marks[slot], else the last MoveTo target
	self.Target = nil :: string?
	-- bodies already placed in this segment
	self.Placed = setmetatable({}, { __mode = "k" }) :: any
	-- players frozen by this service
	self.Frozen = {} :: { [Player]: boolean }
	-- walk in progress per player (a token tells the current walk from a stale MoveToFinished)
	self.Walks = {} :: { [Player]: {} }
	self.Traffic = nil :: TrafficHook?
	-- Fired when a chain starts (scene key) and ends ("none")
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<string>
end

-- Reads -----------------------------------------------------------------------------------------------------------

function CutsceneService:IsPlaying(): boolean
	return self.Scene ~= NONE
end

function CutsceneService:IsParticipant(player: Player): boolean
	return self:IsPlaying() and table.find(self.Participants, player.UserId) ~= nil
end

function CutsceneService:SlotOf(userId: number): number?
	return table.find(self.Participants, userId)
end

-- Participant still in the server and not Away (DEC-194: a disconnected player counts nowhere)
function CutsceneService:Connected(userId: number): Player?
	const player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return nil
	end
	const member = self.Dependencies.RunStateService:GetMember(player)
	if member == nil or member.State == "Away" then
		return nil
	end
	return player
end

function CutsceneService:ConnectedCount(): number
	local count = 0
	for _, userId in self.Participants do
		if self:Connected(userId) ~= nil then
			count += 1
		end
	end
	return count
end

function CutsceneService:VoteCount(): number
	local count = 0
	for userId in self.Votes do
		if self:Connected(userId) ~= nil then
			count += 1
		end
	end
	return count
end

function CutsceneService:Needed(): number
	return math.ceil(VOTE_SHARE * self:ConnectedCount())
end

-- Network -----------------------------------------------------------------------------------------------------------

function CutsceneService:Write()
	if not self.Dependencies.NetService:IsRunning() then
		return
	end
	const playing = self:IsPlaying()
	const record = {
		Scene = self.Scene,
		StartedAt = if playing then self.StartedAt else 0,
		Votes = if playing then math.clamp(self:VoteCount(), 0, MAX_WIRE) else 0,
		Needed = if playing then math.clamp(self:Needed(), 0, MAX_WIRE) else 0,
	}
	if self.Written then
		self.Libs.Net.Cutscene:update(RECORD, record)
	else
		self.Written = true
		self.Libs.Net.Cutscene:add(RECORD, record)
	end
end

-- Traffic (TASK-104) --------------------------------------------------------------------------------------------

function CutsceneService:TrafficHook(): TrafficHook?
	if self.Traffic ~= nil then
		return self.Traffic
	end
	const feature = ServerScriptService.server:FindFirstChild("Traffic")
	const module = if feature then feature:FindFirstChild("TrafficService") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	const traffic = (require :: any)(module) :: TrafficHook
	if type(traffic) ~= "table" or type(traffic.Hold) ~= "function" then
		return nil
	end
	self.Traffic = traffic
	return traffic
end

function CutsceneService:HoldTraffic(on: boolean)
	const traffic = self:TrafficHook()
	if traffic == nil then
		return
	end
	const ok, problem = pcall(function()
		traffic:Hold(HOLD_REASON, on)
	end)
	if not ok then
		warn(`[CutsceneService] TrafficService:Hold failed: {problem}`)
	end
end

-- Bodies ------------------------------------------------------------------------------------------------------------

-- Point id of a target for a slot ("{slot}" -> 1..4)
local function pointId(target: string, slot: number): string
	return (string.gsub(target, SLOT_TOKEN, tostring(slot)))
end

-- Where the body of a slot stands now: its mark, or the current MoveTo target (side by side on a shared point)
function CutsceneService:SpotFor(slot: number): CFrame?
	const scene = sceneOf(self.Scene)
	if scene == nil or not MapIndex.HasBinding() then
		return nil
	end
	const target = self.Target
	if target == nil then
		const marks = scene.Marks
		if #marks == 0 then
			return nil
		end
		return MapIndex.FindPoint(marks[math.min(slot, #marks)])
	end
	const point = MapIndex.FindPoint(pointId(target, slot))
	if point == nil then
		return nil
	end
	if string.find(target, SLOT_TOKEN, 1, true) then
		return point
	end
	const offset = (slot - (#self.Participants + 1) / 2) * LINE_SPACING
	return point * CFrame.new(offset, 0, 0)
end

-- Live body of a connected participant, once CharacterService finished its spawn (it pivots to PS-n in Prepare)
function CutsceneService:BodyOf(player: Player): Model?
	const characters = self.Dependencies.CharacterService
	if characters.Spawning[player] then
		return nil
	end
	return characters:CharacterOf(player)
end

function CutsceneService:Place(player: Player, slot: number)
	const character = self:BodyOf(player)
	if character == nil then
		return
	end
	self.Placed[character] = true
	const spot = self:SpotFor(slot)
	if spot ~= nil then
		character:PivotTo(spot + SPAWN_LIFT)
	end
end

-- Walks a body to the current target. The freeze holds WalkSpeed at 0: the walk sets it for the trip, and
-- CharacterService:RefreshSpeed puts the frozen 0 back on arrival.
function CutsceneService:Walk(player: Player, slot: number)
	const character = self:BodyOf(player)
	const spot = self:SpotFor(slot)
	if character == nil or spot == nil then
		return
	end
	const humanoid = character:FindFirstChildOfClass("Humanoid")
	const root = rootOf(character)
	if humanoid == nil or root == nil then
		return
	end
	const token = {}
	self.Walks[player] = token
	humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
	humanoid:MoveTo(spot.Position)
	local connection: RBXScriptConnection? = nil
	connection = humanoid.MoveToFinished:Connect(function()
		if connection ~= nil then
			connection:Disconnect()
		end
		-- a newer walk (next shot) owns the speed now
		if self.Walks[player] ~= token then
			return
		end
		self.Walks[player] = nil
		if player.Character == character then
			self.Dependencies.CharacterService:RefreshSpeed(player)
		end
	end)
end

-- Stops a walk in progress (end of the chain): the body stays where it is
function CutsceneService:StopWalk(player: Player)
	if self.Walks[player] == nil then
		return
	end
	self.Walks[player] = nil
	const character = player.Character
	const humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	const root = if character ~= nil then rootOf(character) else nil
	if humanoid ~= nil and root ~= nil then
		humanoid:MoveTo(root.Position)
	end
end

-- Freeze every connected participant and place any body not yet placed in this segment
function CutsceneService:Hold()
	const characters = self.Dependencies.CharacterService
	for slot, userId in self.Participants do
		const player = self:Connected(userId)
		if player == nil then
			continue
		end
		if not self.Frozen[player] then
			self.Frozen[player] = true
			characters:Freeze(player, FREEZE_REASON, true)
		end
		const character = self:BodyOf(player)
		if character ~= nil and not self.Placed[character] then
			self:Place(player, slot)
		end
	end
end

function CutsceneService:ReleaseAll()
	const characters = self.Dependencies.CharacterService
	for player in self.Walks do
		self:StopWalk(player)
	end
	for player in self.Frozen do
		if player.Parent ~= nil then
			characters:Freeze(player, FREEZE_REASON, false)
		end
	end
	table.clear(self.Frozen)
	table.clear(self.Walks)
end

-- MoveTo beat: bodies far from the last target are pivoted there first (R23), then walk to the new one
function CutsceneService:RunMove(beat: Beat)
	for slot, userId in self.Participants do
		const player = self:Connected(userId)
		const character = if player ~= nil then self:BodyOf(player) else nil
		if player == nil or character == nil then
			continue
		end
		const root = rootOf(character)
		const last = self:SpotFor(slot)
		if root ~= nil and last ~= nil and (root.Position - last.Position).Magnitude > SNAP_DISTANCE then
			character:PivotTo(last + SPAWN_LIFT)
		end
	end
	self.Target = beat.Target
	for slot, userId in self.Participants do
		const player = self:Connected(userId)
		if player ~= nil then
			self:Walk(player, slot)
		end
	end
end

-- Chain ---------------------------------------------------------------------------------------------------------------

-- Starts a segment of the running chain (votes back to 0, bodies back to their marks)
function CutsceneService:Begin(key: string)
	const scene = sceneOf(key)
	if scene == nil then
		self:Finish()
		return
	end
	self.Scene = key
	self.StartedAt = workspace:GetServerTimeNow()
	table.clear(self.Votes)
	self.Moves = movesOf(scene)
	self.NextMove = 1
	self.Target = nil
	self.Placed = setmetatable({}, { __mode = "k" })
	self:Hold()
	self:Write()
end

-- Plays a chain. owner = Round phase waiting on the probe (nil = dev play).
function CutsceneService:Play(key: string, owner: string?): boolean
	if sceneOf(key) == nil then
		warn(`[CutsceneService] no cutscene {key}`)
		return false
	end
	if self:IsPlaying() then
		self:Finish()
	end
	const runState = self.Dependencies.RunStateService
	const members = runState.Members()
	const participants: { number } = {}
	for _, userId in runState.Roster() do
		const member = members[userId]
		if member ~= nil and member.State ~= "Away" and Players:GetPlayerByUserId(userId) ~= nil then
			table.insert(participants, userId)
		end
	end
	if #participants == 0 then
		return false
	end
	self.Participants = participants
	self.Owner = owner
	self.Done = false
	self:HoldTraffic(true)
	self:Begin(key)
	self.Changed:Fire(key)
	return true
end

-- Ends the chain: everyone free, traffic back, record idle. After the intro the party is "at work" (PS-n).
function CutsceneService:Finish()
	if not self:IsPlaying() then
		self.Done = true
		return
	end
	const wasIntro = self.Owner == "Intro"
	const participants = self.Participants
	self.Scene = NONE
	self.StartedAt = 0
	self.Owner = nil
	self.Done = true
	self.Target = nil
	self.Moves = {}
	self.Participants = {}
	table.clear(self.Votes)
	self:ReleaseAll()
	self:HoldTraffic(false)
	self:Write()
	if wasIntro then
		const characters = self.Dependencies.CharacterService
		const info = self.Dependencies.RoundService:Info()
		for _, userId in participants do
			const player = Players:GetPlayerByUserId(userId)
			const character = if player ~= nil then self:BodyOf(player) else nil
			const point = if player ~= nil and character ~= nil then characters:SpawnPointFor(player, info) else nil
			if character ~= nil and point ~= nil then
				character:PivotTo(point + SPAWN_LIFT)
			end
		end
	end
	self.Changed:Fire(NONE)
end

-- End of the current segment (time or vote): Next plays as a new segment, else the chain is over
function CutsceneService:EndSegment()
	const scene = sceneOf(self.Scene)
	const nextKey: string = if scene ~= nil and scene.Next ~= nil then scene.Next else NONE
	if sceneOf(nextKey) ~= nil then
		self:Begin(nextKey)
		return
	end
	self:Finish()
end

function CutsceneService:Vote(player: Player): boolean
	const scene = sceneOf(self.Scene)
	if scene == nil or not scene.Skippable then
		return false
	end
	const userId = player.UserId
	if table.find(self.Participants, userId) == nil or self:Connected(userId) == nil or self.Votes[userId] then
		return false
	end
	self.Votes[userId] = true
	self:Settle()
	return true
end

-- Votes and Needed after a vote or a departure; enough votes end the segment
function CutsceneService:Settle()
	if not self:IsPlaying() then
		return
	end
	if self:ConnectedCount() == 0 then
		self:Finish()
		return
	end
	const scene = sceneOf(self.Scene)
	if scene ~= nil and scene.Skippable and self:VoteCount() >= self:Needed() then
		self:EndSegment()
		return
	end
	self:Write()
end

function CutsceneService:Step()
	const scene = sceneOf(self.Scene)
	if scene == nil then
		return
	end
	const elapsed = workspace:GetServerTimeNow() - self.StartedAt
	if elapsed >= math.min(scene.Duration, scene.Cap) then
		self:EndSegment()
		return
	end
	while self.NextMove <= #self.Moves and self.Moves[self.NextMove].At <= elapsed do
		const beat = self.Moves[self.NextMove]
		self.NextMove += 1
		self:RunMove(beat)
	end
	self:Hold()
end

-- Round phases ------------------------------------------------------------------------------------------------------

function CutsceneService:OnPhaseChanged(phase: string)
	if self:IsPlaying() and self.Owner ~= nil and self.Owner ~= phase then
		-- the phase cap (or a dev skip) ended the phase first
		self:Finish()
	end
	const key = PHASE_SCENES[phase]
	if key == nil then
		return
	end
	if not self:Play(key, phase) then
		self.Done = true
	end
end

function CutsceneService:ProbeDone(phase: string): boolean
	return self.Done or self.Owner ~= phase
end

-- Lifecycle -------------------------------------------------------------------------------------------------------

CutsceneService:OnInit(function(self)
	self:Setup()
	if not self.Dependencies.PlaceService:Is("Run") then
		return
	end
	self.Enabled = true

	-- Registered before RoundService:StartRun (its OnStart): Intro and Finale are not skipped (§19.0 rule 4)
	const round = self.Dependencies.RoundService
	for phase in PHASE_SCENES do
		round:SetPhaseProbe(phase :: any, function(): boolean
			return self:ProbeDone(phase)
		end)
	end
	-- Higher-priority services ran their Setup before this OnInit (§19.0 rule 2)
	round.PhaseChanged:Connect(function(phase)
		self:OnPhaseChanged(phase)
	end)

	self.Libs.Net.SkipVote:onServer(function(_, player: Player)
		if self.Enabled then
			self:Vote(player)
		end
	end)

	self.Dependencies.RunStateService.MemberAway:Connect(function(player)
		self.Frozen[player] = nil
		self.Walks[player] = nil
		self:Settle()
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Frozen[player] = nil
		self.Walks[player] = nil
		task.defer(function()
			self:Settle()
		end)
	end)
end)

CutsceneService:OnStart(function(self)
	if not self.Enabled or self.Written then
		return
	end
	self:Write()
end)

CutsceneService:OnTick(function(self)
	if not self.Enabled then
		return
	end
	self:Step()
end, TICK_RATE)

return CutsceneService
