--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

type Session = {
	EnteredAt: number,
	Gui: ScreenGui,
	Unmount: () -> (),
	Exit: () -> (),
	Heartbeat: RBXScriptConnection,
	Inputs: { RBXScriptConnection },
	Present: { [number]: boolean }, -- at the counter / window now (known before or seen arriving)
	Arrived: { [number]: number }, -- NpcId -> os.clock() it got there while reading
	Drag: Drag?,
	Held: number, -- -1 / 0 / 1 (x3 for the page keys): a scroll key held
	NextScan: number,
	Back: GuiButton?,
}
type Drag = { Input: InputObject, Last: Vector2 }

export type Public = {
	Clock: Vide.Source<number>,
	Density: Vide.Source<number>,
	Height: Vide.Source<number>,
	LastRead: number,
	LastScare: number?,
	List: ScrollingFrame?,
	PaperPart: Vide.Source<BasePart?>,
	Reading: Vide.Source<boolean>,
	Ready: boolean,
	Reveal: Vide.Source<number>,
	Scale: Vide.Source<number>,
	ScareSeen: number,
	Scroll: Vide.Source<number>,
	Session: Session?,
	Spotlight: boolean,
	Spotlit: boolean,
	Startled: { [number]: boolean },
	Unread: Vide.Source<boolean>,
	Written: Vide.Source<number>,
	Setup: (self: Public) -> (),
	WatchPaper: (self: Public) -> (),
	MountPaper: (self: Public, playerGui: Instance) -> (),
	Animate: (self: Public) -> (),
	Apply: (self: Public, night: number) -> (),
	CanvasPerPixel: (self: Public) -> number,
	ScrollBy: (self: Public, delta: number) -> (),
	FrontNow: (self: Public) -> { [number]: boolean },
	Scan: (self: Public, session: Session) -> (),
	Overlay: (self: Public) -> (() -> (), ScreenGui, GuiButton?),
	BindScroll: (self: Public, session: Session) -> (),
	StepReading: (self: Public, session: Session, dt: number) -> (),
	Enter: (self: Public) -> (),
	Leave: (self: Public) -> (),
	HeadOf: (self: Public, id: number) -> Vector3?,
	LookUp: (self: Public, session: Session) -> (),
}

return {}
