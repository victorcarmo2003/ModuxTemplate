--!strict
--[[
	TicketHud (TASK-522, TASK-570; kitchen-world.md §1-§2; ui-text.md §17.5, Provisional)

	The ticket of the plate the local player holds, on the HUD, and the "#n" tag over a plate in a crewmate's hand.
	Presents only: the plate Tool attributes are written by PlateService, the order comes from the Customers set.

	  Read(tool)   the plate / hot dog Tool as a record (Item, PlateId, Ticket, TicketLine, Bun, Dog, Toppings, Quality,
	               Flipped of shared/Plate/PlateTool); Orphan = a plate with no ticket (yet, or its customer left); nil = not a
	               plate (Content.Items Category HotDog)
	  Track(p)     Vide sources of the local hands: Held = the EQUIPPED plate (or false), Hands = plates + hot dogs carried
	               (character and backpack). Follows respawns, backpack swaps and attribute writes at once (the HUD and the
	               prompts swap with the equipped plate well inside 0.2 s)
	  Card(props)  the HUD card: "#n" tab (Mustard; Slate "?" for an orphan), "Drive-thru" chip, one row of icons (bun,
	               sausage, then the order's toppings; faded = still missing on the plate), then the status lines: the grade
	               seal of an assembled plate, "No toppings", "Flip bonus", "Customer left", "+1 plate"
	  Screen(...)  the ScreenGui holding the card (scaled like the HUD, safe insets, off during a cinematic)
	  Tag(props)   BillboardGui "#n" + grade over a plate (a crewmate's hand, the grade of a central table slot)
	  TagHands(..) mounts a Tag on the plate Tool each OTHER player holds (the local hand has the HUD card)

	Status only (FEAT-032): nothing here is clickable. Sizes in px at UI scale 1 (smallest phone): icons 36 px, text >= 14 px.
	Texts are the ui-text.md §17.5 ids (BELT_HUD_*), kept here until Content opens keys for them (TASK-513 request).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Cinematic = require(StarterPlayer.StarterPlayerScripts.client.Interface.Cinematic)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local Icons = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Icons)
local CartoonPanel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonPanel)
local CartoonLabel = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.CartoonLabel)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIScale is not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const HOT_DOG = "hot_dog"
const CATEGORY = "HotDog"
const NO_GRADE = "None"
const MAX_TOPPINGS = Content.OrderRules.MaxToppings
-- keyed by band ("Perfect" | "Good" | "Messy"); read with the plain string of the Tool attribute / the set field
const GRADE_LABELS = (Content.Prep.Grades.Labels :: any) :: { [string]: string }

-- ui-text.md §17.5 (Provisional; BELT_HUD_*)
const TEXT = table.freeze({
	Drive = "Drive-thru", -- BELT_HUD_DRIVE
	NoToppings = "No toppings", -- BELT_HUD_NOTOP
	Flip = "Flip bonus", -- BELT_HUD_FLIP
	Orphan = "No ticket yet", -- the plate takes the oldest order (kitchen-world.md §2)
	More = "+%d plate", -- BELT_HUD_MORE
})

const CELL = 36
const GAP = 6
const PAD = 8
const LIP = 4
const TAB_HEIGHT = 24
const TAB_TEXT = 16
const LINE_TEXT = 14
const MISSING_TRANSPARENCY = 0.62
const TAG_SIZE = Vector2.new(120, 60)

const GRADE_TONE: { [string]: Theme.Tone } = {
	Perfect = Theme.Tone.Mustard,
	Good = Theme.Tone.Teal,
	Messy = Theme.Tone.Slate, -- never red (style guide §2.4)
}

-- Letter chip for a key with no cell in the sheet (same colours as HudOrder / PlateTicket)
const CHIP: { [string]: { Color: Color3, Label: string } } = {
	bun = { Color = Color3.fromHex("#E8B36B"), Label = "B" },
	sausage = { Color = Color3.fromHex("#C8553D"), Label = "S" },
	ketchup = { Color = Color3.fromHex("#E2402E"), Label = "K" },
	mustard = { Color = Color3.fromHex("#F6C12B"), Label = "M" },
	cheese = { Color = Color3.fromHex("#F39C2B"), Label = "Ch" },
	bacon = { Color = Color3.fromHex("#A8432F"), Label = "B" },
	potato_sticks = { Color = Color3.fromHex("#D9A55B"), Label = "PS" },
	cream_cheese = { Color = Theme.Color.Cream, Label = "CC" },
}

export type HeldPlate = {
	Tool: Tool,
	Item: string, -- "plate" (not assembled) | "hot_dog" (assembled)
	PlateId: number, -- 0 = not written
	Ticket: number, -- NpcId, 0 = none
	Line: number, -- 1 | 2 (pair partner)
	Orphan: boolean,
	Bun: boolean,
	Dog: boolean,
	Toppings: { [string]: boolean },
	Quality: string?, -- "Perfect" | "Good" | "Messy"; nil = no grade
	FlipBonus: boolean,
}

export type Cell = { Key: string, Done: boolean }

export type CardProps = {
	Shown: () -> boolean,
	Number: () -> number?,
	Drive: () -> boolean,
	-- bun, sausage, then the order's toppings (display order, max OrderRules.MaxToppings)
	Cells: () -> { Cell },
	NoToppings: () -> boolean,
	Grade: () -> string?,
	Flip: () -> boolean,
	Orphan: () -> boolean,
	-- other plates carried (0 = none)
	More: () -> number,
	Position: (() -> UDim2)?,
	Name: string?,
}

export type ScreenProps = {
	Card: CardProps,
	-- UI scale (Theme.ScaleOf of the viewport)
	Scale: () -> number,
	Name: string?,
}

export type TagProps = {
	Adornee: Instance?,
	Visible: () -> boolean,
	-- nil = no "#n" tab (only the grade)
	Number: (() -> number?)?,
	Grade: () -> string?,
	Orphan: (() -> boolean)?,
	StudsOffset: Vector3?,
	-- shift by a fraction of the tag's own size (rides over another billboard on the same adornee)
	SizeOffset: Vector2?,
	MaxDistance: number?,
	Name: string?,
}

export type Tracker = {
	Held: Vide.Source<HeldPlate | false>,
	Hands: Vide.Source<number>,
	Stop: () -> (),
}

const TicketHud = {}

local function numberAttr(instance: Instance, name: string): number
	const value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function stringAttr(instance: Instance, name: string): string?
	const value = instance:GetAttribute(name)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function parseToppings(value: string?): { [string]: boolean }
	const out: { [string]: boolean } = {}
	if value ~= nil then
		for _, key in string.split(value, ",") do
			if key ~= "" then
				out[key] = true
			end
		end
	end
	return out
end

-- true = a Tool of the HotDog category (plate or hot_dog): the plates the hands may carry (DEC-299)
function TicketHud.IsPlate(instance: Instance): boolean
	if not instance:IsA("Tool") then
		return false
	end
	const item = stringAttr(instance, "Item")
	const row = if item then Content.Items.ByKey[item] else nil
	return row ~= nil and row.Category == CATEGORY
end

-- The plate Tool as a record; nil = not a plate
function TicketHud.Read(instance: Instance?): HeldPlate?
	if instance == nil or not TicketHud.IsPlate(instance) then
		return nil
	end
	const tool = instance :: Tool
	const item = stringAttr(tool, "Item") :: string
	const assembled = item == HOT_DOG
	const quality = stringAttr(tool, "Quality")
	const line = numberAttr(tool, "TicketLine")
	return {
		Tool = tool,
		Item = item,
		PlateId = numberAttr(tool, "PlateId"),
		Ticket = numberAttr(tool, "Ticket"),
		Line = if line == 2 then 2 else 1,
		Orphan = numberAttr(tool, "PlateId") > 0 and numberAttr(tool, "Ticket") == 0,
		Bun = assembled or tool:GetAttribute("Bun") == true,
		Dog = assembled or tool:GetAttribute("Sausage") == true,
		Toppings = parseToppings(stringAttr(tool, "Toppings")),
		Quality = if quality ~= nil and quality ~= NO_GRADE and GRADE_LABELS[quality] ~= nil then quality else nil,
		FlipBonus = tool:GetAttribute("Flipped") == true,
	}
end

-- Value comparison, so a write that changes nothing the HUD reads does not rebuild it
local function same(a: HeldPlate | false, b: HeldPlate | false): boolean
	if a == false or b == false then
		return a == b
	end
	if
		a.Tool ~= b.Tool
		or a.Item ~= b.Item
		or a.PlateId ~= b.PlateId
		or a.Ticket ~= b.Ticket
		or a.Line ~= b.Line
		or a.Orphan ~= b.Orphan
		or a.Bun ~= b.Bun
		or a.Dog ~= b.Dog
		or a.Quality ~= b.Quality
		or a.FlipBonus ~= b.FlipBonus
	then
		return false
	end
	for key in a.Toppings do
		if not b.Toppings[key] then
			return false
		end
	end
	for key in b.Toppings do
		if not a.Toppings[key] then
			return false
		end
	end
	return true
end

-- Local hands: the equipped plate and the plate count, kept fresh by events (no polling)
function TicketHud.Track(player: Player): Tracker
	const held = Vide.source(false :: HeldPlate | false) :: Vide.Source<HeldPlate | false>
	const hands = Vide.source(0) :: Vide.Source<number>
	const connections: { RBXScriptConnection } = {}
	-- per container (character, backpack) and per Tool
	const watched: { [Instance]: { RBXScriptConnection } } = {}

	local function refresh()
		const character = player.Character
		const backpack = player:FindFirstChildOfClass("Backpack")
		local count = 0
		local equipped: HeldPlate | false = false
		if character ~= nil then
			for _, child in character:GetChildren() do
				if TicketHud.IsPlate(child) then
					count += 1
					if equipped == false then
						equipped = TicketHud.Read(child) or false
					end
				end
			end
		end
		if backpack ~= nil then
			for _, child in backpack:GetChildren() do
				if TicketHud.IsPlate(child) then
					count += 1
				end
			end
		end
		if Vide.untrack(hands) ~= count then
			hands(count)
		end
		if not same(Vide.untrack(held), equipped) then
			held(equipped)
		end
	end

	local function unwatch(instance: Instance)
		const list = watched[instance]
		if list == nil then
			return
		end
		watched[instance] = nil
		for _, connection in list do
			connection:Disconnect()
		end
	end

	local function watchTool(tool: Instance)
		if not tool:IsA("Tool") or watched[tool] ~= nil then
			return
		end
		watched[tool] = {
			tool.AttributeChanged:Connect(refresh),
			tool.AncestryChanged:Connect(function()
				if tool.Parent == nil then
					unwatch(tool)
				end
				refresh()
			end),
		}
	end

	local function watchContainer(container: Instance?)
		if container == nil or watched[container] ~= nil then
			return
		end
		watched[container] = {
			container.ChildAdded:Connect(function(child)
				watchTool(child)
				refresh()
			end),
			container.ChildRemoved:Connect(function()
				refresh()
			end),
			container.AncestryChanged:Connect(function()
				if container.Parent == nil then
					unwatch(container)
				end
				refresh()
			end),
		}
		for _, child in container:GetChildren() do
			watchTool(child)
		end
	end

	table.insert(
		connections,
		player.CharacterAdded:Connect(function(character)
			watchContainer(character)
			refresh()
		end)
	)
	table.insert(
		connections,
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchContainer(child)
				refresh()
			end
		end)
	)
	watchContainer(player.Character)
	watchContainer(player:FindFirstChildOfClass("Backpack"))
	refresh()

	return {
		Held = held,
		Hands = hands,
		Stop = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			for instance in table.clone(watched) do
				unwatch(instance)
			end
		end,
	}
