# Revisão: arjun988/blender-skills

Status: Rascunho (pesquisa, 2026-10-14). Nada foi instalado, baixado ou executado; só leitura via WebFetch/WebSearch.

## Pergunta

Vale trazer skills de https://github.com/arjun988/blender-skills (MIT, 94 skills) para o Sell Hotdogs?

## Resposta curta

Não instalar o pacote. Vale **garimpar 4 a 6 arquivos** e fundi-los (reescritos, em inglês curto) na nossa skill `roblox-asset-pipeline` ou em `docs/art/`. O pacote é genérico, orientado a Unity/Unreal/Godot e AAA, sem nada de Roblox, e pesa contexto. Nossa skill já cobre melhor o que importa (atlas, export Roblox, verificação no Studio, R6). Segurança: nenhum conteúdo suspeito nos arquivos lidos, mas há ressalvas de setup (abaixo) e não li o repositório inteiro.

## Estrutura (confirmado)

- 94 skills em `.claude/skills/<nome>/SKILL.md` (a listagem da pasta tem 95 entradas, incluindo `references/` compartilhada), cada uma com `references/` própria. README cita 175+ arquivos de referência.
- Compartilhado em `.claude/skills/references/`: asset-pipeline, mcp-integration, mcp-tools, naming-conventions, polycount-budgets, reference-analysis-template, reference-image-match, validation-checklist, visual-match-checklist (lista pode estar incompleta).
- Fora das skills: `.claude-plugin/`, `.cursor/` (espelho), `.mcp.json`, `docs/BLENDER_MCP_SETUP.md`, `QUICKSTART.md`, `CLAUDE.md`, `site/` (Next.js/Tailwind/TypeScript, só site de divulgação).
- Skills são só Markdown com frontmatter YAML (name, description, license, triggers, related skills). Seções fixas: When to Use, Workflow, MCP Integration, MUST DO / MUST NOT DO, Reference Guide.
- Depende do addon BlenderMCP (ahujasid/blender-mcp). Nós já temos MCP do Blender.

## Qualidade e utilidade (amostra lida)

| Skill | Linhas (aprox.) | Tokens (aprox.) | Avaliação |
|---|---|---|---|
| blender-director | 358 | 5-6k | Roteador de 94 skills + briefing. Pesado; só faz sentido com o pacote inteiro. |
| lowpoly-style | 150 | ~2k | Foco PS1/PS2/horror. Orçamentos e teste de silhueta úteis; resto não. |
| stylized-style | 165 | ~2.3k | Shape language, paleta limitada, hand-painted. Parte útil. |
| qa-review | 100 | ~1.4k | Severidade (Blocker/Major/Minor), 5 ângulos de captura, veredito SHIP/NO-SHIP. Bom formato. |
| asset-optimization | 130 | ~1.8k | Auditoria pré-export, limpeza de malha, LOD. Sem Roblox. |
| prop-artist | 90 | ~1.2k | Tiers de tris, kitbash. Voltado a props realistas e desgaste. |
| character-artist | 160 | ~2.2k | Edge loops e rosto realista/estilizado. Pouco útil para animal R6 com rosto por textura. |
| export-pipeline | 155 | ~2.2k | Unreal/Unity/Godot; convenção de escala/eixos inconsistente (relatado pela leitura). Não serve. |
| texture-workflow | 135 | ~1.8k | Bake PBR, atlas/trim sheet. Não menciona vertex color. Nosso método de atlas por faixas UV é mais simples. |
| uv-workflow | não lido (a URL raw deu 404) | - | Não verificado. |
| references/polycount-budgets | 90 | ~1.2k | Números "AAA-informed"; redução 50-90% para low-poly. Referência fraca. |
| references/validation-checklist | 100 | ~1.3k | Checklist amplo: escala, normais, UV, topologia, materiais, export. |
| references/reference-image-match | 210 | ~2.8k | Método bom: analisar, enquadrar, blockout, comparar até 3 passes. |
| cozy-wholesome-mood | 26 | ~0.4k | 5 princípios de humor aconchegante. Curto e inofensivo. |

Tokens estimados por mim (~13 tokens/linha), não medidos. Linhas vêm do que o WebFetch reportou (algumas são estimativas do modelo; blender-director veio do contador do GitHub: 358 linhas, 19,2 KB).

