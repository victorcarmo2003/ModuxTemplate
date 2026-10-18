--!strict
-- RailSlot: world pose of a sausage resting on the RestRail (owner request 2026-10-12; Content.RailSlot).
--
--   RailSlot.Resolve(station, slot) -> CFrame?   world pivot pose (sausage pivot = base centre) for the slot
--   RailSlot.Spots(station, spots)               rewrites the Offsets of Slots.Spots with the resolved poses
--
-- Source of truth: `Rail_<slot>/Part` (invisible, anchored, on the roller surface, orientation correct).
-- Tier 1: Rail_<slot>.Part exists and is narrow (Content.RailSlot.PerSlotMaxWidth): one Part per roller.
-- Tier 2: otherwise the Part is a TRAY shared by the slots (today: Rail_8 = the 8-slot rail, one 2.6 x 2.3 Part, N =
-- slot count): the slot Attachment is projected onto the nearest Part's top face (keeps the Part tilt).
-- Tier 3 (TASK-515, the conveyor rest table): no Rail_<N>/Part near the slot, the slot Attachment is dropped onto the top
-- face of the station Part right under it (footprint contains the anchor, top face at most DROP_MAX below it; the
-- closest wins), with that Part's orientation. So a rest table without the owner's surface Parts still rests the sausages.
-- Tier 4: nothing found, nil (the caller keeps the old anchor maths); warns once per station, only then.
-- The pose is cached per (station, slot) in HOST space, so it follows the trailer when the server moves it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
const Content = require(ReplicatedStorage.shared.Content)

const warned: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function warnOnce(station: Instance, text: string)
	if not warned[station] then
		warned[station] = true
		warn(`[RailSlot] {station:GetFullName()}: {text}`)
	end
end

local function surfaceParts(station: Instance): { [number]: BasePart }
	const config = Content.RailSlot
	const found: { [number]: BasePart } = {}
	for _, child in station:GetDescendants() do
		const text = if child:IsA("BasePart") then string.match(child.Name, "^" .. config.RailPrefix .. "(%d+)$") else nil
		const number = if text then tonumber(text) else nil
		if number then
			const part = child:FindFirstChild(config.PartName)
			if part and part:IsA("BasePart") then
				found[number] = part
			end
		end
	end
	return found
end

local function slotPosition(station: Instance, slot: number): Vector3?
	for _, descendant in station:GetDescendants() do
		if descendant:GetAttribute("Slot") == slot and descendant:IsA("Attachment") then
			return descendant.WorldPosition
		end
	end
	return nil
end

const DROP_MAX = 2 -- studs: a top face this far under the slot anchor still catches it (tier 3)
const DROP_INSIDE = 0.05 -- studs: the anchor may sit this much inside the top face

-- Tier 3: the slot anchor dropped onto the top face of the closest station Part right under it, or nil.
local function dropped(station: Instance, position: Vector3, extra: CFrame): CFrame?
	local best: BasePart? = nil
	local bestGap = math.huge
	local bestLocal = Vector3.zero
	for _, child in station:GetDescendants() do
		if not child:IsA("BasePart") then
			continue
		end
		const inside = child.CFrame:PointToObjectSpace(position)
		const half = child.Size / 2
		if math.abs(inside.X) > half.X or math.abs(inside.Z) > half.Z then
			continue
		end
		const gap = inside.Y - half.Y
		if gap >= -DROP_INSIDE and gap <= DROP_MAX and gap < bestGap then
			best, bestGap, bestLocal = child, gap, inside
		end
	end
	if best == nil then
		return nil
	end
	return best.CFrame * CFrame.new(bestLocal.X, best.Size.Y / 2 + Content.RailSlot.VerticalOffset, bestLocal.Z) * extra
end

-- world pose, or nil
local function resolve(station: Instance, slot: number, parts: { [number]: BasePart }): CFrame?
	const config = Content.RailSlot
	const extra = CFrame.Angles(0, math.rad(config.ExtraYawDegrees), 0)
	const exact = parts[slot]
	if exact and exact.Size.X <= config.PerSlotMaxWidth then
		return exact.CFrame * CFrame.new(0, exact.Size.Y / 2 + config.VerticalOffset, 0) * extra
	end
	const position = slotPosition(station, slot)
	if position == nil then
		return nil
	end
	if next(parts) == nil then
		return dropped(station, position, extra)
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, part in parts do
		const distance = (part.Position - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	if best == nil then
		return nil
	end
	const offset = best.CFrame:PointToObjectSpace(position)
	const x = math.clamp(offset.X, -best.Size.X / 2, best.Size.X / 2)
	return best.CFrame * CFrame.new(x, best.Size.Y / 2 + config.VerticalOffset, 0) * extra
end

const RailSlot = {}

function RailSlot.Resolve(station: Instance, slot: number): CFrame?
	return resolve(station, slot, surfaceParts(station))
end

-- spots: Slots.Spots result ({ Slot, Host, Offset }); Offset becomes Host-relative to the resolved pose.
function RailSlot.Spots(station: Instance, spots: { [number]: { Slot: number, Host: BasePart, Offset: CFrame } })
	const parts = surfaceParts(station)
	local missed = 0
	for slot, spot in spots do
		const pose = resolve(station, slot, parts)
		if pose then
			spot.Offset = spot.Host.CFrame:ToObjectSpace(pose)
		else
			missed += 1
		end
	end
	-- only when even the drop onto the table top failed (tier 4): those slots keep their anchors
	if missed > 0 then
		warnOnce(station, `{missed} slot(s) without Rail_<N>/Part nor a surface under the anchor (sausages may float)`)
	end
end

return table.freeze(RailSlot)
