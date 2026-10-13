--!strict
-- World/Stages/Serve: the 3D serve at the window (docs/tech/prep-3d.md §3.5; TASK-206). The tab Serve is the Window view: the real
-- counter of the trailer, the finished plate on its cook side, a tray on the sill (the Hatch target) and the customer outside.
--   Plate     the finished plate is a real object of the world (a local copy of the bun, the grilled sausage and a strip per topping;
--             the bun and sausage models are the ones of the Board section, the plate and the strips are PLACEHOLDERS: no plate model
--             exists yet, AST-120+, Provisional). It shows once the grade seal is on (View.Seal), pulses while it can be served.
--   Serve     drag the plate to the window (Hatch) or tap it, or press Serve: PrepOrder Serve with the pinned ticket
--             (Feed.Pinned, the guide of who is served; the SERVER judges Complete / Incomplete / Wrong, DEC-072). The plate flies to
--             the customer, who takes it; the verdict comes with the Sale packet and shows over the customer (text + a burst); a Wrong
--             plate stays in hand and flies back. A refusal flies it back too (the server's records always win).
--   Take      Stages/Order (overlay): the customer at the counter pulses and a tap on him takes the order (PrepOrder Take).
-- Sends only through Feed (Serve, Take). No GuiObject but one short BillboardGui for the verdict (a Provisional exception to the
-- "no BillboardGui per target" of §8: one, 1 s, destroyed with the stage). Numbers: Content.Prep.Rules.World.Serve.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Feed = require(script.Parent.Parent.Parent.Feed)
local Stage = require(script.Parent.Parent.Parent.Stage)
local Order = require(script.Parent.Order)
local Targets = require(script.Parent.Parent.Targets)
local Types = require(script.Parent.Parent.Types)
local World = require(script.Parent.Parent)

const untrack = Vide.untrack

const prep = Content.Prep
const rules = prep.Rules
const world = rules.World
const cfg = world.Serve

const NOT_READY_TEXT = "Nothing to serve yet" -- ui-text.md §16.5 PREP3D_REF_NOT_READY
const NO_TICKET_TEXT = "Pin a ticket first" -- PREP3D_REF_NO_TICKET
const SERVING_TEXT = "Serving..."
const PLATE_TOP = 0.06 -- studs: thickness of the placeholder plate
const SURFACE_DROP = 0.6 -- studs under the Hatch hitbox centre: the top of the sill (Provisional, measured in Play)
const BOX = Vector3.new(1.3, 0.7, 1.3) -- the plate hitbox
-- colours of the strips of the toppings (pictures of food, not UI states; Provisional placeholders)
const STRIPS: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#C0392B"),
	mustard = Color3.fromHex("#F2C230"),
	cream_cheese = Color3.fromHex("#F4EFE6"),
	cheese = Color3.fromHex("#F5A623"),
	bacon = Color3.fromHex("#8E3B2E"),
	potato_sticks = Color3.fromHex("#D9B26A"),
}

type Anim = { From: CFrame, To: CFrame, T: number, Duration: number, Arc: number, Then: (() -> ())? }

type Session = {
	Controller: any,
	Folder: Folder,
	Registry: Targets.Registry,
	Tray: Part,
	Hatch: Vector3,
	Surface: number,
	Rest: CFrame,
	Plate: Model?,
	Signature: string,
	-- where the plate is now (the pose the model follows) and whether it is on the table at all (a served one is gone)
	Pose: CFrame,
	Gone: boolean,
	Carry: boolean,
	Serving: boolean,
	Anim: Anim?,
	Box: Part,
	Targets: { [string]: Types.Target },
	Pulse: { [string]: boolean },
	Stop: (() -> ())?,
	Anchor: Part,
	Verdict: BillboardGui?,
	VerdictUntil: number,
	Active: boolean,
	CoachTried: boolean,
}

local session: Session? = nil
local hooked = false

-- `/dev prep ray` (player attribute PrepRay) also narrates the serve in the client output.
local function note(text: string)
	if Players.LocalPlayer:GetAttribute("PrepRay") == true then
		print(`[prep serve] {text}`)
	end
end

-- Models ---------------------------------------------------------------------------------------------------------------------

