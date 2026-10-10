--!strict
-- CrewScreen on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, with the 6 MVP classes
-- from Content. Buy/Select are simulated here (after "Latency" seconds) the way the server answers: debit, unlock,
-- select. "Preview" builds the rigs with CrewRig (needs ReplicatedStorage.Assets.Crew synced; otherwise the
-- placeholder letter stays).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local CrewRig = require(ReplicatedStorage.shared.Crew.CrewRig)
local Theme = require(script.Parent.Parent.Theme)
local CrewScreen = require(script.Parent)
local CardState = require(script.Parent.Parent.CrewCard.State)

const create = Vide.create
const source = Vide.source
const effect = Vide.effect
const untrack = Vide.untrack
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Gems: () -> number,
	Latency: () -> number,
	Preview: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 1, 2, 0.05),
		Gems = UILabs.Slider(120, 0, 400, 5),
		Latency = UILabs.Slider(0.4, 0, 3, 0.1),
		Preview = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	const entries: { CrewScreen.Entry } = {}
	for _, class in Content.Classes.List do
		if class.InMvp then
			const species = Content.Species.ByKey[class.Species]
			const animal = if species then species.Name else class.Species
			table.insert(entries, {
				Key = class.Key,
				Title = class.Name,
				Animal = animal,
				Species = class.Species,
				Badge = string.upper(string.sub(animal, 1, 1)),
				Price = class.Price,
				Description = class.Description,
			})
		end
	end

	const gems = source(controls.Gems())
	const owned = source({ class_dog = true } :: { [string]: boolean })
	const selected = source("class_dog")
	const focus = source("class_dog")
	const pending = source("")

	-- the slider resets the balance
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

	local function stateOf(key: string): CardState.State
		const class = Content.Classes.ByKey[key]
		return CardState.Of(owned()[key] == true, selected() == key, gems(), if class then class.Price else 0)
	end

	-- What ClassService does with ClassAction (TASK-017), answered after the latency.
	local function act(key: string)
		const state = untrack(function()
			return stateOf(key)
		end)
		if state ~= "Owned" and state ~= "Buy" then
			return
		end
		pending(key)
		thread = task.delay(controls.Latency(), function()
			thread = nil
			if state == "Buy" then
				const price = Content.Classes.ByKey[key].Price
				if gems() >= price then
					const copy = table.clone(owned())
					copy[key] = true
					gems(gems() - price)
					owned(copy)
				end
			else
				selected(key)
			end
			pending("")
		end)
	end

	const screen = CrewScreen({
		Entries = entries,
		Visible = function()
			return true
		end,
		Gems = gems,
		StateOf = stateOf,
		Focus = focus,
		Busy = function()
			return pending() ~= ""
		end,
		OnFocus = function(key: string)
			focus(key)
		end,
		OnAction = act,
		OnClose = function()
			print("[CrewScreen story] close")
		end,
		Rig = function(species: string): Model?
			if not untrack(controls.Preview) then
				return nil
			end
			const ok, model = pcall(function(): Model
				const rig = CrewRig.Build(species, "crew", { Tag = false, Anchored = true, CFrame = CFrame.new(0, 3, 0) })
				CrewRig.Dress(rig)
				return rig
			end)
			if not ok then
				warn(`[CrewScreen story] no rig for {species}: {model}`)
				return nil
			end
			return model
		end,
		Scale = controls.Scale,
	})

	return create("Frame")({
		Name = "Screen",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = function()
			return if controls.Phone() then UDim2.fromOffset(667, 375) else UDim2.fromScale(1, 1)
		end,
		BackgroundColor3 = Theme.Color.Teal,
		BackgroundTransparency = 0.6,
		ClipsDescendants = true,
		screen,
	})
end)
