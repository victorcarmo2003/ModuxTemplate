--!strict
-- LoadingScreen: the cartoon loading curtain shown from the first frame of the join until the client is ready
-- (ReplicatedFirst Loading/Boot mounts it; LoadingController drives Progress and Status). Cartoon UI kit (AST-091,
-- Theme): warm Mustard backdrop with drifting studs, a bobbing hot dog drawn with CartoonPanels, the title, a tagline,
-- a real progress bar (Ink pill track, Mustard fill, percentage), the current step and a rotating tip card.
--   Shown = false lifts the whole curtain off the top of the screen (spring); the owner destroys it after.
-- Phone: the column is laid out at 560 x 400 and scaled to the screen (UIScale, never below MIN_SCALE, so the
-- smallest text stays >= Theme.MinTextSize on a 667 x 375 phone). Nothing here is touchable.
-- Pure: only props.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local CartoonPanel = require(script.Parent.CartoonPanel)
local CartoonLabel = require(script.Parent.CartoonLabel)

const create = Vide.create
const source = Vide.source
const spring = Vide.spring
const cleanup = Vide.cleanup
const effect = Vide.effect
const untrack = Vide.untrack
-- Vide 0.4.1 types `create` for 19 classes only; UIScale, UIGradient and UISizeConstraint are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

export type Props = {
	-- 0..1 real progress (eased here)
	Progress: () -> number,
	-- current step ("Warming the grill...")
	Status: () -> string,
	-- rotating tips (one at a time, TipTime s each)
	Tips: { string },
	Title: string?,
	Tagline: string?,
	-- false = the curtain lifts away
	Shown: () -> boolean,
	TipTime: number?,
	Name: string?,
}

const DESIGN = Vector2.new(560, 400) -- column size at UI scale 1
const FIT = Vector2.new(620, 440) -- screen size where the scale is 1
const MIN_SCALE = 0.8 -- 18 px status x 0.8 = 14.4 px on the smallest phone
const MAX_SCALE = 1.5
const TIP_TIME = 4.5
const BAR_HEIGHT = 38
const STUDS_SPEED = 14 -- px/s of the drifting studs
const BUN = Theme.ToneOf(Color3.fromHex("#E8A456"))
const SAUSAGE = Theme.Tone.Ketchup
const BACK_TOP = Color3.fromHex("#FFD24D")
const BACK_BOTTOM = Color3.fromHex("#F59A23")

-- Drawn hot dog: bun halves, sausage, mustard squiggle (CartoonPanels only)
local function hotDog(clock: () -> number): Frame
	return create("Frame")({
		Name = "HotDog",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = function()
			return UDim2.new(0.5, 0, 0, 6 - math.abs(math.sin(clock() * 3.2)) * 10)
		end,
		Size = UDim2.fromOffset(170, 84),
		BackgroundTransparency = 1,
		Rotation = function()
			return math.sin(clock() * 1.6) * 6
		end,

		CartoonPanel({
			Name = "BunBack",
			Tone = BUN,
			Radius = Theme.Radius.Pill,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(150, 40),
			ZIndex = 1,
		}),
		CartoonPanel({
			Name = "Sausage",
			Tone = SAUSAGE,
			Radius = Theme.Radius.Pill,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 24),
			Size = UDim2.fromOffset(168, 30),
			ZIndex = 2,
			Children = {
				create("Frame")({
					Name = "Mustard",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.45),
					Size = UDim2.new(0.78, 0, 0, 7),
					BackgroundColor3 = Theme.Color.Mustard,
					Rotation = function()
						return math.sin(clock() * 6) * 3
					end,
					create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
			},
		}),
		CartoonPanel({
			Name = "BunFront",
			Tone = BUN,
			Radius = Theme.Radius.Pill,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(156, 40),
			ZIndex = 3,
		}),
	})
end

