--!strict
--[[
	Anomaly tic in the order talk, client side (design/anomaly-tics-proposal.md; Content.Tics). Pilot ANM-012 the turned
	neck (Provisional Q-459 a); owner 2026-10-22 ("implementa os próximos tiques", Provisional): ANM-013 the white eyes,
	ANM-004 the copy's echo, ANM-014 the big head. Presentation only (T10): TabletService decides when a tic plays and
	writes the rig attributes; every client reads them on the server clock, so all see the same body without a packet.

	Clock: the rig's TicAt (server time of LineStart) and Content.Tics.Timing of the talk's line (the echo's line from
	TicEcho + the taker's DisplayName, Tics.Said). Each beat plays Beats.Sound at the head for everyone within
	Rules.HearRange studs. Body (every client; Mount picks it by row.Body):
	  Neck  (ANM-012, the rig's Neck Motor6D C0; replaces the plain "neck" modifier while the row exists)
	        - before any tic: the head faces forward; every Pre.Every s it jerks Pre.Value degrees aside and back in
	          Pre.Time s, with a soft crack within Pre.Range studs. Through a security camera the head is already
	          turned round and sways (Q-459 a)
	        - the tic: the head turns Turn degrees at each beat; after the last one it stays turned (the residue) and sways
	        - TicFollow (left after the peak): while that player stands in front of her, the nape follows them
	        - NeckSnap (local, cue neck_snap on a refusal / the window shut in her face before any tic): the old snap
	  Eyes  (ANM-013) the face through RigController's local TicFace ("" = the ordinary face, nil = the variant's white
	        eyes)
	        - before any tic: normal eyes and a small cold Glint light on the face that ignores the room; through a security
	          camera the eyes are already white
	        - the tic: from the freeze the face shell is gone for Hold s (the blink), then the eyes open white (the peak)
	          and a cold SpotLight from them (Light.Range, Light.Angle) flares at Light.Brightness over the beat and
	          settles at Light.Residue: it lights whoever stands in front, the taker's face first. White and lit after
	  Head  (ANM-014; replaces the plain "bighead" modifier while the row exists) the head and what is welded to it scale
	        around the neck, like the old modifier
	        - before any tic: x1 (Q-461: the head arrives normal); through a security camera x Cameras
	        - the tic: Scales[i] at beat i, eased over Beats.Time; TicEnd (the taker left between the steps) stops it
	          where it was. The local TicScale on the rig = the scale shown (TabletController's close-up follows it)
	  Echo  (ANM-004) the line is the tic (TabletController); the body only tilts the head Tilt degrees while it says the
	        taker's own hi (peak .. end of the line), and back. Nothing stays
	  Face  (ANM-001, owner 2026-10-22: it must arrive with a face) through RigController's local TicFace ("" = its own
	        face and mood, row.Face = the blank face; RigController keeps the ordinary face on this variant until TicFace
	        names one, so it never arrives faceless before this body mounts)
	        - before any tic: its own face; through a security camera already blank
	        - the tic: from the freeze the face shell fades out (LocalTransparencyModifier, eased in) over the build-up
	          while the line drops its letters (OrderTalk style Blank); at the peak it is gone (row.Face) for everyone and
	          stays so (the residue, the queue). Only the face shell goes: the head keeps its skin, markings and nose
	Delivery queue (owner 2026-10-22, Provisional; anomalies-after-accept-proposal.md §9): while the rig carries AnomalyQueue
(server time its order was taken, Anomaly Kit/CustomerActor) the body shows its sign explicitly, for everyone, from the
row's Queue: Neck = turned round (even when no tic played), the neck broken (Roll, Pitch) with a jerk now and then;
Head = swollen to Queue.Scale and + Queue.PerStep at each Hurry step (rig AnomalyStep, a creak each), back down to the
residue once served right (the attribute cleared); Eyes = white, the light at Queue.Light; Face = no face.
Screen layer = the taker's tension (owner 2026-10-22: "antes da animação acontecer começa a aparecer as barras, aí quebra o
	pescoço, e na hora que quebra - bum - começa os sussurros... junto com o heartbeat"; Provisional; Content.Tics header):
	Content.Tics.Layers[key] (the build-up on "...", the "paradinha", the apex with the hint's whispers and title, the punch,
	the heart; then the bars leaving, the whispers and the heart going on) at Peak + At through the scene player's step
	handlers. Only for the taker (TicUser = me):
	  - before the apex it plays only while my talk close-up is on (LocalPlayer TalkCloseUp): leaving before the apex
	    clears it (the tic is cancelled, nothing of the tension starts)
	  - from the apex it is CARRIED (Scene/Carry): it outlives the close-up and the talk (the order taken, or I left) and
	    ends when her record (Anchor = her NpcId) is Resolved / Failed / gone, or Tension.Max after the apex. Meanwhile her
	    scene's Queue screen steps and the queue caption skip this client (the tension does not start over)
	  - held kinds (bars, words, heart, edges, colour, silence, title) still apply when a frame comes late; a tic already
	    past its apex when the layer would start (a stale TicAt) never replays
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Parent.Effect)
local Steps = require(script.Parent.Parent.Parent.Scene.Steps)
local Carry = require(script.Parent.Parent.Parent.Scene.Carry)

type Undo = () -> ()

-- What every body reads each frame
type Frame = {
	Clock: number, -- os.clock()
	Dt: number,
	Server: number,
	TicAt: number?, -- server time of LineStart of the tic (nil = no tic yet / cancelled)
	Elapsed: number, -- s since TicAt (0 without one)
	Timing: Content.TicTiming?, -- the clock of the tic (nil without one)
	Viewing: boolean, -- this client looks through a security camera
	-- owner 2026-10-22: the actor waits in the delivery queue (rig AnomalyQueue, server time it entered; nil = not) and its
	-- Hurry step (rig AnomalyStep); the body shows the sign explicitly (Content.Tics row Queue)
	QueueAt: number?,
	QueueStep: number,
}

type Body = { Step: (frame: Frame) -> (), Undo: Undo }

const TIC_AT = "TicAt"
const TIC_USER = "TicUser"
const TIC_FOLLOW = "TicFollow"
const TIC_END = "TicEnd"
const TIC_ECHO = "TicEcho"
const TIC_FACE = "TicFace" -- local only, read by RigController ("" = hold the variant's face back, nil = its face)
const TIC_SCALE = "TicScale" -- local only, read by TabletController (the close-up follows the head)
const SNAP_ATTRIBUTE = "NeckSnap" -- local only (OddCustomer snapNeck): os.clock() of the snap
const CLOSE_UP_ATTRIBUTE = "TalkCloseUp" -- TabletController: on LocalPlayer while my talk close-up is on
const VIEW_ATTRIBUTE = Content.Security.Rules.ViewAttribute
const NECK_SWAY = math.rad(8)
const NECK_SWAY_SPEED = 0.7
const SNAP_TIME = 0.12
const SNAP_EXTRA = math.pi * 0.85
const SNAP_ROLL = math.rad(28)
const BEAT_LATE = 0.5 -- s a beat sound may play late (a hitch) before it is skipped
const STEP_LATE = 0.3 -- s a one-shot screen step may start late
-- the kinds of the taker's layer that hold a state (they apply late, with `late`: the handlers start where the scene is)
const HELD: { [string]: boolean } =
	{ Cinema = true, Whispers = true, Heartbeat = true, Vignette = true, Grade = true, Silence = true, Text = true }
const CARRY_CHECK = 0.25 -- s between two reads of her record while the tension is carried
const ENDED: { [string]: boolean } = { Resolved = true, Failed = true }
const FOLLOW_RANGE = 20 -- studs: farther, the turned head stops following
const FOLLOW_MAX = math.rad(80) -- the follower must stand within this angle of her front
const FOLLOW_TURN = 4 -- 1/s
const EYES_COLOR = Color3.fromRGB(205, 225, 255) -- cold white
const EYES_FRONT = 0.55 -- x the head depth: where the lights sit in front of the face
const EYES_LIFT = 0.12 -- x the head height: the eye line over the head's centre
const TILT_EASE = 0.4 -- s the echo's head tilt takes in and out
const SCALE_EPSILON = 1e-3
-- owner 2026-10-22 (Provisional): the delivery queue (Anomaly Kit/CustomerActor writes both on the rig)
const QUEUE_ATTRIBUTE = "AnomalyQueue"
const STEP_ATTRIBUTE = "AnomalyStep"
const BREAK_TIME = 0.35 -- s the neck takes to break when she enters the queue
const QUEUE_TWITCH = { 1.4, 3.2 } -- s between two jerks of the broken neck
const QUEUE_TWITCH_ANGLE = math.rad(7)
const QUEUE_TWITCH_TIME = 0.1
const SWELL_RATE = 5 -- 1/s: how fast the head follows its queue scale (swelling and, served, going back)

const Tic = {}

local function yaw(c0: CFrame, angle: number): CFrame
	return CFrame.fromAxisAngle(c0:VectorToObjectSpace(Vector3.yAxis), angle)
end

local function easeOut(t: number): number
	const c = math.clamp(t, 0, 1)
	return 1 - (1 - c) * (1 - c)
end

-- Within `range` studs of this client's camera
local function heard(at: Vector3, range: number): boolean
	const camera = Workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - at).Magnitude <= range
end

local function headOf(userId: number): BasePart?
	const player = Players:GetPlayerByUserId(userId)
	const character = if player ~= nil then player.Character else nil
	const head = if character ~= nil then character:FindFirstChild("Head") else nil
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

local function partOf(model: Model, name: string): BasePart?
	const part = model:FindFirstChild(name)
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

local function neckOf(model: Model): Motor6D?
	const torso = model:FindFirstChild("Torso")
	const found = if torso ~= nil then torso:FindFirstChild("Neck") else nil
	return if found ~= nil and found:IsA("Motor6D") then found else nil
end

local function play(ctx: Effect.Context, model: Model, key: string, volume: number, range: number)
	const at = partOf(model, "Head")
	const position = if at ~= nil then at.Position else model:GetPivot().Position
	if heard(position, range) then
		ctx.Audio:Play(key, at or position, { Volume = volume })
	end
end

-- Bodies ----------------------------------------------------------------------------------------------------------------

-- ANM-012: the neck turns at each beat and stays round (the pilot)
local function neckBody(model: Model, row: Content.Tic, ctx: Effect.Context): Body?
	const torso = partOf(model, "Torso")
	const motor = neckOf(model)
	if torso == nil or motor == nil then
		return nil
	end
	const base = motor.C0
	const turn = math.rad(row.Turn or 0)
	const pre = row.Pre
	const beats = row.Beats
	const rng = Random.new()
	const started = os.clock()
	local current = 0
	local follow = 0
	local snapFrom: number? = nil
	local twitchAt = -math.huge
	local nextTwitch = if pre ~= nil then started + rng:NextNumber(pre.Every[1], pre.Every[2]) else math.huge
	local breakAt = -math.huge
	local nextBreak = 0

	local function step(frame: Frame)
		local angle = 0
		local roll = 0
		local hang = 0
		const timing = frame.Timing
		const snappedAt = model:GetAttribute(SNAP_ATTRIBUTE)
		if type(snappedAt) == "number" then
			-- TASK-336: the snap round (a refusal / the window in her face before any tic), then held
			const from = snapFrom or current
			snapFrom = from
			const e = easeOut((frame.Clock - snappedAt) / SNAP_TIME)
			angle = from + (math.pi + SNAP_EXTRA - from) * e
			roll = SNAP_ROLL * e
		elseif timing ~= nil then
			const elapsed = frame.Elapsed
			const time = if beats ~= nil then beats.Time else 0.1
			for _, at in timing.Beats do
				if elapsed < at then
					break
				end
				angle += turn * easeOut((elapsed - at) / time)
			end
			if elapsed >= timing.BeatsEnd then
				-- the residue: turned round for everyone, a slow sway; the nape follows who left while in front of her
				angle += math.sin((frame.Clock - started) * NECK_SWAY_SPEED) * NECK_SWAY
				const followValue = model:GetAttribute(TIC_FOLLOW)
				const target = if type(followValue) == "number" then headOf(followValue) else nil
				local goal = 0
				if target ~= nil then
					const dir = torso.CFrame:PointToObjectSpace(target.Position)
					const side = math.atan2(-dir.X, -dir.Z)
					if dir.Magnitude <= FOLLOW_RANGE and math.abs(side) <= FOLLOW_MAX then
						goal = side
					end
				end
				follow += (goal - follow) * math.min(1, frame.Dt * FOLLOW_TURN)
				angle += follow
			end
		elseif frame.Viewing then
			-- Q-459 a: the security feed already shows her head turned round
			angle = math.pi + math.sin((frame.Clock - started) * NECK_SWAY_SPEED) * NECK_SWAY
		elseif pre ~= nil then
			if frame.Clock >= nextTwitch then
				twitchAt = frame.Clock
				nextTwitch = frame.Clock + rng:NextNumber(pre.Every[1], pre.Every[2])
				if beats ~= nil then
					play(ctx, model, beats.Sound, pre.Volume, pre.Range)
				end
			end
			const t = (frame.Clock - twitchAt) / pre.Time
			if t < 1 then
				angle = math.rad(pre.Value) * math.sin(t * math.pi)
			end
		end
		-- owner 2026-10-22: in the delivery queue the neck is broken for everyone (row Queue): the head turned round (even
		-- when no tic played), lying on a shoulder, hanging, and it jerks now and then
		const queueAt = frame.QueueAt
		const queue = row.Queue
		if queueAt ~= nil and queue ~= nil then
			if timing == nil and type(snappedAt) ~= "number" then
				angle = math.pi + math.sin((frame.Clock - started) * NECK_SWAY_SPEED) * NECK_SWAY
			end
			const into = easeOut((frame.Server - queueAt) / BREAK_TIME)
			roll += math.rad(queue.Roll or 0) * into
			hang = math.rad(queue.Pitch or 0) * into
			if frame.Clock >= nextBreak then
				breakAt = frame.Clock
				nextBreak = frame.Clock + rng:NextNumber(QUEUE_TWITCH[1], QUEUE_TWITCH[2])
			end
			const jerk = (frame.Clock - breakAt) / QUEUE_TWITCH_TIME
			if jerk < 1 then
				roll += QUEUE_TWITCH_ANGLE * math.sin(jerk * math.pi)
			end
		end
		current = angle
		motor.C0 = base * yaw(base, angle) * CFrame.Angles(hang, 0, roll)
	end

	return {
		Step = step,
		Undo = function()
			if motor.Parent ~= nil then
				motor.C0 = base
			end
		end,
	}
end

-- ANM-013: normal eyes with a glint; a blink, then white eyes that light the taker's face
local function eyesBody(model: Model, row: Content.Tic): Body?
	const head = partOf(model, "Head")
	const light = row.Light
	if head == nil or light == nil then
		return nil
	end
	const glintRow = row.Glint
	const attachment = Instance.new("Attachment")
	attachment.Name = "TicEyes"
	attachment.Position = Vector3.new(0, head.Size.Y * EYES_LIFT, -head.Size.Z * EYES_FRONT)
	const glint = Instance.new("PointLight")
	glint.Name = "TicGlint"
	glint.Color = EYES_COLOR
	glint.Shadows = false
	glint.Brightness = if glintRow ~= nil then glintRow.Brightness else 0
	glint.Range = if glintRow ~= nil then glintRow.Range else 0
	glint.Enabled = false
	glint.Parent = attachment
	const beam = Instance.new("SpotLight")
	beam.Name = "TicEyesLight"
	beam.Color = EYES_COLOR
	beam.Face = Enum.NormalId.Front
	beam.Angle = light.Angle
	beam.Range = light.Range
	beam.Shadows = false
	beam.Brightness = 0
	beam.Enabled = false
	beam.Parent = attachment
	attachment.Parent = head
	const beatTime = if row.Beats ~= nil then math.max(row.Beats.Time, 0.05) else 0.6
	local blinkFace: BasePart? = nil
	local blinkWas = 0
	local shown: string? = "?" -- TicFace written last ("?" = not yet)

	local function face(value: string?)
		if value ~= shown then
			shown = value
			model:SetAttribute(TIC_FACE, value)
		end
	end

	local function blink(on: boolean)
		if on and blinkFace == nil then
			const shell = partOf(model, "Face")
			if shell ~= nil then
				blinkFace = shell
				blinkWas = shell.LocalTransparencyModifier
				shell.LocalTransparencyModifier = 1
			end
		elseif not on and blinkFace ~= nil then
			const shell = blinkFace :: BasePart
			blinkFace = nil
			if shell.Parent ~= nil then
				shell.LocalTransparencyModifier = blinkWas
			end
		end
	end

	-- owner 2026-10-22: the light of the white eyes while she waits in the delivery queue (row Queue.Light)
	const queueLight = if row.Queue ~= nil and row.Queue.Light ~= nil then row.Queue.Light else light.Residue

	local function step(frame: Frame)
		const timing = frame.Timing
		if frame.QueueAt ~= nil then
			-- in the delivery queue: white for everyone (even when no tic played), the light burning
			blink(false)
			face(nil)
			glint.Enabled = false
			beam.Brightness = queueLight
			beam.Enabled = true
		elseif timing ~= nil and frame.Elapsed >= timing.Peak then
			-- open: white for everyone, the light flares over the beat and settles
			blink(false)
			face(nil)
			glint.Enabled = false
			const t = math.clamp((frame.Elapsed - timing.Peak) / beatTime, 0, 1)
			beam.Brightness = light.Residue + (light.Brightness - light.Residue) * (1 - t * t)
			beam.Enabled = true
		elseif timing ~= nil and frame.Elapsed >= timing.Freeze then
			-- the blink: the face shell goes (the eyelid down), the glint with it
			blink(true)
			face("")
			glint.Enabled = false
			beam.Enabled = false
		elseif frame.Viewing then
			-- the cameras already see them white
			blink(false)
			face(nil)
			glint.Enabled = false
			beam.Enabled = false
		else
			blink(false)
			face("")
			glint.Enabled = glintRow ~= nil
			beam.Enabled = false
		end
	end

	return {
		Step = step,
		Undo = function()
			blink(false)
			attachment:Destroy()
			if model.Parent ~= nil then
				model:SetAttribute(TIC_FACE, nil)
			end
		end,
	}
end

-- ANM-014: the head grows in steps around the neck (the old bighead modifier's scaling, by steps)
local function headBody(model: Model, row: Content.Tic, ctx: Effect.Context): Body?
	const head = partOf(model, "Head")
	const motor = neckOf(model)
	if head == nil or motor == nil then
		return nil
	end
	type Saved = { Part: BasePart, Size: Vector3, Offset: CFrame, Weld: WeldConstraint }
	const saved: { Saved } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") and descendant.Part0 == head and descendant.Part1 ~= nil then
			const part = descendant.Part1 :: BasePart
			table.insert(saved, {
				Part = part,
				Size = part.Size,
				Offset = head.CFrame:ToObjectSpace(part.CFrame),
				Weld = descendant,
			})
		end
	end
	const headSize = head.Size
	const c1 = motor.C1
	const scales: { number } = row.Scales or {}
	const beatTime = if row.Beats ~= nil then math.max(row.Beats.Time, 0.01) else 0.25
	local shown = 1
	local swell: number? = nil -- the scale shown while in (or coming back from) the delivery queue
	local heardStep = 0 -- the last Hurry step whose creak played

	local function apply(scale: number)
		for _, entry in saved do
			entry.Weld.Enabled = false
		end
		head.Size = headSize * scale
		motor.C1 = c1 - c1.Position + c1.Position * scale
		for _, entry in saved do
			const offset = entry.Offset
			entry.Part.Size = entry.Size * scale
			entry.Part.CFrame = head.CFrame * (offset - offset.Position + offset.Position * scale)
			entry.Weld.Enabled = true
		end
	end

	local function step(frame: Frame)
		local scale = 1
		const timing = frame.Timing
		if timing ~= nil then
			-- left between the steps (TicEnd): the step reached stays
			local elapsed = frame.Elapsed
			const stop = model:GetAttribute(TIC_END)
			const ticAt = frame.TicAt
			if type(stop) == "number" and ticAt ~= nil then
				elapsed = math.min(elapsed, stop - ticAt)
			end
			for index, at in timing.Beats do
				if elapsed < at then
					break
				end
				const goal: number = scales[index] or scale
				scale += (goal - scale) * easeOut((elapsed - at) / beatTime)
			end
		elseif frame.Viewing then
			scale = row.Cameras or 1 -- Q-461: the cameras keep the sign
		end
		-- owner 2026-10-22: in the delivery queue the head swells (row Queue.Scale) and a step more at each Hurry step, with
		-- a creak; served right (the attribute gone) it goes back down to the residue
		const queue = row.Queue
		if queue ~= nil and (frame.QueueAt ~= nil or swell ~= nil) then
			local target = scale
			if frame.QueueAt ~= nil then
				target = math.max(scale, (queue.Scale or scale) + (queue.PerStep or 0) * frame.QueueStep)
				if frame.QueueStep > heardStep then
					heardStep = frame.QueueStep
					const beats = row.Beats
					if beats ~= nil then
						play(ctx, model, beats.Sound, beats.Volume, Content.Tics.Rules.HearRange)
					end
				end
			else
				heardStep = 0
			end
			local value = swell or shown
			value += (target - value) * math.min(1, frame.Dt * SWELL_RATE)
			if frame.QueueAt == nil and math.abs(value - target) <= SCALE_EPSILON then
				swell = nil
				value = target
			else
				swell = value
			end
			scale = value
		end
		if math.abs(scale - shown) > SCALE_EPSILON then
			shown = scale
			apply(scale)
			model:SetAttribute(TIC_SCALE, if scale > 1 + SCALE_EPSILON then scale else nil)
		end
	end

	return {
		Step = step,
		Undo = function()
			if head.Parent ~= nil and shown ~= 1 then
				apply(1)
			end
			if model.Parent ~= nil then
				model:SetAttribute(TIC_SCALE, nil)
			end
		end,
	}
end

-- ANM-001: its own face until the talk; it fades out over the build-up and is gone at the peak (the residue)
local function faceBody(model: Model, row: Content.Tic): Body?
	const blank: string = row.Face or ""
	if blank == "" then
		return nil
	end
	local shown: string? = "?" -- TicFace written last ("?" = not yet)
	local fadedPart: BasePart? = nil -- the face shell whose LocalTransparencyModifier this body wrote
	local faded = 0

	local function face(value: string)
		if value ~= shown then
			shown = value
			model:SetAttribute(TIC_FACE, value)
		end
	end

	-- 0 = the face shell as dressed, 1 = gone. Kept at 1 while the blank face is dressed (it is see-through anyway), so
	-- the old face never flashes back between this write and RigController's deferred re-dress
	local function fade(alpha: number)
		const shell = partOf(model, "Face")
		if shell == nil then
			return
		end
		if shell ~= fadedPart then
			fadedPart = shell
			faded = -1
		end
		if math.abs(alpha - faded) > 0.01 then
			faded = alpha
			shell.LocalTransparencyModifier = alpha
		end
	end

	local function step(frame: Frame)
		const timing = frame.Timing
		if frame.QueueAt ~= nil or (timing ~= nil and frame.Elapsed >= timing.Peak) then
			-- gone for everyone: in the delivery queue (even when no tic played) and after the peak (the residue)
			face(blank)
			fade(1)
		elseif timing ~= nil and frame.Elapsed >= timing.Freeze then
			-- the build-up: its own face fading out, slow then faster, gone at the peak
			face("")
			const t = math.clamp((frame.Elapsed - timing.Freeze) / math.max(timing.Peak - timing.Freeze, 0.05), 0, 1)
			fade(t * t)
		elseif frame.Viewing then
			-- the cameras already see it blank
			face(blank)
			fade(1)
		else
			face("")
			fade(0)
		end
	end

	return {
		Step = step,
		Undo = function()
			const shell = fadedPart
			if shell ~= nil and shell.Parent ~= nil then
				shell.LocalTransparencyModifier = 0
			end
			if model.Parent ~= nil then
				model:SetAttribute(TIC_FACE, nil)
			end
		end,
	}
end

-- ANM-004: the head tilts while the copy says the taker's own hi, then back
local function echoBody(model: Model, row: Content.Tic): Body?
	const motor = neckOf(model)
	if motor == nil then
		return nil
	end
	const base = motor.C0
	const tilt = math.rad(row.Tilt or 0)
	local written = 0

	local function step(frame: Frame)
		local roll = 0
		const timing = frame.Timing
		if timing ~= nil and frame.Elapsed >= timing.Peak then
			const into = easeOut((frame.Elapsed - timing.Peak) / TILT_EASE)
			const out = easeOut((frame.Elapsed - timing.End) / TILT_EASE)
			roll = tilt * into * (1 - out)
		end
		if math.abs(roll - written) > 1e-4 then
			written = roll
			motor.C0 = base * CFrame.Angles(0, 0, roll)
		end
	end

	return {
		Step = step,
		Undo = function()
			if motor.Parent ~= nil and written ~= 0 then
				motor.C0 = base
			end
		end,
	}
end

-- Mount ------------------------------------------------------------------------------------------------------------------

-- The tic body and the taker's screen layer of an actor whose Variant has a Content.Tics row (OddCustomer, ANM-004)
function Tic.Mount(ctx: Effect.Context, model: Model, row: Content.Tic): Undo
	local body: Body? = nil
	if row.Body == "Neck" then
		body = neckBody(model, row, ctx)
	elseif row.Body == "Eyes" then
		body = eyesBody(model, row)
	elseif row.Body == "Head" then
		body = headBody(model, row, ctx)
	elseif row.Body == "Echo" then
		body = echoBody(model, row)
	elseif row.Body == "Face" then
		body = faceBody(model, row)
	end
	const rules = Content.Tics.Rules
	const beats = row.Beats
	-- the taker's tension, At = s from the apex, already sorted (Content.Tics)
	const steps: { Content.HorrorStep } = Content.Tics.Layers[row.Key] or row.Steps
	const tension = Content.Tics.TensionOf(row)

	-- the clock of the tic that started at `timedAt` (the echo's line depends on the original and the taker)
	local timedAt: number? = nil
	local timing: Content.TicTiming? = nil
	local beaten = 0 -- beats whose sound played for timedAt
	-- the taker's screen layer: TicAt it plays for, the server time of its apex, its step state and how many steps fired
	local layerAt: number? = nil
	local apexAt = 0
	local layerState: Steps.State? = nil
	local fired = 0
	-- past the apex: the NpcId whose tension I carry (Scene/Carry) until her order is done; the TicAt it was for (never
	-- replayed); the next read of her record
	local carried: number? = nil
	local playedAt: number? = nil
	local checkAt = 0

	local function clearLayer()
		const state = layerState
		layerState = nil
		layerAt = nil
		fired = 0
		const npc = carried
		if npc ~= nil then
			carried = nil
			Carry.Set(npc, nil)
			-- the punches are long over: a camera clear now would cut her scene's own (the Failed jolt, the jumpscare)
			if state ~= nil then
				state.Undo.camera = nil
			end
		end
		if state ~= nil then
			Steps.Clear(ctx, state)
		end
	end

	-- the phase of her record (Anchor = her NpcId), nil = no record of her
	local function phaseOf(npc: number): string?
		for _, occ in ctx.Occurrences(row.Key) do
			const record = occ.Record()
			if record.Anchor == npc then
				return record.Phase
			end
		end
		return nil
	end

	-- the steps due by `server`; the held kinds of a late frame apply once each (the last one of each kind), late
	local function runDue(server: number)
		const state = layerState
		if state == nil then
			return
		end
		local held: { [string]: Content.HorrorStep }? = nil
		local order: { string } = {}
		while fired < #steps do
			const step = steps[fired + 1]
			const late = server - (apexAt + step.At)
			if late < 0 then
				break
			end
			fired += 1
			if HELD[step.Kind] then
				local pending = held
				if pending == nil then
					pending = {}
					held = pending
				end
				const due = pending :: { [string]: Content.HorrorStep }
				if due[step.Kind] == nil then
					table.insert(order, step.Kind)
				end
				due[step.Kind] = step
			elseif late <= STEP_LATE then
				Steps.Run(ctx, state, step, late)
			end
		end
		const due = held
		if due == nil then
			return
		end
		for _, kind in order do
			const step = due[kind]
			Steps.Run(ctx, state, step, math.max(server - (apexAt + step.At), 0))
		end
	end

	local function timingOf(ticAt: number?): Content.TicTiming?
		if ticAt ~= timedAt then
			timedAt = ticAt
			beaten = 0
			if ticAt == nil then
				timing = nil
			else
				const echo = model:GetAttribute(TIC_ECHO)
				const user = model:GetAttribute(TIC_USER)
				const taker = if type(user) == "number" then Players:GetPlayerByUserId(user) else nil
				const said = Content.Tics.Said(
					row,
					if type(echo) == "number" then echo else nil,
					if taker ~= nil then taker.DisplayName else ""
				)
				timing = Content.Tics.Timing(row, said)
			end
		end
		return timing
	end

	-- the taker's tension of the tic that started at `ticAt` (the header: the build-up in my close-up, carried past the apex)
	local function screen(ticAt: number?, server: number, clock: Content.TicTiming?)
		const npc = carried
		if npc ~= nil then
			-- carried: it goes on with me (whatever the rig's tic attributes do) until her order is done
			if server >= checkAt then
				checkAt = server + CARRY_CHECK
				const phase = phaseOf(npc)
				if phase == nil or ENDED[phase] or server - apexAt > tension.Max then
					clearLayer()
					return
				end
			end
			runDue(server)
			return
		end
		const mine = ticAt ~= nil
			and clock ~= nil
			and ticAt ~= playedAt
			and model:GetAttribute(TIC_USER) == Players.LocalPlayer.UserId
			and Players.LocalPlayer:GetAttribute(CLOSE_UP_ATTRIBUTE) == true
		if not mine or ticAt ~= layerAt then
			if layerAt ~= nil then
				-- I left (or the tic went) before the apex: cancelled, nothing of the tension starts
				clearLayer()
			end
			if not mine then
				return
			end
		end
		const at = ticAt :: number
		if layerState == nil then
			const apex = at + (clock :: Content.TicTiming).Peak
			if server > apex + STEP_LATE then
				playedAt = at -- a tic already past its apex (a stale TicAt): never replayed
				return
			end
			layerAt = at
			apexAt = apex
			const id = model:GetAttribute("NpcId")
			layerState = Steps.State(if type(id) == "number" then id else 0, row.Key)
		end
		runDue(server)
		if server >= apexAt then
			-- the apex: from here the tension is carried (the scene's Queue and the caption leave this client alone)
			const id = model:GetAttribute("NpcId")
			if type(id) == "number" then
				carried = id
				playedAt = at
				checkAt = server + CARRY_CHECK
				Carry.Set(id, apexAt)
			end
		end
	end

	const connection = RunService.Heartbeat:Connect(function(dt: number)
		const server = Workspace:GetServerTimeNow()
		const ticValue = model:GetAttribute(TIC_AT)
		const ticAt: number? = if type(ticValue) == "number" then ticValue else nil
		const clock = timingOf(ticAt)
		screen(ticAt, server, clock)
		const elapsed = if ticAt ~= nil then server - ticAt else 0
		-- the beats are heard by everyone near (the crack, the hum, the creak)
		if clock ~= nil and beats ~= nil then
			for index, at in clock.Beats do
				if elapsed < at then
					break
				end
				if index > beaten then
					beaten = index
					if elapsed - at <= BEAT_LATE then
						play(ctx, model, beats.Sound, beats.Volume, rules.HearRange)
					end
				end
			end
		end
		if body ~= nil then
			const view = Players.LocalPlayer:GetAttribute(VIEW_ATTRIBUTE)
			const queueValue = model:GetAttribute(QUEUE_ATTRIBUTE)
			const stepValue = model:GetAttribute(STEP_ATTRIBUTE)
			body.Step({
				Clock = os.clock(),
				Dt = dt,
				Server = server,
				TicAt = ticAt,
				Elapsed = elapsed,
				Timing = clock,
				Viewing = type(view) == "string" and view ~= "",
				QueueAt = if type(queueValue) == "number" then queueValue else nil,
				QueueStep = if type(stepValue) == "number" then stepValue else 0,
			})
		end
	end)
	return function()
		connection:Disconnect()
		clearLayer()
		if body ~= nil then
			body.Undo()
		end
	end
end

-- The pilot's entry (OddCustomer "neck"): the same as Mount
function Tic.Neck(ctx: Effect.Context, model: Model, row: Content.Tic): Undo
	return Tic.Mount(ctx, model, row)
end

return table.freeze(Tic)
