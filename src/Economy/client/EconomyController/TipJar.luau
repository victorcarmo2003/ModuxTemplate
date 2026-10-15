--!strict
--[[
	TipJar (user decision 2026-10-13): the tip jar fills with money as tips pile up.

	Presentation only: the number is `Economy.Drawer` (tips in the jar), the server decides it. This module draws a heap
	of green bills and Mustard coins inside the jar model, proportional to min(1, Drawer / FullAt), up to MaxBills pieces.

	Piece i always sits in the same place (deterministic hash of the index, no network), so every player sees the same
	heap and a piece that leaves and comes back lands on the same spot. Pieces live in a client-only Folder
	"TipJarFill" inside the model, anchored, in the local space of the `Fill_Volume` part (an invisible part the map
	places inside the glass: its size is the room the heap may use). A model without `Fill_Volume` (the legacy POS) draws
	no heap, only the value.

	Set(drawer)   fills / empties; each new piece pops in with a spring (Back easing) from above.
	Collect(fly)  the heap leaves: every piece calls fly(worldPosition, isCoin, delay) so the controller can send a
	              2D copy to the HUD money pill, and the 3D piece hops up and shrinks away.
	An emptying Set(0) waits a moment (CLEAR_GRACE) so a CashCollected that arrives a hair later still finds the pieces.
]]
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Content = require(ReplicatedStorage.shared.Content)

export type Config = {
	FullAt: number,
	MaxBills: number,
	MapId: string,
	LegacyMapIds: { string },
}

type Piece = {
	Part: BasePart,
	Coin: boolean,
	Final: CFrame,
	Size: Vector3,
}

export type TipJar = {
	Model: Model,
	Volume: BasePart,
	Pieces: { Piece },
	Folder: Folder,
	Config: Config,
	Primed: boolean,
	Clear: thread?,
	Destroyed: boolean,
}

const FILL_NAME = "Fill_Volume"
const FOLDER_NAME = "TipJarFill"
const BILL_COLOR = Color3.fromHex("#6FB26B") -- note green (docs/art/style-guide.md palette: Green family)
const COIN_COLOR = Color3.fromHex("#F6C12B") -- Mustard
const OUTLINE_COLOR = Color3.fromHex("#2B2118") -- Ink
const BILL_SIZE = Vector3.new(0.5, 0.02, 0.25)
const COIN_SIZE = Vector3.new(0.04, 0.3, 0.3) -- cylinder: X is the axis
const COIN_EVERY = 3 -- every 3rd piece is a coin
const POP_TIME = 0.38
const POP_STAGGER = 0.07
const POP_RISE = 0.9 -- studs above the final spot the piece falls from
const LEAVE_TIME = 0.3
const CLEAR_GRACE = 0.35

-- Content.TipJar is created by the backend; the defaults keep the client working until it exists
const DEFAULTS: Config = {
	FullAt = 20,
	MaxBills = 14,
	MapId = "TRL-TIPJAR",
	LegacyMapIds = { "DRAWER", "TRL-DRAWER" },
}

local TipJar = {}
TipJar.FillName = FILL_NAME

function TipJar.Config(): Config
	const raw = (Content :: any).TipJar
	if type(raw) ~= "table" then
		return DEFAULTS
	end
	const legacy = if type(raw.LegacyMapIds) == "table" then raw.LegacyMapIds :: { string } else DEFAULTS.LegacyMapIds
	return {
		FullAt = if type(raw.FullAt) == "number" and raw.FullAt > 0 then raw.FullAt else DEFAULTS.FullAt,
		MaxBills = if type(raw.MaxBills) == "number" and raw.MaxBills >= 1 then math.floor(raw.MaxBills) else DEFAULTS.MaxBills,
		MapId = if type(raw.MapId) == "string" then raw.MapId else DEFAULTS.MapId,
		LegacyMapIds = legacy,
	}
end

-- Jar model inside a vehicle: the new MapId first, then the legacy ones
function TipJar.FindModel(vehicle: Instance, config: Config): Model?
	local legacy: Model? = nil
	for _, descendant in vehicle:GetDescendants() do
		if descendant:IsA("Model") then
			const id = descendant:GetAttribute("MapId")
			if id == config.MapId then
				return descendant
			elseif legacy == nil and type(id) == "string" and table.find(config.LegacyMapIds, id) then
				legacy = descendant
			end
		end
	end
	return legacy
end

-- true when this MapId is the jar (new or legacy): used by the streaming listeners
function TipJar.IsJarId(id: unknown, config: Config): boolean
	return type(id) == "string" and (id == config.MapId or table.find(config.LegacyMapIds, id) ~= nil)
end

-- Deterministic 0..1 noise from the piece index and a salt (no randomness, no network)
local function noise(index: number, salt: number): number
	const value = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453
	return value - math.floor(value)
end

