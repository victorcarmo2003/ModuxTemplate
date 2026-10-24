--!strict
--[[
	Carried tension (owner 2026-10-22, Provisional; Content.Tics header "The taker's tension"). The customer anomalies whose
	tension THIS client already carries: Effects/Kit/Tic marks an actor (its NpcId = the record's Anchor) the moment this
	client saw the apex of its tic in its own close-up, and clears it when her record is Resolved / Failed / gone.
	While an actor is carried:
	  - Scene/init skips the Queue steps of its scene whose kind is in Content.Tics.Rules.Carry (and the screen sounds of
	    Rules.CarrySounds): the bars, words, heart, edges and colour do not start over when her order is taken
	  - Score/init skips the hint's caption on Queue (the title came at the apex)
	Local only, nothing replicated.
]]
const carried: { [number]: number } = {} -- NpcId -> server time of the apex

const Carry = {}

-- `at` = server time of the apex (nil = no longer carried)
function Carry.Set(npc: number, at: number?)
	carried[npc] = at
end

function Carry.Has(npc: number?): boolean
	return npc ~= nil and npc ~= 0 and carried[npc] ~= nil
end

return table.freeze(Carry)
