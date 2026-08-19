--!strict

-- Tipos base do template. Igual ao projeto original, isso normalmente é gerado
-- pela tooling do Modux (syncteam) a partir dos módulos reais em src/server e
-- src/client. Aqui está escrito à mão, então ao adicionar novos Services/
-- Controllers/Components, atualize também Types.luau e Manifest.luau.

export type Mode = "Singleton" | "Transient"
export type Type = "Service" | "Controller" | "Component" | "Mixin"
export type TickRate = number

--> DATA TEMPLATE (Profile) — ver src/shared/Templates/Profile.luau
export type DataTemplate = {
	Gems: number,
	FirstLogin: boolean,
	MusicVolume: number,
	SoundVolume: number,
	MusicEnabled: boolean,
	SoundEnabled: boolean,
}
export type DataTemplateKey = "Gems" | "FirstLogin" | "MusicVolume" | "SoundVolume" | "MusicEnabled" | "SoundEnabled"
export type DataKeyPayload =
	{ key: "Gems", value: number }
	| { key: "FirstLogin", value: boolean }
	| { key: "MusicVolume", value: number }
	| { key: "SoundVolume", value: number }
	| { key: "MusicEnabled", value: boolean }
	| { key: "SoundEnabled", value: boolean }

--> VITAL
export type VitalAttributes = "Armor" | "Health" | "Stamina"

--> INPUT BASE
export type Context = "Gameplay" | "Menu"
export type ContextCallback = (NewContext: Context) -> ()
export type HandlerType = {
	OnPress: (() -> ()) -> HandlerType,
	OnRelease: (() -> ()) -> HandlerType,
	Unbind: () -> (),
	_onPressCallbacks: { [number]: () -> () },
	_onReleaseCallbacks: { [number]: () -> () },
}
export type InputSettings = {
	ActionName: string,
	ActionKey: Enum.KeyCode | Enum.UserInputType,
	TouchButton: boolean?,
	ActionPriority: number?,
	Context: Context?,
	Position: UDim2?,
}

--> LYNC BASE TYPES
export type LyncConnection = { connected: boolean, disconnect: (self: LyncConnection) -> () }
export type LyncPacketStats = { bytesSent: number, bytesReceived: number, fires: number, recvFires: number, drops: number }
export type LyncPacket<T> = {
	send: (self: LyncPacket<T>, data: T, target: any?) -> (),
	on: (self: LyncPacket<T>, fn: (data: T, sender: Player?, timestamp: number?) -> ()) -> LyncConnection,
	once: (self: LyncPacket<T>, fn: (data: T, sender: Player?, timestamp: number?) -> ()) -> LyncConnection,
	wait: (self: LyncPacket<T>) -> (T, Player?, number?),
	name: (self: LyncPacket<T>) -> string,
	stats: (self: LyncPacket<T>) -> LyncPacketStats,
}
export type LyncKeyedPacket<Payload, Key, Value> = LyncPacket<Payload> & {
	sendKey: (self: LyncKeyedPacket<Payload, Key, Value>, key: Key, value: Value, target: any?) -> (),
	onKey: (self: LyncKeyedPacket<Payload, Key, Value>, fn: (key: Key, value: Value, sender: Player?, timestamp: number?) -> ()) -> LyncConnection,
}
export type LyncQuery<Req, Resp> = {
	handle: (self: LyncQuery<Req, Resp>, fn: (request: Req, player: Player?) -> Resp?) -> LyncConnection,
	request: (self: LyncQuery<Req, Resp>, data: Req, target: any?) -> Resp?,
	name: (self: LyncQuery<Req, Resp>) -> string,
	stats: (self: LyncQuery<Req, Resp>) -> LyncPacketStats,
}
export type NetworkTarget = any

