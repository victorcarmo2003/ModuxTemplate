--!strict
-- Halloween overlay of the lobby (DEC-346, TASK-629; docs/levels/LOBBY-halloween.md). The decoration itself is map data:
-- workspace.<Content.Events.Halloween.Folder>, built by tools/assetplace/HALLOWEEN_placements.luau, never inside
-- LOBBY_Assets. This client only:
--   Switch   out of Enabled or past EndsAt (server time) = the folder leaves the world locally, nothing animates.
--   Bubbles  Neon spheres rise out of the cauldron liquid (model with attribute HW_Role = "Cauldron", part Glow_Liquid)
--            and pop; walking within Burst.Radius makes it bubble harder for Burst.Duration (cooldown Burst.Cooldown).
--   Bats     models with attribute HW_Flap bob and sway slowly around their placed pivot.
--   Eyes     models with attribute HW_Blink (two Neon dots in a dark window) blink now and then. Mild: no sound.
-- Local only, no network, no sound. Everything stops farther than ActiveDistance from the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

const EVENT = Content.Events.Halloween
const BUBBLE_COLORS = { Color3.fromRGB(95, 211, 141), Color3.fromRGB(185, 166, 232), Color3.fromRGB(123, 75, 196) }

export type Halloween = {
	Step: (t: number, camera: Vector3?) -> (),
	Destroy: () -> (),
}

type Bubble = { Part: Part, Phase: number, Offset: Vector2, Size: number }
type Bat = { Model: Model, Home: CFrame, Phase: number }
type Eyes = { Parts: { BasePart }, NextAt: number, OpenAt: number }

const BLINK_EVERY = { 3.5, 8 } -- s between two blinks of one pair of eyes
const BLINK_LENGTH = 0.18 -- s the eyes stay shut

const SCAN_EVERY = 1 -- s between two looks for overlay pieces still streaming in
const SCAN_FOR = 30 -- s after the folder shows up during which new pieces are still picked up

