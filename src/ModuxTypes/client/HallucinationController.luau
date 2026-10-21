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
	TierIndex: number,
	WhisperText: Vide.Source<string>,
	Setup: (self: Public) -> (),
	LoadEffects: (self: Public) -> (),
	FindVehicle: (self: Public) -> Instance?,
	BuildEnv: (self: Public) -> Context.Env,
	Eligible: (self: Public) -> boolean,
	Cancel: (self: Public) -> (),
	Tier: (self: Public) -> number,
	Schedule: (self: Public, now: number, seconds: number?) -> (),
	Weight: (self: Public, row: Content.Hallucination) -> number,
	CanRun: (self: Public, row: Content.Hallucination, env: Context.Env) -> boolean,
	Candidates: (self: Public, now: number, env: Context.Env) -> { Content.Hallucination },
	ScareCandidates: (self: Public, now: number, env: Context.Env, keys: { string }, cooled: boolean) -> { Content.Hallucination },
	PlayScare: (self: Public, keys: { string }?) -> string?,
	Start: (self: Public, row: Content.Hallucination, env: Context.Env, now: number) -> (),
	Step: (self: Public) -> (),
	DevPlay: (self: Public, key: string) -> string,
	DevStop: (self: Public) -> string,
	DevActive: (self: Public) -> string,
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
