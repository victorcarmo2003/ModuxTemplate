--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Context = require(StarterPlayer.StarterPlayerScripts.client.Hallucination.HallucinationController.Context)

export type Public = {
	Active: Context.Run?,
	ActiveKey: string,
	CooldownUntil: { [string]: number },
	Effects: { [string]: Context.Effect },
	Env: Context.Env?,
	Gui: ScreenGui?,
	Line: Vide.Source<string>,
	NextRollAt: number,
	Random: Random,
	Showing: Vide.Source<boolean>,
	Speaker: Vide.Source<string>,
	WhisperText: Vide.Source<string>,
	Setup: (self: Public) -> (),
	LoadEffects: (self: Public) -> (),
	FindVehicle: (self: Public) -> Instance?,
	BuildEnv: (self: Public) -> Context.Env,
	Eligible: (self: Public) -> boolean,
	Cancel: (self: Public) -> (),
	Schedule: (self: Public, now: number, seconds: number?) -> (),
	Candidates: (self: Public, now: number, env: Context.Env) -> { Content.Hallucination },
	Start: (self: Public, row: Content.Hallucination, env: Context.Env, now: number) -> (),
	Step: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
