--!strict
--[[
	HideController (TASK-103; architecture.md §19.14, network.md §13.6; FEAT-023; DEC-054, 176, 177)

	Presents the `Hides` set (id = UserId, { Slot = 1..4 }); HideService decides who hides, where and when they are
	released. Nothing is applied locally: getting up waits for the server to remove the record.

	  Own record      "Get Up" pill (PromptBillboard, >= 44 px, tappable) low in the view + binding "GetUp"
	                  (Space/E, gamepad A/X, CAS touch button 72 px). Fires Interact{ Id = spot EntityId,
	                  Action = "get_up" }. Plays the looped `hide` clip on the own Animator (replicates to all).
	  Mates' records  pose: the owner's `hide` track replicates; if it has not arrived after POSE_GRACE s (late join,
	                  stream) the same clip plays locally on the mate's rig and stops when the record goes.
	  Prompts         Rules.SetHideProbe: hidden = no prompt at all; a taken spot shows no "Hide".

	The low camera (`CameraController` mode `Hidden`) is TASK-101; it can read `Hidden()` / `MySlot()` from here.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Clips = require(StarterPlayer.StarterPlayerScripts.client.Anim.AnimController.Clips)
local Rules = require(StarterPlayer.StarterPlayerScripts.client.Interaction.PromptController.Rules)
local PromptBillboard = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PromptBillboard)

const TAG = "Interactable"
const HIDE_ACTION = "hide"
const GET_UP_ACTION = "get_up"
const POSE_KEY = "hide"
const BIND_NAME = "GetUp"
const TOUCH_SIZE = 72
const KEY_LABEL = { KeyboardMouse = "Space", Gamepad = "A", Touch = "" }
-- Re-send floor while the server has not answered (network.md §4.1: <= 8/s).
const FIRE_INTERVAL = 0.5
const POSE_GRACE = 0.6
-- Where the pill floats, relative to the camera (studs): low centre of the view.
const PILL_OFFSET = CFrame.new(0, -1.6, -5)

export type HideRecord = { Slot: number }

const HideController = Modux.Controller(
	"HideController",
	{ Require = { "InputController", "AnimController" }, Priority = 660 }
)

function HideController:Setup()
	-- Slots: UserId -> Slot. MySlot: 0 = not hidden. LocalPoses: UserId -> rig where this client plays the pose.
	self.Slots = {} :: { [number]: number }
	self.MySlot = Vide.source(0) :: Vide.Source<number>
	self.Hidden = function(): boolean
		return self.MySlot() ~= 0
	end
	self.LocalPoses = {} :: { [number]: Model }
	self.LastFire = 0 :: number
	self.Gui = nil :: Instance?
	self.Unmount = nil :: (() -> ())?
	self.Holder = nil :: BasePart?
	self.Follow = nil :: RBXScriptConnection?
end

function HideController:IsHidden(userId: number): boolean
	return self.Slots[userId] ~= nil
end

function HideController:SlotOf(userId: number): number?
	return self.Slots[userId]
end

function HideController:SlotTaken(slot: number): boolean
	for _, taken in self.Slots do
		if taken == slot then
			return true
		end
	end
	return false
end

-- EntityId of the hide spot H<slot> (Interactable, PromptAction "hide", Slot n; MapIndex Required wave 3).
function HideController:SpotId(slot: number): number?
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:GetAttribute("PromptAction") == HIDE_ACTION and anchor:GetAttribute("Slot") == slot then
			const id = anchor:GetAttribute("EntityId")
			if typeof(id) == "number" and id >= 1 and id <= 65535 and id % 1 == 0 then
				return id
			end
		end
	end
	return nil
end

function HideController:GetUp()
	const slot = self.MySlot()
	if slot == 0 or Content.Actions.ByKey[GET_UP_ACTION] == nil then
		return
	end
	const now = os.clock()
	if now - self.LastFire < FIRE_INTERVAL then
		return
	end
	const id = self:SpotId(slot)
	if id == nil then
		warn(`[HideController] no Interactable with PromptAction "hide" and Slot {slot}; get_up not sent`)
		return
	end
	self.LastFire = now
	self.Libs.Net.Interact:fireServer({ Id = id, Action = GET_UP_ACTION })
end

-- Pill ----------------------------------------------------------------------------------------------------------

function HideController:ShowButton()
	const input = self.Dependencies.InputController
	if input.Handles[BIND_NAME] == nil then
		input
			:Bind({
				Name = BIND_NAME,
				Key = Enum.KeyCode.Space,
				Keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonX },
				TouchButton = true,
				Title = "Get Up",
				TouchSize = TOUCH_SIZE,
				Priority = Enum.ContextActionPriority.High.Value,
				Context = "Gameplay",
			})
			.OnPress(function()
				self:GetUp()
			end)
	end

	const gui = self.Gui
	if gui == nil or self.Unmount ~= nil then
		return
	end

	-- Local invisible holder in front of the camera: the pill stays low in the view whatever the camera mode.
	const holder = Instance.new("Part")
	holder.Name = "HideGetUpHolder"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Parent = workspace.CurrentCamera
	self.Holder = holder
	self.Follow = RunService.RenderStepped:Connect(function()
		const camera = workspace.CurrentCamera
		if camera then
			holder.CFrame = camera.CFrame * PILL_OFFSET
		end
	end)

	self.Unmount = Vide.mount(function()
		return PromptBillboard({
			Name = "HideGetUp",
			Adornee = holder,
			State = function()
				return if self.MySlot() ~= 0 then "Prompt" else "Hidden"
			end,
			Text = function()
				return Content.Actions.ByKey[GET_UP_ACTION].Text
			end,
			KeyLabel = function()
				return KEY_LABEL[input.Device()]
			end,
			Holding = function()
				return false
			end,
			HoldDuration = function()
				return 0
			end,
			OnPress = function()
				self:GetUp()
			end,
		})
	end, gui)
