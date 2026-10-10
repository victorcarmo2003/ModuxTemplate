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
| `ANM-###` | anomalia | `docs/story/anomalies.md` |
| `MAP-##` | mapa/área | `docs/levels/MAP-##.md` |
| `CHR-###` | personagem da história | `docs/story/characters.md` |
| `AST-###` | asset 3D/visual | `docs/art/asset-list.md` |
| `TASK-###` | tarefa de implementação | `docs/tasks/board.md` |

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

Fluxo e paralelismo: `docs/PIPELINE.md`.

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

Código, identificadores e commits em inglês. Documentação e conversa em pt-BR.

## Assets

- Packs prontos: `Assets/FoodPack`, `Assets/KitchenPack` — use antes de modelar do zero.
- Fontes Blender: `Assets/blender/<categoria>/AST-###_<nome>.blend`
- Exportados: `Assets/models/<categoria>/AST-###_<nome>.fbx`
- Texturas: `Assets/textures/`, referências visuais: `Assets/reference/`
- Limites de orçamento (tris, texturas) ficam em `docs/art/style-guide.md`.
- **Asset de terceiros só entra no repositório com licença verificada** que permita uso comercial (CC0, CC-BY com crédito, compra com licença de jogo ou permissão escrita do autor), registrada em `docs/art/credits.md`. Modelo do Sketchfab sem download liberado / sem licença = todos os direitos reservados: não usar.
