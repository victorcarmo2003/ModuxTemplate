--!strict
--[[
	Beacon: what marks the exact thing to use in a tutorial step (user request 2026-10-11, Provisional).

	  - Highlight on the target (the pot, the grill, the bun crate, the board, the customer): Mustard outline that pulses,
	    light Mustard fill (FillTransparency ~0.8), always on top so it reads through the counter and the awning.
	  - 3D arrow over it: a Mustard arrow built from three parts (shaft + a two-wedge head pointing down) that bobs and
	    spins slowly, with an Ink outline; its own Highlight draws it through walls too (AlwaysOnTop, half fill).
	  - Tip: an invisible anchored part kept at the arrow tip (no bob) where the owner hangs the screen-sized billboard
    arrow (TutorialArrow) that stays readable from far away.
  - Urge(true) (no progress on the step for a while, TutorialController IDLE): faster, wider bob, faster pulse and a
    stronger fill until the owner turns it off (the step changed).
Local only (client parts in a Workspace folder, no collision, no query, no touch, no shadow). Pure presentation:
	the owner (TutorialController) says what to mark (Set) and calls Step every frame.
]]
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)

export type Beacon = {
	-- adornee to mark (nil = nothing); lift = studs between its top and the arrow tip
	Set: (adornee: Instance?, lift: number) -> (),
	Step: () -> (),
	-- stronger pulse while the player made no progress (false = normal)
	Urge: (on: boolean) -> (),
	-- invisible part at the arrow tip (parented to the folder while something is marked)
	Tip: BasePart,
	-- what is marked now (nil = nothing) and whether the Highlight + 3D arrow are in the Workspace (debug panel)
	Marked: () -> Instance?,
	Mounted: () -> boolean,
	Destroy: () -> (),
}

-- PROVISIONAL sizes and timings (tune in play)
const HEAD_WIDTH = 1.7
const HEAD_HEIGHT = 1.3
const THICKNESS = 0.55
const SHAFT_WIDTH = 0.6
const SHAFT_HEIGHT = 1.2
const BOB = 0.35 -- studs up and down
const BOB_SPEED = 4.5 -- rad/s
const SPIN_SPEED = 1.6 -- rad/s around the vertical
const PULSE_SPEED = 5 -- rad/s of the target outline pulse
const FILL_MIN = 0.72 -- target fill transparency range (~0.8)
const FILL_MAX = 0.88
const OUTLINE_MAX = 0.55 -- target outline fades this far at the low of the pulse
const ARROW_FILL = 0.35 -- the arrow's own highlight: half fill, solid when seen through a wall
-- Urge (no progress): PROVISIONAL
const URGE_BOB = 0.8
const URGE_BOB_SPEED = 8
const URGE_PULSE_SPEED = 10
const URGE_FILL_MIN = 0.45

const Beacon = {}

local function part(className: string, name: string, size: Vector3, parent: Instance): BasePart
	const created = Instance.new(className) :: BasePart
	created.Name = name
	created.Size = size
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Massless = true
	created.Material = Enum.Material.SmoothPlastic
	created.Color = Theme.Color.Mustard
	created.Parent = parent
	return created
end

-- Top centre of what is marked (world), or nil when it is gone
local function topOf(adornee: Instance): Vector3?
	if adornee:IsA("Model") then
		const cf, size = adornee:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	elseif adornee:IsA("BasePart") then
		return adornee.Position + Vector3.new(0, adornee.ExtentsSize.Y / 2, 0)
	elseif adornee:IsA("Attachment") then
		return adornee.WorldPosition
	end
	return nil
end

