local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modux = require(game.ReplicatedStorage.Shared.Modux)
local vide = require(ReplicatedStorage.Packages.vide)
local source, effect, cleanup, root = vide.source, vide.effect, vide.cleanup, vide.root

local AnimateController = Modux.Controller("AnimateController")
type Self = typeof(AnimateController)

export type AnimState = "Idle" | "Walk" | "Sprint" | "CrouchIdle" | "CrouchWalk" | "Jump" | "Fall" | "Land"

export type MovementMode = "Walk" | "Sprint" | "Crouch"

type Source<T> = (() -> T) & ((value: T) -> T)

local FADE_TIME = 0.15
local IDLE_GRACE = 0.2

local IdleStates: { [AnimState]: boolean } = {
	Idle = true,
	CrouchIdle = true,
}

local LoopedStates: { [AnimState]: boolean } = {
	Idle = true,
	Walk = true,
	Sprint = true,
	CrouchIdle = true,
	CrouchWalk = true,
	Fall = true,
	Jump = false,
	Land = false,
}

local AnimationIds = {
	Idle = source(94719732720980),
	Walk = source(106291253767285),
	Sprint = source(131893667820080),
	CrouchIdle = source(94719732720980),
	CrouchWalk = source(94719732720980),
	Vault = source(94719732720980),
	Fall = source(94719732720980),
	Land = source(94719732720980),
}

local function LoadTrack(animator: Animator, id: number, looped: boolean): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id

	local track = animator:LoadAnimation(animation)
	track.Looped = looped

	animation:Destroy()
	return track
end

local function ComputeState(
	humanoidState: Enum.HumanoidStateType,
	moveDirection: Vector3,
	movementMode: MovementMode
): AnimState
	if humanoidState == Enum.HumanoidStateType.Jumping then
		return "Jump"
	elseif humanoidState == Enum.HumanoidStateType.Freefall then
		return "Fall"
	elseif humanoidState == Enum.HumanoidStateType.Landed then
		return "Land"
	end

	local isMoving = moveDirection.Magnitude > 0

	if movementMode == "Crouch" then
		return if isMoving then "CrouchWalk" else "CrouchIdle"
	elseif movementMode == "Sprint" then
		return if isMoving then "Sprint" else "Idle"
	end

	return if isMoving then "Walk" else "Idle"
end

AnimateController.LoadAnimator = function(self: Self, humanoid: Humanoid): { [AnimState]: AnimationTrack }
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local tracks = {}
	for state, id in AnimationIds do
		tracks[state] = LoadTrack(animator, id(), LoopedStates[state])
	end

	return tracks
end

AnimateController.TrackHumanoid = function(self: Self, humanoid: Humanoid)
	if self._destroyAnimationRoot then
		self._destroyAnimationRoot()
		self._destroyAnimationRoot = nil
	end

	local tracks = self:LoadAnimator(humanoid)

	local destroyRoot = root(function()
		local humanoidState = source(humanoid:GetState())
		local moveDirection = source(humanoid.MoveDirection)

		cleanup(humanoid.StateChanged:Connect(function(_, newState) --modux ignore line
			humanoidState(newState)
		end))

		cleanup(humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function() --modux ignore line
			moveDirection(humanoid.MoveDirection)
		end))

		cleanup(function()
			for _, track in tracks do
				track:Stop(0)
				track:Destroy()
			end
		end)

		local previousState: AnimState? = nil
		local idleToken = nil :: unknown

		local function applyState(state: AnimState)
			if state == previousState then
				return
			end

			local previousTrack = previousState and tracks[previousState]
			if previousTrack then
				previousTrack:Stop(FADE_TIME)
			end

			local nextTrack = tracks[state]
			if nextTrack then
				nextTrack:Play(FADE_TIME)
			end

			previousState = state
		end

		effect(function()
			local state = ComputeState(humanoidState(), moveDirection(), self.MovementMode())

			if not IdleStates[state] then
				idleToken = nil
				applyState(state)
				return
			end

			local token = {}
			idleToken = token
			task.delay(IDLE_GRACE, function()
				if idleToken == token then
					applyState(state)
				end
			end)
		end)
	end)

	self._destroyAnimationRoot = destroyRoot
end

AnimateController:OnInit(function(self)
	self.MovementMode = source("Walk" :: MovementMode) :: Source<MovementMode>

	self.Network.Packages.AnimationState:on(function(data: { State: string })
		if data.State == "Walk" or data.State == "Sprint" or data.State == "Crouch" then
			self.MovementMode(data.State :: MovementMode)
		end
	end)

	task.defer(function()
		local function onCharacterAdded(character: Model)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			self:TrackHumanoid(humanoid)
		end

		self:Cleanup(self.LocalPlayer.CharacterAdded:Connect(onCharacterAdded))
		if self.LocalPlayer.Character then
			onCharacterAdded(self.LocalPlayer.Character)
		end
	end)
end)

AnimateController:OnStart(function(self)
	--> LOCK FOR THIS GAME ONLY
	self.LocalPlayer.CharacterAdded:Connect(function(a0: Model) --modux ignore line
		local humanoid = a0:WaitForChild("Humanoid") :: Humanoid
		humanoid.JumpHeight = 0
	end)

	local currentChar = self.LocalCharacter
	if currentChar then
		currentChar:FindFirstChild("Humanoid")
		local humanoid = currentChar:WaitForChild("Humanoid") :: Humanoid
		humanoid.JumpHeight = 0
	end
end)

return AnimateController