local function food(name: string): Model?
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const items = if assets then assets:FindFirstChild("Items") else nil
	const folder = if items then items:FindFirstChild("Food") else nil
	const model = if folder then folder:FindFirstChild(name) else nil
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- An inert copy of a food model of the kit, pivot at `at` (relative to the plate pivot).
local function copyOf(name: string, at: CFrame, parent: Instance)
	const source = food(name)
	if source == nil then
		return
	end
	const copy = source:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
		elseif descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
	copy:PivotTo(at)
	copy.Parent = parent
end

local function block(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?)
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- The plate with what is on it (a bun, a grilled sausage, a strip per topping), built at the origin and moved with PivotTo.
local function buildPlate(keys: { string }): Model
	const model = Instance.new("Model")
	model.Name = "Prep_ServePlate"
	const radius = cfg.PlateRadius
	-- the disc (a cylinder whose axis is Y): the pivot offset turns it back so PivotTo(C) puts the model upright at C
	const disc = block(model, "Plate_Placeholder", Vector3.new(PLATE_TOP, radius * 2, radius * 2), CFrame.Angles(0, 0, math.pi / 2), Theme.Color.Cream)
	disc.Shape = Enum.PartType.Cylinder
	disc.PivotOffset = CFrame.Angles(0, 0, -math.pi / 2)
	model.PrimaryPart = disc
	copyOf("BunOpen", CFrame.new(0, PLATE_TOP / 2, 0), model)
	copyOf("SausageGrilled", CFrame.new(0, PLATE_TOP / 2 + 0.17, 0), model)
	-- the strips lie over the sausage, side by side across it
	const count = #keys
	for index, key in keys do
		const offset = (index - (count + 1) / 2) * 0.13
		block(
			model,
			`Topping_{key}`,
			Vector3.new(0.7, 0.04, 0.09),
			CFrame.new(0, PLATE_TOP / 2 + 0.43, offset),
			STRIPS[key] or Theme.Color.Mustard
		)
	end
	return model
end

local function toppingKeys(controller: any): { string }
	const keys: { string } = {}
	const list: { { Key: string } } = controller.View.Toppings()
	for _, topping in list do
		table.insert(keys, topping.Key)
	end
	return keys
end

local function ready(controller: any): boolean
	return controller.View.Seal() ~= false
end

-- Poses ------------------------------------------------------------------------------------------------------------------------

local function lerpPose(from: CFrame, to: CFrame, alpha: number, arc: number): CFrame
	const eased = alpha * alpha * (3 - 2 * alpha)
	const at = from:Lerp(to, eased)
	return at + Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
end

local function setPose(current: Session, pose: CFrame)
	current.Pose = pose
	if current.Plate ~= nil then
		current.Plate:PivotTo(pose)
	end
	current.Box.CFrame = pose + Vector3.new(0, 0.2, 0)
end

local function fly(current: Session, to: CFrame, duration: number, arc: number, after: (() -> ())?)
	current.Anim = { From = current.Pose, To = to, T = 0, Duration = math.max(duration, 0.01), Arc = arc, Then = after }
end

-- The pose the plate rests in, on the cook side of the sill; a carried plate rides `Lift` over it.
local function restPose(current: Session): CFrame
	return current.Rest
end

-- Where the customer of `npc` holds his hand out: over his root part, nil when he is not near the window.
local function handOf(current: Session, npc: number): Vector3?
	const model = (function(): Instance?
		for _, instance in game:GetService("CollectionService"):GetTagged("AnimalRig") do
			if instance:GetAttribute("NpcId") == npc then
				return instance
			end
		end
		return nil
	end)()
	if model == nil then
		return nil
	end
	const root = model:FindFirstChild("HumanoidRootPart") or (model :: Model).PrimaryPart
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	if (root.Position - current.Hatch).Magnitude > 9 then
		return nil
	end
	return root.Position + Vector3.new(0, cfg.HandLift + 1.0, 0)
end

-- The verdict -----------------------------------------------------------------------------------------------------------------

local function clearVerdict(current: Session)
	if current.Verdict ~= nil then
		current.Verdict:Destroy()
		current.Verdict = nil
	end
end

