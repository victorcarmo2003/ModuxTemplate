--!strict
-- World/Belt: the own plate on the restaurant conveyor and the camera poses of the belt focus (TASK-518; tech/prep-conveyor.md §3,
-- MAP-01-r4 §16.5, §16.6; DEC-302, DEC-303 Q-379 A / Q-380 A). Client only: no Modux, no Vide, no network. The PrepController owns
-- the state (which stop, the prediction) and calls this module to SHOW it:
--   Anchor(name)          a named anchor of the two-level bench (Content.Prep.Conveyor.Binding: Mount_Belt, Stop_n, WaitL_n,
--                         WaitR_n, CamAnchor_* / Focus_*), searched under the bench that holds the belt mount, cached
--   Pose(view)            the camera pose of a Conveyor.Views row: CFrame.lookAt(CamAnchor, Focus), its Fov (an anchor attribute
--                         `Fov` wins), widened on screens narrower than 16:9 so the whole bench stays in frame (§16.6)
--   StopView(stop)        the view key of a stop (Rest, Board, Toppings), nil for Out
--   Predict(from, dir, others)   the server rule of the arrows (§3.3) as a prediction: one stop, a busy reservable stop =
--                         wait beside it on the side the plate came from. The truth is always the PrepSeats record
--   ShowPlate / HidePlate the own plate prop on the lower deck, gliding between the stops in PLATE_TRAVEL s (<= 0.4 s), with the
--                         "Waiting" chip over it while it waits beside a busy stop
--   PlateFrame()          where the own plate is drawn now (the Board / Toppings stages put the bun on it, TASK-520)
-- The other cooks' plates are World/BeltMates (TASK-519), not here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Poses = require(script.Parent.Parent.Poses)

export type Dir = "Left" | "Right"

-- Where a plate is on the belt: Stop 1..#Conveyor.Stops (0 = not on the belt), Wait 0 = on the stop, 1 = waiting on its left
-- (WaitL_n, east), 2 = on its right (WaitR_n, west). Same meaning as PrepSeats.Stop / Wait.
export type Place = { Stop: number, Wait: number }

const conveyor = Content.Prep.Conveyor
const binding = conveyor.Binding
const fovAttribute = Content.Prep.Rules.World.Attr.Fov

-- s the plate takes from one stop to the next (TASK-518 acceptance: it reaches the stop in <= 0.4 s)
const PLATE_TRAVEL = 0.3
-- §16.6: the wide view is framed for 16:9 (tan(half width) = tan(35 deg) x 1.78 = 1.245); below this aspect the vertical Fov grows
const FRAMED_ASPECT = 16 / 9
const NARROW_ASPECT = 1.7
const MAX_FOV = 100
-- studs beside a stop where a waiting plate stands when the map has no WaitL_n / WaitR_n (MAP-01-r4 §16.5 a: +- 2.1)
const WAIT_OFFSET = 2.1
-- the placeholder plate (AST-162 stand-in): a flat disc, Cream like the kit plates
const PLATE_DIAMETER = 1.8
const PLATE_THICK = 0.12
const PLATE_LIFT = 0.08 -- studs over the anchor (the anchor sits on the belt)
const CHIP_TEXT = 16 -- px (>= 14 on the smallest screen)

const Belt = {}

-- Anchors ------------------------------------------------------------------------------------------------------------------------

local benchRoot: Instance? = nil
const cache: { [string]: Instance } = {}

local function frameOf(instance: Instance?): CFrame?
	if instance == nil then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.CFrame
	elseif instance:IsA("Attachment") then
		return instance.WorldCFrame
	elseif instance:IsA("Model") then
		return instance:GetPivot()
	end
	return nil
end

-- The bench the anchors hang on: the parent of the belt mount (BENCH2), or the camera anchor's when the mount is missing.
local function root(): Instance?
	const current = benchRoot
	if current ~= nil and current:IsDescendantOf(workspace) then
		return current
	end
	benchRoot = nil
	table.clear(cache)
	const mount = workspace:FindFirstChild(binding.Model, true) or workspace:FindFirstChild(binding.Camera, true)
	if mount == nil then
		return nil
	end
	const parent = mount.Parent
	-- an Attachment hangs on a part: go up to the Model that holds the bench
	local node: Instance = if parent ~= nil and parent ~= workspace then parent else mount
	while node:IsA("BasePart") and node.Parent ~= nil and node.Parent ~= workspace do
		node = node.Parent :: Instance
	end
	benchRoot = node
	return node
