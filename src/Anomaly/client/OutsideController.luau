--!strict
--[[
	OutsideController (owner 2026-10-16, reworked 2026-10-18: "quando o player está fora do trailer ... faz ele ser
	progressivo ... se ele passar 30 segundos lá de fora ... perseguir o player"). Presentation only (T10): the clock, the
	chaser and the catch are Anomaly/server/OutsideService; this client reads its attributes on the LocalPlayer:
	  OutsideStage  "Rise" | "Chase" | "Caught" (nil = nothing), OutsideAt = server time the stage began
	  ChasePos      the chaser's feet while it runs (Vector3, every server tick)
	and plays Content.HorrorScenes.Outside through the scene kits (Scene/Steps: the same whispers, bars, edges, heart,
	grading, silence, bell as the anomaly scenes), personal to this player:
	  Rise    the 30 s of dread;  Chase  the bell, the runner (Effects/Kit/Runner) on him, the chase words;
	  Escape  (stage cleared while chasing or rising) the calm back;  Caught  the face (Kit/Jumpscare) and the hit.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
local Steps = require(script.Parent.AnomalyController.Scene.Steps)
local Jumpscare = require(script.Parent.AnomalyController.Effects.Kit.Jumpscare)
local Runner = require(script.Parent.AnomalyController.Effects.Kit.Runner)

type Step = Content.HorrorStep

const SCENE = Content.HorrorScenes.Outside
const STATE_ID = -7 -- a local scene id that no Anomalies record uses
const KEY = "outside_hunt"
const LATE = 0.6 -- s a one-shot may start late
const HELD: { [string]: boolean } = { Whispers = true, Vignette = true, Heartbeat = true, Cinema = true, Grade = true, Silence = true }
const CLEAR_AFTER = 5 -- s after the escape / catch steps before the kits are cleared
const RUNNER_SCALE = 1.6
const FOLLOW = 10 -- 1/s: how fast the drawn runner closes on the server position

const OutsideController = Modux.Controller("OutsideController", {
	Require = { "AnomalyController" },
	Priority = 40,
})

function OutsideController:Setup()
	self.Stage = "" :: string
	self.Token = 0 :: number
	self.State = nil :: Steps.State?
	self.Runner = nil :: Model?
	self.RunnerAt = nil :: Vector3?
end

function OutsideController:Ctx(): any
	return self.Dependencies.AnomalyController:Context()
end

-- Runs a step list whose t = 0 was `startedAt` (server time), cancelled by the next Play / Stop.
function OutsideController:Play(list: { Step }, startedAt: number)
	self.Token += 1
	const token = self.Token
	const existing: Steps.State? = self.State
	const run: Steps.State = if existing ~= nil then existing else Steps.State(STATE_ID, KEY)
	self.State = run
	const ctx = self:Ctx()
	const elapsed = math.max(0, Workspace:GetServerTimeNow() - startedAt)
	for _, step in list do
		const wait = step.At - elapsed
		if wait < -LATE and not HELD[step.Kind] then
			continue
		end
		task.delay(math.max(wait, 0), function()
			if self.Token == token then
				Steps.Run(ctx, run, step, math.max(0, -wait))
			end
		end)
	end
end

function OutsideController:ClearLater()
	const token = self.Token
	task.delay(CLEAR_AFTER, function()
		const state = self.State
		if self.Token == token and state ~= nil and self.Stage == "" then
			Steps.Clear(self:Ctx(), state)
			self.State = nil
		end
	end)
end

function OutsideController:DropRunner()
	const model = self.Runner
	self.Runner = nil
	self.RunnerAt = nil
	if model ~= nil then
		task.spawn(function()
			for i = 1, 10 do
				Runner.Fade(model, i / 10)
				task.wait(0.05)
			end
			model:Destroy()
		end)
	end
end

function OutsideController:OnStage()
	const player = Players.LocalPlayer
	const raw = player:GetAttribute("OutsideStage")
	const stage = if type(raw) == "string" then raw else ""
	const at = player:GetAttribute("OutsideAt")
	const startedAt = if type(at) == "number" then at else Workspace:GetServerTimeNow()
	const before = self.Stage
	if stage == before then
		return
	end
	self.Stage = stage
	if stage == "Rise" then
		self:Play(SCENE.Rise, startedAt)
	elseif stage == "Chase" then
		self:Play(SCENE.Chase, startedAt)
		if self.Runner == nil then
			self.Runner = Runner.Build(self.Dependencies.AnomalyController:Folder(), "Outside_Runner", RUNNER_SCALE)
		end
	elseif stage == "Caught" then
		self:Play(SCENE.Caught, startedAt)
		pcall(Jumpscare.Show, self:Ctx())
		self:DropRunner()
	else
		-- cleared: escaped inside (or the night ended)
		if before == "Rise" or before == "Chase" then
			self:Play(SCENE.Escape, Workspace:GetServerTimeNow())
		end
		self:DropRunner()
		self:ClearLater()
	end
end

-- the drawn runner eases to the server position, facing the player, with a running bob
function OutsideController:StepRunner(dt: number)
	const model = self.Runner
	if model == nil then
		return
	end
	const goal = Players.LocalPlayer:GetAttribute("ChasePos")
	if typeof(goal) ~= "Vector3" then
		return
	end
	local at = self.RunnerAt or goal
	at = at:Lerp(goal, math.min(1, dt * FOLLOW))
	self.RunnerAt = at
	const character = Players.LocalPlayer.Character
	const root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local look = Vector3.new(0, 0, -1)
	if root ~= nil and root:IsA("BasePart") then
		const d = (root.Position - at) * Vector3.new(1, 0, 1)
		if d.Magnitude > 1e-3 then
			look = d.Unit
		end
	end
	const bob = math.abs(math.sin(os.clock() * 13)) * 0.4
	model:PivotTo(CFrame.lookAt(at, at + look) * CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-16), 0, 0))
end

OutsideController:OnStart(function(self)
	self:Setup()
	const player = Players.LocalPlayer
	player:GetAttributeChangedSignal("OutsideStage"):Connect(function()
		self:OnStage()
	end)
	self:OnStage()
	RunService.RenderStepped:Connect(function(dt: number)
		self:StepRunner(dt)
	end)
end)

return OutsideController
