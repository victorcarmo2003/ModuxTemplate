--!strict
-- TaskList: the tutorial's tasks of this round, top right (DEC-311; owner 2026-10-19: "três tasks: fritar uma salsicha, cortar um
-- pão, servir um cliente"; "deixar a interface de tasks mais bonita"). A Cream CartoonPanel card (gradient, lip, Ink outline) with:
--   Tab      Mustard "Tasks" tab with the paw icon over the top-left corner, and a "1/3" progress chip on the right
--   Bar      a thin progress bar under the title that fills (Green) as tasks get done
--   Lines    one per task: the ingredient icon in a round chip, the text, and a check medallion on the right that pops Green
--            with the tick when done; the line then fades and gets a strike. The NEXT task (first not done) is the current
--            one: Mustard left bar, bold text, the icon chip breathes
--   Done     every task done: the card glows Green and a sparkle pops on the tab
-- Status only: nothing clickable. Pure: only props; build it inside a Vide root. Px at UI scale 1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)
local UiScale = require(script.Parent.UiScale)

const create = Vide.create
const indexes = Vide.indexes
const source = Vide.source
const cleanup = Vide.cleanup
-- Vide 0.4.1 types `create` for 19 classes only; UIStroke, UIPadding and UIScale are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Task = { Text: string, Done: boolean, Icon: string? }

export type Props = {
	Tasks: () -> { Task },
	Shown: () -> boolean,
	Scale: (() -> number)?,
	Position: UDim2?,
}

const WIDTH = 250
const LINE = 34
const CHIP = 28
const CHECK = 24
const BAR = 6
const PHONE = 0.72 -- owner 2026-10-20: the card covered the pickup prompt on a phone

-- An icon of the shared sheets in a square, or nothing when the name is unknown
local function icon(name: () -> string?, size: number, z: number): ImageLabel
	return create("ImageLabel")({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
		Image = function(): string
			const key = name()
			return if key then Icons.ImageOf(key) else ""
		end,
		ImageRectOffset = function(): Vector2
			const key = name()
			const rect = if key then Icons.Rect(key) else nil
			return if rect then rect.Offset else Vector2.zero
		end,
		ImageRectSize = function(): Vector2
			const key = name()
			const rect = if key then Icons.Rect(key) else nil
			return if rect then rect.Size else Vector2.zero
		end,
	}) :: ImageLabel
end

