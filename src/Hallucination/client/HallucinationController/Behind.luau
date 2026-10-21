--!strict
-- Shared spot of the "behind you" effects (owner 2026-10-21, Provisional; Content.Nights.Behind; Effects/BehindSteps,
-- BehindCreak, BehindTap). The server already picked a player facing away; the client checks its own camera again so a
-- player who turned in the meantime never hears it in front of them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Context = require(script.Parent.Context)

const SLACK = 4 -- studs over Behind.Near (the player may have stepped since the server checked)

export type Spot = {
	Root: Vector3, -- the player's root
	Away: Vector3, -- flat unit vector from the player toward the window (behind them)
	Window: Vector3, -- the window's counter spot
	Distance: number, -- flat studs from the player to it
}

const Behind = {}

-- nil = the player is not near the window or is looking at it now
function Behind.Spot(): Spot?
	const rules = Content.Nights.Behind
	const ok, frame = pcall(MapIndex.FindPoint, rules.Point)
	const root = Context.Root()
	const camera = Context.Camera()
	if not ok or frame == nil or root == nil or camera == nil then
		return nil
	end
	const window = (frame :: CFrame).Position
	const toward = Vector3.new(window.X - root.Position.X, 0, window.Z - root.Position.Z)
	const distance = toward.Magnitude
	if distance < 1 or distance > rules.Near + SLACK then
		return nil
	end
	const look = camera.CFrame.LookVector
	const flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	const angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(toward.Unit), -1, 1)))
	if angle < rules.Facing then
		return nil
	end
	return { Root = root.Position, Away = toward.Unit, Window = window, Distance = distance }
end

-- A point `studs` behind the player (toward the window, never past it), lifted `lift` studs
function Behind.At(spot: Spot, studs: number, lift: number): Vector3
	return spot.Root + spot.Away * math.min(studs, spot.Distance) + Vector3.yAxis * lift
end

return table.freeze(Behind)