end

function HideController:HideButton()
	self.Dependencies.InputController:Unbind(BIND_NAME)
	const unmount = self.Unmount
	self.Unmount = nil
	if unmount then
		unmount()
	end
	const follow = self.Follow
	self.Follow = nil
	if follow then
		follow:Disconnect()
	end
	const holder = self.Holder
	self.Holder = nil
	if holder then
		holder:Destroy()
	end
end

-- Pose ----------------------------------------------------------------------------------------------------------

local function hasTrack(rig: Model, animationId: string): boolean
	const humanoid = rig:FindFirstChildOfClass("Humanoid")
	const animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return false
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Animation and track.Animation.AnimationId == animationId then
			return true
		end
	end
	return false
end

function HideController:PoseMate(userId: number)
	task.delay(POSE_GRACE, function()
		if self.Slots[userId] == nil or self.LocalPoses[userId] then
			return
		end
		const clip = Clips.Action(POSE_KEY)
		const player = Players:GetPlayerByUserId(userId)
		const rig = if player then player.Character else nil
		if clip == nil or rig == nil or hasTrack(rig, clip.Id) then
			return -- empty id, no rig, or the owner's track already replicated
		end
		if self.Dependencies.AnimController:Play(rig, POSE_KEY, { Looped = true }) then
			self.LocalPoses[userId] = rig
		end
	end)
end

function HideController:UnposeMate(userId: number)
	const rig = self.LocalPoses[userId]
	self.LocalPoses[userId] = nil
	if rig then
		self.Dependencies.AnimController:Stop(rig, POSE_KEY)
	end
end

-- Set -----------------------------------------------------------------------------------------------------------

function HideController:Apply(userId: number, slot: number?)
	const before = self.Slots[userId]
	if before == slot then
		return
	end
	self.Slots[userId] = slot

	const anim = self.Dependencies.AnimController
	if userId == Players.LocalPlayer.UserId then
		self.MySlot(slot or 0)
		if slot then
			anim:PlayOwn(POSE_KEY, { Looped = true })
			self:ShowButton()
		else
			anim:StopOwn(POSE_KEY)
			self:HideButton()
		end
	elseif slot and before == nil then
		self:PoseMate(userId)
	elseif slot == nil then
		self:UnposeMate(userId)
	end
end

HideController:OnInit(function(self)
	self:Setup()

	const hides = self.Libs.Net.Hides
	hides:onAdded(function(id, record)
		self:Apply(id, (record :: HideRecord).Slot)
	end)
	hides:onChanged(function(id, record)
		self:Apply(id, (record :: HideRecord).Slot)
	end)
	hides:onRemoved(function(id)
		self:Apply(id, nil)
	end)

	Rules.SetHideProbe({
		IsHidden = function(userId: number): boolean
			return self:IsHidden(userId)
		end,
		SlotTaken = function(slot: number): boolean
			return self:SlotTaken(slot)
		end,
	})
end)

HideController:OnStart(function(self)
	-- Respawn while still hidden (rare: the server releases on Down) keeps the pose.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		if self.MySlot() ~= 0 then
			task.defer(function()
				self.Dependencies.AnimController:PlayOwn(POSE_KEY, { Looped = true })
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.LocalPoses[player.UserId] = nil
	end)

	-- PlayerGui may arrive a frame late; do not hold up the other OnStart.
	task.spawn(function()
		self.Gui = Players.LocalPlayer:WaitForChild("PlayerGui")
		if self.MySlot() ~= 0 then
			self:ShowButton()
		end
	end)
end)

return HideController
