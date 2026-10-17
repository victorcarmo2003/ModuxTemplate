--!strict
-- Product bays of the stock room (owner request 2026-10-17, Provisional; FEAT-050 extension of TASK-388). Plain module:
-- no Modux, no network. The SupplyService owns one State and decides when boxes come in and go out.
--
-- Map contract: every Model / BasePart tagged StockShelf (in the Workspace) with a string attribute Package = a key of
-- Content.Packages, and an anchor named Prompt_TakeBox (Attachment or BasePart) under it, in front of the bay. A bay with
-- no anchor gets an Attachment at its pivot (warned). Bays with an unknown Package are skipped (warned). Several bays may
-- hold the same package: a box that comes in goes to the one with the fewest boxes (ties: the first bound).
--
-- Stock rule: a bay holds whole boxes (each one = Package.Amount units, a full Mart package). It fills only from the
-- phone (boxes of its package that arrive go straight to it instead of the hatch) and from the start boxes of the run;
-- "Take <Package>" takes one. Optional number attribute StartBoxes on a bay overrides Content.Restaurant.Supply.StartBoxes
-- for that bay at the start of Night 1. The server writes the number attribute Boxes on the bay (count for the client).
local CollectionService = game:GetService("CollectionService")

export type Shelf = {
	Id: number, -- bind order (1..n), stable for a server
	Package: string,
	Root: Instance,
	Anchor: Instance,
	Boxes: number,
	Start: number?, -- StartBoxes attribute of the map, nil = Content
}

export type State = {
	List: { Shelf },
	ByAnchor: { [Instance]: Shelf },
}

const TAG = "StockShelf"
const PACKAGE = "Package"
const ANCHOR = "Prompt_TakeBox"
const START = "StartBoxes"
const BOXES = "Boxes"

const Shelves = {}

Shelves.Tag = TAG
Shelves.Anchor = ANCHOR

function Shelves.new(): State
	return { List = {}, ByAnchor = {} }
end

local function anchorOf(root: Instance): Instance?
	if root.Name == ANCHOR then
		return root
	end
	const found = root:FindFirstChild(ANCHOR, true)
	if found ~= nil and (found:IsA("Attachment") or found:IsA("BasePart")) then
		return found
	end
	-- no anchor: an Attachment at the bay's pivot (on its first BasePart)
	const part = if root:IsA("BasePart")
		then root
		elseif root:IsA("Model") then root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
		else nil
	if part == nil then
		return nil
	end
	warn(`[SupplyService] {root:GetFullName()}: no {ANCHOR}, made an Attachment at its centre`)
	const attachment = Instance.new("Attachment")
	attachment.Name = ANCHOR
	attachment.Parent = part
	return attachment
end

-- Binds every tagged bay in the Workspace. known = Content.Packages.ByKey
function Shelves.bind(state: State, known: { [string]: any }): number
	const roots = CollectionService:GetTagged(TAG)
	table.sort(roots, function(a: Instance, b: Instance): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	for _, root in roots do
		if not root:IsDescendantOf(workspace) then
			continue
		end
		const package = root:GetAttribute(PACKAGE)
		if type(package) ~= "string" or known[package] == nil then
			warn(`[SupplyService] {root:GetFullName()}: {PACKAGE} must be a Content.Packages key (got {tostring(package)})`)
			continue
		end
		const anchor = anchorOf(root)
		if anchor == nil then
			warn(`[SupplyService] {root:GetFullName()}: no {ANCHOR} and no BasePart to put one on`)
			continue
		end
		if state.ByAnchor[anchor] ~= nil then
			continue
		end
		const start = root:GetAttribute(START)
		const shelf: Shelf = {
			Id = #state.List + 1,
			Package = package,
			Root = root,
			Anchor = anchor,
			Boxes = 0,
			Start = if type(start) == "number" and start >= 0 then math.floor(start) else nil,
		}
		table.insert(state.List, shelf)
		state.ByAnchor[anchor] = shelf
	end
	return #state.List
end

function Shelves.has(state: State, package: string): boolean
	for _, shelf in state.List do
		if shelf.Package == package then
			return true
		end
	end
	return false
end

-- Bay that takes the next box of this package (fewest boxes), nil = no bay for it
function Shelves.target(state: State, package: string): Shelf?
	local best: Shelf? = nil
	for _, shelf in state.List do
		if shelf.Package == package and (best == nil or shelf.Boxes < best.Boxes) then
			best = shelf
		end
	end
	return best
end

-- Boxes on the bays, by package
function Shelves.totals(state: State): { [string]: number }
	const out: { [string]: number } = {}
	for _, shelf in state.List do
		out[shelf.Package] = (out[shelf.Package] or 0) + shelf.Boxes
	end
	return out
end

function Shelves.clear(state: State)
	for _, shelf in state.List do
		shelf.Boxes = 0
	end
end

-- Count for the client (attribute on the bay root)
function Shelves.mark(shelf: Shelf)
	shelf.Root:SetAttribute(BOXES, shelf.Boxes)
end

-- Bays of a package with the StartBoxes attribute (they replace the Content start count for that package)
function Shelves.authoredStart(state: State, package: string): boolean
	for _, shelf in state.List do
		if shelf.Package == package and shelf.Start ~= nil then
			return true
		end
	end
	return false
end

return table.freeze(Shelves)
