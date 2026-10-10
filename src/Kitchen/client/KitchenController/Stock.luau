--!strict
-- Stock visuals (TASK-029; FEAT-007, DEC-140, DEC-156; architecture.md §18.4, network.md §3.4).
-- Reads only the Stock set (through Context.Stock); never decides anything. Per station:
--   sausage_stock, bun_crate  `Fill` follows Amount/Capacity; "7/12" StockCounter pill above the prompts
--   toppings (one per bowl)   `Fill_<Suf>` (food inside the bowl) follows Amount/Capacity;
--                             `Label_<Suf>` gets a StockPlate (icon + "7/12");
--                             `Lid_<Suf>` + `Lock_<Suf>` (padlock) shown only while Blocked (DEC-156)
-- Fill: the part shrinks toward its own bottom along the local axis that points up, with a short tween (DEC-140),
-- so the level reads as going down/up and the food never pokes out of the bowl walls. Amount 0 hides it.
-- Rule of doubt: with no record yet, Fill and counters stay as authored/hidden and bowls stay closed.
-- Everything here is local (LocalTransparencyModifier, client-side Size/CFrame): other clients and the server
-- never see these writes, and the next record overwrites them.
-- Sound and VFX (TASK-079; sound-list §5.3/§5.5, AST-092), from the change between two records of the same capacity
-- (a vehicle swap changes Capacity and is silent; so is a late joiner's first record and a Blocked flip):
--   topping Amount down   SFX-026 `topping_squirt` (ketchup, mustard; pitch per sauce) or SFX-027
--                         `topping_sprinkle` (solids) at the bowl + 6 droplets in the swatch colour
--   any Amount up         SFX-062 `restock` at the station + dust puff (5)
-- Sausage, bun and coffee going down are heard on the grill, the board and the machine instead.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local StockCounter = require(Components.StockCounter)
local StockPlate = require(Components.StockPlate)
local Context = require(script.Parent.Context)
local Fx = require(script.Parent.Fx)

const effect = Vide.effect
const cleanup = Vide.cleanup
const untrack = Vide.untrack

const TOPPINGS_KIND = "toppings"
const INTERACTABLE_TAG = "Interactable"

const FILL_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- Smallest visible level while there is stock (a sliver, so "1 left" still shows food).
const FILL_MIN_RATIO = 0.12
-- Counter pill this far above the station's prompt anchors (the prompt pill sits on the anchor).
const COUNTER_RISE = 1.2
const COUNTER_MAX_DISTANCE = 40

-- Placeholder swatch per ingredient until the icons exist (Q-152); palette of style guide §2.1.
const SWATCH: { [string]: Color3 } = {
	ketchup = Color3.fromHex("#E2402E"),
	mustard = Color3.fromHex("#F6C12B"),
	cheese = Color3.fromHex("#FFD45A"),
	bacon = Color3.fromHex("#C9533E"),
	potato_sticks = Color3.fromHex("#F7D27A"),
	cream_cheese = Color3.fromHex("#FFF8EC"),
	sausage = Color3.fromHex("#C2602F"),
	bun = Color3.fromHex("#F4D9A0"),
}
const DEFAULT_SWATCH = Color3.fromHex("#C9D1D8")

-- SFX-026: the same squirt for both sauces, a different pitch each
const SAUCE_SPEED: { [string]: number } = {
	ketchup = 1,
	mustard = 1.15,
}
const DROPS = 6 -- AST-092 sauce Emit(6)
const DUST = 5 -- AST-092 restock Emit(5)

-- Fill --------------------------------------------------------------------------------------------------------------

type Fill = {
	Part: BasePart,
	Ref: BasePart, -- moves with the station; the authored pose is kept relative to it (vehicle PivotTo, T36)
	Offset: CFrame,
	Size: Vector3,
	Axis: Vector3, -- local unit axis pointing world up
	Span: Vector3, -- |Axis|
	Length: number, -- authored size along Axis (= full)
	Tween: Tween?,
	Shown: boolean,
}

const AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

local function newFill(part: BasePart, ref: BasePart): Fill?
	if not part.Anchored or part == ref then
		-- Moving an unanchored part would drag its whole assembly: only show/hide it then.
		return nil
	end
	local axis, best = Vector3.yAxis, -1
	for _, candidate in AXES do
		const up = part.CFrame:VectorToWorldSpace(candidate).Y
		if math.abs(up) > best then
			best = math.abs(up)
			axis = if up >= 0 then candidate else -candidate
		end
	end
	const span = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
	return {
		Part = part,
		Ref = ref,
		Offset = ref.CFrame:ToObjectSpace(part.CFrame),
		Size = part.Size,
		Axis = axis,
		Span = span,
		Length = part.Size:Dot(span),
		Tween = nil,
		Shown = true,
	}
end

local function stopTween(fill: Fill)
	const tween = fill.Tween
	if tween then
		fill.Tween = nil
		tween:Cancel()
	end
end

local function showPart(part: BasePart, shown: boolean)
	part.LocalTransparencyModifier = if shown then 0 else 1
end

-- ratio 0..1 of the authored level; 0 hides. `instant` skips the tween (first record, late join).
local function setFill(fill: Fill, ratio: number, instant: boolean)
	stopTween(fill)
	if ratio <= 0 then
		fill.Shown = false
		showPart(fill.Part, false)
		return
	end
	const level = math.max(math.clamp(ratio, 0, 1), FILL_MIN_RATIO)
	const shrink = fill.Length * (1 - level)
	const size = fill.Size - fill.Span * shrink
	-- keep the bottom where it was: the centre goes down half of what the part lost
	const pose = fill.Ref.CFrame * fill.Offset * CFrame.new(-fill.Axis * (shrink / 2))
	-- coming back from empty: jump to the level, then show (no grow from the old size)
	const appearing = not fill.Shown
	fill.Shown = true
	showPart(fill.Part, true)
	if instant or appearing then
		fill.Part.Size = size
		fill.Part.CFrame = pose
		return
	end
	const tween = TweenService:Create(fill.Part, FILL_TWEEN, { Size = size, CFrame = pose })
	fill.Tween = tween
	tween:Play()
end

local function restoreFill(fill: Fill)
	stopTween(fill)
	if fill.Part.Parent and fill.Ref.Parent then
		fill.Part.Size = fill.Size
		fill.Part.CFrame = fill.Ref.CFrame * fill.Offset
	end
	showPart(fill.Part, true)
end

-- Drives one Fill part from a stock record. `hideWhenBlocked`: bowls close with the lid, the food goes away.
local function bindFill(part: BasePart, ref: BasePart, read: () -> Context.StockRecord?, hideWhenBlocked: boolean)
	const fill = newFill(part, ref)
	local first = true
	effect(function()
		const record = read()
		if record == nil then
			return -- as authored
		end
		local ratio = if record.Capacity > 0 then record.Amount / record.Capacity else 0
		if hideWhenBlocked and record.Blocked then
			ratio = 0
		end
		if fill then
			setFill(fill, ratio, first)
		else
			showPart(part, ratio > 0)
		end
		first = false
	end)
	cleanup(function()
		if fill then
			restoreFill(fill)
		else
			showPart(part, true)
		end
	end)
end

-- Helpers -----------------------------------------------------------------------------------------------------------

local function setShown(instance: Instance, shown: boolean)
	if instance:IsA("BasePart") then
		showPart(instance, shown)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			showPart(descendant, shown)
		end
	end
end

-- A part of the station that is not the Fill: reference for poses and host of local attachments.
local function hostPart(station: Instance, avoid: BasePart?): BasePart?
	if station:IsA("Model") and station.PrimaryPart and station.PrimaryPart ~= avoid then
		return station.PrimaryPart
	end
	local best: BasePart? = nil
	for _, descendant in station:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= avoid then
			if best == nil or descendant.Size.Magnitude > best.Size.Magnitude then
				best = descendant
			end
		end
	end
	return best
end

local function worldPosition(instance: Instance): Vector3?
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

-- Local attachment at a world position, removed with the view.
local function localAnchor(host: BasePart, name: string, position: Vector3): Attachment
	const attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = host
	attachment.WorldPosition = position
	cleanup(attachment)
	return attachment
end

-- Face of the plate that looks away from the bowl (toward the operator).
local function frontFace(plate: BasePart, from: Vector3, fallback: Vector3): (Enum.NormalId, Vector2)
	local direction = plate.Position - from
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		direction = fallback
	end
	local face, best = Enum.NormalId.Front, -math.huge
	for _, normal in Enum.NormalId:GetEnumItems() do
		const dot = plate.CFrame:VectorToWorldSpace(Vector3.FromNormalId(normal)):Dot(direction)
		if dot > best then
			best = dot
			face = normal
		end
	end
	const size = plate.Size
	const dims = if face == Enum.NormalId.Front or face == Enum.NormalId.Back
		then Vector2.new(size.X, size.Y)
		elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then Vector2.new(size.Z, size.Y)
		else Vector2.new(size.X, size.Z)
	return face, dims
end

-- Lock_<Suf> of the bowl model; without it, a local copy of the kit padlock at Att_Lock_<Suf> or on top of the
-- lid (architecture.md §18.4 / §18.9.1: ReplicatedStorage.Assets.Equipment.Padlock, Att_Hang).
local function padlock(station: Instance, suffix: string, lid: Instance?): Instance?
	const authored = Context.Find(station, "Lock_" .. suffix)
	if authored then
		return authored
	end
	const assets = ReplicatedStorage:FindFirstChild("Assets")
	const equipment = if assets then assets:FindFirstChild("Equipment") else nil
	const source = if equipment then equipment:FindFirstChild("Padlock") else nil
	if source == nil then
		return nil
	end
	const spot = Context.Find(station, "Att_Lock_" .. suffix)
	local target: CFrame? = nil
	if spot and spot:IsA("Attachment") then
		target = spot.WorldCFrame
	elseif lid and lid:IsA("BasePart") then
		target = lid.CFrame * CFrame.new(0, lid.Size.Y / 2, 0)
	end
	if target == nil then
		return nil
	end
	const copy = source:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	if copy:IsA("PVInstance") then
		copy:PivotTo(target)
		const hang = copy:FindFirstChild("Att_Hang", true)
		if hang and hang:IsA("Attachment") then
			copy:PivotTo(copy:GetPivot() + (target.Position - hang.WorldPosition))
		end
	end
	copy.Name = "Lock_" .. suffix
	copy.Parent = station
	cleanup(copy)
	return copy
end

-- Sound -------------------------------------------------------------------------------------------------------------

-- Plays on the change between two records with the same Capacity (see header). `at` = bowl or station anchor.
local function bindSounds(
	station: Instance,
	ingredient: string,
	read: () -> Context.StockRecord?,
	at: Instance,
	topping: boolean,
	audio: Context.Audio
)
	local last: Context.StockRecord? = nil
	effect(function()
		const record = read()
		const previous = last
		last = record
		if record == nil or previous == nil then
			return
		end
		if record.Capacity ~= previous.Capacity or record.Blocked ~= previous.Blocked then
			return
		end
		const delta = record.Amount - previous.Amount
		if delta == 0 then
			return
		end
		untrack(function()
			if not audio.Current(station) then
				return nil
			end
			const position = worldPosition(at)
			if delta > 0 then
				audio.Play(station, "restock", at)
				if position then
					Fx.Burst(position, "Dust", DUST)
				end
			elseif topping then
				const speed = SAUCE_SPEED[ingredient]
				if speed then
					audio.Play(station, "topping_squirt", at, { Speed = speed })
				else
					audio.Play(station, "topping_sprinkle", at)
				end
				if position then
					Fx.Burst(position, "Drops", DROPS, SWATCH[ingredient] or DEFAULT_SWATCH)
				end
			end
			return nil
		end)
	end)
end

-- Views -------------------------------------------------------------------------------------------------------------

local function mountBowl(station: Instance, ingredient: string, context: Context.Context)
	const row = Content.Ingredients.ByKey[ingredient]
	const suffix = Context.Suffix(ingredient)
	const bin = Context.FindPart(station, "Bin_" .. suffix)
	const fillPart = Context.FindPart(station, "Fill_" .. suffix)
	const label = Context.FindPart(station, "Label_" .. suffix)
	const lid = Context.Find(station, "Lid_" .. suffix)
	const lock = padlock(station, suffix, lid)

	local function read(): Context.StockRecord?
		return context.Stock(ingredient)
	end
	local function showCount(): boolean
		const record = read()
		return record ~= nil and not record.Blocked
	end

	if fillPart then
		const ref = bin or hostPart(station, fillPart)
		if ref then
			bindFill(fillPart, ref, read, true)
		end
	end

	const soundAt: Instance? = bin or fillPart or label or hostPart(station, nil)
	if soundAt then
		bindSounds(station, ingredient, read, soundAt, true, context.Audio)
	end

	-- DEC-156: lid + padlock only while Blocked. No record yet = closed (rule of doubt, as authored).
	if lid or lock then
		effect(function()
			const record = read()
			const closed = record == nil or record.Blocked
			if lid then
				setShown(lid, closed)
			end
			if lock then
				setShown(lock, closed)
			end
		end)
		cleanup(function()
			if lid then
				setShown(lid, true)
			end
			if lock then
				setShown(lock, true)
			end
		end)
	end

	if label then
		const pivot = if station:IsA("PVInstance") then station:GetPivot() else label.CFrame
		const face, dims = frontFace(label, if bin then bin.Position else pivot.Position, pivot.LookVector)
		const gui = StockPlate({
			Name = "StockPlate",
			Adornee = label,
			Face = face,
			Icon = function()
				return row.Icon
			end,
			Label = row.Name,
			Color = SWATCH[ingredient] or DEFAULT_SWATCH,
			Text = function()
				return Context.CountText(read())
			end,
			Low = function()
				return Context.IsLow(read())
			end,
			ShowCount = showCount,
			Vertical = dims.Y > dims.X * 1.2,
		})
		gui.Parent = label
		cleanup(gui)
	elseif bin then
		-- Binding without the plate: the counter floats over the bowl instead (still "7/12" for everyone).
		const gui = StockCounter({
			Name = "StockCounter",
			Adornee = bin,
			Text = function()
				return Context.CountText(read())
			end,
			Low = function()
				return Context.IsLow(read())
			end,
			Visible = showCount,
			StudsOffset = Vector3.new(0, bin.Size.Y / 2 + 0.5, 0),
			MaxDistance = COUNTER_MAX_DISTANCE,
		})
		gui.Parent = bin
		cleanup(gui)
	end
end

-- Cooler (sausage) and bun crate: one ingredient per station.
local function mountSingle(station: Instance, ingredient: string, context: Context.Context)
	local function read(): Context.StockRecord?
		return context.Stock(ingredient)
	end

	const fillPart = Context.FindPart(station, "Fill")
	const host = hostPart(station, fillPart)
	if host == nil then
		return
	end
	if fillPart then
		bindFill(fillPart, host, read, false)
	end

	-- Above the station's own prompts (the cooler sits low in the cart body; its prompts are on the counter).
	local sum, count = Vector3.zero, 0
	for _, descendant in station:GetDescendants() do
		if CollectionService:HasTag(descendant, INTERACTABLE_TAG) then
			const position = worldPosition(descendant)
			if position then
				sum += position
				count += 1
			end
		end
	end
	local position: Vector3
	if count > 0 then
		position = sum / count + Vector3.new(0, COUNTER_RISE, 0)
	elseif station:IsA("Model") then
		const box, size = station:GetBoundingBox()
		position = box.Position + Vector3.new(0, size.Y / 2 + 0.6, 0)
	else
		position = host.Position + Vector3.new(0, host.Size.Y / 2 + 0.6, 0)
	end

	const anchor = localAnchor(host, "StockCounter", position)
	bindSounds(station, ingredient, read, host, false, context.Audio)
	const gui = StockCounter({
		Name = "StockCounter",
		Adornee = anchor,
		Text = function()
			return Context.CountText(read())
		end,
		Low = function()
			return Context.IsLow(read())
		end,
		Visible = function()
			const record = read()
			return record ~= nil and not record.Blocked
		end,
		MaxDistance = COUNTER_MAX_DISTANCE,
	})
	gui.Parent = host
	cleanup(gui)
end

const Stock = {}

Stock.Kinds = table.freeze({
	sausage_stock = true,
	bun_crate = true,
	coffee_machine = true, -- coffee stock counter (TASK-068/069)
	[TOPPINGS_KIND] = true,
}) :: { [string]: boolean }

function Stock.Mount(station: Instance, context: Context.Context)
	const kind = station:GetAttribute("StationKind")
	if kind == TOPPINGS_KIND then
		for _, row in Content.Ingredients.List do
			if row.Station == TOPPINGS_KIND then
				mountBowl(station, row.Key, context)
			end
		end
		return
	end
	const ingredient = Context.StationIngredient(station)
	if ingredient then
		mountSingle(station, ingredient, context)
	end
end

return table.freeze(Stock) :: Context.Part
