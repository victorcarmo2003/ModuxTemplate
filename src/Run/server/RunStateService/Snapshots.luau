--!strict
-- Shift snapshot registry (architecture.md §7; data.md §3.3; T12). Plain module, no Modux and no network: the
-- RunStateService owns one registry and decides when to capture and restore.
-- A snapshot is { V, At, [name] = capture() } with the names chosen by each Service (data.md §3.3 uses short keys:
-- Run, M, Sh, Cash, Veh, Stk, Upg, Bn). Wave 1 keeps the last capture in memory; wave 2 hands it to SessionService
-- (MemoryStore Snap[RunId]) with the same shape.
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

export type Mode = "RepeatNight" | "Resume"
export type Capture = () -> any
export type Restore = (data: any, mode: Mode) -> ()
export type Entry = { Name: string, Capture: Capture, Restore: Restore }
export type Snapshot = { [string]: any }
export type Registry = { Entries: { Entry }, Last: Snapshot? }

const VERSION = 1 -- data.md §3.3 (format never published: still V = 1)
const TARGET_BYTES = 2048 -- target size (data.md §3.3)
const MAX_BYTES = 8192 -- hard ceiling: error in Studio, log in production
const RESERVED: { [string]: boolean } = { V = true, At = true }

local function fail(message: string)
	if RunService:IsStudio() then
		error(message, 0)
	end
	warn(message)
end

const Snapshots = {}

function Snapshots.new(): Registry
	return { Entries = {}, Last = nil }
end

-- Called by Services in OnInit. Duplicate or reserved names are programmer errors.
function Snapshots.register(registry: Registry, name: string, capture: Capture, restore: Restore)
	if RESERVED[name] then
		error(`[RunStateService] snapshot name {name} is reserved`, 3)
	end
	for _, entry in registry.Entries do
		if entry.Name == name then
			error(`[RunStateService] snapshot {name} registered twice`, 3)
		end
	end
	table.insert(registry.Entries, { Name = name, Capture = capture, Restore = restore })
end

-- Serialized size in bytes (JSON, the MemoryStore format).
function Snapshots.size(snapshot: Snapshot): number
	return #HttpService:JSONEncode(snapshot)
end

-- Runs every capture; a failing capture is reported and left out (the others still go in).
function Snapshots.capture(registry: Registry): Snapshot
	const snapshot: Snapshot = { V = VERSION, At = os.time() }
	for _, entry in registry.Entries do
		const ok, result = pcall(entry.Capture)
		if ok then
			snapshot[entry.Name] = result
		else
			fail(`[RunStateService] snapshot capture {entry.Name} failed: {result}`)
		end
	end

	const ok, size = pcall(Snapshots.size, snapshot)
	if not ok then
		fail(`[RunStateService] snapshot is not JSON-encodable: {size}`)
	elseif size > MAX_BYTES then
		fail(`[RunStateService] snapshot is {size} bytes (ceiling {MAX_BYTES})`)
	elseif size > TARGET_BYTES then
		warn(`[RunStateService] snapshot is {size} bytes (target {TARGET_BYTES})`)
	end

	registry.Last = snapshot
	return snapshot
end

-- Restores the last capture in registration order. False when nothing was captured yet.
function Snapshots.restore(registry: Registry, mode: Mode): boolean
	const snapshot = registry.Last
	if snapshot == nil then
		return false
	end
	for _, entry in registry.Entries do
		const data = snapshot[entry.Name]
		if data == nil then
			continue
		end
		const ok, problem = pcall(entry.Restore, data, mode)
		if not ok then
			fail(`[RunStateService] snapshot restore {entry.Name} failed: {problem}`)
		end
	end
	return true
end

return table.freeze(Snapshots)
