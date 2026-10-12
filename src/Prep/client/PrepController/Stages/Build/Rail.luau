--!strict
-- Rail: how many grilled sausages wait on the rail of the vehicle in use (the front one is the one the plate takes). Read
-- reactively from the KitchenController (the Stations set: record id = StationId * 100 + slot, Kind = rail, Count). The server
-- decides which sausage the plate takes at PrepFinish; this only tells the UI whether the sausage chip can be dragged.
local CollectionService = game:GetService("CollectionService")

const STATION_TAG = "Station"
const RAIL_KIND = "rail"
const RECORD_SLOT = 0
-- the dev preview (`/dev prep ui`) has no kitchen: a few sausages are always ready
const MOCK_COUNT = 3

const Rail = {}

function Rail.Count(controller: any): number
	if controller.Mock then
		return MOCK_COUNT
	end
	const kitchen: any = controller.Dependencies.KitchenController
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		if station:GetAttribute("StationKind") ~= RAIL_KIND or not station:IsDescendantOf(workspace) then
			continue
		end
		if not kitchen:IsCurrent(station) then
			continue
		end
		const id = station:GetAttribute("StationId")
		if type(id) ~= "number" then
			continue
		end
		const record = kitchen:SlotOf(id * 100 + RECORD_SLOT)
		if record ~= nil and record.Kind == RAIL_KIND then
			return record.Count
		end
	end
	return 0
end

return table.freeze(Rail)
