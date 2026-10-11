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
	  Focus     focus on a live target: a car actor (followed), "Poster", "Phone" (real map instances, Anchors),
	            "Windows" (nearest NO HELP WANTED card ahead) or "Walk" (where the body walks); Fov narrows the view
	  Prompt    PromptBillboard on the target that fills by itself (input locked, script.md §1)
	  Line      subtitle strip (CallSubtitle): "Walt" lines, or "You" for crew lines + a SpeechBalloon over each mate;
	            voiced by text-to-speech when the engine has it (Speech.luau, Rules.Voices; subtitles only otherwise)
	  Actor     local actors (Actors.luau): street cars of the traffic kit, flip phone, Walt, coffee, Raincoat Lady,
	            flyer, Mart bell

	Cutscene active (for the HUD and anyone else): `CutsceneController.Active` (Vide source, true from the first
	segment to the end of the chain) and the attribute `CutsceneActive` (true / nil) on Players.LocalPlayer.

	Every frame is a function of (beats, server time - StartedAt): a late or rejoining client lands on the same frame
	(Timeline.luau). Sounds and balloons only fire for beats crossed live, never on catch-up.

	Skip (DEC-078, DEC-194): SkipPill bottom right, "Skip (votes/needed)" from the set. Hold for HOLD_TIME (E, Space,
	gamepad X/A, or press the pill on touch) -> one `SkipVote` per segment. The own vote only marks the pill; the count
	shown is always the server's. A new segment (finale -> credits) clears the own vote.

	While a chain plays: CameraController:Cutscene(true), input context "Menu" (world prompts off; the skip bind has
	no context), music cue pushed per scene (AudioController:PushMusic). All restored when Scene goes back to "none".

	PROVISIONAL (TASK-121):
	  * Solo/Party variant = more than one player in the server when the chain starts (the set has no roster).
	  * Slot 1 of the flip phone (Q-106 c) = the avatar standing nearest to CS-P1 when the beat fires.
	  * HOLD_TIME, FADE_TIME, LINE_HOLD, TITLE_HOLD, PROMPT_TIME, BALLOON_TIME, look heights; crew speaker "You".
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
local CallSubtitle = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CallSubtitle)
local HudBanner = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudBanner)
local PromptBillboard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PromptBillboard)
local ScreenFade = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ScreenFade)
local SkipPill = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SkipPill)
local SpeechBalloon = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SpeechBalloon)
local Actors = require(script.Actors)
local Speech = require(script.Speech)
local Timeline = require(script.Timeline)
local Walker = require(script.Walker)

type Beat = Content.CutsceneBeat
type Scene = Content.Cutscene

export type Record = { Scene: string, StartedAt: number, Votes: number, Needed: number }
-- HudBanner.Shown, local so the generated type file needs no component require
type Shown = { Title: string, Line: string } | false

const RECORD = 1
const NONE = "none"
const BIND_NAME = "CutsceneSkip"
const KEY_LABEL = { KeyboardMouse = "E", Gamepad = "X", Touch = "" }
const RENDER_STEP = "CutsceneController.Timeline"
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value - 1 -- LookAt lands before the camera reads it

-- PROVISIONAL presentation numbers (TASK-121)
const HOLD_TIME = 0.6 -- s of hold for a skip vote ("Hold to skip", ui-text.md §7)
const FADE_TIME = 1 -- s of each Fade beat
const END_FADE = 0.8 -- s back to clear when the chain ends
const LINE_HOLD = 3.5 -- s a line stays without a next one
const TITLE_HOLD = 3 -- s of a title
const PROMPT_TIME = 1.2 -- s the "Call" prompt takes to fill by itself
const BALLOON_TIME = 2.5 -- s of a crew balloon over a mate
const LOOK_LIFT = Vector3.new(0, 3, 0) -- look target above a ground point
const FLYER_HEIGHT = 4.5 -- the P-01 flyer, same as Actors
const BALLOON_OFFSET = Vector3.new(0, 2.6, 0)
const BALLOON_DISTANCE = 60
const LIVE_WINDOW = 0.75 -- s: a beat crossed later than this after its At is catch-up (no sound, no balloon)
const FADE_ORDER = 51 -- above the vehicle fade (50) and the HUD
const UI_ORDER = 52 -- subtitles and skip over the black
const SPEAKERS: { [string]: string } = { walt = "Walt", crew = "You" }
-- music cue per scene (Content.Music); nil = the default cue of the phase (credits: the finale cue of the Finale
-- phase keeps playing; no credits music, user decision 2026-10-10)
const SCENE_MUSIC: { [string]: string } = { finale = "finale" }
const PROMPT_SOUND = "prompt_done"
const VOTE_SOUND = "skip_vote"
const VOTE_CLIP = "wave_skip"
const ACTIVE_ATTRIBUTE = "CutsceneActive"
const ACTOR_LIFT = Vector3.new(0, 2, 0) -- focus on a car: a bit above its base
const WINDOW_PATTERN = "NoHelp" -- NO HELP WANTED cards (AST-033_NoHelpSign, blockout Window_NoHelpWanted_*)
const WINDOW_RANGE = 34 -- studs: cards farther than this are not glanced at
const WINDOW_AHEAD = 0.15 -- dot with the walk heading: only cards ahead or beside

const CutsceneController = Modux.Controller("CutsceneController", {
	Require = { "InputController", "CameraController", "AnimController", "AudioController" },
	Priority = 560,
})

