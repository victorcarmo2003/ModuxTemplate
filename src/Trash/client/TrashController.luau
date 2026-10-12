--!strict
--[[
	TrashController (owner request 2026-10-12; PROVISIONAL; numbers in Content.Trash)

	The tray of a cleaned table goes to the nearest dumpster: arc flight, lid open (or a bump when the bin has no
	Lid), the tray sinks and is destroyed, sound `trash`. Pure presentation: nothing is sent to the server (the
	server's clean_table already freed the table and paid the tip).

	API
	  Toss(tray: Model): boolean    flies a client-side Model (anchored, parented anywhere) to the nearest bin and
	                                destroys it there. Returns false (and destroys the tray at once) when no bin exists.
	  NearestBin(from: Vector3)     bin + DropPoint world position, or nil

	Bins are found by tag Content.Trash.Tag at call time (tolerant to streaming). A bin needs the Attachment
	DropPoint; a Lid (+ LidHinge) is optional. `/dev trash [n]` sets Workspace.TrashDevToss "<n>:<counter>": the
	client builds a test tray on table n and tosses it.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

local Tray = require(StarterPlayer.StarterPlayerScripts.client.Seating.SeatingController.Tray)

const Params = Content.Trash
const TABLE_TAG = Content.Seating.Binding.Tag
const TABLE_INDEX = Content.Seating.Binding.IndexAttribute

export type Bin = { Root: Instance, Drop: Vector3, Id: string }

const TrashController = Modux.Controller("TrashController", { Require = { "AudioController" }, Priority = 300 })

function TrashController:Setup()
	self.Ready = true :: boolean
end

local function style(name: string, fallback: Enum.EasingStyle): Enum.EasingStyle
	const item = (Enum.EasingStyle :: any)[name]
	return if typeof(item) == "EnumItem" then item else fallback
end

local function direction(name: string, fallback: Enum.EasingDirection): Enum.EasingDirection
	const item = (Enum.EasingDirection :: any)[name]
	return if typeof(item) == "EnumItem" then item else fallback
end

-- Runs step(alpha) on Heartbeat for `seconds` (alpha eased, 0..1; the last call is exactly 1). Yields.
local function animate(seconds: number, easing: Enum.EasingStyle, dir: Enum.EasingDirection, step: (number) -> ())
	if seconds <= 0 then
		step(1)
		return
	end
	local elapsed = 0
	while elapsed < seconds do
		step(TweenService:GetValue(elapsed / seconds, easing, dir))
		elapsed += RunService.Heartbeat:Wait()
	end
	step(1)
end

local function dropOf(root: Instance): Vector3?
	const found = root:FindFirstChild(Params.DropAttachment, true)
	if found ~= nil and found:IsA("Attachment") then
		return found.WorldPosition
	elseif found ~= nil and found:IsA("BasePart") then
		return found.Position
	end
	return nil
end

-- Nearest tagged bin with a DropPoint to `from` (flat distance)
function TrashController:NearestBin(from: Vector3): Bin?
	local best: Bin? = nil
	local bestDistance = math.huge
	for _, root in CollectionService:GetTagged(Params.Tag) do
		const drop = dropOf(root)
		if drop ~= nil and root:IsDescendantOf(workspace) then
			const distance = Vector3.new(drop.X - from.X, 0, drop.Z - from.Z).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				const id = root:GetAttribute(Params.BinIdAttribute)
				best = { Root = root, Drop = drop, Id = if typeof(id) == "string" then id else root.Name }
			end
		end
	end
	return best
end

-- Lid of a bin as (part, hinge CFrame) when it has one
local function lidOf(root: Instance): (BasePart?, CFrame?)
	const lid = root:FindFirstChild(Params.LidName, true)
	if lid == nil or not lid:IsA("BasePart") then
		return nil, nil
	end
	const hinge = root:FindFirstChild(Params.HingeName, true)
	local frame = lid.CFrame
	if hinge ~= nil and hinge:IsA("Attachment") then
		frame = hinge.WorldCFrame
	elseif hinge ~= nil and hinge:IsA("BasePart") then
		frame = hinge.CFrame
	end
	return lid, frame
end

-- Opens (open = true) or closes the lid, or bumps the mesh of a bin without one. Yields for the duration.
local function moveLid(root: Instance, open: boolean)
	const lid, hinge = lidOf(root)
	if lid ~= nil and hinge ~= nil then
		const rest = root:GetAttribute("TrashLidRest")
		const closed: CFrame = if typeof(rest) == "CFrame" then rest else lid.CFrame
		if typeof(rest) ~= "CFrame" then
			root:SetAttribute("TrashLidRest", closed)
		end
		const lidParams = Params.Lid
		const from = if open then 0 else 1
		const to = if open then 1 else 0
		const angle = math.rad(lidParams.OpenDegrees)
		animate(
			if open then lidParams.OpenSeconds else lidParams.CloseSeconds,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			function(alpha: number)
				if lid.Parent == nil then
					return
				end
				const turn = (from + (to - from) * alpha) * angle
				lid.CFrame = hinge * CFrame.Angles(-turn, 0, 0) * hinge:Inverse() * closed
			end
		)
		return
	end
	const mesh = root:FindFirstChildWhichIsA("SpecialMesh", true)
	if mesh == nil or not open then
		return
	end
	const rest = mesh:GetAttribute("TrashMeshRest")
	const original: Vector3 = if typeof(rest) == "Vector3" then rest else mesh.Scale
	mesh:SetAttribute("TrashMeshRest", original)
	const bump = Params.Bump
	animate(bump.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha: number)
		mesh.Scale = original * Vector3.new(1, 1 + (bump.Scale - 1) * alpha, 1)
	end)
	animate(bump.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha: number)
		mesh.Scale = original * Vector3.new(1, bump.Scale + (1 - bump.Scale) * alpha, 1)
	end)
end

-- Settles a bin back to its authored pose (cancelled toss, bin removed mid-way)
local function restore(root: Instance)
	const lid = root:FindFirstChild(Params.LidName, true)
	const rest = root:GetAttribute("TrashLidRest")
	if lid ~= nil and lid:IsA("BasePart") and typeof(rest) == "CFrame" then
		lid.CFrame = rest
	end
end

function TrashController:Fly(tray: Model, bin: Bin)
	const arc = Params.Arc
	const start = tray:GetPivot()
	const target = bin.Drop
	const distance = (target - start.Position).Magnitude
	const seconds = math.clamp(distance / arc.Speed, arc.MinSeconds, arc.MaxSeconds)
	const spin = arc.SpinTurns * math.pi * 2
	local opened = false
	animate(
		seconds,
		style(arc.Style, Enum.EasingStyle.Quad),
		direction(arc.Direction, Enum.EasingDirection.InOut),
		function(alpha: number)
			if tray.Parent == nil then
				return
			end
			const flat = start.Position:Lerp(target, alpha)
			const lift = math.sin(alpha * math.pi) * arc.Height
			tray:PivotTo(CFrame.new(flat + Vector3.new(0, lift, 0)) * (start - start.Position) * CFrame.Angles(0, spin * alpha, 0))
			if not opened and alpha > 0.55 then
				opened = true
				task.spawn(moveLid, bin.Root, true)
			end
		end
	)
	if not opened then
		task.spawn(moveLid, bin.Root, true)
	end
end

function TrashController:Sink(tray: Model, bin: Bin)
	const drop = Params.Drop
	const at = tray:GetPivot()
	const baseScale = tray:GetScale()
	animate(drop.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha: number)
		if tray.Parent == nil then
			return
		end
		tray:PivotTo(at - Vector3.new(0, drop.Depth * alpha, 0))
		tray:ScaleTo(baseScale * (1 + (drop.EndScale - 1) * alpha))
	end)
	tray:Destroy()
	self.Dependencies.AudioController:Play(Params.Sound, bin.Drop)
