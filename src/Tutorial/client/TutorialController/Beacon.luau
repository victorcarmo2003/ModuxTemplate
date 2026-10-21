--!strict
--[[
	Beacon: what marks the exact thing to use in a tutorial step (user request 2026-10-11, Provisional).

	  - Highlight on the target (the pot, the grill, the bun crate, the board, the customer): Mustard outline that pulses,
	    light Mustard fill (FillTransparency ~0.8), always on top so it reads through the counter and the awning.
	  - Frame: a HintMark Rect (rounded rectangle, Ink rim) fitted to the bounding box of the target seen from the camera; it
	    pops in with a spring, breathes and pops out.
	  - 3D arrow over it (Arrow3D, shared with the Market hint and the prep flip focus): the Mustard arrow that bobs and spins,
	    pops in and shrinks away. Owner request 2026-10-14: this is the ONLY arrow over the target; from far away it grows with
	    the distance (GROW_PX) so it keeps a readable size on screen. The 2D one is the edge pointer (EdgePointer), the owner's
	    job, only when the target AND the tip are off screen: TipPosition() gives it the tip.
	  - Urge(true) (no progress on the step for a while, TutorialController IDLE): faster, wider bob, faster pulse and a
	    stronger fill until the owner turns it off (the step changed).
	  - Under a cinematic (Cinematic.Active) everything is taken out of the world and comes back when it ends.
Local only (client parts in a Workspace folder, no collision, no query, no touch, no shadow). Pure presentation:
	the owner (TutorialController) says what to mark (Set) and calls Step every frame.
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local HintMark = require(StarterPlayer.StarterPlayerScripts.client.Interface.HintMark)
local Arrow3D = require(StarterPlayer.StarterPlayerScripts.client.Interface.Arrow3D)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)

export type Beacon = {
	-- adornee to mark (nil = nothing); lift = studs between its top and the arrow tip
	Set: (adornee: Instance?, lift: number) -> (),
	Step: () -> (),
	-- stronger pulse while the player made no progress (false = normal)
	Urge: (on: boolean) -> (),
	-- world point of the arrow tip (no bob) while something is marked, else nil (for the edge pointer)
	TipPosition: () -> Vector3?,
	-- what is marked now (nil = nothing) and whether the Highlight + 3D arrow are in the Workspace (debug panel)
	Marked: () -> Instance?,
	Mounted: () -> boolean,
	Destroy: () -> (),
}

-- PROVISIONAL sizes and timings (tune in play)
const PULSE_SPEED = 5 -- rad/s of the target outline pulse
const FILL_MIN = 0.72 -- target fill transparency range (~0.8)
const FILL_MAX = 0.88
const OUTLINE_MAX = 0.55 -- target outline fades this far at the low of the pulse
-- Urge (no progress): PROVISIONAL
const URGE_PULSE_SPEED = 10
const URGE_FILL_MIN = 0.45
const FRAME_PAD = 0.15 -- studs around the target box
-- Distance growth (owner request 2026-10-14, Provisional): the arrow keeps ~GROW_PX px of apparent height (x UI scale) from
-- far away, up to GROW_MAX times its size; up close it stays at its own size (never smaller)
const GROW_PX = 70
const GROW_MAX = 10

const Beacon = {}

-- How many times bigger than its own size the arrow must be so it reads ~GROW_PX px tall at `top`
local function growth(top: Vector3): number
	const camera = workspace.CurrentCamera
	if camera == nil or camera.ViewportSize.Y < 1 then
		return 1
	end
	const distance = (top - camera.CFrame.Position).Magnitude
	const studsPerPx = 2 * distance * math.tan(math.rad(camera.FieldOfView) / 2) / camera.ViewportSize.Y
	const want = GROW_PX * Theme.ScaleOf(camera.ViewportSize) * studsPerPx / Arrow3D.HEIGHT
	return math.clamp(want, 1, GROW_MAX)
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
const CLOSE_UP = "TalkCloseUp" -- LocalPlayer attribute while the order talk close-up is on (TabletController)

function Beacon.new(container: () -> Instance): Beacon
	local adornee: Instance? = nil
	local lift = 1
	local urged = false
	local rest = Vector3.zero
	local hasRest = false
	local hidden = false -- a cinematic owns the screen: nothing is drawn, the mark is kept
	local frameMark: HintMark.Mark? = nil

	const arrow = Arrow3D.new()

	const glow = Instance.new("Highlight")
	glow.Name = "TutorialHighlight"
	glow.FillColor = Theme.Color.Mustard
	glow.FillTransparency = FILL_MIN
	glow.OutlineColor = Theme.Color.Mustard
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Enabled = false

	-- everything out of the world at once (no animation)
	local function hide()
		hasRest = false
		if frameMark ~= nil then
			frameMark:Hide()
		end
		glow.Enabled = false
		glow.Adornee = nil
		arrow.Detach()
	end

	-- the mark is on again (after a cinematic)
	local function restore(target: Instance)
		const folder = container()
		glow.Parent = folder
		glow.Adornee = target
		glow.Enabled = true
		arrow.Show(folder)
	end

	return {
		Set = function(target: Instance?, height: number)
			lift = height
			if target == adornee then
				return
			end
			adornee = target
			if target == nil then
				-- pop out: the contour goes at once, the arrow and the frame shrink away (Step finishes it)
				glow.Enabled = false
				glow.Adornee = nil
				hasRest = false
				if frameMark ~= nil then
					frameMark:Hide()
				end
				arrow.Hide()
				return
			end
			if hidden then
				return -- Step puts it up when the cinematic ends
			end
			restore(target)
		end,
		Urge = function(on: boolean)
			urged = on
		end,
		TipPosition = function(): Vector3?
			return if adornee ~= nil and hasRest then rest else nil
		end,
		Marked = function(): Instance?
			return adornee
		end,
		Mounted = function(): boolean
			return arrow.Mounted() and glow.Enabled and glow.Parent ~= nil
		end,
		Step = function()
			const target = adornee
			-- owner 2026-10-21: the order talk's close-up (TabletController sets the attribute) hides it too - the contour and
			-- the arrow were drawn over the customer's face
			if Cinematic.Active() or Players.LocalPlayer:GetAttribute(CLOSE_UP) == true then
				-- the intro / finale / credits own the screen: draw nothing, keep what is marked
				if not hidden then
					hidden = true
					hide()
				end
				return
			elseif hidden then
				hidden = false
				if target ~= nil then
					restore(target)
				end
			end
			if target == nil then
				arrow.Step(rest, 1, urged) -- finishes the pop out
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
			-- the arrow grows with the distance, and so does its lift (it stays clear of the target)
			const grow = growth(top)
			rest = top + Vector3.new(0, lift * grow, 0)
			hasRest = true
			-- the frame: the box of the target, as the camera sees it
			if not target:IsA("Attachment") then
				local boxFrame = CFrame.identity
				local boxSize = Vector3.zero
				if target:IsA("Model") then
					boxFrame, boxSize = target:GetBoundingBox()
				elseif target:IsA("BasePart") then
					boxFrame, boxSize = target.CFrame, target.Size
				end
				if boxSize.Magnitude > 0 then
					const frameOwn = frameMark or HintMark.new()
					frameMark = frameOwn
					frameOwn:Fit(boxFrame, boxSize, FRAME_PAD)
				end
			end
			arrow.Step(rest, grow, urged)
		end,
		Destroy = function()
			adornee = nil
			hasRest = false
			glow:Destroy()
			arrow.Destroy()
			if frameMark ~= nil then
				frameMark:Destroy()
				frameMark = nil
			end
		end,
	}
end

return table.freeze(Beacon)
