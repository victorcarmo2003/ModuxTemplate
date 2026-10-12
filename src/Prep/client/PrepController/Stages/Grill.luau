--!strict
-- Stage Grill (tab Grill; TASK-177, docs/tech/prep-mode.md §2 (a), docs/art/prep-ui-spec.md §5.2): the slots of the grill, a
-- chip with the rail. An empty slot adds a sausage (PrepGrill Place), a cooking one shows the bar with the flip window
-- (Content.Prep.Rules.Grill, 40 % to 60 % of the Duration) and, inside it, the cell glows ("Flip!"); a ready one is collected
-- to the rail. The flip is stamped with the SERVER clock and its grade comes back in PrepResult (mini seal on the cell); a
-- sausage never flipped is Messy when collected (Q-222), nothing burns. The grill keeps cooking while the player is on
-- another tab: the Feed reads the Stations set whatever tab is in front, and the tab badge counts the ready ones.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Components = StarterPlayer.StarterPlayerScripts.client.Interface.Components
local CartoonButton = require(Components.CartoonButton)
local CartoonLabel = require(Components.CartoonLabel)
local CartoonPanel = require(Components.CartoonPanel)
local Seal = require(Components.PlateView.Seal)
local Theme = require(Components.Theme)
local Cards = require(script.Parent.Parent.Cards)
local Feed = require(script.Parent.Parent.Feed)
local Stage = require(script.Parent.Parent.Stage)

const create = Vide.create
-- Vide 0.4.1 types `create` for 19 classes only; UIGridLayout and UIStroke are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const prep = Content.Prep
const window = prep.Rules.Grill

const CELL_HEIGHT = 80 -- px of a cell when the grill has one row (2 slots)
const GAP = 6
const RAIL_HEIGHT = 30
const RAIL_ICONS = 6
const OUT_TEXT = "Out of sausages" -- Provisional
-- food colours of the sausage drawn in the cell (pictures of food, not UI states)
const RAW = Color3.fromHex("#EFAFA6")
const DONE = Color3.fromHex("#B9573C")

local function labelOf(slot: Feed.Slot, stock: number): string
	if slot.State == "Empty" then
		return if stock == 0 then "Out" else "Add"
	elseif slot.State == "Cooking" then
		return "Cooking"
	elseif slot.State == "Window" then
		return "Flip!"
	elseif slot.State == "Late" then
		return "Flip late"
	elseif slot.State == "Flipped" then
		return "Flipped"
	end
	return "Collect"
end

local function toneOf(slot: Feed.Slot, stock: number): Theme.Tone
	if slot.State == "Empty" then
		return if stock == 0 then Theme.Tone.Slate else Theme.Tone.Cream
	elseif slot.State == "Window" then
		return Theme.Tone.Mustard
	elseif slot.State == "Ready" then
		return Theme.Tone.Green
	end
	return Theme.Tone.Cream
end

