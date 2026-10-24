--!strict
--[[
	DevCameraController (TASK-C1, docs/marketing/trailer-blackout-60s.md §7; owner request 2026-10-20, Provisional)

	Trailer capture camera, dev mode only (PlaceController:IsDev). Plays the keyframed tracks of
	src/Dev/shared/CameraTracks.luau on the own camera when `/dev track <key>` (Dev/Commands/Track.luau) writes the
	Player attributes DevCameraTrack = key and DevCameraTrackAt = server time of the start:

	  - the CameraController hands the camera over through its "External" mode (the same hand-off the lobby uses:
	    in that mode it leaves CameraType, CFrame and field of view alone); the mode it had comes back at the end;
	  - every frame t = GetServerTimeNow() - At picks the two keys around it and eases Pos / Look / Fov / Roll with
	    the Ease of the next key (TweenService InOut; "Hold" stays on the previous key and jumps at the next T);
	  - a track with HideUi hides the game UI (every ScreenGui of PlayerGui but the anomaly / horror-scene ones and
	    the interaction prompts, the core GUIs and the chat window) and puts it back exactly as it was;
	  - the Note of a key is printed in the client Output when it is reached (what to do at that second);
	  - after Duration, or when the attribute is cleared (`track stop`), everything goes back.

	Also sends the own camera to the server at 2 Hz (Net.DevCameraHere) so `/dev track here` can print the current
	view as a Key line.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CameraTracks = require(ReplicatedStorage.shared.Dev.CameraTracks)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

type Key = CameraTracks.Key
type Track = CameraTracks.Track
type CameraMode = "FirstPerson" | "Spectate" | "Fixed" | "Cutscene" | "Prep" | "External"

type Playing = {
	Track: Track,
	At: number, -- server time of the start
	Reached: number, -- index of the last key whose Note was printed
	ModeBefore: CameraMode,
	FovBefore: number,
	Hidden: boolean,
}

type SavedUi = {
	Guis: { [ScreenGui]: boolean },
	Core: { [Enum.CoreGuiType]: boolean },
	Chat: boolean?,
}

const PREFIX = "[DevCamera]"
const TRACK_ATTRIBUTE = "DevCameraTrack" -- written by Dev/Commands/Track.luau
const AT_ATTRIBUTE = "DevCameraTrackAt"
const RENDER_STEP = "DevCameraController.Track"
-- after the CameraController's own step (Camera + 1): the track is the last word on the camera this frame
const RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 2
const HERE_INTERVAL = 0.5 -- s between DevCameraHere packets (2 Hz)
const HERE_SETTLE = 8 -- s after the game loaded before the first DevCameraHere (past the boot hitches)
const HERE_DISTANCE = 10 -- studs ahead of the camera the Look point is placed
const DEFAULT_EASE = "Linear"
const EASING: { [string]: Enum.EasingStyle } = {
	Linear = Enum.EasingStyle.Linear,
	Sine = Enum.EasingStyle.Sine,
	Quad = Enum.EasingStyle.Quad,
	Cubic = Enum.EasingStyle.Cubic,
}
-- ScreenGuis that stay while HideUi is on: the horror scene / anomaly layers (captions, cinema bars, whispers,
-- jumpscares, overlays) and the interaction prompts, which the trailer shots depend on (§5 #27, #28, #32).
-- Provisional (TASK-C7 will make this selective hide a feature of its own).
const KEEP_GUIS: { [string]: boolean } = {
	HorrorScene = true,
	HorrorCinema = true,
	HorrorScore = true,
	HorrorScreen = true,
	HideWhispers = true,
	Jumpscare = true,
	AnomalySubtitle = true,
	BreakerNote = true,
	SceneGlass = true,
	ANM008_Blind = true,
	HushRun = true,
	BellStroke = true,
	WaltRadio = true,
	InteractionMenu = true,
}

const DevCameraController = Modux.Controller("DevCameraController", {
	Require = { "CameraController", "PlaceController" },
	Priority = 300,
})

local function findTrack(key: string): Track?
	for _, track in CameraTracks do
		if track.Key == key then
			return track
		end
	end
	return nil
end

-- Eased alpha between two keys with the Ease of the next one
local function alphaBetween(from: Key, to: Key, t: number): number
	const span = to.T - from.T
	if span <= 0 then
		return 1
	end
	const ease = to.Ease or DEFAULT_EASE
	if ease == "Hold" then
		return 0
	end
	const linear = math.clamp((t - from.T) / span, 0, 1)
	const style = EASING[ease] or Enum.EasingStyle.Linear
	return TweenService:GetValue(linear, style, Enum.EasingDirection.InOut)
end

-- Pos, Look, Fov and Roll at t (the first key before its T, the last after its T; Fov / Roll inherit the previous key)
local function sample(track: Track, t: number, baseFov: number): (Vector3, Vector3, number, number)
	const keys = track.Keys
	local fov = baseFov
	local roll = 0
	local previous = keys[1]
	for index, key in keys do
		if t < key.T then
			if index == 1 then
				return key.Pos, key.Look, key.Fov or baseFov, key.Roll or 0
			end
			const alpha = alphaBetween(previous, key, t)
			const toFov = key.Fov or fov
			const toRoll = key.Roll or roll
			return previous.Pos:Lerp(key.Pos, alpha),
				previous.Look:Lerp(key.Look, alpha),
				fov + (toFov - fov) * alpha,
				roll + (toRoll - roll) * alpha
		end
		previous = key
		fov = key.Fov or fov
		roll = key.Roll or roll
	end
	return previous.Pos, previous.Look, fov, roll
end

function DevCameraController:Setup()
	self.Enabled = false :: boolean
	self.Playing = nil :: Playing?
	self.Saved = { Guis = {}, Core = {}, Chat = nil } :: SavedUi
	self.NextHere = 0 :: number
end

-- Game UI out of the way (restored as it was by ShowUi). Guis added during the track are left alone.
function DevCameraController:HideUi()
	const saved = self.Saved
	table.clear(saved.Guis)
	table.clear(saved.Core)
	const playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui ~= nil then
		for _, gui in playerGui:GetChildren() do
			if gui:IsA("ScreenGui") and not KEEP_GUIS[gui.Name] then
				saved.Guis[gui] = gui.Enabled
				gui.Enabled = false
			end
		end
	end
	for _, item in Enum.CoreGuiType:GetEnumItems() do
		const coreType = item :: Enum.CoreGuiType
		if coreType == Enum.CoreGuiType.All then
			continue
		end
		const ok, enabled = pcall(function(): boolean
			return StarterGui:GetCoreGuiEnabled(coreType)
		end)
		if ok then
			saved.Core[coreType] = enabled
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if chat ~= nil then
		saved.Chat = chat.Enabled
		chat.Enabled = false
	end
end

function DevCameraController:ShowUi()
	const saved = self.Saved
	for gui, enabled in saved.Guis do
		if gui.Parent ~= nil then
			gui.Enabled = enabled
		end
	end
	for coreType, enabled in saved.Core do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, enabled)
	end
	const chat = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if chat ~= nil and saved.Chat ~= nil then
		chat.Enabled = saved.Chat == true
	end
	table.clear(saved.Guis)
	table.clear(saved.Core)
	saved.Chat = nil
end

function DevCameraController:Play(key: string)
	const track = findTrack(key)
	if track == nil then
		warn(`{PREFIX} unknown track "{key}" (src/Dev/shared/CameraTracks.luau)`)
		return
	end
	if #track.Keys == 0 then
		warn(`{PREFIX} {key} has no keys`)
		return
	end
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const player = Players.LocalPlayer
	const at = player:GetAttribute(AT_ATTRIBUTE)
	const cameras = self.Dependencies.CameraController
	local playing = self.Playing
	if playing ~= nil then
		-- a new track while one plays: keep the owner's mode and the field of view saved at the first start
		playing.Track = track
		playing.At = if type(at) == "number" then at else workspace:GetServerTimeNow()
		playing.Reached = 0
		if track.HideUi and not playing.Hidden then
			self:HideUi()
			playing.Hidden = true
		elseif not track.HideUi and playing.Hidden then
			self:ShowUi()
			playing.Hidden = false
		end
	else
		playing = {
			Track = track,
			At = if type(at) == "number" then at else workspace:GetServerTimeNow(),
			Reached = 0,
			ModeBefore = Vide.untrack(cameras.Mode),
			FovBefore = camera.FieldOfView,
			Hidden = track.HideUi,
		}
		self.Playing = playing
		-- "External": the CameraController leaves the camera alone (lobby hand-off, CameraController.ApplyCamera)
		cameras:SetMode("External")
		if track.HideUi then
			self:HideUi()
		end
		RunService:BindToRenderStep(RENDER_STEP, RENDER_PRIORITY, function()
			self:Step()
		end)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	print(`{PREFIX} {track.Key} ({track.Name}): {track.Duration} s, {#track.Keys} keys`)
end

function DevCameraController:Stop(reason: string)
	const playing = self.Playing
	if playing == nil then
		return
	end
	self.Playing = nil
	RunService:UnbindFromRenderStep(RENDER_STEP)
	const camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.FieldOfView = playing.FovBefore
		camera.CameraType = Enum.CameraType.Custom
	end
	if playing.Hidden then
		self:ShowUi()
	end
	-- the same return the lobby makes: Fixed / Spectate need their target, so FirstPerson and the camera driver
	-- picks the right mode again on its next pass
	const before = playing.ModeBefore
	if before ~= "External" then
		self.Dependencies.CameraController:SetMode(if before == "Cutscene" then "Cutscene" else "FirstPerson")
	end
	print(`{PREFIX} {playing.Track.Key} {reason}`)
end

-- Prints the Note of every key reached since the last frame
function DevCameraController:Notes(playing: Playing, t: number)
	const keys = playing.Track.Keys
	while playing.Reached < #keys and keys[playing.Reached + 1].T <= t do
		playing.Reached += 1
		const key = keys[playing.Reached]
		if key.Note ~= nil then
			print(`{PREFIX} {string.format("%.1f", key.T)} s: {key.Note}`)
		end
	end
end

function DevCameraController:Step()
	const playing = self.Playing
	const camera = workspace.CurrentCamera
	if playing == nil or camera == nil then
		return
	end
	const t = workspace:GetServerTimeNow() - playing.At
	if t >= playing.Track.Duration then
		self:Stop("done")
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	const pos, look, fov, roll = sample(playing.Track, t, playing.FovBefore)
	const aim = if (look - pos).Magnitude > 1e-3 then look else pos + Vector3.zAxis
	camera.CFrame = CFrame.lookAt(pos, aim) * CFrame.Angles(0, 0, math.rad(roll))
	camera.FieldOfView = fov
	self:Notes(playing, t)
end

-- Reads the attribute: a key starts (or switches) a track, nil stops it
function DevCameraController:Refresh()
	const key = Players.LocalPlayer:GetAttribute(TRACK_ATTRIBUTE)
	if type(key) == "string" then
		self:Play(key)
	else
		self:Stop("stopped")
	end
end

-- The own camera to the server (2 Hz) for `track here`
function DevCameraController:SendHere(now: number)
	if now < self.NextHere then
		return
	end
	self.NextHere = now + HERE_INTERVAL
	const camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	const frame = camera.CFrame
	self.Libs.Net.DevCameraHere:fireServer({
		Pos = frame.Position,
		Look = frame.Position + frame.LookVector * HERE_DISTANCE,
	})
end

DevCameraController:OnInit(function(self)
	self:Setup()
	self.Enabled = self.Dependencies.PlaceController:IsDev()
end)

DevCameraController:OnStart(function(self)
	if not self.Enabled then
		return
	end
	const player = Players.LocalPlayer
	player:GetAttributeChangedSignal(TRACK_ATTRIBUTE):Connect(function()
		self:Refresh()
	end)
	if player:GetAttribute(TRACK_ATTRIBUTE) ~= nil then
		self:Refresh()
	end
	-- the first packets waited out the boot hitch (a frame over 1 s) and tripped Lync's "queued and never flushed" check:
	-- start sending once the game is loaded and settled
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		task.wait(HERE_SETTLE)
		RunService.Heartbeat:Connect(function()
			self:SendHere(os.clock())
		end)
	end)
end)

return DevCameraController
