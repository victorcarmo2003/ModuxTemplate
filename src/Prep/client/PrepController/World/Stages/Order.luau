--!strict
-- World/Stages/Order: the Take of the 3D prep (docs/tech/prep-3d.md §3.1; TASK-206). The tab Order left the bar: a customer at the
-- counter (Q1) that waits to be taken is taken in two ways, both PrepOrder Take (the same path as the world prompt,
-- CustomerService:TakeOrderFor; the server only accepts the one on Q1):
--   * the Take button of the ticket rail (2D, PrepController Slots.Ticket + TicketRail `Take`), on every tab and also without 3D
--   * in the Window view this overlay: the customer pulses (Highlight, Mustard) and a tap on it takes the order
-- It is an OVERLAY (Stage3D.Overlay, no tab): the Serve stage arms it (`Enter` / `Leave`) because the Window view is the Serve tab.
-- The Feed (the line, the pin, the Take / Serve acts, the broadcast events) is still started and fed by the 2D Order stage of
-- Stages/Order.luau, which has no board in the 3D set and stays as the Feed's host. The customer has no authored hitbox (it is a
-- rig that comes and goes): a hitbox part is made in code and follows the rig of the customer in front (Rig.SetSpared keeps that
-- rig whole in this view, PrepController:SpareCustomer). Rollback: Rules.World.Stages.Order = false leaves only the 2D Take.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Feed = require(script.Parent.Parent.Parent.Feed)
local Stage = require(script.Parent.Parent.Parent.Stage)
local Types = require(script.Parent.Parent.Types)
local World = require(script.Parent.Parent)

const untrack = Vide.untrack

const prep = Content.Prep
const rules = prep.Rules

const TIP_TEXT = "Tap the customer for the order" -- ui-text.md §16.1 PREP3D_TIP_CUSTOMER
const BOX = Vector3.new(2.4, 3.6, 2.4) -- studs: the hitbox around the rig (a body and a head of the animal rigs)
const BOX_LIFT = 1.0 -- studs over the root part
const FIND_EVERY = 0.25 -- s between two searches for the rig of the customer
const REARM = 0.25 -- s between letting go of a customer's contour and pulsing the next one (the Highlight syncs at 10 Hz)

type Session = {
	Hitbox: Part,
	Id: number,
	Model: Model?,
	Target: Types.Target,
	Stop: (() -> ())?,
	LookAt: number,
	RearmAt: number?,
}

local session: Session? = nil

-- The rig of NPC `id` (attribute NpcId, the tag AnimalRig), nil when it is not in the world.
local function rigOf(id: number): Model?
	for _, instance in CollectionService:GetTagged("AnimalRig") do
		if instance:IsA("Model") and instance:GetAttribute("NpcId") == id then
			return instance
		end
	end
	return nil
end

local function touch()
	const registry = World.Targets()
	if registry ~= nil then
		registry:Touch()
	end
end

local function frame(current: Session)
	const id = untrack(Feed.Front)
	const clock = os.clock()
	if id ~= current.Id then
		-- another customer (or none): the old contour goes first, the new one pulses a beat later
		current.Id = id
		current.Model = nil
		current.Target.Pulse = false
		current.Target.Model = nil
		current.RearmAt = if id ~= 0 then clock + REARM else nil
		current.LookAt = 0
		touch()
	end
	if id == 0 then
		return
	end
	if current.Model == nil and clock >= current.LookAt then
		current.LookAt = clock + FIND_EVERY
		current.Model = rigOf(id)
	end
	const model = current.Model
	if model == nil then
		return
	end
	const root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if root ~= nil and root:IsA("BasePart") then
		current.Hitbox.CFrame = CFrame.new(root.Position + Vector3.new(0, BOX_LIFT, 0))
	end
	if current.RearmAt ~= nil and clock >= current.RearmAt then
		current.RearmAt = nil
		current.Target.Model = model
		current.Target.Pulse = true
		touch()
	end
end

const Order = {}

Order.Tabs = {} :: { string }
Order.Overlay = true

-- armed by the Serve stage when the Window view comes to the front
function Order.Enter(_controller: any, _tab: string)
	if session ~= nil or not Stage.Armed(rules, "Order") then
		return
	end
	const registry = World.Targets()
	const aim = World.Aim()
	const folder = if workspace.CurrentCamera ~= nil then workspace.CurrentCamera:FindFirstChild(Types.FolderName) else nil
	if registry == nil or aim == nil or folder == nil then
		return
	end
	const hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox_Customer"
	hitbox.Anchored = true
	hitbox.Size = BOX
	hitbox.CFrame = CFrame.new(0, -500, 0)
	hitbox.Parent = folder
	const holder: { Session? } = {}
	const target = registry:Add({
		Target = Types.Target("Customer", 0, ""),
		Parts = { hitbox },
		Enabled = function(): boolean
			const open = holder[1]
			return open ~= nil and open.Id ~= 0 and open.Model ~= nil
		end,
	})
	const current: Session = { Hitbox = hitbox, Id = 0, Model = nil, Target = target, Stop = nil, LookAt = 0, RearmAt = nil }
	holder[1] = current
	session = current
	current.Stop = aim:OnFrame(function()
		const ok, problem = pcall(frame, current)
		if not ok then
			warn(`[PrepWorld] Order frame: {problem}`)
		end
	end)
end

function Order.Leave(_controller: any, _tab: string)
	const current = session
	if current == nil then
		return
	end
	session = nil
	if current.Stop ~= nil then
		current.Stop()
	end
	const registry = World.Targets()
	if registry ~= nil then
		registry:Remove(current.Target.Target.Id)
	end
	current.Hitbox:Destroy()
end

function Order.Step(_controller: any, _step: string) end

function Order.Hint(_controller: any): string
	return TIP_TEXT
end

function Order.Next(_controller: any): Stage.Next
	return { Label = prep.Texts.Take, Enabled = Feed.Front() ~= 0 }
end

-- Whether this overlay is armed in the front view and a customer waits to be taken (the Serve stage asks for its hint).
function Order.Waiting(): boolean
	return session ~= nil and untrack(Feed.Front) ~= 0
end

-- The aim messages of the Window view: a tap on the customer takes the order. true = handled.
function Order.OnAim(controller: any, message: any): boolean
	const current = session
	if current == nil or message.Kind ~= "Tap" then
		return false
	end
	const target = message.Target :: Types.Target
	if target.Target.Kind ~= "Customer" then
		return false
	end
	const id = untrack(Feed.Front)
	if id ~= 0 then
		Feed.Take(controller, id)
	end
	return true
end

return Order
