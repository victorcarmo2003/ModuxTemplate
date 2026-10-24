--!strict
--[[
	Horror scene player (TASK-462; DEC-290; tech/horror-scene.md; Content.HorrorScenes). Client only, presents only:
	the anomaly's rule stays on the server (T10). Lives inside AnomalyController (like Score/): it already sees the
	`Anomalies` set and the `AnomalyCue` packet, and a new Modux controller costs type-checker budget.

	  - AnomalyController:Write / :Unmount / :OnCue feed Scene.Record / Scene.Remove / Scene.Cue. A record whose
	    Anomaly key has a scene (and the scene is Live, or `/dev scene` asked for it) gets a Run.
	  - Clock (no new packet): each step plays Step.At s after the record ENTERED Step.Phase. A phase seen changing
	    live is anchored at the server time it arrived (every client receives it at about the same moment); the first
	    phase seen is anchored at record.StartedAt (exact when the record starts in that phase; for a late joiner who
	    arrives after Signal it errs on the late side, so it skips one-shots rather than replaying them).
	  - Late steps (a late joiner, a phase entered before Start, a hitch): a one-shot more than Rules.Latency late is
	    dropped; the held kinds (Lights, Vignette, Lightning, Music, Whispers, Actor, HeadDown) apply their last past step
	    with `late` so the handler shows the state the scene is in.
	  - Who: "Caught" plays only after this client got the anomaly's caught cue (AnomalyCue "jumpscare" with
	    Entity = UserId % 65536); "Safe" = not caught (yet); nil/"All" = everyone. Checked when the step fires.
	  - A phase change drops the pending steps of the old phase; the record leaving (or its id reused) clears the run:
	    lights given back, the scene's music released, moving sounds and the caption gone.
	  - Live gate: Scene.Live = true plays it in the real game. Scenes still under Effects/ modules that do the same
	    job (ANM-020 blackout: Kit/Blackout, its cues, Score/) stay Live = nil until TASK-467 so nothing is doubled;
	    `/dev scene <key>` (Dev/Commands/Scene) sets ReplicatedStorage attribute DevHorrorScene = key, which plays it.
	  - Where (TASK-589, design/horror-cinematic.md §3.0): "Inside" / "Outside" plays only for a client inside / outside
	    the shop (LocalPlayer OutsideStage set = outside), checked when the step fires; nil = both.
	  - Seen (TASK-589): each kit piece shows its step only to the eyes it names (Scene/Seen: Cameras / Eyes / All).
	  - Carried (owner 2026-10-22, Provisional; Content.Tics header): while this client carries the tension of the record's
	    actor (Scene/Carry: it saw the apex of her tic in its close-up, Effects/Kit/Tic), the Queue steps whose kind is in
	    Content.Tics.Rules.Carry (and the on-screen sounds of Rules.CarrySounds) are skipped for it: the bars, words,
	    heart, edges and colour do not start over when her order is taken. Her body, props, lights and sounds in the
	    world still play; the other clients get the Queue as before.
	  - Steps.luau has one handler per Kind; TASK-463/464/465 plug theirs in with Scene.Handle(kind, handler); the pieces
	    of Scene/Kit register themselves through Kits.Register (TASK-586).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Effect)
local Steps = require(script.Steps)
local Carry = require(script.Carry)

export type Handler = Steps.Handler

type Step = Content.HorrorStep

type Run = {
	Id: number,
	Key: string,
	StartedAt: number,
	Actor: number, -- the record's Anchor (a customer anomaly's NpcId; Carry)
	Phase: string,
	Anchor: number, -- server time the record entered Phase
	Queue: { Step }, -- steps of Phase, by At
	Cursor: number,
	Primed: boolean, -- late steps of this phase already handled
	Caught: boolean,
	State: Steps.State,
}

