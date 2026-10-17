--!strict
-- World/FlipFocus: the focus screen of the flip (owner request 2026-10-14). When the first side of a sausage is done and the
-- cooking bar WAITS for the flip, the screen dims (Ink, translucent) except for a ring around the sausage, as the tutorial does
-- for the phone or a pickup, and (when SHOW_ARROW is on) the shared 3D arrow (Interface/Arrow3D) points down at it: "tap this one". The dim never blocks the input (Spotlight's
-- frames are not Active). It is a teaching aid: it shows for the first `Rules.World.Grill.FocusFlips` flips of the session (module
-- counter, never saved) and goes with the window (the flip, a throw, the end of the mode).
-- How it works: `Set(point, radius)` takes the WORLD point of the sausage and its size in studs; `Step` projects them to the
-- screen every frame, moves an invisible Frame ("Hole") there and the Spotlight component rings it. The arrow is an Arrow3D
-- (world parts under the PrepWorld folder of the camera, always on top; owner request 2026-10-14: all guide arrows are 3D, no
-- edge pointer here, the focus already hides itself when the sausage is off screen). One Vide root, a ScreenGui under the shell (DisplayOrder), destroyed with `Destroy`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Spotlight = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Spotlight)
local Arrow3D = require(StarterPlayer.StarterPlayerScripts.client.Interface.Arrow3D)
local Types = require(script.Parent.Types)

export type FlipFocus = {
	-- Shows the focus on a world point (the sausage), `radius` = studs from its centre to the edge of the ring; nil hides it.
	Set: (self: FlipFocus, point: Vector3?, radius: number) -> (),
	Step: (self: FlipFocus, dt: number) -> (),
	Destroy: (self: FlipFocus) -> (),
}

const FlipFocusModule = {}

const create = Vide.create
const ORDER = 4 -- under the prep shell (6) and the cursor (7): the buttons stay bright
const DIM = 0.55
const ARROW_LIFT = 1.35 -- studs over the point: clear of the flip bar (0.7 over the roller), the arrow points DOWN at it (tip)
const SHOW_ARROW = false -- owner request 2026-10-14: no arrow over the sausage (true = the 3D one)

-- flips that showed the focus in this session (module state: it teaches the first few, then stays out of the way)
local shownFor = 0
const MAX_SHOWN = 3

function FlipFocusModule.Taught(): boolean
	return shownFor >= MAX_SHOWN
end

function FlipFocusModule.new(): FlipFocus
	const shown = Vide.source(false)
	local hole: Frame? = nil
	local arrow: Arrow3D.Arrow3D? = nil
	local counted = false
	local point: Vector3? = nil
	local radius = 0.6

	const unmount, gui = Vide.root(function(): ScreenGui
		const holeFrame = create("Frame")({
			Name = "Hole",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(10, 10),
		})
		hole = holeFrame
		return create("ScreenGui")({
			Name = "PrepFlipFocus",
			ResetOnSpawn = false,
			ScreenInsets = Enum.ScreenInsets.None,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = ORDER,
			holeFrame,
			Spotlight({
				Name = "FlipSpotlight",
				Shown = function()
					return shown()
				end,
				Target = function(): GuiObject?
					return holeFrame
				end,
				Padding = 6,
				Dim = DIM,
			}),
		}) :: ScreenGui
	end)
	const player = Players.LocalPlayer
	gui.Parent = player:WaitForChild("PlayerGui")

	const self = {} :: any

	function self.Set(_: any, at: Vector3?, studs: number)
		if at == nil or FlipFocusModule.Taught() and not counted then
			point = nil
			if shown() then
				shown(false)
			end
			if arrow ~= nil then
				arrow.Detach()
			end
			counted = false
			return
		end
		point = at
		radius = studs
		if not counted then
			counted = true
			shownFor += 1
		end
	end

	function self.Step(_: any, _dt: number)
		const camera = workspace.CurrentCamera
		const at = point
		const holeFrame = hole
		if at == nil or camera == nil or holeFrame == nil then
			return
		end
		-- GUI space (WorldToScreenPoint) minus the origin of this gui: a ScreenInsets.None gui starts left / above the safe area
		-- (notch, top bar), and a viewport point used as an offset in it lands off the sausage on a phone with a side inset
		-- (playtest 2026-10-17: the ring sat ~47 px left of the sausage)
		const point, onScreen = camera:WorldToScreenPoint(at)
		const screen = Vector2.new(point.X, point.Y) - gui.AbsolutePosition
		if not onScreen then
			if shown() then
				shown(false)
			end
			if arrow ~= nil then
				arrow.Detach()
			end
			return
		end
		-- the ring: the screen size of `radius` studs at that depth, never smaller than a finger
		const edge = camera:WorldToScreenPoint(at + camera.CFrame.RightVector * radius)
		const side = math.max(math.abs(edge.X - point.X) * 2, 56)
		holeFrame.Position = UDim2.fromOffset(screen.X, screen.Y)
		holeFrame.Size = UDim2.fromOffset(side, side)
		if not shown() then
			shown(true)
		end
		-- no arrow over the sausage (owner request 2026-10-14): the ring of the dim and the flip bar say "this one"
		if SHOW_ARROW then
			const folder = camera:FindFirstChild(Types.FolderName)
			if folder ~= nil then
				if arrow == nil then
					arrow = Arrow3D.new()
				end
				const own = arrow :: Arrow3D.Arrow3D
				if not own.On() then
					own.Show(folder)
				end
				own.Step(at + Vector3.new(0, ARROW_LIFT, 0), 1, false)
			end
		end
	end

	function self.Destroy(_: any)
		if arrow ~= nil then
			arrow.Destroy()
			arrow = nil
		end
		unmount()
		gui:Destroy()
	end

	return self :: FlipFocus
end

return FlipFocusModule
