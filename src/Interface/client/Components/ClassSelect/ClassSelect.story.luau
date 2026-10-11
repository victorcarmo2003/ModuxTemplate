--!strict
-- ClassSelect on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, every class of Content
-- with the viewport stage (ClassStage). Buy (gems or Robux) and Equip are simulated after "Latency" seconds the way the
-- server answers. "Robux" pretends the class products exist (R$ from Content.Shop). "Preview" builds the rigs
-- (needs ReplicatedStorage.Assets.Crew synced; otherwise the placeholder letter stays).
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

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
	Latency: () -> number,
	Robux: () -> boolean,
	Preview: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 1, 2, 0.05),
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
		Badge = function()
			return string.upper(string.sub(focus(), 7, 7))
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
			const product = Content.Shop.ClassProducts.ByKey[key]
			return if product then product.Robux else nil
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
			print(`[ClassSelect story] PromptProductPurchase for {key}`)
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
	})

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Color3.fromHex("#8FD3F4"),
		ClipsDescendants = true,
		createRaw("UIGradient")({
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromHex("#BDE7FA"), Theme.Color.Teal),
		}),
		screen,
	})
end)