end

-- Is the conveyor bench in the place (streamed in)?
function Belt.Present(): boolean
	return root() ~= nil
end

-- A named anchor of the bench (nil when the map does not have it yet).
function Belt.Anchor(name: string): Instance?
	const hit = cache[name]
	if hit ~= nil and hit:IsDescendantOf(workspace) then
		return hit
	end
	cache[name] = nil
	const base = root()
	if base == nil then
		return nil
	end
	local found = base:FindFirstChild(name, true)
	if found == nil then
		const above = base.Parent
		if above ~= nil and above ~= workspace then
			found = above:FindFirstChild(name, true)
		end
	end
	if found ~= nil then
		cache[name] = found
	end
	return found
end

-- Views ---------------------------------------------------------------------------------------------------------------------------

-- The Fov that keeps the 16:9 framing of a view on a narrower screen (4:3 tablets): the horizontal half-angle is kept, so the west end
-- of the belt stays in frame (§16.6). Wider screens keep the authored Fov.
function Belt.FitFov(fov: number): number
	const camera = workspace.CurrentCamera
	if camera == nil then
		return fov
	end
	const size = camera.ViewportSize
	if size.Y <= 0 or size.X <= 0 then
		return fov
	end
	const aspect = size.X / size.Y
	if aspect >= NARROW_ASPECT then
		return fov
	end
	const half = math.tan(math.rad(fov) / 2) * FRAMED_ASPECT
	return math.clamp(math.deg(2 * math.atan(half / aspect)), fov, MAX_FOV)
end

-- The camera pose of a Conveyor.Views row ("Belt", "Rest", "Board", "Toppings", "Grill"); nil when its anchor is missing.
function Belt.Pose(key: string): Poses.Pose?
	const row = conveyor.Views.ByKey[key]
	if row == nil then
		return nil
	end
	const anchor = Belt.Anchor(row.Anchor)
	const frame = frameOf(anchor)
	if anchor == nil or frame == nil then
		return nil
	end
	const focusFrame = frameOf(Belt.Anchor(row.Focus))
	const focus = if focusFrame ~= nil then focusFrame.Position else frame.Position + frame.LookVector * 5
	-- MAP-01-r4 §16.5 c: the rotation of each camera is CFrame.lookAt(CamAnchor, Focus)
	const eye = if (focus - frame.Position).Magnitude > 1e-3 then CFrame.lookAt(frame.Position, focus) else frame
	local fov = if row.Fov > 0 then row.Fov else Content.Prep.Rules.Camera.Fov
	const attribute = anchor:GetAttribute(fovAttribute)
	if type(attribute) == "number" and attribute > 0 then
		fov = attribute
	end
	return { Frame = eye, Focus = focus, Fov = Belt.FitFov(fov), Source = "Anchor" }
end

-- The close view of a stop (Views row with Stop = stop), nil when the stop has none (Out).
function Belt.StopView(stop: number): string?
	if stop <= 0 then
		return nil
	end
	for _, row in conveyor.Views.List do
		if row.Stop == stop then
			return row.Key
		end
	end
	return nil
end

-- The Conveyor.Stops key of a stop ("Grill", "Board", "Toppings", "Out"), "" when out of range.
function Belt.StopKey(stop: number): string
	const row = conveyor.Stops.List[stop]
	return if row ~= nil then row.Key else ""
end

-- The wire tab of a stop (PrepSeats.Step there), nil when out of range.
function Belt.StopTab(stop: number): string?
	const row = conveyor.Stops.List[stop]
	return if row ~= nil then row.Tab else nil
end

-- Prediction --------------------------------------------------------------------------------------------------------------------

