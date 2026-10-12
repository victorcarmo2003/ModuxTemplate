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
-- Tier 3: nothing found, nil (the caller keeps the old anchor maths); warns once per station.
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
	if next(parts) == nil then
		warnOnce(station, "no Rail_<N>/Part found, using the slot anchors (sausages may float)")
		return
	end
	for slot, spot in spots do
		const pose = resolve(station, slot, parts)
		if pose then
			spot.Offset = spot.Host.CFrame:ToObjectSpace(pose)
		end
	end
end

return table.freeze(RailSlot)
