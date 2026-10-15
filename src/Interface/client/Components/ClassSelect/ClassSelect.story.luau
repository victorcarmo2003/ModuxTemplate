--!strict
-- ClassSelect on a phone (iPhone SE landscape, 667 x 375), a tablet (1024 x 768) or the whole viewport, every class
-- of Content with the viewport stage (ClassStage). Check: list and card centred on the vertical, ~70% tall
-- (TASK-297), class name over the arrows without cutting "Line Cook" (TASK-298); card on Phone, Tablet and Viewport:
-- content packed at the top (portrait + chips, blurb, bars around the Rookie middle line, passive skill cards with
-- their icons, TASK-302; outlines whole on all 4 sides), free height only above the buttons (TASK-299; try Hawker
-- for the Tips bar, Hauler / Night Owl for the conditional speed, "Gems" 0 for the Need button); "TopBar" draws the
-- Roblox buttons the title tab and the panels must clear. Buy (gems or Robux) and Equip are simulated after "Latency"
-- seconds the way the server answers. "Robux" pretends the class products exist (R$ from Content.Shop). "Preview"
-- builds the rigs (needs ReplicatedStorage.Assets.Crew synced; otherwise only the floor shadow stays).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Theme = require(script.Parent.Parent.Theme)
local ClassStage = require(script.Parent.Parent.ClassStage)
local ClassSelect = require(script.Parent)
local Entries = require(script.Parent.Entries)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
const cleanup = Vide.cleanup
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const TOP_BAR = Vector2.new(120, 60) -- real px of the Roblox buttons on a phone (ClassSelect TOPBAR_LEFT / HEIGHT)

type Controls = {
	Device: () -> string,
	TopBar: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
	Latency: () -> number,
	Robux: () -> boolean,
	Preview: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Device = UILabs.Choose({ "Phone", "Tablet", "Viewport" }),
		TopBar = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Gems = UILabs.Slider(60, 0, 400, 5),
		Latency = UILabs.Slider(0.4, 0, 3, 0.1),
		Robux = true,
		Preview = true,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const entries = Entries.Build()

	const gems = source(controls.Gems())
	const owned = source({ class_dog = true } :: { [string]: boolean })
	const equipped = source("class_dog")
	const focus = source("class_dog")
	const pending = source(false)

	effect(function()
		const value = controls.Gems()
		untrack(function()
			gems(value)
			return nil
		end)
	end)

	local thread: thread? = nil
	cleanup(function()
		if thread and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end)

	local function later(callback: () -> ())
		pending(true)
		thread = task.delay(controls.Latency(), function()
			thread = nil
			callback()
			pending(false)
		end)
	end

	local function unlock(key: string)
		const copy = table.clone(owned())
		copy[key] = true
		owned(copy)
	end

	local function stateOf(key: string): ClassSelect.State
		const class = Content.Classes.ByKey[key]
		if owned()[key] then
			return if equipped() == key then "Equipped" else "Owned"
		end
		return if class and class.InMvp then "Locked" else "Soon"
	end

	const stage = ClassStage({
		Species = function()
			const class = Content.Classes.ByKey[focus()]
			return if class then class.Species else "dog"
		end,
		Visible = function()
			return true
		end,
		Rig = function(species: string): Model?
			if not untrack(controls.Preview) then
				return nil
			end
			const ok, model = pcall(function(): Model
				const rig = CrewRig.Build(species, "crew", { Tag = false, Anchored = true })
				CrewRig.Dress(rig)
				return rig
			end)
			return if ok then model else nil
		end,
	})

	const screen = ClassSelect({
		Entries = entries,
		Visible = function()
			return true
		end,
		Gems = gems,
		Focus = focus,
		StateOf = stateOf,
		RobuxOf = function(key: string): number?
			if not controls.Robux() then
				return nil
			end
			const pass = Content.Shop.GamePasses.ByKey[key]
			return if pass then pass.Robux else nil
		end,
		Busy = pending,
		OnFocus = function(key: string)
			focus(key)
		end,
		OnBuyGems = function(key: string)
			later(function()
				const price = Content.Classes.ByKey[key].Price
				if gems() >= price then
					gems(gems() - price)
					unlock(key)
				end
			end)
		end,
		OnBuyRobux = function(key: string)
			print(`[ClassSelect story] PromptGamePassPurchase for {key}`)
			later(function()
				unlock(key)
			end)
		end,
		OnEquip = function(key: string)
			later(function()
				equipped(key)
			end)
		end,
		OnClose = function()
			print("[ClassSelect story] close")
		end,
		Stage = stage,
		Scale = controls.Scale,
		Reserved = function()
			return if controls.TopBar() then TOP_BAR else Vector2.zero
		end,
	})

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			const device = controls.Device()
			return if device == "Phone"
				then UDim2.fromOffset(667, 375)
				elseif device == "Tablet" then UDim2.fromOffset(1024, 768)
				else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,
		createRaw("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromHex("#BDE7FA"), Theme.Color.Teal),
		}),
		screen,
		-- mock of the Roblox buttons (top left) the screen must not cover
		create("Frame")({
			Name = "RobloxTopBar",
			Size = UDim2.fromOffset(TOP_BAR.X, TOP_BAR.Y),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			ZIndex = 50,
			Visible = controls.TopBar,
		}),
	})
end)
