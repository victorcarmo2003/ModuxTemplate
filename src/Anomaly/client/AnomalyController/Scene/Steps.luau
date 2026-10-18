--!strict
--[[
	Step dispatcher of the horror scene player (TASK-462): one handler per Content.HorrorScenes step Kind.
	A handler gets the controller context, the run's state and `late` (s since the step's time; > 0 for a late joiner
	applying a held kind, so a ramp or a cascade starts where the scene is).

	Here:
	  * Sound   AudioController:Play (Value = volume scale). Point = MapPoint for a 3D sound on a local carrier part;
	            To = MapPoint it moves to over Duration (a non-looped row is replayed along the way: steps passing by).
	            A MapPoint not streamed in / not built yet (TASK-465) plays it on screen, warned once.
	  * Music   Score.Scene (the director of TASK-443 owns the theme); "Stop" = silence. With the score off, a plain
	            AudioController:Loop.
	  * Lights  Scene/Lights (Off / On / Flicker / Cascade, same means as Kit/Blackout).
	  * Text    the HorrorCaption of TASK-444 ("THE POWER IS OUT. HIDE IN THE PANTRY!" -> title + line at the first
	            ". "), held Duration s.
	Stubs (logged once in Studio, replaced through Scene.Handle by the task that owns them):
	  Shake, Fov, Nudge = TASK-463 · Vignette, Whispers = TASK-464 · Door, Shadow = TASK-465 · Actor, Lightning = TASK-467.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Score = require(script.Parent.Parent.Score)
local Lights = require(script.Parent.Lights)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local HorrorCaption = require(Components.HorrorCaption)
local UiScale = require(Components.UiScale)

type Step = Content.HorrorStep

-- What a run keeps so its end can undo it
export type State = {
	Id: number, -- record id
	Key: string, -- scene / anomaly key
	Rng: Random, -- seeded with the record id: same choices on every client
	Carriers: { BasePart }, -- local parts of 3D sounds
	Music: boolean, -- this run set the scene music
	Lights: boolean, -- this run touched the lights
	Caption: boolean, -- this run showed the caption
}

-- AudioController PlayOptions (structural copy: a literal table did not unify with the optional fields)
type PlayOptions = { Volume: number?, Speed: number?, Vary: number?, Scare: boolean? }

export type Handler = (ctx: Effect.Context, state: State, step: Step, late: number) -> ()

const SOUNDS = Content.Sounds
const MUSIC_STOP = "Stop"
const STEP_GAP = 0.6 -- s between two plays of a moving non-looped sound when its length is unknown
const MIN_GAP = 0.3
const CARRIER_NAME = "HorrorScene_Sound"
const CARRIER_TAIL = 4 -- s a carrier lives after its travel (the last play rings out)
const TEXT_DURATION = 3

const Steps = {}

const warned: { [string]: boolean } = {}
local function warnOnce(tag: string, message: string)
	if warned[tag] then
		return
	end
	warned[tag] = true
	warn(`[Scene] {message}`)
end

local function noteOnce(tag: string, message: string)
	if warned[tag] or not RunService:IsStudio() then
		return
	end
	warned[tag] = true
	print(`[Scene] {message}`)
end

-- Sound ---------------------------------------------------------------------------------------------------------------

local function carrier(ctx: Effect.Context, state: State, at: Vector3): BasePart
	const part = Instance.new("Part")
	part.Name = CARRIER_NAME
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = at
	part.Parent = ctx.Folder()
	table.insert(state.Carriers, part)
	return part
end

local function point(ctx: Effect.Context, state: State, id: string): Vector3?
	const found = ctx.Point(id)
	if found == nil then
		warnOnce(`point:{id}`, `MapPoint {id} not found (scene {state.Key}): sound on screen`)
		return nil
	end
	return found.Position
end

const sound: Handler = function(ctx, state, step, _late)
	const key = step.Target
	if key == nil then
		return
	end
	const opts: PlayOptions = { Volume = step.Value or 1 }
	const from = if step.Point ~= nil then point(ctx, state, step.Point) else nil
	if from == nil then
		ctx.Audio:Play(key, nil, opts)
		return
	end
	const part = carrier(ctx, state, from)
	const duration = step.Duration or 0
	const to = if type(step.To) == "string" and duration > 0 then point(ctx, state, step.To) else nil
	local first = ctx.Audio:Play(key, part, opts)
	if to == nil then
		task.delay(math.max(duration, CARRIER_TAIL), part.Destroy, part)
		return
	end
	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = to }):Play()
	const row = SOUNDS.ByKey[key]
	if row ~= nil and not row.Looped then
		task.spawn(function()
			const started = os.clock()
			local last = first
			while part.Parent ~= nil do
				const length = if last ~= nil and last.TimeLength > 0 then last.TimeLength else STEP_GAP
				task.wait(math.max(length, MIN_GAP))
				if part.Parent == nil or os.clock() - started >= duration then
					break
				end
				last = ctx.Audio:Play(key, part, opts)
			end
		end)
	end
	task.delay(duration + CARRIER_TAIL, part.Destroy, part)
