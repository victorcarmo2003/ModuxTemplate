--!strict
-- Data-driven content (docs/tech/content-data.md). ReplicatedStorage.shared.Content, read by server and client.
-- Pure data: no Modux, Lync, Vide or self.Libs, so Net can require it to build enums (network.md §1 rule 3).
-- Owner of this file: TASK-003. Content tasks edit only their own table file.
local Actions = require(script.Actions)
local Classes = require(script.Classes)
local CustomerTypes = require(script.CustomerTypes)
local Flow = require(script.Flow)
local Ingredients = require(script.Ingredients)
local Items = require(script.Items)
local Moods = require(script.Moods)
local Notices = require(script.Notices)
local OpalLines = require(script.OpalLines)
local Orders = require(script.Orders)
local Outfits = require(script.Outfits)
local Packages = require(script.Packages)
local RunParams = require(script.RunParams)
local Shift = require(script.Shift)
local Species = require(script.Species)
local Stations = require(script.Stations)
local Stats = require(script.Stats)
local Table = require(script.Table)
local Upgrades = require(script.Upgrades)
local Validate = require(script.Validate)
local Vehicles = require(script.Vehicles)

export type Table<T> = Table.Table<T>
export type Action = Actions.Action
export type Class = Classes.Class
export type ClassEffect = Classes.Effect
export type CustomerType = CustomerTypes.CustomerType
export type Ingredient = Ingredients.Ingredient
export type Item = Items.Item
export type ItemRules = Items.ItemRules
export type Looks = Outfits.Looks
export type Mood = Moods.Mood
export type MoodRules = Moods.MoodRules
export type Notice = Notices.Notice
export type OpalPool = OpalLines.OpalPool
export type OrderPhase = Orders.OrderPhase
export type OrderRules = Orders.OrderRules
export type Outfit = Outfits.Outfit
export type Package = Packages.Package
export type Phase = Shift.Phase
export type Species = Species.Species
export type Stat = Stats.Stat
export type Station = Stations.Station
export type Upgrade = Upgrades.Upgrade
export type UpgradeLevel = Upgrades.Level
export type Vehicle = Vehicles.Vehicle

Validate()

return table.freeze({
	-- wave 1, complete
	Actions = Actions,
	Ingredients = Ingredients,
	Items = Items,
	ItemRules = Items.Rules,
	Looks = Outfits.Looks,
	MoodRules = Moods.Rules,
	Moods = Moods,
	Notices = Notices,
	Outfits = Outfits,
	Packages = Packages,
	Stations = Stations,
	Stats = Stats,

	-- wave 1, typed stubs (values in TASK-008 / TASK-009)
	Classes = Classes,
	CustomerTypes = CustomerTypes,
	Flow = Flow,
	OpalLines = OpalLines,
	OrderPhases = Orders,
	OrderRules = Orders.Rules,
	RunParams = RunParams,
	Shift = Shift,
	Species = Species,
	Upgrades = Upgrades,
	Vehicles = Vehicles,
})
