--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

export type Mode = "FirstPerson" | "Spectate" | "Fixed" | "Cutscene" | "Prep" | "External"
export type Rig = {
	Dolly: Vector3, -- eye offset, camera space (X right, Y up, Z forward)
	Boom: Vector3?, -- detached eye in walker space (X right, Y up, Z forward of the own body): the establishing shot
	BoomLook: Vector3?, -- what a boom looks at, walker space from the head
	Orbit: number, -- radians the eye circles the focus target
	Roll: number,
	Fov: number?, -- overrides the focus fov
	Far: number?, -- depth of field far blur
	Rack: number?, -- 1/s the depth of field follows the focus
	Shake: Vector3, -- hand-held, camera space studs
	Tilt: Vector3, -- hand-held, radians (pitch, yaw, roll)
}
export type PrepOptions = {
	Fov: number?, -- field of view at the station
	Travel: number?, -- s the glide takes at most (0 = a cut); the real time follows the distance, between Min and Travel
	Min: number?, -- s: the shortest glide (a short hop between two views)
	Look: Vector3?, -- the point the camera looks at (the Focus of the view); nil = along the frame
	Dof: boolean?, -- depth of field behind the work surface (quality > 3 only; the caller decides)
	Focus: number?, -- studs of the DOF focus distance (camera to the point looked at); it glides with the view
	Radius: number?, -- studs in focus around it
	Far: number?, -- far blur intensity
}
type PrepState = {
	Pos: Vector3,
	PosVel: Vector3,
	Look: Vector3,
	LookVel: Vector3,
	Fov: number, -- now
	FovVel: number,
	FocusDist: number,
	FocusVel: number,
	RadiusNow: number,
	RadiusVel: number,
	-- where it is going
	To: CFrame,
	ToLook: Vector3,
	ToFov: number,
	ToFocus: number,
	ToRadius: number,
	Omega: number, -- 1/s of the springs
	BaseFov: number,
	Start: number,
	Travel: number,
	Leaving: boolean,
	Last: number, -- os.clock of the last frame
	Dof: DepthOfFieldEffect?,
	Far: number,
}
type Group = "Head" | "Arm" | "Body"

export type Public = {
	Applied: boolean,
	ArmShadowOff: { [BasePart]: boolean },
	ArmsVisible: Vide.Source<boolean>,
	BaseFov: number?,
	BasePitch: number,
	BaseYaw: number?,
	Bound: boolean,
	CanSwitch: Vide.Source<boolean>,
	Character: Model?,
	CharacterConnections: { RBXScriptConnection },
	Dirty: boolean,
	Dof: DepthOfFieldEffect?,
	DownAt: number?,
	FallPoint: string?,
	FixedPoint: Vide.Source<string?>,
	FocusFov: number?,
	FocusGetter: (() -> Vector3?)?,
	GazeAt: number,
	GazePitch: number,
	GazeYaw: number,
	Groups: { [BasePart]: Group },
	HoldYaw: number?,
	LastLookInput: number,
	LastPosition: Vector3?,
	LastState: string,
	LastTargetYaw: number?,
	LookPitch: number,
	LookVelocity: Vector2,
	LookYaw: number,
	Mode: Vide.Source<Mode>,
	MouseLocked: boolean,
	NextDrive: number,
	NextGaze: number,
	NextPointRetry: number,
	NextStream: number,
	PointId: string?,
	PrepState: PrepState?,
	Retarget: boolean,
	Rig: Rig?,
	Target: number?,
	TouchDelta: Vector2,
	Transition: { FromYaw: number, FromPitch: number, At: number, Time: number }?,
	WasBoom: boolean,
	Watching: Vide.Source<number?>,
	Setup: (self: Public) -> (),
	SetMode: (self: Public, mode: Mode) -> (),
	PrepClear: (self: Public) -> (),
	Prep: (self: Public, on: boolean, frame: CFrame?, options: PrepOptions?) -> (),
	PrepGoal: (self: Public, eye: Vector3, look: Vector3, fov: number, omega: number?, focus: number?, radius: number?) -> (),
	PrepExitFrame: (self: Public) -> CFrame?,
	ApplyPrep: (self: Public, camera: Camera) -> (),
	ResetLook: (self: Public) -> (),
	Cutscene: (self: Public, on: boolean) -> (),
	SetRig: (self: Public, rig: Rig?) -> (),
	Focus: (self: Public, getter: (() -> Vector3?)?, fov: number?) -> (),
	LookAt: (self: Public, position: Vector3?) -> (),
	SetArmsVisible: (self: Public, visible: boolean) -> (),
	Spectate: (self: Public, userId: number) -> (),
	Fixed: (self: Public, pointId: string) -> (),
	Mates: (self: Public) -> { number },
	Next: (self: Public) -> (),
	NearestPoint: (self: Public, position: Vector3?) -> string,
	PointFrame: (self: Public, id: string?) -> CFrame?,
	Stream: (self: Public, force: boolean) -> (),
	SetSwitchBind: (self: Public, on: boolean) -> (),
	Drive: (self: Public) -> (),
	Body: (self: Public) -> Model?,
	UnlockMouse: (self: Public) -> (),
	LookInput: (self: Public, dt: number) -> (number, number),
	ApplyPov: (self: Public, mode: Mode, camera: Camera, dt: number) -> (),
	BoomView: (self: Public, rig: Rig, head: Vector3, facing: Vector3) -> Vector3,
	OrbitEye: (self: Public, eye: Vector3, angle: number) -> Vector3,
	CutsceneBase: (self: Public, eye: Vector3, facing: Vector3, camera: Camera, dt: number, now: number) -> (),
	CutsceneLens: (self: Public, camera: Camera, dt: number, distance: number?) -> (),
	ElasticLook: (self: Public, dYaw: number, dPitch: number, dt: number, now: number) -> (),
	ApplyCamera: (self: Public, dt: number) -> (),
	IsFirstPerson: (self: Public) -> boolean,
	SendGaze: (self: Public, now: number) -> (),
	Track: (self: Public, character: Model?) -> (),
	Restore: (self: Public) -> (),
	Update: (self: Public, dt: number) -> (),
}

return {}