--> PROMISE
export type PromiseStatus = "Pending" | "Fulfilled" | "Rejected" | "Cancelled"
export type PromiseLike = Promise<any>
export type Resolve<T> = (value: T | Promise<T>, ...any) -> ()
export type Reject = (reason: any) -> ()
export type OnCancel = (callback: () -> ()) -> ()
export type Executor<T> = (resolve: Resolve<T>, reject: Reject, onCancel: OnCancel) -> ()
export type Promise<T> = {
	andThen: <U>(self: Promise<T>, onFulfilled: ((value: T) -> U | Promise<U>)?, onRejected: ((reason: any) -> U | Promise<U>)?) -> Promise<U>,
	catch: <U>(self: Promise<T>, onRejected: (reason: any) -> U | Promise<U>) -> Promise<T | U>,
	finally: (self: Promise<T>, onFinally: (status: PromiseStatus) -> any) -> Promise<T>,
	tap: (self: Promise<T>, onTap: (value: T) -> any) -> Promise<T>,
	andThenCall: <U>(self: Promise<T>, callback: (...any) -> U, ...any) -> Promise<U>,
	andThenReturn: <U>(self: Promise<T>, value: U) -> Promise<U>,
	finallyCall: (self: Promise<T>, callback: (...any) -> ...any, ...any) -> Promise<T>,
	finallyReturn: <U>(self: Promise<T>, value: U) -> Promise<U>,
	now: (self: Promise<T>, rejectionValue: any?) -> Promise<T>,
	timeout: (self: Promise<T>, seconds: number, rejectionValue: any?) -> Promise<T>,
	cancel: (self: Promise<T>) -> (),
	getStatus: (self: Promise<T>) -> PromiseStatus,
	awaitStatus: (self: Promise<T>) -> (PromiseStatus, T?),
	expect: (self: Promise<T>) -> T,
	await: (self: Promise<T>) -> (boolean, T?),
}
export type PromiseAPI = {
	new: <T>(executor: Executor<T>) -> Promise<T>,
	defer: <T>(executor: Executor<T>) -> Promise<T>,
	resolve: <T>(value: T | Promise<T>) -> Promise<T>,
	reject: <T>(reason: any) -> Promise<T>,
	try: <T>(fn: (...any) -> T, ...any) -> Promise<T>,
	promisify: <T>(callback: (...any) -> T) -> (...any) -> Promise<T>,
	fromEvent: <T>(event: any, predicate: ((...any) -> boolean)?) -> Promise<T>,
	delay: (seconds: number) -> Promise<number>,
	all: <T>(promises: { Promise<T> }) -> Promise<{ T }>,
	some: <T>(promises: { Promise<T> }, count: number) -> Promise<{ T }>,
	race: <T>(promises: { Promise<T> }) -> Promise<T>,
	any: <T>(promises: { Promise<T> }) -> Promise<T>,
	allSettled: <T>(promises: { Promise<T> }) -> Promise<{ { status: "fulfilled", value: T } | { status: "rejected", reason: any } }>,
	each: <T, U>(list: { T }, predicate: (value: T, index: number) -> U | Promise<U>) -> Promise<{ U }>,
	fold: <T, U>(list: { T }, reducer: (acc: U, value: T, index: number) -> U | Promise<U>, initialValue: U) -> Promise<U>,
	retry: <T>(callback: (...any) -> Promise<T>, times: number, ...any) -> Promise<T>,
	retryWithDelay: <T>(callback: (...any) -> Promise<T>, times: number, seconds: number, ...any) -> Promise<T>,
	is: (value: any) -> boolean,
	onUnhandledRejection: (callback: (promise: PromiseLike, reason: any) -> ()) -> () -> (),
	Status: { Pending: "Pending", Fulfilled: "Fulfilled", Rejected: "Rejected", Cancelled: "Cancelled" },
	Error: any,
}

export type GlobalClock = {
	GetTime: (self: GlobalClock) -> number,
	GetSine: ((self: GlobalClock) -> number) & ((self: GlobalClock, speed: number?) -> number) & ((self: GlobalClock, speed: number?, amplitude: number?) -> number) & ((self: GlobalClock, speed: number?, amplitude: number?, offset: number?) -> number),
	Lerp: (self: GlobalClock, a: number, b: number, t: number) -> number,
}

export type Tools = {
	WaitForChildOfClass: any,
	Spring: typeof(require(script.Parent.src.Tools.SpringWrapper)),
	Debounce: typeof(require(script.Parent.src.Tools.Debounce)),
	BreakJoints: (Part: Instance) -> (),
}

export type SignalConnection = {
	Connected: boolean,
	Disconnect: (self: SignalConnection) -> (),
}
export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> SignalConnection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Block: (self: Signal<T...>) -> (),
	Unblock: (self: Signal<T...>) -> (),
	GetConnectionCount: (self: Signal<T...>) -> number,
	DisconnectAll: (self: Signal<T...>) -> (),
}
export type SignalAPI = {
	new: <T...>() -> Signal<T...>,
}

--> NETWORK PACKAGES (Lync) — ver src/shared/Modux/src/Network/init.luau
export type Network = {
	Packages: {
		Data: LyncPacket<DataTemplate>,
		DataKey: LyncKeyedPacket<DataKeyPayload, DataTemplateKey, any>,
		VitalKey: LyncKeyedPacket<{ key: "Armor", value: number } | { key: "Health", value: number } | { key: "Stamina", value: number }, VitalAttributes, number>,
		GetVitals: LyncQuery<nil, { Armor: number, Health: number, Stamina: number }>,
		AnimationState: LyncPacket<{
			State: "Idle" | "Walk" | "Sprint" | "Crouch" | "Jump" | "Fall" | "Land" | "Emote",
			EmoteId: number,
		}>,
	},
	all: NetworkTarget,
}

return {}