-- The bar of a cooking sausage: the fill, and the bracket of the flip window (a shape, not only a colour).
local function bar(slot: () -> Feed.Slot): Frame
	return create("Frame")({
		Name = "Bar",
		LayoutOrder = 3,
		Size = UDim2.new(1, -8, 0, 14),
		BackgroundColor3 = Theme.Tone.Cream.Lip,
		Visible = function(): boolean
			const state = slot().State
			return state == "Cooking" or state == "Window" or state == "Late" or state == "Flipped"
		end,
		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("Frame")({
			Name = "Fill",
			Size = function(): UDim2
				return UDim2.fromScale(math.clamp(slot().Progress, 0.04, 1), 1)
			end,
			BackgroundColor3 = Theme.Color.Cooking,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("Frame")({
			Name = "Window",
			Position = UDim2.fromScale(window.From, -0.2),
			Size = UDim2.fromScale(window.To - window.From, 1.4),
			BackgroundTransparency = 1,
			ZIndex = 3,
			create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		}),
	})
end

-- The picture of the cell: "+" (empty), the sausage (cooking, rawer to browner), a check (ready).
local function picture(slot: () -> Feed.Slot, stock: () -> number): Frame
	return create("Frame")({
		Name = "Picture",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		CartoonLabel({
			Name = "Plus",
			Text = "+",
			TextSize = 28,
			Color = function(): Color3
				return if stock() == 0 then Theme.Tone.Slate.Lip else Theme.Color.Ink
			end,
			Stroke = 0,
			Box = UDim2.fromScale(1, 1),
			Visible = function(): boolean
				return slot().State == "Empty"
			end,
		}),
		create("Frame")({
			Name = "Sausage",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(46, 16),
			BackgroundColor3 = function(): Color3
				return RAW:Lerp(DONE, math.clamp(slot().Progress, 0, 1))
			end,
			Visible = function(): boolean
				const state = slot().State
				return state == "Cooking" or state == "Window" or state == "Late" or state == "Flipped"
			end,
			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			-- the marks of a flipped sausage
			create("Frame")({
				Name = "Mark1",
				Position = UDim2.fromScale(0.3, 0.2),
				Size = UDim2.fromScale(0.06, 0.6),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
				Visible = function(): boolean
					return slot().Flipped ~= false
				end,
			}),
			create("Frame")({
				Name = "Mark2",
				Position = UDim2.fromScale(0.6, 0.2),
				Size = UDim2.fromScale(0.06, 0.6),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
				Visible = function(): boolean
					return slot().Flipped ~= false
				end,
			}),
		}),
		create("Frame")({
			Name = "Done",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 1,
			Visible = function(): boolean
				return slot().State == "Ready"
			end,
			Cards.CheckMark(24),
		}),
	})
end

local function cell(controller: any, index: number): Frame
	const slot = Feed.Slots[index]
	const read = function(): Feed.Slot
		return slot()
	end
	const stock = function(): number
		return Feed.Stock()
	end
	-- a refused act shakes the cell; a refused Place (slot unknown) shakes every empty one
	const own = Cards.Shaker("slot", index)
	const everyEmpty = Cards.Shaker("slot", 0)
	const flash = function(): Feed.Grade?
		const mark = Feed.Flash()[index]
		if mark ~= nil then
			return mark.Grade
		end
		const flipped = slot().Flipped
		return if flipped ~= false then flipped else nil
	end

	-- the grid owns the position of the cell: the button moves inside a holder (the shake)
	const button = CartoonButton({
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		Tone = function(): Theme.Tone
			return toneOf(slot(), stock())
		end,
		Radius = Theme.Radius.Card,
		Outline = function(): number
			return if slot().State == "Window" then Theme.Outline.Thin + 1 + math.floor(Feed.Pulse() * 2 + 0.5) else Theme.Outline.Normal
		end,
		Position = function(): UDim2
			return UDim2.fromOffset(own() + (if slot().State == "Empty" then everyEmpty() else 0), 0)
		end,
		Padding = 4,
		Children = {
			create("Frame")({
				Name = "Rows",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				CartoonLabel({
					Name = "State",
					LayoutOrder = 1,
					Text = function(): string
						return labelOf(slot(), stock())
					end,
					TextSize = 16,
					Color = Theme.Color.Ink,
					Stroke = 0,
					Box = UDim2.new(1, 0, 0, 20),
					Wrapped = true,
					Truncate = true,
				}),
				picture(read, stock),
				bar(read),
			}),
			Seal({
				Name = "Grade",
				Size = 26,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 2, 0, -4),
				Grade = flash,
			}),
		},
		OnActivated = function()
			const state = slot().State
			if state == "Empty" then
				if stock() == 0 then
					controller:Toast(OUT_TEXT, "Alert")
					return
				end
				Feed.Place(controller)
			elseif state == "Window" or state == "Late" then
				Feed.Flip(controller, index)
			elseif state == "Ready" then
				Feed.Collect(controller, index)
			end
		end,
	})
	return create("Frame")({
		Name = `Slot{index}`,
		LayoutOrder = index,
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return slot().Exists
		end,
		button,
	})
end

-- The rail as a chip: "Ready x3" and one little sausage per piece (spec §5.2).
local function rail(): Frame
	const minis: { any } = {}
	for index = 1, RAIL_ICONS do
		table.insert(
			minis,
			create("Frame")({
				Name = `Piece{index}`,
				LayoutOrder = index + 1,
				Size = UDim2.fromOffset(20, 10),
				BackgroundColor3 = DONE,
				Visible = function(): boolean
					return Feed.Rail() >= index
				end,
				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			})
		)
	end
	return CartoonPanel({
		Name = "Rail",
		Tone = Theme.Tone.Cream,
		Radius = Theme.Radius.Pill,
		Lip = 3,
		Outline = 2,
		Gloss = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, RAIL_HEIGHT),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Padding = { Left = 10, Right = 10 },
		Children = {
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			CartoonLabel({
				LayoutOrder = 1,
				Name = "Count",
				Text = function(): string
					const count = Feed.Rail()
					return if count > 0 then `Ready x{count}` else "Rail empty"
				end,
				TextSize = Theme.MinTextSize,
				Color = Theme.Color.Ink,
				Stroke = 0,
			}),
			minis,
		},
	})
