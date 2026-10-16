--!strict
--[[
	LoadingController: the "client ready" gate of a join (user feedback 2026-10-11: the start of the intro was lost
	while the client was still loading, and the voices failed to load). Drives the loading screen that Loading/Boot
	(ReplicatedFirst) put up, then tells the server with `ClientReady`; CutsceneService holds the intro until every
	participant sent it (Content.Cutscenes.Rules.ReadyTimeout at most).

	Steps (weights of the real progress bar), the slow ones in parallel:
	  Game     game:IsLoaded()                                                     (the engine join)
	  Start    every Modux controller ran its OnStart: this controller has the lowest priority, so the Loader
	           (descending priority, OnInit of all then OnStart of all) reaches its OnStart last
	  Kit      RigController warm-up done (crew meshes, expressions, look textures: RigController:Warmup)
	  Assets   LoadQueue (the one audio queue, small batches) of the intro sounds (music cue, phone, horns, car, prompt, skip, day
	           ambience) and the UI images (Icons.Ids)
	  Voices   Run place only: the text-to-speech lines of the first seconds of the intro (CutsceneController:
	           PreloadVoices; one piece at a time with retry, see Speech.luau); the later intro lines keep loading in
	           order of use. Walt's tutorial lines (rookies) load in the background after the curtain lifts
	           (BackgroundVoices), during the intro that comes before the tutorial (playtest 2026-10-11: the gate took
	           ~45 s with all of them blocking)
	Every step has its own timeout and the whole gate STEP_CAP (18 s); a step that fails or times out never blocks the join.
	After ClientReady the curtain stays while the server says the intro is Waiting for the other participants
	(Cutscene set) up to the server's ReadyTimeout + margin, then lifts (attribute Done on the ScreenGui).

	Skip (playtest 2026-10-14): after 10 s the boot shows "Skip loading"; a skip lifts the curtain at once and sets the
	local attribute LoadingSkipped on the LocalPlayer. Here that sends ClientReady and sets Ready right away (the player
	is in); the steps keep running in the background and the end of the gate (Lift) still releases the audio queue and
	starts the background voices when they are done.

	Ready = Vide source, true once the curtain lifted or the player skipped it (the gate is over for this join).
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local LoadQueue = require(StarterPlayer.StarterPlayerScripts.client.Audio.AudioController.LoadQueue)

type Texts = { Status: { [string]: string } }

const GUI_NAME = "LoadingScreen"
const SKIPPED_ATTRIBUTE = "LoadingSkipped" -- set on the LocalPlayer by Loading/Boot when the player skips
const KIT_TIMEOUT = 10 -- s for the crew kit warm-up (it keeps going in the background; RigController has its own cap)
const MAP_TIMEOUT = 14 -- s for the meshes and textures of the map / lobby (the rest keeps loading behind the curtain)
const ASSET_TIMEOUT = 12 -- s for PreloadAsync of sounds and images
const VOICE_TIMEOUT = 8 -- s for the intro voices of the first seconds (the rest keeps loading in the background)
const TUTORIAL_VOICE_TIMEOUT = 150 -- s the background load of Walt's tutorial lines may run (rookies only)
const STEP_CAP = 18 -- s for all steps together (the server's ReadyTimeout stays 10 s above it)
const CREW_MARGIN = 3 -- s past the server's ReadyTimeout that the curtain waits for the others
const POLL = 0.1
const INTRO = "intro"
-- intro sounds besides the scene's music cue and the car horns (Content.Sounds keys; missing keys are skipped)
const INTRO_SOUNDS = {
	"phone_pickup",
	"phone_hangup",
	"phone_ring",
	"prompt_done",
	"skip_vote",
	"car_engine",
	"amb_day_street",
}
-- weights of the steps on the bar
const WEIGHTS: { [string]: number } = { Game = 1, Start = 0.5, Kit = 2, Assets = 2, Voices = 3, Map = 3 }
-- texts (ReplicatedFirst/client/Loading/Tips); fallback when the boot folder is missing (Studio without it)
const FALLBACK_STATUS: { [string]: string } = {
	Game = "Loading...",
	Kit = "Loading...",
	Assets = "Loading...",
	Voices = "Loading...",
	Crew = "Waiting for the crew...",
	Done = "Ready!",
}

local function texts(): { [string]: string }
	const folder = ReplicatedFirst:FindFirstChild("client")
	const loading = if folder ~= nil then folder:FindFirstChild("Loading") else nil
	const module = if loading ~= nil then loading:FindFirstChild("Tips") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return FALLBACK_STATUS
	end
	const ok, result = pcall(function(): Texts
		return (require :: any)(module)
	end)
	return if ok and type(result) == "table" and type(result.Status) == "table" then result.Status else FALLBACK_STATUS
end

const LoadingController = Modux.Controller("LoadingController", {
	Require = { "PlaceController", "RigController", "CutsceneController", "TutorialController" },
	-- lowest priority of the client: its OnStart runs after every other controller's OnStart
	Priority = -1000,
})

function LoadingController:Setup()
	self.Ready = Vide.source(false) :: Vide.Source<boolean>
	self.Progress = Vide.source(0) :: Vide.Source<number>
	self.Status = texts() :: { [string]: string }
	-- fraction 0..1 of each step
	self.Steps = { Game = 0, Start = 0, Kit = 0, Assets = 0, Voices = 0, Map = 0 } :: { [string]: number }
	self.Gui = nil :: ScreenGui?
	self.Sent = false :: boolean
	self.Skipped = false :: boolean
end

-- The player skipped the loading screen (Loading/Boot): in now, the loading goes on behind
function LoadingController:Skip()
	if self.Skipped then
		return
	end
	self.Skipped = true
	self:SendReady()
	self.Ready(true)
end

function LoadingController:WatchSkip()
	const player = Players.LocalPlayer
	if player:GetAttribute(SKIPPED_ATTRIBUTE) == true then
		self:Skip()
		return
	end
	local connection: RBXScriptConnection? = nil
	connection = player:GetAttributeChangedSignal(SKIPPED_ATTRIBUTE):Connect(function()
		if player:GetAttribute(SKIPPED_ATTRIBUTE) == true then
			self:Skip()
			if connection ~= nil then
				connection:Disconnect()
			end
		end
	end)
end

function LoadingController:FindGui(): ScreenGui?
	const existing = self.Gui
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	const gui = if playerGui ~= nil then playerGui:FindFirstChild(GUI_NAME) else nil
	if gui ~= nil and gui:IsA("ScreenGui") then
		self.Gui = gui
		return gui
	end
	return nil
end

function LoadingController:SetStatus(key: string)
	const gui = self:FindGui()
	if gui ~= nil then
		gui:SetAttribute("Status", self.Status[key] or FALLBACK_STATUS[key] or "")
	end
end

-- Step fraction -> weighted bar (never goes back)
function LoadingController:Mark(step: string, fraction: number)
	const steps = self.Steps
	steps[step] = math.max(steps[step] or 0, math.clamp(fraction, 0, 1))
	local total, done = 0, 0
	for key, weight in WEIGHTS do
		total += weight
		done += weight * (steps[key] or 0)
	end
	const value = if total > 0 then done / total else 1
	self.Progress(value)
	const gui = self:FindGui()
	if gui ~= nil then
		const shown = gui:GetAttribute("Progress")
		if type(shown) ~= "number" or value > shown then
			gui:SetAttribute("Progress", value)
		end
	end
end

-- Sounds and images of the intro, as PreloadAsync items
function LoadingController:AssetList(): { any }
	const list: { any } = {}
	const keys: { string } = table.clone(INTRO_SOUNDS)
	const scene = Content.Cutscenes.ByKey[INTRO]
	if scene ~= nil and scene.Music ~= nil then
		const cue = Content.Music.ByKey[scene.Music]
		if cue ~= nil then
			table.insert(keys, cue.Sound)
		end
	end
	for _, car in Content.Cutscenes.Rules.Cars do
		table.insert(keys, car.Horn)
	end
	const seen: { [string]: boolean } = {}
	for _, key in keys do
		const row = Content.Sounds.ByKey[key]
		if row == nil or row.Id == "" or seen[row.Id] then
			continue
		end
		seen[row.Id] = true
		const sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = row.Id
		table.insert(list, sound)
	end
	const ids: { [string]: string } = Icons.Ids :: any
	for _, id in ids do
		if id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	return list
end

-- Runs `work(progress)` in its own thread; returns when it ends or after `timeout` (the work keeps running)
local function within(timeout: number, work: () -> ())
	local finished = false
	task.spawn(function()
		const ok, problem = pcall(work)
		if not ok then
			warn(`[LoadingController] loading step failed: {problem}`)
		end
		finished = true
	end)
	const deadline = os.clock() + timeout
	while not finished and os.clock() < deadline do
		task.wait(POLL)
	end
end

function LoadingController:StepKit()
	const rig = self.Dependencies.RigController
	const started = os.clock()
	within(KIT_TIMEOUT, function()
		while not rig.Warm do
			-- the warm-up has no progress of its own: creep towards 90 % while it runs
			self:Mark("Kit", math.min((os.clock() - started) / 8, 0.9))
			task.wait(POLL)
		end
	end)
	self:Mark("Kit", 1)
end

function LoadingController:StepAssets()
	const list = self:AssetList()
	const total = #list
	local done = 0
	within(ASSET_TIMEOUT, function()
		if total == 0 then
			return
		end
		-- sounds through the one audio queue (urgent: before AudioController's background preload), in small
		-- batches; images straight to PreloadAsync (no audio rate limit)
		const sounds: { any } = {}
		const images: { any } = {}
		for _, item in list do
			table.insert(if typeof(item) == "Instance" then sounds else images, item)
		end
		local soundsDone = 0
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(images, function()
					done += 1
					self:Mark("Assets", (done + soundsDone) / total)
				end)
			end)
		end)
		LoadQueue.Preload(sounds, function(count: number)
			soundsDone = count
			self:Mark("Assets", (done + soundsDone) / total)
		end, true)
	end)
	self:Mark("Assets", 1)
	for _, item in list do
		if typeof(item) == "Instance" then
			(item :: Instance):Destroy()
		end
	end
end

-- Meshes, textures and decals of the world the player lands in (lobby or run map): one representative instance per
-- distinct mesh + texture pair goes to PreloadAsync, so the pieces do not show up untextured (user report 2026-10-12)
function LoadingController:MapAssetList(): { Instance }
	const list: { Instance } = {}
	const seen: { [string]: boolean } = {}
	for _, root in workspace:GetChildren() do
		if not (string.match(root.Name, "_Assets$") or string.match(root.Name, "^LOBBY") or root.Name == "MapBinding") then
			continue
		end
		for _, item in root:GetDescendants() do
			local key: string? = nil
			if item:IsA("MeshPart") then
				key = `{item.MeshId}|{item.TextureID}`
			elseif item:IsA("Decal") or item:IsA("Texture") then
				key = `d|{(item :: Decal).Texture}`
			elseif item:IsA("SurfaceAppearance") then
				-- ColorMap / NormalMap are Plugin-only reads ("lacking capability Plugin"): dedupe by the mesh it dresses
				const parent = item.Parent
				key = `s|{if parent ~= nil and parent:IsA("MeshPart") then parent.MeshId else ""}|{item.Name}`
			end
			if key ~= nil and not seen[key] then
				seen[key] = true
				table.insert(list, item)
			end
		end
	end
	return list
end

function LoadingController:StepMap()
	const list = self:MapAssetList()
	const total = #list
	if total == 0 then
		self:Mark("Map", 1)
		return
	end
	local done = 0
	within(MAP_TIMEOUT, function()
		-- batches keep the progress honest and let a slow asset hold back only its own batch
		const BATCH = 24
		for first = 1, total, BATCH do
			const batch = table.move(list, first, math.min(first + BATCH - 1, total), 1, {})
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			done += #batch
			self:Mark("Map", math.min(done / total, 0.99))
		end
	end)
	self:Mark("Map", 1)
end

function LoadingController:StepVoices()
	if not self.Dependencies.PlaceController:Is("Run") then
		self:Mark("Voices", 1)
		return
	end
	self:SetStatus("Voices")
	-- only the intro lines of its first seconds are waited for (CutsceneController:PreloadVoices queues the whole
	-- scene in order of use); Walt's tutorial lines load in the background after the curtain lifts (Lift)
	within(VOICE_TIMEOUT + 1, function()
		self.Dependencies.CutsceneController:PreloadVoices(VOICE_TIMEOUT, function(fraction: number)
			self:Mark("Voices", fraction)
		end)
	end)
	self:Mark("Voices", 1)
end

-- After the curtain: the tutorial voices of a rookie load during the intro (~2 min before the tutorial starts)
function LoadingController:BackgroundVoices()
	if not self.Dependencies.PlaceController:Is("Run") then
		return
	end
	task.spawn(function()
		const ok, problem = pcall(function()
			self.Dependencies.TutorialController:PreloadVoices(TUTORIAL_VOICE_TIMEOUT)
		end)
		if not ok then
			warn(`[LoadingController] background tutorial voices failed: {problem}`)
		end
	end)
end

function LoadingController:Run()
	-- 1. the engine join
	self:SetStatus("Game")
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	self:Mark("Game", 1)
	-- 2. every controller started (this OnStart is the last one)
	self:Mark("Start", 1)

	-- 3-5. kit, assets and voices together
	self:SetStatus("Kit")
	local pending = 4
	local function done()
		pending -= 1
	end
	task.spawn(function()
		self:StepKit()
		self:SetStatus("Assets")
		done()
	end)
	task.spawn(function()
		self:StepAssets()
		done()
	end)
	task.spawn(function()
		self:StepVoices()
		done()
	end)
	task.spawn(function()
		self:StepMap()
		done()
	end)
	const deadline = os.clock() + STEP_CAP
	while pending > 0 and os.clock() < deadline do
		task.wait(POLL)
	end
	for key in WEIGHTS do
		self:Mark(key, 1)
	end

	-- the server may start the intro now
	self:SendReady()

	-- hold the curtain while the intro waits for the other participants (not after a skip: the curtain is gone)
	const cutscene = self.Dependencies.CutsceneController
	if self.Dependencies.PlaceController:Is("Run") and not self.Skipped then
		const holdUntil = os.clock() + Content.Cutscenes.Rules.ReadyTimeout + CREW_MARGIN
		-- one beat for the set to arrive after the packet
		task.wait(0.3)
		if Vide.untrack(cutscene.Waiting) then
			self:SetStatus("Crew")
		end
		while Vide.untrack(cutscene.Waiting) and os.clock() < holdUntil do
			task.wait(POLL)
		end
	end

	self:SetStatus("Done")
	self:Lift()
end

function LoadingController:SendReady()
	if self.Sent then
		return
	end
	self.Sent = true
	self.Libs.Net.ClientReady:fireServer()
end

function LoadingController:Lift()
	-- the audio queue may run its background jobs now; the tutorial voices start loading behind the intro
	LoadQueue.Release()
	self:BackgroundVoices()
	self.Ready(true)
	const gui = self:FindGui()
	if gui ~= nil then
		gui:SetAttribute("Done", true)
	end
end

LoadingController:OnInit(function(self)
	self:Setup()
end)

LoadingController:OnStart(function(self)
	self:WatchSkip()
	task.spawn(function()
		const ok, problem = pcall(function()
			self:Run()
		end)
		if not ok then
			warn(`[LoadingController] loading gate failed, letting the player in: {problem}`)
			self:SendReady()
			self:Lift()
		end
	end)
end)

return LoadingController
