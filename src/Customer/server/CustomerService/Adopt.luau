--!strict
--[[
	CustomerService/Adopt (TASK-163; user request 2026-10-11; FEAT-009 note; Content.Flow.Adopt). All PROVISIONAL.
	A passer-by near the queue may become the next customer instead of a spawn at a door.

	PedestrianService owns the walkers and registers an Adopter through CustomerService:SetAdopter (T42: the
	peripheral requires the central; CustomerService never requires PedestrianService).

	  * notice: NoticeLead s before a scheduled attempt (CustomerService.NextSpawnAt), once per attempt, with the
	    Chance of the shift, from FromDay / FromNight and at least MinGapSeconds after the last adoption, if a customer
	    could spawn now (selling phase, no tutorial customer around, no tension, room at the counter and in both caps):
	    the nearest walker within MaxDistance studs of Q5 whose species and outfit fit a customer type of the shift
	    (and that is not on a crosswalk) brakes on the sidewalk (Adopter.Pick);
	  * attempt: CustomerService:Attempt takes it (Adopt.Spawn) instead of NpcService:Spawn when no pair was drawn: a
	    server rig with the walker's species and outfit (Plain: no type accessory, the walker had none) on the walker's
	    spot facing the cart, routing from the nearest node of its sidewalk; the walker record goes in the same frame
	    (rig attribute FromWalker = its slot, for the client hand-off). Type: weighted draw among the types of the
	    shift with that species and outfit. Then it is a normal customer (Create: ledger, orders, may sit). It faces
	    the cart Beat s, then walks to Q5;
	  * a noticed walker nobody took (pair drawn, counter full, caps, phase change) walks on after GRACE s;
	  * FirstDelay: the first attempt of a selling phase is pulled to FirstDelay s after the phase starts.
	Never: the tutorial customer, anomaly actors (SpawnActor), the thief, pairs (walkers walk alone), under tension (no
	walkers then). Cutscenes run only in Intro / Finale, which are not selling phases.
	Draws use an unseeded Random (walkers are cosmetic and unseeded); an adoption skips one seeded look draw.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Content = require(ReplicatedStorage.shared.Content)
local MapIndex = require(ReplicatedStorage.shared.Place.MapIndex)
local Queue = require(script.Parent.Queue)

export type Handoff = {
	Species: string,
	Outfit: string,
	Position: Vector3, -- floor point where the walker stands
	Heading: Vector3, -- horizontal unit heading of its path there
	Node: string, -- NpcNode of its sidewalk the customer routes from
}

-- Provided by PedestrianService (slot = Pedestrians record id)
export type Adopter = {
	-- nearest walker within `radius` studs of `center` that `accept`s, now braking on the spot; nil = none
	Pick: (center: Vector3, radius: number, accept: (species: string, outfit: string) -> boolean) -> number?,
	Peek: (slot: number) -> Handoff?, -- the noticed walker of `slot`, nil when it is gone
	Take: (slot: number) -> boolean, -- removes the noticed walker record
	Release: (slot: number) -> (), -- the noticed walker walks on
}

-- What the adopter gets back (dev commands)
export type Controls = {
	Force: () -> string,
	Status: () -> string,
}

type Notice = { Slot: number, Due: number, Until: number }

const STEP = 0.1 -- s between checks
const GRACE = 1.5 -- s after the attempt time a noticed walker is still kept
const CART = "CART" -- MapPoint the new customer faces (fallback: Q1)
const RULES = Content.Flow.Adopt

const Adopt = {}

local adopter: Adopter? = nil
local notice: Notice? = nil
local rolledFor = 0 -- NextSpawnAt already rolled for
local lastAt = -math.huge -- server time of the last adoption
local forced = false
local rng = Random.new()
const stats = { Noticed = 0, Adopted = 0, Released = 0 }

local function now(): number
	return workspace:GetServerTimeNow()
end

local function between(range: { number }): number
	const low, high = range[1] or 0, range[2] or range[1] or 0
	if high <= low then
		return low
	end
	return low + rng:NextNumber() * (high - low)
end

local function nodePosition(id: string): Vector3?
	const ok, info = pcall(MapIndex.Node, id)
	return if ok then info.Position else nil
end

local function cartPosition(): Vector3?
	const point = MapIndex.FindPoint(CART)
	if point ~= nil then
		return point.Position
	end
	return nodePosition(Queue.point(1))
end

-- Customer types of this shift a walker with `species` + `outfit` may be (same unlock rules as NpcService Look)
local function typesFor(service: any, species: string, outfit: string): ({ string }, { number }, number)
	const keys: { string } = {}
	const weights: { number } = {}
	local total = 0
	const speciesRow = Content.Species.ByKey[species]
	const outfitRow = Content.Outfits.ByKey[outfit]
	if
		speciesRow == nil
		or not speciesRow.Customer
		or speciesRow.ReservedFor ~= nil
		or outfitRow == nil
		or outfitRow.Use ~= "Civil"
		or table.find(Content.Looks.NpcNeverUses.Outfits, outfit) ~= nil
	then
		return keys, weights, 0
	end
	const info = service.Dependencies.RoundService:Info()
	const night: boolean = service:IsNightShift()
	for _, row in Content.CustomerTypes.List do
		if row.Role ~= "Customer" or table.find(row.Species, species) == nil or table.find(row.Outfits, outfit) == nil then
			continue
		end
		local weight: number
		local unlocked: boolean
		if night then
			weight = row.Weight.Night
			unlocked = row.Shift ~= "Day" and row.UnlockNight >= 1 and info.Night >= row.UnlockNight
		else
			weight = row.Weight.Day
			unlocked = row.Shift ~= "Night" and row.UnlockDay >= 1 and info.Day >= row.UnlockDay
		end
		if unlocked and weight > 0 then
			table.insert(keys, row.Key)
			table.insert(weights, weight)
			total += weight
		end
	end
	return keys, weights, total
end

local function pickType(service: any, species: string, outfit: string): string?
	const keys, weights, total = typesFor(service, species, outfit)
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll < 0 then
			return keys[index]
		end
	end
	return keys[#keys]
end

-- A customer could spawn right now (the same gates as Attempt, plus no tutorial customer and no tension)
local function canSpawn(service: any): boolean
	if not service.Enabled or not service:IsSelling() or service:HasTutorial() then
		return false
	end
	const npc = service.Dependencies.NpcService
	if npc:IsTension() or Queue.isFull(service:Occupants(), service:QueueSize()) then
		return false
	end
	return service:Count() < service:MaxCustomers() and npc:Count() < npc:Capacity()
end

-- This shift allows adoptions at all (FromDay / FromNight); the chance of the shift
local function chanceNow(service: any): number
	const info = service.Dependencies.RoundService:Info()
	if service:IsNightShift() then
		if RULES.FromNight < 1 or info.Night < RULES.FromNight then
			return 0
		end
		return RULES.ChanceNight
	end
	if info.Day < RULES.FromDay then
		return 0
	end
	return RULES.ChanceDay
end

local function release()
	const current = notice
	notice = nil
	if current ~= nil and adopter ~= nil then
		(adopter :: Adopter).Release(current.Slot)
		stats.Released += 1
	end
end

local function step(service: any, t: number)
	const current = notice
	if current ~= nil then
		if t > current.Until or not canSpawn(service) then
			release()
		end
		return
	end
	const a = adopter
	const due: number = service.NextSpawnAt
	if a == nil or due <= 0 or due == rolledFor or due - t > RULES.NoticeLead or not canSpawn(service) then
		return
	end
	rolledFor = due
	if not forced then
		if t - lastAt < RULES.MinGapSeconds or rng:NextNumber() >= chanceNow(service) then
			return
		end
	end
	forced = false
	const center = nodePosition(Queue.entry())
	if center == nil then
		return
	end
	const slot = a.Pick(center, RULES.MaxDistance, function(species: string, outfit: string): boolean
		const _, _, total = typesFor(service, species, outfit)
		return total > 0
	end)
	if slot ~= nil then
		notice = { Slot = slot, Due = due, Until = math.max(due, t) + GRACE }
		stats.Noticed += 1
	end
end

-- The new customer faces the cart Beat s before its arrival walk (Create already started one: silenced and redone)
local function beat(service: any, id: number)
	if RULES.Beat <= 0 then
		return
	end
	const customer = service.Customers[id]
	if customer == nil or customer.State ~= "Arriving" then
		return
	end
	customer.Move += 1 -- the arrival walk of Create no longer answers
	const npc = service.Dependencies.NpcService
	npc:Stop(id)
	const rig = npc:GetRig(id)
	const cart = cartPosition()
	if rig ~= nil and cart ~= nil then
		npc:Face(id, cart - rig.Root.Position)
	end
	task.wait(RULES.Beat)
	if service.Customers[id] ~= customer or customer.State ~= "Arriving" then
		return
	end
	service:Walk(customer, Queue.entry(), true, function(ok: boolean)
		if ok then
			service:Join(customer)
		else
			service:Remove(id) -- no route (binding broken): nothing to queue
		end
	end)
end

local function hasRoute(from: string): boolean
	const ok, found = pcall(function(): boolean
		return MapIndex.Path(from, Queue.entry(), { AvoidQueue = true }) ~= nil
	end)
	return ok and found
end

-- API -------------------------------------------------------------------------------------------------------------

-- CustomerService:Attempt, lone customer branch: the noticed walker becomes the customer. Returns its NpcId (the
-- caller runs Create), or nil (nobody noticed, walker gone, no type, no route, pool full: a normal spawn follows).
function Adopt.Spawn(service: any): number?
	const current = notice
	const a = adopter
	if current == nil or a == nil then
		return nil
	end
	notice = nil
	const handoff = a.Peek(current.Slot)
	if handoff == nil then
		return nil
	end
	const typeKey = pickType(service, handoff.Species, handoff.Outfit)
	if typeKey == nil or not hasRoute(handoff.Node) then
		a.Release(current.Slot)
		stats.Released += 1
		return nil
	end
	local look = handoff.Heading
	const cart = cartPosition()
	if cart ~= nil then
		const flat = Vector3.new(cart.X - handoff.Position.X, 0, cart.Z - handoff.Position.Z)
		if flat.Magnitude > 1e-3 then
			look = flat.Unit
		end
	end
	const npc = service.Dependencies.NpcService
	const id: number? = npc:Spawn({
		CustomerType = typeKey,
		Species = handoff.Species,
		Outfit = handoff.Outfit,
		From = handoff.Node,
		At = CFrame.lookAt(handoff.Position, handoff.Position + look),
		Plain = true,
		Walker = current.Slot,
		Rng = rng,
	})
	if id == nil then
		a.Release(current.Slot)
		stats.Released += 1
		return nil
	end
	a.Take(current.Slot)
	lastAt = now()
	stats.Adopted += 1
	task.defer(beat, service, id)
	return id
end

-- PedestrianService registers (or clears) its walkers. Returns the dev controls.
function Adopt.Set(service: any, value: Adopter?): Controls
	release()
	adopter = value
	return {
		-- next attempt adopts if any walker fits (chance, gap and From ignored; caps and phase still apply)
		Force = function(): string
			if not service.Enabled or not service:IsSelling() then
				return "not a selling phase (Open / Night): no attempt to adopt for"
			end
			forced = true
			rolledFor = 0
			const t = now()
			if service.NextSpawnAt <= 0 or service.NextSpawnAt > t + RULES.NoticeLead then
				service.NextSpawnAt = t + RULES.NoticeLead
			end
			return `adoption armed: next attempt in {string.format("%.1f", service.NextSpawnAt - t)} s`
		end,
		Status = function(): string
			const current = notice
			return string.format(
				"adopt: %s; noticed %d, adopted %d, released %d; last %s; next attempt %s",
				if current then `walker #{current.Slot} noticed` else "none noticed",
				stats.Noticed,
				stats.Adopted,
				stats.Released,
				if lastAt > -math.huge then string.format("%.0f s ago", now() - lastAt) else "never",
				if service.NextSpawnAt > 0 then string.format("in %.1f s", service.NextSpawnAt - now()) else "off"
			)
		end,
	}
end

-- CustomerService OnInit, after its own PhaseChanged handler (the first attempt is already scheduled there)
function Adopt.Init(service: any)
	service.Dependencies.RoundService.PhaseChanged:Connect(function()
		if service.NextSpawnAt > 0 and service:IsSelling() then
			service.NextSpawnAt = math.min(service.NextSpawnAt, now() + between(RULES.FirstDelay))
		elseif notice ~= nil then
			release()
		end
	end)
	local nextAt = 0
	RunService.Heartbeat:Connect(function()
		const t = now()
		if t < nextAt then
			return
		end
		nextAt = t + STEP
		step(service, t)
	end)
end

return Adopt
