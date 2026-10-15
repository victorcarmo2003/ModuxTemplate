--!strict
-- SettingsPanel: the settings window (TASK-279; owner request 2026-10-14, Provisional), cartoon kit, mobile first.
-- A LobbyWindow (600 x 310 at Scale 1, fits the smallest landscape phone) with two columns:
--   Sound  Music · Effects · Voices · Jumpscares   sliders 0..100% (Slider.luau)
--   Game   Prompts (Single / Multi) · Prep helper (On / Off) · Reduce motion (On / Off)   (Choice.luau)
--          and one small line under them (`Hint`, e.g. the key that opens the panel; "" = none)
-- Every change calls OnChange(key, value) at once (the owner applies it live and saves it debounced). No confirm button:
-- the window only closes (X). Texts in English; house palette only (Ink, Mustard, Cream; never red).
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local SettingsRules = require(ReplicatedStorage.shared.Settings.SettingsRules)
local Theme = require(script.Parent.Theme)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)
local Slider = require(script.Slider)
local Choice = require(script.Choice)

const create = Vide.create

export type Props = {
	Visible: () -> boolean,
	Values: () -> SettingsRules.Settings,
	OnChange: (key: SettingsRules.Key, value: any) -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
	-- Small line at the bottom of the Game column ("" or nil = none).
	Hint: (() -> string)?,
}

const WIDTH = 600
const HEIGHT = 310
const COLUMN_GAP = 16
const ROW = 44
const ROW_GAP = 4
const HEADING = 26

const ON_OFF: { Choice.Option } = {
	{ Key = "On", Text = "On" },
	{ Key = "Off", Text = "Off" },
}
const PROMPTS: { Choice.Option } = {
	{ Key = "Single", Text = "Single" },
	{ Key = "Multi", Text = "Multi" },
}

local function heading(text: string): TextLabel
	return CartoonLabel({
		Name = "Heading",
		LayoutOrder = 0,
		TextSize = 20,
		Color = Theme.Color.Mustard,
		Text = text,
		XAlignment = Enum.TextXAlignment.Left,
		Box = UDim2.new(1, 0, 0, HEADING),
	})
end

local function column(name: string, order: number, children: { any }): Frame
	return create("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(0.5, -COLUMN_GAP / 2, 1, 0),
		BackgroundTransparency = 1,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, ROW_GAP),
		}),
		children,
	}) :: Frame
end

return function(props: Props): Frame
	local function volume(key: SettingsRules.Key, label: string, order: number)
		return Slider({
			Name = key,
			LayoutOrder = order,
			Label = label,
			Height = ROW,
			Value = function(): number
				return (props.Values() :: any)[key]
			end,
			OnChange = function(value: number)
				props.OnChange(key, value)
			end,
		})
	end

	local function onOff(key: SettingsRules.Key, label: string, order: number)
		return Choice({
			Name = key,
			LayoutOrder = order,
			Label = label,
			Height = ROW,
			Options = ON_OFF,
			Value = function(): string
				return if (props.Values() :: any)[key] == true then "On" else "Off"
			end,
			OnChange = function(choice: string)
				props.OnChange(key, choice == "On")
			end,
		})
	end

	return LobbyWindow({
		Name = "SettingsPanel",
		Title = "Settings",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, COLUMN_GAP),
			}),

			column("Sound", 1, {
				heading("Sound"),
				volume("Music", "Music", 1),
				volume("Sfx", "Effects", 2),
				volume("Voice", "Voices", 3),
				volume("Scare", "Jumpscares", 4),
			}),

			column("Game", 2, {
				heading("Game"),
				Choice({
					Name = "PromptMode",
					LayoutOrder = 1,
					Label = "Prompts",
					Height = ROW,
					Options = PROMPTS,
					Value = function(): string
						return props.Values().PromptMode
					end,
					OnChange = function(choice: string)
						props.OnChange("PromptMode", choice)
					end,
				}),
				onOff("PrepAssist", "Prep helper", 2),
				onOff("ReducedMotion", "Less motion", 3),
				CartoonLabel({
					Name = "Hint",
					LayoutOrder = 4,
					TextSize = 14,
					Color = Theme.Color.Cream,
					Text = function()
						return if props.Hint then props.Hint() else ""
					end,
					XAlignment = Enum.TextXAlignment.Left,
					Box = UDim2.new(1, 0, 0, 22),
					Visible = function()
						return props.Hint ~= nil and props.Hint() ~= ""
					end,
				}),
			}),
		},
	})
end