local function line(task: () -> Task, index: number, current: () -> number, clock: () -> number): Frame
	const done = function(): boolean
		return task().Done
	end
	const isCurrent = function(): boolean
		return current() == index
	end
	const pop = Motion.Pop(done)
	return create("Frame")({
		Name = `Task{index}`,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, LINE),
		BackgroundTransparency = 1,
		-- the current task's Mustard bar on the left
		create("Frame")({
			Name = "Now",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -6, 0.5, 0),
			Size = UDim2.fromOffset(4, LINE - 8),
			BackgroundColor3 = Theme.Color.Mustard,
			BorderSizePixel = 0,
			Visible = isCurrent,
			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		}),
		-- the ingredient chip
		create("Frame")({
			Name = "Chip",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(CHIP, CHIP),
			BackgroundColor3 = function(): Color3
				return if isCurrent() then Theme.Color.Mustard else Color3.fromHex("#FFF8EA")
			end,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
			createRaw("UIScale")({
				Scale = function(): number
					-- the current one breathes
					return if isCurrent() and not Motion.Reduced() then 1 + 0.08 * math.sin(clock() * 4) else 1
				end,
			}),
			icon(function(): string?
				return task().Icon
			end, CHIP - 6, 3),
		}),
		CartoonLabel({
			Name = "Text",
			Text = function(): string
				return task().Text
			end,
			TextSize = 16,
			Color = Theme.Color.Dark,
			Stroke = 0,
			Transparency = function(): number
				return if done() then 0.5 else 0
			end,
			Position = UDim2.fromOffset(CHIP + 10, 0),
			Box = UDim2.new(1, -(CHIP + 10 + CHECK + 8), 1, 0),
			XAlignment = Enum.TextXAlignment.Left,
			YAlignment = Enum.TextYAlignment.Center,
			Truncate = true,
		}),
		-- the strike over a done task
		create("Frame")({
			Name = "Strike",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, CHIP + 8, 0.5, 1),
			Size = function(): UDim2
				return UDim2.new(pop() * 0.62, 0, 0, 2)
			end,
			BackgroundColor3 = Theme.Color.Ink,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Visible = done,
		}),
		-- the check medallion
		create("Frame")({
			Name = "Check",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(CHECK, CHECK),
			BackgroundColor3 = function(): Color3
				return if done() then Theme.Color.Green else Color3.new(1, 1, 1)
			end,
			BorderSizePixel = 0,
			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			createRaw("UIStroke")({ Color = Theme.Color.Ink, Thickness = 2 }),
			createRaw("UIScale")({
				Scale = function(): number
					-- pops a little over size when it turns done
					const p = pop()
					return if done() then 0.85 + 0.15 * p + 0.25 * math.sin(math.clamp(p, 0, 1) * math.pi) else 1
				end,
			}),
			icon(function(): string?
				return if done() and Icons.Has("Ui/check") then "Ui/check" else nil
			end, CHECK - 6, 3),
			CartoonLabel({
				Name = "Tick",
				Text = function(): string
					return if done() and not Icons.Has("Ui/check") then "✓" else ""
				end,
				TextSize = 15,
				Stroke = 0,
				Position = UDim2.fromOffset(0, 0),
				Box = UDim2.fromScale(1, 1),
				XAlignment = Enum.TextXAlignment.Center,
				YAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	}) :: Frame
end

return function(props: Props): Frame
	-- the clock of the small loops (breathing chip, glow)
	const clock = source(0)
	const beat = RunService.Heartbeat:Connect(function()
		clock(os.clock())
	end)
	cleanup(function()
		beat:Disconnect()
	end)
	const total = function(): number
		return #props.Tasks()
	end
	const doneCount = function(): number
		local n = 0
		for _, task in props.Tasks() do
			if task.Done then
				n += 1
			end
		end
		return n
	end
	const current = function(): number
		for index, task in props.Tasks() do
			if not task.Done then
				return index
			end
		end
		return 0
	end
	const allDone = function(): boolean
		return total() > 0 and doneCount() == total()
	end
	const bump = Motion.Bump(doneCount, 1.12)
	const sparkle = Motion.Pop(allDone)

	return create("Frame")({
		Name = "TaskList",
		AnchorPoint = Vector2.new(1, 0),
		Position = props.Position or UDim2.new(1, -12, 0, 120),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = function(): boolean
			return props.Shown() and total() > 0
		end,
		createRaw("UIScale")({
			Scale = function(): number
				return (if props.Scale then props.Scale() else 1) * UiScale.Compact(PHONE) * bump()
			end,
		}),
		CartoonPanel({
			Name = "Card",
			Radius = UDim.new(0, 14),
			Tone = function(): Theme.Tone
				return if allDone() then Theme.Tone.Green else Theme.Tone.Cream
			end,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Padding = { Top = 22, Bottom = 10, Left = 14, Right = 12 },
			Children = {
				create("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				-- the progress bar
				create("Frame")({
					Name = "Progress",
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, BAR + 6),
					BackgroundTransparency = 1,
					create("Frame")({
						Name = "Track",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.new(1, 0, 0, BAR),
						BackgroundColor3 = Color3.fromHex("#E9DCC2"),
						BorderSizePixel = 0,
						create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
						create("Frame")({
							Name = "Fill",
							Size = function(): UDim2
								return UDim2.fromScale(if total() > 0 then doneCount() / total() else 0, 1)
							end,
							BackgroundColor3 = Theme.Color.Green,
							BorderSizePixel = 0,
							create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
						}),
					}),
				}),
				indexes(props.Tasks, function(task: () -> Task, index: number): Frame
					return line(task, index, current, clock)
				end),
			},
		}),
		-- the "Tasks" tab with the paw, over the top-left corner
		CartoonPanel({
			Name = "Tab",
			Tone = Theme.Tone.Mustard,
			Position = UDim2.fromOffset(10, -6),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			Lip = 2,
			Padding = { Left = 8, Right = 10 },
			ZIndex = 5,
			Children = {
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
				create("Frame")({
					Name = "Paw",
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					icon(function(): string?
						return if Icons.Has("Ui/paw") then "Ui/paw" else nil
					end, 18, 7),
				}),
				CartoonLabel({
					Name = "Title",
					Text = "Tasks",
					TextSize = 16,
					Color = Theme.Color.Dark,
					Stroke = 0,
					Box = UDim2.new(0, 0, 0, 22),
					AutomaticSize = Enum.AutomaticSize.X,
					YAlignment = Enum.TextYAlignment.Center,
				}),
			},
		}),
		-- the progress chip, top right
		CartoonPanel({
			Name = "Count",
			Tone = function(): Theme.Tone
				return if allDone() then Theme.Tone.Teal else Theme.Tone.Ink
			end,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, -4),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Lip = 2,
			Padding = { Left = 8, Right = 8 },
			ZIndex = 5,
			Children = {
				CartoonLabel({
					Name = "Text",
					Text = function(): string
						return `{doneCount()}/{total()}`
					end,
					TextSize = 14,
					Box = UDim2.new(0, 0, 0, 18),
					AutomaticSize = Enum.AutomaticSize.X,
					YAlignment = Enum.TextYAlignment.Center,
				}),
			},
		}),
		-- all done: a sparkle pops on the corner
		create("ImageLabel")({
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 6),
			Size = UDim2.fromOffset(34, 34),
			BackgroundTransparency = 1,
			ZIndex = 9,
			Visible = function(): boolean
				return sparkle() > 0.02 and Icons.Has("Ui/sparkle")
			end,
			Image = Icons.ImageOf("Ui/sparkle"),
			ImageRectOffset = if Icons.Rect("Ui/sparkle") then (Icons.Rect("Ui/sparkle") :: any).Offset else Vector2.zero,
			ImageRectSize = if Icons.Rect("Ui/sparkle") then (Icons.Rect("Ui/sparkle") :: any).Size else Vector2.zero,
			Rotation = function(): number
				return clock() * 40 % 360
			end,
			createRaw("UIScale")({
				Scale = function(): number
					return math.max(sparkle(), 0.01)
				end,
			}),
		}),
	}) :: Frame
end
