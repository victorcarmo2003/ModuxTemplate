--!strict
--[[
	CutsceneController (TASK-121; architecture.md §19.16; network.md §6.2, §13.7; FEAT-004, FEAT-027; script.md §1;
	ending.md §2.2, §2.4; MAP-01 §11; DEC-078, DEC-088, DEC-097, DEC-194, DEC-202, DEC-203, DEC-205)

	Presents the `Cutscene` set (record 1; Scene "none" = idle). CutsceneService decides everything that matters:
	which scene, when each segment starts and ends, the vote count and the threshold, where the bodies stand and walk
	(Freeze + PivotTo + MoveTo). This client only shows the beats of Content.Cutscenes over the server clock:

	  Fade      ScreenFade over the whole screen (black before the first beat when that beat is a fade in)
	  Text      HudBanner title ("Bellmoor"; "Credits" stays until the next fade)
	  MoveTo    the own body walks the shared Route (Walker.luau: eased start/stop, flowing waypoints, smooth turn);
	            the server only places bodies and re-places one that is far (CutsceneService)
	  LookAt    focus on a point / post / Walt's mark (CameraController:Focus, elastic free look, eased switch)
	  Focus     focus on a live target: a car actor (followed), "Poster", "Phone", "Sign" (real map instances,
	            Anchors; "Sign" = the tagged NO HELP WANTED sign, else the nearest card ahead), "Windows" (nearest
	            NO HELP WANTED card ahead), a MapPoint or "Walk" (where the body walks); Fov narrows the view
	  Prompt    PromptBillboard on the target that fills by itself (input locked, script.md §1)
	  Line      subtitle strip (CallSubtitle): "Walt" lines, or "You" for crew lines (no balloons: one avatar);
	            voiced by text-to-speech when the engine has it (Speech.luau, Rules.Voices; subtitles only otherwise)
	  Actor     local actors (Actors.luau): flip phone, Walt, coffee, Raincoat Lady, street cars (none in the intro),
	            flyer, Mart bell. A car with Rules.Cars[].Cross is synced to the own body: it passes when the body
	            reaches fraction At of the crossing + the planned time to its stop + After (CrossClock)

	Ready gate: the server holds a chain (record Waiting = true, Scene "none") until every participant's client sent
	ClientReady (LoadingController); `Waiting` mirrors it so the loading screen stays up meanwhile. The intro voices
	are loaded under that loading screen (PreloadVoices -> Speech.Preload: one request at a time, retry, voice
	fallback), and the same Speech is used when the chain starts.

	Cutscene active (for the HUD and anyone else): `CutsceneController.Active` (Vide source, true from the first
	segment to the end of the chain) and the attribute `CutsceneActive` (true / nil) on Players.LocalPlayer.

	Every frame is a function of (beats, server time - StartedAt): a late or rejoining client lands on the same frame
	(Timeline.luau). Sounds and balloons only fire for beats crossed live, never on catch-up.

	Skip (DEC-078, DEC-194): SkipPill bottom right, "Skip (votes/needed)" from the set. Hold for HOLD_TIME (E, Space,
	gamepad X/A, or press the pill on touch) -> one `SkipVote` per segment. The own vote only marks the pill; the count
	shown is always the server's. A new segment (finale -> credits) clears the own vote.

	While a chain plays: CameraController:Cutscene(true), input context "Menu" (world prompts off; the skip bind has
	no context), music cue of the scene pushed (Content.Cutscenes[].Music, AudioController:PushMusic; the shift track
	waits for the end of the chain). All restored when Scene goes back to "none"; the screen stays black END_HOLD s
	and then fades into the game.

	PROVISIONAL (TASK-121):
	  * ONE avatar (owner 2026-10-12): the own. Route/Walker use slot 1 of 1 for everybody, the other players' characters
	    are hidden for this client (Hide.luau) until the chain ends or is skipped, the variant is always Solo and the
	    flip phone is always in the own view. Each client sees its own scene alone; the server record is unchanged.
	  * HOLD_TIME, FADE_TIME, LINE_HOLD, TITLE_HOLD, PROMPT_TIME, look heights; crew speaker "You".
	  * Finale lines also use the call strip (its phone badge has no "in person" variant yet).
	  * Credits show the title only (the roll from docs/art/credits.md is not in Content yet).
	  * A non-participant (late member, DEC-205) sees the same presentation; its vote is ignored by the server.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Anchors = require(ReplicatedStorage.shared.Cutscene.Anchors)
local Route = require(ReplicatedStorage.shared.Cutscene.Route)
local CallSubtitle = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CallSubtitle)
local HudBanner = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudBanner)
local PromptBillboard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PromptBillboard)
local ScreenFade = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ScreenFade)
local SkipPill = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SkipPill)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local UiScale = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.UiScale)
local Vignette = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Vignette)
local Actors = require(script.Actors)
local Ambience = require(script.Ambience)
local Director = require(script.Director)
local Hide = require(script.Hide)
local Speech = require(script.Speech)
local Timeline = require(script.Timeline)
local Walker = require(script.Walker)

type Beat = Content.CutsceneBeat
type Scene = Content.Cutscene

export type Record = { Scene: string, StartedAt: number, Votes: number, Needed: number, Waiting: boolean }
-- HudBanner.Shown, local so the generated type file needs no component require
type Shown = { Title: string, Line: string } | false

-- A subtitle line following its voice: Pending (waiting for the voice to start, or to miss) -> Voice (the voice
-- speaks) -> Tail, or Pending -> Text (no voice: reading time)
type Caption = {
	Beat: Beat,
	State: string,
	Started: boolean, -- Speech OnStart
	Ended: boolean, -- Speech OnEnd
	Missed: boolean, -- Speech OnMiss (no voice for it)
	Silent: boolean, -- catch-up line: text only, no balloon
	Cancel: (() -> ())?,
	ActiveAt: number, -- os.clock it became the current caption
	ShownElapsed: number, -- segment time it went on screen
	TailUntil: number,
}

-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const RECORD = 1
const NONE = "none"
const INTRO = "intro"
const VOICE_AHEAD = 25 -- s of the intro whose voices the loading screen waits for (the later ones load in the background)
const BIND_NAME = "CutsceneSkip"
const KEY_LABEL = { KeyboardMouse = "E", Gamepad = "X", Touch = "" }
const RENDER_STEP = "CutsceneController.Timeline"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1 -- LookAt lands before the camera reads it

