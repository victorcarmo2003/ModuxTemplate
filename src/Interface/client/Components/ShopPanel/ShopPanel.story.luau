--!strict
-- ShopPanel on a phone-sized frame (iPhone SE landscape, 667 x 375) or the whole viewport, with the HUD button column
-- (gear + "M", cart + "B") and the quick note. "Phone" (default on) is the small-landscape check of the window. Controls: Night (Night-only cards), Device (key labels), "Nudge" shows the
-- note (click it: the shop opens and the Scare card blinks). Buying prints and fakes the receipt note (no server).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Parent.Theme)
local GearButton = require(script.Parent.Parent.GearButton)
local CartButton = require(script.Parent.Parent.CartButton)
local KeyHint = require(script.Parent.Parent.KeyHint)
local HudNudge = require(script.Parent.Parent.HudNudge)
local ShopPanel = require(script.Parent)

const create = Vide.create
const source = Vide.source
const untrack = Vide.untrack
const effect = Vide.effect

type Controls = {
	Phone: () -> boolean,
	Scale: () -> number,
	Night: () -> boolean,
	Device: () -> string,
	Nudge: () -> boolean,
}

const MATES = { { Id = 1, Text = "Mia" }, { Id = 2, Text = "Theo" }, { Id = 3, Text = "Juno" } }

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Phone = true,
		Scale = UILabs.Slider(1, 0.86, 1.6, 0.02), -- Theme.Scale: 1 phone, 1.4 at 1080p
		Night = true,
		Device = UILabs.Choose({ "KeyboardMouse", "Gamepad", "Touch" }),
		Nudge = false,
	},
}, function(props)
	const controls: Controls = (props.controls :: any)
	const open = source(true)
	const flash = source("")
	const picking = source(false :: ShopPanel.Pick | false)
	const status = source("")
	const nudge = source("")
	local pickKey = ""

	effect(function()
		const on = controls.Nudge()
		untrack(function()
			nudge(if on then "scare" else "")
			return nil
		end)
	end)

	const device = function(): KeyHint.Device
		return controls.Device() :: any
	end
	-- touch: full touch targets (HudScreen does the same)
	const buttonSize = function(): number
		return if controls.Device() == "Touch" then 44 else 38
	end

	const cards = function(): { ShopPanel.Card }
		const night = controls.Night()
		const out: { ShopPanel.Card } = {}
		for _, utility in Content.Shop.Utilities.List do
			const note = if utility.Night and not night then "Night only" else ""
			table.insert(out, {
				Key = utility.Key,
				Name = utility.Name,
				Text = utility.Text,
				Icon = utility.Icon,
				Price = `R$ {utility.Robux}`,
				Enabled = note == "",
				Note = note,
				Category = utility.Category,
				Tone = utility.Tone,
			})
		end
		return out
	end

	local function blink()
		task.spawn(function()
			for i = 1, 7 do
				flash(if i % 2 == 1 then "util_scare" else "")
				task.wait(0.15)
			end
			flash("")
		end)
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

		create("Frame")({
			Name = "Buttons",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = function()
				return UDim2.fromOffset(if controls.Device() == "Touch" then 44 else 38, 0)
			end,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
			}),
			GearButton({ LayoutOrder = 1, Size = buttonSize, OnActivated = function() end }),
			KeyHint({
				LayoutOrder = 2,
				Device = device,
				Key = Enum.KeyCode.M,
				Pad = Enum.KeyCode.ButtonSelect,
				PadText = "Select",
			}),
			CartButton({
				LayoutOrder = 3,
				Size = buttonSize,
				Open = open,
				Glow = function()
					return nudge() ~= ""
				end,
				OnActivated = function()
					open(not untrack(open))
				end,
			}),
			KeyHint({
				LayoutOrder = 4,
				Device = device,
				Key = Enum.KeyCode.B,
				Pad = Enum.KeyCode.DPadRight,
				PadText = "Right",
			}),
		}),

		HudNudge({
			Position = function()
				return UDim2.new(1, -10, 0, if controls.Device() == "Touch" then 106 else 134)
			end,
			-- words per device, as ShopController:NudgeLine
			Text = function()
				if nudge() == "" then
					return ""
				end
				const kind = controls.Device()
				return if kind == "Touch"
					then "Tap here to scare your friends"
					elseif kind == "Gamepad" then "Press {pad} to scare your friends"
					else "Press B to scare your friends"
			end,
			PadText = "Right",
			Touch = function()
				return controls.Device() == "Touch"
			end,
			OnActivated = function()
				nudge("")
				open(true)
				blink()
			end,
		}),

		ShopPanel({
			Visible = open,
			Items = cards,
			Categories = Content.Shop.Categories,
			Flash = flash,
			Picking = picking,
			Status = status,
			Scale = controls.Scale,
			OnBuy = function(key: string)
				const utility = Content.Shop.Utilities.ByKey[key]
				if utility.Target == "Mate" then
					pickKey = key
					picking({ Title = "Who do you want to scare?", Options = MATES })
					return
				elseif utility.Target == "Ingredient" then
					const options: { ShopPanel.Option } = {}
					for index, ingredient in Content.Ingredients.List do
						table.insert(options, { Id = index, Text = ingredient.Name })
					end
					pickKey = key
					picking({ Title = "Which one do you want to refill?", Options = options })
					return
				end
				print(`[ShopPanel story] buy {key}`)
				status("Coming soon: this item is not on sale yet.")
			end,
			OnPick = function(id: number)
				print(`[ShopPanel story] buy {pickKey} -> {id}`)
				picking(false)
				status("Coming soon: this item is not on sale yet.")
			end,
			OnBack = function()
				picking(false)
			end,
			OnClose = function()
				open(false)
			end,
		}),
	})
end)