-- The place the server will give the own plate for an arrow (prep-conveyor.md §3.3): one stop toward the grill (Left) or toward Out
-- (Right); nil at the ends (the server answers Invalid and nothing moves). A reservable stop taken by another plate (on it, Wait 0)
-- leaves the plate waiting beside it, on the side it came from (Right -> 1 = left of it, Left -> 2 = right of it).
function Belt.Predict(from: Place, dir: Dir, others: { Place }): Place?
	const stops = conveyor.Stops.List
	if from.Stop < 1 or from.Stop > #stops then
		return nil
	end
	const target = from.Stop + (if dir == "Left" then -1 else 1)
	if target < 1 or target > #stops then
		return nil
	end
	local busy = false
	if stops[target].Reserve then
		for _, other in others do
			if other.Stop == target and other.Wait == 0 then
				busy = true
				break
			end
		end
	end
	return { Stop = target, Wait = if not busy then 0 elseif dir == "Right" then 1 else 2 }
end

-- The plate prop -------------------------------------------------------------------------------------------------------------------

type Prop = {
	Part: Part,
	Chip: BillboardGui,
	Tag: BillboardGui,
	Ticket: TextLabel,
	Tween: Tween?,
	Place: Place?,
	ArriveAt: number,
}

local prop: Prop? = nil

