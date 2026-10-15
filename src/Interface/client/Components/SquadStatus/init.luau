--!strict
-- SquadStatus: the squad card over the lobby Play button (user request 2026-10-12), cartoon kit (AST-091), mobile first.
-- Says at a glance who is going to the run:
--   title row    "SOLO" or "SQUAD 2/4" (Gold)
--   chips row    "2 open spots" (Cream) and an access chip (Teal "Friends only", Violet "Invite only", Slate "Closed",
--                Mustard "Setting up"); hidden when neither applies
--   slots row    one column per player the squad takes (Max): the real head shot (Avatar: Players:GetUserThumbnailAsync,
--                cached, silhouette while loading / failed) in a round ring (Mustard leader with a crown diamond, Green
--                ready, Slate not ready), the short name under it and the state ("Leader", "Ready", "Waiting"; "You"
--                when solo). A free slot is a dashed circle with "+": tapping it opens the invite list (OnInvite), only
--                when `CanInvite` (leader, or alone) and not Starting
--   status line  one short line ("Waiting for 1 player", "Starting in 3...", "Pick solo or squad"); hidden when empty
-- As wide as its slots (UI scale 1), as tall as its rows (auto height). Pure: only props; the owner reads the Party set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local Avatar = require(script.Avatar)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke and UIPadding are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Member = {
	UserId: number,
	Leader: boolean,
	Ready: boolean,
	-- display name; nil / "" = "Player" (cut to a short form under the head shot)
	Name: string?,
}

export type Info = {
	-- true = in a squad (title "SQUAD n/max"); false = alone ("SOLO")
	Squad: boolean,
	-- who is in it (solo: just the player)
	Members: { Member },
	-- slots to draw (squad: its MaxPlayers; solo: 1)
	Max: number,
	FriendsOnly: boolean,
	-- who may join (PartyRules.Access): "Friends" Teal chip, "Invite" Violet "Invite only", "Closed" Slate, "Setup" Mustard
	-- "Setting up"; nil / "Open" = no chip (FriendsOnly still gives the Teal chip)
	Access: string?,
	-- short line under the slots; "" = none
	Status: string,
	-- free slots open the invite list (leader or alone); default false
	CanInvite: boolean?,
	-- the countdown runs: free slots stop inviting
	Starting: boolean?,
}

export type Props = {
	Info: () -> Info,
	Visible: (() -> boolean)?,
	Name: string?,
	AnchorPoint: Vector2?,
	Position: UDim2?,
	-- tap on a free slot (opens the invite list)
	OnInvite: (() -> ())?,
}

const SLOT = 44 -- avatar diameter
const COL = 58 -- one slot column (avatar + name)
const SLOT_GAP = 6
const ROW = 24
const SIDE = 8 -- card padding left / right
const MIN_WIDTH = 150
const NAME_MAX = 8 -- characters of a name before the ellipsis
const DASHES = 12

type Slot = { Member: Member? }

local function shortName(name: string?, userId: number): string
	local text = name or ""
	if text == "" then
		return if userId > 0 then "Player" else ""
	end
	if (utf8.len(text) or #text) > NAME_MAX then
		const cut = utf8.offset(text, NAME_MAX) or (NAME_MAX + 1)
		text = string.sub(text, 1, cut - 1) .. "."
	end
	return text
end

-- Dashed circle of an empty slot: DASHES small bars around the centre (Roblox has no dashed stroke).
local function dashes(diameter: number): { Instance }
	const list: { Instance } = {}
	const radius = diameter / 2 - 2
	for index = 1, DASHES do
		const angle = (index - 1) / DASHES * math.pi * 2
		table.insert(
			list,
			create("Frame")({
				Name = "Dash",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius),
				Size = UDim2.fromOffset(6, 3),
				Rotation = math.deg(angle) + 90,
				BackgroundColor3 = Theme.Color.Cream,
				BackgroundTransparency = 0.25,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			})
		)
	end
	return list
