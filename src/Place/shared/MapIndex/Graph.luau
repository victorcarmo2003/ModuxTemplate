--!strict
-- NpcNode graph (architecture.md §18.6): undirected adjacency from Links and A* with euclidean cost. Ties break by
-- NodeId (string order), so server and client walk the same path (T28, T39). Pure: no Modux, Lync, Vide.

export type Node = {
	Id: string,
	Position: Vector3,
	Links: { string }, -- as authored (may be one-sided)
	Crosswalk: string?,
}

-- Sorted neighbour ids per node, symmetric.
export type Adjacency = { [string]: { string } }

export type PathOptions = {
	AvoidCrossings: boolean?, -- skip crosswalk edges (MAP-01 §9.2)
	-- queue slots Q1..Qn are never intermediate (customers outside the queue walk around it) except the slots behind a
	-- queue goal (Graph.behind: up the line from its tail), and stepping through a
	-- pickup slot PU-n costs PICKUP_PASS more (the lane behind the pickup line wins over walking along the slots, where
	-- the other customers stand; restaurant patio 2026-10-18, PROVISIONAL)
	AvoidQueue: boolean?,
}

const EPSILON = 1e-9
const PICKUP_PASS = 4 -- studs added for walking through a pickup slot that is neither the start nor the goal

const Graph = {}

function Graph.isQueue(id: string): boolean
	return string.match(id, "^Q%d+$") ~= nil
end

-- Queue slot `id` stands behind queue slot `goal` (Q4 behind Q2): walking up the line from its tail passes only free
-- slots (the line fills from Q1), so an AvoidQueue walk to `goal` may step through it. Owner 2026-10-21: Q1 got its own
-- way in from the west corridor; a walk to Q3 must not take it through Q1 and Q2, where customers stand
function Graph.behind(id: string, goal: string): boolean
	const slot = tonumber(string.match(id, "^Q(%d+)$"))
	const target = tonumber(string.match(goal, "^Q(%d+)$"))
	return slot ~= nil and target ~= nil and slot > target
end

function Graph.isPickup(id: string): boolean
	return string.match(id, "^PU%-%d+$") ~= nil
end

-- A crosswalk edge joins the two curb nodes of the same crosswalk (§18.6).
function Graph.isCrossing(a: Node, b: Node): boolean
	return a.Crosswalk ~= nil and a.Crosswalk == b.Crosswalk
end

-- Symmetric adjacency. Unknown ids and self links are left out and reported.
function Graph.adjacency(nodes: { [string]: Node }): (Adjacency, { string })
	const sets: { [string]: { [string]: boolean } } = {}
	const problems: { string } = {}
	for id in nodes do
		sets[id] = {}
	end
	for id, node in nodes do
		for _, link in node.Links do
			if nodes[link] == nil then
				table.insert(problems, `6: {id} links to unknown id {link}`)
			elseif link == id then
				table.insert(problems, `6: {id} links to itself`)
			else
				sets[id][link] = true
				sets[link][id] = true
			end
		end
	end
	const adjacency: Adjacency = {}
	for id, set in sets do
		const list: { string } = {}
		for other in set do
			table.insert(list, other)
		end
		table.sort(list)
		adjacency[id] = list
	end
	return adjacency, problems
end

-- Ids reachable from `start`.
function Graph.reach(adjacency: Adjacency, start: string): { [string]: boolean }
	const seen: { [string]: boolean } = { [start] = true }
	const stack = { start }
	while #stack > 0 do
		const current = table.remove(stack) :: string
		for _, other in adjacency[current] or {} do
			if not seen[other] then
				seen[other] = true
				table.insert(stack, other)
			end
		end
	end
	return seen
end

-- A* from `from` to `to`; nil when either end is unknown or there is no path.
function Graph.path(
	nodes: { [string]: Node },
	adjacency: Adjacency,
	from: string,
	to: string,
	options: PathOptions?
): { string }?
	const goal = nodes[to]
	if nodes[from] == nil or goal == nil then
		return nil
	end
	const avoidCrossings = options ~= nil and options.AvoidCrossings == true
	const avoidQueue = options ~= nil and options.AvoidQueue == true

	const cost: { [string]: number } = { [from] = 0 }
	const came: { [string]: string } = {}
	const open: { [string]: boolean } = { [from] = true }
	const closed: { [string]: boolean } = {}

	while next(open) ~= nil do
		local best: string? = nil
		local bestScore = math.huge
		for id in open do
			const score = cost[id] + (nodes[id].Position - goal.Position).Magnitude
			if score < bestScore - EPSILON or (math.abs(score - bestScore) <= EPSILON and best ~= nil and id < best) then
				best = id
				bestScore = score
			end
		end
		const current = best :: string

		if current == to then
			const path = { current }
			local step = current
			while came[step] ~= nil do
				step = came[step]
				table.insert(path, 1, step)
			end
			return path
		end

		open[current] = nil
		closed[current] = true

		if avoidQueue and current ~= from and Graph.isQueue(current) and not Graph.behind(current, to) then
			continue
		end
		const node = nodes[current]
		const pass = if avoidQueue and current ~= from and Graph.isPickup(current) then PICKUP_PASS else 0
		for _, other in adjacency[current] or {} do
			if closed[other] then
				continue
			end
			const neighbor = nodes[other]
			if avoidCrossings and Graph.isCrossing(node, neighbor) then
				continue
			end
			const total = cost[current] + pass + (node.Position - neighbor.Position).Magnitude
			const known = cost[other]
			if known == nil or total < known - EPSILON then
				cost[other] = total
				came[other] = current
				open[other] = true
			end
		end
	end
	return nil
end

return table.freeze(Graph)
