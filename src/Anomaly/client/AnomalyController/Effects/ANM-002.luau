--!strict
--[[
	ANM-002 "The wrong food", client effect (TASK-114; docs/story/anomalies.md N2; asset-list AST-061, AST-095;
	style guide §10; DEC-195). API: ../Effect.luau. Server: AnomalyService/Anomalies/ANM-002.luau (TASK-113).

	Presents only. The altered item itself is drawn by the KitchenController (TASK-110, `Altered` on the Stations
	record); this module adds the two flavor bits around it:

	  - Sign (Mount, fresh occurrence only): a short light-gray puff and a short sizzle on the altered food the first
	    time it shows up on the rail or the board (anomalies.md N2 "Som de chiado curto quando surge"; AST-095). A late
	    joiner (Mount more than FRESH s after StartedAt) gets no puff: the item is already there.
	  - Cue `smoke` (Entity = NpcId of the customer that got the hot dog): the hot dog turns to smoke on the bite,
	    light-gray puff in front of the customer's mouth, `Emit(8)`, ~0.8 s (style guide §10), sound `smoke_poof`.
	    Seen by every client (the cue goes to everyone). The customer's frown and leaving belong to the customer flow.

	No VFX points at anything the player must act on beyond the item itself (anomalies.md §4.4).

	PROVISIONAL (frontend-coder, TASK-114): (a) built-in smoke texture until the AST-092 wisp sheet exists; (b) the sign
	sizzle is `grill_sizzle` played once (no short sizzle key in Content.Sounds yet, Q-168); (c) the sign puff finds the
	food by the clone names of KitchenController/Slots.Food (`SausageWrong_Slot<n>`, `BunBitten_Slot<n>`, children
	of the station model); if the kit draws nothing, there is no puff.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)

const REF = "ANM-002"
const SMOKE_CUE = "smoke"
const SMOKE_SOUND = "smoke_poof"
const SIGN_SOUND = "grill_sizzle"
const STATION_TAG = "Station"
const STATION_KINDS = { rail = true, board = true } :: { [string]: boolean }
const ALTERED_PREFIXES = { "SausageWrong_Slot", "BunBitten_Slot" }

const FRESH = 2 -- s after StartedAt: later Mounts are late joiners (no sign puff)
const SIGN_WAIT = 2 -- s to wait for the KitchenController to draw the item (sets may arrive in any order)
const POLL = 0.1
const SIGN_COUNT = 4
const SIGN_LIFE = 0.6
const SIGN_SIZE = 0.5
const BITE_COUNT = 8 -- style guide §10
const BITE_LIFE = 0.8
const BITE_SIZE = 0.9
const BITE_OFFSET = CFrame.new(0, -0.3, -0.8) -- in front of the mouth, Head space
const BODY_OFFSET = CFrame.new(0, 1.5, -0.8) -- no Head: rig pivot space

const SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
const SMOKE_COLOR = ColorSequence.new(Color3.fromRGB(232, 232, 236), Color3.fromRGB(205, 207, 214))

-- Altered food models that already got their sign puff (one puff per drawn item)
const puffed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function keypoint(time: number, value: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(time, value)
end

-- Short local smoke burst at `at`, under the effects folder; destroys itself.
local function puff(ctx: Effect.Context, at: CFrame, count: number, life: number, size: number, hold: number?)
	const part = Instance.new("Part")
	part.Name = "ANM002_Smoke"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = at

	const emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE_TEXTURE
	emitter.Color = SMOKE_COLOR
	emitter.LightEmission = 0
	emitter.LightInfluence = 0.3 -- still reads at night without glowing
	emitter.Size = NumberSequence.new({ keypoint(0, size * 0.5), keypoint(1, size * 1.6) })
	emitter.Transparency = NumberSequence.new({ keypoint(0, 0.25), keypoint(0.7, 0.6), keypoint(1, 1) })
	emitter.Lifetime = NumberRange.new(life * 0.75, life)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Drag = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = part

	part.Parent = ctx.Folder()
	emitter:Emit(count)
	task.delay(math.max(life + 0.5, hold or 0), function()
		part:Destroy()
	end)
end

local function isAlteredFood(instance: Instance): boolean
	if not instance:IsA("Model") or puffed[instance] then
		return false
	end
	for _, prefix in ALTERED_PREFIXES do
		if string.sub(instance.Name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

-- First altered food clone on a rail or board not puffed yet.
local function findAlteredFood(): Model?
	for _, station in CollectionService:GetTagged(STATION_TAG) do
		const kind = station:GetAttribute("StationKind")
		if typeof(kind) ~= "string" or not STATION_KINDS[kind] then
			continue
		end
		for _, child in station:GetChildren() do
			if isAlteredFood(child) then
				return child :: Model
			end
		end
	end
	return nil
end

-- Where the bite smoke comes out: in front of the customer's mouth.
local function biteAt(rig: Model): CFrame
	const head = rig:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		return head.CFrame * BITE_OFFSET
	end
	return rig:GetPivot() * BODY_OFFSET
end

const WrongFood: Effect.Module = {
	Ref = REF,

	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		if occ.Elapsed() > FRESH then
			return -- late joiner: the item is already on the station, no sign puff
		end
		local alive = true
		Vide.cleanup(function()
			alive = false
		end)
		task.spawn(function()
			const deadline = os.clock() + SIGN_WAIT
			while alive and os.clock() < deadline do
				const food = findAlteredFood()
				if food ~= nil then
					puffed[food] = true
					const at = food:GetPivot()
					puff(ctx, at, SIGN_COUNT, SIGN_LIFE, SIGN_SIZE)
					ctx.Audio:Play(SIGN_SOUND, at.Position, { Volume = 0.8, Speed = 1.3 })
					return
				end
				task.wait(POLL)
			end
		end)
	end,

	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue ~= SMOKE_CUE or cue.Entity == 0 then
			return
		end
		const rig = ctx.Npc(cue.Entity)
		if rig == nil or rig.Parent == nil then
			return -- customer not streamed in / already gone: nothing to show
		end
		const at = biteAt(rig)
		puff(ctx, at, BITE_COUNT, BITE_LIFE, BITE_SIZE, cue.Row.Duration)
		ctx.Play(SMOKE_SOUND, at.Position)
	end,
}

return WrongFood