end

-- Flies `tray` to the nearest bin and destroys it there. No bin: destroyed at once (the old behaviour).
function TrashController:Toss(tray: Model): boolean
	for _, descendant in tray:GetDescendants() do
		-- tip coins already went to the drawer ("+$N" pop): only the rubbish is thrown away
		if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, 4) == "Coin" then
			descendant:Destroy()
		end
	end
	const bin = self:NearestBin(tray:GetPivot().Position)
	if bin == nil then
		tray:Destroy()
		return false
	end
	if tray.Parent == nil then
		tray.Parent = workspace
	end
	task.spawn(function()
		self:Fly(tray, bin)
		if tray.Parent ~= nil then
			self:Sink(tray, bin)
		end
		task.wait(Params.Lid.HoldSeconds)
		moveLid(bin.Root, false)
		restore(bin.Root)
	end)
	return true
end

-- Dev: a test tray on table `index` (client side) thrown to the nearest bin
function TrashController:DevToss(index: number)
	for _, model in CollectionService:GetTagged(TABLE_TAG) do
		if model:GetAttribute(TABLE_INDEX) == index and model:IsA("Model") then
			const frame, size = model:GetBoundingBox()
			const tray = Tray.Build(CFrame.new(frame.Position + Vector3.new(0, size.Y / 2, 0)), 0, Content.Seating.TableTip)
			tray.Parent = workspace
			self:Toss(tray)
			return
		end
	end
	warn(`[TrashController] dev toss: no table {index}`)
end

TrashController:OnInit(function(self)
	self:Setup()
end)

TrashController:OnStart(function(self)
	local function onDev()
		const value = workspace:GetAttribute(Params.DevAttribute)
		if typeof(value) ~= "string" then
			return
		end
		const index = tonumber(string.match(value, "^(%d+):"))
		if index ~= nil then
			self:DevToss(index)
		end
	end
	workspace:GetAttributeChangedSignal(Params.DevAttribute):Connect(onDev)
end)

return TrashController
