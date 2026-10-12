--!strict
--[[
	Hide: during a cutscene this client sees ONE avatar, its own (owner request 2026-10-12). Every other player's
	character is hidden locally: parts and decals invisible, name tags / overhead GUIs / emitters off, the Humanoid's
	name plate off. Nothing is replicated and nothing is destroyed: the server and the other clients are untouched, and
	every change is remembered so Restore() puts it back exactly (also when the chain is skipped).

	Update() sweeps again at a low rate: a mate's character that spawns, or an accessory that loads, in the middle of
	the scene is hidden too.
]]
local Players = game:GetService("Players")

const SWEEP_EVERY = 0.25 -- s between two sweeps

export type Hide = {
	Update: () -> (),
	Restore: () -> (),
}

const Hide = {}

function Hide.new(): Hide
	-- instance -> value it had before (parts: LocalTransparencyModifier; gui/emitters: Enabled; humanoid: plate)
	const touched: { [Instance]: any } = {}
	local last = -math.huge
	local active = true

	local function hideInstance(instance: Instance)
		if touched[instance] ~= nil then
			return
		end
		if instance:IsA("BasePart") then
			touched[instance] = instance.LocalTransparencyModifier
			instance.LocalTransparencyModifier = 1
		elseif instance:IsA("Decal") then
			-- Decal/Texture: LocalTransparencyModifier exists on both (the face is a Decal)
			const decal = instance :: any
			touched[instance] = decal.LocalTransparencyModifier
			decal.LocalTransparencyModifier = 1
		elseif instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
			touched[instance] = instance.Enabled
			instance.Enabled = false
		elseif
			instance:IsA("ParticleEmitter")
			or instance:IsA("Beam")
			or instance:IsA("Trail")
			or instance:IsA("Light")
			or instance:IsA("Fire")
			or instance:IsA("Smoke")
			or instance:IsA("Sparkles")
		then
			const effect = instance :: any
			touched[instance] = effect.Enabled
			effect.Enabled = false
		elseif instance:IsA("Humanoid") then
			touched[instance] = instance.DisplayDistanceType
			instance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end

	local function hideCharacter(character: Model)
		hideInstance(character)
		for _, descendant in character:GetDescendants() do
			hideInstance(descendant)
		end
	end

	local function sweep()
		for _, player in Players:GetPlayers() do
			if player == Players.LocalPlayer then
				continue
			end
			const character = player.Character
			if character ~= nil then
				hideCharacter(character)
			end
		end
	end

	return {
		Update = function()
			if not active then
				return
			end
			const now = os.clock()
			if now - last < SWEEP_EVERY then
				return
			end
			last = now
			sweep()
		end,
		Restore = function()
			active = false
			for instance, before in touched do
				if instance.Parent == nil then
					continue
				end
				if instance:IsA("BasePart") then
					instance.LocalTransparencyModifier = before :: number
				elseif instance:IsA("Decal") then
					(instance :: any).LocalTransparencyModifier = before
				elseif instance:IsA("Humanoid") then
					instance.DisplayDistanceType = before :: Enum.HumanoidDisplayDistanceType
				else
					(instance :: any).Enabled = before
				end
			end
			table.clear(touched)
		end,
	}
end

return table.freeze(Hide)