local function showVerdict(current: Session, at: Vector3, text: string, small: string)
	clearVerdict(current)
	current.Anchor.CFrame = CFrame.new(at)
	const gui = Instance.new("BillboardGui")
	gui.Name = "Verdict"
	gui.Adornee = current.Anchor
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(190, 64)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	-- in the PlayerGui (a BillboardGui under the camera does not draw), adorned to the anchor part
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	const card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Theme.Color.Cream
	card.Parent = gui
	const corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	const stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Color.Ink
	stroke.Thickness = 3
	stroke.Parent = card
	const label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, if small ~= "" then 0.62 else 1, 0)
	label.FontFace = Theme.Font.Title
	label.TextSize = 26
	label.TextColor3 = Theme.Color.Ink
	label.Text = text
	label.Parent = card
	if small ~= "" then
		const line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0, 0.58)
		line.Size = UDim2.fromScale(1, 0.38)
		line.FontFace = Theme.Font.Body
		line.TextSize = 16
		line.TextColor3 = Theme.Color.Ink
		line.Text = small
		line.Parent = card
	end
	current.Verdict = gui
	current.VerdictUntil = os.clock() + cfg.Verdict
end

-- Acts ---------------------------------------------------------------------------------------------------------------------------

-- Back to the rest pose (a refusal, a drop on nothing, a Wrong plate that stays in hand).
local function giveBack(current: Session)
	current.Carry = false
	fly(current, restPose(current), cfg.Return, 0.1, nil)
end

local function serve(current: Session): boolean
	const controller = current.Controller
	if not ready(controller) or current.Gone then
		controller:Toast(NOT_READY_TEXT, "Alert")
		giveBack(current)
		return false
	end
	const pinned = untrack(Feed.Pinned)
	if pinned == 0 then
		controller:Toast(NO_TICKET_TEXT, "Alert")
		giveBack(current)
		return false
	end
	if not Feed.Serve(controller, pinned) then
		controller:Toast("One at a time", "Info")
		giveBack(current)
		return false
	end
	note(`Serve sent, customer {pinned}`)
World.Coach():Done("Serve")
	current.Serving = true
	current.Carry = false
	-- the plate flies to the hand of the customer who ordered (or to the middle of the tray when he is not at the window)
	const hand = handOf(current, pinned)
	const target = if hand ~= nil then CFrame.new(hand) else CFrame.new(current.Hatch.X, current.Surface + 0.1, current.Hatch.Z)
	fly(current, target, cfg.Fly, 0.25, function()
		-- he took it: the plate is gone until the server says otherwise
		if current.Serving and current.Plate ~= nil then
			current.Gone = true
			current.Plate:Destroy()
			current.Plate = nil
			current.Signature = ""
		end
	end)
	return true
end

-- The Sale of our Serve came back (Feed.OnServed): the verdict over the customer and the burst; Wrong keeps the plate.
local function onServed(controller: any, stamp: Feed.Stamp, npc: number)
	const current = session
	if current == nil or not current.Active then
		return
	end
	note(`Sale: {stamp.Result} +${stamp.Amount} for customer {npc}`)
	current.Serving = false
	const at = handOf(current, npc) or (current.Hatch + Vector3.new(0, 1.6, 0))
	const grade: any = untrack(function(): any
		return controller.View.Seal()
	end)
	showVerdict(current, at, Feed.ServeText(stamp.Result, stamp.Amount), if grade ~= false then prep.Grades.Labels[grade] or "" else "")
	const juice = World.Juice()
	if stamp.Result == "Perfect" then
		juice:Burst("Confetti", at, world.Juice.Confetti.Perfect, nil)
		juice:Burst("Coins", at, 8)
		juice:Float(`+${stamp.Amount}`, at + Vector3.new(0, 0.6, 0), Theme.Color.Mustard, nil)
		juice:Tone("coin", at, 4)
	elseif stamp.Result == "Complete" then
		juice:Burst("Sparks", at, 10, Theme.Color.Mustard)
		juice:Burst("Coins", at, 5)
		juice:Float(`+${stamp.Amount}`, at + Vector3.new(0, 0.6, 0), Theme.Color.Mustard, nil)
		juice:Tone("coin", at, 0)
	else
		juice:Burst("Dust", at, 6)
	end
	if stamp.Result == "Wrong" then
		-- the hot dog stayed in hand: the plate comes back to the rest pose
		current.Gone = false
		current.Signature = ""
		current.Pose = CFrame.new(at)
		giveBack(current)
	end
end

-- Frame ------------------------------------------------------------------------------------------------------------------------

