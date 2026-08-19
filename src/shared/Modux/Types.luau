--!strict

-- Registro central de tipos do Modux. No projeto original isso é gerado pela
-- tooling (syncteam) varrendo src/server, src/client e src/shared. Aqui está
-- reduzido à mão, cobrindo só os módulos essenciais deste template.
--
-- Ao criar um novo Service/Controller/Component/Mixin, adicione a entrada
-- correspondente no *FnMap abaixo (pode apontar pra "any" se não quiser tipar
-- os métodos específicos) e registre o caminho em Manifest.luau.

local CoreTypes = require(script.Parent.CoreTypes)

export type Mode = CoreTypes.Mode
export type Type = CoreTypes.Type
export type DataTemplate = CoreTypes.DataTemplate
export type DataTemplateKey = CoreTypes.DataTemplateKey
export type DataKeyPayload = CoreTypes.DataKeyPayload
export type VitalAttributes = CoreTypes.VitalAttributes
export type Context = CoreTypes.Context
export type ContextCallback = CoreTypes.ContextCallback
export type HandlerType = CoreTypes.HandlerType
export type InputSettings = CoreTypes.InputSettings
export type Signal<T...> = CoreTypes.Signal<T...>
export type SignalAPI = CoreTypes.SignalAPI
export type SignalConnection = CoreTypes.SignalConnection
export type Promise<T> = CoreTypes.Promise<T>
export type PromiseAPI = CoreTypes.PromiseAPI
export type GlobalClock = CoreTypes.GlobalClock
export type Tools = CoreTypes.Tools
export type Network = CoreTypes.Network
export type NetworkTarget = CoreTypes.NetworkTarget

export type ImportFn = (self: any, id: string, scopeKey: string?) -> any

--> SERVICES (src/server/Services/**)
export type ServiceFnMap = {
	PlayerService: any,
	ProfileService: any,
	SpawnService: any,
	VitalService: any,
}
export type ServiceFn = <K>(id: K & keyof<ServiceFnMap>, mode: Mode?) -> index<ServiceFnMap, K>

--> CONTROLLERS (src/client/Controllers/**)
export type ControllerFnMap = {
	AnimateController: any,
	InputController: any,
}
export type ControllerFn = <K>(id: K & keyof<ControllerFnMap>, mode: Mode?) -> index<ControllerFnMap, K>

--> COMPONENTS (src/server/Components/**, src/client/Components/**, src/shared/Components/**)
export type ComponentFnMap = {
	VitalComponent: any,
}
export type ComponentFn = <K>(id: K & keyof<ComponentFnMap>, mode: Mode?) -> index<ComponentFnMap, K>

--> MIXINS — nenhum incluso neste template
export type MixinFnMap = {}
export type MixinFn = <K>(id: K & keyof<MixinFnMap>, mode: Mode?) -> index<MixinFnMap, K>

return {}