end

local function chipOf(key: string): { Color: Color3, Label: string }
	return CHIP[key] or { Color = Theme.Color.Teal, Label = string.upper(string.sub(key, 1, 1)) }
end

local function iconCell(cell: () -> Cell, order: number): Frame
	local function name(): string
		return `Ingredient/{cell().Key}`
	end
	local function hasArt(): boolean
		return Icons.Has(name())
	end
	local function rect(): Icons.Rect
		return Icons.Rect(name()) or { Offset = Vector2.zero, Size = Vector2.zero }
	end
	local function faded(): number
		return if cell().Done then 0 else MISSING_TRANSPARENCY
	end
	return create("Frame")({
		Name = "Cell",
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = function()
			return chipOf(cell().Key).Color
		end,
		BackgroundTransparency = function()
			return if hasArt() then 1 else faded()
		end,
		create("UICorner")({ CornerRadius = Theme.Radius.Pill }),
		create("ImageLabel")({
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Image = function()
				return Icons.ImageOf(name())
			end,
			ImageRectOffset = function()
				return rect().Offset
			end,
			ImageRectSize = function()
				return rect().Size
			end,
			ImageTransparency = faded,
			Visible = hasArt,
		}),
		CartoonLabel({
			Name = "Letter",
			Box = UDim2.fromScale(1, 1),
			TextSize = LINE_TEXT,
			Text = function()
				return chipOf(cell().Key).Label
			end,
			Transparency = faded,
			Visible = function()
				return not hasArt()
			end,
		}),
	})
