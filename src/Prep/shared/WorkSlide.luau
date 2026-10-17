--!strict
-- Sliding grill Work prompt (TASK-354; owner request 2026-10-17, Provisional; Content.Prep.WorkSlide).
-- The Work prompt of the grill follows the player along the counter: its position is the authored anchor moved along the
-- counter axis to the player's projection, clamped to [0, Fraction] of the counter measured from the end nearest the
-- authored anchor (the grill end). Past Fraction it stays at that limit. Height and depth of the anchor never change.
-- The counter is the bounding box of the Model named WorkSlide.Model (PrepTargets) in an ancestor of the anchor.
-- Used by the client (PrepController moves the Attachment locally, presentation) and by the server (InteractionService
-- range check and PrepService:WorkDistance use the same point for that player). Pure: no Modux, Lync or Vide.
-- ReplicatedStorage.shared.Prep.WorkSlide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

const WORK_ACTION = "prep_work"
const rules = Content.Prep.WorkSlide

export type Bench = {
	Start: Vector3, -- end of the counter nearest the authored anchor
	Axis: Vector3, -- unit, from Start along the counter
	Length: number,
	Pivot: CFrame, -- pivot of the counter Model when measured (recomputed when it moves)
}

const WorkSlide = {}

const benches: { [Model]: Bench } = setmetatable({}, { __mode = "k" }) :: any

-- true = this anchor is the sliding one (PromptAction prep_work, PromptStep = WorkSlide.Step)
function WorkSlide.Applies(anchor: Instance): boolean
	return anchor:GetAttribute("PromptAction") == WORK_ACTION and anchor:GetAttribute("PromptStep") == rules.Step
end

-- The counter Model of an anchor: a child named WorkSlide.Model of one of its ancestors (nil = none, no sliding)
function WorkSlide.Counter(anchor: Instance): Model?
	local current = anchor.Parent
	while current ~= nil and current ~= workspace do
		const found = current:FindFirstChild(rules.Model)
		if found ~= nil and found:IsA("Model") then
			return found
		end
		current = current.Parent
	end
	return nil
end

-- Axis of the counter (its longest horizontal side), oriented from the end nearest `authored`
function WorkSlide.Bench(counter: Model, authored: Vector3): Bench
	const pivot = counter:GetPivot()
	const cached = benches[counter]
	if cached ~= nil and cached.Pivot == pivot then
		return cached
	end
	const cf, size = counter:GetBoundingBox()
	const alongX = size.X >= size.Z
	local axis = if alongX then cf.RightVector else cf.LookVector
	const length = if alongX then size.X else size.Z
	local start = cf.Position - axis * (length / 2)
	const other = cf.Position + axis * (length / 2)
	if (authored - other):Dot(axis) ^ 2 < (authored - start):Dot(axis) ^ 2 then
		start = other
		axis = -axis
	end
	const bench: Bench = { Start = start, Axis = axis, Length = length, Pivot = pivot }
	benches[counter] = bench
	return bench
end

-- Where the prompt is for a player standing at `root`. `authored` = the anchor's own world position (the server's; the
-- client keeps the one it saw before moving it). No counter = `authored`.
function WorkSlide.Position(anchor: Instance, authored: Vector3, root: Vector3): Vector3
	const counter = WorkSlide.Counter(anchor)
	if counter == nil then
		return authored
	end
	const bench = WorkSlide.Bench(counter, authored)
	if bench.Length <= 0 then
		return authored
	end
	const t = math.clamp((root - bench.Start):Dot(bench.Axis) / bench.Length, 0, rules.Fraction)
	const along = (authored - bench.Start):Dot(bench.Axis)
	return authored + bench.Axis * (t * bench.Length - along)
end

return table.freeze(WorkSlide)
