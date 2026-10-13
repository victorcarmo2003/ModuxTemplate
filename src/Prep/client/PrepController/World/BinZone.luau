--!strict
-- World/BinZone: the 2D bin of the prep chrome (polish of 2026-10-12: the bin is a UI zone, not a 3D prop). The bridge between three
-- layers that do not know each other: the stages (World/Bin: `SetWanted`, `Eat`), the Aim (is the dragged item over the zone?) and
-- the PrepShell (draws the zone, says where it is). Module state, no Roblox instances, no Vide: the controller turns it into Vide
-- sources with `Subscribe`. Everything is reset when the world leaves (`Reset`).
local BinZone = {}

-- Is there something that can be thrown right now (the zone shows only then)?
local wanted = false
-- A dragged item is over the zone (the lid opens and lights).
local over = false
-- Counts the swallows (the zone bounces on a change).
local chomp = 0
-- Where the zone is, in raw viewport px: set by the shell. `Hit` tests a viewport point, `Center` is the middle of the zone.
local hit: ((Vector2) -> boolean)? = nil
local center: (() -> Vector2?)? = nil
local listeners: { () -> () } = {}

local function notify()
	for _, fn in table.clone(listeners) do
		fn()
	end
end

function BinZone.Wanted(): boolean
	return wanted
end

function BinZone.Over(): boolean
	return over
end

function BinZone.Chomp(): number
	return chomp
end

function BinZone.SetWanted(value: boolean)
	if wanted ~= value then
		wanted = value
		if not value then
			over = false
		end
		notify()
	end
end

function BinZone.SetOver(value: boolean)
	if over ~= value then
		over = value
		notify()
	end
end

function BinZone.Swallowed()
	chomp += 1
	notify()
end

-- The shell registers how to test a point (and the centre) while it is mounted; nil on unmount.
function BinZone.Bind(hitFn: ((Vector2) -> boolean)?, centerFn: (() -> Vector2?)?)
	hit = hitFn
	center = centerFn
end

-- Is the raw viewport point inside the zone? False when the zone is not on screen.
function BinZone.Hit(viewportPx: Vector2): boolean
	return wanted and hit ~= nil and hit(viewportPx)
end

function BinZone.Center(): Vector2?
	return if center ~= nil then center() else nil
end

-- Calls `fn` on every change of the state; returns the function that stops it.
function BinZone.Subscribe(fn: () -> ()): () -> ()
	table.insert(listeners, fn)
	return function()
		const index = table.find(listeners, fn)
		if index ~= nil then
			table.remove(listeners, index)
		end
	end
end

function BinZone.Reset()
	wanted = false
	over = false
	notify()
end

return BinZone