-- World point of a place: the Stop_n anchor, or WaitL_n / WaitR_n beside it (the offset along the belt when the map lacks them).
function Belt.PointOf(place: Place): CFrame?
	const stopFrame = frameOf(Belt.Anchor(string.format(binding.Stop, place.Stop)))
	if stopFrame == nil then
		return nil
	end
	const at = CFrame.new(stopFrame.Position)
	if place.Wait == 0 then
		return at
	end
	const name = if place.Wait == 1 then binding.WaitLeft else binding.WaitRight
	const waitFrame = frameOf(Belt.Anchor(string.format(name, place.Stop)))
	if waitFrame ~= nil then
		return CFrame.new(waitFrame.Position)
	end
	-- left of the cook = toward stop 1 (the grill end, east on MAP-01)
	const first = frameOf(Belt.Anchor(string.format(binding.Stop, 1)))
	const last = frameOf(Belt.Anchor(string.format(binding.Stop, #conveyor.Stops.List)))
	local left = Vector3.xAxis
	if first ~= nil and last ~= nil and (first.Position - last.Position).Magnitude > 1e-3 then
		left = (first.Position - last.Position).Unit
	end
	return at + left * (if place.Wait == 1 then WAIT_OFFSET else -WAIT_OFFSET)
end

local function label(parent: Instance, name: string, text: string, color: Color3, back: Color3): TextLabel
	const value = Instance.new("TextLabel")
	value.Name = name
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = UDim2.fromScale(0.5, 0.5)
	value.Size = UDim2.fromScale(1, 1)
	value.BackgroundColor3 = back
	value.BackgroundTransparency = 0
	value.BorderSizePixel = 0
	value.FontFace = Theme.Font.Body
	value.TextSize = CHIP_TEXT
	value.TextColor3 = color
	value.Text = text
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = value
	const stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Ink
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = value
	value.Parent = parent
	return value
end

local function build(): Prop?
	const camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	const part = Instance.new("Part")
	part.Name = "PrepBeltPlate"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(PLATE_THICK, PLATE_DIAMETER, PLATE_DIAMETER)
	part.Color = Theme.Color.Cream
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = camera
	-- the chip over the plate: "Waiting" while it waits beside a busy stop (BELT_UI_WAIT); the ticket #n under it
	const chip = Instance.new("BillboardGui")
	chip.Name = "BeltChip"
	chip.Size = UDim2.fromOffset(112, 30)
	chip.StudsOffsetWorldSpace = Vector3.new(0, 1.1, 0)
	chip.AlwaysOnTop = true
	chip.LightInfluence = 0
	chip.ResetOnSpawn = false
	chip.Enabled = false
	chip.Adornee = part
	chip.Parent = part
	label(chip, "Wait", Content.Prep.Texts.BeltWait, Theme.Color.Ink, Theme.Color.Mustard)
	const tag = Instance.new("BillboardGui")
	tag.Name = "BeltTicket"
	tag.Size = UDim2.fromOffset(56, 26)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 0.45, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.ResetOnSpawn = false
	tag.Enabled = false
	tag.Adornee = part
	tag.Parent = part
	const ticket = label(tag, "Ticket", "", Theme.Color.Ink, Theme.Color.Cream)
	return { Part = part, Chip = chip, Tag = tag, Ticket = ticket, Tween = nil, Place = nil, ArriveAt = 0 }
end

local function lay(frame: CFrame): CFrame
	-- a Cylinder runs along its X axis: stand it up so the disc lies on the belt
	return frame * CFrame.new(0, PLATE_LIFT, 0) * CFrame.Angles(0, 0, math.rad(90))
end

-- Shows the own plate at `place` (gliding there unless `instant` or reduced motion). `ticket` = the #n on its tag (0 = none).
-- Returns the s it takes to get there (0 when it is already there or jumps). Nothing is drawn when the map has no Stop_n.
function Belt.ShowPlate(place: Place, ticket: number, instant: boolean): number
	const target = Belt.PointOf(place)
	if target == nil then
		Belt.HidePlate()
		return 0
	end
	local current = prop
	if current == nil or current.Part.Parent == nil then
		current = build()
		prop = current
		instant = true
	end
	if current == nil then
		return 0
	end
	current.Chip.Enabled = place.Wait ~= 0
	current.Ticket.Text = if ticket > 0 then `#{ticket}` else ""
	current.Tag.Enabled = ticket > 0
	const previous = current.Place
	current.Place = { Stop = place.Stop, Wait = place.Wait }
	if previous ~= nil and previous.Stop == place.Stop and previous.Wait == place.Wait and current.Tween == nil then
		return 0
	end
	if current.Tween ~= nil then
		current.Tween:Cancel()
		current.Tween = nil
	end
	const goal = lay(target)
	if instant then
		current.Part.CFrame = goal
		current.ArriveAt = os.clock()
		return 0
	end
	const tween = TweenService:Create(current.Part, TweenInfo.new(PLATE_TRAVEL, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = goal,
	})
	current.Tween = tween
	const owner: Prop = current
	tween.Completed:Once(function()
		if owner.Tween == tween then
			owner.Tween = nil
		end
	end)
	tween:Play()
	current.ArriveAt = os.clock() + PLATE_TRAVEL
	return PLATE_TRAVEL
end

-- The plate is still gliding.
function Belt.Moving(): boolean
	const current = prop
	return current ~= nil and current.Tween ~= nil
end

-- Where the own plate is drawn now (nil when it is not drawn).
function Belt.PlateFrame(): CFrame?
	const current = prop
	if current == nil or current.Part.Parent == nil then
		return nil
	end
	return current.Part.CFrame * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -PLATE_LIFT, 0)
end

-- The own plate leaves the screen (the focus ended).
function Belt.HidePlate()
	const current = prop
	prop = nil
	if current == nil then
		return
	end
	if current.Tween ~= nil then
		current.Tween:Cancel()
	end
	current.Part:Destroy()
end

-- A press at an end of the belt: the plate nudges toward the arrow and comes back (nothing is sent).
function Belt.Nudge(dir: Dir)
	const found = prop
	if found == nil or found.Tween ~= nil or found.Place == nil then
		return
	end
	const current: Prop = found
	const home = current.Part.CFrame
	const first = frameOf(Belt.Anchor(string.format(binding.Stop, 1)))
	const last = frameOf(Belt.Anchor(string.format(binding.Stop, #conveyor.Stops.List)))
	if first == nil or last == nil or (first.Position - last.Position).Magnitude < 1e-3 then
		return
	end
	const left = (first.Position - last.Position).Unit
	const push = if dir == "Left" then left * 0.25 else -left * 0.25
	const out = TweenService:Create(current.Part, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = home + push,
	})
	current.Tween = out
	out.Completed:Once(function()
		if current.Tween ~= out or current.Part.Parent == nil then
			return
		end
		const back = TweenService:Create(current.Part, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = home,
		})
		current.Tween = back
		back.Completed:Once(function()
			if current.Tween == back then
				current.Tween = nil
			end
		end)
		back:Play()
	end)
	out:Play()
end

return Belt
