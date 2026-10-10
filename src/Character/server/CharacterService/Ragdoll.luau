--!strict
-- R6 ragdoll joints of a crew character (architecture.md §8.3; DEC-216: sanity 0 = ragdoll in place, no throw).
-- Pure helper of CharacterService: no Modux, no network. TASK-061 builds the joints on demand for Faint; TASK-100
-- (Knock, wave 3) may prebuild them in Prepare and add the impulse and the get-up on top of this module.
-- The body Motor6Ds are disabled and a BallSocketConstraint takes each one's place at the same joint frame. The
-- RootJoint stays on, so the HumanoidRootPart follows the Torso. Limits are technical (keep the pose readable), not
-- design numbers.
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

function Ragdoll.IsOn(character: Model): boolean
	return active[character] == true
end

-- Turns the ragdoll on. Limbs collide so the body rests on the ground. Idempotent.
function Ragdoll.Enable(character: Model)
	if Ragdoll.IsOn(character) then
		return
	end
	for _, motor in bodyMotors(character) do
		const part0 = motor.Part0
		const part1 = motor.Part1
		if part0 == nil or part1 == nil then
			continue
		end
		const limit = LIMITS[motor.Name]
		const socket = Instance.new("BallSocketConstraint")
		socket.Name = SOCKET_NAME
		socket.Attachment0 = attachment(part0, `{ATTACHMENT0}_{motor.Name}`, motor.C0)
		socket.Attachment1 = attachment(part1, `{ATTACHMENT1}_{motor.Name}`, motor.C1)
		socket.LimitsEnabled = true
		socket.UpperAngle = limit.Upper
		socket.TwistLimitsEnabled = true
		socket.TwistLowerAngle = limit.TwistLower
		socket.TwistUpperAngle = limit.TwistUpper
		socket.Parent = part1
		if motor.Name ~= "Neck" then
			part1.CanCollide = true
		end
		motor.Enabled = false
	end
	active[character] = true
end

-- Turns the ragdoll off (motors back, sockets removed, limbs back to no collision). Idempotent.
function Ragdoll.Disable(character: Model)
	if not Ragdoll.IsOn(character) then
		return
	end
	for _, motor in bodyMotors(character) do
		const part1 = motor.Part1
		if part1 ~= nil then
			for _, child in part1:GetChildren() do
				if child:IsA("BallSocketConstraint") and child.Name == SOCKET_NAME then
					child:Destroy()
				end
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
