--!strict
-- State: which grill slot is being flipped right now and where the sausage icon is on its bar. Written by the focused cook mode
-- (CookController/Grill), read by the world bars (ProgressBar's flip mode through KitchenController/Slots). Status only: the
-- press and the score stay with the cook mode; the server decides the flip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

const active: Vide.Source<number?> = Vide.source(nil :: number?)
const marker = Vide.source(0)

const State = {}

-- Record id (StationId * 100 + Slot) of the sausage whose bar is in flip mode, nil = none. Reactive.
function State.Active(): number?
	return (active :: any)() :: number?
end

-- 0..1 along the bar. Reactive.
function State.Marker(): number
	return marker()
end

function State.Set(id: number?)
	if Vide.untrack(active) ~= id then
		active(id)
	end
end

function State.SetMarker(value: number)
	marker(value)
end

function State.Clear()
	State.Set(nil)
end

return table.freeze(State)
