Status: Rascunho (briefing fixo; o orquestrador cita este arquivo em vez de repetir regras no prompt)

# Briefing fixo dos agentes

Vale para todo agente de implementação. O prompt da tarefa traz só o que é específico (TASK, arquivos, critérios).
Fontes: `CLAUDE.md`, `README.md`, `docs/PIPELINE.md`, `tools/assetplace/STUDIO_LAYER.md`, skill `roblox-asset-pipeline`.

## 1. Gate (nesta ordem, antes de entregar)

1. `rogen build` → `modux generate` → `modux check` (zero erro).
2. `tools/analyze.ps1 -Changed` (só as features que você mexeu) ou `-Filter "*SeuArquivo.luau"`. Erro fora dos seus arquivos: liste, não conserte.
3. O **orquestrador** roda o `analyze.ps1` completo (um processo só) e é o **único que commita**. Agente não faz `git commit`.
4. Gerados, nunca à mão: `*/Manifest/init.luau`, `*/Modules.luau`, `shared/Libs.luau`, `src/ModuxTypes/**`, `src/Modux/**`.
5. Warnings de CRLF/LF do git são ruído, ignore. Tipo gerado quebrado em `ModuxTypes` quase sempre é comentário `--` no meio de um `self.X = ... :: T -- texto` em Setup: comentário vai na linha de cima.

## 2. Código

- Luau `--!strict`, `LuauSolverV2`, `const` para imutáveis. Identificadores, commits e logs em **inglês**; docs e conversa em pt-BR.
- Feature-based: `src/<Feature>/server|client`. Módulo com mais de um arquivo = pasta com `init.luau`.
- Rede: Lync, só em `src/Libs/Net/init.luau`. Set (`replicate`) = estado compartilhado; packet = evento/privado. `keyBy` só campo finito. Responder só em Service/Controller dentro de `OnInit`.
- **Lync `drop.section`**: set com 8+ registros e registro de menos de 7 bits some no cliente. Use `Lync.int(0, 255)` e o clamp real no servidor.
- Charm no servidor, Vide no client. Vide: `derive`/`effect`/`source` **só dentro de um root** (`Vide.root`/mount). Lync e Vide são requeridos direto, nunca em `src/Libs`.
- Não mexa em arquivos de outro agente da mesma rodada (o prompt lista a posse). Um dono por arquivo.
- Dev: comando novo = arquivo novo em `src/Dev/server/DevService/Commands/` (contrato em `Api.luau`); o `DevService` não se edita.

## 3. Studio e mapa

- O Studio **muda de id ao reabrir**: sempre `list_roblox_studios` antes.
- Snippets de Studio são **idempotentes e cirúrgicos** (acham por nome/MeshId/atributo, nunca por coordenada; marcam o que já fizeram). **Nunca `Place.run`** sem pedido explícito do dono: ele apaga edições à mão. Antes, `Place.diff` = 0 e o dono salvar (memória `studio-hand-edits`).
- `MeshId` **não é gravável por script**: clone a MeshPart nova do template e destrua a antiga, **removendo os filhos clonados do template** (senão duplicam attachments/welds). Depois mova filhos, welds e atributos para a peça nova.
- Para carregar um snippet do repo: `tools/studio/README.md` (`run_snippet`). Não cole snippets longos no prompt.
- Não altere o mapa fora do escopo da tarefa. Edit lighting é frio: julgue cor em Play.
- Teste de fumaça: `/dev smoke` (`tools/studio/smoke.md`). Rode antes de entregar mudança de servidor.

## 3b. Modo de preparo focado (`docs/tech/prep-mode.md`, DEC-223)

- Contratos prontos (onda P0): `Content.Prep` (`src/Shared/Content/Prep.luau`: `Rules`, `Tabs`, `Steps`, `Gestures`, `Tolerances`, `Grades`, `Reasons`, `Texts`), packets `PrepEnter/Leave/Tab/Grill/Begin/Finish/Trash/Order`, `PrepResult` (privado) e o set `PrepSeats` em `Libs/Net`. Número novo de nota ou tolerância = linha nova em `Prep.luau`, nunca constante no código; topping novo exige linha em `Tolerances` (o `Validate` cobra).
- A conta de nota vive em um lugar só: `src/Prep/shared/Grade.luau` (puro, usado pelo client para a prévia e pelo servidor para o veredito). Não reimplemente.
- Mexeu em `Grade`, `Prep.luau` ou nas tolerâncias: rode `/dev prep grade` em Play (`tools/studio/README.md`, `run_snippet`); precisa terminar com `N/N ok`. Sem Studio, o mesmo teste roda em Luau puro (`luau.exe` do rokit, sem Roblox, trocando `const` por `local`).
- `Prep.Rules.WorldKitchenPrompts = false` esconde os prompts de cozinha do mundo; `true` devolve o fluxo antigo (rollback sem código).

## 4. Conteúdo, voz e UI

- Voz TTS: sem a palavra **"sausage"** (filtro) e **sem números de telefone**; use `frank`. Falas curtas, por frase, com pausas.
- UI: **sem vermelho de alerta** (paleta da casa: creme, mostarda, tinta; ver `docs/art/style-guide.md`). Texto em inglês na UI. Nada centralizado em 1ª pessoa (README, "armadilha da UI no centro").
- Nomes, personagens, falas e assets de outros jogos não entram. Asset de terceiros só com licença verificada em `docs/art/credits.md`.

## 5. Documentação (regra em lote, ver `docs/PIPELINE.md`)

- **Não edite documentos de design** durante a rodada. Registre no registro do dia (`docs/tasks/playtest-YYYY-MM-DD.md`): item no checklist e linha na tabela de **Valores provisórios** (Valor, Onde, Antes, Depois, Precisa decidir?).
- Valor novo vira **Provisório** na tabela, **sem DEC** (só o dono aprova). `Q-###` só para decisão real do dono, não para cada número.
- Dúvida que bloqueia escopo/história/monetização: `Q-###` bloqueante e troque de tarefa.
- O secretário atualiza os docs de design no fim da rodada, a partir do registro e do `git diff`.

## 6. Relatório final do agente

Curto (≤ 20 linhas, pt-BR): o que mudou, arquivos (caminho absoluto), resultado do gate, linhas para o registro do dia, o que ficou fora do seu escopo.