local function setPulse(current: Session, id: string, on: boolean)
	if current.Pulse[id] == on then
		return
	end
	current.Pulse[id] = on
	const target = current.Targets[id]
	if target ~= nil then
		target.Pulse = on
		current.Registry:Touch()
	end
end

local function frame(current: Session, dt: number)
	const controller = current.Controller
	const now = os.clock()
	const show = ready(controller) and not current.Gone
	-- the plate model follows what the plate holds (re-built when the toppings change or after a Wrong)
	if show then
		const keys = toppingKeys(controller)
		const signature = table.concat(keys, ",")
		if current.Plate == nil or current.Signature ~= signature then
			if current.Plate ~= nil then
				current.Plate:Destroy()
			end
			const model = buildPlate(keys)
			model.Parent = current.Folder
			current.Plate = model
			current.Signature = signature
			const target = current.Targets.Plate
			if target ~= nil then
				target.Model = model
			end
			setPose(current, current.Pose)
		end
	elseif current.Plate ~= nil and not current.Serving then
		current.Plate:Destroy()
		current.Plate = nil
		current.Signature = ""
	end
	-- the flight
	const anim = current.Anim
	if anim ~= nil then
		anim.T += dt
		const alpha = math.clamp(anim.T / anim.Duration, 0, 1)
		setPose(current, lerpPose(anim.From, anim.To, alpha, anim.Arc))
		if alpha >= 1 then
			current.Anim = nil
			if anim.Then ~= nil then
				anim.Then()
			end
		end
	end
	if current.Verdict ~= nil and now >= current.VerdictUntil then
		clearVerdict(current)
	end
	-- the invitations: the plate pulses while it can be served, the tray while it is carried
	const canServe = show and not current.Serving and untrack(Feed.Pinned) ~= 0
	setPulse(current, "Plate", canServe and not current.Carry)
	setPulse(current, "Hatch", canServe and current.Carry)
	-- the virtual bin shows while the finished plate is on the sill
	const bin = World.Bin()
	if bin ~= nil then
		bin:SetWanted(show and not current.Serving and current.Plate ~= nil)
	end
	-- the hand of the tutorial: the plate to the window, once
	if show and not current.CoachTried and current.Plate ~= nil and not World.Coach():Active() then
		current.CoachTried = true
		World.Coach():Show("Serve", { current.Rest.Position + Vector3.new(0, 0.15, 0), Vector3.new(current.Hatch.X, current.Surface + 0.25, current.Hatch.Z) })
	end
end

-- Targets ----------------------------------------------------------------------------------------------------------------------