return function(): Halloween?
	if not EVENT.Enabled or Workspace:GetServerTimeNow() >= EVENT.EndsAt then
		-- local only: the overlay is off for this client, now or when it streams in
		const folder = Workspace:FindFirstChild(EVENT.Folder)
		if folder then
			folder.Parent = nil
		else
			local connection: RBXScriptConnection? = nil
			connection = Workspace.ChildAdded:Connect(function(child: Instance)
				if child.Name == EVENT.Folder then
					child.Parent = nil
					if connection then
						connection:Disconnect()
					end
				end
			end)
		end
		return nil
	end

	-- StreamingEnabled: the folder and its (Persistent) models arrive after this controller starts, so the pieces
	-- are picked up lazily from Step, once a second during the first SCAN_FOR s after the folder shows up.
	local folder: Instance? = nil
	local seenAt = 0
	local nextScan = 0
	local burstFx: Instance? = nil
	const known: { [Instance]: boolean } = {}
	const bats: { Bat } = {}
	const eyes: { Eyes } = {}
	const bubbles: { Bubble } = {}
	const blinkRandom = Random.new()
	local base = Vector3.zero

	local function makeBubbles(liquid: BasePart, holder: Model)
		base = liquid.Position + Vector3.new(0, liquid.Size.Y / 2, 0)
		const spread = math.min(liquid.Size.X, liquid.Size.Z) * 0.32
		const random = Random.new(31)
		for i = 1, EVENT.Bubbles.Count do
			const part = Instance.new("Part")
			part.Name = `HW_Bubble{i}`
			part.Shape = Enum.PartType.Ball
			part.Material = Enum.Material.Neon
			part.Color = BUBBLE_COLORS[(i - 1) % #BUBBLE_COLORS + 1]
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Locked = true
			part.Transparency = 1
			part.Parent = holder
			const angle = random:NextNumber(0, math.pi * 2)
			const radius = spread * math.sqrt(random:NextNumber())
			table.insert(bubbles, {
				Part = part,
				Phase = (i - 1) / EVENT.Bubbles.Count,
				Offset = Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius),
				Size = random:NextNumber(EVENT.Bubbles.Size[1], EVENT.Bubbles.Size[2]),
			})
		end
	end

	local function scan(t: number)
		if folder == nil or folder.Parent == nil then
			folder = Workspace:FindFirstChild(EVENT.Folder)
			if folder == nil then
				return
			end
			seenAt = t
		end
		for _, item in (folder :: Instance):GetDescendants() do
			if not item:IsA("Model") or known[item] then
				continue
			end
			if item:GetAttribute("HW_Role") == "Cauldron" then
				const liquid = item:FindFirstChild("Glow_Liquid", true)
				if liquid and liquid:IsA("BasePart") then
					known[item] = true
					burstFx = item:FindFirstChild("HW_Burst", true)
					makeBubbles(liquid, item)
				end
			elseif item:GetAttribute("HW_Flap") then
				known[item] = true
				table.insert(bats, { Model = item, Home = item:GetPivot(), Phase = #bats * 0.37 })
			elseif item:GetAttribute("HW_Blink") then
				const parts: { BasePart } = {}
				for _, part in item:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(parts, part)
					end
				end
				if #parts > 0 then
					known[item] = true
					table.insert(eyes, { Parts = parts, NextAt = t + #eyes * 2.3 + 2, OpenAt = 0 })
				end
			end
		end
	end

	local clock = 0 -- bubble time: runs faster during a burst
	local last = 0
	local burstUntil = -math.huge
	local nextBurst = 0

	local function stepBubbles(t: number)
		local speed = 1
		if t < burstUntil then
			speed = EVENT.Burst.Speed
		elseif t >= nextBurst then
			const character = Players.LocalPlayer.Character
			const root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				const flat = Vector2.new(root.Position.X - base.X, root.Position.Z - base.Z)
				if flat.Magnitude <= EVENT.Burst.Radius then
					burstUntil = t + EVENT.Burst.Duration
					nextBurst = t + EVENT.Burst.Cooldown
					if burstFx and burstFx:IsA("ParticleEmitter") then
						burstFx:Emit(14)
					end
				end
			end
		end
		clock += (t - last) * speed
		for _, bubble in bubbles do
			const k = (clock / EVENT.Bubbles.Period + bubble.Phase) % 1
			const size = bubble.Size * (0.4 + 0.6 * math.min(k * 3, 1))
			bubble.Part.Size = Vector3.new(size, size, size)
			bubble.Part.Position = base + Vector3.new(bubble.Offset.X, k * EVENT.Bubbles.Rise, bubble.Offset.Y)
			bubble.Part.Transparency = if k > 0.8 then 0.2 + (k - 0.8) * 4 else 0.2
		end
	end

	local function stepBats(t: number)
		const bob, period, sway = EVENT.Bats.Bob, EVENT.Bats.Period, math.rad(EVENT.Bats.Sway)
		for _, bat in bats do
			const w = (t / period + bat.Phase) * math.pi * 2
			bat.Model:PivotTo(bat.Home * CFrame.new(0, math.sin(w) * bob, 0) * CFrame.Angles(0, math.sin(w * 0.5) * sway, 0))
		end
	end

	local function stepEyes(t: number)
		for _, pair in eyes do
			if pair.OpenAt > 0 and t >= pair.OpenAt then
				pair.OpenAt = 0
				for _, part in pair.Parts do
					part.Transparency = 0
				end
			elseif pair.OpenAt == 0 and t >= pair.NextAt then
				pair.OpenAt = t + BLINK_LENGTH
				pair.NextAt = t + blinkRandom:NextNumber(BLINK_EVERY[1], BLINK_EVERY[2])
				for _, part in pair.Parts do
					part.Transparency = 1
				end
			end
		end
	end

	local function near(camera: Vector3?, at: Vector3): boolean
		return camera == nil or (camera - at).Magnitude <= EVENT.ActiveDistance
	end

	return {
		Step = function(t: number, camera: Vector3?)
			if t >= nextScan and (folder == nil or t - seenAt <= SCAN_FOR) then
				nextScan = t + SCAN_EVERY
				scan(t)
			end
			if #bubbles > 0 and near(camera, base) then
				stepBubbles(t)
			end
			last = t
			if #bats > 0 then
				stepBats(t) -- rooftop bats are far from everything: they always move (6 PivotTo per frame at most)
			end
			stepEyes(t)
		end,
		Destroy = function()
			for _, bubble in bubbles do
				bubble.Part:Destroy()
			end
			table.clear(bubbles)
			for _, bat in bats do
				bat.Model:PivotTo(bat.Home)
			end
			for _, pair in eyes do
				for _, part in pair.Parts do
					part.Transparency = 0
				end
			end
		end,
	}
end