-- PROVISIONAL presentation numbers (TASK-121)
const HOLD_TIME = 0.6 -- s of hold for a skip vote ("Hold to skip", ui-text.md §7)
const FADE_TIME = 1 -- s of each Fade beat
const END_FADE = 0.8 -- s back to clear when the chain ends
const END_HOLD = 0.35 -- s the screen holds its fade before that (bodies land at their spawn under the black)
const LINE_HOLD = 3.5 -- s a line without a voice stays without a next one
-- subtitles follow the voice (playtest 2026-10-11: the text ran ahead of it)
const CAPTION_TAIL = 0.4 -- s the text stays after its voice ended
const CAPTION_TEXT_MIN = 1.2 -- s a text-only line stays at least
const CAPTION_LOAD_LATE = 1.5 -- s past its At a line whose voice is still loading goes on as text only
const CAPTION_VERY_LATE = 3 -- s past its At a line whose voice did not start within CAPTION_VOICE_WAIT does too
const CAPTION_VOICE_WAIT = 1.5 -- s a loaded line has to start its voice once it is the current one
const TITLE_HOLD = 3 -- s of a title
const PROMPT_TIME = 1.2 -- s the "Call" prompt takes to fill by itself
const LOOK_LIFT = Vector3.new(0, 3, 0) -- look target above a ground point
const FLYER_HEIGHT = 4.5 -- the P-01 flyer, same as Actors
const LIVE_WINDOW = 0.75 -- s: a beat crossed later than this after its At is catch-up (no sound, no balloon)
-- watchdog (a lost Cutscene frame must not leave the camera/input in a chain): how often the set's store is read
-- back, and how long past the scene's server Cap a chain may run before the client ends it by itself
const WATCH_RATE = 2 -- Hz
const STALE_MARGIN = 5 -- s
const FADE_ORDER = 51 -- above the vehicle fade (50) and the HUD
const UI_ORDER = 52 -- subtitles and skip over the black
const SPEAKERS: { [string]: string } = { walt = "Walt", crew = "You" }
const PROMPT_SOUND = "prompt_done"
const VOTE_SOUND = "skip_vote"
const VOTE_CLIP = "wave_skip"
const ACTIVE_ATTRIBUTE = "CutsceneActive"
const LOOK_ATTRIBUTE = "CutsceneLook" -- Content.Cutscenes[].Look: LightController applies that preset while the scene plays
const NIGHTFALL_ATTRIBUTE = "CutsceneNightfall" -- Content.Cutscenes[].Nightfall.Time: s LightController blends to the night
const CINEMA_ORDER = 50 -- letterbox and vignette: under the fade (51) and the subtitles (52)
const VIGNETTE_COLOR = Color3.fromRGB(34, 20, 12) -- warm dark edge, never the night blue
const ACTOR_LIFT = Vector3.new(0, 2, 0) -- focus on a car: a bit above its base
const WINDOW_PATTERN = "NoHelp" -- NO HELP WANTED cards (AST-033_NoHelpSign, blockout Window_NoHelpWanted_*)
const WINDOW_RANGE = 34 -- studs: cards farther than this are not glanced at
const WINDOW_AHEAD = 0.15 -- dot with the walk heading: only cards ahead or beside
const SIGN_TARGET = "Sign" -- the tagged NO HELP WANTED sign (Rules.Sign)
-- car synced to the walker (Rules.Cars[].Cross; PROVISIONAL frontend-coder 2026-10-11)
const CROSS_STEP = 0.05 -- s between two samples of the planned walk
const CROSS_WIDTH = 8 -- studs off the crossing line that still count as on it
const CROSS_OVER = 1.2 -- fraction past the far end where a body no longer triggers (already crossed)
const CROSS_WAIT = 2 -- s the car waits at most for a body behind its plan

const CutsceneController = Modux.Controller("CutsceneController", {
	Require = { "InputController", "CameraController", "AnimController", "AudioController" },
	Priority = 560,
})

function CutsceneController:Setup()
	-- set mirror
	self.SceneKey = Vide.source(NONE) :: Vide.Source<string>
	self.Votes = Vide.source(0) :: Vide.Source<number>
	self.Needed = Vide.source(0) :: Vide.Source<number>
	-- the server holds the next chain until every participant's client is ready (LoadingController, ClientReady)
	self.Waiting = Vide.source(false) :: Vide.Source<boolean>
	-- presentation
	self.Fade = Vide.source(0) :: Vide.Source<number>
	self.Speaker = Vide.source("") :: Vide.Source<string>
	self.LineText = Vide.source("") :: Vide.Source<string>
	self.LineShown = Vide.source(false) :: Vide.Source<boolean>
	self.Banner = Vide.source(false :: Shown) :: Vide.Source<Shown>
	self.PromptText = Vide.source("") :: Vide.Source<string>
	self.PromptShown = Vide.source(false) :: Vide.Source<boolean>
	self.Voted = Vide.source(false) :: Vide.Source<boolean>
	self.Progress = Vide.source(0) :: Vide.Source<number>
	self.Skippable = Vide.source(false) :: Vide.Source<boolean>
	-- a chain plays (HUD and others hide what does not belong in a cutscene); also attribute CutsceneActive
	self.Active = Vide.source(false) :: Vide.Source<boolean>
	-- cinema dressing (Content.Cutscenes[].Cinema): letterbox bar height as a fraction of the screen, vignette strength
	self.Bars = Vide.source(0) :: Vide.Source<number>
	self.Vignette = Vide.source(0) :: Vide.Source<number>
	self.EndBars = 0 :: number
	self.Ambience = nil :: Ambience.Ambience?

	-- segment
	self.Scene = nil :: Scene?
	self.StartedAt = 0 :: number
	self.Beats = {} :: { Beat }
	self.Fired = {} :: { [number]: boolean }
	self.LastElapsed = 0 :: number
	self.Actors = {} :: { [string]: { Actor: Actors.Actor, At: number } }
	self.LookIndex = 0 :: number
	self.Music = nil :: string?
	self.Walker = nil :: Walker.Walker?
	-- hides every other player's character for this client while the chain plays (one avatar: the own)
	self.Mates = nil :: Hide.Hide?
	self.Speech = nil :: Speech.Speech?
	-- subtitle lines fired and waiting their turn, and the one on screen (or waiting for its voice)
	self.Captions = {} :: { Caption }
	self.Caption = nil :: Caption?
	self.Windows = nil :: { BasePart }?
	-- chain
	self.Playing = false :: boolean
	self.Party = false :: boolean
	self.EndedAt = nil :: number?
	self.EndAlpha = 0 :: number
	-- skip hold
	self.HoldStart = nil :: number?
	-- ui
	self.Gui = nil :: Instance?
	self.Unmounts = {} :: { () -> () }
	self.Balloons = {} :: { () -> () }
	self.PromptHolder = nil :: BasePart?
	self.Folder = nil :: Folder?
	self.Warned = {} :: { [string]: boolean }
	self.Stepping = false :: boolean
	self.ShotIndex = 0 :: number
	-- last CutsceneSnapshot packet (fallback while the Cutscene set has no record 1)
	self.Snapshot = nil :: Record?
