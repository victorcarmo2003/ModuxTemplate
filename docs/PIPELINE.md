# Pipeline de produção

Como os agentes trabalham juntos e em paralelo.

## Fases

| Fase | Objetivo | Saída | Gate |
|---|---|---|---|
| 0. Pré-produção | mapear o jogo inteiro | GDD completo em `docs/` | **bandeira verde** do usuário (`DEC-###`) |
| 1. Fundação técnica | arquitetura + sistemas núcleo (venda, estoque, moeda, upgrades) | `docs/tech/architecture.md` + código | QA verde no núcleo |
| 2. Vertical slice | **MAP-01** jogável do começo ao fim, com arte final | loop completo | aprovação do usuário |
| 3. Produção | demais mapas, conteúdo e progressão | jogo completo | QA por mapa |
| 4. Polimento | balanceamento, performance, mobile, UX | release | playtest |

## Trilhas paralelas

Cada trilha roda numa sessão/terminal própria do Claude Code. Elas se comunicam **só por `docs/`**,
nunca por memória de conversa.

```
Trilha A  usuário + secretary           (design: perguntas, decisões, GDD)
            ├─ chama game-designer / narrative-writer / art-director para propor opções
Trilha B  modeler-3d                    (Blender: consome fichas AST Aprovadas)
Trilha C  level-designer                (conceito e blockout dos mapas já descritos)
Trilha D  researcher                    (referências e viabilidade, sob demanda)
Trilha E  architect → task-planner → backend/frontend-coder → qa-tester   (após bandeira verde)
```

Durante a Fase 0, A, B, C e D já rodam juntas. B só modela ficha **Aprovada** — modelar rascunho é
trabalho jogado fora. Comece por assets que quase certamente existem em qualquer versão do jogo
e que não estejam nos packs de `Assets/`.

### Restrições físicas

- **Blender é um só.** O MCP do Blender controla uma instância; apenas uma sessão `modeler-3d` por vez.
- **Um dono por arquivo.** Antes de editar um doc compartilhado (`board.md`, `asset-list.md`), a trilha
  marca o item com seu dono. Coders trabalham em worktrees separadas (`isolation: worktree`) por feature.
- **`src/Modux` e `src/Libs/Net/init.luau`** são pontos de conflito: mudança neles passa pelo `architect`.

## Ciclo de um item

```
ideia → secretary registra (Rascunho)
      → especialista detalha (game-designer / narrative / art / level)
      → usuário decide → DEC-### → Aprovado
      → task-planner gera TASK-### / AST-### entra na fila do modeler
      → coder/modeler executa
      → qa-tester valida critérios de aceite
      → Feito
```

## Sem o usuário (após bandeira verde)

Dúvida que surge durante a construção:

1. Está respondida em `docs/`? Use.
2. Não está e **não bloqueia**: siga a recomendação do especialista, marque **Provisória**, abra `Q-###` não bloqueante.
3. Não está e **bloqueia** (muda escopo, história ou monetização): abra `Q-###` bloqueante e passe para outra task.
