# Vide 0.4 patterns for game UI

Verified against `centau/vide@0.4.1` source. If the project pins another version, read its `src/lib.luau` first.

## API surface (0.4.1)

| Function | Signature | Use |
|---|---|---|
| `create` | `create(class)(props)` or `create "Frame" { ... }` | build instance; function values = reactive bindings, function on an event = connection, array entries = children |
| `source` | `source(initial) -> src` ; `src()` read, `src(v)` write | state |
| `derive` | `derive(fn) -> () -> T` | cached computed value (use when expensive or read by many) |
| `effect` | `effect(fn)` | side effect on change (sounds, tweens, analytics) |
| `cleanup` | `cleanup(fn or Instance or Connection)` | runs when the owning scope is destroyed |
| `untrack` | `untrack(fn)` | read without subscribing |
| `batch` | `batch(fn)` | many writes, one update |
| `show` | `show(cond, component, fallback?)` | conditional subtree (destroyed when false) |
| `switch` | `switch(keySource)({ [key] = component })` | one of N subtrees |
| `indexes` | `indexes(listSource, function(item: () -> V, i: number) ... end)` | list keyed by index (slots, ammo pips, segments) |
| `values` | `values(listSource, function(v: V, i: () -> number) ... end)` | list keyed by value (feed entries, players) |
| `spring` | `spring(source, period=1, dampingRatio=1) -> (value, settings)` | smoothed number/UDim2/Color3/Vector2… ; `settings({ impulse = x })` for kicks |
| `action` | `action(function(inst) end, priority?)` | run code on the created instance (store ref, start tween) |
| `changed` | `changed("Property", function(v) end)` | listen to an instance property inside props |
| `root` / `mount` | `root(function(destroy) ... end)`, `mount(component, parent) -> destroy` | top-level ownership |
| `Vide.strict` | flag | on in Studio (non -O2): catches nested-scope errors; keep it on in dev |

Not in 0.4.1 public table: `timeout`, `branch` (internal). Do not call them.

## Gotchas that break HUDs

1. **Defaults:** with `Vide.defaults = true` (default) Frame/ImageLabel/ImageButton/ScrollingFrame get
   `BackgroundColor3 = white`, `BorderSizePixel = 0` — background still **opaque**. Every decorative Frame,
   ImageLabel and TextLabel used as art needs `BackgroundTransparency = 1` explicitly. White boxes behind
   icons in the capture = this bug.
2. **Reactive scopes inside function children:** a child given as `function() return {...} end` runs inside an
   effect; creating `spring`/`source`/nested reactive components there errors in strict mode. Use
   `indexes`/`values`/`show`/`switch` for dynamic children.
3. **Spring damping:** `spring(src, 0.05, 2)` errors ("damping too high"). Keep `period >= 0.1` for dampingRatio 1–1.5.
   HUD feel: numbers `0.15–0.25`, bars `0.3`, panels sliding `0.35, 0.8` (slight overshoot).
4. **Typed create:** the typed `create` knows a subset of classes; projects cast `Vide.create :: any` for others
   (UIStroke on some versions, `Path2D`…). Follow the project's convention.
5. **Duplicate property at same depth** errors. Don't set `Size` twice via helper spreads.
6. **Glow/shadow/back plates are siblings with lower ZIndex**, never children (a child always draws above its
   parent under `ZIndexBehavior.Sibling`).
7. **TextSize caps at 100** and is the line box, not the CSS em — see roblox-ui-fundamentals.md "Text and fonts".
8. Events: `Activated = function() ... end` connects. `MouseEnter`/`MouseLeave` for hover; for console/gamepad
   use `SelectionGained`/`SelectionLost` too.

## Component template (match the project idiom: `const` vs `local`, call style, comments)

```luau
--!strict
-- AmmoCounter: round count (big) over reserve (small), divider between. Low ammo tints amber, empty red + flash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)

local create = Vide.create
local spring = Vide.spring

export type Props = {
	Rounds: () -> number,
	Reserve: () -> number,
	MagSize: () -> number,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function AmmoCounter(props: Props): Instance
	local ratio = function(): number
		return props.Rounds() / math.max(props.MagSize(), 1)
	end
	local tint = function(): Color3
		local r = ratio()
		return if props.Rounds() == 0 then Theme.Danger elseif r <= 0.25 then Theme.Warning else Theme.Primary
	end
	local color = spring(tint, 0.2)

	return create("Frame")({
		Name = "AmmoCounter",
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint or Vector2.new(1, 1),
		Position = props.Position or UDim2.new(1, -48, 1, -40),
		Size = UDim2.fromOffset(180, 170),

		create("TextLabel")({
			Name = "Rounds",
			BackgroundTransparency = 1,
			-- 120 px line: TextSize caps at 100 -> half size + UIScale 2 (scales around AnchorPoint)
			Size = UDim2.new(0.5, 0, 0, 60),
			FontFace = Theme.Font.Numeral,
			TextSize = 60,
			TextColor3 = color,
			Text = function()
				return tostring(props.Rounds())
			end,
			create("UIScale")({ Scale = 2 }),
		}),
		create("Frame")({
			Name = "Divider",
			BackgroundColor3 = Theme.Neutral,
			BackgroundTransparency = 0.25,
			Position = UDim2.fromOffset(0, 126),
			Size = UDim2.new(1, 0, 0, 2),
		}),
		create("TextLabel")({
			Name = "Reserve",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 132),
			Size = UDim2.new(1, 0, 0, 40),
			FontFace = Theme.Font.Numeral,
			TextSize = 40,
			TextColor3 = Theme.Neutral,
			Text = function()
				return tostring(props.Reserve())
			end,
		}),
	})
end

return AmmoCounter
```