end

function CutsceneController:WarnOnce(key: string, message: string)
	if self.Warned[key] then
		return
	end
	self.Warned[key] = true
	warn(`[CutsceneController] {message}`)
end

function CutsceneController:IsPlaying(): boolean
	return self.Playing
end

-- World positions -----------------------------------------------------------------------------------------------

-- Ground point under a StreetLight (MapIndex tag StreetLight, attribute PostId)
local function postGround(id: string): Vector3?
	for _, instance in CollectionService:GetTagged("StreetLight") do
		if instance:GetAttribute("PostId") ~= id then
			continue
		end
		if instance:IsA("Model") then
			const box, size = instance:GetBoundingBox()
			return box.Position - Vector3.new(0, size.Y / 2, 0)
		elseif instance:IsA("BasePart") then
			return instance.Position - Vector3.new(0, instance.Size.Y / 2, 0)
		end
	end
	return nil
end

-- Where a LookAt / Prompt target is: the real poster / phone, a MapPoint (+ LOOK_LIFT) or a street post (flyer
-- height). "P-01" (the flyer post) is the poster itself when the map has it.
function CutsceneController:TargetPosition(target: string): Vector3?
	if target == SIGN_TARGET then
		const sign = Anchors.Sign()
		return if sign ~= nil then sign.Position else nil
	end
	if target == "Poster" or target == "Phone" or target == "P-01" then
		const anchor = Anchors.Point(if target == "P-01" then "Poster" else target)
		if anchor ~= nil then
			return anchor.Position
		end
	end
	const point = if MapIndex.HasBinding() then MapIndex.FindPoint(target) else nil
	if point ~= nil then
		return point.Position + LOOK_LIFT
	end
	const ground = postGround(target)
	if ground ~= nil then
		return ground + Vector3.new(0, FLYER_HEIGHT, 0)
	end
	return nil
end

-- NO HELP WANTED cards of the map (found once per chain)
function CutsceneController:WindowCards(): { BasePart }
	const cached = self.Windows
	if cached ~= nil then
		return cached
	end
	const cards: { BasePart } = {}
	for _, instance in Workspace:GetDescendants() do
		if string.find(instance.Name, WINDOW_PATTERN, 1, true) then
			if instance:IsA("BasePart") then
				table.insert(cards, instance)
			elseif instance:IsA("Model") and instance.PrimaryPart ~= nil then
				table.insert(cards, instance.PrimaryPart)
			end
		end
	end
	self.Windows = cards
	return cards
end

-- Live focus of a Focus beat (nil = where the body walks)
function CutsceneController:FocusGetter(target: string): (() -> Vector3?)?
	if target == "Walk" then
		return nil
	elseif target == "Windows" then
		const cards = self:WindowCards()
		return function(): Vector3?
			const character = Players.LocalPlayer.Character
			const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root == nil or not root:IsA("BasePart") then
				return nil
			end
			const heading = root.CFrame.LookVector
			local best: Vector3? = nil
			local bestScore = -math.huge
			for _, card in cards do
				if card.Parent == nil then
					continue
				end
				const offset = card.Position - root.Position
				const distance = offset.Magnitude
				if distance > WINDOW_RANGE or distance < 1 then
					continue
				end
				const ahead = Vector3.new(offset.X, 0, offset.Z).Unit:Dot(Vector3.new(heading.X, 0, heading.Z).Unit)
				if ahead < WINDOW_AHEAD then
					continue
				end
				const score = ahead - distance / WINDOW_RANGE
				if score > bestScore then
					bestScore = score
					best = card.Position
				end
			end
			return best
		end
	elseif target == "Poster" or target == "Phone" then
		return function(): Vector3?
			return self:TargetPosition(target)
		end
	elseif target == SIGN_TARGET then
		-- the tagged sign (read live: the user may move it); none in the map -> the nearest card ahead
		const cards = self:FocusGetter("Windows")
		return function(): Vector3?
			const sign = self:TargetPosition(SIGN_TARGET)
			if sign ~= nil then
				return sign
			end
			return if cards ~= nil then cards() else nil
		end
	elseif Content.Cutscenes.Rules.Cars[target] ~= nil then
		return function(): Vector3?
			const entry = self.Actors[target]
			const model = if entry ~= nil then entry.Actor.Model else nil
			if model == nil or model.Parent == nil then
				return nil
			end
			return model:GetPivot().Position + ACTOR_LIFT
		end
	end
	const fixed = self:TargetPosition(target)
	if fixed == nil then
		self:WarnOnce(`focus:{target}`, `Focus target "{target}" not found`)
		return nil
	end
	return function(): Vector3?
		return fixed
	end
end

-- Fraction of `position` along a -> b (XZ, unclamped) and its horizontal distance off that segment
local function crossProgress(a: Vector3, b: Vector3, position: Vector3): (number, number)
	const ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	const ap = Vector3.new(position.X - a.X, 0, position.Z - a.Z)
	const length2 = ab:Dot(ab)
	const t = if length2 > 1e-6 then ap:Dot(ab) / length2 else 0
	return t, (ap - ab * math.clamp(t, 0, 1)).Magnitude
end

