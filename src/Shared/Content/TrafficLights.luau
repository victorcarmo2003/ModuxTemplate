--!strict
--[[
	Content.TrafficLights: the cycle of the street lights of MAP-01 (owner request 2026-10-12; PROVISIONAL, no DEC;
	DEC-130 said "no traffic light", the owner's hand-made lights stand). Pure data and pure functions: no Roblox API,
	so it runs in plain Luau. The client (TrafficLightController) paints lamps from it; nothing on the server reads it.

	Two axes, EW and NS, share one cycle of CycleTime seconds. Per axis: Green -> Yellow -> Red. Between the two
	greens there is an all-red gap (AllRed) on both axes, so opposite axes are never green or yellow together.

	  t in [0, Green)                          EW green      NS red
	  [Green, Green+Yellow)                    EW yellow     NS red
	  [Green+Yellow, Half)                     all red (AllRed)
	  [Half, Half+Green)                       NS green      EW red      (Half = Green + Yellow + AllRed)
	  ...                                      NS yellow, all red, back to 0

	Pedestrian rule (documented choice): a pedestrian WALKING ALONG an axis crosses the street of the other axis, and
	is released while the cars of that same axis (the ones that run parallel to the walk) have green: the street being
	crossed is red then. So `pedAllowedToCross(walkAxis, t)` is true while `walkAxis` is Green with more than PedFlash
	seconds left (Walk). The last PedFlash seconds of the green are a blinking hand (FlashingHand: do not start) and
	yellow and red are a steady Hand. A PedSignal carries the Axis of the walk it shows (same value as the cars that
	have green while it says Walk). With the other axis red the whole time, a walker never meets a green car.

	Time is `workspace:GetServerTimeNow()`, so every client draws the same phase.
]]

export type Axis = "EW" | "NS"
export type Phase = "Green" | "Yellow" | "Red"
export type PedState = "Walk" | "FlashingHand" | "Hand"
export type State = {
	Phase: Phase,
	TimeLeft: number, -- seconds until this phase ends
	PedState: PedState,
}

const Green = 10
const Yellow = 3
const AllRed = 1.5
const PedFlash = 4 -- last seconds of Green where the hand blinks
const FlashPeriod = 0.4 -- seconds per blink step (lit, then dark); same 0.8 s blink as the old Studio script
const OffDim = 0.18 -- a lamp that is off keeps this share of its lit colour (SmoothPlastic)
const Half = Green + Yellow + AllRed
const CycleTime = Half * 2

-- start of the green of each axis, in seconds inside the cycle
const Offsets: { [Axis]: number } = { EW = 0, NS = Half }

-- numeric ids for the allocation-free sampler (`sample`)
const PHASE_GREEN = 1
const PHASE_YELLOW = 2
const PHASE_RED = 3
const PED_WALK = 1
const PED_HAND_LIT = 2 -- steady hand, or the lit step of the blink
const PED_HAND_DARK = 3 -- the dark step of the blink

local PhaseNames: { Phase } = { "Green", "Yellow", "Red" }

-- phase id, seconds left in it, seconds left of green (0 when not green)
local function locate(axis: Axis, t: number): (number, number, number)
	const inCycle = (t - Offsets[axis]) % CycleTime
	if inCycle < Green then
		return PHASE_GREEN, Green - inCycle, Green - inCycle
	elseif inCycle < Green + Yellow then
		return PHASE_YELLOW, Green + Yellow - inCycle, 0
	end
	return PHASE_RED, CycleTime - inCycle, 0
end

-- Allocation-free: (phase id 1 Green | 2 Yellow | 3 Red, ped id 1 Walk | 2 Hand lit | 3 Hand dark). The ped blink is
-- part of the id, so a caller that repaints only when the pair changes also follows the blinking.
local function sample(axis: Axis, t: number): (number, number)
	const phase, _, greenLeft = locate(axis, t)
	if phase ~= PHASE_GREEN then
		return phase, PED_HAND_LIT
	end
	if greenLeft > PedFlash then
		return phase, PED_WALK
	end
	const step = math.floor(greenLeft / FlashPeriod)
	return phase, if step % 2 == 0 then PED_HAND_LIT else PED_HAND_DARK
end

-- Pure state of one axis at time t (allocates one table; for logic, tests and tools)
local function phaseAt(axis: Axis, t: number): State
	const phase, left, greenLeft = locate(axis, t)
	local ped: PedState = "Hand"
	if phase == PHASE_GREEN then
		ped = if greenLeft > PedFlash then "Walk" else "FlashingHand"
	end
	return { Phase = PhaseNames[phase], TimeLeft = left, PedState = ped }
end

-- true while a pedestrian walking along `walkAxis` may start crossing (Walk)
local function pedAllowedToCross(walkAxis: Axis, t: number): boolean
	const _phase, ped = sample(walkAxis, t)
	return ped == PED_WALK
end

return table.freeze({
	Green = Green,
	Yellow = Yellow,
	AllRed = AllRed,
	PedFlash = PedFlash,
	FlashPeriod = FlashPeriod,
	OffDim = OffDim,
	CycleTime = CycleTime,
	Offsets = table.freeze(Offsets),

	-- tags and attributes shared by the Studio layer, the controller and the rebuild snippet
	Tags = table.freeze({ Head = "TrafficSignal", Ped = "PedSignal" }),
	AxisAttribute = "Axis",
	OnColorAttribute = "OnColor",
	FolderName = "TrafficLights",
	HeadLamps = table.freeze({ "Red", "Yellow", "Green" }),
	PedLamps = table.freeze({ "Walk", "Hand" }),

	PHASE_GREEN = PHASE_GREEN,
	PHASE_YELLOW = PHASE_YELLOW,
	PHASE_RED = PHASE_RED,
	PED_WALK = PED_WALK,
	PED_HAND_LIT = PED_HAND_LIT,
	PED_HAND_DARK = PED_HAND_DARK,

	phaseAt = phaseAt,
	sample = sample,
	pedAllowedToCross = pedAllowedToCross,
})
