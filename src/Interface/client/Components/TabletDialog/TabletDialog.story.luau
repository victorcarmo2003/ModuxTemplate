--!strict
-- TabletDialog on a phone-sized frame (667 x 375 at UI scale 1). The customer's line types letter by letter on the
-- story's own clock (Content.OrderSpeech, the same speech TabletController builds from the server record), looping.
-- Pick the order, Pair for a 2nd hot dog, and Who: an ordinary customer (Normal / Stressed by its id) or one of the odd
-- ones (its text style; a Content.Tics row plays its tic: the freeze, the caption, the broken rest of the line).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local TabletDialog = require(script.Parent)

const create = Vide.create
const source = Vide.source
const derive = Vide.derive
const cleanup = Vide.cleanup

type Controls = {
	Order: () -> string,
	Pair: () -> boolean,
	Who: () -> string,
	Playing: () -> boolean,
	Shown: () -> boolean,
}

const ORDERS: { [string]: { string } } = {
	["K0 plain"] = {},
	["K2 mustard + cheese"] = { "mustard", "cheese" },
	["K3 ketchup + bacon + potato sticks"] = { "ketchup", "bacon", "potato_sticks" },
}

-- Who -> (NpcId, rig Variant): ids picked so the ordinary ones land Normal (1) and Stressed (5, OrderSpeech.StyleOf)
const WHO: { [string]: { Npc: number, Variant: string } } = {
	["Ordinary"] = { Npc = 1, Variant = "" },
	["Ordinary, stressed"] = { Npc = 5, Variant = "" },
	["Shaker (ANM-011)"] = { Npc = 4, Variant = "shake" },
	["Turned neck (ANM-012)"] = { Npc = 9, Variant = "neck" },
	["White eyes (ANM-013)"] = { Npc = 6, Variant = "eyes" },
	["Big head (ANM-014)"] = { Npc = 7, Variant = "bighead" },
	["Copy (ANM-004)"] = { Npc = 8, Variant = "mirror" },
	["Blank folks (ANM-001)"] = { Npc = 10, Variant = "blank" },
}

const LOOP_REST = 1.5 -- s the finished talk stays before it starts over

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Order = UILabs.Choose({ "K2 mustard + cheese", "K0 plain", "K3 ketchup + bacon + potato sticks" }),
		Pair = false,
		Who = UILabs.Choose({
			"Ordinary",
			"Ordinary, stressed",
			"Shaker (ANM-011)",
			"Turned neck (ANM-012)",
			"White eyes (ANM-013)",
			"Big head (ANM-014)",
			"Copy (ANM-004)",
			"Blank folks (ANM-001)",
		}),
		Playing = true,
		Shown = true,
	},
}, function(props)
	-- UI Labs types the control sources loosely; pin them to what the story reads.
	const controls: Controls = (props.controls :: any)

	local function set(keys: { string }): { [string]: boolean }
		const out: { [string]: boolean } = {}
		for _, key in keys do
			out[key] = true
		end
		return out
	end

	const speech = derive(function(): Content.Speech
		const who = WHO[controls.Who()] or WHO.Ordinary
		const row = Content.Tics.ByVariant[who.Variant]
		return Content.OrderSpeech.Build({
			Npc = who.Npc,
			Variant = who.Variant,
			Night = 5,
			Order = set(ORDERS[controls.Order()] or {}),
			Order2 = if controls.Pair() then set({ "ketchup" }) else nil,
			Tic = row,
			Said = if row ~= nil then Content.Tics.Said(row, 1, "Rookie") else nil,
		})
	end)

	const elapsed = source(0)
	const connection = RunService.Heartbeat:Connect(function(dt: number)
		if controls.Playing() then
			const span = Vide.untrack(speech).Duration + LOOP_REST
			elapsed((elapsed() + dt) % span)
		end
	end)
	cleanup(connection)

	local function now(): Content.SpeechAt
		return Content.OrderSpeech.At(Vide.untrack(speech), Vide.untrack(elapsed))
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
				elapsed()
				const style = Content.OrderTalk.Styles[speech().Style]
				return if style ~= nil and style.Voice == "You" and now().Phase == "After" then "Player" else "Customer"
			end,
			Text = function()
				return speech().Text
			end,
			Clock = function()
				const at = now()
				return { Typed = at.Typed, Phase = at.Phase }
			end,
			Style = function(): Content.TalkStyle?
				return Content.OrderTalk.Styles[speech().Style]
			end,
			Break = function(): number?
				return speech().Break
			end,
			Caption = function(): string?
				elapsed()
				return now().Caption
			end,
			Items = function()
				return speech().Items
			end,
			Reveal = function()
				elapsed()
				return now().Reveal
			end,
		}),
	})
end)
