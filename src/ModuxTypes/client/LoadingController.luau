--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Public = {
	Gui: ScreenGui?,
	Progress: Vide.Source<number>,
	Ready: Vide.Source<boolean>,
	Sent: boolean,
	Status: { [string]: string },
	Steps: { [string]: number },
	Setup: (self: Public) -> (),
	FindGui: (self: Public) -> ScreenGui?,
	SetStatus: (self: Public, key: string) -> (),
	Mark: (self: Public, step: string, fraction: number) -> (),
	AssetList: (self: Public) -> { any },
	StepKit: (self: Public) -> (),
	StepAssets: (self: Public) -> (),
	StepVoices: (self: Public) -> (),
	BackgroundVoices: (self: Public) -> (),
	Run: (self: Public) -> (),
	SendReady: (self: Public) -> (),
	Lift: (self: Public) -> (),
}

return {}
