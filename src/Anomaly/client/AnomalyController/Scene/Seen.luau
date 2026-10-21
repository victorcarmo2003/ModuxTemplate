--!strict
--[[
	Which eyes see a step (TASK-586, TASK-589; design/horror-cinematic.md §11.3, the blackout's "only on the cameras"
	made a rule for every piece). Step.Seen:
	  "Cameras"  only while this client looks through a security camera (Kit/Watch)
	  "Eyes"     only with the bare eye: gone the moment the view goes to a camera
	  nil/"All"  always
	Seen.Visible(seen) answers now; Seen.Bind(seen, apply) calls apply(visible) at once and on every camera enter / leave,
	and returns the function that stops it (put it in state.Undo or the piece's own cleanup).
]]
local Watch = require(script.Parent.Parent.Effects.Kit.Watch)

const Seen = {}

function Seen.Visible(seen: string?): boolean
	if seen == "Cameras" then
		return Watch.Watching()
	elseif seen == "Eyes" then
		return not Watch.Watching()
	end
	return true
end

-- true when the step's visibility follows the camera view (worth a Bind)
function Seen.Layered(seen: string?): boolean
	return seen == "Cameras" or seen == "Eyes"
end

function Seen.Bind(seen: string?, apply: (visible: boolean) -> ()): () -> ()
	apply(Seen.Visible(seen))
	if not Seen.Layered(seen) then
		return function() end
	end
	const connection = Watch.Changed(function()
		apply(Seen.Visible(seen))
	end)
	return function()
		connection:Disconnect()
	end
end

return table.freeze(Seen)