const SCENES = Content.HorrorScenes
const RULES = SCENES.Rules
const DEV_ATTRIBUTE = "DevHorrorScene"
const ENTITY_MOD = 65536 -- AnomalyCue.Entity range (Kit/Hide.EntityOf on the server)
const CAUGHT_CUE = "jumpscare"
const OUTSIDE_ATTRIBUTE = "OutsideStage" -- OutsideService: set while the player is outside the shop
-- Actor (TASK-472): a late joiner gets the walking model where it should be (the handler skips `late` s of the walk)
-- HeadDown (TASK-484): a late joiner still gets the head-down help for the rest of the walk
-- Lantern, Silhouette (TASK-589): the light around him and the shape outside, where they should be
const HELD: { [string]: boolean } =
	{ Lights = true, Vignette = true, Lightning = true, Music = true, Whispers = true, Actor = true, HeadDown = true, Lantern = true, Silhouette = true }
-- the Queue steps a carrier skips (Content.Tics.Rules.Carry / CarrySounds; header, Carried)
const CARRY_KINDS: { [string]: boolean } = {}
for _, kind in Content.Tics.Rules.Carry do
	CARRY_KINDS[kind] = true
end
const CARRY_SOUNDS: { [string]: boolean } = {}
for _, key in Content.Tics.Rules.CarrySounds do
	CARRY_SOUNDS[key] = true
end

-- scene key -> phase -> steps by At (ties keep the data order)
const QUEUES: { [string]: { [string]: { Step } } } = {}
for _, scene in SCENES.List do
	const byPhase: { [string]: { Step } } = {}
	const order: { [Step]: number } = {}
	for index, step in scene.Steps do
		order[step] = index
		local list = byPhase[step.Phase]
		if list == nil then
			list = {}
			byPhase[step.Phase] = list
		end
		table.insert(list :: { Step }, step)
	end
	for _, list in byPhase do
		table.sort(list, function(a: Step, b: Step): boolean
			if a.At ~= b.At then
				return a.At < b.At
			end
			return order[a] < order[b]
		end)
	end
	QUEUES[scene.Key] = byPhase
end
const EMPTY: { Step } = table.freeze({} :: { Step })

const Scene = {}

local context: Effect.Context? = nil
local connection: RBXScriptConnection? = nil
const runs: { [number]: Run } = {}
const records: { [number]: Effect.Record } = {} -- every live record, scene or not (re-read when the dev mark changes)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function playable(scene: Content.HorrorScene): boolean
	return scene.Live == true or ReplicatedStorage:GetAttribute(DEV_ATTRIBUTE) == scene.Key
end

-- TASK-589 (design/horror-cinematic.md §3.0): outside the shop = the attribute OutsideService puts on the player
local function outside(): boolean
	return Players.LocalPlayer:GetAttribute(OUTSIDE_ATTRIBUTE) ~= nil
end

-- A Queue step this client skips because it carries the actor's tension already (header, Carried)
local function carried(run: Run, step: Step): boolean
	if step.Phase ~= "Queue" or not Carry.Has(run.Actor) then
		return false
	end
	if CARRY_KINDS[step.Kind] then
		return true
	end
	return step.Kind == "Sound" and step.Point == nil and CARRY_SOUNDS[step.Target or ""] == true
end

local function allowed(run: Run, step: Step): boolean
	const where = step.Where
	if where ~= nil and (where == "Outside") ~= outside() then
		return false
	end
	if carried(run, step) then
		return false
	end
	const who = step.Who or "All"
	if who == "Caught" then
		return run.Caught
	elseif who == "Safe" then
		return not run.Caught
	end
	return true
end

local function fire(run: Run, step: Step, late: number)
	const ctx = context
	if ctx == nil or not allowed(run, step) then
		return
	end
	Steps.Run(ctx, run.State, step, late)
end

local function enter(run: Run, phase: string, anchor: number)
	run.Phase = phase
	run.Anchor = anchor
	const byPhase = QUEUES[run.Key]
	run.Queue = if byPhase ~= nil then byPhase[phase] or EMPTY else EMPTY
	run.Cursor = 1
	run.Primed = false
end