-- container() = the folder the effects live in (re-created by the owner when it was destroyed)
function Beacon.new(container: () -> Instance): Beacon
	local adornee: Instance? = nil
	local lift = 1
	local urged = false

	const model = Instance.new("Model")
	model.Name = "TutorialArrow3D"
	const shaft = part("Part", "Shaft", Vector3.new(THICKNESS, SHAFT_HEIGHT, SHAFT_WIDTH), model)
	-- head: two wedges upside down, back to back, their vertical edges meeting under the shaft (a down triangle)
	const left = part("WedgePart", "HeadLeft", Vector3.new(THICKNESS, HEAD_HEIGHT, HEAD_WIDTH / 2), model)
	const right = part("WedgePart", "HeadRight", Vector3.new(THICKNESS, HEAD_HEIGHT, HEAD_WIDTH / 2), model)
	model.PrimaryPart = shaft
	const tip = part("Part", "TutorialTip", Vector3.new(0.2, 0.2, 0.2), model)
	tip.Transparency = 1
	tip.Parent = nil

	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillColor = Theme.Color.Mustard
	outline.FillTransparency = ARROW_FILL
	outline.OutlineColor = Theme.Color.Ink
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Adornee = model
	outline.Parent = model

	const glow = Instance.new("Highlight")
	glow.Name = "TutorialHighlight"
	glow.FillColor = Theme.Color.Mustard
	glow.FillTransparency = FILL_MIN
	glow.OutlineColor = Theme.Color.Mustard
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Enabled = false

	-- local frames of the pieces around the arrow tip (origin, y up), the head spread along Z before the spin.
	-- A WedgePart is full at its back (local +Z) and its bottom; upside down (local Y = world down) with its back
	-- turned to the centre, each half has its vertical edge on z = 0, its flat top up and its slope down to the tip.
	const quarter = HEAD_WIDTH / 4
	const headY = HEAD_HEIGHT / 2
	const leftFrame = CFrame.fromMatrix(
		Vector3.new(0, headY, -quarter),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, 1)
	)
	const rightFrame = CFrame.fromMatrix(
		Vector3.new(0, headY, quarter),
		Vector3.new(1, 0, 0),
		Vector3.new(0, -1, 0),
		Vector3.new(0, 0, -1)
	)
	const shaftFrame = CFrame.new(0, HEAD_HEIGHT + SHAFT_HEIGHT / 2 - 0.05, 0)

	local function hide()
		glow.Enabled = false
		glow.Adornee = nil
		model.Parent = nil
		tip.Parent = nil
	end

	return {
		Set = function(target: Instance?, height: number)
			lift = height
			if target == adornee then
				return
			end
			adornee = target
			if target == nil then
				hide()
				return
			end
			const folder = container()
			glow.Parent = folder
			glow.Adornee = target
			glow.Enabled = true
			model.Parent = folder
			tip.Parent = folder
		end,
		Urge = function(on: boolean)
			urged = on
		end,
		Tip = tip,
		Marked = function(): Instance?
			return adornee
		end,
		Mounted = function(): boolean
			return model.Parent ~= nil and glow.Enabled and glow.Parent ~= nil
		end,
		Step = function()
			const target = adornee
			if target == nil then
				return
			end
			if not target:IsDescendantOf(workspace) then
				-- the rig went back to the pool, the station was rebuilt: nothing to mark until the owner says so
				adornee = nil
				hide()
				return
			end
			const clock = os.clock()
			const pulse = (math.sin(clock * (if urged then URGE_PULSE_SPEED else PULSE_SPEED)) + 1) / 2
			const fillMin = if urged then URGE_FILL_MIN else FILL_MIN
			glow.OutlineTransparency = OUTLINE_MAX * (1 - pulse)
			glow.FillTransparency = FILL_MAX - (FILL_MAX - fillMin) * pulse
			const top = topOf(target)
			if top == nil then
				return
			end
			const rest = top + Vector3.new(0, lift, 0)
			tip.CFrame = CFrame.new(rest)
			const bob = if urged then URGE_BOB else BOB
			const at = rest + Vector3.new(0, bob * (1 + math.sin(clock * (if urged then URGE_BOB_SPEED else BOB_SPEED))), 0)
			const base = CFrame.new(at) * CFrame.Angles(0, clock * SPIN_SPEED, 0)
			left.CFrame = base * leftFrame
			right.CFrame = base * rightFrame
			shaft.CFrame = base * shaftFrame
		end,
		Destroy = function()
			adornee = nil
			tip:Destroy()
			glow:Destroy()
			model:Destroy()
		end,
	}
end

return table.freeze(Beacon)
