--!strict
-- Zone signs of the lobby (owner request 2026-10-20: "I don't know what each pad means"). One ZoneSign
-- (Interface/Components/ZoneSign, a studs-sized BillboardGui) floating over every non-squad zone: an icon disc and the
-- zone name (Classes, Gems, Codes). The squad pads already have their PadTag (Pads.luau). Each zone is read from
-- LobbyZones (the tagged LobbyZone floor Part of the map, no position in code); the sign hangs from a local invisible
-- anchor Part over the zone centre (Workspace.LobbyZoneSigns, created by this client, never replicated).
-- LobbyZones.Version() moving (a zone edited / streamed in) re-places the signs. A sign hides while its own panel is
-- open (the player is inside the zone, the window says it already) and while the caller says so.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local Theme = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Theme)
local ZoneSign = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.ZoneSign)

export type Props = {
	-- Where the BillboardGuis go (PlayerGui or the ScreenGui).
	Parent: Instance,
	-- Panel open now (reactive): the sign of that zone hides.
	Panel: () -> string,
	-- The signs show only while this is true (a screen that owns the view hides them).
	Visible: () -> boolean,
}

export type Signs = {
	Step: () -> (),
	Destroy: () -> (),
}

type Def = { Text: string, Icon: string, Tone: Theme.Tone, Fallback: string, Lift: number }

type Sign = {
	Anchor: Part,
	Billboard: BillboardGui,
	Unmount: () -> (),
}

-- Same icons and tones as the LobbyHud tiles, so the floor, the sign and the button read as one thing.
-- Lift: studs over the zone floor to the sign centre (the sign is 9.8 tall: it floats over the storefront neon of the map).
const DEFS: { [string]: Def } = {
	Classes = { Text = "CLASSES", Icon = "Ui/paw", Tone = Theme.Tone.Mustard, Fallback = "C", Lift = 18.5 },
	Shop = { Text = "GEMS", Icon = "Hud/gem", Tone = Theme.Tone.Teal, Fallback = "$", Lift = 18.5 },
	Codes = { Text = "CODES", Icon = "Ui/sparkle", Tone = Theme.Tone.Violet, Fallback = "#", Lift = 18.5 },
}

const FOLDER = "LobbyZoneSigns"
const DISTANCE = 160 -- studs the signs stay on

return function(props: Props): Signs
	const root = Instance.new("Folder")
	root.Name = FOLDER
	root.Parent = workspace

	const signs: { [string]: Sign } = {}
	local built = -1 -- LobbyZones.Version() the signs were placed for

	local function drop(key: string)
		const sign = signs[key]
		if sign then
			signs[key] = nil
			sign.Unmount()
			sign.Billboard:Destroy()
			sign.Anchor:Destroy()
		end
	end

	local function make(zone: LobbyZones.Zone, def: Def)
		const anchor = Instance.new("Part")
		anchor.Name = `ZoneSign{zone.Key}`
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Massless = true
		anchor.Locked = true
		anchor.CFrame = CFrame.new(zone.Center)
		anchor.Parent = root
		const panel = zone.Panel
		const unmount, billboard = Vide.root(function()
			return ZoneSign({
				Name = `ZoneSign{zone.Key}`,
				Adornee = anchor,
				Visible = function()
					return props.Visible() and props.Panel() ~= panel
				end,
				Text = def.Text,
				Icon = def.Icon,
				Fallback = def.Fallback,
				Tone = def.Tone,
				Offset = Vector3.new(0, def.Lift, 0),
				MaxDistance = DISTANCE,
			})
		end)
		billboard.Parent = props.Parent
		signs[zone.Key] = { Anchor = anchor, Billboard = billboard, Unmount = unmount }
	end

	local function build()
		const seen: { [string]: boolean } = {}
		for _, zone in LobbyZones.List() do
			const def = DEFS[zone.Key]
			if def == nil or zone.Platform > 0 then
				continue
			end
			seen[zone.Key] = true
			const sign = signs[zone.Key]
			if sign == nil then
				make(zone, def)
			elseif sign.Anchor.Position ~= zone.Center then
				sign.Anchor.CFrame = CFrame.new(zone.Center)
			end
		end
		for key in signs do
			if not seen[key] then
				drop(key)
			end
		end
		built = LobbyZones.Version()
	end

	build()

	return {
		-- Called from the lobby Heartbeat (cheap: one integer compare).
		Step = function()
			if LobbyZones.Version() ~= built then
				build()
			end
		end,
		Destroy = function()
			for key in signs do
				drop(key)
			end
			root:Destroy()
		end,
	}
end
