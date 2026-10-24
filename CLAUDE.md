# Sell Hotdogs

Jogo de Roblox feito 100% com IA. Visão, público e loop ainda a definir em `docs/vision.md`.

> Inspiração, não cópia. Nomes, personagens, falas, logos e assets de outros jogos ou marcas
> **não entram** no projeto. Tudo é original.

---

## Fase atual: 1 — Produção

Bandeira verde dada pelo usuário em 2026-10-10 (**DEC-193**). Regras da fase:

- Código de gameplay em `src/` liberado, guiado pelas `TASK-###` de `docs/tasks/board.md`.
- Documentos ainda em Rascunho valem como base **Provisória**; para virar **Aprovado** continua precisando de DEC do usuário.
- Os agentes constroem sem depender do usuário: dúvida nova vira entrada em `docs/open-questions.md` e o trabalho
  segue com a recomendação do agente, marcada como **Provisória**. As perguntas ao usuário vão em lotes.

---

## Fonte da verdade

`docs/` é a fonte da verdade do design. Comece por `docs/README.md`.

Ordem de autoridade quando dois documentos discordam:

1. `docs/decisions.md` (decisões do usuário, append-only)
2. documento de design com status **Aprovado**
3. documento com status **Rascunho**
4. qualquer coisa dita em conversa e não registrada — não vale até ser registrada

Ninguém além do usuário aprova. Agente propõe, secretário registra, usuário decide.

### IDs

Tudo que é referenciado entre documentos tem ID estável. Nunca reaproveite um ID apagado.

| Prefixo | O quê | Onde |
|---|---|---|
| `DEC-###` | decisão | `docs/decisions.md` |
| `Q-###` | pergunta aberta | `docs/open-questions.md` |
| `FEAT-###` | feature/mecânica | `docs/design/features.md` |
| `ITM-###` | item/produto/ingrediente | `docs/design/items.md` |
| `UPG-###` | upgrade/equipamento | `docs/design/upgrades.md` |
| `NPC-###` | NPC (cliente, vendedor) | `docs/design/npcs.md` |
| `CLS-###` | classe jogável | `docs/design/classes.md` |
| `ANM-###` | anomalia | `docs/design/anomalies-v2-proposal.md` (V2, DEC-254); histórico em `docs/story/anomalies.md` |
| `ATM-#` | atmosfera da noite | `docs/design/anomalies-v2-proposal.md` §4 (DEC-257) |
| `MAP-##` | mapa/área | `docs/levels/MAP-##.md` |
| `CHR-###` | personagem da história | `docs/story/characters.md` |
| `AST-###` | asset 3D/visual | `docs/art/asset-list.md` |
| `TASK-###` | tarefa de implementação | `docs/tasks/board.md` |
| `SFX-###` / `MUS-###` / `AMB-###` | efeito sonoro / música / ambiente | `docs/audio/sound-list.md` |

### Status de documento

Todo documento de design começa com uma linha `Status:` — `Vazio`, `Rascunho`, `Em revisão`, `Aprovado`.
Mudar para **Aprovado** só com decisão do usuário registrada (`DEC-###`).

---

## Agentes (`.claude/agents/`)

| Agente | Papel |
|---|---|
| `secretary` | conduz o mapeamento com o usuário, mantém o GDD, decisões e perguntas abertas |
| `game-designer` | mecânicas, produtos, clientes, upgrades, progressão, economia, números |
| `narrative-writer` | ambientação, personagens, falas, textos de tutorial e UI |
| `art-director` | direção visual, style guide, fichas de asset para o modelador |
| `level-designer` | layout e fluxo de cada mapa, blockout, rotas de NPC |
| `modeler-3d` | modela/gera assets no Blender (MCP) e exporta para `Assets/` |
| `researcher` | referências de jogos do gênero, APIs do Roblox, bibliotecas, viabilidade |
| `architect` | arquitetura técnica sobre Modux V3, contratos de rede, dados persistidos |
| `task-planner` | quebra specs aprovadas em `TASK-###` paralelizáveis |
| `backend-coder` | Services e Components do servidor |
| `frontend-coder` | Controllers do client, UI em Vide, câmera, input, VFX |
| `qa-tester` | plano de teste por feature, análise estática, validação de critérios |
| `debugger` | causa raiz de bug, correção mínima |