local function ownRoot(): BasePart?
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Pass time of a car synced to the own body (Rules.Cars[target].Cross), in s after its Actor beat, read every frame.
-- Planned: the first instant the planned walk reaches fraction Cross.At of From -> To; the car passes Near at the
-- end of that walk (the stop) + Cross.After. Live: when the real body reaches that fraction, the clock starts there
-- (a body behind its plan holds the car back up to CROSS_WAIT s). nil = not a synced car / crossing not walked.
function CutsceneController:CrossClock(target: string): (() -> number?)?
	const row = Content.Cutscenes.Rules.Cars[target]
	const cross = if row ~= nil then row.Cross else nil
	const scene = self.Scene
	if cross == nil or scene == nil then
		return nil
	end
	const from = Anchors.Point(cross.From)
	const to = Anchors.Point(cross.To)
	if from == nil or to == nil then
		self:WarnOnce(`cross:{target}`, `car "{target}": crossing {cross.From} -> {cross.To} not in the map, fixed Pass`)
		return nil
	end
	const a, b = from.Position, to.Position
	const walker = self.Walker
	local plan = if walker ~= nil then walker.Plan() else nil
	if plan == nil then
		plan = Route.Build(scene, 1, 1, Anchors.Spot)
	end
	const walk = plan :: Route.Plan
	local planned: number? = nil
	local stop = 0
	local t = 0
	const finish = Route.EndTime(walk)
	while t <= finish do
		const position = Route.Sample(walk, t)
		if position ~= nil then
			const progress, off = crossProgress(a, b, position)
			if progress >= cross.At and progress <= CROSS_OVER and off <= CROSS_WIDTH then
				planned = t
				const run = Route.RunAt(walk, t)
				stop = if run ~= nil then run.T1 else t
				break
			end
		end
		t += CROSS_STEP
	end
	if planned == nil then
		self:WarnOnce(`cross:{target}`, `car "{target}": the walk never crosses {cross.From} -> {cross.To}, fixed Pass`)
		return nil
	end
	const plannedAt = planned :: number
	const lead = stop - plannedAt + cross.After
	local actual: number? = nil
	return function(): number?
		const entry = self.Actors[target]
		if entry == nil then
			return nil
		end
		const elapsed = self.LastElapsed
		if actual == nil then
			const root = ownRoot()
			if root ~= nil then
				const progress, off = crossProgress(a, b, root.Position)
				if progress >= cross.At and progress <= CROSS_OVER and off <= CROSS_WIDTH then
					actual = elapsed
				end
			end
		end
		const trigger = actual or math.clamp(elapsed, plannedAt, plannedAt + CROSS_WAIT)
		return trigger + lead - entry.At
	end
end

function CutsceneController:ActorContext(): Actors.Context
	const anim = self.Dependencies.AnimController
	const audio = self.Dependencies.AudioController
	return {
		Point = function(id: string): CFrame?
			return if MapIndex.HasBinding() then MapIndex.FindPoint(id) else nil
		end,
		Post = postGround,
		Find = function(target: string): Actors.Actor?
			const entry = self.Actors[target]
			return if entry ~= nil then entry.Actor else nil
		end,
		Play = function(sound: string, at: (Vector3 | Instance)?)
			audio:Play(sound, at)
		end,
		Loop = function(sound: string, at: Instance, on: boolean)
			audio:Loop(sound, at, on)
		end,
		Caller = function(): Vector3?
			const spot = Anchors.Spot(Content.Cutscenes.Rules.Stand.Target, 1, 1)
			return if spot ~= nil then spot.Position else nil
		end,
		Warn = function(key: string, message: string)
			self:WarnOnce(key, message)
		end,
		PassAt = function(target: string): (() -> number?)?
			return self:CrossClock(target)
		end,
		Bind = function(model: Model, set: string)
			anim:Bind(model, set)
		end,
		Action = function(model: Model, key: string)
			anim:Play(model, key)
		end,
		Folder = self:ActorFolder(),
	}
end

function CutsceneController:ActorFolder(): Folder
	const existing = self.Folder
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const folder = Instance.new("Folder")
	folder.Name = "CutsceneActors"
	folder.Parent = Workspace
	self.Folder = folder
	return folder
end

-- Segments ------------------------------------------------------------------------------------------------------

function CutsceneController:ClearSegment()
	for _, entry in self.Actors do
		entry.Actor.Destroy()
	end
	table.clear(self.Actors)
	for _, unmount in self.Balloons do
		unmount()
	end
	table.clear(self.Balloons)
	const walker = self.Walker
	self.Walker = nil
	if walker ~= nil then
		walker.Stop()
	end
	const speech = self.Speech
	if speech ~= nil then
		speech.Stop()
	end
	table.clear(self.Captions)
	self.Caption = nil
	const music = self.Music
	self.Music = nil
	if music ~= nil then
		self.Dependencies.AudioController:PopMusic(music)
	end
	-- cinema dressing off: shot rig, ambience and the scene's lighting look (LightController blends back)
	self.Dependencies.CameraController:SetRig(nil)
	const ambience = self.Ambience
	self.Ambience = nil
	if ambience ~= nil then
		ambience.Destroy()
	end
	Players.LocalPlayer:SetAttribute(LOOK_ATTRIBUTE, nil)
	Players.LocalPlayer:SetAttribute(NIGHTFALL_ATTRIBUTE, nil)
	self.Scene = nil
	self.Beats = {}
	table.clear(self.Fired)
	self.LookIndex = 0
	self.ShotIndex = 0
	self.HoldStart = nil
	Vide.batch(function()
		self.Voted(false)
		self.Progress(0)
		self.LineShown(false)
		self.PromptShown(false)
		self.Banner(false)
	end)
end

-- Master x Voice group of the AudioController (user volumes)
function CutsceneController:VoiceVolume(): number
	const volumes = self.Dependencies.AudioController.Volumes
	return (volumes.Master or 1) * (volumes.Voice or 1)
end

-- The text-to-speech of the session (built on first use; destroyed at the end of a chain)
function CutsceneController:SpeechOf(): Speech.Speech
	const existing = self.Speech
	if existing ~= nil then
		return existing
	end
	const speech = Speech.new(function(): number
		return self:VoiceVolume()
	end)
	self.Speech = speech
	return speech
end

-- Loads the voices of every intro line ahead (LoadingController, under the loading screen): the variant this
-- client will most likely see first (party = more than one player now), then the other. Yields until all are
-- settled or `timeout`; what is left keeps loading in the background. progress(0..1).
function CutsceneController:PreloadVoices(timeout: number, progress: ((number) -> ())?)
	const scene = Content.Cutscenes.ByKey[INTRO]
	if scene == nil then
		if progress ~= nil then
			progress(1)
		end
		return
	end
	-- one avatar: always the Solo variant
	const lines = Timeline.Beats(scene, false)
	-- the loading screen waits only for the lines of the first VOICE_AHEAD s of the scene; every line is queued in
	-- order of use, so the rest keeps loading in the background while the intro plays
	const speech = self:SpeechOf()
	const early: { Beat } = {}
	for _, beat in lines do
		if beat.At <= VOICE_AHEAD then
			table.insert(early, beat)
		end
	end
	speech.Prepare(lines)
	speech.Preload(early, timeout, progress)
