--!strict
-- Room signs of the lobby squad pads (user request 2026-10-12). One PadTag (Interface/Components/PadTag, a studs-sized
-- BillboardGui) over every squad platform: a count pill ("n/max" of the room, no fixed capacity per pad; FREE / SETUP /
-- FULL by state), the run seal ("D1") and the leader's name. It also reports somebody stepping on / off (OnCount). Each pad is read from LobbyZones (the tagged PartyPlatform /
-- LobbyZone floor Part of the map, any count, no position in code); the sign hangs from a local invisible anchor Part
-- over the pad centre (Workspace.LobbyPadTags, created by this client, never replicated). LobbyZones.Version() moving
-- (a pad edited / streamed in) re-places the signs. Presentation only: the owner reads the Party set the server
-- replicates and decides every text; the server decides the squads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local LobbyZones = require(ReplicatedStorage.shared.Lobby.LobbyZones)
local PadTag = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PadTag)

export type Props = {
	-- Where the BillboardGuis go (PlayerGui or the ScreenGui).
	Parent: Instance,
	-- Pads to sign (1..n).
	Count: number,
	-- Per pad (reactive reads of the Party set / the clock).
	Members: (n: number) -> number,
	Max: (n: number) -> number,
	State: (n: number) -> PadTag.State,
	Status: (n: number) -> string,
	-- Name of the leader of the squad on pad n ("" = none).
	Leader: (n: number) -> string,
	-- User ids on pad n, leader first (the head shots of the sign).
	Faces: (n: number) -> { number },
	-- Text of the run seal ("D1"; Content.Lobby.Squad.Pad.Badge).
	Badge: string,
	-- Somebody stepped on / off pad n (the number of players on it changed). Presentation hook: sound, ring shiver.
	OnCount: (n: number, from: number, to: number) -> (),
	-- The sign shows only while this is true (a screen that owns the view hides them).
	Visible: () -> boolean,
}

export type Pads = {
	Step: () -> (),
	Destroy: () -> (),
}

type Sign = {
	Anchor: Part,
	Billboard: BillboardGui,
	Unmount: () -> (),
}

const FOLDER = "LobbyPadTags"
const LIFT = 9.6 -- studs over the pad floor to the sign centre (the sign is 7.2 tall: its foot clears a standing player)
const DISTANCE = 140 -- studs the signs stay on

return function(props: Props): Pads
	const root = Instance.new("Folder")
	root.Name = FOLDER
	root.Parent = workspace

	const signs: { [number]: Sign } = {}
	local built = -1 -- LobbyZones.Version() the signs were placed for

	local function drop(n: number)
		const sign = signs[n]
		if sign then
			signs[n] = nil
			sign.Unmount()
			sign.Billboard:Destroy()
			sign.Anchor:Destroy()
		end
	end

	local function make(n: number, center: Vector3)
		const anchor = Instance.new("Part")
		anchor.Name = `PadTag{n}`
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Massless = true
		anchor.Locked = true
		anchor.CFrame = CFrame.new(center)
		anchor.Parent = root
		const unmount, billboard = Vide.root(function()
			local last = Vide.untrack(function(): number
				return props.Members(n)
			end)
			Vide.effect(function()
				const now = props.Members(n)
				Vide.untrack(function()
					if now ~= last then
						const from = last
						last = now
						props.OnCount(n, from, now)
					end
					return nil
				end)
			end)
			return PadTag({
				Name = `PadTag{n}`,
				Adornee = anchor,
				Visible = props.Visible,
				Badge = props.Badge,
				Leader = function()
					return props.Leader(n)
				end,
				Faces = function()
					return props.Faces(n)
				end,
				Count = function()
					return props.Members(n)
				end,
				Max = function()
					return props.Max(n)
				end,
				State = function()
					return props.State(n)
				end,
				Status = function()
					return props.Status(n)
				end,
				Offset = Vector3.new(0, LIFT, 0),
				MaxDistance = DISTANCE,
			})
		end)
		billboard.Parent = props.Parent
		signs[n] = { Anchor = anchor, Billboard = billboard, Unmount = unmount }
	end

	local function build()
		for n = 1, props.Count do
			const zone = LobbyZones.Platform(n)
			const sign = signs[n]
			if zone == nil then
				drop(n)
			elseif sign == nil then
				make(n, zone.Center)
			elseif sign.Anchor.Position ~= zone.Center then
				sign.Anchor.CFrame = CFrame.new(zone.Center)
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
			for n in signs do
				drop(n)
			end
			root:Destroy()
		end,
	}
end
