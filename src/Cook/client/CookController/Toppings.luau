--!strict
-- Condiment table of the cooking focus (kitchen-focus.md §1 #4). The hot dog in hand (on its dish) sits in the middle of the table,
-- turned so the bun runs left to right on screen; the pans of the order are lit by PlateController.
--   tap a pan                  selects that condiment (a white outline)
--   sauce (ketchup, mustard, cream cheese): on the hot dog (TASK-594; owner 2026-10-19: "tudo 3D", no 2D board): the guide is a
--                              row of 2D Mustard arrows (owner 2026-10-22: UI, the tutorial's arrows; Components/SauceGuide) put
--                              each frame through the S's points on the sausage, so they bend with it; the paw coaches without its
--                              own 3D trail; a see-through squeeze bottle rides the pointer and empties as the line
--                              grows (it holds about 1.6 times the pattern); the line is drawn on the hot dog itself. Release =
--                              Cook Topping with the drawn line (it stays on the hot dog: HotDogVisual.Sauce) and Gestures.Trace ->
--                              Grade.Score. The focus bar fills with the share of the pattern covered so far. Until the player
--                              learns it, the paw traces the S over the bun
--   cheese, bacon, potato sticks: the piece follows the pointer; press / release on the bun = Cook Topping, scored by how close to
--                              the middle of the bun it landed (Gestures.Place)
-- The prop sits the bun (and the dish under it) a little lower than the kit (TASK-594, owner 2026-10-19: the bun hid the
-- sauces); the bun space (and the grade) stays the kit's. The dish's size and drop come from KitchenService attachDish.
-- With a condiment in hand, a press on the hot dog draws / drops there even when a pan's hitbox reaches over it (owner 2026-10-19:
-- "não tá detectando que estou pressionando no cachorro quente").
-- The step ends when every topping of the order is on (an order not known = never by itself).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)
local Grade = require(ReplicatedStorage.shared.Prep.Grade)
local HotDogVisual = require(ReplicatedStorage.shared.Item.HotDogVisual)
local Sauce = HotDogVisual.Sauce
local Gestures = require(script.Parent.Gestures)
local Kit = require(script.Parent.Kit)
local Session = require(script.Parent.Session)
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SauceGuide = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.SauceGuide)