Qualidade geral: bem organizado e consistente, mas genérico e com ar de "gerado em série". Há incoerências internas (escala Unreal 0.01 vs "1 unit = 1 m"; eixo forward divergente entre export-pipeline e validation-checklist). Sem menção a Roblox em asset-optimization; não vi menção em nenhum arquivo lido.

## Segurança

**Achado nos arquivos de skill lidos: nada suspeito.** Nenhum prompt injection, pedido de rede, download, exfiltração, chave, desligar permissões ou `curl | sh` em: blender-director, lowpoly-style, stylized-style, qa-review, asset-optimization, prop-artist, character-artist, export-pipeline, texture-workflow, cozy-wholesome-mood, references/{polycount-budgets, validation-checklist, reference-image-match, mcp-integration}, CLAUDE.md.

Pontos de atenção (setup, não conteúdo das skills):

- `docs/BLENDER_MCP_SETUP.md`: manda rodar `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"` (instalador oficial da uv, mas é remoto-para-shell), alterar PATH do usuário de forma permanente e baixar `https://github.com/ahujasid/blender-mcp/raw/main/addon.py` (branch `main`, sem versão fixa).
- `.mcp.json`: `cmd /c uvx --python 3.11 blender-mcp` (pacote sem versão fixa, puxa a última a cada execução), porta `9876`, `DISABLE_TELEMETRY=true`.
- `QUICKSTART.md`: sugere `/plugin marketplace add arjun988/blender-skills` e `Copy-Item -Force` (sobrescreve sem perguntar). Instalar como plugin deixa o autor alterar o comportamento do agente a cada atualização.
- `blender-director` e `mcp-integration`: mandam "preferir MCP a instruções de UI" e criar hierarquia de coleções (Reference, Blockout, HighPoly, LowPoly, Collision, Lights, Export) imediatamente. Não é malicioso, mas conflita com nossas convenções de organização.
- `execute_blender_code` roda Python arbitrário no Blender (risco do addon, não do repo).

**Não consegui verificar:**
- Conteúdo dos outros ~80 SKILL.md e da maioria dos 175+ arquivos de `references/` (inclusive uv-workflow, hard-surface, collision-proxy, set-dressing, scene-assembly, rigging).
- Se existem scripts `.py`/`.sh`/`.ps1` aninhados: a busca sugere que a linguagem principal é TypeScript (do `site/`), o que não indica scripts, mas não vi a árvore completa.
- `site/package.json` e dependências npm (não lidas; irrelevantes se não instalarmos o site).
- `.cursor/`, `.claude-plugin/marketplace.json` e histórico de commits.
- O WebFetch resume por modelo pequeno: um trecho malicioso sutil poderia ser omitido. Para rigor, clonar em pasta isolada e rodar `rg -i "curl|wget|iex|Invoke-|base64|http|ssh|token|key"` antes de qualquer cópia.

## Proposta: o que adaptar (4 a 6)

Regra: a skill `roblox-asset-pipeline` vence em qualquer conflito. Trazer como **referências curtas (20-60 linhas)** em `references/` da nossa skill, reescritas, não copiadas por inteiro.

