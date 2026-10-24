--!strict
--[[
	ANM-001 The blank folks, client effect (TASK-112; anomalies.md N1; style guide §4.4, §10; AST-060, AST-082;
	DEC-195). Presents what AnomalyService/Anomalies/ANM-001 (TASK-111) decides; never a verb or a payment.

	Already done elsewhere (TASK-110): the blank face (RigController, Variant "blank": CrewExpressions.Blank on the face
	shell; owner 2026-10-22: the head keeps the species' own skin, it is no longer swapped for the AST-060 flat head) and
	an order bubble without topping icons (CustomerController). Here:
	  - the tic (owner 2026-10-22, Provisional; Content.Tics "blank", Kit/Tic Body "Face"): it arrives with its own face
	    and mood (the cameras already show it blank); in the order talk the face fades out while the line drops its
	    letters, and from the apex it is faceless for everyone (the residue, the delivery queue), with the taker's tension;
	  - no breathing: while the actor stands, its idle is held on the first frame (Kit.HoldStill), bound to the rig's
	    Variant so it lasts while it walks off slowly after the record is gone;
	  - cue `blank_coin` (DEC-195 flavor, sent on "Take Order" = the failure): a coin with no design hops from the
	    actor to the drawer of the vehicle in use and lies there. Visual only: the Drawer never changes (server), no
	    sound (cue Kind Visual). It goes with the night (AnomalyController empties its folder when IsNight falls,
	    anomalies.md "some da gaveta no fim do turno").

	Placeholder (AST-082 has no mesh yet): flat Mustard cylinder 0.4 Ø × 0.08 with a smooth face; a `Coin_Blank`
	anywhere under ReplicatedStorage.Assets (BasePart or Model) replaces it when the kit has it. Provisional.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Effect = require(script.Parent.Parent.Effect)
local Kit = require(script.Parent.Kit.CustomerActor)
local Jumpscare = require(script.Parent.Kit.Jumpscare)
local Tic = require(script.Parent.Kit.Tic)

const VARIANT = "blank"
const COIN_NAME = "Coin_Blank"
const COIN_SIZE = Vector3.new(0.08, 0.4, 0.4) -- cylinder axis = X; laid flat below
const MUSTARD = Color3.fromHex("#F6C12B") -- AST-082: Mustard, never Gold
const FLAT = CFrame.Angles(0, 0, math.rad(90))
const HOP_TIME = 0.5 -- s
const HOP_HEIGHT = 1.5 -- studs over the straight line
const SPREAD = 0.25 -- studs of random offset on the drawer
const MAX_COINS = 6 -- older blank coins go first
const VEHICLE_TAG = "Vehicle"
const VEHICLE_ATTRIBUTE = "Vehicle"
const ANCHOR_NAME = "Value_Anchor" -- EconomyController's drawer anchor (architecture.md §18.3)
const DRAWER_MAP_ID = "DRAWER"

local kitCoin: Instance? = nil
local kitLooked = false

-- Coin model of the kit (once), else nil = placeholder.
local function kitTemplate(): Instance?
	if not kitLooked then
		kitLooked = true
		const assets = ReplicatedStorage:FindFirstChild("Assets")
		const found = if assets then assets:FindFirstChild(COIN_NAME, true) else nil
		if found ~= nil and (found:IsA("BasePart") or found:IsA("Model")) then
			kitCoin = found
		end
	end
	return kitCoin
end

local function newCoin(): PVInstance
	const template = kitTemplate()
	if template ~= nil then
		const clone = template:Clone() :: PVInstance
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
			end
		end
		if clone:IsA("BasePart") then
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
		end
		clone.Name = COIN_NAME
		return clone
	end
	const coin = Kit.Part(COIN_NAME, COIN_SIZE, MUSTARD)
	coin.Shape = Enum.PartType.Cylinder
	return coin
end

-- Where the coin lies: the drawer anchor of the vehicle in use (same lookup as EconomyController).
local function drawerTop(ctx: Effect.Context): Vector3?
	const current = ctx.Round.Vehicle()
	for _, vehicle in CollectionService:GetTagged(VEHICLE_TAG) do
		if vehicle:GetAttribute(VEHICLE_ATTRIBUTE) ~= current or not vehicle:IsDescendantOf(Workspace) then
			continue
		end
		local best: Vector3? = nil
		local bestY = -math.huge
		for _, descendant in vehicle:GetDescendants() do
			if descendant.Name == ANCHOR_NAME then
				if descendant:IsA("Attachment") then
					return descendant.WorldPosition
				elseif descendant:IsA("BasePart") then
					return descendant.Position + Vector3.new(0, descendant.Size.Y / 2, 0)
				end
			elseif descendant:IsA("Model") and (descendant:GetAttribute("MapId") == DRAWER_MAP_ID or descendant:GetAttribute("MapId") == "TRL-TIPJAR") then
				for _, piece in descendant:GetDescendants() do
					if piece:IsA("BasePart") then
						const top = piece.Position.Y + piece.Size.Y / 2
						if top > bestY then
							bestY = top
							best = Vector3.new(piece.Position.X, top, piece.Position.Z)
						end
					end
				end
			end
		end
		if best ~= nil then
			return best
		end
	end
	return nil
end

local function trim(folder: Folder)
	const coins: { Instance } = {}
	for _, child in folder:GetChildren() do
		if child.Name == COIN_NAME then
			table.insert(coins, child)
		end
	end
	for index = 1, #coins - MAX_COINS + 1 do
		coins[index]:Destroy()
	end
end

local function blankCoin(ctx: Effect.Context, cue: Effect.Cue)
	const top = drawerTop(ctx)
	if top == nil then
		return -- no drawer drawn here (streamed out): nothing to see
	end
	const rest = top
		+ Vector3.new((cue.Rng:NextNumber() * 2 - 1) * SPREAD, COIN_SIZE.X / 2, (cue.Rng:NextNumber() * 2 - 1) * SPREAD)
	const spin = CFrame.Angles(0, cue.Rng:NextNumber() * math.pi * 2, 0)

	const actor = if cue.Entity > 0 then ctx.Npc(cue.Entity) else nil
	const root = if actor ~= nil then Kit.Root(actor) else nil
	const from = if root ~= nil then root.Position else rest + Vector3.new(0, HOP_HEIGHT, 0)

	const folder = ctx.Folder()
	trim(folder)
	const coin = newCoin()
	coin:PivotTo(CFrame.new(from) * spin * FLAT)
	coin.Parent = folder

	const started = os.clock()
	while coin.Parent ~= nil do
		const t = math.clamp((os.clock() - started) / HOP_TIME, 0, 1)
		const position = from:Lerp(rest, t) + Vector3.new(0, HOP_HEIGHT * 4 * t * (1 - t), 0)
		coin:PivotTo(CFrame.new(position) * spin * FLAT)
		if t >= 1 then
			break
		end
		task.wait()
	end
end

return {
	Ref = "ANM-001",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		Vide.cleanup(Kit.Follow(ctx, occ, VARIANT, "blank_still", function(model: Model): Kit.Undo
			return Kit.HoldStill(ctx, model)
		end))
		-- the face that fades in the talk and the taker's tension (Kit/Tic); without the row the face is blank from the
		-- spawn as before (RigController), rollback = remove the row
		const tic = Content.Tics.ByVariant[VARIANT]
		if tic ~= nil then
			Vide.cleanup(Kit.Follow(ctx, occ, VARIANT, "blank_tic", function(model: Model): Kit.Undo
				return Tic.Mount(ctx, model, tic)
			end))
		end
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "blank_coin" then
			blankCoin(ctx, cue)
		elseif cue.Cue == "jumpscare" then
			Jumpscare.Cue(ctx, cue) -- V2 error (DEC-255, TASK-269)
		end
	end,
} :: Effect.Module