local function build(controller: any)
	const registry = World.Targets()
	const aim = World.Aim()
	const camera = workspace.CurrentCamera
	const folder = if camera ~= nil then camera:FindFirstChild(Types.FolderName) else nil
	if registry == nil or aim == nil or camera == nil or folder == nil then
		error("the 3D world is not running")
	end
	-- where the sill is: the Hatch hitbox of the trailer, else a point in front of the focus of the view
	const scanned = registry:Get("Hatch")
	const pose = controller.Pose :: { Frame: CFrame, Focus: Vector3 }
	local hatch = pose.Focus
	local surface = hatch.Y - 0.5
	local hatchParts: { BasePart } = {}
	local hatchModel: Instance? = nil
	if scanned ~= nil and scanned.Parts[1] ~= nil then
		hatchParts = scanned.Parts
		hatch = scanned.Parts[1].Position
		surface = hatch.Y - SURFACE_DROP
	else
		warn("[PrepWorld] no Hatch hitbox in the trailer (tag PrepTarget, TargetKind Hatch): the tray goes to the focus of the view")
		const box = Instance.new("Part")
		box.Name = "Hitbox_Hatch"
		box.Anchored = true
		box.Size = Vector3.new(3, 1, 1.3)
		box.CFrame = CFrame.new(hatch)
		box.Parent = folder
		hatchParts = { box :: BasePart }
	end
	const away = Vector3.new(pose.Frame.Position.X - hatch.X, 0, pose.Frame.Position.Z - hatch.Z)
	const toward = if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis
	const rotation = hatchParts[1].CFrame.Rotation
	-- the plate waits at the left of the tray as the camera sees it (the view looks steeply down at the sill)
	const flatRight = Vector3.new(pose.Frame.RightVector.X, 0, pose.Frame.RightVector.Z)
	const left = if flatRight.Magnitude > 1e-3 then -flatRight.Unit else -Vector3.xAxis
	const rest = CFrame.new(hatch.X, surface + PLATE_TOP / 2, hatch.Z) + left * cfg.RestSide - toward * cfg.RestAway

	-- the placeholder tray on the sill (Provisional: no tray model exists yet)
	const tray = block(
		folder,
		"Tray_Placeholder",
		Vector3.new(cfg.TrayLength, 0.08, 1.0),
		CFrame.new(hatch.X, surface + 0.04, hatch.Z) * rotation,
		Theme.Color.Mustard
	)
	hatchModel = tray
	const box = Instance.new("Part")
	box.Name = "Hitbox_Plate"
	box.Anchored = true
	box.Size = BOX
	box.CFrame = rest
	box.Parent = folder
	const anchor = Instance.new("Part")
	anchor.Name = "VerdictAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Parent = folder

	const holder: { Session? } = {}
	const current: Session = {
		Controller = controller,
		Folder = folder :: Folder,
		Registry = registry,
		Tray = tray,
		Hatch = hatch,
		Surface = surface,
		Rest = rest,
		Plate = nil,
		Signature = "",
		Pose = rest,
		Gone = false,
		Carry = false,
		Serving = false,
		Anim = nil,
		Box = box,
		Targets = {},
		Pulse = {},
		Stop = nil,
		Anchor = anchor,
		Verdict = nil,
		VerdictUntil = 0,
		Active = true,
		CoachTried = false,
	}
	holder[1] = current
	session = current
	current.Targets.Plate = registry:Add({
		Target = Types.Target("Plate", 0, ""),
		Parts = { box },
		Enabled = function(): boolean
			const open = holder[1]
			-- off while it is carried: its own hitbox under the pointer would hide the Hatch from the ray
			return open ~= nil and open.Active and open.Plate ~= nil and not open.Serving and open.Anim == nil and not open.Carry
		end,
	})
	current.Targets.Hatch = registry:Add({
		Target = Types.Target("Hatch", 0, ""),
		Parts = hatchParts,
		Model = hatchModel,
		Enabled = function(): boolean
			const open = holder[1]
			return open ~= nil and open.Active and open.Plate ~= nil and not open.Serving
		end,
	})
	-- the plane the plate is dragged on: the sill, a little over it (Aim lifts a carried thing by Rules.World.Lift)
	World.SetWorkPlane({ Origin = Vector3.new(0, surface + PLATE_TOP, 0), Normal = Vector3.yAxis })
	current.Stop = aim:OnFrame(function(dt: number)
		const ok, problem = pcall(frame, current, dt)
		if not ok then
			warn(`[PrepWorld] Serve frame: {problem}`)
		end
	end)
end

local function teardown()
	const current = session
	if current == nil then
		return
	end
	session = nil
	current.Active = false
	if current.Stop ~= nil then
		current.Stop()
	end
	const bin = World.Bin()
	if bin ~= nil then
		bin:SetWanted(false)
	end
	clearVerdict(current)
	if current.Plate ~= nil then
		current.Plate:Destroy()
	end
	current.Registry:Remove("Plate")
	current.Registry:Remove("Hatch")
	current.Box:Destroy()
	current.Tray:Destroy()
	current.Anchor:Destroy()
	World.SetWorkPlane(nil)
end

-- The stage ---------------------------------------------------------------------------------------------------------------------

-- What the corner button does: serve a ready plate with a pinned ticket, else take the customer at the counter.
local function cornerMode(controller: any): string
	if ready(controller) and Feed.Pinned() ~= 0 then
		return "Serve"
	elseif Feed.Front() ~= 0 then
		return "Take"
	end
	return "Idle"
end

