--!strict
--[[
	SuspenseController (TASK-481; DEC-294; design/horror-cinematic.md §7; tech/suspense.md). Presentation only (T10):
	where, when and how much it costs are the server's (SuspenseService).

	Packet Suspense { Id, Event, Spot, Seed }: the creature of Content.Suspense[Event] appears AT ONCE on Spot (MapPoint
	Spot.Point when the place has it, else Spot.Position, dropped to the floor), facing Spot.Face, scaled by
	Event.Scale x Spot.Scale; the body is the family B kit's (Anomaly/.../Kit/Hide.luau, Hide.Build). It waits up to
	Rules.Life s. The glance: in first person, its head comes on screen (inside Rules.ScreenMargin of the edges), within
	Rules.SeenRange studs and in clear line from the camera. Then, once:
	  * SuspenseSeen { Id } to the server (it charges the sanity, once per player per event);
	  * the camera is hijacked: CameraController:HorrorPull towards the head (Hijack.Pull degrees over Hijack.Duration),
	    HorrorFov zoom in and back, a HorrorShake;
	  * "sub drop" (suspense_drop, on screen) + a short hiss on the creature (suspense_hiss), both Scare (DEC-173);
	  * Screen.Pulse + edges closing and opening (Screen.SetVignette, channel "suspense");
	  * whispers from Content.HorrorScenes.Words.suspense after the pull;
	  * the creature is gone Hijack.Linger s later.
	Unseen by the end of Rules.Life: it simply vanishes. Motion.Reduced(): the camera API scales itself
	(HorrorScenes.Rules.ReduceMotion) and Screen.Pulse is skipped; no pull/zoom beyond that.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Kit = StarterPlayer.StarterPlayerScripts.client.Anomaly.AnomalyController.Effects.Kit
local Hide = require(Kit.Hide)
local Screen = require(Kit.Screen)
local Whispers = require(Kit.Whispers)

type Show = {
	Id: number,
	Event: Content.SuspenseEvent,
	Model: Model,
	Head: Vector3,
	EndsAt: number, -- os.clock
	Seen: boolean,
	Connection: RBXScriptConnection?,
}

const RULES = Content.Suspense.Rules
const HIJACK = RULES.Hijack
const FOLDER_NAME = "SuspenseEvents"
const CHANNEL = "suspense" -- Screen vignette channel
const DROP_KEY = "suspense_drop"
const HISS_KEY = "suspense_hiss"
const GROUND_UP = 6
const GROUND_DOWN = 20
const ZOOM_HOLD = 0.5 -- s the zoom stays in after the pull before it eases back

const SuspenseController = Modux.Controller("SuspenseController", {
	Require = { "CameraController", "AudioController" },
	Priority = 550,
})

function SuspenseController:Setup()
	self.Show = nil :: Show?
	self.Folder = nil :: Folder?
end

function SuspenseController:FolderOf(): Folder
	const current = self.Folder
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	self.Folder = folder
	return folder
end

local function exclude(extra: { Instance }): RaycastParams
	const params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	const ignore = table.clone(extra)
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

-- Feet and facing of a spot (MapPoint first, then the Content position), feet dropped to the floor.
local function poseOf(spot: Content.SuspenseSpot): CFrame
	const point = MapIndex.FindPoint(spot.Point)
	local feet = if point ~= nil then point.Position else spot.Position
	const hit = Workspace:Raycast(feet + Vector3.new(0, GROUND_UP, 0), Vector3.new(0, -GROUND_DOWN, 0), exclude({}))
	if hit ~= nil then
		feet = hit.Position
	end
	local look = if point ~= nil then point.LookVector else spot.Face - feet
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(feet, feet + look.Unit)
end

-- Removes the current creature at once (new event, end of life, after the glance).
function SuspenseController:Clear()
	const show = self.Show
	if show == nil then
		return
	end
	self.Show = nil
	if show.Connection ~= nil then
		show.Connection:Disconnect()
	end
	show.Model:Destroy()
end

-- Head on screen (inside the margin), in range and in clear line from the camera, in first person.
function SuspenseController:Glanced(show: Show): boolean
	const camera = Workspace.CurrentCamera
	if camera == nil or self.Dependencies.CameraController.Mode() ~= "FirstPerson" then
		return false
	end
	const origin = camera.CFrame.Position
	const offset = show.Head - origin
	if offset.Magnitude > RULES.SeenRange then
		return false
	end
	const screen, visible = camera:WorldToViewportPoint(show.Head)
	if not visible or screen.Z <= 0 then
		return false
	end
	const size = camera.ViewportSize
	const margin = RULES.ScreenMargin
	if
		screen.X < size.X * margin
		or screen.X > size.X * (1 - margin)
		or screen.Y < size.Y * margin
		or screen.Y > size.Y * (1 - margin)
	then
		return false
	end
	return Workspace:Raycast(origin, offset, exclude({ show.Model })) == nil
end

-- The scare, once per event on this client.
function SuspenseController:Catch(show: Show)
	show.Seen = true
	self.Libs.Net.SuspenseSeen:fireServer({ Id = show.Id })

	const camera = self.Dependencies.CameraController
	camera:HorrorPull(show.Head, HIJACK.Pull, HIJACK.Duration)
	camera:HorrorFov(HIJACK.Fov, 0, HIJACK.Duration + ZOOM_HOLD)
	camera:HorrorShake(HIJACK.Shake)

	const audio = self.Dependencies.AudioController
	audio:Play(DROP_KEY, nil, { Scare = true })
	audio:Play(HISS_KEY, show.Head, { Scare = true })

	Screen.Pulse(HIJACK.Pulse)
	Screen.SetVignette(HIJACK.Vignette, 0, HIJACK.VignetteFor, CHANNEL)

	const id = show.Id
	task.delay(HIJACK.Linger, function()
		const current = self.Show
		if current ~= nil and current.Id == id then
			self:Clear()
		end
	end)
	task.delay(HIJACK.Duration, function()
		Whispers.Play(HIJACK.Words, Content.HorrorScenes.Words.suspense)
	end)
end

function SuspenseController:Begin(data: { Id: number, Event: string, Spot: string, Seed: number })
	const event = Content.Suspense.ByKey[data.Event]
	const spot = Content.Suspense.Spots.ByKey[data.Spot]
	if event == nil or spot == nil then
		return
	end
	self:Clear()
	const scale = event.Scale * spot.Scale
	const model = Hide.Build(event.Style, event.Asset, self:FolderOf(), `Suspense_{event.Key}`)
	if math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(scale)
	end
	const pose = poseOf(spot)
	model:PivotTo(pose)
	const show: Show = {
		Id = data.Id,
		Event = event,
		Model = model,
		Head = pose.Position + Vector3.new(0, event.Head * scale, 0),
		EndsAt = os.clock() + RULES.Life,
		Seen = false,
		Connection = nil,
	}
	self.Show = show
	show.Connection = RunService.RenderStepped:Connect(function()
		if self.Show ~= show or show.Seen then
			return
		end
		if os.clock() >= show.EndsAt then
			self:Clear()
		elseif self:Glanced(show) then
			self:Catch(show)
		end
	end)
end

-- Character reset / teleport: the creature and the edges go.
function SuspenseController:Reset()
	self:Clear()
	Screen.ClearVignette(CHANNEL)
end

SuspenseController:OnInit(function(self)
	self:Setup()
	self.Libs.Net.Suspense:onClient(function(data)
		self:Begin(data)
	end)
end)

SuspenseController:OnStart(function(self)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		self:Reset()
	end)
end)

return SuspenseController
