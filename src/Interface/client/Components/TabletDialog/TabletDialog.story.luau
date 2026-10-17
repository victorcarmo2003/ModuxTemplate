--!strict
-- TabletDialog on a phone-sized frame (667 x 375 at UI scale 1). "Playing" runs the talk on its own clock (the same steps
-- TabletController reads from the server: greeting, opening, one pop-up per item, "That's it!"); with it off, the Step
-- slider picks the moment by hand. Pick the order and turn Pair on for a 2nd hot dog.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local TabletDialog = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Order: () -> string,
	Pair: () -> boolean,
	Playing: () -> boolean,
	Step: () -> number,
	Shown: () -> boolean,
}

const ORDERS: { [string]: { string } } = {
	["K0 plain"] = {},
	["K2 mustard + cheese"] = { "mustard", "cheese" },
	["K3 ketchup + bacon + potato sticks"] = { "ketchup", "bacon", "potato_sticks" },
}

const DIALOG = Content.Restaurant.Dialog
const STEP_TIME = 0.6 -- s per step while Playing

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Order = UILabs.Choose({ "K2 mustard + cheese", "K0 plain", "K3 ketchup + bacon + potato sticks" }),
		Pair = false,
		Playing = true,
		Step = UILabs.Slider(4, 0, 12, 1),
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	local function items(): { string }
		const list: { string } = { "bun", "sausage" }
		for _, key in ORDERS[controls.Order()] or {} do
			table.insert(list, key)
		end
		if controls.Pair() then
			table.insert(list, "bun")
			table.insert(list, "sausage")
			table.insert(list, "ketchup")
		end
		return list
	end

	-- steps: 0 greeting, 1 opening, 2..(1 + #items) one item each, then the close line
	const elapsed = source(0)
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if controls.Playing() then
			elapsed((elapsed() + dt) % (STEP_TIME * (#items() + 4)))
		end
	end)
	cleanup(connection)

	local function step(): number
		return if controls.Playing() then math.floor(elapsed() / STEP_TIME) else controls.Step()
	end

	local function reveal(): number
		return math.clamp(step() - 1, 0, #items())
	end

	local function text(): string
		const s = step()
		if s <= 0 then
			return DIALOG.Greeting[1]
		elseif s == 1 then
			return DIALOG.Opening[1]
		elseif s <= 1 + #items() then
			const key = items()[s - 1]
			const lines = DIALOG.Ask[key]
			return if lines then lines[1] else key
		end
		return DIALOG.Close[1]
	end

	return create("Frame")({
		Name = "Phone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(667, 375),
		BackgroundColor3 = Color3.fromHex("#6B8F71"),
		TabletDialog({
			Shown = controls.Shown,
			Speaker = function(): TabletDialog.Speaker
				return if step() <= 0 then "Player" else "Customer"
			end,
			Text = text,
			Items = items,
			Reveal = reveal,
		}),
	})
end)
