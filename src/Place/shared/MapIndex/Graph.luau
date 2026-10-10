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
	AvoidCrossings: boolean?, -- skip crosswalk edges (thief, MAP-01 §9.2)
	AvoidQueue: boolean?, -- queue slots Q1..Qn are never intermediate (customers outside the queue walk around it)
}

const EPSILON = 1e-9

const Graph = {}

function Graph.isQueue(id: string): boolean
	return string.match(id, "^Q%d+$") ~= nil
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

		if avoidQueue and current ~= from and Graph.isQueue(current) then
			continue
		end
		const node = nodes[current]
		for _, other in adjacency[current] or {} do
			if closed[other] then
				continue
			end
			const neighbor = nodes[other]
			if avoidCrossings and Graph.isCrossing(node, neighbor) then
				continue
			end
			const total = cost[current] + (node.Position - neighbor.Position).Magnitude
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