end

const Grill: Stage.Stage = {
	Tab = "Grill",
	HasPanel = false,
	Board = function(controller: any): any
		const cells: { any } = {
			createRaw("UIGridLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				FillDirection = Enum.FillDirection.Horizontal,
				CellPadding = UDim2.fromOffset(GAP, GAP),
				CellSize = function(): UDim2
					const count = Feed.SlotCount()
					const cols = if count <= 4 then 2 else 4
					const rows = math.max(1, math.ceil(count / cols))
					if rows == 1 then
						return UDim2.new(1 / cols, -GAP, 0, CELL_HEIGHT)
					end
					return UDim2.new(1 / cols, -GAP, 1 / rows, -GAP)
				end,
			}),
		}
		for index = 1, 8 do
			table.insert(cells, cell(controller, index))
		end
		return create("Frame")({
			Name = "GrillBoard",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("Frame")({
				Name = "Slots",
				Size = UDim2.new(1, 0, 1, -(RAIL_HEIGHT + 4)),
				BackgroundTransparency = 1,
				Visible = Feed.HasGrill,
				cells,
			}),
			create("Frame")({
				Name = "RailRow",
				Position = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				Size = UDim2.new(1, 0, 0, RAIL_HEIGHT),
				BackgroundTransparency = 1,
				Visible = Feed.HasGrill,
				rail(),
			}),
			Cards.Empty(function(): string
				return "No grill here"
			end, function(): boolean
				return not Feed.HasGrill()
			end),
		})
	end,
	Hint = function(_controller: any): string
		if not Feed.HasGrill() then
			return "No grill here"
		end
		local ready = false
		for index = 1, 8 do
			const state = Feed.Slots[index]().State
			if state == "Window" then
				return "Flip now!"
			elseif state == "Ready" then
				ready = true
			end
		end
		if ready then
			return "A sausage is ready: Collect"
		elseif Feed.Stock() == 0 then
			return OUT_TEXT
		end
		return prep.Steps.ByKey.grill.Hint
	end,
	Next = function(_controller: any): Stage.Next
		return { Label = prep.Steps.ByKey.grill.NextLabel, Enabled = true, Pulse = Feed.Rail() > 0 and Feed.Pinned() ~= 0 }
	end,
	OnEnter = function(controller: any)
		Feed.Start(controller)
	end,
	OnNext = function(controller: any)
		controller:SetStage("bun")
	end,
}

return Grill