## UI Labs story template

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Vide = require(ReplicatedStorage.Packages.Vide)
local AmmoCounter = require(script.Parent)

return UILabs.CreateVideStory({
	vide = Vide,
	controls = {
		Rounds = UILabs.Slider(25, 0, 30, 1),
		Reserve = UILabs.Slider(120, 0, 300, 1),
		-- One control per visual state in the reference: never leave a state only reachable in-game.
		ShowReference = false,
	},
}, function(props)
	local c = props.controls
	return {
		-- Optional: the reference under the UI at 50% to align by eye inside UI Labs.
		Vide.show(c.ShowReference, function()
			return Vide.create("ImageLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Image = "rbxassetid://REFERENCE_UPLOAD", -- upload the ref only for dev, never ship it
				ImageTransparency = 0.5,
				ZIndex = -10,
			})
		end),
		AmmoCounter({ Rounds = c.Rounds, Reserve = c.Reserve, MagSize = function() return 30 end }),
	}
end)
```

## Animation recipes

| Effect | Recipe |
|---|---|
| Number roll / bar fill follow | `spring(target, 0.2)` bound to `Size`/`Text` (round when displaying) |
| Hit flash / pop | `effect` watching the trigger → `TweenService:Create(inst, TweenInfo.new(0.08), {...}):Play()` then back; inst from `action` |
| Panel slide-in | `spring(function() return if open() then UDim2... else UDim2... end, 0.35, 0.8)` |
| Low-state pulse | `effect` + a `source` driven by `RunService.Heartbeat` sine; or tween `ImageTransparency` with `RepeatCount = -1, Reverses = true` (cancel in `cleanup`) |
| Ring sweep (cooldown) | two half-ring images each under a `UIGradient` with `Transparency` hard step, rotate gradient `Rotation` from progress |
| Glitch / flicker in | `TweenService` on transparency with `Enum.EasingStyle.Bounce` or 3 quick steps; respect ReduceMotion |
| Scanline drift | tiled scanline image, tween `Position` Y by one period, repeat |

Clip-reveal (level / progress on one silhouette) — Studio-verified on the AW battery and streak icon:

```luau
-- Battery level: full-height rounded fill inside a clip sized by the charge.
-- Top edge = the clip's flat cut, bottom keeps the shell rounding. Animates by Size only.
create("Frame")({
	Name = "BatteryLevel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 7.8, 1, -76.2),
	Size = function()
		return UDim2.fromOffset(22, FULL_HEIGHT * charge())
	end,
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	create("Frame")({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(22, FULL_HEIGHT),
		BackgroundColor3 = function()
			return if charge() < 0.25 then DANGER else PRIMARY
		end,
		create("UICorner")({ CornerRadius = UDim.new(0, 3) }),
	}),
}),

-- Progress on one icon: the same PNG twice. Back copy dim, front copy accent inside a clip that grows.
-- PAD/INK = transparent padding and ink width inside the PNG (from layout.json), so 0..1 maps to the ink.
create("ImageLabel")({ Image = ICON, ImageColor3 = DIM, ImageTransparency = 0.25, Size = ICON_SIZE, Position = POS }),
create("Frame")({
	Position = POS,
	Size = function()
		return UDim2.fromOffset(PAD + INK * progress(), ICON_SIZE.Y.Offset)
	end,
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 2,
	create("ImageLabel")({ Image = ICON, ImageColor3 = ACCENT, Size = ICON_SIZE, BackgroundTransparency = 1 }),
}),
```

Radial progress (no arc primitive) recipe:

```luau
-- progress: () -> number in 0..1. RING is a full white ring PNG. Two halves, each masked by a UIGradient.
local function half(side: number, progress: () -> number): Instance
	return create("Frame")({
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0.5, 1),
		Position = UDim2.fromScale(if side == 0 then 0 else 0.5, 0),
		create("ImageLabel")({
			BackgroundTransparency = 1,
			Image = RING,
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if side == 0 then 0 else -1, 0),
			create("UIGradient")({
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.501, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = function()
					-- right half covers 0..0.5, left half 0.5..1 (clockwise from the top)
					local p = math.clamp(progress() * 2 - side, 0, 1)
					return (if side == 0 then 90 else -90) + p * 180 -- tune sign/offset once in a story
				end,
			}),
		}),
	})
end
```
Verify the sweep direction in a story with a slider before using it; gradient rotation conventions are easy to flip.