-- Steps already past when the phase is first ticked: one-shots dropped, the last step of each held kind applied late
local function prime(run: Run, t: number)
	run.Primed = true
	const elapsed = t - run.Anchor
	const held: { Step } = {}
	const slot: { [string]: number } = {}
	while run.Cursor <= #run.Queue do
		const step = run.Queue[run.Cursor]
		if step.At + RULES.Latency >= elapsed then
			break
		end
		if HELD[step.Kind] and allowed(run, step) then
			const at = slot[step.Kind]
			if at ~= nil then
				held[at] = step
			else
				table.insert(held, step)
				slot[step.Kind] = #held
			end
		end
		run.Cursor += 1
	end
	for _, step in held do
		fire(run, step, elapsed - step.At)
	end
end

local function tick()
	const t = now()
	for _, run in runs do
		if not run.Primed then
			prime(run, t)
		end
		const elapsed = t - run.Anchor
		while run.Cursor <= #run.Queue do
			const step = run.Queue[run.Cursor]
			if step.At > elapsed then
				break
			end
			run.Cursor += 1
			const late = elapsed - step.At
			if late <= RULES.Latency or HELD[step.Kind] then
				fire(run, step, late)
			end
		end
	end
end

local function finish(run: Run)
	if runs[run.Id] == run then
		runs[run.Id] = nil
	end
	const ctx = context
	if ctx ~= nil then
		Steps.Clear(ctx, run.State)
	end
end

-- AnomalyController:Write: a record arrived or changed
function Scene.Record(id: number, record: Effect.Record)
	records[id] = record
	const run = runs[id]
	if run ~= nil and run.Key == record.Anomaly and run.StartedAt == record.StartedAt then
		run.Actor = record.Anchor
		if run.Phase ~= record.Phase then
			enter(run, record.Phase, now())
		end
		return
	end
	if run ~= nil then
		finish(run)
	end
	const scene = SCENES.ByKey[record.Anomaly]
	if scene == nil or not playable(scene) then
		return
	end
	const created: Run = {
		Id = id,
		Key = scene.Key,
		StartedAt = record.StartedAt,
		Actor = record.Anchor,
		Phase = record.Phase,
		Anchor = record.StartedAt,
		Queue = EMPTY,
		Cursor = 1,
		Primed = false,
		Caught = false,
		State = Steps.State(id, scene.Key),
	}
	enter(created, record.Phase, record.StartedAt)
	runs[id] = created
end

-- AnomalyController:Unmount: the record left the set
function Scene.Remove(id: number)
	records[id] = nil
	const run = runs[id]
	if run ~= nil then
		finish(run)
	end
end

-- AnomalyController:OnCue: the caught cue marks this client "Caught" for the live runs of that anomaly
-- user: the full UserId the cue is for (AnomalyCue.User); when present it decides alone (family A: Entity is the actor)
function Scene.Cue(anomaly: string, cue: string, entity: number, user: number?)
	if cue ~= CAUGHT_CUE then
		return
	end
	if user ~= nil then
		if user ~= Players.LocalPlayer.UserId then
			return
		end
	elseif entity == 0 or entity ~= Players.LocalPlayer.UserId % ENTITY_MOD then
		return
	end
	for _, run in runs do
		if run.Key == anomaly then
			run.Caught = true
		end
	end
end

-- Replaces the handler of a step Kind (TASK-463 camera, TASK-464 vignette / Whispers, TASK-465 door / shadow)
function Scene.Handle(kind: Content.HorrorStepKind, handler: Handler)
	Steps.Handle(kind, handler)
end

-- AnomalyController:OnStart. Runs created before it start here (their late steps are handled on the first tick).
function Scene.Start(ctx: Effect.Context)
	if connection ~= nil then
		return
	end
	context = ctx
	Steps.Bind(ctx)
	connection = RunService.Heartbeat:Connect(tick)
	-- `/dev scene` may mark a scene after its record arrived: give those records their run now
	ReplicatedStorage:GetAttributeChangedSignal(DEV_ATTRIBUTE):Connect(function()
		for id, record in records do
			Scene.Record(id, record)
		end
	end)
end

return table.freeze(Scene)
