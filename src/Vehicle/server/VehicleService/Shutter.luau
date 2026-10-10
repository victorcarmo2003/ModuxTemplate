--!strict
-- Trailer interior volume of the service window (architecture.md §19.14 v4.2; DEC-221; TASK-130; tests/wave-3.md
-- L3-20). VehicleService:IsInside reads it. No Modux, Lync or Charm.
--
-- PROVISIONAL (TASK-130, L3-20): "inside the trailer" = the LightZone volume LZ-1 of the binding (MAP-01 §10.2/§16:
-- MapBinding/LightZones, X 27..53, Z 36..46, floor +2 up to the ceiling; Group trailer_interior), not the bounding
-- box of the trailer Model: that box also holds the awning, the roof and the wheels, so a player under the awning or
-- on the roof would count as protected. LZ-1 sits at the Pad, where the trailer always is while it is the current
-- vehicle (the trailer for sale never has its window in use). Same reader as LightService (shared Light/Zones).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Zones = require(ReplicatedStorage.shared.Light.Zones)

-- ZoneId of the trailer interior (MAP-01 §16 binding id, like the MapPoints CART/TRL)
const INTERIOR_ZONE = "LZ-1"

const Shutter = {}

Shutter.InteriorZone = INTERIOR_ZONE

-- LightZone part of the interior in the Workspace, or nil
function Shutter.findInterior(): BasePart?
	for _, instance in CollectionService:GetTagged(Zones.Tag) do
		if
			instance:IsA("BasePart")
			and instance:IsDescendantOf(workspace)
			and instance:GetAttribute("ZoneId") == INTERIOR_ZONE
		then
			return instance
		end
	end
	return nil
end

-- position inside the interior part (read live: the part never moves, but nothing is cached against a re-bind)
function Shutter.contains(part: BasePart, position: Vector3): boolean
	const zone = Zones.read(part)
	return zone ~= nil and Zones.contains(zone, position)
end

return table.freeze(Shutter)
