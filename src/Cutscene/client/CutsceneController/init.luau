--!strict
--[[
	CutsceneController (TASK-121; architecture.md §19.16; network.md §6.2, §13.7; FEAT-004, FEAT-027; script.md §1;
	ending.md §2.2, §2.4; MAP-01 §11; DEC-078, DEC-088, DEC-097, DEC-194, DEC-202, DEC-203, DEC-205)

	Presents the `Cutscene` set (record 1; Scene "none" = idle). CutsceneService decides everything that matters:
	which scene, when each segment starts and ends, the vote count and the threshold, where the bodies stand and walk
	(Freeze + PivotTo + MoveTo). This client only shows the beats of Content.Cutscenes over the server clock:

	  Fade      ScreenFade over the whole screen (black before the first beat when that beat is a fade in)
	  Text      HudBanner title ("Bellmoor"; "Credits" stays until the next fade)
	  MoveTo    nothing here: the server walks the bodies
	  LookAt    CameraController:LookAt(point / post / Walt's mark) inside the Cutscene POV (own head, free look)
	  Prompt    PromptBillboard on the target that fills by itself (input locked, script.md §1)
	  Line      subtitle strip (CallSubtitle): "Walt" lines, or "You" for crew lines + a SpeechBalloon over each mate
	  Actor     local actors (Actors.luau): toy cars, flip phone, Walt, coffee, Raincoat Lady, flyer, Mart bell

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
local CallSubtitle = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CallSubtitle)
local HudBanner = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudBanner)
local PromptBillboard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PromptBillboard)
local ScreenFade = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ScreenFade)
local SkipPill = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SkipPill)
local SpeechBalloon = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SpeechBalloon)
local Actors = require(script.Actors)
local Timeline = require(script.Timeline)

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
-- music cue per scene (Content.Music); nil = the default cue of the phase
const SCENE_MUSIC: { [string]: string } = { finale = "finale", credits = "credits" }
const PROMPT_SOUND = "prompt_done"
const VOTE_SOUND = "skip_vote"
const VOTE_CLIP = "wave_skip"

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

	-- segment
	self.Scene = nil :: Scene?
	self.StartedAt = 0 :: number
	self.Beats = {} :: { Beat }
	self.Fired = {} :: { [number]: boolean }
	self.LastElapsed = 0 :: number
	self.Actors = {} :: { [string]: { Actor: Actors.Actor, At: number } }
	self.LookIndex = 0 :: number
	self.Music = nil :: string?
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

-- Where a LookAt / Prompt target is: a MapPoint (+ LOOK_LIFT) or a street post (flyer height)
function CutsceneController:TargetPosition(target: string): Vector3?
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

function CutsceneController:BeginChain()
	self.Playing = true
	self.EndedAt = nil
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
	self.Dependencies.CameraController:LookAt(nil)
	self.Skippable(scene.Skippable)
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
	elseif beat.Kind == "Line" and live and beat.Speaker == "crew" then
		self:CrewBalloons(beat.Text or "")
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

	-- camera look: the last LookAt beat already reached
	const look, lookIndex = Timeline.Last(self.Beats, "LookAt", elapsed)
	if lookIndex ~= self.LookIndex then
		self.LookIndex = lookIndex
		const position = if look ~= nil then self:TargetPosition(look.Target) else nil
		if look ~= nil and position == nil then
			self:WarnOnce(`look:{look.Target}`, `LookAt target "{look.Target}" not found`)
		end
		self.Dependencies.CameraController:LookAt(position)
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
