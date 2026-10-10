--!strict
-- ANM-004 The copies (N4; TASK-111; anomalies.md N4; npcs.md NPC-012; DEC-051, DEC-195, DEC-204).
-- An ordinary customer (the original: a normal spawn, counts in the customer cap and the ledger) and its mirrored copy
-- (actor Variant "mirror", CopyOf = original: same type, species and outfit, mirrored on the client — TASK-112) walk to
-- the counter together. Needs Params.FreeSlots free counter slots and NPC cap room, otherwise Start waits.
-- Refuse the copy = resolved. "Take Order" on the copy = Fail of who took it, arrival + Wrong, cue mirror_smile and the
-- copy walks off. Refusing the original is only a lost sale (CustomerService counts it). Copy left waiting = nothing.
-- Never on the same customer as N1: the copy is a "mirror" actor and the original is never an actor (CopyOf refuses).
-- Verb and numbers: Rules/ANM-004.luau. Body: Kit/CustomerActor.
--
-- PROVISIONAL (TASK-111, backend-coder):
--   * both spawn in the same Start, from two different spawn points (npcs.md "<= 10 s apart"; 0 s, no overlap).
--   * Mr. Pickett as the 1st original of Night 4 (NPC-021) is not done: there is no Pickett customer type/look in
--     Content yet; the original is any type of the shift.
--   * copy refused after the original spawned (rare: cap raced): the original stays a normal customer, Start retries.
local Api = require(script.Parent.Parent.Api)
local Kit = require(script.Parent.Kit.CustomerActor)

const SPAWN_TRIES = 4 -- draws for a spawn point different from the original's

local function spawnPair(ctx: Api.Context, occ: Api.Occurrence, rule: Api.Rule, state: Kit.State): number?
	const variant = rule.Params.Variant
	const need = rule.Params.FreeSlots
	if type(variant) ~= "string" or type(need) ~= "number" then
		return nil
	end
	const customers = Kit.Customers()
	const npcs = Kit.Npcs()
	if customers:QueueSize() - customers:Occupants() < need then
		return nil
	end
	if npcs:Capacity() - npcs:Count() < need then
		return nil
	end
	-- the original is an ordinary customer: it must fit in the customer cap too
	if customers:Count() >= customers:MaxCustomers() then
		return nil
	end
	const _, original = customers:Attempt()
	if original == nil then
		return nil
	end
	const from = npcs:GetNode(original)
	local point: string? = nil
	for _ = 1, SPAWN_TRIES do
		const pick = npcs:PickSpawnPoint(true, occ.Rng)
		if pick ~= from then
			point = pick
			break
		end
	end
	const copy = ctx.Spawn({ Variant = variant, CopyOf = original, From = point })
	if copy == nil then
		ctx.Log(occ, `copy of #{original} refused; the original stays an ordinary customer`)
		return nil
	end
	state.Original = original
	return copy
end

return Kit.Module({
	Ref = "ANM-004",
	Spawn = spawnPair,
	FailCue = "mirror_smile",
})