Fluxo e paralelismo: `docs/PIPELINE.md`. Regras fixas para todo agente (gate, Lync, Studio, UI, docs em lote): `docs/AGENT-BRIEF.md`.

---

## Stack técnica

Leia `README.md` (raiz) antes de escrever qualquer código. Resumo do que não pode ser esquecido:

- Framework **Modux V3** em `src/Modux` (não editar; gerados: `*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`).
- Estrutura **feature-based**: `src/<Feature>/server/` e `src/<Feature>/client/`. Feature nova = pasta nova.
- Módulo com mais de um arquivo é pasta com `init.luau`.
- Rede: **Lync**, definições em `src/Libs/Net/init.luau`. Set (`replicate`) para estado compartilhado, packet para evento/privado. `keyBy` só campo finito.
- Responder de rede só em Service/Controller dentro de `OnInit`. Componente não registra responder.
- **Charm no servidor, Vide no client.** Lync e Vide são requeridos direto, nunca em `src/Libs`.
- Luau `--!strict`, `LuauSolverV2`, `const` para valores imutáveis.
- Ordem de build: `rogen build` → `modux generate` → `rojo serve`.
- Verificação: `modux check` e `tools/analyze.ps1` (zero erro antes de entregar).
- Preparo do hot dog é o **modo focado** (DEC-223): contratos em `Content.Prep` e `src/Prep/shared/Grade.luau`, desenho em `docs/tech/prep-mode.md`. A nota é calculada só em `Grade`; teste com `/dev prep grade`.

Código, identificadores e commits em inglês. Documentação e conversa em pt-BR.

## Assets

- Packs prontos: `Assets/FoodPack`, `Assets/KitchenPack` — use antes de modelar do zero.
- Fontes Blender: `Assets/blender/<categoria>/AST-###_<nome>.blend`
- Exportados: `Assets/models/<categoria>/AST-###_<nome>.fbx`
- Texturas: `Assets/textures/`, referências visuais: `Assets/reference/`
- Limites de orçamento (tris, texturas) ficam em `docs/art/style-guide.md`.
- **Asset de terceiros só entra no repositório com licença verificada** que permita uso comercial (CC0, CC-BY com crédito, compra com licença de jogo ou permissão escrita do autor), registrada em `docs/art/credits.md`. Modelo do Sketchfab sem download liberado / sem licença = todos os direitos reservados: não usar.

---

## Trabalho em dupla (desde 2026-10-23)

Duas pessoas, cada uma com o seu Claude Code, no mesmo jogo. Estas regras existem para os dois lados não se
atropelarem. Valem para **todo** agente e sessão, nas duas máquinas. Setup da máquina do colaborador:
`docs/SETUP-COLABORADOR.md`.

### Quem é quem

- **Dono:** Victor (`victorcarmo2003` / `H4K0R`). Repositório canônico: `github.com/victorcarmo2003/ModuxTemplate`
  (remote `upstream` na máquina do colaborador, `origin` na do dono).
- **Colaborador:** trabalha na **fork** dele (remote `origin` lá) e manda Pull Request para o `main` do dono.
- "Usuário"/"dono" nas regras acima = **Victor**. `DEC-###` só nasce com o OK do Victor. O colaborador propõe
  (PR, `Q-###`, linha Provisória no registro do dia); o Claude do colaborador **não** registra DEC sozinho.
- Antes de começar, o Claude pergunta (uma vez por sessão, se não souber) **em qual máquina está**: dono ou colaborador.
  `git config user.name` / `git remote -v` costumam responder sem precisar perguntar.

### Git

- `main` é a linha de integração. Todo trabalho em branch curta a partir do `main` atualizado:
  `feat/<assunto>`, `fix/<assunto>`, `tune/<assunto>` (colaborador: prefixo `c/`, ex. `c/feat/shop-ui`).
- Antes de abrir branch e antes do PR: `git fetch upstream && git rebase upstream/main` (colaborador) ou
  `git pull --rebase origin main` (dono). Branch velha = conflito garantido.
- PR pequeno, um assunto. Título no padrão dos commits (`feat(anomaly): ...`, em inglês). O outro revisa antes do merge
  quando mexer em ponto de conflito (abaixo). Ninguém dá `push --force` no `main`.
- **Git LFS obrigatório** (`.gitattributes`: `.blend`, `.fbx`, `.obj`, `.glb`, `.bin`, `.png`). Rode `git lfs install`
  uma vez. Arquivo > 100 MB não entra (limite do GitHub); `.rar`/zip de thumbnails ficam fora.