end

function CutsceneController:BeginChain()
	self.Playing = true
	self.EndedAt = nil
	self.Windows = nil
	self.Active(true)
	Players.LocalPlayer:SetAttribute(ACTIVE_ATTRIBUTE, true)
	self:SpeechOf()
	-- one avatar in the scene whatever the server holds: always the Solo variant
	self.Party = false
	self.Mates = Hide.new()
	self.Dependencies.InputController:Hold("Cutscene", true)
	self.Dependencies.CameraController:Cutscene(true)
	self:BindSkip()
	self:StartStepping()
end

function CutsceneController:EndChain()
	if not self.Playing then
		return
	end
	self.Playing = false
	self.EndAlpha = Vide.untrack(self.Fade)
	self.EndBars = Vide.untrack(self.Bars)
	self.EndedAt = os.clock()
	self:ClearSegment()
	const speech = self.Speech
	self.Speech = nil
	if speech ~= nil then
		speech.Destroy()
	end
	self.Windows = nil
	const mates = self.Mates
	self.Mates = nil
	if mates ~= nil then
		mates.Restore()
	end
	self.Active(false)
	Players.LocalPlayer:SetAttribute(ACTIVE_ATTRIBUTE, nil)
	self.Skippable(false)
	self:UnbindSkip()
	self.Dependencies.CameraController:Cutscene(false)
	self.Dependencies.InputController:Hold("Cutscene", false)
end

function CutsceneController:BeginSegment(key: string, startedAt: number)
	const scene = Content.Cutscenes.ByKey[key]
	if scene == nil then
		self:EndChain()
		return
	end
	if not self.Playing then
		self:BeginChain()
	end
	self:ClearSegment()
	self.Scene = scene
	self.StartedAt = startedAt
	self.Beats = Timeline.Beats(scene, self.Party)
	-- a client that arrives in the middle starts here: nothing before now counts as live (a fresh segment, seen
	-- within LIVE_WINDOW of its start, plays its first beats live)
	const elapsed = Workspace:GetServerTimeNow() - startedAt
	self.LastElapsed = if elapsed <= LIVE_WINDOW then -LIVE_WINDOW else elapsed
	self.Dependencies.CameraController:Focus(nil, nil)
	self.Skippable(scene.Skippable)
	-- cinema dressing: the scene's lighting look and the living background
	if scene.Look ~= nil then
		Players.LocalPlayer:SetAttribute(LOOK_ATTRIBUTE, scene.Look)
	end
	if scene.Cinema == true then
		const anim = self.Dependencies.AnimController
		self.Ambience = Ambience.new({
			Bind = function(model: Model, set: string)
				anim:Bind(model, set)
			end,
		})
	end
	-- the own walk along the shared Route, and the voices of this segment loaded ahead
	self.Walker = Walker.new(scene, 1)
	const speech = self.Speech
	if speech ~= nil then
		speech.Prepare(self.Beats)
	end
	-- one music at a time: the scene's cue overrides the phase (AudioController keeps the shift track off meanwhile)
	const music = scene.Music
	if music ~= nil then
		self.Music = music
		self.Dependencies.AudioController:PushMusic(music)
	end
	self:Step()
end

function CutsceneController:Apply(record: Record?)
	const key = if record ~= nil then record.Scene else NONE
	Vide.batch(function()
		self.SceneKey(key)
		self.Votes(if record ~= nil then record.Votes else 0)
		self.Needed(if record ~= nil then record.Needed else 0)
		self.Waiting(if record ~= nil then record.Waiting else false)
	end)
	if key == NONE or Content.Cutscenes.ByKey[key] == nil then
		self:EndChain()
		return
	end
	const scene = self.Scene
	if scene == nil or scene.Key ~= key or record == nil or record.StartedAt ~= self.StartedAt then
		self:BeginSegment(key, if record ~= nil then record.StartedAt else Workspace:GetServerTimeNow())
	end
end

-- A segment the server has certainly ended by now (its Cap passed long ago)
local function overdue(key: string, startedAt: number): boolean
	const scene = Content.Cutscenes.ByKey[key]
	if scene == nil or key == NONE or startedAt <= 0 then
		return false
	end
	return Workspace:GetServerTimeNow() - startedAt > scene.Cap + STALE_MARGIN
end

-- Record 1 of the Cutscene set, or the last CutsceneSnapshot while the set has none (its keyframe was lost)
function CutsceneController:Current(): Record?
	const ok, stored = pcall(function()
		return self.Libs.Net.Cutscene:get(RECORD)
	end)
	const record = if ok then stored :: Record? else nil
	return if record ~= nil then record else self.Snapshot
end

-- Watchdog: the set's store (or the snapshot) read back, so a listener call lost with a dropped frame is applied
-- late, and a chain past its Cap ended locally (camera, input and HUD back): a lost update never holds the client
-- in a cutscene.
function CutsceneController:Watch()
	const record = self:Current()
	if record ~= nil then
		const key = record.Scene
		const scene = self.Scene
		const differs = if key == NONE or Content.Cutscenes.ByKey[key] == nil
			then self.Playing
			else not self.Playing or scene == nil or scene.Key ~= key or record.StartedAt ~= self.StartedAt
		if differs and not overdue(key, record.StartedAt) then
			self:Apply(record)
		elseif record.Waiting ~= Vide.untrack(self.Waiting) then
			self.Waiting(record.Waiting)
		end
	end
	const scene = self.Scene
	if self.Playing and scene ~= nil and overdue(scene.Key, self.StartedAt) then
		warn(`[CutsceneController] {scene.Key} ran past its cap without an end from the server: ending it here`)
		self:EndChain()
	end
end

-- Beats ---------------------------------------------------------------------------------------------------------

