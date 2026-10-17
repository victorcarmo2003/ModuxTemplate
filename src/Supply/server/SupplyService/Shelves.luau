--!strict
-- Product bays of the stock room (owner request 2026-10-17, Provisional; FEAT-050 extension of TASK-388). Plain module:
-- no Modux, no network. The SupplyService owns one State and gives the boxes.
--
-- Map contract: every Model / BasePart tagged StockShelf (in the Workspace) with a string attribute Package = a key of
-- Content.Packages, and an anchor named Prompt_TakeBox (Attachment or BasePart) under it, in front of the bay. A bay with
-- no anchor gets an Attachment at its pivot (warned). Bays with an unknown Package are skipped (warned). Several bays may
-- hold the same package.
--
-- Stock rule (owner 2026-10-17, Provisional): the stock room is infinite. A bay has no count and never runs out:
-- "Take <Package>" always gives one box (a full Mart package, Package.Amount units). The limit is the stations' Capacity
-- (KitchenService Restock); the package limit in hand is ItemService's.
local CollectionService = game:GetService("CollectionService")

export type Shelf = {
	Id: number, -- bind order (1..n), stable for a server
	Package: string,
	Root: Instance,
	Anchor: Instance,
}

export type State = {
	List: { Shelf },
	ByAnchor: { [Instance]: Shelf },
}

const TAG = "StockShelf"
const PACKAGE = "Package"
const ANCHOR = "Prompt_TakeBox"

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
		const shelf: Shelf = {
			Id = #state.List + 1,
			Package = package,
			Root = root,
			Anchor = anchor,
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

return table.freeze(Shelves)
