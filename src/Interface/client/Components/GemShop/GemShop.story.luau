--!strict
-- GemShop with the packs of Content.Shop.GemPacks on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole
-- viewport. "Created" pretends every product exists (ProductId > 0); off = the real table (ids still 0 -> "Soon").
-- Buying adds the gems after "Latency" seconds, the way the receipt would.
-- TASK-301: "Split" passes Base / Bonus / Badge from the table (off = the Pack without them, the LobbyController shape:
-- the component reads them from Content by key, same result; read on the next rebuild: flip "Created").
-- "Live" fakes a Creator Hub price (-10%) on every pack.
-- Reduced motion: toggle the game Settings switch (or the Roblox setting) and the shine / pulse stop within 0.5 s.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local GemShop = require(script.Parent)

const create = Vide.create
const source = Vide.source
const cleanup = Vide.cleanup

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Created: () -> boolean,
	Latency: () -> number,
	Split: () -> boolean,
	Live: () -> boolean,
}

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Created = true,
		Latency = UILabs.Slider(1, 0, 3, 0.1),
		Split = true,
		Live = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const gems = source(25)
	const busy = source(false)

	local thread: thread? = nil
	cleanup(function()
		if thread and coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end)

	local function packs(created: boolean): { GemShop.Pack }
		const split = Vide.untrack(controls.Split)
		const list: { GemShop.Pack } = {}
		for _, pack in Content.Shop.GemPacks.List do
			table.insert(list, {
				Key = pack.Key,
				Name = pack.Name,
				Gems = pack.Gems,
				Robux = pack.Robux,
				Available = created or pack.ProductId > 0,
				Base = if split then pack.Base else nil,
				Bonus = if split then pack.Bonus else nil,
				Badge = if split then pack.Badge else nil,
			})
		end
		return list
	end

	const priceOf = function(key: string): number?
		if not controls.Live() then
			return nil
		end
		return math.floor(Content.Shop.GemPacks.ByKey[key].Robux * 0.9)
	end

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

		-- rebuilt when "Created" flips (the pack list is static props)
		Vide.show(controls.Created, function()
			return GemShop({
				Packs = packs(true),
				Visible = function()
					return true
				end,
				Gems = gems,
				PriceOf = priceOf,
				Busy = busy,
				OnBuy = function(key: string)
					busy(true)
					thread = task.delay(controls.Latency(), function()
						thread = nil
						gems(gems() + Content.Shop.GemPacks.ByKey[key].Gems)
						busy(false)
					end)
				end,
				OnClose = function()
					print("[GemShop story] close")
				end,
				Scale = controls.Scale,
			})
		end, function()
			return GemShop({
				Packs = packs(false),
				Visible = function()
					return true
				end,
				Gems = gems,
				OnBuy = function(key: string)
					print(`[GemShop story] buy {key}`)
				end,
				OnClose = function()
					print("[GemShop story] close")
				end,
				Scale = controls.Scale,
			})
		end),
	})
end)