function CutsceneController:FireBeat(beat: Beat, live: boolean)
	if beat.Kind == "Actor" then
		if self.Actors[beat.Target] ~= nil then
			return
		end
		const actor = Actors.Create(beat.Target, self:ActorContext())
		if actor == nil then
			self:WarnOnce(`actor:{beat.Target}`, `actor "{beat.Target}" not shown (unknown target or map points missing)`)
			return
		end
		self.Actors[beat.Target] = { Actor = actor, At = beat.At }
	elseif beat.Kind == "Line" then
		self:QueueCaption(beat, live)
	elseif beat.Kind == "Prompt" and live then
		self:PlacePrompt(beat.Target)
	end
end

-- A fired Line beat joins the subtitle queue and asks the voice for its turn (live beats only; a catch-up line is shown
-- as text if it is still fresh). The text goes on screen when its voice STARTS (StepCaptions), not at the beat's At.
function CutsceneController:QueueCaption(beat: Beat, live: boolean)
	const caption: Caption = {
		Beat = beat,
		State = "Pending",
		Started = false,
		Ended = false,
		Missed = false,
		Silent = not live,
		Cancel = nil,
		ActiveAt = 0,
		ShownElapsed = 0,
		TailUntil = 0,
	}
	if not live then
		if Workspace:GetServerTimeNow() - self.StartedAt - beat.At > LINE_HOLD then
			return
		end
		caption.Missed = true
		table.insert(self.Captions, caption)
		return
	end
	table.insert(self.Captions, caption)
	const speech = self.Speech
	if speech == nil then
		caption.Missed = true
		return
	end
	-- handlers may fire inside Say (no voice at all): the caption is already queued
	caption.Cancel = speech.Say(beat, {
		OnStart = function()
			caption.Started = true
		end,
		OnEnd = function()
			caption.Ended = true
		end,
		OnMiss = function()
			caption.Missed = true
		end,
	})
end

-- The line on screen now (nil = none). One caption at a time, in order: it appears when its voice starts, stays until
-- the voice ended (+ CAPTION_TAIL); a line without a voice (off, failed, late, still loading) is read for LINE_HOLD s
-- like before. A voice that is late makes the text wait, never the opposite.
function CutsceneController:StepCaptions(elapsed: number): Beat?
	const now = os.clock()
	const queue = self.Captions
	const speech = self.Speech
	local current = self.Caption

	local function show(caption: Caption, state: string)
		caption.State = state
		caption.ShownElapsed = elapsed
	end

	for _ = 1, 16 do
		if current == nil then
			const head = table.remove(queue, 1)
			if head == nil then
				self.Caption = nil
				return nil
			end
			head.ActiveAt = now
			current = head
			self.Caption = head
		end
		const caption = current :: Caption
		if caption.State == "Pending" then
			if caption.Started or caption.Ended then
				show(caption, "Voice")
			elseif caption.Missed then
				show(caption, "Text")
			else
				const late = elapsed - caption.Beat.At
				const status = if speech ~= nil then speech.Peek(caption.Beat) else "Off"
				const loading = status == nil or status == "Queued" or status == "Loading"
				if
					status == "Off"
					or status == "Failed"
					or (loading and late > CAPTION_LOAD_LATE)
					or (late > CAPTION_VERY_LATE and now - caption.ActiveAt > CAPTION_VOICE_WAIT)
				then
					-- no voice is coming in time: this line is text only, and its voice (if it comes) is dropped
					caption.Missed = true
					if caption.Cancel ~= nil then
						caption.Cancel()
					end
					show(caption, "Text")
				else
					return nil
				end
			end
		end
		if caption.State == "Voice" then
			if caption.Ended then
				caption.State = "Tail"
				caption.TailUntil = now + CAPTION_TAIL
			else
				return caption.Beat
			end
		end
		if caption.State == "Tail" then
			if now >= caption.TailUntil then
				current = nil
				self.Caption = nil
			else
				return caption.Beat
			end
		elseif caption.State == "Text" then
			const shown = elapsed - caption.ShownElapsed
			local over = shown >= LINE_HOLD
			if not over and shown >= CAPTION_TEXT_MIN then
				const following = queue[1]
				if following ~= nil then
					over = following.Started or (following.Missed and following.Beat.At <= elapsed)
				end
			end
			if over then
				current = nil
				self.Caption = nil
			else
				return caption.Beat
			end
		end
	end
	return nil
end

function CutsceneController:PlacePrompt(target: string)
	const holder = self.PromptHolder
	const position = self:TargetPosition(target)
	if holder == nil or position == nil then
		return
	end
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace.CurrentCamera
end

-- An instant falls inside (last, elapsed]
local function crossed(at: number, elapsed: number, last: number): boolean
	return last < at and at <= elapsed
end

-- Cinema of this frame (scenes with Shots / Cinema): the camera rig of the shot, the black of a dip and the height of the
-- letterbox bars. Sounds (title, dip, shot cues) fire for instants crossed live only. Returns (dip, bar fraction).
function CutsceneController:StepCinema(scene: Scene, elapsed: number, last: number): (number, number)
	-- Nightfall (DEC-300): the scene's look leaves and LightController blends to the night of the shift over its Time
	const nightfall = scene.Nightfall
	const player = Players.LocalPlayer
	if nightfall ~= nil and elapsed >= nightfall.At and player:GetAttribute(NIGHTFALL_ATTRIBUTE) == nil then
		player:SetAttribute(NIGHTFALL_ATTRIBUTE, nightfall.Time)
		player:SetAttribute(LOOK_ATTRIBUTE, nil)
	end
	if scene.Cinema ~= true and scene.Shots == nil then
		return 0, 0
	end
	const cinema = Content.Cutscenes.Rules.Cinema
	const audio = self.Dependencies.AudioController
	const live = elapsed - last <= LIVE_WINDOW
	if scene.Shots ~= nil then
		self.Dependencies.CameraController:SetRig(Director.Rig(scene, elapsed, not Motion.Reduced()))
		if live then
			const shot, index = Director.ShotAt(scene, elapsed)
			if shot ~= nil and index ~= self.ShotIndex then
				self.ShotIndex = index
				if shot.Cue ~= nil and crossed(shot.At, elapsed, last) then
					audio:Play(shot.Cue)
				end
			end
			if Director.DipStarting(scene, elapsed, last) ~= nil then
				audio:Play(cinema.DipSound)
			end
		end
	end
	const title = Timeline.Last(self.Beats, "Text", elapsed)
	if live and title ~= nil and title.Target ~= "Credits" and crossed(title.At, elapsed, last) then
		audio:Play(cinema.TitleSound)
	end
	const ambience = self.Ambience
	if ambience ~= nil then
		ambience.Step(elapsed, math.clamp(elapsed - last, 0, 0.1))
	end
	if scene.Cinema ~= true then
		return Director.Dip(scene, elapsed), 0
	end
	return Director.Dip(scene, elapsed), self:BarFraction(Director.Bars(scene, elapsed))