-- Final spot of piece `index` (1..max) in the local space of the volume: a heap that rises with the index
local function slotOf(index: number, max: number, volume: Vector3, coin: boolean): CFrame
	const room = math.min(volume.X, volume.Z) * 0.5 - 0.3
	const radius = math.max(0, room) * math.sqrt(noise(index, 1))
	const angle = noise(index, 2) * math.pi * 2
	const rise = (index - 0.5) / max
	const y = -volume.Y / 2 + 0.05 + (volume.Y - 0.2) * rise * 0.9
	const spot = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
	if coin then
		-- face up, a little off-flat
		return CFrame.new(spot)
			* CFrame.Angles(0, noise(index, 3) * math.pi, (noise(index, 4) - 0.5) * 0.5)
			* CFrame.Angles(0, 0, math.pi / 2)
	end
	return CFrame.new(spot)
		* CFrame.Angles((noise(index, 5) - 0.5) * 1.3, noise(index, 3) * math.pi * 2, (noise(index, 6) - 0.5) * 0.9)
end

function TipJar.new(model: Model, volume: BasePart, config: Config): TipJar
	const folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = model
	-- one outline for the whole heap (a light Ink edge so a green note reads against the glass)
	const outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.Adornee = folder
	outline.FillTransparency = 1
	outline.OutlineColor = OUTLINE_COLOR
	outline.OutlineTransparency = 0.55
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = folder
	return {
		Model = model,
		Volume = volume,
		Pieces = {},
		Folder = folder,
		Config = config,
		Primed = false,
		Clear = nil,
		Destroyed = false,
	}
end

local function makePiece(jar: TipJar, index: number): Piece
	const coin = index % COIN_EVERY == 0
	const part = Instance.new("Part")
	part.Name = if coin then "Coin" else "Bill"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = if coin then Enum.Material.SmoothPlastic else Enum.Material.Fabric
	part.Color = if coin then COIN_COLOR else BILL_COLOR
	if coin then
		part.Shape = Enum.PartType.Cylinder
	end
	const size = if coin then COIN_SIZE else BILL_SIZE
	part.Size = size
	const final = jar.Volume.CFrame * slotOf(index, jar.Config.MaxBills, jar.Volume.Size, coin)
	part.CFrame = final
	return { Part = part, Coin = coin, Final = final, Size = size }
end

local function popIn(piece: Piece, delay: number)
	const part = piece.Part
	part.Size = piece.Size * 0.2
	part.CFrame = piece.Final * CFrame.new(0, POP_RISE, 0)
	task.delay(delay, function()
		if part.Parent == nil then
			return
		end
		TweenService:Create(
			part,
			TweenInfo.new(POP_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = piece.Size, CFrame = piece.Final }
		):Play()
	end)
end

local function leave(piece: Piece, delay: number)
	const part = piece.Part
	const tween = TweenService:Create(
		part,
		TweenInfo.new(LEAVE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay),
		{ Size = piece.Size * 0.1, CFrame = piece.Final * CFrame.new(0, 1.2, 0) }
	)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

local function cancelClear(jar: TipJar)
	const pending = jar.Clear
	if pending then
		jar.Clear = nil
		if coroutine.status(pending) == "suspended" then
			task.cancel(pending)
		end
	end
end

-- How many pieces the amount shows: none for 0, at least one for any tip, all of them at FullAt
function TipJar.Target(config: Config, drawer: number): number
	if drawer <= 0 then
		return 0
	end
	return math.clamp(math.ceil(config.MaxBills * math.min(1, drawer / config.FullAt)), 1, config.MaxBills)
end

function TipJar.Set(jar: TipJar, drawer: number)
	if jar.Destroyed then
		return
	end
	const target = TipJar.Target(jar.Config, drawer)
	const count = #jar.Pieces
	const animate = jar.Primed
	jar.Primed = true
	if target == count then
		return
	end
	if target > count then
		cancelClear(jar)
		for index = count + 1, target do
			const piece = makePiece(jar, index)
			piece.Part.Parent = jar.Folder
			table.insert(jar.Pieces, piece)
			if animate then
				popIn(piece, (index - count - 1) * POP_STAGGER)
			end
		end
		return
	end
	-- fewer pieces
	if target == 0 and animate then
		-- the whole heap goes: a CashCollected right behind this still finds the pieces (Collect cancels the timer)
		cancelClear(jar)
		jar.Clear = task.delay(CLEAR_GRACE, function()
			jar.Clear = nil
			for index, piece in jar.Pieces do
				leave(piece, (index - 1) * 0.02)
			end
			table.clear(jar.Pieces)
		end)
		return
	end
	for index = count, target + 1, -1 do
		const piece = table.remove(jar.Pieces, index) :: Piece
		if animate then
			leave(piece, 0)
		else
			piece.Part:Destroy()
		end
	end
end

-- "Collect Tips": the heap leaves. `fly(position, isCoin, delay)` is called once per piece (the controller flies a 2D
-- copy to the HUD pill). Returns how many pieces left.
function TipJar.Collect(jar: TipJar, fly: (position: Vector3, coin: boolean, delay: number) -> ()): number
	cancelClear(jar)
	const pieces = jar.Pieces
	jar.Pieces = {}
	for index, piece in pieces do
		const delay = (index - 1) * 0.035
		fly(piece.Part.Position, piece.Coin, delay)
		leave(piece, delay)
	end
	return #pieces
end

-- World position of the middle of the heap (burst / sound anchor)
function TipJar.Center(jar: TipJar): Vector3
	return jar.Volume.Position
end

function TipJar.Destroy(jar: TipJar)
	if jar.Destroyed then
		return
	end
	jar.Destroyed = true
	cancelClear(jar)
	jar.Folder:Destroy()
	table.clear(jar.Pieces)
end

return TipJar
