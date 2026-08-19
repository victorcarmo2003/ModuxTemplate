# ModuxTemplate

Template inicial pro framework **Modux** (arquitetura Service/Controller/Component customizada, extraída do projeto Faithless), já com 4 sistemas essenciais funcionando:

- **ProfileService** (`src/server/Services/ProfileService`) — persistência de dados via ProfileStore (vendorizado em `Profile.luau`), com replicação automática (`Data`/`DataKey`) pro client.
- **VitalService + VitalComponent** (`src/server/Services/Player/VitalService.luau`, `src/server/Components/Player/VitalComponent.luau`) — Health/Armor/Stamina, dano, morte e respawn via `SpawnService`.
- **AnimateController** (`src/client/Controllers/Player/AnimateController.luau`) — máquina de estados de animação (Idle/Walk/Sprint/Jump/Fall/Land) reativa com `vide`.
- **InputController** (`src/client/Controllers/InputContext/InputController.luau`) — wrapper de `ContextActionService` com contexto (Gameplay/Menu) e binds desktop+mobile.

## Estrutura

```
src/
├── server/
│   ├── init.server.luau
│   ├── Services/
│   │   ├── Player/{PlayerService,SpawnService,VitalService}.luau
│   │   └── ProfileService/{init,Profile}.luau
│   └── Components/Player/VitalComponent.luau
├── client/
│   ├── init.client.luau
│   └── Controllers/
│       ├── Player/AnimateController.luau
│       └── InputContext/InputController.luau
└── shared/
    ├── Modux/           -- framework (não edite src/shared/Modux/src/**)
    │   ├── init.luau
    │   ├── CoreTypes.luau    -- tipos base (edite ao adicionar módulos)
    │   ├── Types.luau        -- *FnMap de cada Service/Controller/Component
    │   ├── Manifest.luau     -- lista de módulos carregados pelo Loader
    │   └── src/Network/init.luau  -- pacotes lync (específico de projeto)
    └── Templates/Profile.luau     -- schema dos dados persistentes
```

## Como funciona o carregamento de tipos

No projeto original, `CoreTypes.luau`, `Types.luau` e `Manifest.luau` são **gerados** por uma tooling externa (`syncteam`, listada em `rokit.toml`) que varre `src/server`/`src/client`/`src/shared` procurando `Modux.Service(...)`, `Modux.Controller(...)`, etc. Neste template esses três arquivos foram escritos à mão, reduzidos aos módulos essenciais acima.

Ao criar um novo Service/Controller/Component:

1. Escreva o módulo normalmente (ver padrões abaixo).
2. Adicione o caminho dotted em `src/shared/Modux/Manifest.luau` (`Services.X`, `Controllers.X`, `Components.X`).
3. Adicione a entrada em `ServiceFnMap`/`ControllerFnMap`/`ComponentFnMap` dentro de `src/shared/Modux/Types.luau` (pode apontar pra `any` se não quiser tipar os métodos específicos — só isso já dá autocomplete nos IDs válidos de `:Import("...")`).

Se você tiver o `syncteam` disponível, ele deve conseguir regenerar esses três arquivos automaticamente a partir daqui em diante.

## Padrões Modux

```luau
-- Service (server-only, singleton)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyService = Modux.Service("MyService")
MyService:Import("PlayerService")

MyService:OnInit(function(self) end)
MyService:OnStart(function(self) end)

return MyService
```

```luau
-- Controller (client-only, singleton)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyController = Modux.Controller("MyController")

MyController:OnInit(function(self)
	self.Network.Packages.SomePacket:on(function(data, sender, timestamp) end)
end)

return MyController
```

```luau
-- Component (tagged instance)
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local MyComponent = Modux.Component("MyComponent"):Tag("TagName"):ClassName("Instance")

MyComponent:OnStart(function(self) end)
MyComponent:OnDestroy(function(self) end)

return MyComponent
```

Dependências entre módulos: `:Import("Name")`. Lifecycle: `OnInit` (setup) -> `OnStart` (todos os módulos prontos) -> `OnDestroy` (cleanup). Rede: server manda com `self.Network.Packages.X:send(data, Player)`, client escuta com `:on(callback)`.

## Setup

```
rokit install
wally install
rojo serve
```

## O que NÃO está incluso

De propósito, pra manter o template enxuto: câmera, UI (vide components), FSM, zonas, sistemas de mapa/rodada, VitalController (UI de HP client-side — acopla em `vide` + interface própria, então fica de fora; siga o padrão do `AnimateController` pra criar o seu). Adicione conforme a necessidade do projeto.