end

return function(props: Props): Frame
	const columns = function(): number
		const info = props.Info()
		return math.max(info.Max, #info.Members, 1)
	end
	const width = function(): number
		const count = columns()
		return math.max(MIN_WIDTH, count * COL + (count - 1) * SLOT_GAP + SIDE * 2)
	end
	const title = function(): string
		const info = props.Info()
		return if info.Squad then `SQUAD {#info.Members}/{info.Max}` else "SOLO"
	end
	const spots = function(): number
		const info = props.Info()
		return if info.Squad then math.max(info.Max - #info.Members, 0) else 0
	end
	const spotsText = function(): string
		const count = spots()
		return if count == 1 then "1 open spot" else `{count} open spots`
	end
	const slots = function(): { Slot }
		const info = props.Info()
		const list: { Slot } = {}
		for index = 1, columns() do
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
	const stateText = function(member: Member): string
		if not props.Info().Squad then
			return "You"
		end
		if member.Leader then
			return "Leader"
		end
		return if member.Ready then "Ready" else "Waiting"
	end
	const accessText = function(): string
		const info = props.Info()
		const access = info.Access
		if access == "Friends" or (access == nil and info.FriendsOnly) then
			return "Friends only"
		elseif access == "Invite" then
			return "Invite only"
		elseif access == "Closed" and info.Squad then
			return "Closed"
		elseif access == "Setup" then
			return "Setting up"
		end
		return ""
	end
	const accessTone = function(): Theme.Tone
		const access = props.Info().Access
		if access == "Invite" then
			return Theme.Tone.Violet
		elseif access == "Closed" then
			return Theme.Tone.Slate
		elseif access == "Setup" then
			return Theme.Tone.Mustard
		end
		return Theme.Tone.Teal
	end
	const canInvite = function(): boolean
		const info = props.Info()
		return info.CanInvite == true and info.Starting ~= true and props.OnInvite ~= nil
	end

	return CartoonPanel({
		Name = props.Name or "SquadStatus",
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = function()
			return UDim2.fromOffset(width(), 0)
		end,
		AutomaticSize = Enum.AutomaticSize.Y,
		Tone = Theme.Tone.Ink,
		Outline = Theme.Outline.Thick,
		Radius = Theme.Radius.Card,
		Lip = 3,
		Padding = { Top = 5, Bottom = 5, Left = SIDE, Right = SIDE },
		Visible = props.Visible,
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),

			-- title row
			CartoonLabel({
				Name = "Title",
				LayoutOrder = 1,
				Box = UDim2.new(1, 0, 0, ROW),
				TextSize = 18,
				Color = Theme.Color.Gold,
				XAlignment = Enum.TextXAlignment.Center,
				Text = title,
			}),

			-- chips row: open spots, friends only
			create("Frame")({
				Name = "Chips",
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, ROW - 2),
				BackgroundTransparency = 1,
				Visible = function()
					return spots() > 0 or accessText() ~= ""
				end,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				CartoonPanel({
					Name = "Spots",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(0, ROW - 2),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = Theme.Tone.Cream,
					Lip = 2,
					Outline = 2,
					Padding = { Left = 8, Right = 8 },
					Visible = function()
						return spots() > 0
					end,
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = Theme.MinTextSize,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Text = spotsText,
						}),
					},
				}),
				CartoonPanel({
					Name = "Access",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, ROW - 2),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = accessTone,
					Lip = 2,
					Outline = 2,
					Padding = { Left = 8, Right = 8 },
					Visible = function()
						return accessText() ~= ""
					end,
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = Theme.MinTextSize,
							-- white with the Ink stroke on every tone: Mustard's own dark text under a stroke was unreadable
							-- (TASK-305)
							Color = Theme.Color.Text,
							Text = accessText,
						}),
					},
				}),
			}),

			-- slots row
			create("Frame")({
				Name = "Slots",
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, SLOT_GAP),
				}),
				indexes(slots, function(slot: () -> Slot, index: number)
					return create("Frame")({
						Name = "Slot",
						LayoutOrder = index,
						Size = UDim2.fromOffset(COL, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 1),
						}),

						-- the player: head shot in a ring, crown diamond for the leader
						create("Frame")({
							Name = "Player",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(SLOT + 10, SLOT + 10),
							BackgroundTransparency = 1,
							Visible = function()
								return slot().Member ~= nil
							end,
							create("Frame")({
								Name = "Holder",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(SLOT + 8, SLOT + 8),
								BackgroundColor3 = Theme.Color.Ink,
								create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								create("UIListLayout")({
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Center,
								}),
								Avatar({
									Name = "Avatar",
									Size = SLOT,
									UserId = function()
										const member = slot().Member
										return if member then member.UserId else 0
									end,
									Ring = function()
										const member = slot().Member
										return if member then ring(member) else Theme.Color.Slate
									end,
								}),
							}),
							create("Frame")({
								Name = "Crown",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.new(1, -8, 0, 6),
								Size = UDim2.fromOffset(14, 14),
								Rotation = 45,
								BackgroundColor3 = Theme.Color.Mustard,
								ZIndex = 3,
								Visible = function()
									const member = slot().Member
									return member ~= nil and member.Leader and props.Info().Squad
								end,
								createRaw("UIStroke")({
									Thickness = 2,
									Color = Theme.Color.Ink,
								}),
							}),
						}),

						-- a free slot: dashed circle with "+", a button when the leader may invite
						create("TextButton")({
							Name = "Invite",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(SLOT + 10, SLOT + 10),
							BackgroundTransparency = 1,
							Text = "",
							AutoButtonColor = false,
							Active = canInvite,
							Selectable = canInvite,
							Visible = function()
								return slot().Member == nil
							end,
							Activated = function()
								if canInvite() and props.OnInvite then
									props.OnInvite()
								end
							end,
							create("Frame")({
								Name = "Circle",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(SLOT, SLOT),
								BackgroundColor3 = Theme.Color.Slate,
								BackgroundTransparency = function()
									return if canInvite() then 0.6 else 0.8
								end,
								create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
								dashes(SLOT),
								CartoonLabel({
									Name = "Plus",
									Box = UDim2.fromScale(1, 1),
									TextSize = 24,
									XAlignment = Enum.TextXAlignment.Center,
									YAlignment = Enum.TextYAlignment.Center,
									Color = function()
										return if canInvite() then Theme.Color.Mustard else Theme.Color.Slate
									end,
									Text = "+",
								}),
							}),
						}),

						CartoonLabel({
							Name = "Name",
							LayoutOrder = 2,
							Box = UDim2.new(1, 0, 0, 16),
							TextSize = Theme.MinTextSize,
							Truncate = true,
							XAlignment = Enum.TextXAlignment.Center,
							Text = function()
								const member = slot().Member
								return if member then shortName(member.Name, member.UserId) else "Open"
							end,
							Color = function()
								return if slot().Member then Theme.Color.Text else Theme.Color.Slate
							end,
						}),
						CartoonLabel({
							Name = "State",
							LayoutOrder = 3,
							Box = UDim2.new(1, 0, 0, 16),
							TextSize = Theme.MinTextSize,
							Truncate = true,
							XAlignment = Enum.TextXAlignment.Center,
							Color = function()
								const member = slot().Member
								return if member then ring(member) else Theme.Color.Slate
							end,
							Text = function()
								const member = slot().Member
								return if member then stateText(member) else ""
							end,
						}),
					})
				end),
			}),

			-- status line
			CartoonLabel({
				Name = "Status",
				LayoutOrder = 4,
				Box = UDim2.new(1, 0, 0, 20),
				TextSize = Theme.MinTextSize,
				Truncate = true,
				XAlignment = Enum.TextXAlignment.Center,
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
