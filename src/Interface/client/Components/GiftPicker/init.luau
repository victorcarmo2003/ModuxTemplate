--!strict
-- GiftPicker (TASK-353, owner request 2026-10-16, Provisional): who gets the gift. A LobbyWindow over the shop that
-- opened it (cartoon kit, mobile first, 560 x 300 at Scale 1, shrinks to fit a phone):
--   line     "Pick who gets <gift name>"
--   cards    the players of this server (never yourself) and the one found by username, as a row that scrolls
--            sideways: round headshot, display name, @name; the picked card turns Mustard
--   row      username box + Find (Players:GetUserIdFromNameAsync, the caller resolves) · Send (Green, the price;
--            Slate "Soon" while the gift product is not created; "..." while the server answers / the prompt is open)
-- Close: the round close button (and, from the caller, ButtonB / the Roblox menu). Gamepad: every card is Selectable
-- (Name "Recipient"), then the box, Find and Send. Pure: only props; the caller sends GiftPrompt and prompts the product.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonButton = require(script.Parent.CartoonButton)
local CartoonLabel = require(script.Parent.CartoonLabel)
local LobbyWindow = require(script.Parent.LobbyWindow)

const create = Vide.create
const source = Vide.source
const indexes = Vide.indexes
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; TextBox and ScrollingFrame are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Candidate = {
	UserId: number,
	Name: string, -- username (@name)
	DisplayName: string,
}

-- Username search: None (nothing typed yet) · Wait (resolving) · Missing (no such user / yourself; Text says why)
export type Lookup = { Kind: "None" | "Wait" | "Missing", Text: string }

export type Props = {
	Visible: () -> boolean,
	-- shown name of the gift ("Handful of Gems", "Cat Crew")
	Title: () -> string,
	-- price text of the Send button ("R$ 79")
	Price: () -> string,
	-- the gift product exists (ProductId > 0); false = "Soon", Send never fires
	Available: () -> boolean,
	Candidates: () -> { Candidate },
	Selected: () -> number, -- UserId, 0 = none
	Lookup: () -> Lookup,
	-- GiftPrompt on its way / purchase prompt open
	Busy: () -> boolean,
	OnSelect: (userId: number) -> (),
	OnSearch: (name: string) -> (),
	OnConfirm: () -> (),
	OnClose: () -> (),
	Scale: (() -> number)?,
}

const WIDTH = 560
const HEIGHT = 300
const LINE = 24
const CARD_W = 104
const CARD_H = 118
const AVATAR = 60
const ROW = 48
const FIND = 92
const SEND = 168
const GAP = 8
const MAX_NAME = 20 -- Roblox usernames are 3..20 characters

local function headshot(userId: number): string
	return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
end

