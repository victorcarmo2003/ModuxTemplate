--!strict
-- Sign: the Gear Stand's own lamps and its TIMER board follow the business hours (owner request 2026-10-21, Provisional).
--   * every Light under the stand's `GearLights` folder (tools/assetplace/gearstand_lights.luau) is on only while the stand
--     is open (MarketController.KioskOpen: the server hours and the Day 1 rule, same as the shutters);
--   * the `TIMER` part (SurfaceGui + TextLabel, placed by hand in Studio) reads "CLOSED" while closed, "OPEN" while open
--     with no close scheduled yet, and "CLOSES IN m:ss" once GearStandService scheduled it (Workspace attribute
--     Hours.Attributes.ClosesAt, server time).
-- Local only (no server rule). The stand is the Model of a GearShutter / GearPedestal (MapId GEAR_STAND), found again
-- while the map streams in. Plain module, owned by MarketController (Step at its tick).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Content = require(ReplicatedStorage.shared.Content)

const MART = Content.Mart
const LIGHTS = "GearLights"
const TIMER = "TIMER"
const STAND_ID = "GEAR_STAND"
const FIND_EVERY = 2 -- s between two searches for the stand while it is missing
const TEXT_CLOSED = "CLOSED"
const TEXT_OPEN = "OPEN"

export type Sign = {
	Stand: Instance?,
	Label: TextLabel?,
	Lights: { Light },
	Open: boolean?, -- last state written to the lamps (nil = never)
	Text: string,
	FoundAt: number,
	Step: (self: Sign, now: number, open: boolean) -> (),
}

-- The GEAR_STAND model around a tagged shutter / pedestal: the outermost ancestor with MapId GEAR_STAND
local function standOf(instance: Instance): Instance?
	local found: Instance? = nil
	local at: Instance? = instance
	while at ~= nil and at ~= Workspace do
		if at:IsA("Model") and at:GetAttribute("MapId") == STAND_ID then
			found = at
		end
		at = at.Parent
	end
	return found
end

local function findStand(): Instance?
	for _, tag in { MART.Tags.Shutter, MART.Tags.Pedestal } do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsDescendantOf(Workspace) then
				const stand = standOf(instance)
				if stand ~= nil then
					return stand
				end
			end
		end
	end
	return nil
end

local function countdown(left: number): string
	const seconds = math.max(0, math.ceil(left))
	return string.format("CLOSES IN %d:%02d", seconds // 60, seconds % 60)
end

local Sign = {}

function Sign.new(): Sign
	return {
		Stand = nil,
		Label = nil,
		Lights = {},
		Open = nil,
		Text = "",
		FoundAt = -math.huge,
		Step = Sign.Step,
	}
end

function Sign.Bind(self: Sign, stand: Instance)
	self.Stand = stand
	self.Open = nil
	self.Text = ""
	table.clear(self.Lights)
	const folder = stand:FindFirstChild(LIGHTS, true)
	if folder ~= nil then
		for _, light in folder:GetDescendants() do
			if light:IsA("Light") then
				table.insert(self.Lights, light)
			end
		end
	end
	const timer = stand:FindFirstChild(TIMER, true)
	const label = if timer ~= nil then timer:FindFirstChildWhichIsA("TextLabel", true) else nil
	self.Label = label
end

function Sign.Step(self: Sign, now: number, open: boolean)
	const stand = self.Stand
	if stand == nil or not stand:IsDescendantOf(Workspace) then
		self.Stand = nil
		if now - self.FoundAt < FIND_EVERY then
			return
		end
		self.FoundAt = now
		const found = findStand()
		if found == nil then
			return
		end
		Sign.Bind(self, found)
	end
	if self.Open ~= open then
		self.Open = open
		for _, light in self.Lights do
			light.Enabled = open
		end
	end
	const label = self.Label
	if label == nil then
		return
	end
	local text = TEXT_CLOSED
	if open then
		const closesAt = Workspace:GetAttribute(MART.Hours.Attributes.ClosesAt)
		text = if type(closesAt) == "number" and closesAt > 0
			then countdown(closesAt - Workspace:GetServerTimeNow())
			else TEXT_OPEN
	end
	if text ~= self.Text then
		self.Text = text
		label.Text = text
	end
end

return table.freeze(Sign)