const BUILD = Content.Prep.Build
const BUN_LENGTH = 0.85 -- HotDogVisual: share of the Handle's long side the bun space covers
const BUN_WIDTH = 0.7
-- owner 2026-10-19: the hot dog on the condiment table is drawn twice the kit size
const PROP_SCALE = 2
-- TASK-594 (Provisional, judged in Play): kit studs the bun drops under the sausage (the dish goes down with it)
const BUN_DROP = 0.08
-- owner 2026-10-19 ("a salsicha tá muito pra cima"): studs the hot dog sits toward the camera from the table's middle, so it shows
-- low on the screen, clear of the pans behind it (capped to stay on the table)
const PROP_FORWARD = 0.65
const TABLE_EDGE = 0.45 -- studs it keeps from the table's front edge
const INK_SHARE = 1.6 -- the bottle holds this many times the pattern's length
const SQUIRT_EVERY = 0.22 -- s between two squirt sounds while drawing
const STEP = 0.015 -- bun-space distance (x scaled by the aspect) between two points of the line
const SLACK = 0.3 -- share of the bun around it where a press starts a line / the bottle shows
-- the line and the guide, shares of the bun length (HotDogVisual draws its beads at 0.05 too)
const BEAD = 0.05
-- the guide (owner 2026-10-19: the chevron chain looked like a centipede, then "a gente pode retirar" the arrowheads): one soft
-- Cream line along the S and a Mustard start dot (Theme colours), shares of the bun length
-- owner 2026-10-22 ("em vez dessa linha em 3D... em 2D, como UI, que vai se curvar junto com a salsicha"; "tá muito pra cima"):
-- px at 720 p (scaled by the viewport height), see-through share, Ink outline px, points per stretch of the S, and the lift
-- over the sausage in beads (it was 1.2: the far half of the S stood out over the sausage's top edge)
const GUIDE_SPACING = 21 -- owner 2026-10-22 (UI Labs): px between two arrows at 720 p (scaled by the viewport height)
const GUIDE_SIZE = 18 -- px of an arrow at 720 p
const GUIDE_STEPS = 6
const GUIDE_LIFT = 1.25 -- owner 2026-10-22 (UI Labs SauceGuide story)
-- the hot dog proper: a pan under the pointer outside this still (re)selects (a wider margin swallowed the pans next to the bun)
const OVER_BUN = { X = 0.02, Y = 0.1 }
-- the touch reach of a sauce (TASK-594, owner 2026-10-19: "tá muito ruim de posicionar... a parte final da salsicha... pras crianças
-- que vão mexer em tablets, tem que ser fácil"): a press within this many px of the sausage's line on screen (ends included) starts
-- the line, and while drawing the pointer is held on the sausage (x and y clamped) instead of letting go. Px at 720 p, scaled by the
-- viewport height; never less than REACH_MIN. Provisional, judged in Play
const REACH = 110
const REACH_MIN = 64
const CLAMP_X = { -0.04, 1.04 } -- bun-space x the drawn line may reach (the sausage runs a little past the bun space)
const PICK_COLOR = Color3.fromHex("#FFFFFF")
-- the server writes Toppings / Sauce first and rebuilds the ToppingVisual after it, so the attribute can reach this client before
-- the new visual does (the prop drew a bare bun for the last second, owner 2026-10-22): the prop waits for the visual this long
const PAINT_WAIT = 0.6
-- the squeeze bottle, studs at the prop's size: nozzle, cap, see-through body; it leans a little to the screen's right
const BOTTLE = { Nozzle = 0.14, Cap = 0.1, Body = 0.62, Width = 0.26, Lean = 0.3 }
const BOTTLE_GLASS = Color3.fromHex("#F4F1EA")
const TRACE: { [string]: boolean } = {}
for _, row in Content.Prep.Tolerances.List do
	if row.Gesture == "trace" then
		TRACE[row.Key] = true
	end
end

-- Axis / Radius: the sausage (world, at the middle of the bun); the bun space wraps around it (HotDogVisual.around) so the guide,
-- the live line and the sauce left on the hot dog all hug the sausage (owner 2026-10-19: "a linha não tá alinhada com a salsicha")
type Space = { Origin: Vector3, Along: Vector3, Across: Vector3, Length: number, Width: number, Axis: Vector3, Radius: number }
type Bottle = { Model: Model, Liquid: Part, Pieces: { { Part: Part, From: number, Length: number } } }

-- Length of the pattern in the bun space (x scaled by the aspect)
local function pathLength(): number
	local total = 0
	const path = BUILD.Sauce.Path
	for index = 2, #path do
		const a, b = path[index - 1], path[index]
		total += Vector2.new((b.X - a.X) * BUILD.Aspect, b.Y - a.Y).Magnitude
	end
	return total
end

const Toppings = {}

-- The replicated ToppingVisual of the hot dog in hand already shows what its attributes say (every topping, each drawn sauce as
-- its line)
local function painted(tool: Tool): boolean
	const keys = HotDogVisual.parse(tool:GetAttribute("Toppings") :: string?)
	const visual = tool:FindFirstChild(HotDogVisual.VisualName)
	if visual == nil then
		return #keys == 0
	end
	const shown: { [string]: boolean } = {}
	for _, child in visual:GetChildren() do
		const key = child:GetAttribute("Ingredient")
		if type(key) == "string" then
			shown[key] = true
		end
	end
	for _, key in keys do
		if not shown[key] then
			return false
		end
	end
	for key in Sauce.Decode(tool:GetAttribute(Sauce.Attribute)) do
		if table.find(keys, key) ~= nil and visual:FindFirstChild(`Sauce_{key}`) == nil then
			return false
		end
	end
	return true
end

local function toppingModel(key: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const kit = if items then items:FindFirstChild("Toppings") else nil
	const template = if kit then kit:FindFirstChild(key) else nil
	if template == nil or not template:IsA("Model") then
		return nil
	end
	const copy = template:Clone()
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return copy
end

local function cylinder(parent: Instance, name: string, color: Color3, transparency: number, width: number): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(0.1, width, width)
	part.Parent = parent
	return part
end

-- The squeeze bottle, nozzle down: the liquid sits on the nozzle side and shortens as the ink runs out
local function makeBottle(color: Color3): Bottle
	const model = Instance.new("Model")
	model.Name = "SqueezeBottle"
	const body = cylinder(model, "Body", BOTTLE_GLASS, 0.55, BOTTLE.Width)
	const liquid = cylinder(model, "Liquid", color, 0.1, BOTTLE.Width * 0.84)
	const cap = cylinder(model, "Cap", color:Lerp(Color3.new(0, 0, 0), 0.25), 0, BOTTLE.Width * 0.7)
	const nozzle = cylinder(model, "Nozzle", color:Lerp(Color3.new(0, 0, 0), 0.25), 0, BOTTLE.Width * 0.18)
	return {
		Model = model,
		Liquid = liquid,
		Pieces = {
			{ Part = nozzle, From = 0, Length = BOTTLE.Nozzle },
			{ Part = cap, From = BOTTLE.Nozzle, Length = BOTTLE.Cap },
			{ Part = body, From = BOTTLE.Nozzle + BOTTLE.Cap, Length = BOTTLE.Body },
		},
	}
end

function Toppings.Start(session: Session.Session): Session.Handler
	const folder = session.Folder
	const up = Vector3.yAxis
	const right = session.Right
	const lean = (up + right * BOTTLE.Lean).Unit

	-- the pans of the table
	const pans: { Instance } = {}
	for _, child in session.Target:GetDescendants() do
		if child:IsA("Model") and type(child:GetAttribute("Topping")) == "string" then
			table.insert(pans, child)
		end
	end
	if #pans == 0 and type(session.Target:GetAttribute("Topping")) == "string" then
		table.insert(pans, session.Target)
	end

	const propFolder = Instance.new("Folder")
	propFolder.Name = "HotDog"
	propFolder.Parent = folder
	const inkFolder = Instance.new("Folder")
	inkFolder.Name = "Ink"
	inkFolder.Parent = folder
	-- the 2D guide: one ScreenGui of the focus with the arrows (SauceGuide), the S's points on screen written every frame (Step)
	const guidePoints = Vide.source({} :: { Vector2 })
	const guideScale = Vide.source(1)
	const guidePath = SauceGuide.Dense(BUILD.Sauce.Path, GUIDE_STEPS)
	const unmountGuide, guide = Vide.root(function()
		return Vide.create("ScreenGui")({
			Name = "CookSauceGuide",
			IgnoreGuiInset = true, -- WorldToViewportPoint coordinates
			ResetOnSpawn = false,
			DisplayOrder = 1,
			Enabled = false,
			SauceGuide.Component({
				Points = guidePoints,
				Spacing = function(): number
					return GUIDE_SPACING * guideScale()
				end,
				Size = function(): number
					return GUIDE_SIZE * guideScale()
				end,
			}),
		})
	end)
	guide.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local space: Space? = nil
	local shown = ""
	-- the signature the prop waits to draw (its visual still on the way) and since when
	local waiting = ""
	local waitSince = 0
	local selected: string? = nil
	local pick: Highlight? = nil
	local ghost: Model? = nil
	local bottle: Bottle? = nil
	-- the line of the sauce in hand: one piece per stretch on the hot dog (owner 2026-10-20: a slip off the bun and back, still
	-- pressed, goes on in the same line; the pieces are not joined across the slip)
	local pieces: { { Gestures.Point } } = {}
	local points = 0 -- points over all the pieces
	local last: Vector3? = nil
	local drawing = false
	local justSelected = false
	-- the pointer left the hot dog mid-squeeze: paused (no ink, no points); back on it a fresh piece starts there
	local gap = false
	local finished = false
	local ink = 1 -- share of the bottle left
	local squirtAt = 0 -- os.clock() of the last squirt sound
	const inkTotal = pathLength() * INK_SHARE

	-- width of the drawn line in studs (the same bead HotDogVisual keeps on the hot dog)
	local function bead(): number
		const current = space
		return if current then math.max(current.Length * BEAD, 0.04 * PROP_SCALE) else 0.08
	end

	-- the hot dog in hand as a local model in the middle of the table, the bun running along the screen's right
	local function drawProp(tool: Tool)
		propFolder:ClearAllChildren()
		space = nil
		const model = Kit.FromTool(tool)
		if model == nil then
			return
		end
		const handle = model.PrimaryPart :: BasePart
		-- the top of the stack rides the sausage, so it stays where the kit puts it when the bun drops
		const anchor = handle:FindFirstChild("Att_Topping1")
		const sausage = model:FindFirstChild("Sausage")
		local top: Attachment? = nil
		if sausage ~= nil and sausage:IsA("BasePart") then
			const mark = Instance.new("Attachment")
			mark.Name = "PropTop"
			mark.Parent = sausage
			mark.WorldPosition = if anchor ~= nil and anchor:IsA("Attachment")
				then anchor.WorldPosition
				else handle.Position + handle.CFrame.UpVector * (handle.Size.Y / 2)
			top = mark
			-- TASK-594: the bun a little lower, the sauces on the sausage show over its halves
			handle.CFrame += handle.CFrame.UpVector * -BUN_DROP
		end
		-- the dish (already at the bun's size and a little under it: KitchenService attachDish, TASK-594) follows the bun down
		const dish = model:FindFirstChild("Dish")
		const base = if dish ~= nil then dish:FindFirstChild("DishBase") else nil
		if dish ~= nil and dish:IsA("Model") and base ~= nil and base:IsA("BasePart") and top ~= nil then
			-- owner 2026-10-22 ("o pão tá flutuando, alinha com o Y do prato"): the bun sits on the dish's base (its top face, in
			-- its own frame), centred over it; the whole prop then stands on the table by its lowest point (the dish)
			const bunUp = handle.CFrame.UpVector
			const bunBottom = handle.Position - bunUp * (handle.Size.Y / 2)
			const baseTop = base.Position + base.CFrame.UpVector * (base.Size.Y / 2)
			const flat = handle.Position - base.Position
			const centre = flat - bunUp * flat:Dot(bunUp)
			dish:PivotTo(dish:GetPivot() + bunUp * (bunBottom - baseTop):Dot(bunUp) + centre)
		elseif dish ~= nil and dish:IsA("Model") and top ~= nil then
			dish:PivotTo(dish:GetPivot() + handle.CFrame.UpVector * -BUN_DROP)
		end
		const kitRadius = HotDogVisual.radiusOf(model)
		model:ScaleTo(PROP_SCALE)
		const alongLocal = if handle.Size.X >= handle.Size.Z then Vector3.xAxis else Vector3.zAxis
		const handleFrame = if alongLocal == Vector3.xAxis
			then CFrame.fromMatrix(session.Top, right, up)
			else CFrame.fromMatrix(session.Top, up:Cross(right), up)
		model:PivotTo(handleFrame * handle.CFrame:ToObjectSpace(model:GetPivot()))
		const box, size = model:GetBoundingBox()
		-- toward the camera, low on the screen, still on the table
		const depth = math.abs(session.Size:Dot(session.Toward))
		const forward = math.clamp(math.min(PROP_FORWARD, depth / 2 - TABLE_EDGE - size.Z / 2), 0, PROP_FORWARD)
		const spot = session.Top + session.Toward * forward
		model:PivotTo(model:GetPivot() + Vector3.new(spot.X - box.Position.X, spot.Y - (box.Position.Y - size.Y / 2), spot.Z - box.Position.Z))
		model.Parent = propFolder
		const acrossLocal = if alongLocal == Vector3.xAxis then Vector3.zAxis else Vector3.xAxis
		const origin = if top ~= nil
			then top.WorldPosition
			elseif anchor ~= nil and anchor:IsA("Attachment") then anchor.WorldPosition
			else handle.Position + up * (handle.Size.Y / 2)
		const radius = (kitRadius or math.abs(handle.Size:Dot(acrossLocal)) * BUN_WIDTH / 2) * PROP_SCALE
		space = {
			Origin = origin,
			Along = handle.CFrame:VectorToWorldSpace(alongLocal),
			Across = handle.CFrame:VectorToWorldSpace(acrossLocal),
			Length = math.abs(handle.Size:Dot(alongLocal)) * BUN_LENGTH,
			Width = math.abs(handle.Size:Dot(acrossLocal)) * BUN_WIDTH,
			Axis = origin - up * radius,
			Radius = radius,
		}
	end

	local function bunPoint(position: Vector2): (number?, number?, Vector3?)
		const current = space
		if current == nil then
			return nil, nil, nil
		end
		const camera = workspace.CurrentCamera
		if camera == nil then
			return nil, nil, nil
		end
		-- the pointer's ray against the sausage (a cylinder a bead over it); a miss = the ray's closest pass to its axis
		const ray = camera:ScreenPointToRay(position.X, position.Y)
		const along = current.Along
		const from = ray.Origin - current.Axis
		const flatFrom = from - along * from:Dot(along)
		const flatDirection = ray.Direction - along * ray.Direction:Dot(along)
		const a = flatDirection:Dot(flatDirection)
		if a < 1e-6 then
			return nil, nil, nil
		end
		const reach = current.Radius + bead() * 0.5
		const b = flatFrom:Dot(flatDirection)
		const c = flatFrom:Dot(flatFrom) - reach * reach
		const discriminant = b * b - a * c
		const t = if discriminant >= 0 then (-b - math.sqrt(discriminant)) / a else -b / a
		if t < 0 then
			return nil, nil, nil
		end
		const world = ray.Origin + ray.Direction * t
		const offset = world - current.Axis
		local y = HotDogVisual.acrossOf(offset:Dot(up), offset:Dot(current.Across))
		if discriminant < 0 then
			-- off the sausage: past its edge by how far the ray passes from it (one radius = one share)
			const miss = ((flatFrom + flatDirection * t).Magnitude - reach) / reach
			y = if y >= 0.5 then math.max(y, 1 + miss) else math.min(y, -miss)
		end
		return offset:Dot(along) / current.Length + 0.5, y, world
	end

	local function worldOf(x: number, y: number, lift: number): Vector3?
		const current = space
		if current == nil then
			return nil
		end
		return current.Axis + current.Along * ((x - 0.5) * current.Length) + HotDogVisual.around(up, current.Across, y) * (current.Radius + lift)
	end

	-- the press is on the hot dog itself: it draws / drops there even when a pan's hitbox reaches over it
	local function overBun(x: number?, y: number?): boolean
		return x ~= nil and y ~= nil and x > -OVER_BUN.X and x < 1 + OVER_BUN.X and y > -OVER_BUN.Y and y < 1 + OVER_BUN.Y
	end

	-- the pan whose mouth is under the pointer: the plane of its top inside its footprint (the pans reach down under the counter;
	-- a ray only against them went through the counter and took the pan behind the hot dog)
	const panBoxes: { { Pan: Instance, Top: Vector3, Size: Vector3 } } = {}
	for _, pan in pans do
		const top, size = Kit.Bounds(pan)
		table.insert(panBoxes, { Pan = pan, Top = top, Size = size })
	end
	local function panAt(position: Vector2): Instance?
		for _, box in panBoxes do
			const world = Kit.OnPlane(position, box.Top, up)
			if world ~= nil and math.abs(world.X - box.Top.X) <= box.Size.X / 2 and math.abs(world.Z - box.Top.Z) <= box.Size.Z / 2 then
				return box.Pan
			end
		end
		return nil
	end

	-- the pointer is within the touch reach of the sausage's line on screen (generous for fingers and tablets)
	local function inReach(position: Vector2): boolean
		const camera = workspace.CurrentCamera
		const a = worldOf(CLAMP_X[1], 0.5, 0)
		const b = worldOf(CLAMP_X[2], 0.5, 0)
		if camera == nil or a == nil or b == nil then
			return false
		end
		const screenA, frontA = camera:WorldToScreenPoint(a)
		const screenB, frontB = camera:WorldToScreenPoint(b)
		if not frontA and not frontB then
			return false
		end
		const from = Vector2.new(screenA.X, screenA.Y)
		const span = Vector2.new(screenB.X, screenB.Y) - from
		const share = if span:Dot(span) > 1e-6 then math.clamp((position - from):Dot(span) / span:Dot(span), 0, 1) else 0
		const reach = math.max(REACH * camera.ViewportSize.Y / 720, REACH_MIN)
		return (position - (from + span * share)).Magnitude <= reach
	end

	-- the bottle with its nozzle tip on `tip` (nil hides it), the liquid as long as the ink left
	local function placeBottle(tip: Vector3?)
		const current = bottle
		if current == nil then
			return
		end
		if tip == nil then
			current.Model.Parent = nil
			return
		end
		const side = right:Cross(lean).Unit
		for _, piece in current.Pieces do
			piece.Part.Size = Vector3.new(piece.Length, piece.Part.Size.Y, piece.Part.Size.Z)
			piece.Part.CFrame = CFrame.fromMatrix(tip + lean * (piece.From + piece.Length / 2), lean, side)
		end
		const full = BOTTLE.Body - 0.04
		const length = math.max(full * ink, 0.01)
		current.Liquid.Size = Vector3.new(length, current.Liquid.Size.Y, current.Liquid.Size.Z)
		current.Liquid.CFrame = CFrame.fromMatrix(tip + lean * (BOTTLE.Nozzle + BOTTLE.Cap + 0.02 + length / 2), lean, side)
		current.Model.Parent = folder
	end

	-- the S over the sausage: a soft line and a start dot (owner 2026-10-19: no arrowheads, "vai ficar até melhor desse jeito").
	-- 2D (owner 2026-10-22): on while a sauce is in hand; placeGuide moves it every frame
	local function drawGuide()
		guide.Enabled = space ~= nil
	end

	-- the guide's points on screen this frame (the camera glides in, the hot dog may be redrawn)
	local function placeGuide()
		const camera = workspace.CurrentCamera
		if not guide.Enabled or camera == nil or space == nil then
			return
		end
		guideScale(camera.ViewportSize.Y / 720)
		const lift = bead() * GUIDE_LIFT
		const screen: { Vector2 } = {}
		for _, point in guidePath do
			const world = worldOf(point.X, point.Y, lift)
			if world ~= nil then
				const at = camera:WorldToViewportPoint(world)
				table.insert(screen, Vector2.new(at.X, at.Y))
			end
		end
		guidePoints(screen)
	end

	local function clearLine()
		inkFolder:ClearAllChildren()
		table.clear(pieces)
		points = 0
		last = nil
		drawing = false
		ink = 1
	end

	local function clearPick()
		justSelected = false
		if pick ~= nil then
			pick:Destroy()
			pick = nil
		end
		if ghost ~= nil then
			ghost:Destroy()
			ghost = nil
		end
		if bottle ~= nil then
			bottle.Model:Destroy()
			bottle = nil
		end
		guide.Enabled = false
		clearLine()
		session.Progress(nil)
		selected = nil
	end

	local function onHotDog(key: string): boolean
		const held = session.Held()
		const raw = if held then held:GetAttribute("Toppings") else nil
		return type(raw) == "string" and table.find(string.split(raw, ","), key) ~= nil
	end

	local function select(pan: Instance)
		const key = pan:GetAttribute("Topping") :: string
		clearPick()
		if onHotDog(key) then
			const row = Content.Ingredients.ByKey[key]
			session.Hint(`{if row then row.Name else key} is already on it`)
			return
		end
		selected = key
		const light = Instance.new("Highlight")
		light.Name = "CookPick"
		light.Adornee = pan
		light.FillTransparency = 1
		light.OutlineColor = PICK_COLOR
		light.DepthMode = Enum.HighlightDepthMode.Occluded
		light.Parent = folder
		pick = light
		const row = Content.Ingredients.ByKey[key]
		const name = if row then row.Name else key
		if TRACE[key] then
			-- the S line over the sausage and the squeeze bottle, all on the hot dog
			drawGuide()
			bottle = makeBottle(Sauce.ColorOf(key))
			session.Hint(`Squeeze the {name} along the line`)
		else
			ghost = toppingModel(key)
			if ghost ~= nil then
				ghost:ScaleTo(PROP_SCALE)
				ghost.Parent = folder
			end
			session.Hint(`Drop the {name} on the bun`)
		end
	end

	-- the focus bar: share of the pattern the line covers now (the same measure the grade uses)
	local function showCoverage()
		const coverage = Gestures.Trace(pieces, BUILD.Sauce.Path, BUILD.Aspect, BUILD.Sauce.Reach, BUILD.Sauce.Spill)
		session.Progress(math.clamp(coverage / 100, 0, 1))
	end

	local function commitSauce(key: string)
		const coverage, excess = Gestures.Trace(pieces, BUILD.Sauce.Path, BUILD.Aspect, BUILD.Sauce.Reach, BUILD.Sauce.Spill)
		const score = Grade.Score(Content.Prep, key, coverage, excess)
		const segments: { { Vector2 } } = {}
		for _, piece in pieces do
			if #piece < 2 then
				continue
			end
			const segment: { Vector2 } = {}
			for _, point in piece do
				table.insert(segment, Vector2.new(math.clamp(point.X, 0, 1), math.clamp(point.Y, 0, 1)))
			end
			table.insert(segments, segment)
		end
		session.Graded(score, worldOf(0.5, 0.5, 0.15))
		session.Send({ Act = "Topping", Slot = 0, Score = score, Key = key, Points = Sauce.Pack(segments) })
		session.Paw:Learned("sauce_trace")
		-- the drawn line stays until the hot dog redraws with it (the signature changes in Step)
		const kept = inkFolder:Clone()
		kept.Name = "InkSent"
		kept.Parent = folder
		task.delay(1.5, function()
			kept:Destroy()
		end)
		clearPick()
	end

	-- the pan of the order still missing on the hot dog (nil = none / order not known)
	local function nextPan(): Instance?
		const order = session.Order()
		if order == nil then
			return nil
		end
		for _, key in order do
			if not onHotDog(key) then
				for _, pan in pans do
					if pan:GetAttribute("Topping") == key then
						return pan
					end
				end
			end
		end
		return nil
	end

	-- the paw: tap the next pan, trace the S over the bun, or carry the piece to the bun
	local function coach()
		const key = selected
		if space == nil or drawing then
			session.Paw:Hide()
		elseif key == nil then
			const pan = nextPan()
			if pan ~= nil then
				session.Paw:Show("topping_pick", { (Kit.Bounds(pan)) })
			else
				session.Paw:Hide()
			end
		elseif TRACE[key] then
			const path: { Vector3 } = {}
			for _, point in BUILD.Sauce.Path do
				const at = worldOf(point.X, point.Y, bead())
				if at ~= nil then
					table.insert(path, at)
				end
			end
			session.Paw:Show("sauce_trace", path)
		else
			local from: Vector3? = nil
			for _, candidate in pans do
				if candidate:GetAttribute("Topping") == key then
					from = (Kit.Bounds(candidate))
					break
				end
			end
			const to = worldOf(0.5, 0.5, 0.05)
			if from ~= nil and to ~= nil then
				session.Paw:Show("topping_drop", { from, to })
			else
				session.Paw:Hide()
			end
		end
	end

	local function remaining(): (number, number)
		const order = session.Order()
		if order == nil then
			return -1, 0
		end
		local left = 0
		for _, key in order do
			if not onHotDog(key) then
				left += 1
			end
		end
		return left, #order
	end

	-- one pointer event of a sauce on the hot dog
	local function onSauce(kind: string, key: string, rawX: number?, rawY: number?, position: Vector2)
		const near = inReach(position)
		-- on the sausage: a pointer a little off it is held on its line (TASK-594: easy on tablets). Out of reach the squeeze
		-- pauses and picks up again when the pointer comes back (owner 2026-10-20: one slip off the dog ended the line)
		const x = if rawX ~= nil and near then math.clamp(rawX, CLAMP_X[1], CLAMP_X[2]) else rawX
		const y = if rawY ~= nil and near then math.clamp(rawY, 0, 1) else rawY
		const tipLift = bead() * 0.6
		placeBottle(if near and x ~= nil and y ~= nil then worldOf(x, y, tipLift + 0.04) else nil)
		if kind == "Down" and near then
			clearLine()
			drawing = true
			gap = false
			session.Progress(0)
			placeBottle(if x ~= nil and y ~= nil then worldOf(x, y, tipLift + 0.04) else nil)
		end
		if not drawing then
			return
		end
		if kind ~= "Up" then
			if not near then
				gap = true
				return
			end
			if x == nil or y == nil then
				return
			end
			const here = Vector2.new(x * BUILD.Aspect, y)
			-- after a pause: a new piece, no segment from the point where the pointer left
			const piece = if gap then nil else pieces[#pieces]
			const previous = if piece then piece[#piece] else nil
			const back = if previous then Vector2.new(previous.X * BUILD.Aspect, previous.Y) else nil
			if ink <= 0 or (back ~= nil and (here - back).Magnitude < STEP) or points >= BUILD.Sauce.MaxPoints then
				return
			end
			const at = worldOf(x, y, bead() * 0.35)
			if at == nil then
				return
			end
			const color = Sauce.ColorOf(key)
			if back ~= nil and last ~= nil then
				ink = math.max(ink - (here - back).Magnitude / inkTotal, 0)
				Kit.Segment(inkFolder, last, at, color, bead()).Material = Enum.Material.Plastic
			end
			Kit.Ball(inkFolder, at, color, bead(), 0).Material = Enum.Material.Plastic
			last = at
			gap = false
			if piece == nil then
				table.insert(pieces, { { X = x, Y = y } })
			else
				table.insert(piece, { X = x, Y = y })
			end
			points += 1
			showCoverage()
			-- the squeeze: a squirt now and then
			if os.clock() - squirtAt >= SQUIRT_EVERY then
				squirtAt = os.clock()
				session.Juice:Sound("topping_squirt", at)
			end
			if ink <= 0 then
				session.Hint("The bottle is empty: let go")
			end
			return
		end
		drawing = false
		session.Progress(nil)
		if points < BUILD.Sauce.MinPoints then
			clearLine()
			session.Hint("Squeeze a longer line along the line")
			return
		end
		commitSauce(key)
	end

	return {
		Pointer = function(kind: string, position: Vector2)
			if finished then
				return
			end
			if kind == "Up" and justSelected then
				justSelected = false
				return
			end
			const key = selected
			const x, y, world = bunPoint(position)
			if kind == "Down" and not drawing then
				-- right over the hot dog = the condiment in hand; else a pan's mouth (re)selects; else near the sausage = the sauce
				const pan = if key ~= nil and overBun(x, y) then nil else panAt(position)
				if pan ~= nil then
					select(pan)
					justSelected = true
					session.Paw:Learned("topping_pick")
					return
				end
				if key == nil then
					session.Hint("Tap a condiment first")
					return
				end
				if TRACE[key] and not inReach(position) then
					session.Hint("Squeeze it on the hot dog, along the line")
					return
				end
			end
			if key == nil then
				return
			end
			if TRACE[key] then
				onSauce(kind, key, x, y, position)
				return
			end
			if x == nil or y == nil or world == nil then
				return
			end
			-- a piece: it follows the pointer, the release on the bun drops it
			const model = ghost
			if model ~= nil then
				model:PivotTo(CFrame.fromMatrix(world + up * 0.08, right, up))
			end
			if kind == "Up" then
				if x < -BUILD.DropSlack or x > 1 + BUILD.DropSlack or y < -1 or y > 2 then
					return
				end
				const score = Grade.Score(Content.Prep, key, Gestures.Place(x, y, BUILD.Aspect, BUILD.Groove.X, BUILD.Groove.Y))
				session.Graded(score, world)
				session.Juice:Sound("topping_sprinkle", world)
				session.Send({ Act = "Topping", Slot = 0, Score = score, Key = key })
				session.Paw:Learned("topping_drop")
				clearPick()
			end
		end,
		Step = function(_dt: number)
			if finished then
				session.Paw:Hide()
				return
			end
			coach()
			placeGuide()
			const held = session.Held()
			if held == nil or held:GetAttribute("Item") ~= "hot_dog" then
				if shown ~= "" then
					shown = ""
					propFolder:ClearAllChildren()
					space = nil
					clearPick()
				end
				session.Hint("Bring the hot dog on its plate")
				return
			end
			const signature = `{held:GetAttribute("Toppings") or ""}|{held:GetAttribute("Sauce") or ""}`
			if signature ~= shown then
				if signature ~= waiting then
					waiting = signature
					waitSince = os.clock()
				end
				if not painted(held) and os.clock() - waitSince < PAINT_WAIT then
					return
				end
				shown = signature
				drawProp(held)
				const sent = folder:FindFirstChild("InkSent")
				if sent ~= nil then
					sent:Destroy()
				end
				if selected ~= nil and TRACE[selected] then
					drawGuide()
				end
				const left, total = remaining()
				if left == 0 then
					finished = true
					clearPick()
					session.Hint(if total == 0 then "No toppings for this one. Hand it over!" else "All done! Hand it over at the pickup")
					session.Done()
					return
				end
				if selected == nil then
					session.Hint("Tap a lit condiment, then put it on the bun")
				end
			end
		end,
		Stop = function()
			clearPick()
			unmountGuide()
			guide:Destroy()
		end,
	}
end

return table.freeze(Toppings)
