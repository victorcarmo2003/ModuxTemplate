--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Content = require(ReplicatedStorage.shared.Content)
local Rain = require(StarterPlayer.StarterPlayerScripts.client.Atmosphere.AtmosphereController.Rain)
local Lightning = require(StarterPlayer.StarterPlayerScripts.client.Atmosphere.AtmosphereController.Lightning)

type AtmosphereRow = Content.Atmosphere
type Preset = Content.LightPreset
type Effects = { Atmosphere: Atmosphere?, ColorCorrection: ColorCorrectionEffect?, Bloom: BloomEffect? }

export type Public = {
	Alpha: number,
	Current: AtmosphereRow?,
	Enabled: boolean,
	Fields: { string },
	HasOverride: boolean,
	LastAlpha: number,
	LastBase: Preset?,
	LastFlash: number,
	Lightning: Lightning.Lightning,
	MoonOriginal: number?,
	NextPosts: number,
	Override: string?,
	PostOriginals: { [Light]: number },
	Rain: Rain.Rain?,
	Sky: Sky?,
	Sound: Sound?,
	SoundBase: number,
	Target: string?,
	Setup: (self: Public) -> (),
	Apply: (self: Public, key: string?) -> (),
	Get: (self: Public) -> string?,
	Level: (self: Public) -> number,
	OnStrike: (self: Public, callback: (number) -> ()) -> () -> (),
	Retarget: (self: Public) -> (),
	Effects: (self: Public) -> Effects,
	Begin: (self: Public, row: AtmosphereRow) -> (),
	Finish: (self: Public) -> (),
	Write: (self: Public, row: AtmosphereRow, base: Preset, alpha: number, flash: number) -> (),
	ScalePosts: (self: Public, scale: number, restore: boolean) -> (),
	Step: (self: Public, dt: number) -> (),
}

return {}