- Commit só pela sessão principal (orquestrador), nunca por subagente (`docs/AGENT-BRIEF.md` §1).

### IDs sem colisão

Os IDs são sequenciais, e dois Claudes pegando "o próximo número" ao mesmo tempo geram o mesmo ID. Por isso:

- **Dono:** continua a sequência normal (abaixo de 5000).
- **Colaborador:** todo ID novo, de **qualquer** prefixo (`TASK`, `Q`, `FEAT`, `ITM`, `UPG`, `NPC`, `ANM`, `AST`,
  `SFX`, `MUS`, `AMB`, `CHR`, `CLS`...), começa em **5001** e segue dali (`TASK-5001`, `Q-5001`, `AST-5001`).
  `DEC` é só do dono, então não tem faixa do colaborador.
- Nunca renumere um ID que já existe, nem para "arrumar" a sequência.

### Posse de arquivo e de tarefa

- Antes de pegar uma `TASK-###`, marque o dono no `docs/tasks/board.md` (`Dono: victor` / `Dono: <colaborador>`) num
  commit pequeno e já mande pro `main` (ou avise o outro). Tarefa com dono é do dono até ele soltar.
- Uma feature (`src/<Feature>/`) por pessoa de cada vez. Mexer na feature que o outro está mexendo: combine antes.
- **Pontos de conflito** (PR precisa do OK do outro): `src/Libs/Net/init.luau` (contratos Lync), `src/Shared/Content/*`
  compartilhados por várias features, `src/Modux/**`, `wally.toml`/`rokit.toml`, `default.project.json`,
  `docs/decisions.md`, `.claude/agents/*`, `CLAUDE.md`, `docs/AGENT-BRIEF.md`.
- Arquivos append-only (`docs/decisions.md`, `docs/open-questions.md`, `docs/tasks/board.md`, registros de asset id):
  sempre acrescente **no fim** da seção. No conflito, mantenha **as duas** entradas.
- Gerados (`*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**`): no conflito, aceite
  qualquer lado e rode `rogen build` → `modux generate` de novo. Nunca resolva à mão.
- Registro do dia: o colaborador usa `docs/tasks/playtest-YYYY-MM-DD-<nome>.md`, para não brigar pelo mesmo arquivo.

### Studio, mapa e Roblox

- O código vai pelo git + Rojo. O **mapa** (workspace) vive no place do Roblox, não no git.
- **Nunca** dois `rojo serve` no mesmo place de Team Create: um sobrescreve os scripts do outro. Cada um testa numa
  cópia local do place (File → Save to File, `.rbxl` já é ignorado pelo git).
- Mapa: quem edita à mão no place oficial é o **dono**. O colaborador muda mapa pelas tabelas do repo
  (`tools/assetplace/*placements*`) e pede ao dono para aplicar. `Place.run` só com o pedido explícito do dono, depois de
  `Place.diff` = 0 e place salvo (ele apaga edições à mão).
- Upload de asset (Open Cloud): cada um usa a **própria** chave em `ROBLOX_API_KEY` (variável de ambiente, nunca no repo),
  com permissão no grupo do jogo. Universe id do jogo: `10769741507` (não é BadgeId).
- Segredo (chave de API, cookie, token) **nunca** entra em arquivo versionado nem em log commitado.

### Skills e memória

- Skills do projeto estão em `.claude/skills/` (`roblox-asset-pipeline`, `roblox-cartoon-animal-char`,
  `roblox-thumbnail`, `roblox-vide-ui`). A cópia do repo é a oficial: melhoria na skill vai por PR, não só na máquina local.
- A memória automática do Claude é local de cada máquina e **não** vai pelo git. Regra que o outro lado precisa saber
  vai para este arquivo, `docs/AGENT-BRIEF.md` ou `docs/`.
- Gosto do dono para terror (vale para anomalia, cena, trailer): crescendo cinematográfico até **um** clímax monstruoso;
  tarefa simples sob nervosismo; poucos sinais, depois muitos; silêncio logo antes do pico; respiração/batimento;
  distorção de cor e blur no pico. Referência que ele chamou de perfeita: o blackout (ANM-020).
- Sessão filha (worktree paralela) não roda install, `modux generate/check` nem `analyze.ps1`: reporta à sessão-pai, que
  roda o gate uma vez.
