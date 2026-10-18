--!strict
--[[
	CenterTable (TASK-522; DEC-304, Q-383 A; tech/prep-conveyor.md §7.2; MAP-01-r4 §16.5 d / §16.7; ui-text.md §17.1)

	Putting the equipped plate on a free slot of the central table, from the client side. The server decides
	(PlateService, responder of Net.Restaurant.CenterPut): nothing here moves a plate.

	  Desktop   click a free slot (Click_Slot_n box under the pointer; the crosshair in first person). Bound to
	            MouseButton1 only while a plate is equipped near a free slot; hover = "Click to set #n here"
	  Touch     tap the slot in the world (TouchTapInWorld) or the "Set down" button (nearest free slot)
	  Gamepad   Y ("Set down"): the free slot nearest the character
	A slot shown as taken never sends a packet (the tap / click does nothing); a just-sent slot stays pending
	PENDING s, and the client keeps the CenterTable.PutRate floor (the server drops the excess anyway).
	While a plate is equipped near the table the free slots glow (local discs) and the one the input would pick is
	brighter, so a tap lands on the right slot (10 of 10 on a 667 x 375 phone: boxes 2.2 x 1.0 x 2.2, 0.4 apart).

	Also gives the prompt rules the slot of the only "Take" prompt that may show: the plate nearest the character
	(NearestTake), so the 8 hold-E prompts 2.6 studs apart do not pile up on a phone.

	Plain module: the PlateController owns the state and passes the reads in (Host). The pick is ray-box maths on the
	slot boxes, so it works whatever CanQuery / CanCollide the map gives them.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local CartoonPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonPanel)
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)
local CartoonButton = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonButton)

const create = Vide.create