end

-- Height of one letterbox bar as a fraction of the screen for `amount` (0..1) of closing: the bars of the 2.35:1 frame,
-- none on a screen narrower than MinAspect (portrait phone), never more than MaxBar
function CutsceneController:BarFraction(amount: number): number
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return 0
	end
	const cinema = Content.Cutscenes.Rules.Cinema
	const size = camera.ViewportSize
	const aspect = size.X / math.max(size.Y, 1)
	if aspect < cinema.MinAspect then
		return 0
	end
	return math.min((1 - aspect / cinema.Ratio) / 2, cinema.MaxBar) * amount
end

function CutsceneController:Step()
	const scene = self.Scene
	if scene == nil then
		return
	end
	const elapsed = Workspace:GetServerTimeNow() - self.StartedAt
	const last = self.LastElapsed
	self.LastElapsed = elapsed

	for index, beat in self.Beats do
		if beat.At > elapsed then
			break
		end
		if not self.Fired[index] then
			self.Fired[index] = true
			self:FireBeat(beat, beat.At > last - 1e-3 and elapsed - beat.At <= LIVE_WINDOW)
		end
	end

	-- camera focus: the last LookAt / Focus beat already reached
	const look, lookIndex = Timeline.LastOf(self.Beats, { LookAt = true, Focus = true }, elapsed)
	if lookIndex ~= self.LookIndex then
		self.LookIndex = lookIndex
		const camera = self.Dependencies.CameraController
		if look == nil then
			camera:Focus(nil, nil)
		elseif look.Kind == "Focus" then
			camera:Focus(self:FocusGetter(look.Target), look.Fov)
		else
			const position = self:TargetPosition(look.Target)
			if position == nil then
				self:WarnOnce(`look:{look.Target}`, `LookAt target "{look.Target}" not found`)
			end
			camera:Focus(if position ~= nil
				then function(): Vector3?
					return position
				end
				else nil, look.Fov)
		end
	end

	const mates = self.Mates
	if mates ~= nil then
		mates.Update()
	end
	const walker = self.Walker
	if walker ~= nil then
		walker.Step(elapsed, math.clamp(elapsed - last, 0, 0.1))
	end

	for _, entry in self.Actors do
		entry.Actor.Update(elapsed - entry.At, last - entry.At)
	end

	const dip, bars = self:StepCinema(scene, elapsed, last)

	const line = self:StepCaptions(elapsed)
	const title = Timeline.Title(self.Beats, elapsed, TITLE_HOLD, scene.Duration)
	const prompt = Timeline.Prompt(self.Beats, elapsed, PROMPT_TIME)
	-- the prompt "completes" when its fill ends (crossed live only)
	const lastPrompt = Timeline.Last(self.Beats, "Prompt", elapsed)
	if lastPrompt ~= nil and crossed(lastPrompt.At + PROMPT_TIME, elapsed, last) then
		self.Dependencies.AudioController:Play(PROMPT_SOUND)
	end
	Vide.batch(function()
		self.Fade(math.max(Timeline.Fade(self.Beats, elapsed, FADE_TIME), dip))
		self.Bars(bars)
		self.Vignette(if scene.Cinema == true then Content.Cutscenes.Rules.Cinema.Vignette * Director.Bars(scene, elapsed) else 0)
		if line ~= nil then
			const speaker = SPEAKERS[line.Speaker or "walt"] or "Walt"
			if Vide.untrack(self.Speaker) ~= speaker then
				self.Speaker(speaker)
			end
			if Vide.untrack(self.LineText) ~= (line.Text or "") then
				self.LineText(line.Text or "")
			end
		end
		if Vide.untrack(self.LineShown) ~= (line ~= nil) then
			self.LineShown(line ~= nil)
		end
		const banner = Vide.untrack(self.Banner)
		if title ~= nil then
			if banner == false or banner.Title ~= (title.Text or "") or banner.Line ~= (title.Sub or "") then
				self.Banner({ Title = title.Text or "", Line = title.Sub or "" })
			end
		elseif banner ~= false then
			self.Banner(false)
		end
		if prompt ~= nil and Vide.untrack(self.PromptText) ~= (prompt.Text or "") then
			self.PromptText(prompt.Text or "")
		end
		if Vide.untrack(self.PromptShown) ~= (prompt ~= nil) then
			self.PromptShown(prompt ~= nil)
		end
	end)

	self:StepHold()
end

-- Skip ----------------------------------------------------------------------------------------------------------

function CutsceneController:CanVote(): boolean
	return self.Playing and Vide.untrack(self.Skippable) and not Vide.untrack(self.Voted)
end

function CutsceneController:PressSkip()
	if self:CanVote() then
		self.HoldStart = os.clock()
	end
end

function CutsceneController:ReleaseSkip()
	self.HoldStart = nil
	if Vide.untrack(self.Progress) ~= 0 then
		self.Progress(0)
	end
end

function CutsceneController:StepHold()
	const start = self.HoldStart
	if start == nil then
		return
	end
	if not self:CanVote() then
		self:ReleaseSkip()
		return
	end
	const progress = (os.clock() - start) / HOLD_TIME
	if progress < 1 then
		self.Progress(progress)
		return
	end
	self.HoldStart = nil
	Vide.batch(function()
		self.Progress(0)
		self.Voted(true)
	end)
	-- one per segment; the server decides whether it counts (participant, connected, not voted)
	self.Libs.Net.SkipVote:fireServer()
	self.Dependencies.AudioController:Play(VOTE_SOUND)
	self.Dependencies.AnimController:PlayOwn(VOTE_CLIP)
end

function CutsceneController:BindSkip()
	const input = self.Dependencies.InputController
	input
		:Bind({
			Name = BIND_NAME,
			Key = Enum.KeyCode.E,
			Keys = { Enum.KeyCode.Space, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonA },
			-- touch: the SkipPill itself is the button (bottom right, >= 44 px)
			TouchButton = false,
			Priority = Enum.ContextActionPriority.High.Value + 1,
		})
		.OnPress(function()
			self:PressSkip()
		end)
		.OnRelease(function()
			self:ReleaseSkip()
		end)
