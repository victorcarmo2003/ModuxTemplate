--!strict
-- SecurityFeed: the screen overlay of the security camera view (FEAT-040, TASK-285; owner request 2026-10-14). It sits over the
-- 3D view of the camera (the colour grade is a ColorCorrectionEffect of the SecurityController, not this component):
--   grain        two tiled noise layers (Content.Security.Textures.Noise) jumping to a new random offset every frame
--   scanlines    a tiled 8 px line texture scrolling down slowly
--   band         a soft bright band rolling down the picture (the "leve distorção" of the tape, night only)
--   vignette     dark corners
--   static       a burst of grain + grey cover on a camera or view switch (`Static` 0..1)
--   viewfinder   corners, thin rule-of-thirds guides and a centre cross (owner 2026-10-15, TASK-323), below the Roblox top bar
--   stamps       inside the viewfinder, by its top corners: REC (Mustard dot blinking, never red), camera label, view name;
--                clock, night and elapsed time; monospace
--   controls     one button per camera, the Night / Normal toggle and Exit, each with its key (desktop / gamepad); touch taps
-- Only `Time` animates it (seconds, written every frame by the owner while the view is up). Pure: only props.
-- Wrap it in a ScreenGui with IgnoreGuiInset = true so the grain covers the top bar too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Content = require(ReplicatedStorage.shared.Content)
local Theme = require(script.Parent.Theme)
local CartoonButton = require(script.Parent.CartoonButton)

const create = Vide.create
const indexes = Vide.indexes
-- Vide 0.4.1 types `create` for 19 classes only; UIScale / UIGradient / UIListLayout are not among them.
const createRaw = (Vide.create :: any) :: (className: string) -> ({ [any]: any }) -> Instance

const textures = Content.Security.Textures
const rules = Content.Security.Rules

const MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
const NOISE_TILE = 256
const SCAN_TILE = 6
const SCAN_SPEED = 12 -- px/s the scanlines crawl down
const BAND_PERIOD = 5.5 -- s for the band to roll over the picture
const MARGIN = 18 -- px from the screen edges (UI scale 1)
-- viewfinder (owner 2026-10-15, TASK-323): corners, rule-of-thirds guides and a centre cross; the stamps sit inside it
const TOP_GAP = 10 -- px between the Roblox top bar and the viewfinder
const TOP_MIN = 58 -- px the top bar takes when GuiService reports none (Studio, story)
const BOTTOM = 44 + 18 + 14 -- px under the viewfinder: the controls row, its margin and a gap
const INNER = 14 -- px from a corner to the stamps beside it
const ARM = 34 -- px of one arm of a corner
const LINE = 2 -- px of the corner arms and the centre cross
const GUIDE = 1 -- px of the thirds guides
const CROSS = 22 -- px of the centre cross arms
const GUIDE_ALPHA = 0.78 -- transparency of the thirds guides
const CROSS_ALPHA = 0.45 -- transparency of the centre cross
-- stamp text: warm white in Normal, phosphor green in Night
const STAMP_NORMAL = Color3.fromRGB(245, 241, 226)
const STAMP_NIGHT = Color3.fromRGB(196, 255, 200)

export type Value<T> = T | () -> T

export type CamRow = { Key: string, Label: string }

export type Props = {
	Cams: { CamRow },
	Cam: () -> string, -- Key of the camera shown
	View: () -> Content.SecurityView,
	Look: () -> Content.SecurityLook,
	Time: () -> number, -- seconds, drives every animation
	Since: () -> number, -- Time when the view opened (elapsed stamp)
	Static: () -> number, -- 0..1 switch burst
	Clock: () -> string, -- game clock ("11:42 PM")
	Night: () -> string, -- "NIGHT 3" / "DAY 2"
	Device: () -> string, -- "KeyboardMouse" | "Gamepad" | "Touch"
	Scale: () -> number,
	Inset: () -> number, -- real px of the Roblox top bar (GuiService.TopbarInset.Height), 0 = unknown
	OnCam: (key: string) -> (),
	OnView: () -> (),
	OnExit: () -> (),
}

