--!strict
-- ANM-021 The red fog, client look (owner 2026-10-18; server Anomalies/ANM-021; the directed layer - bell, bangs on the
-- glass, words, heart, bars, red grading - is Content.HorrorScenes anm_021_red_fog). Presentation only (T10).
--   * the Atmosphere turns thick and red over LightController's preset (ctx.Light.Applied), rising over FOG_IN while the
--     record is Signal / Active and going back over FOG_OUT after (the last write is exactly the preset again);
--   * the `amb_fog` loop while it is up;
--   * cue jumpscare: only the client whose UserId % 65536 = Entity shows the face (Kit/Jumpscare).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Jumpscare = require(script.Parent.Kit.Jumpscare)

const ENTITY_MOD = 65536
const FOG_IN = 10 -- s (about the omen)
const FOG_OUT = 4
const DENSITY = 0.62
const HAZE = 2.6
const COLOR = Color3.fromHex("#7A1418")
const DECAY = Color3.fromHex("#3A0608")

type State = { Alpha: number, Rising: boolean, Orphan: boolean, Done: boolean, Connection: RBXScriptConnection? }

local function write(ctx: Effect.Context, alpha: number)
	const light = ctx.Light
	const atmosphere = light.Atmosphere
	const preset = light.Applied
	if atmosphere == nil or preset == nil then
		return
	end
	atmosphere.Density = preset.AtmDensity + (math.max(DENSITY, preset.AtmDensity) - preset.AtmDensity) * alpha
	atmosphere.Haze = preset.AtmHaze + (math.max(HAZE, preset.AtmHaze) - preset.AtmHaze) * alpha
	atmosphere.Color = preset.AtmColor:Lerp(COLOR, alpha)
	atmosphere.Decay = preset.AtmDecay:Lerp(DECAY, alpha)
end

return {
	Ref = "ANM-021",

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const record = Vide.untrack(occ.Record)
		const state: State = {
			Alpha = if occ.Elapsed() >= FOG_IN then 1 else 0,
			Rising = record.Phase == "Signal" or record.Phase == "Active",
			Orphan = false,
			Done = false,
			Connection = nil,
		}
		local function finish()
			if state.Done then
				return
			end
			state.Done = true
			if state.Connection ~= nil then
				state.Connection:Disconnect()
				state.Connection = nil
			end
			write(ctx, 0)
			ctx.Audio:Loop("amb_fog", nil, false)
		end
		ctx.Audio:Loop("amb_fog", nil, true)
		state.Connection = RunService.RenderStepped:Connect(function(dt: number)
			if state.Rising and not state.Orphan then
				state.Alpha = math.min(1, state.Alpha + dt / FOG_IN)
			else
				state.Alpha = math.max(0, state.Alpha - dt / FOG_OUT)
				if state.Alpha <= 0 then
					finish()
					return
				end
			end
			write(ctx, state.Alpha)
		end)
		Vide.effect(function()
			const phase = occ.Record().Phase
			state.Rising = phase == "Signal" or phase == "Active"
			if not state.Rising then
				ctx.Audio:Loop("amb_fog", nil, false)
			end
		end)
		Vide.cleanup(function()
			state.Orphan = true
			ctx.Audio:Loop("amb_fog", nil, false)
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "jumpscare" and cue.Entity == Players.LocalPlayer.UserId % ENTITY_MOD then
			Jumpscare.Show(ctx)
		end
	end,
} :: Effect.Module
