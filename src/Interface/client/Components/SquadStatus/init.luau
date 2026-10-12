--!strict
-- SquadStatus: the status card over the lobby Play button (user request 2026-10-12), cartoon kit (AST-091), mobile first.
-- Says at a glance whether the player is alone or in a squad:
--   title row    "SOLO" · "SQUAD 2/4" (Mustard tab text) and a Teal "Friends only" chip when the squad is friends only
--   slots row    one round slot per player the squad takes (Max): head shot of the member (ring: Mustard leader, Green
--                ready, Slate not ready) or an empty "+" slot; solo shows the player alone
--   status line  one short line ("Waiting for 1 player", "Starting in 3...", "Pick solo or squad"); hidden when empty
-- 210 px wide at UI scale 1, as tall as its rows (auto height). Pure: only props; the owner reads the Party set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Member = {
	UserId: number,
	Leader: boolean,
	Ready: boolean,
}

export type Info = {
	-- true = in a squad (title "SQUAD n/max"); false = alone ("SOLO")
	Squad: boolean,
	-- who is in it (solo: just the player)
	Members: { Member },
	-- slots to draw (squad: its MaxPlayers; solo: 1)
	Max: number,
	FriendsOnly: boolean,
	-- short line under the slots; "" = none
	Status: string,
}

export type Props = {
	Info: () -> Info,
	Visible: (() -> boolean)?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
}

const WIDTH = 210
const SLOT = 34
const SLOT_GAP = 6
const ROW = 24

type Slot = { Member: Member? }

local function headshot(userId: number): string
	return if userId > 0 then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` else ""
end

return function(props: Props): Frame
	const title = function(): string
		const info = props.Info()
		return if info.Squad then `SQUAD {#info.Members}/{info.Max}` else "SOLO"
	end
	const slots = function(): { Slot }
		const info = props.Info()
		const list: { Slot } = {}
		for index = 1, math.max(info.Max, #info.Members) do
			table.insert(list, { Member = info.Members[index] })
		end
		return list
	end
	const ring = function(member: Member): Color3
		if member.Leader then
			return Theme.Color.Mustard
		end
		return if member.Ready then Theme.Color.Green else Theme.Color.Slate
	end

	return CartoonPanel({
		Name = props.Name or "SquadStatus",
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Tone = Theme.Tone.Ink,
		Outline = Theme.Outline.Thick,
		Radius = Theme.Radius.Card,
		Lip = 3,
		Padding = { Top = 5, Bottom = 5, Left = 8, Right = 8 },
		Visible = props.Visible,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),

			-- title row
			create("Frame")({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				CartoonLabel({
					Name = "Text",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					TextSize = 18,
					Color = Theme.Color.Gold,
					Text = title,
				}),
				CartoonPanel({
					Name = "FriendsOnly",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(0, ROW - 2),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Teal,
					Lip = 2,
					Outline = 2,
					Padding = { Left = 8, Right = 8 },
					Visible = function()
						return props.Info().FriendsOnly
					end,
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = Theme.MinTextSize,
							Text = "Friends only",
						}),
					},
				}),
			}),

			-- slots row
			create("Frame")({
				Name = "Slots",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, SLOT),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, SLOT_GAP),
				}),
				indexes(slots, function(slot: () -> Slot, index: number)
					return create("Frame")({
						Name = "Slot",
						LayoutOrder = index,
						Size = UDim2.fromOffset(SLOT, SLOT),
						BackgroundColor3 = Theme.Color.Slate,
						BackgroundTransparency = function()
							return if slot().Member then 0 else 0.65
						end,
						create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						createRaw("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Thickness = 3,
							Color = function()
								const member = slot().Member
								return if member then ring(member) else Theme.Color.Slate
							end,
							Transparency = function()
								return if slot().Member then 0 else 0.4
							end,
						}),
						create("ImageLabel")({
							Name = "Avatar",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = function()
								const member = slot().Member
								return if member then headshot(member.UserId) else ""
							end,
							Visible = function()
								return slot().Member ~= nil
							end,
							create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						}),
						CartoonLabel({
							Name = "Empty",
							Box = UDim2.fromScale(1, 1),
							TextSize = 20,
							Color = Theme.Color.Slate,
							Stroke = 0,
							Text = "+",
							Visible = function()
								return slot().Member == nil
							end,
						}),
					})
				end),
			}),

			-- status line
			CartoonLabel({
				Name = "Status",
				LayoutOrder = 3,
				Box = UDim2.new(1, 0, 0, 20),
				TextSize = Theme.MinTextSize,
				Truncate = true,
				Text = function()
					return props.Info().Status
				end,
				Visible = function()
					return props.Info().Status ~= ""
				end,
			}),
		},
	})
end