1. **qa-review (formato)** (~100 linhas, ~1,4k tokens). Motivo: níveis de severidade e veredito SHIP/NO-SHIP dão formato ao nosso checklist da seção 5 e ao `qa-tester`. Adaptar: trocar critérios por nossos (zfight_pairs=0, tris do style guide, frente -Z, pivô na base, checagem no Studio). Conflito: nenhum direto; a validação deles é só no Blender e nossa regra é "verificar no Studio".
2. **reference-image-match** (~210 linhas, ~2,8k tokens; cortar para ~60). Motivo: método de analisar imagem, enquadrar, blockout, comparar até 3 passes serve para recriar props a partir de `Assets/reference/`. Adaptar: usar paleta do atlas da família em vez de materiais PBR; render com nosso `toylib.render`. Conflito: manda criar hierarquia de coleções e usar MCP ao vivo; nossa regra é headless via `bl.sh` e MCP só para a cena que o usuário assiste.
3. **lowpoly-style, só o teste de silhueta e as regras "sem subdivisão, sem micro-bevel"** (~20 linhas aproveitáveis). Motivo: teste de silhueta em cor chapada na distância de jogo é barato e útil. Adaptar: descartar PS1/horror e os números de tris (usar `docs/art/style-guide.md`). Conflito: tris deles (props 50-500) divergem do nosso budget; o style guide vence.
4. **stylized-style, só shape language** (~30 linhas). Motivo: círculo = amigável, quadrado = estável, triângulo = perigoso ajuda design de clientes/anomalias e de animais R6. Adaptar: alinhar à paleta e ao tom de `docs/art/style-guide.md`; ignorar NPR/outline do Blender (Roblox não usa). Conflito: nenhum.
5. **asset-optimization, só a auditoria de malha** (~25 linhas). Motivo: lista de limpeza (vértices duplicados, loose, não-manifold, normais invertidas, transformações aplicadas) cobre normais, que nossa skill trata pouco. Adaptar: integrar ao `overlap_check.py` como passo extra; remover LOD (Roblox faz sozinho), prefixos `SM_`/`MAT_`/`COL_` e UV com texel density (usamos atlas por faixas). Conflito: nomes PascalCase em inglês e `Att_*` prevalecem.
6. **cozy-wholesome-mood** (26 linhas, ~0,4k tokens). Motivo: só se o `docs/vision.md` pedir tom aconchegante; é pequeno. Opcional, não prioritário; a direção real vem do `art-director` e do usuário.

## O que NÃO trazer

- Pacote inteiro, plugin marketplace, `.mcp.json`, `QUICKSTART.md`, setup do addon: já temos Blender MCP; o `uvx` sem versão fixa e `irm | iex` são risco desnecessário.
- `blender-director` (358 linhas): roteador de 94 skills; duplica nosso `orchestration.md` e pesa contexto.
- `export-pipeline`, `unity-export`, `unreal-export`, `godot-export`, `lod-pipeline`: outros engines e escala/eixo diferentes dos nossos (0,01, rotação 180, frente -Z); incoerentes entre si.
- `character-artist`, `creature-artist`, `rigging`, `hair-groom`: realista/edge loops; conflitam com `roblox-cartoon-animal-char` (R6, cabeça redonda, rosto por textura).
- `texture-workflow`, `materials`, `lookdev`, `rendering`: PBR/bake; usamos atlas de cor.
- Todos os `*-style`, `*-worlds`, `genre-*`, `*-horror`, `visual-console-eras`: estilos fora do nosso, e skills de gênero sem relação com Roblox.

## Recomendação

1. Não instalar nada agora. Se o dono quiser mais, clonar em pasta isolada e fazer o `rg` de segurança acima antes de qualquer cópia.
2. Reescrever os itens 1 a 5 em uma única referência `references/qa-and-style.md` (~100 linhas) na skill do projeto e registrar origem MIT em `docs/art/credits.md` (conteúdo derivado de arjun988/blender-skills, licença MIT).
3. Custo/benefício: ganho pequeno, porque a skill do projeto já cobre os pontos fortes; o valor real é o formato de QA e o teste de silhueta.

## Fontes

- https://github.com/arjun988/blender-skills (README, estrutura, pastas `.claude/skills`, `references`, `site`)
- https://raw.githubusercontent.com/arjun988/blender-skills/main/.mcp.json
- https://raw.githubusercontent.com/arjun988/blender-skills/main/docs/BLENDER_MCP_SETUP.md
- https://raw.githubusercontent.com/arjun988/blender-skills/main/QUICKSTART.md
- https://raw.githubusercontent.com/arjun988/blender-skills/main/CLAUDE.md
- https://github.com/arjun988/blender-skills/blob/main/.claude/skills/blender-director/SKILL.md
- https://raw.githubusercontent.com/arjun988/blender-skills/main/.claude/skills/ (lowpoly-style, stylized-style, qa-review, asset-optimization, prop-artist, character-artist, export-pipeline, texture-workflow, cozy-wholesome-mood, references/*)
- https://skillsllm.com/skill/blender-skills e https://trendshift.io/repositories/74897 (metadados; contagem de estrelas diverge entre sites)
- Nossa skill: `C:\Users\hakor\.claude\skills\roblox-asset-pipeline\SKILL.md`
