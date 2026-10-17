--!strict
-- StockMenu: the phone card (quick order, cost, "On the way 0:45"), the HUD supply chip (pulsing box icon, "Low on Buns")
-- and the world "xN" bay counter on a temporary part 8 studs in front of the Studio camera (removed when the story
-- closes). "Countdown" runs the 45 s delivery clock; "Phone" toggles the card; "Low" makes the chip pulse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local StockMenu = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

const ETA = 45
const PACKAGES = { "pack_sausages", "pack_buns", "pack_ketchup", "pack_bacon" }
const NAMES = { "Sausages", "Buns", "Ketchup", "Bacon" }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Kinds = UILabs.Slider(2, 0, 4, 1),
		Cash = UILabs.Slider(40, 0, 100, 1),
		Countdown = false,
		Low = true,
		Boxes = UILabs.Slider(3, 0, 6, 1),
		InWorld = true,
	},
}, function(props)
	const controls = props.controls

	const left = source(0)
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if controls.Countdown() then
			const value = left()
			left(if value <= 0 then ETA else math.max(value - dt, 0))
		elseif left() ~= 0 then
			left(0)
		end
	end)
	cleanup(connection)

	local function lines(): { StockMenu.Line }
		const kinds = controls.Kinds()
		const out: { StockMenu.Line } = {}
		-- 4 boxes spread over `kinds` packages, as the quick order does
		for index = 1, kinds do
			const count = 4 // kinds + (if index <= 4 % kinds then 1 else 0)
			table.insert(out, { Package = PACKAGES[index], Name = NAMES[index], Count = count })
		end
		return out
	end
	local function cost(): number
		local total = 2
		for _, line in lines() do
			total += line.Count * 5
		end
		return if #lines() == 0 then 0 else total
	end

	const card = StockMenu.new({
		Visible = controls.Phone,
		Lines = lines,
		Cost = cost,
		CanPay = function()
			return controls.Cash() >= cost()
		end,
		SecondsLeft = left,
		Hint = function()
			return "Hold E to call"
		end,
		Position = UDim2.new(0.5, 0, 0, 20),
	})

	const chip = StockMenu.Chip({
		Visible = function()
			return not controls.Phone() and (controls.Low() or left() > 0)
		end,
		Icon = function()
			return "Item/pack_buns"
		end,
		Text = function()
			return if left() > 0 then `On the way {StockMenu.Clock(left())}` else "Low on Buns"
		end,
		Pulse = controls.Low,
		Position = UDim2.new(0.5, 0, 0, 160),
	})

	const camera = workspace.CurrentCamera
	const anchor = Instance.new("Part")
	anchor.Name = "__StockMenuStory"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Size = Vector3.new(2.2, 1.6, 0.1)
	anchor.Color = Color3.fromRGB(214, 150, 72)
	anchor.CFrame = camera.CFrame * CFrame.new(0, -1, -8)
	anchor.Parent = workspace
	cleanup(anchor)

	const tag = StockMenu.Tag({
		Adornee = anchor,
		Visible = controls.InWorld,
		Text = function()
			return `x{controls.Boxes()}`
		end,
		Empty = function()
			return controls.Boxes() == 0
		end,
		Count = controls.Boxes,
		StudsOffset = Vector3.new(0, 1.6, 0),
	})
	tag.Parent = anchor

	return create("Frame")({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		card,
		chip,
	})
end)