const CENTER = Content.Restaurant.CenterTable
-- MAP-01-r4 §16.7: the put reach of the click (<= CenterTable.Reach, the server's): at 6 studs the box is still >= 44 px
const PUT_REACH = math.min(6, CENTER.Reach)
const PUT_INTERVAL = 1 / math.max(CENTER.PutRate, 1)
const PENDING = 0.6 -- s a just-sent slot is not sent again (the set answers well inside it)
const RAY_LENGTH = 40
const MARK_SIZE = Vector3.new(0.06, 2.0, 2.0) -- disc (cylinder along X, laid flat)
const MARK_LIFT = 0.04
const MARK_IDLE = 0.72 -- transparency of a free slot
const MARK_PICK = 0.3 -- the slot the input would pick
const MARK_COLOR = Theme.Color.Mustard
const FOLDER_NAME = "CenterTableMarks"

-- ui-text.md §17.1 (Provisional; BELT_TIP_PUT_* / BELT_UI_PUT_PAD)
const TEXT = table.freeze({
	Mouse = "Click to set %s here",
	Touch = "Tap to set %s here",
	Pad = "Set down",
	PadKey = "Y: Set down", -- the gamepad chip (Y does it)
	Plate = "the plate", -- %s when the plate has no #n yet
})

export type View = {
	Index: number,
	Box: BasePart?, -- Click_Slot_n (the click target)
	Mount: CFrame?, -- where the plate sits (Mount_Plate_n); nil = the bottom of the box
	Free: boolean, -- no plate on it as the set shows it (unknown = free: the server decides)
	Plate: boolean, -- a plate is on it (ticket or orphan): its "Take" prompt may show
}

export type Host = {
	Views: () -> { View }, -- the bound slots now (not reactive)
	-- the equipped plate / hot dog that can be put down (#n for the tip); nil = none equipped
	Equipped: () -> { Number: number? }?,
	Device: () -> string, -- "KeyboardMouse" | "Gamepad" | "Touch" (reactive)
	Gameplay: () -> boolean, -- InputController context is Gameplay
	Root: () -> BasePart?, -- local HumanoidRootPart
	SetBound: (on: boolean) -> (), -- binds / unbinds the put input (InputController)
	Send: (slot: number) -> (), -- fires CenterPut
}

export type State = {
	Host: Host,
	Near: Vide.Source<boolean>, -- a putable plate is equipped near a free slot (the input is bound)
	Hover: Vide.Source<number?>, -- desktop: the free slot under the pointer
	Pick: Vide.Source<number?>, -- gamepad / touch button: the free slot nearest the character
	Number: Vide.Source<number?>, -- #n of the equipped plate (tip)
	Take: number?, -- slot of the only plate_take prompt (nearest plate), not reactive (read by Rules at 10 Hz)
	Bound: boolean,
	LastSend: number,
	Pending: { [number]: number }, -- slot -> os.clock() it was sent
	Marks: { [number]: BasePart },
	Folder: Folder?,
}

const CenterTable = {}

function CenterTable.new(host: Host): State
	return {
		Host = host,
		Near = Vide.source(false) :: Vide.Source<boolean>,
		Hover = Vide.source(nil :: number?) :: Vide.Source<number?>,
		Pick = Vide.source(nil :: number?) :: Vide.Source<number?>,
		Number = Vide.source(nil :: number?) :: Vide.Source<number?>,
		Take = nil,
		Bound = false,
		LastSend = 0,
		Pending = {},
		Marks = {},
		Folder = nil,
	}
end

-- Where the plate of a slot sits (world): the mount, else the bottom face of the box (yaw kept)
function CenterTable.Base(view: View): CFrame?
	if view.Mount ~= nil then
		return view.Mount
	end
	const box = view.Box
	if box == nil then
		return nil
	end
	const cf = box.CFrame
	const _, yaw = cf:ToOrientation()
	return CFrame.new(cf.Position - Vector3.new(0, box.Size.Y / 2, 0)) * CFrame.fromOrientation(0, yaw, 0)
end

-- One slab of the ray-box test: the new (near, far) or nil when the ray misses
local function slab(o: number, d: number, half: number, near: number, far: number): (number?, number)
	if math.abs(d) < 1e-9 then
		if math.abs(o) > half then
			return nil, far
		end
		return near, far
	end
	local t1, t2 = (-half - o) / d, (half - o) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	const lo, hi = math.max(near, t1), math.min(far, t2)
	if lo > hi then
		return nil, hi
	end
	return lo, hi
end

-- Distance along the ray to the box (slab test in the box's space); nil = missed
local function rayBox(origin: Vector3, direction: Vector3, box: BasePart): number?
	const cf = box.CFrame
	const o = cf:PointToObjectSpace(origin)
	const d = cf:VectorToObjectSpace(direction)
	const half = box.Size / 2
	local near: number?, far = 0, math.huge
	near, far = slab(o.X, d.X, half.X, near :: number, far)
	if near == nil then
		return nil
	end
	near, far = slab(o.Y, d.Y, half.Y, near, far)
	if near == nil then
		return nil
	end
	near, far = slab(o.Z, d.Z, half.Z, near, far)
	return near
end

local function within(view: View, root: BasePart): boolean
	const base = CenterTable.Base(view)
	return base ~= nil and (base.Position - root.Position).Magnitude <= PUT_REACH
end

-- Slot whose box the screen point hits first (any state); nil = none. `inset` = the point includes the GUI inset
function CenterTable.Under(state: State, point: Vector2, inset: boolean): View?
	const camera = Workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	const ray = if inset then camera:ScreenPointToRay(point.X, point.Y) else camera:ViewportPointToRay(point.X, point.Y)
	const direction = ray.Direction.Unit * RAY_LENGTH
	local best: View? = nil
	local bestT = math.huge
	for _, view in state.Host.Views() do
		const box = view.Box
		if box ~= nil and box.Parent ~= nil then
			const t = rayBox(ray.Origin, direction, box)
			if t ~= nil and t < bestT then
				best, bestT = view, t
			end
		end
	end
	return best
end

-- The free slot nearest the character, within the put reach
local function nearestFree(views: { View }, root: BasePart): number?
	local best: number? = nil
	local bestDistance = math.huge
	for _, view in views do
		const base = CenterTable.Base(view)
		if view.Free and base ~= nil then
			const distance = (base.Position - root.Position).Magnitude
			if distance <= PUT_REACH and distance < bestDistance then
				best, bestDistance = view.Index, distance
			end
		end
	end
	return best
end

-- The plate nearest the character (any distance): the only "Take" prompt that may show
local function nearestPlate(views: { View }, root: BasePart): number?
	local best: number? = nil
	local bestDistance = math.huge
	for _, view in views do
		const base = CenterTable.Base(view)
		if view.Plate and base ~= nil then
			const distance = (base.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = view.Index, distance
			end
		end
	end
	return best
end

local function viewOf(views: { View }, index: number): View?
	for _, view in views do
		if view.Index == index then
			return view
		end
	end
	return nil
end

-- Sends CenterPut for `index` if it is free, in reach and not just sent. Returns true when a packet went out.
function CenterTable.Put(state: State, index: number?): boolean
	if index == nil or not Vide.untrack(state.Near) then
		return false
	end
	const host = state.Host
	const root = host.Root()
	const view = viewOf(host.Views(), index)
	if root == nil or view == nil or not view.Free or not within(view, root) or host.Equipped() == nil then
		return false -- a slot shown as taken never sends a packet
	end
	const now = os.clock()
	const sent = state.Pending[index]
	if (sent ~= nil and now - sent < PENDING) or now - state.LastSend < PUT_INTERVAL then
		return false
	end
	state.Pending[index] = now
	state.LastSend = now
	host.Send(index)
	return true
end

-- The bound key (MouseButton1 / ButtonY / the touch button): pointer slot on desktop, nearest free slot otherwise
function CenterTable.Press(state: State)
	if state.Host.Device() == "KeyboardMouse" then
		const view = CenterTable.Under(state, UserInputService:GetMouseLocation(), false)
		CenterTable.Put(state, if view then view.Index else nil)
	else
		CenterTable.Put(state, Vide.untrack(state.Pick))
	end
end

-- A tap in the world (UserInputService.TouchTapInWorld, screen point with the inset)
function CenterTable.Tap(state: State, point: Vector2)
	const view = CenterTable.Under(state, point, true)
	if view ~= nil then
		CenterTable.Put(state, view.Index)
	end
end

function CenterTable.NearestTake(state: State): number?
	return state.Take
end

local function setIf<T>(value: Vide.Source<T>, new: T)
	if Vide.untrack(value) ~= new then
		value(new)
	end
end

-- Local glow discs on the free slots while a plate is equipped near the table
local function drawMarks(state: State, views: { View }, on: boolean, picked: number?)
	if state.Folder == nil and on then
		const folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = Workspace
		state.Folder = folder
	end
	const keep: { [number]: boolean } = {}
	if on then
		for _, view in views do
			const base = CenterTable.Base(view)
			if view.Free and base ~= nil then
				keep[view.Index] = true
				local mark = state.Marks[view.Index]
				if mark == nil or mark.Parent == nil then
					const part = Instance.new("Part")
					part.Name = `Mark_{view.Index}`
					part.Shape = Enum.PartType.Cylinder
					part.Size = MARK_SIZE
					part.Material = Enum.Material.Neon
					part.Color = MARK_COLOR
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					part.Parent = state.Folder
					state.Marks[view.Index] = part
					mark = part
				end
				const target = base * CFrame.new(0, MARK_LIFT, 0) * CFrame.Angles(0, 0, math.pi / 2)
				if mark.CFrame ~= target then
					mark.CFrame = target
				end
				const transparency = if picked == view.Index then MARK_PICK else MARK_IDLE
				if mark.Transparency ~= transparency then
					mark.Transparency = transparency
				end
			end
		end
	end
	for index, mark in state.Marks do
		if not keep[index] then
			mark:Destroy()
			state.Marks[index] = nil
		end
	end
end

-- 10 Hz (PlateController clock): reach, binding, hover, the nearest plate for the prompt rules, the glow discs
function CenterTable.Step(state: State)
	const host = state.Host
	const views = host.Views()
	const root = host.Root()
	const equipped = host.Equipped()
	state.Take = if root ~= nil then nearestPlate(views, root) else nil

	const now = os.clock()
	for index, sent in state.Pending do
		if now - sent >= PENDING then
			state.Pending[index] = nil
		end
	end

	const pick = if root ~= nil and equipped ~= nil and host.Gameplay() then nearestFree(views, root) else nil
	const near = pick ~= nil
	setIf(state.Near, near)
	setIf(state.Pick, pick)
	setIf(state.Number, if equipped then equipped.Number else nil)

	local hover: number? = nil
	if near and Vide.untrack(host.Device) == "KeyboardMouse" and root ~= nil then
		const view = CenterTable.Under(state, UserInputService:GetMouseLocation(), false)
		if view ~= nil and view.Free and within(view, root) then
			hover = view.Index
		end
	end
	setIf(state.Hover, hover)

	if near ~= state.Bound then
		state.Bound = near
		host.SetBound(near)
	end
	const desktop = Vide.untrack(host.Device) == "KeyboardMouse"
	drawMarks(state, views, near, if desktop then hover else pick)
end

function CenterTable.Destroy(state: State)
	if state.Bound then
		state.Bound = false
		state.Host.SetBound(false)
	end
	for _, mark in state.Marks do
		mark:Destroy()
	end
	table.clear(state.Marks)
	if state.Folder ~= nil then
		state.Folder:Destroy()
		state.Folder = nil
	end
end

local function tipText(state: State, format: string): string
	const number = state.Number()
	return string.format(format, if number ~= nil then `#{number}` else TEXT.Plate)
end

-- The put hint and the "Set down" button (build inside a Vide root; scaled by the caller's layer)
--   Desktop  the tip under the crosshair while the pointer is on a free slot
--   Touch    the tip over a "Set down" button (>= 44 px) on the right edge, clear of the jump / interact circle
--   Gamepad  the same button as a chip naming Y (pressing Y does it)
function CenterTable.Ui(state: State): Frame
	const host = state.Host
	local function device(): string
		return host.Device()
	end
	return create("Frame")({
		Name = "CenterTablePut",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		-- Desktop hover tip
		CartoonPanel({
			Name = "MouseTip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 36),
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			Tone = Theme.Tone.Ink,
			Outline = Theme.Outline.Normal,
			Lip = 3,
			Padding = { Left = 10, Right = 10 },
			Visible = function()
				return device() == "KeyboardMouse" and state.Near() and state.Hover() ~= nil
			end,
			Children = {
				CartoonLabel({
					Box = UDim2.new(0, 0, 1, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					TextSize = 16,
					Text = function()
						return tipText(state, TEXT.Mouse)
					end,
				}),
			},
		}),

		-- Touch / gamepad: tip + button on the right edge
		create("Frame")({
			Name = "PutSide",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.42, 0),
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Visible = function()
				return device() ~= "KeyboardMouse" and state.Near()
			end,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			CartoonPanel({
				Name = "Tip",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Ink,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 8, Right = 8 },
				Visible = function()
					return device() == "Touch"
				end,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = 14,
						Text = function()
							return tipText(state, TEXT.Touch)
						end,
					}),
				},
			}),
			CartoonButton({
				Name = "SetDown",
				LayoutOrder = 2,
				Text = function()
					return if device() == "Gamepad" then TEXT.PadKey else TEXT.Pad
				end,
				TextSize = 18,
				Size = UDim2.fromOffset(0, math.max(Theme.MinTouch, 52)),
				AutomaticSize = Enum.AutomaticSize.X,
				Selectable = false,
				OnActivated = function()
					CenterTable.Put(state, Vide.untrack(state.Pick))
				end,
			}),
		}),
	})
end

return table.freeze(CenterTable)
