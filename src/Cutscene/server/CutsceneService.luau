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
-- Marks[slot]. The walk itself is the shared Route (src/Cutscene/shared/Route.luau): each client steers its own body
-- along it (smooth start/stop, no dry stop at a waypoint, CutsceneController/Walker). At each MoveTo beat a body far
-- from where the Route says it should be (Rules.SnapDistance) is pivoted there (R23). A body that appears later
-- (spawn after join, rejoin) is frozen and pivoted where the Route puts it. Targets come from the real map
-- (Anchors.luau): the stand spots in front of the phone/poster follow the instance wherever it was moved.
-- Poster: the Help Wanted flyer gets its printed text + phone number (Rules.Poster) once per server (DressPoster).
-- Vote: SkipVote from a connected participant (spectators too, DEC-194 a), once per segment. The segment ends when
-- Votes >= Needed = ceil(0.5 x connected participants), recomputed when someone leaves. Everything else in the
-- beats (fade, text, lines, actors, look, prompt) is client presentation (CutsceneController, TASK-121).
-- Traffic: TrafficService:Hold("cutscene", on) while a chain plays (runtime lookup: Traffic is not in Require).
-- Ready gate (user feedback 2026-10-11: the start of the intro was lost under the client's loading): a chain does not
-- start at Play. The participants are frozen and the record says Waiting (Scene "none") until every connected
-- participant sent ClientReady (LoadingController: loading screen done) or Rules.ReadyTimeout s passed; then the
-- first segment begins with StartedAt = now, so nobody misses its first beats.
-- PROVISIONAL (TASK-120 note): side-by-side spacing on shared targets (Rules.LineSpacing); walk pace = Rules.Walk;
-- intro end moves participants to their spawn point (PS-n, "at work"); chain ends when no participant is connected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local SignalLib = require(ReplicatedStorage.shared.Libs.Signal)
local Anchors = require(ReplicatedStorage.shared.Cutscene.Anchors)
local Route = require(ReplicatedStorage.shared.Cutscene.Route)
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
const MAX_WIRE = 4 -- Cutscene.Votes / Needed wire range
const VOTE_SHARE = 0.5 -- DEC-194
const TICK_RATE = 10 -- Hz: beat timing and late bodies
const SPAWN_LIFT = Vector3.new(0, 3, 0) -- architecture.md §18.5
const RULES = Content.Cutscenes.Rules
const PHASE_SCENES: { [string]: string } = { Intro = "intro", Finale = "finale" }
-- Help Wanted flyer dressing (Rules.Poster; PROVISIONAL look, frontend-coder 2026-10-11)
const DRESSED_ATTRIBUTE = "CutsceneDressed"
const POSTER_PPS = 100
const INK = Color3.fromHex("#2B2233")
const KETCHUP = Color3.fromHex("#E2402E")
const CREAM = Color3.fromHex("#FFF1D6")

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

local function label(parent: Instance, name: string, text: string, y: number, h: number, color: Color3, bold: boolean)
	const line = Instance.new("TextLabel")
	line.Name = name
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0.06, y)
	line.Size = UDim2.fromScale(0.88, h)
	line.FontFace = Font.fromEnum(if bold then Enum.Font.FredokaOne else Enum.Font.Gotham)
	line.TextScaled = true
	line.TextWrapped = true
	line.TextColor3 = color
	line.Text = text
	line.Parent = parent
end

local function phoneStrip(parent: Instance, phone: string)
	const strip = Instance.new("Frame")
	strip.Name = "PhoneStrip"
	strip.BorderSizePixel = 0
	strip.BackgroundColor3 = KETCHUP
	strip.Position = UDim2.fromScale(0, 0.78)
	strip.Size = UDim2.fromScale(1, 0.19)
	strip.Parent = parent
	label(strip, "Phone", `CALL {phone}`, 0.08, 0.84, CREAM, true)
end

