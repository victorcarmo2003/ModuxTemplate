--!strict
-- EntityId <-> anchor registry (architecture.md §18.3, T33; network.md §1 rule 5). Pure: no Modux, Lync or Charm.
-- Ids live in 1..65535 and are handed out by a cyclic counter; a released id stays out of use for REUSE_DELAY
-- seconds so a late Interact cannot land on the next anchor that takes it.

const MAX_ID = 65535
const REUSE_DELAY = 10

export type Registry = {
	Cursor: number,
	ById: { [number]: Instance },
	IdOf: { [Instance]: number },
	ReleasedAt: { [number]: number },
}

const Registry = {}

function Registry.new(): Registry
	return {
		Cursor = 0,
		ById = {},
		IdOf = {},
		ReleasedAt = {},
	}
end

local function isFree(registry: Registry, id: number, now: number): boolean
	if registry.ById[id] ~= nil then
		return false
	end
	const releasedAt = registry.ReleasedAt[id]
	if releasedAt ~= nil and now - releasedAt < REUSE_DELAY then
		return false
	end
	return true
end

-- Registers the anchor and returns its id (the existing one if already registered); nil when every id is taken.
function Registry.add(registry: Registry, anchor: Instance, now: number): number?
	const existing = registry.IdOf[anchor]
	if existing ~= nil then
		return existing
	end
	for _ = 1, MAX_ID do
		registry.Cursor = registry.Cursor % MAX_ID + 1
		const id = registry.Cursor
		if isFree(registry, id, now) then
			registry.ById[id] = anchor
			registry.IdOf[anchor] = id
			registry.ReleasedAt[id] = nil
			return id
		end
	end
	return nil
end

-- Unregisters the anchor and returns the id it had (nil if it was not registered).
function Registry.remove(registry: Registry, anchor: Instance, now: number): number?
	const id = registry.IdOf[anchor]
	if id == nil then
		return nil
	end
	registry.IdOf[anchor] = nil
	registry.ById[id] = nil
	registry.ReleasedAt[id] = now
	return id
end

function Registry.get(registry: Registry, id: number): Instance?
	return registry.ById[id]
end

function Registry.idOf(registry: Registry, anchor: Instance): number?
	return registry.IdOf[anchor]
end

-- World position of an anchor: Attachment (preferred) or invisible BasePart (architecture.md §18.3).
function Registry.position(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

return table.freeze(Registry)