end

-- Music ---------------------------------------------------------------------------------------------------------------

local fallback: string? = nil -- key looped by hand while the score director is off

local function setMusic(ctx: Effect.Context, key: string?)
	if Score.Scene(key) then
		return
	end
	const playing = fallback
	if playing ~= nil then
		ctx.Audio:Loop(playing, nil, false)
		fallback = nil
	end
	if key ~= nil and key ~= MUSIC_STOP then
		ctx.Audio:Loop(key, nil, true)
		fallback = key
	end
end

const music: Handler = function(ctx, state, step, _late)
	const key = step.Target
	if key == nil then
		return
	end
	state.Music = true
	setMusic(ctx, key)
end

-- Lights --------------------------------------------------------------------------------------------------------------

const lights: Handler = function(_ctx, state, step, late)
	const target = step.Target
	const duration = step.Duration or 0
	state.Lights = true
	if target == "Off" then
		Lights.Off()
	elseif target == "On" then
		Lights.On()
	elseif target == "Flicker" then
		if late < duration then
			Lights.Flicker(duration - late)
		end
	elseif target == "Cascade" then
		Lights.Cascade(math.max(0, duration - late))
	end
end

-- Text ----------------------------------------------------------------------------------------------------------------

const captionShown = Vide.source(false)
const captionTitle = Vide.source("")
const captionLine = Vide.source("")
local captionToken = 0
local captionMounted = false

local function mountCaption()
	if captionMounted then
		return
	end
	captionMounted = true
	task.spawn(function()
		const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		const _, gui = Vide.root(function()
			return Vide.create("ScreenGui")({
				Name = "HorrorScene",
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = 3, -- as Score's HorrorScore: over the HUD, under full-screen fades and the jumpscare
				HorrorCaption({
					Shown = captionShown,
					Title = captionTitle,
					Line = captionLine,
					Scale = UiScale.Current,
					Name = "SceneCaption",
				}),
			})
		end)
		gui.Parent = playerGui
	end)
end

local function hideCaption()
	captionToken += 1
	captionShown(false)
end

const text: Handler = function(_ctx, state, step, late)
	const words = step.Text
	const hold = (step.Duration or TEXT_DURATION) - late
	if words == nil or words == "" or hold <= 0 then
		return
	end
	mountCaption()
	const cut = string.find(words, "%.%s")
	captionTitle(if cut ~= nil then string.sub(words, 1, cut - 1) else words)
	captionLine(if cut ~= nil then (string.gsub(string.sub(words, cut + 1), "^%s+", "")) else "")
	captionShown(true)
	state.Caption = true
	captionToken += 1
	const mine = captionToken
	task.delay(hold, function()
		if captionToken == mine then
			captionShown(false)
		end
	end)
end

-- Stubs ---------------------------------------------------------------------------------------------------------------

local function stub(owner: string): Handler
	return function(_ctx, state, step, _late)
		noteOnce(`stub:{step.Kind}`, `{step.Kind} steps are not played yet ({owner}); scene {state.Key}`)
	end
end

const handlers: { [string]: Handler } = {
	Sound = sound,
	Music = music,
	Lights = lights,
	Text = text,
	Shake = stub("TASK-463"),
	Fov = stub("TASK-463"),
	Nudge = stub("TASK-463"),
	Vignette = stub("TASK-464"),
	Whispers = stub("TASK-464"),
	Door = stub("TASK-465"),
	Shadow = stub("TASK-465"),
	Actor = stub("TASK-467"),
	Lightning = stub("TASK-467"),
}

-- API -----------------------------------------------------------------------------------------------------------------

function Steps.State(id: number, key: string): State
	return {
		Id = id,
		Key = key,
		Rng = Random.new(id),
		Carriers = {},
		Music = false,
		Lights = false,
		Caption = false,
	}
end

function Steps.Bind(ctx: Effect.Context)
	Lights.Bind(ctx)
end

function Steps.Handle(kind: Content.HorrorStepKind, handler: Handler)
	handlers[kind] = handler
end

function Steps.Run(ctx: Effect.Context, state: State, step: Step, late: number)
	const handler = handlers[step.Kind]
	if handler == nil then
		warnOnce(`kind:{step.Kind}`, `no handler for step Kind {step.Kind}`)
		return
	end
	const ok, problem = pcall(handler, ctx, state, step, late)
	if not ok then
		warnOnce(`fail:{state.Key}:{step.Kind}`, `{state.Key} {step.Kind} step at {step.Phase}+{step.At}: {problem}`)
	end
end

-- The run ended (record gone or its id reused): undo what it holds
function Steps.Clear(ctx: Effect.Context, state: State)
	for _, part in state.Carriers do
		part:Destroy()
	end
	table.clear(state.Carriers)
	if state.Music then
		state.Music = false
		setMusic(ctx, nil)
	end
	if state.Lights then
		state.Lights = false
		Lights.On()
	end
	if state.Caption then
		state.Caption = false
		hideCaption()
	end
end

return table.freeze(Steps)