-- Cheap hash of a frame number to 0..1 (the grain offset): same frame, same offset.
local function hash(n: number, salt: number): number
	const x = math.sin(n * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function tint(props: Props): Color3
	return if props.View() == "Night" then STAMP_NIGHT else STAMP_NORMAL
end

-- One corner of the viewfinder: two straight arms (axis-aligned Frames, no rotation) meeting at `at` (0/1, 0/1).
local function corner(props: Props, at: Vector2): Frame
	local function arm(size: UDim2): Frame
		return create("Frame")({
			AnchorPoint = at,
			Position = UDim2.fromScale(at.X, at.Y),
			Size = size,
			BackgroundColor3 = function()
				return tint(props)
			end,
			BorderSizePixel = 0,
			ZIndex = 14,
		})
	end
	return create("Frame")({
		Name = `Corner{at.X}{at.Y}`,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 14,
		arm(UDim2.fromOffset(ARM, LINE)),
		arm(UDim2.fromOffset(LINE, ARM)),
	})
end

-- A thin thirds guide line of the viewfinder (vertical when its width is an offset, horizontal otherwise).
local function guide(props: Props, position: UDim2, size: UDim2): Frame
	return create("Frame")({
		Name = "Guide",
		AnchorPoint = if size.X.Scale == 0 then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = function()
			return tint(props)
		end,
		BackgroundTransparency = GUIDE_ALPHA,
		BorderSizePixel = 0,
		ZIndex = 13,
	})
end

-- One arm of the centre cross.
local function cross(props: Props, size: UDim2): Frame
	return create("Frame")({
		Name = "Cross",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = function()
			return tint(props)
		end,
		BackgroundTransparency = CROSS_ALPHA,
		BorderSizePixel = 0,
		ZIndex = 13,
	})
end

local function stamp(props: Props, text: () -> string, size: number, anchor: Vector2, position: UDim2, order: number?): TextLabel
	return create("TextLabel")({
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(0, size),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = MONO,
		TextSize = size,
		Text = text,
		TextColor3 = function()
			return tint(props)
		end,
		TextStrokeColor3 = Theme.Color.Ink,
		TextStrokeTransparency = 0.45,
		TextXAlignment = if anchor.X > 0.5 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		LayoutOrder = order or 0,
		ZIndex = 20,
	})
end

local function keyOf(props: Props, desktop: string, pad: string): string
	const device = props.Device()
	if device == "Gamepad" then
		return `{pad}  `
	elseif device == "Touch" then
		return ""
	end
	return `{desktop}  `
end

return function(props: Props): Frame
	const frame = function(): number
		return math.floor(props.Time() * 30)
	end
	const scaleOf = function(): number
		return math.max(props.Scale(), 0.1)
	end
	-- px (in the scaled Chrome) from the screen top to the viewfinder: the Roblox top bar (real px) unscaled, plus a gap
	const top = function(): number
		const inset = props.Inset()
		return (if inset > 0 then inset else TOP_MIN) / scaleOf() + TOP_GAP
	end
	const grain = function(): number
		return math.clamp(props.Look().Noise + props.Static() * 0.8, 0, 0.95)
	end

	local function noise(salt: number): ImageLabel
		return create("ImageLabel")({
			Name = `Grain{salt}`,
			Size = UDim2.new(1, NOISE_TILE, 1, NOISE_TILE),
			Position = function()
				const n = frame()
				return UDim2.fromOffset(-math.floor(hash(n, salt) * NOISE_TILE), -math.floor(hash(n, salt + 7) * NOISE_TILE))
			end,
			BackgroundTransparency = 1,
			Image = textures.Noise,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(NOISE_TILE, NOISE_TILE),
			ImageTransparency = function()
				return 1 - grain() * (if salt == 1 then 1 else 0.6)
			end,
			ZIndex = 4,
		})
	end

	const buttons: () -> { { Key: string, Text: string, Active: boolean, Action: () -> () } } = function()
		const list = {}
		for index, cam in props.Cams do
			table.insert(list, {
				Key = cam.Key,
				Text = keyOf(props, tostring(index), if index == 1 then "LB" else "RB") .. cam.Label,
				Active = props.Cam() == cam.Key,
				Action = function()
					props.OnCam(cam.Key)
				end,
			})
		end
		table.insert(list, {
			Key = "View",
			Text = keyOf(props, "N", "Y") .. (if props.View() == "Night" then "Normal" else "Night Vision"),
			Active = false,
			Action = props.OnView,
		})
		table.insert(list, {
			Key = "Exit",
			Text = keyOf(props, "Q", "B") .. "Exit",
			Active = false,
			Action = props.OnExit,
		})
		return list
	end

	return create("Frame")({
		Name = "SecurityFeed",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Active = false,

		-- vignette (dark corners)
		create("ImageLabel")({
			Name = "Vignette",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = textures.Vignette,
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = function()
				return 1 - props.Look().Vignette
			end,
			ZIndex = 2,
		}),

		-- scanlines, crawling down
		create("ImageLabel")({
			Name = "Scanlines",
			Size = UDim2.new(1, 0, 1, SCAN_TILE),
			Position = function()
				return UDim2.fromOffset(0, -SCAN_TILE + (props.Time() * SCAN_SPEED) % SCAN_TILE)
			end,
			BackgroundTransparency = 1,
			Image = textures.Scanlines,
			ImageColor3 = Color3.new(0, 0, 0),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(SCAN_TILE, SCAN_TILE),
			ImageTransparency = function()
				return 1 - props.Look().Scanlines
			end,
			ZIndex = 3,
		}),

		noise(1),
		noise(2),

		-- rolling bright band
		create("Frame")({
			Name = "Band",
			Size = UDim2.fromScale(1, 0.14),
			Position = function()
				return UDim2.fromScale(0, (props.Time() / BAND_PERIOD) % 1 * 1.3 - 0.15)
			end,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			BackgroundTransparency = function()
				return 1 - props.Look().Band
			end,
			Visible = function()
				return props.Look().Band > 0
			end,
			ZIndex = 5,
			createRaw("UIGradient")({
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		}),

		-- static burst cover (switch)
		create("Frame")({
			Name = "Static",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(60, 66, 62),
			BorderSizePixel = 0,
			BackgroundTransparency = function()
				return 1 - props.Static() * 0.7
			end,
			ZIndex = 6,
		}),

		-- viewfinder, stamps and controls, scaled with the rest of the UI
		create("Frame")({
			Name = "Chrome",
			-- the UIScale shrinks / grows from the top left: the frame is sized 1 / scale so it still covers the screen
			Size = function()
				return UDim2.fromScale(1 / scaleOf(), 1 / scaleOf())
			end,
			BackgroundTransparency = 1,
			ZIndex = 10,
			createRaw("UIScale")({
				Scale = props.Scale,
			}),

			-- the viewfinder: below the Roblox top bar, above the controls, a margin from the sides (responsive: every edge
			-- is an offset from the screen, the guides are fractions of the box)
			create("Frame")({
				Name = "Viewfinder",
				Position = function()
					return UDim2.fromOffset(MARGIN, top())
				end,
				Size = function()
					return UDim2.new(1, -MARGIN * 2, 1, -(top() + BOTTOM))
				end,
				BackgroundTransparency = 1,
				ZIndex = 12,

				-- corners
				corner(props, Vector2.new(0, 0)),
				corner(props, Vector2.new(1, 0)),
				corner(props, Vector2.new(0, 1)),
				corner(props, Vector2.new(1, 1)),
				-- rule-of-thirds grid
				guide(props, UDim2.fromScale(1 / 3, 0), UDim2.new(0, GUIDE, 1, 0)),
				guide(props, UDim2.fromScale(2 / 3, 0), UDim2.new(0, GUIDE, 1, 0)),
				guide(props, UDim2.fromScale(0, 1 / 3), UDim2.new(1, 0, 0, GUIDE)),
				guide(props, UDim2.fromScale(0, 2 / 3), UDim2.new(1, 0, 0, GUIDE)),
				-- centre cross
				cross(props, UDim2.fromOffset(CROSS, LINE)),
				cross(props, UDim2.fromOffset(LINE, CROSS)),

				-- top left, inside the corner: REC, camera, view
				create("Frame")({
					Name = "Rec",
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.fromOffset(INNER + 2, INNER + 5),
					BackgroundColor3 = Theme.Color.Mustard,
					BorderSizePixel = 0,
					BackgroundTransparency = function()
						return if (props.Time() % rules.Rec) < rules.Rec / 2 then 0 else 1
					end,
					ZIndex = 20,
					createRaw("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				}),
				stamp(props, function()
					return "REC"
				end, 18, Vector2.zero, UDim2.fromOffset(INNER + 18, INNER)),
				stamp(props, function()
					for _, cam in props.Cams do
						if cam.Key == props.Cam() then
							return cam.Label
						end
					end
					return props.Cam()
				end, 28, Vector2.zero, UDim2.fromOffset(INNER, INNER + 22)),
				stamp(props, function()
					return if props.View() == "Night" then "NIGHT VISION" else "NORMAL"
				end, 14, Vector2.zero, UDim2.fromOffset(INNER, INNER + 54)),

				-- top right, inside the corner: clock, night, elapsed
				stamp(props, props.Clock, 22, Vector2.new(1, 0), UDim2.new(1, -INNER, 0, INNER)),
				stamp(props, props.Night, 14, Vector2.new(1, 0), UDim2.new(1, -INNER, 0, INNER + 28)),
				stamp(props, function()
					const elapsed = math.max(props.Time() - props.Since(), 0)
					return string.format(
						"%02d:%02d:%02d",
						math.floor(elapsed / 3600),
						math.floor(elapsed / 60) % 60,
						math.floor(elapsed) % 60
					)
				end, 14, Vector2.new(1, 0), UDim2.new(1, -INNER, 0, INNER + 46)),
			}),

			-- bottom: controls, under the viewfinder
			create("Frame")({
				Name = "Controls",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -MARGIN),
				Size = UDim2.fromOffset(0, 44),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ZIndex = 20,
				createRaw("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				indexes(buttons, function(row, index)
					return CartoonButton({
						Name = `Button{index}`,
						Text = function()
							return row().Text
						end,
						TextSize = 16,
						Tone = function()
							return if row().Active then Theme.Tone.Mustard else Theme.Tone.Cream
						end,
						LayoutOrder = index,
						OnActivated = function()
							row().Action()
						end,
					})
				end),
			}),
		}),
	})
end