-- Printed flyer: title, the lines and a "CALL <number>" strip (Rules.Poster) on the SurfaceGui the map already has.
-- A flyer without SurfaceGui (texture) only gets the strip, on its Front face.
local function dressPoster(part: BasePart)
	local gui: SurfaceGui? = nil
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			gui = child
			break
		end
	end
	const poster = RULES.Poster
	if gui == nil then
		warn(`[CutsceneService] {part:GetFullName()} has no SurfaceGui: adding a "CALL {poster.Phone}" strip on Front`)
		const created = Instance.new("SurfaceGui")
		created.Name = "PhoneStrip"
		created.Face = Enum.NormalId.Front
		created.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		created.PixelsPerStud = POSTER_PPS
		created.LightInfluence = 0
		created.Parent = part
		phoneStrip(created, poster.Phone)
		return
	end
	const surface = gui :: SurfaceGui
	surface:ClearAllChildren()
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = POSTER_PPS
	surface.LightInfluence = 0
	const lines = poster.Lines
	label(surface, "Title", lines[1] or "", 0.04, 0.2, KETCHUP, true)
	const rest = math.max(#lines - 1, 1)
	const room = 0.5 / rest
	for i = 2, #lines do
		label(surface, `Line{i - 1}`, lines[i], 0.26 + (i - 2) * room, room * 0.9, INK, false)
	end
	phoneStrip(surface, poster.Phone)
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
	-- walk plan per slot of the current segment (shared Route; rebuilt while a target is missing)
	self.Plans = {} :: { [number]: Route.Plan }
	self.Traffic = nil :: TrafficHook?
	-- Fired when a chain starts (scene key) and ends ("none")
	self.Changed = self.Libs.Signal.new() :: SignalLib.Signal<string>
	-- chain held for the participants' ClientReady (nil = none) and since when (os.clock)
	self.Pending = nil :: string?
	self.PendingSince = 0 :: number
	-- players whose client finished loading (ClientReady)
	self.Loaded = {} :: { [Player]: boolean }
end

-- Reads -----------------------------------------------------------------------------------------------------------

function CutsceneService:IsPlaying(): boolean
	return self.Scene ~= NONE
end

function CutsceneService:IsParticipant(player: Player): boolean
	return (self:IsPlaying() or self:IsWaiting()) and table.find(self.Participants, player.UserId) ~= nil
end

-- A chain is held for the participants' ClientReady
function CutsceneService:IsWaiting(): boolean
	return self.Pending ~= nil
end

-- Every connected participant finished loading (a disconnected one does not hold the others)
function CutsceneService:AllLoaded(): boolean
	for _, userId in self.Participants do
		const player = self:Connected(userId)
		if player ~= nil and not self.Loaded[player] then
			return false
		end
	end
	return true
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
		Waiting = self.Pending ~= nil,
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

-- Poster ------------------------------------------------------------------------------------------------------------

-- Prints the Help Wanted flyer (title, lines, phone number) once; replicated to every client
function CutsceneService:DressPoster()
	const instance = Anchors.PosterInstance()
	if instance == nil or instance:GetAttribute(DRESSED_ATTRIBUTE) then
		return
	end
	local part: BasePart? = nil
	if instance:IsA("BasePart") then
		part = instance
	else
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("SurfaceGui") and descendant.Parent ~= nil and descendant.Parent:IsA("BasePart") then
				part = descendant.Parent :: BasePart
				break
			end
		end
		if part == nil then
			part = instance:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	if part == nil then
		return
	end
	instance:SetAttribute(DRESSED_ATTRIBUTE, true)
	const ok, problem = pcall(dressPoster, part)
	if not ok then
		warn(`[CutsceneService] poster dressing failed: {problem}`)
	end
end

-- Bodies ------------------------------------------------------------------------------------------------------------

-- Walk plan of a slot for the current segment (Anchors: real map; rebuilt while something is not found)
function CutsceneService:PlanFor(slot: number): Route.Plan?
	const scene = sceneOf(self.Scene)
	if scene == nil or not MapIndex.HasBinding() then
		return nil
	end
	const cached = self.Plans[slot]
	if cached ~= nil and not cached.Missing then
		return cached
	end
	const plan = Route.Build(scene, slot, #self.Participants, Anchors.Spot)
	self.Plans[slot] = plan
	return plan
end

-- Where the body of a slot should stand now (its mark, a point of the walk, or the last target), facing its way
function CutsceneService:SpotFor(slot: number): CFrame?
	const plan = self:PlanFor(slot)
	if plan == nil then
		return nil
	end
	const position, _, facing = Route.Sample(plan, workspace:GetServerTimeNow() - self.StartedAt)
	if position == nil then
		return nil
	end
	return CFrame.lookAt(position, position + (facing or Vector3.new(0, 0, -1)))
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

-- Freeze every connected participant and place any body not yet placed in this segment (only freeze while the
-- chain waits for ClientReady: there is no segment to place them in yet)
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
		if not self:IsPlaying() then
			continue
		end
		const character = self:BodyOf(player)
		if character ~= nil and not self.Placed[character] then
			self:Place(player, slot)
		end
	end
end

function CutsceneService:ReleaseAll()
	const characters = self.Dependencies.CharacterService
	for player in self.Frozen do
		if player.Parent ~= nil then
			characters:Freeze(player, FREEZE_REASON, false)
		end
	end
	table.clear(self.Frozen)
end

-- MoveTo beat: the clients walk their own bodies along the Route; a body far from where the Route puts it now
-- (lag, a client that does not walk) is pivoted there (R23)
function CutsceneService:RunMove(beat: Beat)
	self.Target = beat.Target
	for slot, userId in self.Participants do
		const player = self:Connected(userId)
		const character = if player ~= nil then self:BodyOf(player) else nil
		if character == nil then
			continue
		end
		const root = rootOf(character)
		const spot = self:SpotFor(slot)
		if root ~= nil and spot ~= nil then
			const off = Vector3.new(root.Position.X - spot.Position.X, 0, root.Position.Z - spot.Position.Z)
			if off.Magnitude > RULES.SnapDistance then
				character:PivotTo(spot + SPAWN_LIFT)
			end
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
	self.Plans = {}
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
	if self:IsPlaying() or self:IsWaiting() then
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
	self:DressPoster()
	self:HoldTraffic(true)
	-- held until every participant's client is ready (Rules.ReadyTimeout at most)
	self.Pending = key
	self.PendingSince = os.clock()
	self:Hold()
	self:Write()
	self:StepPending()
	return true
end

-- Starts the held chain once every connected participant is loaded, or at the timeout
function CutsceneService:StepPending()
	const key = self.Pending
	if key == nil then
		return
	end
	const waited = os.clock() - self.PendingSince
	if not self:AllLoaded() and waited < RULES.ReadyTimeout then
		self:Hold()
		return
	end
	if waited >= RULES.ReadyTimeout and not self:AllLoaded() then
		warn(`[CutsceneService] {key}: starting after {RULES.ReadyTimeout} s without every ClientReady`)
	end
	self.Pending = nil
	self:Begin(key)
	self.Changed:Fire(key)
end

-- Ends the chain: everyone free, traffic back, record idle. After the intro the party is "at work" (PS-n).
function CutsceneService:Finish()
	if self:IsWaiting() and not self:IsPlaying() then
		-- held chain dropped before it started (phase over, nobody left, dev stop)
		self.Pending = nil
		self.Owner = nil
		self.Done = true
		self.Participants = {}
		self:ReleaseAll()
		self:HoldTraffic(false)
		self:Write()
		return
	end
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
	self.Plans = {}
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
	if self:IsWaiting() then
		if self:ConnectedCount() == 0 then
			self:Finish()
		else
			self:StepPending()
		end
		return
	end
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
	if self:IsWaiting() then
		self:StepPending()
		return
	end
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
	if (self:IsPlaying() or self:IsWaiting()) and self.Owner ~= nil and self.Owner ~= phase then
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
	-- registered on every place: the client sends it wherever it loads
	self.Libs.Net.ClientReady:onServer(function(_, player: Player)
		self.Loaded[player] = true
		if self.Enabled and self:IsWaiting() then
			self:StepPending()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Loaded[player] = nil
	end)
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
		self:Settle()
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.Frozen[player] = nil
		task.defer(function()
			self:Settle()
		end)
	end)
end)

CutsceneService:OnStart(function(self)
	if not self.Enabled then
		return
	end
	task.defer(function()
		self:DressPoster()
	end)
	if self.Written then
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
