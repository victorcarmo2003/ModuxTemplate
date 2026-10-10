--!strict
--[[
	ANM-004 The copies, client effect (TASK-112; anomalies.md N4; style guide §2.4, §4.4; AST-062, AST-081).
	Presents what AnomalyService/Anomalies/ANM-004 (TASK-111) decides; never a verb or a payment.

	Already done elsewhere (TASK-110): the mirrored outfit sheet `<outfit>_mirror` (RigController, Variant
	"mirror"; inverted shirt text = the main read on a phone). Here:
	  - accessories on the other side: every accessory piece of the copy (parts with the `Accessory` attribute,
	    CrewRig.Build) welded to a side limb, or off-centre on the head/torso, is hidden locally
	    (LocalTransparencyModifier) and a local clone is welded at its mirror image on the opposite limb. The server's
	    pieces and welds are never changed. Bound to the rig's Variant (Kit.WhileVariant): the copy stays mirrored while
	    it walks off, and a pooled rig gets its pieces back.
	  - cue `mirror_smile` (DEC-195 flavor, sent on "Take Order" on the copy = the failure): the copy smiles and the
	    smile holds a second longer than it should (Smile for the cue Duration + HOLD_EXTRA), then the face goes back
	    to whatever the customer layer set; the walk-away plays `copy_backwalk` (AST-069; Id "" = nothing until the
	    clip exists) while the rig is still the copy.
	Nothing else differs from the original (AST-062 "Proibido": colour, size, face).

	Provisional (frontend-coder): the clone is the same mesh, so a piece with its own handedness (watch face) reads
	"other wrist", not "mirrored mesh"; mirrored hair meshes (3 parted hairs, AST-062) come with the kit.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Effect = require(script.Parent.Parent.Effect)
local Kit = require(script.Parent.Kit.CustomerActor)

const VARIANT = "mirror"
const ACCESSORY_ATTRIBUTE = "Accessory" -- CrewRig.Build marks every accessory piece
const CLONE_ATTRIBUTE = "MirrorOf" -- local clones (never confused with a server piece)
const CENTRE = 0.15 -- studs: head/torso pieces closer than this to the middle are symmetric enough
const SMILE = "Smile" -- Content.Looks.Expressions
const HOLD_EXTRA = 1 -- s: "o sorriso fica parado um segundo a mais"
const HOLD_STEP = 0.1
const BACKWALK = "copy_backwalk" -- Content.Animations (N4)
const OPPOSITE: { [string]: string } = {
	["Left Arm"] = "Right Arm",
	["Right Arm"] = "Left Arm",
	["Left Leg"] = "Right Leg",
	["Right Leg"] = "Left Leg",
}

-- Mirror image across the limb's YZ plane (R6: local X is the rig's side axis): S * cf * S, S = diag(-1, 1, 1).
local function reflect(cf: CFrame): CFrame
	const x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

-- Limb a piece is welded to (CrewRig.Build: WeldConstraint inside the piece, Part0 = limb).
local function anchorOf(piece: BasePart): BasePart?
	for _, child in piece:GetChildren() do
		if child:IsA("WeldConstraint") then
			const other = if child.Part0 == piece then child.Part1 else child.Part0
			if other ~= nil then
				return other
			end
		end
	end
	return nil
end

local function mirrorAccessories(model: Model): Kit.Undo
	const hidden: { BasePart } = {}
	const clones: { BasePart } = {}
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") or child:GetAttribute(ACCESSORY_ATTRIBUTE) == nil then
			continue
		end
		if child:GetAttribute(CLONE_ATTRIBUTE) ~= nil then
			continue
		end
		const anchor = anchorOf(child)
		if anchor == nil then
			continue
		end
		const offset = anchor.CFrame:ToObjectSpace(child.CFrame)
		const oppositeName = OPPOSITE[anchor.Name]
		if oppositeName == nil and math.abs(offset.X) < CENTRE then
			continue -- centred on the head/torso: the mirror image is the same place
		end
		const target = if oppositeName ~= nil then Kit.Limb(model, oppositeName) else anchor
		if target == nil then
			continue
		end
		const clone = child:Clone()
		for _, inner in clone:GetChildren() do
			if inner:IsA("WeldConstraint") or inner:IsA("JointInstance") then
				inner:Destroy()
			end
		end
		clone:SetAttribute(ACCESSORY_ATTRIBUTE, nil)
		clone:SetAttribute(CLONE_ATTRIBUTE, child.Name)
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.LocalTransparencyModifier = 0
		Kit.Attach(clone, target, reflect(offset))
		child.LocalTransparencyModifier = 1
		table.insert(hidden, child)
		table.insert(clones, clone)
	end
	return function()
		for _, clone in clones do
			clone:Destroy()
		end
		for _, piece in hidden do
			piece.LocalTransparencyModifier = 0
		end
	end
end

-- The copy smiles a second too long, then walks off (backwards when the clip exists).
local function mirrorSmile(ctx: Effect.Context, cue: Effect.Cue)
	const model = if cue.Entity > 0 then ctx.Npc(cue.Entity) else nil
	if model == nil or Kit.VariantOf(model) ~= VARIANT then
		return
	end
	const rig = ctx.Rig
	-- whatever the customer layer writes meanwhile is kept and given back at the end
	local latest = rig.Expressions[model]
	rig:SetExpression(model, SMILE)
	Kit.WhileVariant(model, VARIANT, "mirror_backwalk", function(target: Model): Kit.Undo
		ctx.Anim:Play(target, BACKWALK, { Looped = true })
		return function()
			ctx.Anim:Stop(target, BACKWALK)
		end
	end)
	const ends = os.clock() + cue.Row.Duration + HOLD_EXTRA
	while os.clock() < ends and model.Parent ~= nil do
		const now = rig.Expressions[model]
		if now ~= SMILE then
			latest = now
			rig:SetExpression(model, SMILE)
		end
		task.wait(HOLD_STEP)
	end
	if rig.Expressions[model] == SMILE then
		rig:SetExpression(model, latest)
	end
end

return {
	Ref = "ANM-004",
	Mount = function(ctx: Effect.Context, occ: Effect.Occurrence)
		Vide.cleanup(Kit.Follow(ctx, occ, VARIANT, "mirror_accessories", mirrorAccessories))
	end,
	Cue = function(ctx: Effect.Context, cue: Effect.Cue)
		if cue.Cue == "mirror_smile" then
			mirrorSmile(ctx, cue)
		end
	end,
} :: Effect.Module