end

-- Small flat label of the status list
local function statusLine(text: () -> string, order: number): TextLabel
	return CartoonLabel({
		Name = "Line",
		LayoutOrder = order,
		TextSize = LINE_TEXT,
		Text = text,
		Color = Theme.Color.Dark,
		Stroke = 0,
	})
end

function TicketHud.Card(props: CardProps): Frame
	local function tabText(): string
		if props.Orphan() then
			return "?"
		end
		const number = props.Number()
		return if number ~= nil then `#{number}` else "#"
	end

	local function lines(): { string }
		const list: { string } = {}
		if props.Orphan() then
			table.insert(list, TEXT.Orphan)
		end
		if props.Grade() == nil and props.NoToppings() then
			table.insert(list, TEXT.NoToppings)
		end
		if props.Flip() then
			table.insert(list, TEXT.Flip)
		end
		const more = props.More()
		if more > 0 then
			table.insert(list, string.format(TEXT.More, more))
		end
		return list
	end

	return create("Frame")({
		Name = props.Name or "TicketHud",
		Position = props.Position or UDim2.fromOffset(8, 96),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = props.Shown,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, -6), -- the tab sits over the card edge
		}),

		-- Title row: "#n" tab and the drive-thru chip
		create("Frame")({
			Name = "Head",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, TAB_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			ZIndex = 2,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
			}),
			createRaw("UIPadding")({ PaddingLeft = UDim.new(0, PAD) }),
			CartoonPanel({
				Name = "Number",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, TAB_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				Rotation = -3,
				Tone = function()
					return if props.Orphan() then Theme.Tone.Slate else Theme.Tone.Mustard
				end,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 8, Right = 8 },
				ZIndex = 2,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = TAB_TEXT,
						Text = tabText,
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),
			CartoonPanel({
				Name = "Drive",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, TAB_HEIGHT - 4),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = Theme.Tone.Teal,
				Outline = Theme.Outline.Normal,
				Lip = 2,
				Padding = { Left = 6, Right = 6 },
				Visible = props.Drive,
				ZIndex = 2,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = LINE_TEXT,
						Text = TEXT.Drive,
					}),
				},
			}),
		}),

		-- The card: icons, then the grade seal and the status lines
		CartoonPanel({
			Name = "Card",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Tone = function()
				return if props.Orphan() then Theme.Tone.Cream else Theme.Tone.White
			end,
			Outline = Theme.Outline.Thick,
			Radius = Theme.Radius.Card,
			Lip = LIP,
			Padding = { Top = PAD + 4, Bottom = PAD, Left = PAD, Right = PAD },
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, 4),
				}),
				create("Frame")({
					Name = "Icons",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(0, CELL),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, GAP),
					}),
					indexes(function(): { Cell }
						const cells = props.Cells()
						if #cells > 2 + MAX_TOPPINGS then
							const cut: { Cell } = {}
							for index = 1, 2 + MAX_TOPPINGS do
								cut[index] = cells[index]
							end
							return cut
						end
						return cells
					end, iconCell),
				}),
				CartoonPanel({
					Name = "Grade",
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, TAB_HEIGHT),
					AutomaticSize = Enum.AutomaticSize.X,
					Tone = function()
						const grade = props.Grade()
						return if grade then GRADE_TONE[grade] or Theme.Tone.Teal else Theme.Tone.Teal
					end,
					Outline = Theme.Outline.Normal,
					Lip = 3,
					Padding = { Left = 8, Right = 8 },
					Visible = function()
						return props.Grade() ~= nil
					end,
					Children = {
						CartoonLabel({
							Box = UDim2.new(0, 0, 1, 0),
							AutomaticSize = Enum.AutomaticSize.X,
							TextSize = TAB_TEXT,
							Text = function()
								const grade = props.Grade()
								return if grade then GRADE_LABELS[grade] or grade else ""
							end,
							Color = Theme.Color.Dark,
							Stroke = 0,
						}),
					},
				}),
				indexes(lines, function(text: () -> string, order: number): TextLabel
					return statusLine(text, 2 + order)
				end),
			},
		}),
	})
