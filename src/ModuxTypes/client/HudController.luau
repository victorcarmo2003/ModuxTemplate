--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local HudBanner = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudBanner)
local HudRunEnd = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudRunEnd)
local HudSpectate = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSpectate)
local HudSummary = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.HudSummary)
local ToastStack = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast.Stack)
local Toast = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.Toast)

export type Report = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Arrived: number,
	Completed: number,
	Drawer: number,
	Tips: number,
	Stolen: number,
	Grade: string,
	Bonus: number,
	Deposited: number,
	Gems: number,
	AfkLocked: boolean,
	LastChanceUsed: boolean,
}
export type ShiftRecord = {
	Day: number,
	Night: number,
	IsNight: boolean,
	Attempt: number,
	Phase: string,
	PhaseStartedAt: number,
	PhaseDuration: number,
	WipeEndsAt: number,
	WipeFrozen: boolean,
	Chances: number,
}
export type RunReport = {
	Result: "Success" | "Failed",
	Day: number,
	Night: number,
	Gems: number,
}
export type LifeEvent = {
	UserId: number,
	Event: "Down" | "Revived" | "Spectating" | "Hit" | "Wipe" | "WipeCleared",
}

export type Public = {
	Banner: Vide.Source<HudBanner.Shown>,
	BannerKey: string,
	BannerThread: thread?,
	Card: Vide.Source<boolean>,
	CardThread: thread?,
	DevAll: Vide.Source<boolean>,
	DevGate: Vide.Source<boolean>,
	Epoch: Vide.Source<number>,
	Gui: ScreenGui?,
	Intros: Vide.Source<{ [string]: boolean }>,
	Open: Vide.Source<{ [string]: boolean }>,
	Report: Vide.Source<HudSummary.Shown>,
	ReportThread: thread?,
	RunEnd: Vide.Source<HudRunEnd.Shown>,
	RunEndThread: thread?,
	Scale: Vide.Source<number>,
	ShiftPhase: string,
	Toasts: Vide.Source<{ ToastStack.Entry }>,
	Unmount: (() -> ())?,
	Viewport: Vide.Source<Vector2>,
	Watching: Vide.Source<string>,
	WipeEndsAt: number,
	WipeFrozen: boolean,
	WipeLeft: Vide.Source<number>,
	WipePhase: boolean,
	Setup: (self: Public) -> (),
	NoticeText: (self: Public, kind: string, value: number) -> string?,
	PushToast: (self: Public, kind: string, value: number) -> (),
	PushText: (self: Public, text: string, toastKind: Toast.Kind) -> boolean,
	ToastDone: (self: Public, entry: ToastStack.Entry) -> (),
	CancelReport: (self: Public) -> (),
	HideReport: (self: Public) -> (),
	ShowReport: (self: Public, report: Report) -> (),
	ShiftText: (self: Public) -> string,
	OnLifeEvent: (self: Public, event: LifeEvent) -> (),
	ShowBanner: (self: Public, banner: HudBanner.Banner, duration: number?) -> (),
	RefreshWipe: (self: Public) -> (),
	ApplyShift: (self: Public, record: ShiftRecord) -> (),
	Covered: (self: Public) -> boolean,
	Fallen: (self: Public) -> boolean,
	DownLine: (self: Public) -> string,
	SpectateMode: (self: Public) -> HudSpectate.Mode,
	ShowCard: (self: Public) -> (),
	HideCard: (self: Public) -> (),
	RefreshWatching: (self: Public) -> (),
	SwitchHint: (self: Public) -> string,
	Species: (self: Public) -> string?,
	ShowRunEnd: (self: Public, report: RunReport) -> (),
	HideRunEnd: (self: Public) -> (),
	Layer: (self: Public, name: string, zIndex: number, children: { Instance }) -> Frame,
	SanityMeter: (self: Public) -> Frame,
	TopBar: (self: Public) -> number,
	TopLeftY: (self: Public) -> number,
	Compact: (self: Public) -> boolean,
	SanityOn: (self: Public) -> boolean,
	OrderPosition: (self: Public) -> UDim2,
	OrderCard: (self: Public) -> Frame,
	IsOpen: (self: Public, key: string) -> boolean,
	IsOpenNow: (self: Public, key: string) -> boolean,
	EvaluateReveal: (self: Public) -> (),
	DevReveal: (self: Public, text: string) -> (),
	Rescale: (self: Public, camera: Camera?) -> (),
	WatchViewport: (self: Public) -> (),
	Mount: (self: Public, playerGui: Instance) -> (),
}

return {}