end

function CutsceneController:UnbindSkip()
	self.Dependencies.InputController:Unbind(BIND_NAME)
	self:ReleaseSkip()
end

-- Frame loop ----------------------------------------------------------------------------------------------------

function CutsceneController:StartStepping()
	if self.Stepping then
		return
	end
	self.Stepping = true
	RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function()
		if self.Playing then
			self:Step()
			return
		end
		-- after the chain: back to clear, then stop
		const endedAt = self.EndedAt
		const progress = if endedAt ~= nil then (os.clock() - endedAt - END_HOLD) / END_FADE else 1
		self.Fade(self.EndAlpha * (1 - math.clamp(progress, 0, 1)))
		self.Bars(self.EndBars * (1 - math.clamp(progress, 0, 1)))
		self.Vignette(0)
		if progress >= 1 then
			self:StopStepping()
		end
	end)
end

function CutsceneController:StopStepping()
	if not self.Stepping then
		return
	end
	self.Stepping = false
	RunService:UnbindFromRenderStep(RENDER_STEP)
	self.Fade(0)
	self.Bars(0)
	self.Vignette(0)
end

-- UI ------------------------------------------------------------------------------------------------------------

function CutsceneController:Mount(gui: Instance)
	self.Gui = gui
	const input = self.Dependencies.InputController

	const holder = Instance.new("Part")
	holder.Name = "CutscenePromptHolder"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	self.PromptHolder = holder

	-- letterbox + vignette (scenes with Cinema), under the fade and the subtitles
	const unmountCinema, cinemaGui = Vide.root(function()
		const bar = function(name: string, anchor: Vector2, position: UDim2): Frame
			return Vide.create("Frame")({
				Name = name,
				AnchorPoint = anchor,
				Position = position,
				Size = function()
					return UDim2.fromScale(1, self.Bars())
				end,
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Visible = function()
					return self.Bars() > 0.001
				end,
			})
		end
		return Vide.create("ScreenGui")({
			Name = "CutsceneCinema",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = CINEMA_ORDER,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Vignette({ Name = "CutsceneVignette", Strength = self.Vignette, Color = VIGNETTE_COLOR }),
			bar("BarTop", Vector2.zero, UDim2.fromScale(0, 0)),
			bar("BarBottom", Vector2.new(0, 1), UDim2.fromScale(0, 1)),
		})
	end)
	cinemaGui.Parent = gui
	table.insert(self.Unmounts, function()
		unmountCinema()
		cinemaGui:Destroy()
	end)

	const unmountFade, fadeGui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "CutsceneFade",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = FADE_ORDER,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			ScreenFade({ Name = "CutsceneFade", Alpha = self.Fade }),
		})
	end)
	fadeGui.Parent = gui
	table.insert(self.Unmounts, function()
		unmountFade()
		fadeGui:Destroy()
	end)

	const unmountUi, uiGui = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "CutsceneScreen",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
			DisplayOrder = UI_ORDER,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			-- global UI scale (Theme.ScaleOf); the frame shrinks by the same factor to keep covering the screen
			Vide.create("Frame")({
				Name = "Scaled",
				Size = function()
					const s = UiScale.Current()
					return UDim2.fromScale(1 / s, 1 / s)
				end,
				BackgroundTransparency = 1,
				createRaw("UIScale")({ Scale = UiScale.Current }),

				HudBanner({ Name = "CutsceneTitle", Banner = self.Banner }),
				CallSubtitle({
					Name = "CutsceneSubtitle",
					Visible = function()
						return self.LineShown() and self.LineText() ~= ""
					end,
					Speaker = self.Speaker,
					Text = self.LineText,
					Phone = function()
						return "trailer"
					end,
				}),
				SkipPill({
					Name = "CutsceneSkip",
					Visible = function()
						return self.SceneKey() ~= NONE and self.Skippable()
					end,
					Votes = self.Votes,
					Needed = self.Needed,
					Voted = self.Voted,
					Progress = self.Progress,
					KeyLabel = function()
						return KEY_LABEL[input.Device()]
					end,
					OnPress = function()
						self:PressSkip()
					end,
					OnRelease = function()
						self:ReleaseSkip()
					end,
				}),
			}),
		})
	end)
	uiGui.Parent = gui
	table.insert(self.Unmounts, function()
		unmountUi()
		uiGui:Destroy()
	end)

	const unmountPrompt, promptGui = Vide.root(function()
		return PromptBillboard({
			Name = "CutscenePrompt",
			Adornee = holder,
			State = function()
				return if self.PromptShown() then "Prompt" else "Hidden"
			end,
			Text = self.PromptText,
			KeyLabel = function()
				return ""
			end,
			Holding = self.PromptShown,
			HoldDuration = function()
				return PROMPT_TIME
			end,
		})
	end)
	promptGui.Parent = gui
	table.insert(self.Unmounts, function()
		unmountPrompt()
		promptGui:Destroy()
		holder:Destroy()
	end)
end

-- Lifecycle -----------------------------------------------------------------------------------------------------

CutsceneController:OnInit(function(self)
	self:Setup()

	const cutscene = self.Libs.Net.Cutscene
	cutscene:onAdded(function(id, record)
		if id == RECORD then
			self:Apply(record :: Record)
		end
	end)
	cutscene:onChanged(function(id, record)
		if id == RECORD then
			self:Apply(record :: Record)
		end
	end)
	cutscene:onRemoved(function(id)
		if id == RECORD then
			self:Apply(nil)
		end
	end)
	-- fallback (Net CutsceneSnapshot): applied only while the set itself has no record 1
	self.Libs.Net.CutsceneSnapshot:onClient(function(record)
		self.Snapshot = record :: Record
		const ok, stored = pcall(function()
			return self.Libs.Net.Cutscene:get(RECORD)
		end)
		if ok and stored == nil then
			self:Watch()
		end
	end)
end)

CutsceneController:OnStart(function(self)
	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self:Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
		const record = self.Libs.Net.Cutscene:get(RECORD)
		if record ~= nil and not self.Playing then
			self:Apply(record :: Record)
		end
	end)
end)

CutsceneController:OnTick(function(self)
	self:Watch()
end, WATCH_RATE)

return CutsceneController
