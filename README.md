# ModuxTemplate

Ponto de partida para projetos em Roblox com o [Modux V3](https://github.com/victorcarmo2003/ModuxV3):
o framework, a rede já ligada e cinco sistemas base funcionando.

O framework vive em `src/Modux` e é cópia da branch `framework` do repositório do
Modux. Nada do que está aqui é exemplo descartável — é o que roda.

---

## Setup

```sh
rokit install
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
rogen build
modux generate
rojo serve
```

**`wally-package-types` não é opcional.** O shim que o Wally escreve em
`Packages/X.lua` é `return require(_Index[...])`, e `export type` não atravessa
um require assim: os valores resolvem, os tipos não. Sem esse passo,
`Vide.Source` e `Charm.Atom` viram `Unknown type` e o projeto não compila.
Rode de novo depois de cada `wally install`.

`rogen build` vem antes de `modux generate`: o `default.project.json` é gerado a
partir das pastas, e fora de ordem o gerador resolve caminho por um arquivo
velho.

---

## Estrutura

```
src/Modux/           framework (gerado + invariante, ver src/Modux/README.md)
src/Shared/          Types utilitarios (Occlude, Struct, Union) e tablejs
src/Libs/            injetadas em self.Libs: Signal, Promise, FSM, Charm, Net
src/Services/server/ NetService, PlayerService, ProfileService, VitalService, GameService
src/Controllers/client/  NetController, InputController, ProfileController, VitalController, RoundController
src/Components/server/   Vital
src/Interface/       componentes Vide e stories do UI Labs
```

Um módulo é uma pasta com `init.luau`, nunca um arquivo solto: o gerador escreve
o `Type.luau` ao lado do módulo, e dois módulos na mesma pasta colidiriam nesse
nome.

---

## Rede

As definições ficam em `src/Libs/Net/init.luau`, um `Lync.define` só, requerido
pelos dois lados. Adicionar tráfego é adicionar uma entrada ali.

```lua
Vitals = Lync.replicate(Lync.struct({
	Health = Lync.int(0, 100),
	Armor = Lync.int(0, 100),
	Stamina = Lync.int(0, 100),
})),
```

Do lado do código, `self.Libs.Net.Vitals:update(...)` já vem tipado pelo schema.

**O schema é validado em runtime, dentro de `Lync.start()`.** `analyze.ps1`
passando não diz nada sobre ele: um `keyBy` inválido compila e só estoura no
Studio, levando junto tudo que depende do start.

### Set ou packet

| | |
|---|---|
| **set** (`replicate`) | estado que vários clientes veem. Manda só o campo que mudou, junta escritas do mesmo flush, e **entrega o estado atual a quem chega depois**. |
| **packet** (`packet`) | evento, ou dado privado de um jogador só. Não guarda nada: se ninguém estava escutando, se perde. |

`keyBy` particiona a audiência e aceita **só campo finito** — `bool`, `int`,
`quant`, `angle` ou `enum`. Não serve para "cada um vê o seu": um `str` com o
UserId é recusado no start, e um `int` com o range de UserId seria uma grade
absurda. Set é para time, sala, região.

Por isso `Vitals` é set (todos veem) e `Profile` é packet direcionado
(`fireClient(player, ...)`), privado por construção — não por uma alocação de
chave que um bug poderia errar.

### O handshake Ready

Como packet não guarda estado, o servidor não pode replicar o perfil quando
quiser: o cliente demora **segundos** a mais para bootar, e o pacote enviado
antes disso simplesmente some.

`NetController` dispara `Ready` no `OnStart`; `NetService` escuta e expõe o
signal `ClientReady` mais o `IsReady(player)`. `ProfileService:Replicate`
verifica `IsReady` e desiste se o cliente ainda não chegou, e replica de novo
quando o `ClientReady` chega. Os dois caminhos existem porque a ordem entre
"perfil carregou" e "cliente pronto" não é garantida.

Set não precisa disso: quem chega depois recebe o estado atual num `onAdded`.

### start, flush e close

`NetService` e `NetController` existem só para isso, e o lugar deles no ciclo de
vida não é arbitrário:

| | |
|---|---|
| `Priority = 1000` | roda o **primeiro** `OnStart`, quando todos os `OnInit` já registraram seus responders e antes de qualquer módulo disparar |
| `OnTick(..., 60, -1000)` | roda o **último** tick do frame, depois de todo mundo ter escrito |

Isso decorre de como o Loader funciona: ele completa todos os `OnInit` antes de
começar os `OnStart`, e ordena as duas fases por prioridade decrescente.

Daí saem duas regras:

- **Responder de rede só em Service ou Controller, dentro de `OnInit`.**
  `Lync.start()` tranca as definições, e registrar depois disso lança.
- **Componente não registra responder.** Componente tagueado sobe depois do
  `start`, e um responder é único por definição — um por instância seria errado
  de qualquer forma. Componente dispara e lê à vontade.
- **Varredura de quem já está no servidor vai no `OnStart`, não no `OnInit`.**
  `PlayerService` faz isso: varrendo no `OnInit`, os serviços de prioridade
  menor ainda não tinham conectado seus handlers e perderiam quem já estava lá,
  e o `Vitals:add` do componente rodaria antes do `Lync.start()`.

---

## O que vem pronto

| | |
|---|---|
| `PlayerService` | entrada e saída de jogador e de personagem em Signals, tratando quem já estava no servidor |
| `ProfileService` | ProfileStore + set `Profile` do Lync com audiência por dono; `Update` aceita patch parcial e replica só o delta |
| `VitalService` + `Vital` | Health/Armor/Stamina por jogador, dano com absorção por armadura, regen de stamina a 4 Hz, morte e respawn |
| `InputController` | `ContextActionService` com contexto (Gameplay/Menu), binds desktop e mobile |
| `GameService` | ciclo de rodada em `atom` do Charm, com `batch` e `effect` replicando |
| `Counter` | componente Vide com story do UI Labs, para provar o caminho de UI |

O throttle manual de replicação que a versão anterior deste template carregava
não existe mais: um set do Lync manda só o campo que mudou, junta escritas
dentro do mesmo flush e tem orçamento por cliente.

---

## Estado reativo

**Charm no servidor, Vide no client.** São dois sistemas de reatividade que não
se enxergam: um `atom` mudando não re-renderiza Vide. Não há ponte aqui, e é
proposital — o client recebe do Lync e escreve em `source`.

```lua
-- server
self.Status = self.Libs.Charm.atom("Waiting") :: Charm.Atom<Status>

-- client
self.Health = Vide.source(100) :: Vide.Source<number>
```

Para usar Charm no client também, nada precisa mudar: ele já está em
`self.Libs` dos dois lados.

---

## A armadilha do `self.Libs`

Toda pasta em `src/Libs` entra em `self.Libs` automaticamente, com o tipo saindo
de `typeof(require(...))`. Mas **nem toda lib pode entrar**.

Lync e Vide estão fora de propósito. O tipo dos dois contém type function que
não reduz — `Codec<T>` no Lync, `index<Instances, Name>` no `Vide.create` — e
uma dessas dentro dos extras impede o `SelfOf.Build` de reduzir. O resultado é
brutal e enganoso:

```
Cannot add property 'Setup' to table 'setmetatable<Build<Public, {...}>, ...>'
```

Esse erro aparece em **todos** os módulos do projeto, em métodos que não têm
nada de errado, e nunca menciona a lib que o causou. Uma lib ruim derruba a
tipagem inteira.

Por isso os dois são requeridos direto onde se usa:

```lua
local Lync = require(ReplicatedStorage.Packages.Lync)
local Vide = require(ReplicatedStorage.Packages.Vide)
```

`src/Libs/Net` continua em `self.Libs` e funciona: `Lync.define(...)` devolve as
definições com os tipos já aplicados a codecs concretos, então nada fica
pendente.

**Se depois de adicionar uma lib o projeto inteiro passar a acusar
`Cannot add property`, o suspeito é a lib que você acabou de adicionar.** Tire
de `src/Libs`, requeira direto, e rode `tools/analyze.ps1` de novo.

---

## Verificando

```sh
modux check          # falha se algo esta desatualizado (CI)
tools/analyze.ps1    # roda o motor do editor sobre o projeto inteiro
```

`analyze.ps1` passando não prova que os tipos existem — prova que nada errou.
Para saber se o `self` está mesmo tipado, escreva um acesso que **deveria**
falhar (`self.Dependencies.ServicoQueNaoDeclarei`) e confirme que ele falha.

### `LuauSolverV2` é obrigatório

Sem a flag não existe type function, `self` fica sem tipo e o autocomplete
devolve zero item — sem erro e sem aviso. O `.vscode/settings.json` já liga.

---

## Atualizando o framework

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 /tmp/modux
```

E copie por cima de `src/Modux`, menos os quatro arquivos gerados
(`*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`), que o
`modux generate` reescreve. Os dois `Bootstrap` são seus.
