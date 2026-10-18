--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Steps = require(StarterPlayer.StarterPlayerScripts.client.Anomaly.AnomalyController.Scene.Steps)

type Step = Content.HorrorStep

export type Public = {
	Runner: Model?,
	RunnerAt: Vector3?,
	Stage: string,
	State: Steps.State?,
	Token: number,
	Setup: (self: Public) -> (),
	Ctx: (self: Public) -> any,
	Play: (self: Public, list: { Step }, startedAt: number) -> (),
	ClearLater: (self: Public) -> (),
	DropRunner: (self: Public) -> (),
	OnStage: (self: Public) -> (),
	StepRunner: (self: Public, dt: number) -> (),
}

return {}
