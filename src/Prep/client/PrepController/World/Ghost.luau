--!strict
-- World/Ghost: the live drag of the 3D prep co-op (DEC-259; TASK-350, the client half of TASK-349). Rules.World.Ghost.
--   Send    the views of the own hand report what it holds with Ghost.Hold(source, tool, topping, point): GrillView and
--           BoardView (the carried sausage / plate), BoardView (the knife), ToolView (bottle, slice, strip, pinch). One Heartbeat
--           sends PrepPointer at Ghost.Hz while something is held (an unchanged hand is repeated every Stale / 2 s, which also
--           renews the server's grab lease) and Tool = None ONCE on release. Nothing at all while Rules.World.GhostHand is false.
--   Ghost   a PrepGhost of a colleague = his held item drawn here: a model of the same 3D prep kit (ToolView for the topping
--           tools; anchored, no collision, CanQuery false), its position smoothed with Ghost.Lerp, a Highlight in
--           Presence.Palette[station] (FillTransparency Ghost.Fill; none at Budget.LowQuality) and his name tag (Mates.Tag; the
--           UserId comes from PrepSeats). Ghost.Stale s without a packet (or Tool = None): it fades out. At most Budget.Ghosts.
--   Claims  the set PrepClaims = the grill / rail sausages a seat holds. Ghost.HeldBy tells a stage who holds one (it refuses
--           the grab locally, the server refuses it anyway) and the sausage of the world gets a Highlight in the holder's colour.
-- Mounted ONCE by PrepController:OnInit, which also owns the responders (PrepGhost, PrepClaims) and feeds them here: the ghost
-- lives outside the mode too, so someone walking in the world sees the drag. Its folder sits under the camera, apart from
-- the PrepWorld folder (World.Leave only calls Ghost.Clear). The colleague's character is World/Mates' (it hides the body in
-- the mode); nothing here touches a character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Mates = require(script.Parent.Parent.Mates)
local ToolView = require(script.Parent.ToolView)

const prep = Content.Prep
const world = prep.Rules.World
const ghostRules = world.Ghost

const FOLDER_NAME = "PrepGhosts"
const FADE = 0.2 -- s the ghost takes to fade out once stale
const MOVE_EPS = 0.02 -- studs: a hand that moved less is not sent again before Stale / 2
const CLAIM_REFRESH = 0.25 -- s between two re-reads of the held sausages of the world (adornees come and go with the slots)
const HELD_TEXT = "%s is holding it" -- Provisional (ui-text §16 to add): the toast of a refused grab
const SOMEONE = "A colleague" -- the name when the seat's player is not found

type Hold = { Tool: Content.PrepToolKind, Topping: string?, Pos: Vector3, At: number }

type Ghost = {
	Station: number,
	Tool: Content.PrepToolKind,
	Topping: string?,
	Root: Model,
	Anchor: Part,
	View: ToolView.Tool?,
	Model: Model?,
	Light: Highlight?,
	Tag: BillboardGui?,
	Target: Vector3,
	Pos: Vector3,
	Seen: boolean,
	Last: number, -- os.clock() of the last packet; -inf = released
	Alpha: number, -- 0 shown .. 1 gone
}

const Ghost = {}

local net: any = nil
local kitchen: any = nil
local folder: Folder? = nil
local connection: RBXScriptConnection? = nil

-- the own hand, by source (a view); the latest one picked wins
const holds: { [string]: Hold } = {}
local sentTool: Content.PrepToolKind = "None"
local sentTopping: string? = nil
local sentPos = Vector3.zero
local sentAt = -math.huge
local sendIn = 0

const ghosts: { [number]: Ghost } = {}
-- PrepClaims: record id -> station; the Highlights of the held world sausages by record id
const claims: { [number]: number } = {}
const claimLights: { [number]: Highlight } = {}
local claimIn = 0

const toppingKeys: { [string]: boolean } = {}
for _, key in Content.Ingredients.ToppingKeys do
	toppingKeys[key] = true
end

const TOOL_VIEW: { [string]: ToolView.Kind } = { Bottle = "Bottle", Slice = "Slice", Strip = "Strip", Pinch = "Pinch" }

-- Reading the seats -------------------------------------------------------------------------------------------------------

-- The seat of the local player (PrepSeats record with User = own UserId), nil = not seated.
local function mySeat(): number?
	if net == nil then
		return nil
	end
	const me = Players.LocalPlayer.UserId
	for station = 1, prep.Stations do
		const record = net.PrepSeats:get(station)
		if record ~= nil and record.User == me then
			return station
		end
	end
	return nil
end

-- The username of the player at a seat (the tag and the "is holding it" toast).
local function nameOf(station: number): string
	const record = if net ~= nil then net.PrepSeats:get(station) else nil
	const user = if record ~= nil then record.User else nil
	const player = if type(user) == "number" then Players:GetPlayerByUserId(user) else nil
	return if player ~= nil then player.Name else SOMEONE
end

local function claimId(from: string, slot: number): number?
	const index = table.find(prep.GrabFrom, from)
	if index == nil or slot < 1 or slot > 8 then
		return nil
	end
	return (index - 1) * 8 + slot
end

-- The graphics quality is read once per ghost / light made (Mates.LowQuality: Budget.LowQuality).
local function canLight(): boolean
	return not Mates.LowQuality()
end

local function ensureFolder(): Folder
	const current: Folder = folder or Instance.new("Folder")
	if folder == nil then
		current.Name = FOLDER_NAME
		folder = current
	end
	const camera = workspace.CurrentCamera
	if camera ~= nil and current.Parent ~= camera then
		current.Parent = camera
	end
	return current
end

-- The ghost item ----------------------------------------------------------------------------------------------------------

local function inertPart(size: Vector3, color: Color3, parent: Instance): Part
	const part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function kitModel(group: string, name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const found = if items then items:FindFirstChild(group) else nil
	const model = if found then found:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- A copy of a kit model: anchored, never hit by a ray, never casting a shadow (the same treatment as GrillView / BoardView).
local function inertCopy(source: Model, parent: Instance): Model
	const copy = source:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
		elseif descendant:IsA("WeldConstraint") or descendant:IsA("Weld") then
			descendant:Destroy()
		end
	end
	copy.Parent = parent
	return copy
end

-- The knife and the tools the kit has no model for (ladle, spatula): PLACEHOLDER Parts (Provisional), a blade and a handle.
local function placeholder(tool: Content.PrepToolKind, parent: Instance): Model
	const model = Instance.new("Model")
	model.Name = `Ghost_{tool}`
	const blade = inertPart(Vector3.new(1.1, 0.05, 0.22), Color3.fromHex("#C9CED6"), model)
	blade.Name = "Blade"
	blade.CFrame = CFrame.new(0.3, 0, 0)
	const handle = inertPart(Vector3.new(0.5, 0.12, 0.14), Theme.Color.Ink, model)
	handle.Name = "Handle"
	handle.CFrame = CFrame.new(-0.5, 0, 0)
	model.PrimaryPart = blade
	model.Parent = parent
	return model
end

local function buildItem(ghost: Ghost)
	if ghost.View ~= nil then
		ghost.View:Destroy()
		ghost.View = nil
	end
	if ghost.Model ~= nil then
		ghost.Model:Destroy()
		ghost.Model = nil
	end
	ghost.Seen = false
	const tool = ghost.Tool
	const viewKind = TOOL_VIEW[tool]
	if viewKind ~= nil then
		-- the topping tools are ToolView itself (bottle Parts, the kit's cheese / bacon / potato sticks); its folder is the ghost Model
		-- so the Highlight covers it
		const view = ToolView.new(ghost.Root :: any, world, CFrame.identity)
		view:Set(viewKind, ghost.Topping or "")
		ghost.View = view
		return
	end
	local source: Model? = nil
	if tool == "Sausage" then
		source = kitModel("Food", "SausageGrilled")
	elseif tool == "Plate" then
		source = kitModel("Food", "BunOpen")
	end
	ghost.Model = if source ~= nil then inertCopy(source, ghost.Root) else placeholder(tool, ghost.Root)
end

local function newGhost(station: number): Ghost
	const color = Mates.ColorOf(station)
	const root = Instance.new("Model")
	root.Name = `Ghost_{station}`
	const anchor = inertPart(Vector3.new(0.1, 0.1, 0.1), color, root)
	anchor.Name = "TagAnchor"
	anchor.Transparency = 1
	const ghost: Ghost = {
		Station = station,
		Tool = "None",
		Topping = nil,
		Root = root,
		Anchor = anchor,
		View = nil,
		Model = nil,
		Light = nil,
		Tag = nil,
		Target = Vector3.zero,
		Pos = Vector3.zero,
		Seen = false,
		Last = os.clock(),
		Alpha = 0,
	}
	if canLight() then
		const light = Instance.new("Highlight")
		light.Name = "GhostLight"
		light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		light.FillColor = color
		light.FillTransparency = ghostRules.Fill
		light.OutlineColor = color
		light.OutlineTransparency = 0
		light.Adornee = root
		light.Parent = root
		ghost.Light = light
	end
	-- no name tag on the item (owner 2026-10-17: one billboard per player, the one over the head; the colour says who)
	root.Parent = ensureFolder()
	return ghost
end

local function dropGhost(station: number)
	const ghost = ghosts[station]
	if ghost == nil then
		return
	end
	ghosts[station] = nil
	if ghost.View ~= nil then
		ghost.View:Destroy()
	end
	ghost.Root:Destroy()
end

local function setAlpha(ghost: Ghost, alpha: number)
	ghost.Alpha = alpha
	for _, descendant in ghost.Root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= ghost.Anchor then
			descendant.LocalTransparencyModifier = alpha
		end
	end
	if ghost.Light ~= nil then
		ghost.Light.FillTransparency = ghostRules.Fill + (1 - ghostRules.Fill) * alpha
		ghost.Light.OutlineTransparency = alpha
	end
	if ghost.Tag ~= nil then
		ghost.Tag.Enabled = alpha < 0.5
	end
end

local function stepGhost(ghost: Ghost, dt: number, now: number): boolean
	if now - ghost.Last > ghostRules.Stale then
		const alpha = math.min(ghost.Alpha + dt / FADE, 1)
		setAlpha(ghost, alpha)
		return alpha < 1
	end
	if ghost.Alpha > 0 then
		setAlpha(ghost, 0)
	end
	ghost.Pos = if ghost.Seen then ghost.Pos:Lerp(ghost.Target, 1 - math.exp(-ghostRules.Lerp * dt)) else ghost.Target
	ghost.Seen = true
	ghost.Anchor.CFrame = CFrame.new(ghost.Pos)
	if ghost.View ~= nil then
		ghost.View:Move(ghost.Pos, false, 0)
		ghost.View:Step(dt)
	elseif ghost.Model ~= nil then
		ghost.Model:PivotTo(CFrame.new(ghost.Pos))
	end
	return true
end

-- The held sausages of the world ------------------------------------------------------------------------------------------

local function dropClaimLight(id: number)
	const light = claimLights[id]
	if light ~= nil then
		light:Destroy()
		claimLights[id] = nil
	end
end

local function refreshClaims()
	const mine = mySeat()
	const lit = canLight()
	local count = 0
	for id in claimLights do
		if claims[id] == nil or not lit then
			dropClaimLight(id)
		else
			count += 1
		end
	end
	for id, station in claims do
		if not lit or station == mine or kitchen == nil then
			dropClaimLight(id)
			continue
		end
		const from = prep.GrabFrom[(id - 1) // 8 + 1]
		const slot = (id - 1) % 8 + 1
		const entry: { Container: Model? }? = if from ~= nil then kitchen:SlotView(string.lower(from), slot) else nil
		const container = if entry ~= nil then entry.Container else nil
		if container == nil then
			dropClaimLight(id)
			continue
		end
		local light = claimLights[id]
		if light == nil then
			if count >= world.Budget.Ghosts then
				continue
			end
			light = Instance.new("Highlight")
			const made = light :: Highlight
			made.Name = "ClaimLight"
			made.DepthMode = Enum.HighlightDepthMode.Occluded
			made.FillTransparency = ghostRules.Fill
			made.OutlineTransparency = 0
			made.Parent = ensureFolder()
			claimLights[id] = made
			count += 1
		end
		const held = light :: Highlight
		const color = Mates.ColorOf(station)
		held.FillColor = color
		held.OutlineColor = color
		if held.Adornee ~= container then
			held.Adornee = container
		end
	end
end

-- The own hand -------------------------------------------------------------------------------------------------------------

local function pickHold(): Hold?
	local best: Hold? = nil
	for _, entry in holds do
		if best == nil or entry.At > (best :: Hold).At then
			best = entry
		end
	end
	return best
end

local function fire(tool: Content.PrepToolKind, topping: string?, pos: Vector3, now: number)
	sentTool, sentTopping, sentPos, sentAt = tool, topping, pos, now
	if net ~= nil then
		net.PrepPointer:fireServer({ Tool = tool, Topping = topping, Pos = pos })
	end
end

local function stepSend(dt: number, now: number)
	sendIn -= dt
	if sendIn > 0 then
		return
	end
	sendIn = 1 / ghostRules.Hz
	const hold = pickHold()
	if hold == nil then
		if sentTool ~= "None" then
			fire("None", nil, sentPos, now)
		end
		return
	end
	const topping = if hold.Topping ~= nil and toppingKeys[hold.Topping] then hold.Topping else nil
	if hold.Tool == sentTool and topping == sentTopping and (hold.Pos - sentPos).Magnitude < MOVE_EPS and now - sentAt < ghostRules.Stale / 2 then
		return
	end
	fire(hold.Tool, topping, hold.Pos, now)
end

local function step(dt: number)
	const now = os.clock()
	if world.GhostHand then
		stepSend(dt, now)
	end
	for station, ghost in ghosts do
		if not stepGhost(ghost, dt, now) then
			dropGhost(station)
		end
	end
	claimIn -= dt
	if claimIn <= 0 then
		claimIn = CLAIM_REFRESH
		refreshClaims()
	end
end

-- API ----------------------------------------------------------------------------------------------------------------------

-- Once, from PrepController:OnInit. `network` = the Libs.Net of the controller, `kitchenController` = KitchenController (its
-- SlotView finds the world sausage of a held grill / rail slot).
function Ghost.Mount(network: any, kitchenController: any)
	if connection ~= nil then
		return
	end
	net = network
	kitchen = kitchenController
	connection = RunService.Heartbeat:Connect(step)
end

-- The own hand: `source` = the view reporting (one entry each), `tool` = what it holds ("None" or a nil point = it let go),
-- `topping` = the ingredient of a Bottle / Slice / Strip / Pinch, `point` = the world position of the held item (nil = the ray
-- missed the work plane for a frame: the last position stays, so the colleagues' ghost does not blink).
function Ghost.Hold(source: string, tool: Content.PrepToolKind, topping: string?, point: Vector3?)
	if not world.GhostHand then
		return
	end
	if tool == "None" then
		holds[source] = nil
		return
	end
	if point == nil then
		return
	end
	const entry = holds[source]
	if entry == nil or entry.Tool ~= tool or entry.Topping ~= topping then
		holds[source] = { Tool = tool, Topping = topping, Pos = point, At = os.clock() }
	else
		entry.Pos = point
	end
end

-- The mode was left: nothing is held any more (the next send is Tool = None, once).
function Ghost.Clear()
	table.clear(holds)
end

-- PrepGhost (responder in PrepController:OnInit): a colleague's hand.
function Ghost.Receive(data: any)
	if not world.GhostHand then
		return
	end
	const station: number = data.Station
	if station == mySeat() then
		return
	end
	local ghost = ghosts[station]
	if data.Tool == "None" then
		if ghost ~= nil then
			ghost.Last = -math.huge
		end
		return
	end
	if ghost == nil then
		local count = 0
		for _ in ghosts do
			count += 1
		end
		if count >= world.Budget.Ghosts then
			return
		end
		ghost = newGhost(station)
		ghosts[station] = ghost
	end
	const live = ghost :: Ghost
	if live.Tool ~= data.Tool or live.Topping ~= data.Topping or (live.View == nil and live.Model == nil) then
		live.Tool = data.Tool
		live.Topping = data.Topping
		buildItem(live)
	end
	live.Target = data.Pos
	live.Last = os.clock()
end

-- PrepClaims (responders in PrepController:OnInit): `station` = the holder of the record, nil = the record was removed.
function Ghost.SetClaim(id: number, station: number?)
	claims[id] = station
	claimIn = 0
end

-- Who holds a grill / rail sausage, when it is ANOTHER seat: (station, the "<name> is holding it" toast), nil = free or mine.
function Ghost.HeldBy(from: string, slot: number): (number?, string?)
	const id = claimId(from, slot)
	const station = if id ~= nil then claims[id] else nil
	if station == nil or station == mySeat() then
		return nil, nil
	end
	return station, string.format(HELD_TEXT, nameOf(station))
end

-- The toast of a refused grab (PrepResult Act = Grab, Reason = Held) when the claim is not known here yet.
function Ghost.HeldText(from: string, slot: number): string
	const _, text = Ghost.HeldBy(from, slot)
	return text or string.format(HELD_TEXT, SOMEONE)
end

return Ghost