return function(props: Props): Frame
	const text = source("")
	const waiting = function(): boolean
		return props.Lookup().Kind == "Wait"
	end

	const box = createRaw("TextBox")({
		Name = "Username",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = Theme.Font.Title,
		TextSize = 18,
		TextColor3 = Theme.Color.Ink,
		PlaceholderText = "Or type a username",
		PlaceholderColor3 = Theme.Color.Slate,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Selectable = true,
	}) :: TextBox

	local function search()
		const name = string.match(box.Text, "^%s*(.-)%s*$") or ""
		if name == "" or untrack(waiting) then
			return
		end
		props.OnSearch(name)
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > MAX_NAME then
			box.Text = string.sub(box.Text, 1, MAX_NAME)
			return
		end
		text(box.Text)
	end)
	box.FocusLost:Connect(function(enter: boolean)
		if enter then
			search()
		end
	end)

	const empty = function(): boolean
		return #props.Candidates() == 0
	end

	const cards = createRaw("ScrollingFrame")({
		Name = "Cards",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, CARD_H + 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Cream,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Selectable = false,
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}),
		createRaw("UIPadding")({
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingTop = UDim.new(0, 2),
		}),
		-- nobody else here
		CartoonLabel({
			Name = "Empty",
			Box = UDim2.new(0, WIDTH - 60, 0, CARD_H),
			TextSize = 18,
			Wrapped = true,
			Transparency = 0.15,
			Visible = empty,
			Text = "Nobody else is here. Type a username below!",
		}),
		indexes(props.Candidates, function(candidate: () -> Candidate, index: number)
			const picked = function(): boolean
				return props.Selected() == candidate().UserId
			end
			return CartoonButton({
				Name = "Recipient",
				LayoutOrder = index,
				Size = UDim2.fromOffset(CARD_W, CARD_H),
				Tone = function()
					return if picked() then Theme.Tone.Mustard else Theme.Tone.Cream
				end,
				Outline = function()
					return if picked() then Theme.Outline.Thick else Theme.Outline.Normal
				end,
				Radius = Theme.Radius.Card,
				Padding = 6,
				OnActivated = function()
					props.OnSelect(untrack(candidate).UserId)
				end,
				Children = {
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),
					create("ImageLabel")({
						Name = "Avatar",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(AVATAR, AVATAR),
						BackgroundColor3 = Theme.Color.Cream,
						Image = function()
							return headshot(candidate().UserId)
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
					}),
					CartoonLabel({
						Name = "DisplayName",
						LayoutOrder = 2,
						Box = UDim2.new(1, 0, 0, 20),
						TextSize = 16,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Truncate = true,
						Text = function()
							return candidate().DisplayName
						end,
					}),
					CartoonLabel({
						Name = "UserName",
						LayoutOrder = 3,
						Box = UDim2.new(1, 0, 0, 16),
						TextSize = Theme.MinTextSize,
						Color = Theme.Color.Dark,
						Stroke = 0,
						Transparency = 0.35,
						Truncate = true,
						Text = function()
							return `@{candidate().Name}`
						end,
					}),
				},
			})
		end),
	}) :: ScrollingFrame

	const canSend = function(): boolean
		return props.Available() and props.Selected() > 0 and not props.Busy()
	end

	return LobbyWindow({
		Name = "GiftPicker",
		Title = "Send a Gift",
		Icon = "Ui/sparkle",
		Size = Vector2.new(WIDTH, HEIGHT),
		Visible = props.Visible,
		Scale = props.Scale,
		OnClose = props.OnClose,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			CartoonLabel({
				Name = "Line",
				LayoutOrder = 1,
				Box = UDim2.new(1, 0, 0, LINE),
				TextSize = 18,
				Truncate = true,
				Text = function()
					const lookup = props.Lookup()
					if lookup.Kind == "Missing" then
						return lookup.Text
					end
					return `Pick who gets {props.Title()}`
				end,
				Color = function()
					return if props.Lookup().Kind == "Missing" then Theme.Color.Mustard else Color3.new(1, 1, 1)
				end,
			}),
			cards,
			create("Frame")({
				Name = "Row",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				CartoonPanel({
					Name = "Box",
					Size = UDim2.new(1, -(FIND + SEND + GAP * 2), 1, 0),
					Tone = Theme.Tone.White,
					Outline = Theme.Outline.Thick,
					Radius = Theme.Radius.Chip,
					Gloss = false,
					Padding = { Left = 10, Right = 10 },
					Children = { box },
				}),
				CartoonButton({
					Name = "Find",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -(SEND + GAP), 0, 0),
					Size = UDim2.fromOffset(FIND, ROW),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Teal,
					Enabled = function()
						return text() ~= "" and not waiting()
					end,
					Text = function()
						return if waiting() then "..." else "Find"
					end,
					OnActivated = search,
				}),
				CartoonButton({
					Name = "Send",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(SEND, ROW),
					TextSize = 18,
					Outline = Theme.Outline.Thick,
					Tone = Theme.Tone.Green,
					Enabled = canSend,
					Text = function()
						if not props.Available() then
							return "Soon"
						elseif props.Busy() then
							return "..."
						end
						return `Send  {props.Price()}`
					end,
					OnActivated = function()
						if untrack(canSend) then
							props.OnConfirm()
						end
					end,
				}),
			}),
		},
	})
end
