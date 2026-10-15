--!strict
--[[
	Arrow3D: the Mustard 3D guide arrow (owner request 2026-10-14: all arrows are 3D; the 2D one only when the target is
	off screen -> EdgePointer). Extracted from the tutorial Beacon so the Beacon, the Market hint and the prep FlipFocus
	draw the very same arrow.

	  - Shape: a rectangular shaft and a two-wedge head pointing DOWN, Mustard with an Ink outline (its own Highlight, always
	    on top, half fill), bobbing and spinning slowly, popping in with a spring (overshoot) and shrinking away on Hide.
	  - The owner says where (Step(rest, grow, urged) every frame): `rest` = the world point of the TIP (no bob), `grow` >= 1
	    scales the whole arrow (the Beacon grows it with the distance so it keeps a readable size on screen), `urged` = no
	    progress for a while: wider/faster bob.
	  - Reduced motion (Motion.Reduced): no bob, no spin, no pop (appears and disappears whole).
	Local presentation only (client parts, no collision, no query, no touch, no shadow).
]]
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Motion = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Motion)
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)

export type Arrow3D = {
	-- Pops the arrow in under `parent` (a Folder in the Workspace). Calling it again while shown only re-parents.
	Show: (parent: Instance) -> (),
	-- Pops it out (shrinks away, Step finishes it); at once when it was not drawn or with reduced motion.
	Hide: () -> (),
	-- Takes it out of the world at once (no animation): Show brings it back from zero.
	Detach: () -> (),
	-- rest = world point of the tip (no bob); grow >= 1 = size factor; urged = stronger bob.
	Step: (rest: Vector3, grow: number, urged: boolean) -> (),
	-- Whether it is in the Workspace (shown or shrinking away).
	Mounted: () -> boolean,
	-- Whether it is wanted (Show was called and Hide was not).
	On: () -> boolean,
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
const ARROW_FILL = 0.35 -- the arrow's own highlight: half fill, solid when seen through a wall
const URGE_BOB = 0.8
const URGE_BOB_SPEED = 8
const POP_OMEGA, POP_ZETA = 26, 0.55 -- pop in (~12% overshoot)
const OUT_OMEGA, OUT_ZETA = 30, 0.9 -- pop out
const GONE = 0.03

const Arrow3D = {}

-- studs from the tip to the top of the shaft at grow = 1 (the Beacon sizes the arrow on screen with it)
Arrow3D.HEIGHT = HEAD_HEIGHT + SHAFT_HEIGHT - 0.05

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

function Arrow3D.new(): Arrow3D
	local on = false
	local leaving = false
	const pop: HintMark.Spring = { X = 0, V = 0 }
	local lastClock = os.clock()

	const model = Instance.new("Model")
	model.Name = "Arrow3D"
	const shaftSize = Vector3.new(THICKNESS, SHAFT_HEIGHT, SHAFT_WIDTH)
	const leftSize = Vector3.new(THICKNESS, HEAD_HEIGHT, HEAD_WIDTH / 2)
	const shaft = part("Part", "Shaft", shaftSize, model)
	-- head: two wedges upside down, back to back, their vertical edges meeting under the shaft (a down triangle)
	const left = part("WedgePart", "HeadLeft", leftSize, model)
	const right = part("WedgePart", "HeadRight", leftSize, model)
	model.PrimaryPart = shaft

	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillColor = Theme.Color.Mustard
	outline.FillTransparency = ARROW_FILL
	outline.OutlineColor = Theme.Color.Ink
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Adornee = model
	outline.Parent = model

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

	local function detach()
		on = false
		leaving = false
		model.Parent = nil
	end

	return {
		Show = function(parent: Instance)
			if not on and not leaving and model.Parent == nil then
				pop.X = 0
				pop.V = 0
				lastClock = os.clock()
			end
			on = true
			leaving = false
			model.Parent = parent
		end,
		Hide = function()
			if not on then
				return
			end
			on = false
			if model.Parent == nil or Motion.Reduced() then
				detach()
			else
				leaving = true
			end
		end,
		Detach = detach,
		Step = function(rest: Vector3, grow: number, urged: boolean)
			const clock = os.clock()
			const dt = math.min(clock - lastClock, 0.1)
			lastClock = clock
			if not on and not leaving then
				return
			end
			const still = Motion.Reduced()
			if still then
				pop.X = if leaving then 0 else 1
				pop.V = 0
			elseif leaving then
				HintMark.Step(pop, 0, dt, OUT_OMEGA, OUT_ZETA)
			else
				HintMark.Step(pop, 1, dt, POP_OMEGA, POP_ZETA)
			end
			if leaving and pop.X < GONE then
				detach()
				return
			end
			const factor = math.max(grow, 1)
			const k = math.max(pop.X, 0.01) * factor
			const bob = (if urged then URGE_BOB else BOB) * factor
			const wave = math.sin(clock * (if urged then URGE_BOB_SPEED else BOB_SPEED))
			const at = rest + Vector3.new(0, if still then 0 else bob * (1 + wave), 0)
			const base = CFrame.new(at) * CFrame.Angles(0, if still then 0 else clock * SPIN_SPEED, 0)
			left.Size = leftSize * k
			right.Size = leftSize * k
			shaft.Size = shaftSize * k
			left.CFrame = base * (CFrame.new(leftFrame.Position * k) * leftFrame.Rotation)
			right.CFrame = base * (CFrame.new(rightFrame.Position * k) * rightFrame.Rotation)
			shaft.CFrame = base * (CFrame.new(shaftFrame.Position * k) * shaftFrame.Rotation)
		end,
		Mounted = function(): boolean
			return model.Parent ~= nil
		end,
		On = function(): boolean
			return on
		end,
		Destroy = function()
			on = false
			leaving = false
			model:Destroy()
		end,
	}
end

return table.freeze(Arrow3D)