return function(props: Props): Frame
	const title = props.Title or "SELL HOTDOGS"
	const tips = props.Tips
	const tipTime = props.TipTime or TIP_TIME

	-- animation clock
	const clock = source(0)
	const started = os.clock()
	const tick = RunService.Heartbeat:Connect(function()
		clock(os.clock() - started)
	end)
	cleanup(function()
		tick:Disconnect()
	end)

	-- rotating tip (bumps when it changes)
	const tipIndex = source(if #tips > 0 then math.random(1, #tips) else 0)
	const tipThread = task.spawn(function()
		while #tips > 1 do
			task.wait(tipTime)
			const now = untrack(tipIndex)
			tipIndex(now % #tips + 1)
		end
	end)
	cleanup(function()
		if coroutine.status(tipThread) == "suspended" then
			task.cancel(tipThread)
		end
	end)
	const tipBump = Motion.Bump(function(): number
		return tipIndex()
	end, 1.06, 0.18)

	-- eased progress (never goes back)
	const shownProgress = source(0)
	effect(function()
		const value = math.clamp(props.Progress(), 0, 1)
		if value > untrack(shownProgress) then
			shownProgress(value)
		end
	end)
	const eased = spring(shownProgress, 0.35, 0.9)
	const fill = function(): number
		return math.clamp(eased(), 0, 1)
	end

	-- curtain: 0 = down (shown), 1 = lifted
	const lift = spring(function(): number
		return if props.Shown() then 0 else 1
	end, 0.45, 0.8)

	-- screen fit
	const screen = source(FIT)
	const scale = function(): number
		const size = screen()
		-- fits the screen, and never bigger than the global UI scale (Theme.ScaleOf)
		return math.clamp(math.min(size.X / FIT.X, size.Y / FIT.Y, Theme.ScaleOf(size)), MIN_SCALE, MAX_SCALE)
	end

	const studs = Icons.Ids.Studs

	const root = create("Frame")({
		Name = props.Name or "LoadingScreen",
		Size = UDim2.fromScale(1, 1),
		Position = function()
			return UDim2.fromScale(0, -1.15 * lift())
		end,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 1,
		Visible = function()
			return lift() < 0.999
		end,

		createRaw("UIGradient")({
			Color = ColorSequence.new(BACK_TOP, BACK_BOTTOM),
			Rotation = 90,
		}),

		create("ImageLabel")({
			Name = "Studs",
			Size = UDim2.new(1, Theme.StudsTile * 4, 1, Theme.StudsTile * 4),
			Position = function()
				const shift = (clock() * STUDS_SPEED) % (Theme.StudsTile * 2)
				return UDim2.fromOffset(-shift, -shift)
			end,
			BackgroundTransparency = 1,
			Image = studs,
			ImageTransparency = 0.82,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(Theme.StudsTile * 2, Theme.StudsTile * 2),
			Visible = studs ~= "",
		}),

		-- bottom ribbon (Ketchup band with an Ink edge)
		create("Frame")({
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundColor3 = Theme.Tone.Ketchup.Bottom,
			BorderSizePixel = 0,
			create("Frame")({
				Name = "Edge",
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundColor3 = Theme.Color.Ink,
				BorderSizePixel = 0,
			}),
		}),

		create("Frame")({
			Name = "Column",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
			BackgroundTransparency = 1,
			ZIndex = 2,

			createRaw("UIScale")({ Scale = scale }),

			hotDog(clock),

			CartoonLabel({
				Name = "Title",
				Text = title,
				TextSize = 52,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 92),
				Box = UDim2.fromOffset(DESIGN.X, 60),
				Rotation = function()
					return math.sin(clock() * 1.1) * 1.5
				end,
			}),

			CartoonLabel({
				Name = "Tagline",
				Text = props.Tagline or "",
				TextSize = 20,
				Color = Theme.Color.Ink,
				Stroke = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 152),
				Box = UDim2.fromOffset(DESIGN.X, 26),
				Visible = (props.Tagline or "") ~= "",
			}),

			-- progress bar: Ink pill track, Mustard fill, percentage
			CartoonPanel({
				Name = "Bar",
				Tone = Theme.Tone.Ink,
				Radius = Theme.Radius.Pill,
				Outline = Theme.Outline.Thick,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 194),
				Size = UDim2.fromOffset(440, BAR_HEIGHT),
				Padding = 4,
				Children = {
					CartoonPanel({
						Name = "Fill",
						Tone = Theme.Tone.Mustard,
						Radius = Theme.Radius.Pill,
						Outline = 0,
						Lip = 2,
						Size = function()
							return UDim2.fromScale(fill(), 1)
						end,
						Visible = function()
							return fill() > 0.01
						end,
						Decor = {
							createRaw("UISizeConstraint")({ MinSize = Vector2.new(BAR_HEIGHT - 8, 0) }),
						},
					}),
					CartoonLabel({
						Name = "Percent",
						Text = function()
							return `{math.floor(fill() * 100 + 0.5)}%`
						end,
						TextSize = 18,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Box = UDim2.fromScale(1, 1),
						ZIndex = 5,
					}),
				},
			}),

			CartoonLabel({
				Name = "Status",
				Text = props.Status,
				TextSize = 18,
				Color = Theme.Color.Ink,
				Stroke = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 240),
				Box = UDim2.fromOffset(DESIGN.X, 24),
			}),

			-- tip card
			create("Frame")({
				Name = "TipHolder",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 282),
				Size = UDim2.fromOffset(500, 104),
				BackgroundTransparency = 1,
				Visible = #tips > 0,
				createRaw("UIScale")({ Scale = tipBump }),
				CartoonPanel({
					Name = "Tip",
					Tone = Theme.Tone.Cream,
					Radius = Theme.Radius.Card,
					Outline = Theme.Outline.Thick,
					Size = UDim2.fromScale(1, 1),
					Rotation = -1.5,
					Padding = { Top = 26, Bottom = 10, Left = 18, Right = 18 },
					Children = {
						CartoonLabel({
							Name = "Text",
							Text = function()
								return tips[tipIndex()] or ""
							end,
							TextSize = 18,
							Color = Theme.Color.Dark,
							Stroke = 0,
							Wrapped = true,
							Box = UDim2.fromScale(1, 1),
						}),
					},
				}),
				CartoonPanel({
					Name = "Chip",
					Tone = Theme.Tone.Ketchup,
					Radius = Theme.Radius.Pill,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(16, 2),
					Size = UDim2.fromOffset(72, 30),
					Rotation = -4,
					ZIndex = 4,
					Children = {
						CartoonLabel({
							Name = "Label",
							Text = "TIP",
							TextSize = 16,
							Box = UDim2.fromScale(1, 1),
						}),
					},
				}),
			}),
		}),
	}) :: Frame

	const measure = function()
		screen(root.AbsoluteSize)
	end
	const sizeChanged = root:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
	cleanup(function()
		sizeChanged:Disconnect()
	end)
	task.defer(measure)

	return root
end