end

-- The HUD layer: own ScreenGui, scaled like the Hud one (Theme.ScaleOf), same safe insets, off during a cinematic
function TicketHud.Screen(props: ScreenProps): ScreenGui
	return create("ScreenGui")({
		Name = props.Name or "PlateTicketHud",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1,
		Enabled = function()
			return not Cinematic.Active()
		end,
		create("Frame")({
			Name = "Layer",
			Size = function()
				const scale = props.Scale()
				return UDim2.fromScale(1 / scale, 1 / scale)
			end,
			BackgroundTransparency = 1,
			createRaw("UIScale")({ Scale = props.Scale }),
			TicketHud.Card(props.Card),
		}),
	})
end

-- "#n" + grade over a plate in the world (fixed px, like PlateTicket: readable on a phone, never AlwaysOnTop or Active)
function TicketHud.Tag(props: TagProps): BillboardGui
	const orphan = props.Orphan or function(): boolean
		return false
	end
	const readNumber = props.Number
	local function numberText(): string?
		if readNumber == nil then
			return nil
		elseif orphan() then
			return "?"
		end
		const number = readNumber()
		return if number ~= nil then `#{number}` else nil
	end
	return create("BillboardGui")({
		Name = props.Name or "PlateTag",
		Adornee = props.Adornee,
		Size = UDim2.fromOffset(TAG_SIZE.X, TAG_SIZE.Y),
		StudsOffset = props.StudsOffset or Vector3.new(0, 1, 0),
		SizeOffset = props.SizeOffset or Vector2.zero,
		MaxDistance = props.MaxDistance or 30,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = false,
		Enabled = function()
			return props.Visible() and (numberText() ~= nil or props.Grade() ~= nil) and not Cinematic.Active()
		end,
		create("Frame")({
			Name = "Root",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			CartoonPanel({
				Name = "Number",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, TAB_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = function()
					return if orphan() then Theme.Tone.Slate else Theme.Tone.Mustard
				end,
				Outline = Theme.Outline.Normal,
				Lip = 3,
				Padding = { Left = 8, Right = 8 },
				Visible = function()
					return numberText() ~= nil
				end,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = TAB_TEXT,
						Text = function()
							return numberText() or ""
						end,
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),
			CartoonPanel({
				Name = "Grade",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, TAB_HEIGHT - 2),
				AutomaticSize = Enum.AutomaticSize.X,
				Tone = function()
					const grade = props.Grade()
					return if grade then GRADE_TONE[grade] or Theme.Tone.Teal else Theme.Tone.Teal
				end,
				Outline = Theme.Outline.Normal,
				Lip = 2,
				Padding = { Left = 6, Right = 6 },
				Visible = function()
					return props.Grade() ~= nil
				end,
				Children = {
					CartoonLabel({
						Box = UDim2.new(0, 0, 1, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						TextSize = LINE_TEXT,
						Text = function()
							const grade = props.Grade()
							return if grade then GRADE_LABELS[grade] or grade else ""
						end,
						Color = Theme.Color.Dark,
						Stroke = 0,
					}),
				},
			}),
		}),
	})
end

-- A Tag on the plate Tool of every OTHER player (the local hand shows the HUD card). `number` reads #n of a ticket
-- (reactive). Returns the stop function.
function TicketHud.TagHands(parent: Instance, number: (npc: number) -> number?): () -> ()
	const me = Players.LocalPlayer
	const connections: { RBXScriptConnection } = {}
	-- Tool -> its tag (unmount, gui, attribute connection)
	const tags: { [Tool]: { Unmount: () -> (), Gui: Instance, Connection: RBXScriptConnection } } = {}

	local function drop(tool: Tool)
		const tag = tags[tool]
		if tag == nil then
			return
		end
		tags[tool] = nil
		tag.Connection:Disconnect()
		tag.Unmount()
		tag.Gui:Destroy()
	end

	local function mount(tool: Instance)
		if not TicketHud.IsPlate(tool) or tags[tool :: Tool] ~= nil then
			return
		end
		const plate = tool :: Tool
		const handle = plate:FindFirstChild("Handle")
		const record = Vide.source(TicketHud.Read(plate) or false) :: Vide.Source<HeldPlate | false>
		const connection = plate.AttributeChanged:Connect(function()
			record(TicketHud.Read(plate) or false)
		end)
		const unmount, gui = Vide.root(function()
			return TicketHud.Tag({
				Name = `PlateTag_{plate.Name}`,
				Adornee = handle or plate,
				StudsOffset = Vector3.new(0, 1.2, 0),
				Visible = function()
					const read = record()
					return read ~= false and (read.Ticket ~= 0 or read.Orphan)
				end,
				Number = function(): number?
					const read = record()
					return if read ~= false and read.Ticket ~= 0 then number(read.Ticket) else nil
				end,
				Grade = function(): string?
					const read = record()
					return if read ~= false then read.Quality else nil
				end,
				Orphan = function(): boolean
					const read = record()
					return read ~= false and read.Orphan
				end,
			})
		end)
		gui.Parent = parent
		tags[plate] = { Unmount = unmount, Gui = gui, Connection = connection }
	end

	local function watchCharacter(character: Model)
		table.insert(
			connections,
			character.ChildAdded:Connect(function(child)
				mount(child)
			end)
		)
		table.insert(
			connections,
			character.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") then
					drop(child)
				end
			end)
		)
		for _, child in character:GetChildren() do
			mount(child)
		end
	end

	local function watchPlayer(player: Player)
		if player == me then
			return
		end
		table.insert(connections, player.CharacterAdded:Connect(watchCharacter))
		if player.Character ~= nil then
			watchCharacter(player.Character)
		end
	end

	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for tool in table.clone(tags) do
			drop(tool)
		end
	end
end

return table.freeze(TicketHud)
