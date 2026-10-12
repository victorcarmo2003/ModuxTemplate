--!strict
-- World/Types: the vocabulary the 3D prep layers share (docs/tech/prep-3d.md §2, TASK-194). Types and a few constants only, no
-- state: TASK-196 (Ray, Aim, Targets, Marker), 197 (Plane), 198 (views, Rig), 199 (PrepShell) and 203..209 (stages) all read
-- the same names from here, so a name changes in this file or not at all. Data (kinds, tools, tag and attribute names, budget)
-- lives in Content.Prep; nothing here duplicates a number.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrepContent = require(ReplicatedStorage.shared.Content.Prep)

export type TargetKind = PrepContent.TargetKind
export type ToolKind = PrepContent.ToolKind
export type SlotPhase = PrepContent.SlotPhase
export type ViewKey = PrepContent.ViewKey
export type PrepTarget = PrepContent.PrepTarget
export type Band = PrepContent.Band

-- Where the pointer comes from (Pointer.luau / Cursor.luau). Decides hover (mouse, gamepad cursor), the touch offset
-- (Rules.TouchOffset) and the pulsing invitation (touch has no hover).
export type PointerKind = "Mouse" | "Touch" | "Gamepad"

-- One entry of the Targets registry (World/Targets, TASK-196). `Target` is the identity; the rest is live state.
export type Target = {
	Target: PrepTarget,
	Parts: { BasePart }, -- the hitboxes (tag Rules.World.Tag); a fallback box from the model when authoring is missing
	Model: Instance?, -- the real object the hitbox belongs to (Highlight adornee, hover grow)
	-- evaluated on every hover / press: a disabled target is neither hit nor highlighted
	Enabled: () -> boolean,
	Pulse: boolean, -- the invitation: pulses by itself (touch) even without hover
}

-- A ray result (World/Ray + Aim). Hit = the nearest enabled target, nil = the ray touched none.
export type Hit = {
	Target: Target?,
	Position: Vector3, -- world point of the hit (or of the work plane when nothing was hit)
	Distance: number,
}

-- What Aim tells the stage that owns the front tab (Stage3D.OnAim). Move is only sent during a drag, at most once a frame.
export type AimMsg =
	{ Kind: "Hover", Target: Target?, Previous: Target?, Pointer: PointerKind }
	| { Kind: "Press", Target: Target, Point: Vector3, Pointer: PointerKind }
	| { Kind: "Move", Source: Target, Point: Vector3, Over: Target? }
	| { Kind: "Release", Source: Target, Point: Vector3 }
	| { Kind: "Drop", Source: Target, Over: Target, Point: Vector3 }
	| { Kind: "Tap", Target: Target, Point: Vector3 }
	| { Kind: "Cancel", Source: Target?, Reason: string }

-- Render state of one grill slot, one per Slot 1..8 (Feed + the server clock + the local prediction, prep-3d.md §2.5, §3.2).
-- Progress = (GetServerTimeNow() - StartedAt) / Duration, clamped 0..1, recomputed at Rules.World.Budget.ColorHz.
export type SlotState = {
	Slot: number,
	Phase: SlotPhase,
	Progress: number,
	Flip: number?, -- flip score 0..100 (Stations.Flip - 1), nil = not flipped
	Predicted: boolean, -- true until the server record agrees (Place, Flip, Collect run ahead of the packet)
}

-- Messages the stages send down to the World layer (World/Fx, GrillView, tool, puppet): presentation only, nothing is ever
-- sent over the network from here. `World:Send(message)`.
export type WorldMsg =
	{ Kind: "Slot", State: SlotState }
	| { Kind: "Tool", Tool: ToolKind, Topping: string, Fill: number } -- the tool in the hand; Fill 0..1 of the bottle
	| { Kind: "Plate", Mask: number } -- the open plate as a PlateMask (Prep/shared/PlateMask)
	| { Kind: "Pulse", Target: PrepTarget } -- tutorial / hint: pulse a target for a while
	| { Kind: "Burst", Band: Band, At: Vector3 } -- grade burst (stars, sparks, dust)
	| { Kind: "Rollback", Target: PrepTarget, Reason: string } -- the server refused: undo the prediction with a shake
	| { Kind: "Settle", Target: PrepTarget } -- the server disagreed with a prediction: snap with a tween (Rules.World.Settle)

-- Region of the plane of the bun that Gestures reads instead of a GuiObject (TASK-197, prep-3d.md §2.3). Normalise maps a
-- screen point (px) to the bun space 0..1 on both axes (the space of Content.Prep.Build); Aspect = width / height of the bun.
export type PlaneRegion = {
	Inside: (px: Vector2) -> boolean,
	Normalise: (px: Vector2) -> Vector2,
	Aspect: number,
}

const Types = {}

-- Folder of the local 3D prep objects under workspace.CurrentCamera (ghosts, rings, tool, markers): everything the layer creates
-- lives in it and goes away with it on Leave.
Types.FolderName = "PrepWorld"

-- Stable id of a target inside a seat: `GrillSlot:3`, `Rail:1`, `Topping:ketchup`, `Bin`. Slot only counts for GrillSlot and Rail
-- and Board; Topping only for Topping.
function Types.IdOf(kind: TargetKind, slot: number?, topping: string?): string
	if kind == "GrillSlot" or kind == "Rail" or kind == "Board" then
		return `{kind}:{slot or 0}`
	elseif kind == "Topping" then
		return `{kind}:{topping or ""}`
	end
	return kind
end

function Types.Target(kind: TargetKind, slot: number?, topping: string?): PrepTarget
	return { Kind = kind, Id = Types.IdOf(kind, slot, topping), Slot = slot or 0, Topping = topping or "" }
end

return table.freeze(Types)
