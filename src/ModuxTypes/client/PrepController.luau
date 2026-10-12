--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local PlateView = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PlateView)
local PrepShell = require(StarterPlayer.StarterPlayerScripts.client.Interface.Components.PrepShell)
local Cursor = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Cursor)
local Gestures = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Gestures)
local Mock = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Mock)
local Pointer = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Pointer)
local Poses = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Poses)
local Rig = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Rig)
local Stage = require(StarterPlayer.StarterPlayerScripts.client.Prep.PrepController.Stage)

export type Toast = { Text: string, Kind: "Info" | "Good" | "Alert", Id: number }
export type View = {
	Bun: Vide.Source<PlateView.BunState>,
	Cut: Vide.Source<number>,
	Guide: Vide.Source<boolean>,
	Sausage: Vide.Source<PlateView.Sausage | false>,
	Toppings: Vide.Source<{ PlateView.Topping }>,
	Seal: Vide.Source<PlateView.Grade | false>,
	Message: Vide.Source<string>,
	Pips: Vide.Source<{ Pip }>,
	-- ingredient boxes: the keys already on the plate, the box in focus, a refused pick, the plate is full
	Used: Vide.Source<{ [string]: boolean }>,
	Focus: Vide.Source<string>,
	Refused: Vide.Source<{ Key: string, Id: number } | false>,
	Full: () -> boolean,
	Info: (key: string) -> { Stock: number, Locked: boolean, Used: boolean },
	-- sauce stroke layer (StrokeCanvas): points 0..1, the target path, the colour, the meter
	Stroke: Vide.Source<{ Vector2 }>,
	StrokeGuide: Vide.Source<{ Vector2 }>,
	StrokeColor: Vide.Source<Color3>,
	Meter: Vide.Source<{ Fill: number, Target: number, Window: number } | false>,
	-- the ticket in front and the line behind it
	Ticket: Vide.Source<Mock.Ticket | false>,
	Queue: Vide.Source<number>,
}
export type Pip = PrepShell.Pip

export type Public = {
	Active: Vide.Source<boolean>,
	Assist: Vide.Source<boolean>,
	Badges: Vide.Source<{ [string]: number }>,
	BoundNames: { string },
	Cursor: Cursor.Cursor?,
	CursorGui: ScreenGui?,
	Forced: boolean,
	Gestures: Gestures.Recogniser?,
	Gui: ScreenGui?,
	InMode: boolean,
	LeaveReason: string,
	LeaveTravel: number,
	Leaving: boolean,
	LeavingSince: number,
	Mock: boolean,
	Needs: Vide.Source<{ [string]: boolean }>,
	NextBeat: number,
	Pointer: Pointer.Pointer?,
	PointerStops: { () -> () },
	Pose: Poses.Pose?,
	PreviousContext: string,
	Rig: Rig.Rig,
	RigReleased: boolean,
	Saved: { [string]: any },
	Shown: Vide.Source<boolean>,
	Stages: { [string]: Stage.Stage },
	Station: Vide.Source<number>,
	Step: Vide.Source<string>,
	Tab: Vide.Source<string>,
	ToastId: number,
	Toasts: Vide.Source<Toast | false>,
	Unmount: (() -> ())?,
	UnmountCursor: (() -> ())?,
	View: View,
	Vignette: Vide.Source<boolean>,
	Setup: (self: Public) -> (),
	MakeView: (self: Public) -> View,
	InfoOf: (self: Public, key: string) -> { Stock: number, Locked: boolean, Used: boolean },
	LoadStages: (self: Public) -> (),
	StageOf: (self: Public, tab: string?) -> Stage.Stage?,
	SetTab: (self: Public, tab: string) -> (),
	SetStage: (self: Public, stepKey: string) -> (),
	Need: (self: Public, name: string, value: boolean) -> (),
	SetPip: (self: Public, index: number, grade: PlateView.Grade?) -> (),
	ResetPlate: (self: Public) -> (),
	Toast: (self: Public, text: string, kind: ("Info" | "Good" | "Alert")?) -> (),
	SetAssist: (self: Public, on: boolean) -> (),
	OnGesture: (self: Public, event: any) -> (),
	OnPick: (self: Public, key: string) -> (),
	CancelGestures: (self: Public) -> (),
	PressNext: (self: Public) -> (),
	Trash: (self: Public) -> (),
	CycleTicket: (self: Public) -> (),
	Broadcast: (self: Public, event: any) -> (),
	SendTab: (self: Public) -> (),
	OnResult: (self: Public, result: any) -> (),
	Notice: (self: Public, reason: string) -> (),
	Isolate: (self: Public, on: boolean) -> (),
	Bind: (self: Public, on: boolean) -> (),
	Mount: (self: Public) -> (),
	Unmounted: (self: Public) -> (),
	Enter: (self: Public, station: number, mock: boolean?, tab: string?) -> boolean,
	MoveTo: (self: Public, station: number) -> (),
	Leave: (self: Public, reason: string, forced: boolean?, fromServer: boolean?) -> (),
	Finish: (self: Public, takeover: boolean) -> (),
	LoadPreview: (self: Public) -> (),
	Update: (self: Public, dt: number) -> (),
}

return {}