const Serve: Stage.Stage3D = {
	Tabs = { "Serve" },
	Enter = function(controller: any, tab: string)
		teardown()
		-- the hook of the 2D Serve stage (toast, board clear, back to the grill) stays; ours adds the verdict in the world
		if not hooked then
			hooked = true
			const previous = Feed.OnServed
			Feed.OnServed = function(owner: any, stamp: Feed.Stamp, npc: number)
				if previous ~= nil then
					previous(owner, stamp, npc)
				end
				onServed(owner, stamp, npc)
			end
		end
		Feed.Start(controller)
		const ok, problem = pcall(build, controller)
		if not ok then
			warn(`[PrepController] 3D serve failed to start, leaving the mode: {problem}`)
			teardown()
			task.defer(function()
				controller:Leave("StageFailed", false, false)
			end)
			return
		end
		Order.Enter(controller, tab)
	end,
	Leave = function(controller: any, tab: string)
		const aim = World.Aim()
		if aim ~= nil then
			aim:Cancel("Leave")
		end
		Order.Leave(controller, tab)
		teardown()
	end,
	Step = function(_controller: any, _step: string) end,
	Hint = function(controller: any): string
		if Feed.Sending() then
			return SERVING_TEXT
		end
		const mode = cornerMode(controller)
		if mode == "Serve" then
			return prep.Tabs.ByKey.Serve.Hint
		elseif mode == "Take" then
			return Order.Hint(controller)
		elseif ready(controller) then
			return NO_TICKET_TEXT
		end
		return NOT_READY_TEXT
	end,
	Next = function(controller: any): Stage.Next
		const mode = cornerMode(controller)
		if mode == "Serve" then
			return { Label = prep.Texts.Serve, Enabled = not Feed.Sending(), Pulse = not Feed.Sending() }
		elseif mode == "Take" then
			return { Label = prep.Texts.Take, Enabled = true, Pulse = true }
		end
		return { Label = prep.Texts.Serve, Enabled = false }
	end,
	OnNext = function(controller: any)
		const current = session
		const mode = untrack(function(): string
			return cornerMode(controller)
		end)
		if mode == "Take" then
			const id = untrack(Feed.Front)
			if id ~= 0 then
				Feed.Take(controller, id)
			end
		elseif mode == "Serve" and current ~= nil then
			serve(current)
		end
	end,
	OnAim = function(controller: any, message: any)
		const current = session
		if current == nil then
			return
		end
		if Order.OnAim(controller, message) then
			return
		end
		const kind: string = message.Kind
		if kind == "Press" then
			if (message.Target :: Types.Target).Target.Kind == "Plate" then
				current.Anim = nil
				current.Carry = true
			end
		elseif kind == "Move" then
			if (message.Source :: Types.Target).Target.Kind == "Plate" and current.Carry then
				const over = message.Over :: Types.Target?
				const point: Vector3 = message.Point
				if over ~= nil and over.Target.Kind == "Hatch" then
					-- the tray draws the plate in
					setPose(current, CFrame.new(current.Hatch.X, point.Y, current.Hatch.Z))
				else
					setPose(current, CFrame.new(point))
				end
			end
		elseif kind == "Release" or kind == "Cancel" then
			note(`{kind}: the plate goes back`)
			if current.Carry and not current.Serving then
				giveBack(current)
			end
		elseif kind == "Drop" then
			const source = message.Source :: Types.Target
			const over = message.Over :: Types.Target
			note(`Drop {source.Target.Id} over {over.Target.Id}`)
			if source.Target.Kind == "Plate" and (over.Target.Kind == "Hatch" or over.Target.Kind == "Customer") then
				serve(current)
			elseif source.Target.Kind == "Plate" and over.Target.Kind == "Bin" and current.Plate ~= nil and not current.Serving then
				-- the finished plate goes to the virtual bin: a copy is swallowed, the hot dog in hand is thrown by the server (PrepTrash)
				const bin = World.Bin()
				const copy = current.Plate:Clone()
				copy.Parent = current.Folder
				if bin ~= nil then
					bin:Eat(copy)
				else
					copy:Destroy()
				end
				current.Carry = false
				current.Gone = true
				current.Plate:Destroy()
				current.Plate = nil
				current.Signature = ""
				note("plate to the bin")
				current.Controller:Trash("Plate")
			elseif current.Carry then
				giveBack(current)
			end
		elseif kind == "Tap" then
			const target = message.Target :: Types.Target
			if target.Target.Kind == "Plate" or target.Target.Kind == "Hatch" then
				current.Carry = false
				serve(current)
			end
		end
	end,
	OnResult = function(_controller: any, result: any)
		const current = session
		-- a refused Serve: the plate comes back (the Notice of the reason was already shown by the controller)
		if current ~= nil and current.Serving and result.Act == "Order" and not result.Ok then
			current.Serving = false
			current.Gone = false
			current.Signature = ""
			giveBack(current)
		end
	end,
}

return Serve
