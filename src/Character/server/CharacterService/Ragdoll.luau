--!strict
-- R6 ragdoll joints of a crew character (architecture.md §8.3, §19.17; DEC-216: sanity 0 = ragdoll in place, no
-- throw; DEC-197: car hit). Pure helper of CharacterService: no Modux, no network.
-- Prepare builds one disabled BallSocketConstraint per body Motor6D at spawn (TASK-100: the knock only flips
-- Enabled, no instance is created on the hit frame). Enable turns the Motor6Ds off and the sockets on; Disable does
-- the reverse and keeps the sockets for the next time. A character without Prepare still works (sockets built on
-- demand). The RootJoint stays on, so the HumanoidRootPart follows the Torso. Limits are technical (keep the pose
-- readable), not design numbers.
local Ragdoll = {}

const SOCKET_NAME = "RagdollSocket"
const ATTACHMENT0 = "RagdollAttachment0"
const ATTACHMENT1 = "RagdollAttachment1"

type Limit = { Upper: number, TwistLower: number, TwistUpper: number }

const NECK: Limit = { Upper = 30, TwistLower = -45, TwistUpper = 45 }
const SHOULDER: Limit = { Upper = 90, TwistLower = -75, TwistUpper = 75 }
const HIP: Limit = { Upper = 60, TwistLower = -30, TwistUpper = 30 }

-- Motor6D name -> socket limits (the R6 joints of CrewRig.Build, RootJoint excluded).
const LIMITS: { [string]: Limit } = table.freeze({
	Neck = NECK,
	["Right Shoulder"] = SHOULDER,
	["Left Shoulder"] = SHOULDER,
	["Right Hip"] = HIP,
	["Left Hip"] = HIP,
} :: { [string]: Limit })

-- characters with the ragdoll on (weak: a destroyed character goes away with it)
const active: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function bodyMotors(character: Model): { Motor6D }
	const motors: { Motor6D } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and LIMITS[descendant.Name] ~= nil then
			table.insert(motors, descendant)
		end
	end
	return motors
end

local function attachment(parent: BasePart, name: string, frame: CFrame): Attachment
	const existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Attachment") then
		existing.CFrame = frame
		return existing
	end
	const created = Instance.new("Attachment")
	created.Name = name
	created.CFrame = frame
	created.Parent = parent
	return created
end

-- Socket of one motor (on its Part1), built disabled when missing. Nil when the motor has no parts.
local function socketOf(motor: Motor6D): BallSocketConstraint?
	const part0 = motor.Part0
	const part1 = motor.Part1
	if part0 == nil or part1 == nil then
		return nil
	end
	const name = `{SOCKET_NAME}_{motor.Name}`
	const existing = part1:FindFirstChild(name)
	if existing ~= nil and existing:IsA("BallSocketConstraint") then
		return existing
	end
	const limit = LIMITS[motor.Name]
	const socket = Instance.new("BallSocketConstraint")
	socket.Name = name
	socket.Enabled = false
	socket.Attachment0 = attachment(part0, `{ATTACHMENT0}_{motor.Name}`, motor.C0)
	socket.Attachment1 = attachment(part1, `{ATTACHMENT1}_{motor.Name}`, motor.C1)
	socket.LimitsEnabled = true
	socket.UpperAngle = limit.Upper
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = limit.TwistLower
	socket.TwistUpperAngle = limit.TwistUpper
	socket.Parent = part1
	return socket
end

function Ragdoll.IsOn(character: Model): boolean
	return active[character] == true
end

-- Prebuilds the disabled sockets (CharacterService:Prepare, at spawn). Idempotent.
function Ragdoll.Prepare(character: Model)
	for _, motor in bodyMotors(character) do
		socketOf(motor)
	end
end

-- Turns the ragdoll on. Limbs collide so the body rests on the ground. Idempotent.
function Ragdoll.Enable(character: Model)
	if Ragdoll.IsOn(character) then
		return
	end
	for _, motor in bodyMotors(character) do
		const socket = socketOf(motor)
		if socket == nil then
			continue
		end
		socket.Enabled = true
		const part1 = motor.Part1 :: BasePart
		if motor.Name ~= "Neck" then
			part1.CanCollide = true
		end
		motor.Enabled = false
	end
	active[character] = true
end

-- Turns the ragdoll off (motors back, sockets disabled and kept, limbs back to no collision). Idempotent.
function Ragdoll.Disable(character: Model)
	if not Ragdoll.IsOn(character) then
		return
	end
	for _, motor in bodyMotors(character) do
		const part1 = motor.Part1
		if part1 ~= nil then
			const socket = part1:FindFirstChild(`{SOCKET_NAME}_{motor.Name}`)
			if socket ~= nil and socket:IsA("BallSocketConstraint") then
				socket.Enabled = false
			end
			if motor.Name ~= "Neck" then
				part1.CanCollide = false
			end
		end
		motor.Enabled = true
	end
	active[character] = nil
end

return Ragdoll
