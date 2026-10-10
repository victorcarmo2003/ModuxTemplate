--!strict
-- PromptBillboard: the custom interaction prompt in the world (port of AnimalPlane `PromptInterface`,
-- DEC-015, DEC-029, DEC-066). Three states:
--   Hidden    nothing drawn
--   Indicator small dot: "something here can be used"
--   Prompt    pill with the key chip (desktop/gamepad only) and the action text; fills while held
-- Pure: only props. PromptController (TASK-014) owns targeting, input and the hold timer; this only
-- draws `Holding` over `HoldDuration`. Taps on the pill reach OnPress/OnRelease only when the
-- BillboardGui is parented under PlayerGui.
-- Fixed pixel size (not studs) so the text keeps >= 14 px and the pill >= 44 px tall on a phone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local UseTween = require(script.Parent.UseTween)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type State = "Hidden" | "Indicator" | "Prompt"

export type Props = {
	Adornee: Instance?,
	State: () -> State,
	-- Action text from the target's `PromptText` (e.g. "Grill", "Take Order").
	Text: () -> string,
	-- Key shown in the chip ("E", "X"). Empty string hides the chip (mobile uses the fixed button).
	KeyLabel: () -> string,
	Holding: () -> boolean,
	-- Seconds the action must be held; 0 = tap.
	HoldDuration: () -> number,
	OnPress: (() -> ())?,
	OnRelease: (() -> ())?,
	StudsOffset: Vector3?,
	Name: string?,
}

const PILL_HEIGHT = 48
const CHIP_SIZE = 34
const DOT_SIZE = 14
const TEXT_SIZE = 20
const RELEASE_TIME = 0.15

return function(props: Props): BillboardGui
	const hovered = source(false)

	local function isPrompt(): boolean
		return props.State() == "Prompt"
	end

	local function hasKey(): boolean
		return props.KeyLabel() ~= ""
	end

	-- Hold fill: linear over HoldDuration while held, quick drain from wherever it stopped on release.
	const fill = UseTween(function()
		return if props.Holding() and isPrompt() then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
	end, function()
		return if untrack(props.Holding) then untrack(props.HoldDuration) else RELEASE_TIME
	end, Enum.EasingStyle.Linear)

	const pillScale = spring(function()
		if not isPrompt() then
			return 0
		elseif props.Holding() then
			return 0.95
		elseif hovered() then
			return 1.05
		end
		return 1
	end, 0.2, 1)

	const dotSize = spring(function()
		return if props.State() == "Indicator" then DOT_SIZE else 0
	end, 0.15, 1)

	return create("BillboardGui")({
		Name = props.Name or "PromptBillboard",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(320, 72),
		StudsOffset = props.StudsOffset or Vector3.zero,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true,
		ClipsDescendants = false,
		Enabled = function()
			return props.State() ~= "Hidden" or pillScale() > 0.01 or dotSize() > 0.5
		end,

		create("Frame")({
			Name = "Indicator",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				const size = dotSize()
				return UDim2.fromOffset(size, size)
			end,
			Visible = function()
				return dotSize() > 0.5
			end,
			BackgroundColor3 = Theme.Color.Mustard,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
		}),

		create("CanvasGroup")({
			Name = "Pill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, PILL_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = Theme.Transparency.Panel,
			Visible = function()
				return pillScale() > 0.01
			end,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIScale")({ Scale = pillScale }),

			create("Frame")({
				Name = "HoldFill",
				Size = fill,
				BackgroundColor3 = Theme.Color.Mustard,
				BackgroundTransparency = 0.15,
				Visible = function()
					return fill().X.Scale > 0.001
				end,
			}),

			create("Frame")({
				Name = "Content",
				Size = UDim2.fromOffset(0, PILL_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 2,

				createRaw("UIPadding")({
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 18),
				}),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),

				create("Frame")({
					Name = "KeyChip",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(CHIP_SIZE, CHIP_SIZE),
					BackgroundColor3 = Theme.Color.Cream,
					Visible = hasKey,
					create("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),

					create("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						FontFace = Theme.Font.Title,
						TextSize = TEXT_SIZE,
						TextColor3 = Theme.Color.Ink,
						Text = props.KeyLabel,
					}),
				}),

				create("TextLabel")({
					Name = "Action",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, PILL_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					FontFace = Theme.Font.Body,
					TextSize = TEXT_SIZE,
					TextColor3 = Theme.Color.Text,
					Text = props.Text,
					createRaw("UIPadding")({
						-- Without a key chip the text needs its own left margin to stay off the pill edge.
						PaddingLeft = function()
							return UDim.new(0, if hasKey() then 0 else 10)
						end,
					}),
					createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = Theme.Stroke }),
				}),
			}),

			-- Touch/mouse target over the whole pill (>= 44 px tall).
			create("TextButton")({
				Name = "Hit",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 3,
				Active = true,
				MouseEnter = function()
					hovered(true)
				end,
				MouseLeave = function()
					hovered(false)
				end,
				MouseButton1Down = function()
					if props.OnPress then
						props.OnPress()
					end
				end,
				MouseButton1Up = function()
					if props.OnRelease then
						props.OnRelease()
					end
				end,
			}),
		}),
	})
end