function CutsceneController:Setup()
	-- set mirror
	self.SceneKey = Vide.source(NONE) :: Vide.Source<string>
	self.Votes = Vide.source(0) :: Vide.Source<number>
	self.Needed = Vide.source(0) :: Vide.Source<number>
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
	self.Speech = nil :: Speech.Speech?
	self.Windows = nil :: { BasePart }?
	-- chain
	self.Playing = false :: boolean
	self.Party = false :: boolean
	self.PreviousContext = nil :: string?
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
			const spot = Anchors.Spot(Content.Cutscenes.Rules.Stand.Target, 1, #Players:GetPlayers())
			return if spot ~= nil then spot.Position else nil
		end,
		Warn = function(key: string, message: string)
			self:WarnOnce(key, message)
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
	const music = self.Music
	self.Music = nil
	if music ~= nil then
		self.Dependencies.AudioController:PopMusic(music)
	end
	self.Scene = nil
	self.Beats = {}
	table.clear(self.Fired)
	self.LookIndex = 0
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

function CutsceneController:BeginChain()
	self.Playing = true
	self.EndedAt = nil
	self.Windows = nil
	self.Active(true)
	Players.LocalPlayer:SetAttribute(ACTIVE_ATTRIBUTE, true)
	if self.Speech == nil then
		self.Speech = Speech.new(function(): number
			return self:VoiceVolume()
		end)
	end
	self.Party = #Players:GetPlayers() > 1
	const input = self.Dependencies.InputController
	self.PreviousContext = input.Context
	input:SetContext("Menu")
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
	self.EndedAt = os.clock()
	self:ClearSegment()
	const speech = self.Speech
	self.Speech = nil
	if speech ~= nil then
		speech.Destroy()
	end
	self.Windows = nil
	self.Active(false)
	Players.LocalPlayer:SetAttribute(ACTIVE_ATTRIBUTE, nil)
	self.Skippable(false)
	self:UnbindSkip()
	self.Dependencies.CameraController:Cutscene(false)
	const input = self.Dependencies.InputController
	if input.Context == "Menu" then
		input:SetContext(if self.PreviousContext == "Menu" then "Menu" else "Gameplay")
	end
	self.PreviousContext = nil
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
	-- the own walk along the shared Route, and the voices of this segment loaded ahead
	self.Walker = Walker.new(scene, #Players:GetPlayers())
	const speech = self.Speech
	if speech ~= nil then
		speech.Prepare(self.Beats)
	end
	const music = SCENE_MUSIC[key]
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
	elseif beat.Kind == "Line" and live then
		const speech = self.Speech
		if speech ~= nil then
			speech.Say(beat)
		end
		if beat.Speaker == "crew" then
			self:CrewBalloons(beat.Text or "")
		end
	elseif beat.Kind == "Prompt" and live then
		self:PlacePrompt(beat.Target)
	end
end

-- "crew" lines: a balloon over each mate (each client sees the others, not itself, DEC-088)
function CutsceneController:CrewBalloons(text: string)
	const gui = self.Gui
	if gui == nil or text == "" then
		return
	end
	for _, player in Players:GetPlayers() do
		if player == Players.LocalPlayer then
			continue
		end
		const character = player.Character
		const head = if character ~= nil then character:FindFirstChild("Head") else nil
		if head == nil then
			continue
		end
		const shown = Vide.source(true)
		const unmount, balloon = Vide.root(function()
			return SpeechBalloon({
				Name = "CutsceneBalloon",
				Adornee = head,
				Visible = shown,
				Text = function()
					return text
				end,
				StudsOffset = BALLOON_OFFSET,
				MaxDistance = BALLOON_DISTANCE,
			})
		end)
		balloon.Parent = gui
		local done = false
		local function close()
			if done then
				return
			end
			done = true
			unmount()
			balloon:Destroy()
		end
		table.insert(self.Balloons, close)
		task.delay(BALLOON_TIME, close)
	end
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

	const walker = self.Walker
	if walker ~= nil then
		walker.Step(elapsed, math.clamp(elapsed - last, 0, 0.1))
	end

	for _, entry in self.Actors do
		entry.Actor.Update(elapsed - entry.At, last - entry.At)
	end

	const line = Timeline.Line(self.Beats, elapsed, LINE_HOLD)
	const title = Timeline.Title(self.Beats, elapsed, TITLE_HOLD, scene.Duration)
	const prompt = Timeline.Prompt(self.Beats, elapsed, PROMPT_TIME)
	-- the prompt "completes" when its fill ends (crossed live only)
	const lastPrompt = Timeline.Last(self.Beats, "Prompt", elapsed)
	if lastPrompt ~= nil and crossed(lastPrompt.At + PROMPT_TIME, elapsed, last) then
		self.Dependencies.AudioController:Play(PROMPT_SOUND)
	end
	Vide.batch(function()
		self.Fade(Timeline.Fade(self.Beats, elapsed, FADE_TIME))
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
			if banner == false or banner.Title ~= (title.Text or "") then
				self.Banner({ Title = title.Text or "", Line = "" })
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
		const progress = if endedAt ~= nil then (os.clock() - endedAt) / END_FADE else 1
		self.Fade(self.EndAlpha * (1 - math.clamp(progress, 0, 1)))
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
			IgnoreGuiInset = false,
			DisplayOrder = UI_ORDER,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			HudBanner({ Name = "CutsceneTitle", Banner = self.Banner }),
			CallSubtitle({
				Name = "CutsceneSubtitle",
				Visible = self.LineShown,
				Speaker = self.Speaker,
				Text = self.LineText,
				Phone = function()
					return "cart"
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

return CutsceneController
