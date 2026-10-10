--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local HudSummary = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSummary)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)

export type Report = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Arrived: number,
	Completed: number,
	Drawer: number,
	Stolen: number,
	Grade: string,
	Bonus: number,
	Deposited: number,
	Gems: number,
	AfkLocked: boolean,
	LastChanceUsed: boolean,
}

export type Public = {
	Gui: ScreenGui?,
	Report: Vide.Source<HudSummary.Shown>,
	ReportThread: thread?,
	Scale: Vide.Source<number>,
	Toasts: Vide.Source<{ ToastStack.Entry }>,
	Unmount: (() -> ())?,
	Setup: (self: Public) -> (),
	NoticeText: (self: Public, kind: string, value: number) -> string?,
	PushToast: (self: Public, kind: string, value: number) -> (),
	ToastDone: (self: Public, entry: ToastStack.Entry) -> (),
	CancelReport: (self: Public) -> (),
	HideReport: (self: Public) -> (),
	ShowReport: (self: Public, report: Report) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
