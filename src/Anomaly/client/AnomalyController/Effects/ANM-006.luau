--!strict
--[[
	ANM-006 The wavers, client effect (TASK-116; anomalies.md N6; npcs.md NPC-014; asset-list AST-045, AST-063;
	server contract: AnomalyService/Anomalies/ANM-006.luau, TASK-115).

	Presents only. The server picks the window (record Anchor = n of WV-n), measures the gaze against the anchor and
	decides the failure; nothing here feeds a rule (X3-16: hiding the local window changes nothing on the server).

	  Signal    window WV-n lit, curtain still closed, no silhouette (cue `curtain` plays its sound just before).
	  Active    curtain open, silhouette (AST-063) waving slowly with one hand, without stopping.
	  Failed    same as Active (the N6 is per player: the server never publishes Failed for it; kept for safety).
	  Resolved  the light goes off by itself (AutoOff); silhouette gone, curtain closed again.
	  Removed   (root destroyed) everything restored.
	  Cue `waver_more` (entity = window n, Duration 5 s): the silhouette waves with both hands from then on and the
	            two other WV windows light up for the cue Duration (anomalies.md N6 "Consequência").

	A late joiner mounts with the current record and sees the same state (lit / waving), no sound replayed (T116-01).

	Window (binding W2 of bind_map01, AST-045 sheet): the AnomalyAnchor WV-n is either the Model `Window_Up_<n>`
	(children `Window_Up_<n>_Lit`, `Curtain_Up_<n>`, glass, `Att_Waver_<n>`) or a single Part (the invisible fallback
	of the binding while AST-045 is not re-uploaded). "Lit" = hide the glass so the `_Lit` strip behind it shows
	(LocalTransparencyModifier only: the map parts stay as the server made them). Without a `_Lit` part a local Neon
	pane is drawn on the outer face of the anchor. Curtain "open" = curtain parts faded out locally.

	PROVISIONAL (frontend-coder, TASK-116): the silhouette is a Part placeholder (bust card #2B2233, round head with
	no ears, separate Arm_R / Arm_L) until the AST-063 model ships (TASK-124); a template named `AST-063_Wavers` or
	`Silhouette_Card` under ReplicatedStorage.Assets replaces it automatically (arms found by name). Lit colour, wave
	speed/angle and the curtain fade time are Provisional numbers; "two hands for the rest of the occurrence" reads
	the N6 sheet ("passa a acenar com as duas mãos").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)

const REF = "ANM-006"
const WINDOW_PREFIX = "WV-"
const WINDOWS = 3 -- WV-1..3 (MAP-01 §10.3)
const ASSET_NAMES = { "AST-063_Wavers", "Silhouette_Card" }
const RETRY = 1 -- s between two lookups of a window that has not streamed in yet

const INK = Color3.fromHex("#2B2233") -- AST-063 Silhouette_Card
const LIT_COLOR = Color3.fromHex("#FFD9A0") -- warm Cream window (style guide Cream family); Provisional
const PANE_INSET = 0.94 -- pane size relative to the window opening
const PANE_OUT = 0.03 -- studs past the outer face of the anchor
const CARD_OUT = 0.02 -- studs in front of the pane
const CARD_THICK = 0.04

const MIN_HEIGHT = 3 -- studs: smallest opening the bust is laid out for
const SHOULDERS = Vector2.new(1.8, 1.2) -- width, height of the bust card
const HEAD = 1.15 -- diameter
const ARM = Vector2.new(0.32, 1.25) -- width, length
const SHOULDER_X = 0.8
const SHOULDER_Y = 1.05 -- above the bottom of the opening

const WAVE_PERIOD = 2.4 -- s per back-and-forth: slow (anomalies.md N6 "acena devagar")
const WAVE_CENTRE = math.rad(150) -- from hanging down: raised and slightly outwards
const WAVE_SWING = math.rad(22)
const CURTAIN_FADE = 0.35 -- s

type Window = {
	Index: number,
	Anchor: Instance,
	Frame: CFrame, -- centre of the opening; LookVector = outwards (street side), UpVector = world up
	Width: number,
	Height: number,
	Thin: number, -- depth of the anchor along the normal
	Glass: { BasePart },
	Curtains: { BasePart },
	LitPart: BasePart?,
	CardFrame: CFrame, -- where the silhouette card stands (centre of the opening, in the card plane)
}

type Arm = { Part: BasePart, Shoulder: CFrame, Side: number, Offset: CFrame }

type Waver = {
	Model: Model,
	Arms: { [string]: Arm },
	TwoHands: boolean,
	Connection: RBXScriptConnection?,
}

type Hold = { Count: number, Pane: BasePart?, Window: Window }

type State = {
	Occurrence: Effect.Occurrence,
	Window: Window?,
	Lit: (() -> ())?,
	Open: (() -> ())?,
	Waver: Waver?,
	TwoHands: boolean,
	Alive: boolean,
	Retrying: boolean,
}

-- Shared by every occurrence: two occurrences may light the same window (refcounted, restored at 0).
const litHolds: { [number]: Hold } = {}
const openHolds: { [number]: Hold } = {}
-- record id -> state (the cue `waver_more` reaches the silhouette of its occurrence)
const states: { [number]: State } = {}

-- Geometry --------------------------------------------------------------------------------------------------------

local function nameHas(instance: Instance, text: string): boolean
	return string.find(string.lower(instance.Name), string.lower(text), 1, true) ~= nil
end

local function boxOf(anchor: Instance): (CFrame?, Vector3?)
	if anchor:IsA("BasePart") then
		return anchor.CFrame, anchor.Size
	elseif anchor:IsA("Model") then
		const cf, size = anchor:GetBoundingBox()
		return cf, size
	end
	return nil, nil
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

-- Frame of the opening: the most vertical box axis is "up"; of the two horizontal ones the thinner is the normal,
-- turned towards the camera (the window is only seen from the street side; +Z = south, MAP-01, when no camera).
local function frameOf(cf: CFrame, size: Vector3): (CFrame, number, number, number)
	const axes = {
		{ Vector = cf.RightVector, Size = size.X },
		{ Vector = cf.UpVector, Size = size.Y },
		{ Vector = cf.LookVector, Size = size.Z },
	}
	local upIndex = 1
	for index, axis in axes do
		if math.abs(axis.Vector.Y) > math.abs(axes[upIndex].Vector.Y) then
			upIndex = index
		end
	end
	const horizontal: { { Vector: Vector3, Size: number } } = {}
	for index, axis in axes do
		if index ~= upIndex then
			table.insert(horizontal, axis)
		end
	end
	table.sort(horizontal, function(a: { Vector: Vector3, Size: number }, b: { Vector: Vector3, Size: number }): boolean
		return a.Size < b.Size
	end)
	const normalAxis, widthAxis = horizontal[1], horizontal[2]
	local normal = Vector3.new(normalAxis.Vector.X, 0, normalAxis.Vector.Z)
	normal = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.zAxis
	const camera = Workspace.CurrentCamera
	const towards = if camera then camera.CFrame.Position - cf.Position else Vector3.zAxis
	if normal:Dot(towards) < 0 then
		normal = -normal
	end
	return CFrame.lookAt(cf.Position, cf.Position + normal), widthAxis.Size, axes[upIndex].Size, normalAxis.Size
end

local function resolve(ctx: Effect.Context, index: number): Window?
	if index < 1 or index > WINDOWS or index ~= math.floor(index) then
		return nil
	end
	const anchor = ctx.Anchor(`{WINDOW_PREFIX}{index}`)
	if anchor == nil then
		return nil
	end
	const cf, size = boxOf(anchor)
	if cf == nil or size == nil then
		return nil
	end
	const frame, width, height, thin = frameOf(cf, size)

	const glass: { BasePart } = {}
	const curtains: { BasePart } = {}
	local litPart: BasePart? = nil
	local waverAt: Vector3? = nil
	for _, descendant in anchor:GetDescendants() do
		if descendant:IsA("BasePart") then
			if string.sub(descendant.Name, -4) == "_Lit" then
				litPart = descendant
			elseif nameHas(descendant, "Curtain") then
				table.insert(curtains, descendant)
			elseif nameHas(descendant, "Glass") or descendant.Material == Enum.Material.Glass then
				table.insert(glass, descendant)
			end
		end
		if waverAt == nil and nameHas(descendant, "Att_Waver") then
			waverAt = positionOf(descendant)
		end
	end

	-- card plane: the Att_Waver fitting (between the light and the glass) or in front of the local pane
	local depth = thin / 2 + PANE_OUT + CARD_OUT
	if waverAt then
		depth = (waverAt - frame.Position):Dot(frame.LookVector)
	end
	return {
		Index = index,
		Anchor = anchor,
		Frame = frame,
		Width = width,
		Height = math.max(height, MIN_HEIGHT),
		Thin = thin,
		Glass = glass,
		Curtains = curtains,
		LitPart = litPart,
		CardFrame = frame * CFrame.new(0, 0, -depth),
	}
end

-- Local parts -----------------------------------------------------------------------------------------------------

local function localPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	return part
end

local function fade(parts: { BasePart }, to: number, time: number)
	for _, part in parts do
		if part.Parent == nil then
			continue
		end
		if time <= 0 then
			part.LocalTransparencyModifier = to
		else
			TweenService:Create(part, TweenInfo.new(time), { LocalTransparencyModifier = to }):Play()
		end
	end
end

-- Lit: glass hidden (the `_Lit` strip shows) or a local Neon pane. Returns the release.
local function holdLit(ctx: Effect.Context, window: Window): () -> ()
	local hold = litHolds[window.Index]
	if hold == nil or hold.Window.Anchor ~= window.Anchor then
		hold = { Count = 0, Pane = nil, Window = window } :: Hold
		litHolds[window.Index] = hold
	end
	const current = hold :: Hold
	current.Count += 1
	if current.Count == 1 then
		fade(window.Glass, 1, 0)
		if window.LitPart == nil then
			const pane = localPart(
				`WV-{window.Index}_Lit`,
				Vector3.new(window.Width * PANE_INSET, window.Height * PANE_INSET, CARD_THICK),
				LIT_COLOR,
				Enum.Material.Neon
			)
			pane.CFrame = window.Frame * CFrame.new(0, 0, -(window.Thin / 2 + PANE_OUT))
			pane.Parent = ctx.Folder()
			current.Pane = pane
		end
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		current.Count -= 1
		if current.Count > 0 then
			return
		end
		fade(window.Glass, 0, 0)
		const pane = current.Pane
		if pane then
			pane:Destroy()
		end
		current.Pane = nil
		if litHolds[window.Index] == current then
			litHolds[window.Index] = nil
		end
	end
end

-- Curtain open (faded out locally). Returns the release (curtain closed again).
local function holdOpen(window: Window): () -> ()
	local hold = openHolds[window.Index]
	if hold == nil or hold.Window.Anchor ~= window.Anchor then
		hold = { Count = 0, Pane = nil, Window = window } :: Hold
		openHolds[window.Index] = hold
	end
	const current = hold :: Hold
	current.Count += 1
	if current.Count == 1 then
		fade(window.Curtains, 1, CURTAIN_FADE)
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		current.Count -= 1
		if current.Count > 0 then
			return
		end
		fade(window.Curtains, 0, 0)
		if openHolds[window.Index] == current then
			openHolds[window.Index] = nil
		end
	end
end

-- Silhouette ------------------------------------------------------------------------------------------------------

-- Placeholder AST-063 in the card frame (origin = centre of the opening): bust, round head without ears, two arms.
local function placeholder(height: number): (Model, { [string]: Arm })
	const model = Instance.new("Model")
	model.Name = "AST-063_Wavers_Placeholder"
	const bottom = -height / 2
	const bust = localPart("Silhouette_Card", Vector3.new(SHOULDERS.X, SHOULDERS.Y, CARD_THICK), INK, Enum.Material.SmoothPlastic)
	bust:SetAttribute("Offset", CFrame.new(0, bottom + SHOULDERS.Y / 2, 0))
	bust.Parent = model
	const head = localPart("Head", Vector3.new(CARD_THICK, HEAD, HEAD), INK, Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Cylinder
	head:SetAttribute("Offset", CFrame.new(0, bottom + SHOULDERS.Y + HEAD / 2 - 0.05, 0) * CFrame.Angles(0, math.rad(90), 0))
	head.Parent = model
	const arms: { [string]: Arm } = {}
	for _, spec in { { Name = "Arm_R", Side = -1 }, { Name = "Arm_L", Side = 1 } } do
		const arm = localPart(spec.Name, Vector3.new(ARM.X, ARM.Y, CARD_THICK), INK, Enum.Material.SmoothPlastic)
		arm.Parent = model
		arms[spec.Name] = {
			Part = arm,
			Shoulder = CFrame.new(spec.Side * SHOULDER_X, bottom + SHOULDER_Y, 0),
			Side = spec.Side,
			Offset = CFrame.new(0, -ARM.Y / 2, 0),
		}
	end
	return model, arms
end

-- Template from ReplicatedStorage.Assets (AST-063): pivot = card centre; arms by name, shoulder = top of the arm.
local function fromAsset(): (Model?, { [string]: Arm })
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets == nil then
		return nil, {}
	end
	for _, name in ASSET_NAMES do
		const found = assets:FindFirstChild(name, true)
		if found and found:IsA("Model") then
			const model = found:Clone()
			const pivot = model:GetPivot()
			const arms: { [string]: Arm } = {}
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
					descendant.CastShadow = false
					descendant:SetAttribute("Offset", pivot:ToObjectSpace(descendant.CFrame))
					if descendant.Name == "Arm_R" or descendant.Name == "Arm_L" then
						const local_ = pivot:ToObjectSpace(descendant.CFrame)
						const shoulder = CFrame.new((local_ * CFrame.new(0, descendant.Size.Y / 2, 0)).Position)
						arms[descendant.Name] = {
							Part = descendant,
							Shoulder = shoulder,
							Side = if local_.Position.X < 0 then -1 else 1,
							Offset = shoulder:ToObjectSpace(local_),
						}
					end
				end
			end
			return model, arms
		end
	end
	return nil, {}
end

-- Body parts once (full), arms every frame.
local function placeWaver(waver: Waver, frame: CFrame, now: number, full: boolean)
	if full then
		for _, descendant in waver.Model:GetDescendants() do
			if descendant:IsA("BasePart") and waver.Arms[descendant.Name] == nil then
				const offset = descendant:GetAttribute("Offset")
				if typeof(offset) == "CFrame" then
					descendant.CFrame = frame * offset
				end
			end
		end
	end
	const phase = math.sin(now * 2 * math.pi / WAVE_PERIOD)
	for name, arm in waver.Arms do
		const raised = name == "Arm_R" or waver.TwoHands
		-- tip x = L sin(angle): the angle sign follows the side so the arm is raised outwards (above the shoulder)
		const angle = if raised then arm.Side * WAVE_CENTRE + WAVE_SWING * phase else 0
		arm.Part.CFrame = frame * arm.Shoulder * CFrame.Angles(0, 0, angle) * arm.Offset
	end
end

local function spawnWaver(ctx: Effect.Context, state: State, window: Window): Waver
	local model, arms = fromAsset()
	if model == nil then
		model, arms = placeholder(window.Height)
	end
	const built = model :: Model
	const waver: Waver = { Model = built, Arms = arms, TwoHands = state.TwoHands, Connection = nil }
	placeWaver(waver, window.CardFrame, os.clock(), true)
	built.Parent = ctx.Folder()
	waver.Connection = RunService.Heartbeat:Connect(function()
		waver.TwoHands = state.TwoHands
		placeWaver(waver, window.CardFrame, os.clock(), false)
	end)
	return waver
end

local function dropWaver(state: State)
	const waver = state.Waver
	if waver == nil then
		return
	end
	state.Waver = nil
	const connection = waver.Connection
	if connection then
		connection:Disconnect()
	end
	waver.Model:Destroy()
end

-- State -----------------------------------------------------------------------------------------------------------

local function release(state: State)
	dropWaver(state)
	const open = state.Open
	state.Open = nil
	if open then
		open()
	end
	const lit = state.Lit
	state.Lit = nil
	if lit then
		lit()
	end
end

local apply: (ctx: Effect.Context, state: State) -> ()

local function retryLater(ctx: Effect.Context, state: State)
	if state.Retrying then
		return
	end
	state.Retrying = true
	task.spawn(function()
		while state.Alive and state.Window == nil do
			task.wait(RETRY)
			if state.Alive then
				apply(ctx, state)
			end
		end
		state.Retrying = false
	end)
end

apply = function(ctx: Effect.Context, state: State)
	if not state.Alive then
		return
	end
	const record = state.Occurrence.Record()
	const phase = record.Phase
	const lit = phase == "Signal" or phase == "Active" or phase == "Failed"
	const waving = phase == "Active" or phase == "Failed"

	local window = state.Window
	if window and window.Index ~= record.Anchor then
		release(state)
		window = nil
		state.Window = nil
	end
	if window == nil then
		if not lit then
			return
		end
		window = resolve(ctx, record.Anchor)
		if window == nil then
			retryLater(ctx, state)
			return
		end
		state.Window = window
	end
	const current = window :: Window

	if lit and state.Lit == nil then
		state.Lit = holdLit(ctx, current)
	end
	if waving then
		if state.Open == nil then
			state.Open = holdOpen(current)
		end
		if state.Waver == nil then
			state.Waver = spawnWaver(ctx, state, current)
		end
	else
		dropWaver(state)
		const open = state.Open
		state.Open = nil
		if open then
			open()
		end
	end
	if not lit then
		const held = state.Lit
		state.Lit = nil
		if held then
			held()
		end
	end
end

-- Module ----------------------------------------------------------------------------------------------------------

local function stateFor(cue: Effect.Cue): State?
	const occurrence = cue.Occurrence
	if occurrence then
		const found = states[occurrence.Id]
		if found and found.Occurrence == occurrence then
			return found
		end
	end
	for _, state in states do
		const window = state.Window
		if window and window.Index == cue.Entity then
			return state
		end
	end
	return nil
end

const Wavers: Effect.Module = {
	Ref = REF,

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		const state: State = {
			Occurrence = occ,
			Window = nil,
			Lit = nil,
			Open = nil,
			Waver = nil,
			TwoHands = false,
			Alive = true,
			Retrying = false,
		}
		states[occ.Id] = state

		Vide.effect(function()
			occ.Record() -- track: Phase and Anchor
			Vide.untrack(function()
				apply(ctx, state)
			end)
		end)

		Vide.cleanup(function()
			state.Alive = false
			release(state)
			if states[occ.Id] == state then
				states[occ.Id] = nil
			end
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "curtain" then
			-- the sound comes before the silhouette (FEAT-022 rule 2); heard from the window
			const window = resolve(ctx, cue.Entity)
			ctx.Play("curtain", if window then window.Frame.Position else nil)
		elseif cue.Cue == "waver_more" then
			const state = stateFor(cue)
			if state then
				state.TwoHands = true
			end
			-- the two other windows light up for the cue Duration
			const releases: { () -> () } = {}
			for index = 1, WINDOWS do
				if index ~= cue.Entity then
					const window = resolve(ctx, index)
					if window then
						table.insert(releases, holdLit(ctx, window))
					end
				end
			end
			task.wait(math.max(cue.Row.Duration, 0))
			for _, releaseOne in releases do
				releaseOne()
			end
		end
	end,
}

return Wavers
